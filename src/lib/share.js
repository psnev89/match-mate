// Plain text with WhatsApp-style emphasis. Nothing is sent automatically.
export function matchSummary(match, teams) {
  const name = (id) => teams.find((team) => team.id === id)?.name ?? "Team";
  const a = name(match.team_a_id),
    b = name(match.team_b_id);
  const lines = [
    "⚽ *Match Mate*",
    `📅 ${match.date}`,
    "",
    `*${a} ${match.team_a_score}–${match.team_b_score} ${b}*`,
  ];
  for (const teamId of [match.team_a_id, match.team_b_id]) {
    lines.push("", `*${name(teamId)} lineup*`);
    const players = match.match_players.filter((row) => row.team_id === teamId);
    lines.push(
      players.length
        ? players.map((row) => row.player.name).join(", ")
        : "Lineup not recorded",
    );
    const totals = new Map();
    for (const goal of match.goals.filter((goal) => goal.team_id === teamId)) {
      const key = `${goal.player_id}:${goal.is_own_goal}`;
      const row = totals.get(key) ?? {
        name: goal.player?.name ?? "Scorer not recorded",
        own: goal.is_own_goal,
        count: 0,
      };
      row.count++;
      totals.set(key, row);
    }
    lines.push(
      `Goals: ${totals.size ? [...totals.values()].map((row) => `${row.name}${row.count > 1 ? ` ×${row.count}` : ""}${row.own ? " (own goal)" : ""}`).join(", ") : "None"}`,
    );
  }
  return lines.join("\n");
}
