-- Run once on an existing database created from the previous version.
-- Keeps existing matches, players and goals. No attendance is guessed for old games.
begin;

alter table public.matches add column lineup_recorded boolean not null default false;
alter table public.goals add column is_own_goal boolean not null default false;

create table public.match_players (
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  team_id uuid not null references public.teams(id) on delete restrict,
  primary key (match_id, player_id)
);
create index match_players_player_idx on public.match_players(player_id);
create index match_players_team_idx on public.match_players(team_id);
alter table public.match_players enable row level security;
create policy match_players_read on public.match_players
  for select to authenticated using (true);
revoke all on public.match_players from anon, authenticated;
grant select on public.match_players to authenticated;

-- Remove the old entry point so an older client cannot skip the lineup rules.
drop function if exists public.log_match(date, uuid[], uuid[]);

-- Goal objects: {"player_id": "uuid", "is_own_goal": false}.
-- p_goals_a always contains goals credited to Team A, including own goals by B.
create function public.record_match(
  p_date date,
  p_lineup_a uuid[],
  p_lineup_b uuid[],
  p_goals_a jsonb,
  p_goals_b jsonb
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
begin
  if auth.uid() is null then
    raise exception 'Sign in before recording a match.';
  end if;
  if p_date is null or p_date not between date '1900-01-01' and date '2100-12-31' then
    raise exception 'Choose a match date between 1900 and 2100.';
  end if;
  if p_lineup_a is null or p_lineup_b is null
     or cardinality(p_lineup_a) = 0 or cardinality(p_lineup_b) = 0 then
    raise exception 'Select at least one player for each team.';
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
    where p.id is null or not p.active
  ) then
    raise exception 'Select active players for the match lineup.';
  end if;

  insert into public.matches(date, team_a_id, team_a_score, team_b_id, team_b_score, lineup_recorded)
    values (p_date, v_team_a, jsonb_array_length(p_goals_a), v_team_b, jsonb_array_length(p_goals_b), true)
    returning id into v_match_id;
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
revoke all on function public.record_match(date, uuid[], uuid[], jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.record_match(date, uuid[], uuid[], jsonb, jsonb) to authenticated;

create or replace function public.season_leaderboard(p_year integer)
returns table (player_id uuid, name text, goals bigint, rank bigint)
language sql stable security invoker set search_path = ''
as $$
  with totals as (
    select p.id as player_id, p.name, count(m.id) as goals
    from public.players p
    left join public.goals g on g.player_id = p.id and not g.is_own_goal
    left join public.matches m on m.id = g.match_id and m.season_year = p_year
    group by p.id, p.name
  )
  select t.player_id, t.name, t.goals, dense_rank() over (order by t.goals desc)
  from totals t order by t.goals desc, t.name, t.player_id;
$$;
revoke all on function public.season_leaderboard(integer) from public, anon, authenticated;
grant execute on function public.season_leaderboard(integer) to authenticated;

create function public.season_win_rates(p_year integer)
returns table (player_id uuid, name text, games bigint, wins bigint, win_percentage numeric, rank bigint)
language sql stable security invoker set search_path = ''
as $$
  with totals as (
    select p.id as player_id, p.name, count(*) as games,
      count(*) filter (where
        (mp.team_id = m.team_a_id and m.team_a_score > m.team_b_score) or
        (mp.team_id = m.team_b_id and m.team_b_score > m.team_a_score)
      ) as wins
    from public.match_players mp
    join public.matches m on m.id = mp.match_id
    join public.players p on p.id = mp.player_id
    where m.season_year = p_year and m.lineup_recorded
    group by p.id, p.name
    having count(*) >= 5
  )
  select t.player_id, t.name, t.games, t.wins,
    round(100.0 * t.wins / t.games, 1) as win_percentage,
    dense_rank() over (order by (t.wins::numeric / t.games) desc) as rank
  from totals t
  order by (t.wins::numeric / t.games) desc, t.name, t.player_id;
$$;
revoke all on function public.season_win_rates(integer) from public, anon, authenticated;
grant execute on function public.season_win_rates(integer) to authenticated;
commit;
