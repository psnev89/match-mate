<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { useFootballStore } from "../stores/football";
import { logMatch, getMatch, getPreviousMatch } from "../services/football";
import {
  localToday,
  validScore,
  scorerSlot,
  validLineups,
  lineupOptions,
} from "../lib/stats";

const football = useFootballStore();
const route = useRoute();
const router = useRouter();
const editing = Boolean(route.params.id);
const version = ref(null);
const originalPlayers = ref([]);
const copying = ref(false);
const hydrating = ref(false);
const copyMessage = ref("");
const date = ref(localToday());
const scores = reactive({ A: 0, B: 0 });
const goals = reactive({ A: [], B: [] });
// Five slots per side. Players not selected did not play.
const lineups = reactive({ A: Array(5).fill(""), B: Array(5).fill("") });
const loading = ref(true);
const saving = ref(false);
const loadError = ref("");
const error = ref("");
const success = ref("");
const activePlayers = computed(() =>
  football.players.filter(
    (player) => player.active || originalPlayers.value.includes(player.id),
  ),
);
const sides = computed(() =>
  ["A", "B"].map((slot) => ({
    slot,
    team: football.teams.find((team) => team.slot === slot),
    players: activePlayers.value.filter((player) =>
      lineups[slot].includes(player.id),
    ),
  })),
);
function teamName(slot) {
  return (
    sides.value.find((side) => side.slot === slot)?.team?.name ?? `Team ${slot}`
  );
}
function availableScorers(slot, goal) {
  const playingFor = scorerSlot(slot, goal.is_own_goal);
  return sides.value.find((side) => side.slot === playingFor)?.players ?? [];
}
function resetLineups() {
  lineups.A = Array(5).fill("");
  lineups.B = Array(5).fill("");
}
for (const slot of ["A", "B"]) {
  watch(
    () => scores[slot],
    (score) => {
      if (!validScore(score)) return;
      goals[slot] = Array.from(
        { length: score },
        (_, index) =>
          goals[slot][index] ?? { player_id: "", is_own_goal: false },
      );
    },
    { flush: "sync" },
  );
}
// Moving/removing a player clears scorer choices that are no longer valid.
watch(
  lineups,
  () => {
    if (hydrating.value) return;
    for (const slot of ["A", "B"]) {
      for (const goal of goals[slot]) {
        if (
          !availableScorers(slot, goal).some(
            (player) => player.id === goal.player_id,
          )
        ) {
          goal.player_id = "";
        }
      }
    }
  },
  { flush: "sync" },
);
const valid = computed(
  () =>
    Boolean(date.value) &&
    validLineups(lineups, activePlayers.value) &&
    sides.value.every(
      (side) =>
        side.team &&
        side.players.length === 5 &&
        validScore(scores[side.slot]) &&
        goals[side.slot].length === scores[side.slot] &&
        goals[side.slot].every(
          (goal) =>
            !goal.player_id ||
            availableScorers(side.slot, goal).some(
              (player) => player.id === goal.player_id,
            ),
        ),
    ),
);
async function load() {
  loading.value = true;
  loadError.value = "";
  try {
    await football.loadRoster();
    if (sides.value.some((side) => !side.team))
      throw new Error(
        "Create Team A and Team B using the database setup script.",
      );
    resetLineups();
    if (editing) {
      const match = await getMatch(route.params.id);
      hydrating.value = true;
      date.value = match.date;
      version.value = match.version;
      originalPlayers.value = match.match_players.map((row) => row.player_id);
      for (const side of sides.value) {
        const ids = match.match_players
          .filter((row) => row.team_id === side.team.id)
          .map((row) => row.player_id);
        lineups[side.slot] = Array.from(
          { length: 5 },
          (_, index) => ids[index] ?? "",
        );
        scores[side.slot] =
          side.slot === "A" ? match.team_a_score : match.team_b_score;
        const entries = match.goals.filter(
          (goal) => goal.team_id === side.team.id,
        );
        goals[side.slot] = Array.from(
          { length: scores[side.slot] },
          (_, index) => ({
            player_id: entries[index]?.player_id ?? "",
            is_own_goal: entries[index]?.is_own_goal ?? false,
          }),
        );
      }
      hydrating.value = false;
      // Both sides are now loaded; invalid legacy scorer choices need correction.
      for (const side of sides.value)
        for (const goal of goals[side.slot]) {
          if (
            !availableScorers(side.slot, goal).some(
              (player) => player.id === goal.player_id,
            )
          )
            goal.player_id = "";
        }
      if (!match.lineup_recorded)
        copyMessage.value =
          "This older match has no lineup. Select all ten players before saving.";
    }
  } catch (e) {
    loadError.value = e.message;
  } finally {
    loading.value = false;
  }
}
async function submit() {
  if (saving.value || !valid.value) return;
  saving.value = true;
  error.value = "";
  success.value = "";
  try {
    const savedId = await logMatch({
      matchId: editing ? route.params.id : null,
      version: version.value,
      date: date.value,
      lineupA: sides.value
        .find((side) => side.slot === "A")
        .players.map((player) => player.id),
      lineupB: sides.value
        .find((side) => side.slot === "B")
        .players.map((player) => player.id),
      goalsA: goals.A.map((goal) => ({ ...goal })),
      goalsB: goals.B.map((goal) => ({ ...goal })),
    });
    success.value = `Match saved: ${scores.A}–${scores.B}.`;
    if (editing) version.value += 1;
    router.push(`/matches/${savedId}`);
    football.season = Number(date.value.slice(0, 4));
    scores.A = 0;
    scores.B = 0;
    goals.A = [];
    goals.B = [];
    resetLineups();
  } catch (e) {
    error.value =
      e.code === "23505"
        ? "A match already exists for this date. Check the dashboard before retrying."
        : `${e.message || "Could not save."} Your entries have been kept. If the connection dropped, check the dashboard before retrying.`;
  } finally {
    saving.value = false;
  }
}
async function copyLineups() {
  if (lineups.A.some(Boolean) || lineups.B.some(Boolean)) {
    if (
      !window.confirm(
        "Replace the current lineups with the previous match’s lineups?",
      )
    )
      return;
  }
  copying.value = true;
  error.value = "";
  copyMessage.value = "";
  try {
    const previous = await getPreviousMatch(date.value);
    if (!previous) {
      copyMessage.value = "No earlier match with a recorded lineup was found.";
      return;
    }
    let skipped = 0;
    for (const side of sides.value) {
      const ids = previous.match_players
        .filter((row) => row.team_id === side.team.id)
        .map((row) => row.player_id);
      const available = ids.filter((id) =>
        activePlayers.value.some((player) => player.id === id),
      );
      skipped += ids.length - available.length;
      lineups[side.slot] = Array.from(
        { length: 5 },
        (_, index) => available[index] ?? "",
      );
    }
    copyMessage.value = `Copied lineups from ${previous.date}. Review all ten players.${skipped ? " Inactive players were left out; fill the empty slots." : ""}`;
  } catch (e) {
    error.value = e.message;
  } finally {
    copying.value = false;
  }
}
onMounted(load);
</script>
<template>
  <div class="mx-auto max-w-2xl">
    <h1 class="heading">{{ editing ? "Edit match" : "Log a match" }}</h1>
    <p class="mb-6 mt-2 text-slate-600">
      Pick the lineups and result. Goalscorers are optional and can be added
      later.
    </p>
    <p v-if="loading" role="status">Loading the squad…</p>
    <div v-else-if="loadError" class="error" role="alert">
      {{ loadError }} <button class="underline" @click="load">Retry</button>
    </div>
    <form v-else class="space-y-5" @submit.prevent="submit">
      <div v-if="success" class="success" role="status">
        {{ success }}
        <RouterLink to="/" class="font-semibold underline"
          >View dashboard</RouterLink
        >
      </div>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
      <fieldset :disabled="saving || copying" class="space-y-5">
        <legend class="sr-only">Match details</legend>
        <div>
          <label for="match-date" class="label">Date played</label
          ><input
            id="match-date"
            v-model="date"
            class="field"
            type="date"
            min="1900-01-01"
            max="2100-12-31"
            required
          />
        </div>
        <section>
          <div v-if="!editing" class="mb-4">
            <button
              type="button"
              class="btn-secondary"
              :disabled="!date || copying"
              @click="copyLineups"
            >
              {{ copying ? "Loading…" : "Copy previous lineups" }}
            </button>
            <p class="mt-2 text-xs text-slate-500">
              Uses the latest recorded lineup before the selected date. Review
              who is playing today.
            </p>
          </div>
          <p
            v-if="copyMessage"
            role="status"
            class="mb-4 rounded-xl bg-amber-50 p-3 text-sm"
          >
            {{ copyMessage }}
          </p>
          <h2 class="text-xl font-bold">1. Pick the two teams</h2>
          <p class="mb-4 mt-2 text-sm text-slate-600">
            Five players per team. Players already picked are hidden from the
            other dropdowns.
          </p>
          <p
            v-if="activePlayers.length < 10"
            class="mb-4 rounded-xl bg-amber-50 p-4 text-sm text-amber-900"
          >
            You need at least 10 active players.
            <RouterLink to="/roster" class="font-semibold underline"
              >Add players</RouterLink
            >
            before logging a 5v5 match.
          </p>
          <div class="grid gap-4 sm:grid-cols-2">
            <section v-for="side in sides" :key="side.slot" class="card">
              <h3 class="text-xl font-bold">{{ side.team.name }}</h3>
              <p class="mt-1 text-sm text-slate-500">
                {{ side.players.length }} / 5 selected
              </p>
              <div
                v-for="(_, index) in lineups[side.slot]"
                :key="index"
                class="mt-4"
              >
                <label :for="`lineup-${side.slot}-${index}`" class="label"
                  >Player {{ index + 1 }}</label
                >
                <select
                  :id="`lineup-${side.slot}-${index}`"
                  v-model="lineups[side.slot][index]"
                  class="field"
                  required
                >
                  <option value="">Select player</option>
                  <option
                    v-for="player in lineupOptions(
                      activePlayers,
                      lineups,
                      side.slot,
                      index,
                    )"
                    :key="player.id"
                    :value="player.id"
                  >
                    {{ player.name }}
                  </option>
                </select>
              </div>
            </section>
          </div>
          <p class="mt-3 text-xs text-slate-500">
            To swap players, clear one selection first. Changing a lineup clears
            any goalscorer selections that no longer match.
          </p>
        </section>
        <h2 class="text-xl font-bold">2. Result and goals</h2>
        <div class="grid gap-4 sm:grid-cols-2">
          <section v-for="side in sides" :key="side.slot" class="card">
            <h3 class="text-xl font-bold">{{ side.team.name }}</h3>
            <label :for="`score-${side.slot}`" class="label mt-4"
              >Final score (including own goals)</label
            >
            <input
              :id="`score-${side.slot}`"
              v-model.number="scores[side.slot]"
              class="field !text-center !text-3xl font-bold"
              type="number"
              inputmode="numeric"
              min="0"
              max="50"
              step="1"
              required
            />
            <div
              v-for="(goal, index) in goals[side.slot]"
              :key="index"
              class="mt-5 border-t border-slate-100 pt-4"
            >
              <label :for="`goal-${side.slot}-${index}`" class="label"
                >Goal {{ index + 1 }} credited to {{ side.team.name }}</label
              >
              <label class="mb-2 flex min-h-10 items-center gap-2 text-sm"
                ><input
                  v-model="goal.is_own_goal"
                  type="checkbox"
                  class="h-5 w-5 accent-emerald-700"
                  @change="goal.player_id = ''"
                />Own goal by {{ teamName(scorerSlot(side.slot, true)) }}</label
              >
              <select
                :id="`goal-${side.slot}-${index}`"
                v-model="goal.player_id"
                class="field"
              >
                <option value="">Scorer not recorded (optional)</option>
                <option
                  v-for="player in availableScorers(side.slot, goal)"
                  :key="player.id"
                  :value="player.id"
                >
                  {{ player.name }}
                </option>
              </select>
              <p v-if="goal.is_own_goal" class="mt-2 text-xs text-slate-500">
                Counts for {{ side.team.name }}. Does not count toward the
                player's Golden Boot goals.
              </p>
            </div>
          </section>
        </div>
        <p class="text-sm text-slate-500">
          Leave scorers blank to save just the result, or select a player again
          for each goal they scored. Reducing the score removes the last
          selections. A 0–0 draw still needs both lineups.
        </p>
        <button
          class="btn w-full"
          :disabled="saving || !valid"
          :aria-busy="saving"
        >
          {{
            saving ? "Saving match…" : editing ? "Save changes" : "Save match"
          }}
        </button>
        <p class="text-center text-xs text-slate-500">
          An internet connection is required to save.
        </p>
      </fieldset>
    </form>
  </div>
</template>
