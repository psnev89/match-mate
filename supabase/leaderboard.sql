-- Optional: refresh leaderboard functions AFTER the new schema or migration.
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
grant execute on function public.season_leaderboard(integer) to anon, authenticated;

create or replace function public.season_win_rates(p_year integer)
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
grant execute on function public.season_win_rates(integer) to anon, authenticated;
