// Show shared leaders on ties. Do not award Golden Boot for zero goals.
export function playerLeaders(players) {
  const highestGoals = Math.max(
    0,
    ...players.map((player) => Number(player.goals)),
  );
  const scorers =
    highestGoals > 0
      ? players.filter((player) => Number(player.goals) === highestGoals)
      : [];
  const eligible = players.filter((player) => Number(player.games) >= 5);
  const best = eligible.reduce((leader, player) => {
    if (
      !leader ||
      Number(player.wins) * Number(leader.games) >
        Number(leader.wins) * Number(player.games)
    )
      return player;
    return leader;
  }, null);
  // Compare fractions, not rounded display percentages.
  const winners = best
    ? eligible.filter(
        (player) =>
          Number(player.wins) * Number(best.games) ===
          Number(best.wins) * Number(player.games),
      )
    : [];
  return { scorers, winners, highestGoals };
}
