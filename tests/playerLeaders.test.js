import test from "node:test";
import assert from "node:assert/strict";
import { playerLeaders } from "../src/lib/playerLeaders.js";
const row = (name, games, wins, goals = 0) => ({ name, games, wins, goals });
test("no fake winner in empty or zero-goal seasons", () => {
  assert.deepEqual(playerLeaders([]), {
    scorers: [],
    winners: [],
    highestGoals: 0,
  });
  assert.equal(playerLeaders([row("New", 0, 0)]).scorers.length, 0);
});
test("five games qualifies; four games at 100 percent does not", () => {
  const result = playerLeaders([row("Four", 4, 4, 2), row("Five", 5, 3, 1)]);
  assert.deepEqual(
    result.winners.map((p) => p.name),
    ["Five"],
  );
  assert.deepEqual(
    result.scorers.map((p) => p.name),
    ["Four"],
  );
});
test("shared leaders include equivalent fractions and goal totals", () => {
  const result = playerLeaders([
    row("One", 5, 3, 8),
    row("Two", 10, 6, 8),
    row("Three", 5, 2, 7),
  ]);
  assert.equal(result.winners.length, 2);
  assert.equal(result.scorers.length, 2);
});
test("leader uses actual fraction, even if rounded display rates are equal", () => {
  const result = playerLeaders([
    row("Lower", 2001, 1000),
    row("Higher", 2000, 1000),
  ]);
  assert.deepEqual(
    result.winners.map((p) => p.name),
    ["Higher"],
  );
});
