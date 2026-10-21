import test from "node:test";
import assert from "node:assert/strict";
import { matchSummary } from "../src/lib/share.js";
const teams = [
  { id: "a", name: "Team A" },
  { id: "b", name: "Team B" },
];
const game = {
  date: "2026-10-18",
  team_a_id: "a",
  team_b_id: "b",
  team_a_score: 3,
  team_b_score: 0,
  match_players: [
    { team_id: "a", player_id: "alex", player: { name: "Alex" } },
    { team_id: "b", player_id: "blair", player: { name: "Blair" } },
  ],
  goals: [
    {
      team_id: "a",
      player_id: "alex",
      player: { name: "Alex" },
      is_own_goal: false,
    },
    {
      team_id: "a",
      player_id: "alex",
      player: { name: "Alex" },
      is_own_goal: false,
    },
    {
      team_id: "a",
      player_id: "blair",
      player: { name: "Blair" },
      is_own_goal: true,
    },
  ],
};
test("share text groups repeated scorers and marks own goals under the credited team", () => {
  const text = matchSummary(game, teams);
  assert.ok(text.includes("*Team A 3–0 Team B*"));
  assert.ok(text.includes("Alex ×2, Blair (own goal)"));
  assert.ok(text.includes("*Team B lineup*\nBlair\nGoals: None"));
});
test("legacy games explicitly say attendance was not recorded", () => {
  const text = matchSummary({ ...game, match_players: [] }, teams);
  assert.equal(text.match(/Lineup not recorded/g).length, 2);
});
