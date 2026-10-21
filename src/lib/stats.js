// Pure functions are easy to read and test without a database.
export function calculateTeamSummary(teams, matches) {
  return teams.map((team) => {
    let wins = 0;
    let goalDifference = 0;
    for (const match of matches) {
      if (team.id !== match.team_a_id && team.id !== match.team_b_id) continue;
      const isA = team.id === match.team_a_id;
      const scored = isA ? match.team_a_score : match.team_b_score;
      const conceded = isA ? match.team_b_score : match.team_a_score;
      if (scored > conceded) wins++;
      goalDifference += scored - conceded;
    }
    return { ...team, wins, goalDifference };
  });
}

// "creditedSlot" is the side whose score increases, even for an own goal.
export function scorerSlot(creditedSlot, isOwnGoal) {
  return isOwnGoal ? (creditedSlot === "A" ? "B" : "A") : creditedSlot;
}

export function localToday() {
  const date = new Date();
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

export function formatDate(value) {
  // Dates represent a calendar day, not a UTC timestamp.
  return new Intl.DateTimeFormat(undefined, {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(new Date(`${value}T12:00:00`));
}

export function validScore(value) {
  return Number.isInteger(value) && value >= 0 && value <= 50;
}

// Each of the ten slots needs a different active player.
export function validLineups(lineups, activePlayers) {
  const ids = [...lineups.A, ...lineups.B];
  const activeIds = new Set(activePlayers.map((player) => player.id));
  return (
    lineups.A.length === 5 &&
    lineups.B.length === 5 &&
    new Set(ids).size === 10 &&
    ids.every((id) => activeIds.has(id))
  );
}

export function lineupOptions(players, lineups, slot, index) {
  const selected = new Set([...lineups.A, ...lineups.B]);
  const current = lineups[slot][index];
  return players.filter(
    (player) => player.id === current || !selected.has(player.id),
  );
}
