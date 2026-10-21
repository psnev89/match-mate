-- Run once after migration 005. No existing data is changed.
begin;
-- Reuse the same season rules as individual profiles, in one browser request.
create function public.season_players(p_year integer)
returns table(player_id uuid,name text,active boolean,games bigint,wins bigint,draws bigint,losses bigint,goals bigint,win_percentage numeric)
language sql stable security invoker set search_path = '' as $$
  select p.id,p.name,p.active,s.games,s.wins,s.draws,s.losses,s.goals,s.win_percentage
  from public.players p
  cross join lateral public.player_season_stats(p.id,p_year) s
  order by p.name,p.id;
$$;
revoke all on function public.season_players(integer) from public,anon,authenticated;
grant execute on function public.season_players(integer) to anon,authenticated;
commit;
