-- Run once AFTER migrations 002 and 003. Existing records are preserved.
begin;
alter table public.matches add column version integer not null default 1;
create or replace function public.save_match(
  p_date date,
  p_lineup_a uuid[],
  p_lineup_b uuid[],
  p_goals_a jsonb,
  p_goals_b jsonb,
  p_match_id uuid default null,
  p_expected_version integer default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_team_a uuid;
  v_team_b uuid;
  v_match_id uuid;
  v_players uuid[];
  v_goal jsonb;
  v_player_id uuid;
  v_own_goal boolean;
  v_credit_a boolean;
  v_existing public.matches%rowtype;
  v_previous_players uuid[] := array[]::uuid[];
begin
  if auth.uid() is null then
    raise exception 'Sign in before recording a match.';
  end if;
  if p_date is null or p_date not between date '1900-01-01' and date '2100-12-31' then
    raise exception 'Choose a match date between 1900 and 2100.';
  end if;
  if p_lineup_a is null or p_lineup_b is null
     or cardinality(p_lineup_a) <> 5 or cardinality(p_lineup_b) <> 5 then
    raise exception 'Select exactly five players for each team.';
  end if;
  if p_match_id is not null then
    select * into v_existing from public.matches where id = p_match_id for update;
    if not found then raise exception 'Match not found.'; end if;
    if p_expected_version is distinct from v_existing.version then
      raise exception 'This match was edited by someone else. Reload before saving.';
    end if;
    select coalesce(array_agg(player_id), array[]::uuid[]) into v_previous_players
      from public.match_players where match_id = p_match_id;
  end if;
  v_players := p_lineup_a || p_lineup_b;
  if array_position(v_players, null) is not null
     or cardinality(v_players) <> (select count(distinct id) from unnest(v_players) as p(id)) then
    raise exception 'A player can appear only once in a match lineup.';
  end if;
  if p_goals_a is null or p_goals_b is null
     or jsonb_typeof(p_goals_a) <> 'array' or jsonb_typeof(p_goals_b) <> 'array' then
    raise exception 'Provide both goal lists.';
  end if;
  if jsonb_array_length(p_goals_a) > 50 or jsonb_array_length(p_goals_b) > 50 then
    raise exception 'Each score must be between 0 and 50.';
  end if;

  select id into strict v_team_a from public.teams where slot = 'A';
  select id into strict v_team_b from public.teams where slot = 'B';
  perform p.id from public.players p where p.id = any(v_players)
    order by p.id for share;
  if exists (
    select 1 from unnest(v_players) as selected(id)
    left join public.players p on p.id = selected.id
    where p.id is null or (not p.active and not (p.id = any(v_previous_players)))
  ) then
    raise exception 'Select active players for the match lineup.';
  end if;

  if p_match_id is null then
    insert into public.matches(date, team_a_id, team_a_score, team_b_id, team_b_score, lineup_recorded)
      values (p_date, v_team_a, jsonb_array_length(p_goals_a), v_team_b, jsonb_array_length(p_goals_b), true)
      returning id into v_match_id;
  else
    v_match_id := p_match_id;
    update public.matches set date = p_date, team_a_score = jsonb_array_length(p_goals_a),
      team_b_score = jsonb_array_length(p_goals_b), lineup_recorded = true, version = version + 1
      where id = v_match_id;
    delete from public.goals where match_id = v_match_id;
    delete from public.match_players where match_id = v_match_id;
  end if;
  insert into public.match_players(match_id, player_id, team_id)
    select v_match_id, id, v_team_a from unnest(p_lineup_a) as p(id)
    union all
    select v_match_id, id, v_team_b from unnest(p_lineup_b) as p(id);

  -- Validate against that day's lineup, never the player's usual team.
  for v_goal, v_credit_a in
    select value, true from jsonb_array_elements(p_goals_a)
    union all
    select value, false from jsonb_array_elements(p_goals_b)
  loop
    if jsonb_typeof(v_goal) is distinct from 'object'
       or jsonb_typeof(v_goal -> 'player_id') is distinct from 'string'
       or jsonb_typeof(v_goal -> 'is_own_goal') is distinct from 'boolean' then
      raise exception 'Each goal needs a player and an own-goal flag.';
    end if;
    v_player_id := (v_goal ->> 'player_id')::uuid;
    v_own_goal := (v_goal ->> 'is_own_goal')::boolean;
    -- Normal goal: scorer plays for the credited side. Own goal: opposite side.
    if not (v_player_id = any(
      case when v_credit_a <> v_own_goal then p_lineup_a else p_lineup_b end
    )) then
      raise exception 'Goal scorer does not match the selected lineup and goal type.';
    end if;
    insert into public.goals(match_id, player_id, team_id, is_own_goal)
      values (v_match_id, v_player_id, case when v_credit_a then v_team_a else v_team_b end, v_own_goal);
  end loop;
  return v_match_id;
end;
$$;

revoke all on function public.save_match(date,uuid[],uuid[],jsonb,jsonb,uuid,integer) from public,anon,authenticated;
grant execute on function public.save_match(date,uuid[],uuid[],jsonb,jsonb,uuid,integer) to authenticated;
-- Keep the previous create-only API working, using the same validated save.
create or replace function public.record_match(p_date date,p_lineup_a uuid[],p_lineup_b uuid[],p_goals_a jsonb,p_goals_b jsonb)
returns uuid language sql security invoker set search_path = '' as $$
  select public.save_match(p_date,p_lineup_a,p_lineup_b,p_goals_a,p_goals_b);
$$;

create function public.player_season_stats(p_player_id uuid,p_year integer)
returns table(games bigint,wins bigint,draws bigint,losses bigint,goals bigint,goals_per_game numeric,win_percentage numeric)
language sql stable security invoker set search_path = '' as $$
  with appearances as (
    select m.*, mp.team_id as played_for
    from public.match_players mp join public.matches m on m.id=mp.match_id
    where mp.player_id=p_player_id and m.season_year=p_year and m.lineup_recorded
  ), results as (
    select count(*) as games,
      count(*) filter(where (played_for=team_a_id and team_a_score>team_b_score) or (played_for=team_b_id and team_b_score>team_a_score)) as wins,
      count(*) filter(where team_a_score=team_b_score) as draws,
      count(*) filter(where (played_for=team_a_id and team_a_score<team_b_score) or (played_for=team_b_id and team_b_score<team_a_score)) as losses
    from appearances
  ), scoring as (
    select count(*) as goals, count(*) filter(where exists(select 1 from appearances a where a.id=m.id)) as known_goals
    from public.goals g join public.matches m on m.id=g.match_id
    where g.player_id=p_player_id and m.season_year=p_year and not g.is_own_goal
  )
  select r.games,r.wins,r.draws,r.losses,s.goals,
    round(s.known_goals::numeric/nullif(r.games,0),2),round(100.0*r.wins/nullif(r.games,0),1)
  from results r cross join scoring s;
$$;
revoke all on function public.player_season_stats(uuid,integer) from public,anon,authenticated;
grant execute on function public.player_season_stats(uuid,integer) to authenticated;
commit;
