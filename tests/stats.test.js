import test from "node:test";
import assert from "node:assert/strict";
import {
  calculateTeamSummary,
  scorerSlot,
  validScore,
  formatDate,
} from "../src/lib/stats.js";
const teams = [
  { id: "a", name: "A" },
  { id: "b", name: "B" },
];
function match(a, b) {
  return { team_a_id: "a", team_b_id: "b", team_a_score: a, team_b_score: b };
}

test("empty season has zero wins and goal difference", () => {
  assert.deepEqual(
    calculateTeamSummary(teams, []).map((t) => [t.wins, t.goalDifference]),
    [
      [0, 0],
      [0, 0],
    ],
  );
});
test("counts wins and opposite goal differences without a points table", () => {
  const result = calculateTeamSummary(teams, [
    match(3, 1),
    match(0, 0),
    match(1, 2),
  ]);
  assert.deepEqual(
    result.map((t) => [t.wins, t.goalDifference]),
    [
      [1, 1],
      [1, -1],
    ],
  );
  assert.ok(!("points" in result[0]));
});
test("a draw affects neither wins nor goal difference", () => {
  assert.deepEqual(
    calculateTeamSummary(teams, [match(2, 2)]).map((t) => [
      t.wins,
      t.goalDifference,
    ]),
    [
      [0, 0],
      [0, 0],
    ],
  );
});
test("own goals select a player from the side opposite the credited team", () => {
  assert.equal(scorerSlot("A", false), "A");
  assert.equal(scorerSlot("B", false), "B");
  assert.equal(scorerSlot("A", true), "B");
  assert.equal(scorerSlot("B", true), "A");
});
test("scores must be integer numbers in range", () => {
  for (const invalid of ["", "3", -1, 2.5, 51, NaN, null])
    assert.equal(validScore(invalid), false);
  for (const valid of [0, 3, 50]) assert.equal(validScore(valid), true);
});
test("formatDate accepts a calendar day", () => {
  assert.ok(formatDate("2026-10-18").includes("2026"));
});

import { validLineups, lineupOptions } from "../src/lib/stats.js";
const squad = Array.from({ length: 11 }, (_, i) => ({
  id: String(i),
  name: `Player ${i}`,
}));
const fiveAside = {
  A: ["0", "1", "2", "3", "4"],
  B: ["5", "6", "7", "8", "9"],
};
test("5v5 requires ten different active players", () => {
  assert.equal(validLineups(fiveAside, squad), true);
  assert.equal(
    validLineups({ ...fiveAside, A: ["0", "1", "2", "3", ""] }, squad),
    false,
  );
  assert.equal(
    validLineups({ ...fiveAside, B: ["0", "6", "7", "8", "9"] }, squad),
    false,
  );
  assert.equal(
    validLineups({ ...fiveAside, A: ["0", "0", "2", "3", "4"] }, squad),
    false,
  );
  assert.equal(
    validLineups(
      fiveAside,
      squad.filter((p) => p.id !== "9"),
    ),
    false,
  );
  assert.equal(
    validLineups({ ...fiveAside, A: ["0", "1", "2", "3"] }, squad),
    false,
  );
});
test("dropdown keeps its own player but excludes players picked in other slots", () => {
  assert.deepEqual(
    lineupOptions(squad, fiveAside, "A", 0).map((p) => p.id),
    ["0", "10"],
  );
  const cleared = { ...fiveAside, A: ["", "1", "2", "3", "4"] };
  assert.deepEqual(
    lineupOptions(squad, cleared, "B", 0).map((p) => p.id),
    ["0", "5", "10"],
  );
});
