// All database calls live here. Views do not need to know SQL or table details.
import { supabase } from "../lib/supabase";

export async function getTeams() {
  const { data, error } = await supabase
    .from("teams")
    .select("*")
    .order("slot");
  if (error) throw error;
  return data;
}

export async function getPlayers() {
  const { data, error } = await supabase
    .from("players")
    .select("*")
    .order("name");
  if (error) throw error;
  return data;
}

export async function addPlayer(name) {
  const { error } = await supabase
    .from("players")
    .insert({ name: name.trim() });
  if (error) throw error;
}

export async function updatePlayer(id, { name, active }) {
  const { error } = await supabase
    .from("players")
    .update({ name: name.trim(), active })
    .eq("id", id);
  if (error) throw error;
}

export async function getMatches(year) {
  // Pagination avoids silently losing matches/goals at Supabase's row limit.
  const matches = [];
  const pageSize = 200;
  for (let offset = 0; ; offset += pageSize) {
    const { data, error } = await supabase
      .from("matches")
      .select("*, goals(player_id)")
      .eq("season_year", year)
      .order("date", { ascending: false })
      .range(offset, offset + pageSize - 1);
    if (error) throw error;
    matches.push(...data);
    if (data.length < pageSize) break;
  }
  return matches;
}

export async function getLeaderboard(year) {
  const { data, error } = await supabase.rpc("season_leaderboard", {
    p_year: year,
  });
  if (error) throw error;
  return data;
}

export async function getWinRates(year) {
  const { data, error } = await supabase.rpc("season_win_rates", {
    p_year: year,
  });
  if (error) throw error;
  return data;
}

export async function logMatch({
  date,
  lineupA,
  lineupB,
  goalsA,
  goalsB,
  matchId = null,
  version = null,
}) {
  // One transaction saves the result, attendance and goals together.
  const { data, error } = await supabase.rpc("save_match", {
    p_match_id: matchId,
    p_expected_version: version,
    p_date: date,
    p_lineup_a: lineupA,
    p_lineup_b: lineupB,
    p_goals_a: goalsA.map((goal) => ({
      ...goal,
      player_id: goal.player_id || null,
    })),
    p_goals_b: goalsB.map((goal) => ({
      ...goal,
      player_id: goal.player_id || null,
    })),
  });
  if (error) throw error;
  return data;
}

export async function getMatch(id) {
  const { data, error } = await supabase
    .from("matches")
    .select(
      "*, goals(*, player:players(id,name)), match_players(*, player:players(id,name))",
    )
    .eq("id", id)
    .single();
  if (error) throw error;
  return data;
}

export async function getPreviousMatch(beforeDate) {
  const { data, error } = await supabase
    .from("matches")
    .select("id")
    .eq("lineup_recorded", true)
    .lt("date", beforeDate)
    .order("date", { ascending: false })
    .limit(1);
  if (error) throw error;
  return data.length ? getMatch(data[0].id) : null;
}

export async function getPlayerProfile(id, year) {
  const [player, stats] = await Promise.all([
    supabase.from("players").select("id,name,active").eq("id", id).single(),
    supabase.rpc("player_season_stats", { p_player_id: id, p_year: year }),
  ]);
  if (player.error) throw player.error;
  if (stats.error) throw stats.error;
  return { player: player.data, stats: stats.data[0] };
}
