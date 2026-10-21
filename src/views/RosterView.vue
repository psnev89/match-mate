<script setup>
import { computed, reactive, ref, watch, nextTick } from "vue";
import { RouterLink } from "vue-router";
import { useAuthStore } from "../stores/auth";
import { useFootballStore } from "../stores/football";
import {
  addPlayer,
  updatePlayer,
  getSeasonPlayers,
  getMatches,
} from "../services/football";
import { playerLeaders } from "../lib/playerLeaders";
import SeasonPicker from "../components/SeasonPicker.vue";
const auth = useAuthStore();
const football = useFootballStore();
const rows = ref([]);
const missingLineups = ref(0);
const loading = ref(true);
const busy = ref(false);
const error = ref("");
const success = ref("");
const hint = ref("");
const editingId = ref(null);
const showForm = ref(false);
const form = reactive({ name: "", active: true });
const leaders = computed(() => playerLeaders(rows.value));
let request = 0;
function rate(player) {
  return player.win_percentage == null
    ? "—"
    : `${Number(player.win_percentage).toFixed(1)}%`;
}
function eligibility(player) {
  return `${player.name} has ${player.games} of the 5 games needed to qualify for highest win rate this season. ${5 - Number(player.games)} more needed. Draws count as games.`;
}
function reset() {
  editingId.value = null;
  form.name = "";
  form.active = true;
  showForm.value = false;
}
async function edit(player) {
  editingId.value = player.player_id;
  form.name = player.name;
  form.active = player.active;
  showForm.value = true;
  success.value = "";
  await nextTick();
  document.getElementById("player-name")?.focus();
}
async function openAdd() {
  reset();
  showForm.value = true;
  await nextTick();
  document.getElementById("player-name")?.focus();
}
async function load() {
  const id = ++request;
  const year = football.season;
  error.value = "";
  hint.value = "";
  if (!Number.isInteger(year) || year < 1900 || year > 2100) {
    loading.value = false;
    error.value = "Enter a season from 1900 to 2100.";
    return;
  }
  loading.value = true;
  try {
    const [players, matches] = await Promise.all([
      getSeasonPlayers(year),
      getMatches(year),
    ]);
    if (id === request) {
      rows.value = players;
      missingLineups.value = matches.filter(
        (match) => !match.lineup_recorded,
      ).length;
    }
  } catch (e) {
    if (id === request) error.value = e.message;
  } finally {
    if (id === request) loading.value = false;
  }
}
async function save() {
  if (!auth.user || busy.value || !form.name.trim()) return;
  busy.value = true;
  error.value = "";
  success.value = "";
  try {
    if (editingId.value) await updatePlayer(editingId.value, form);
    else await addPlayer(form.name);
    success.value = "Player saved.";
    reset();
    await load(); // Refresh both cards and the table after a successful write.
  } catch (e) {
    error.value = e.message;
  } finally {
    busy.value = false;
  }
}
watch(() => football.season, load, { immediate: true });
</script>
<template>
  <div class="mb-6 flex flex-wrap items-center justify-between gap-4">
    <div>
      <h1 class="heading">Players</h1>
      <p class="mt-2 text-slate-600">The squad and the season so far.</p>
    </div>
    <SeasonPicker />
  </div>
  <p v-if="loading" role="status">Loading players…</p>
  <div v-if="error" role="alert" class="error mb-4">
    {{ error }}
    <button :disabled="busy" class="underline" @click="load">Retry</button>
  </div>
  <p v-if="success" role="status" class="success mb-4">{{ success }}</p>
  <template v-if="!loading && !error">
    <div class="mb-6 grid gap-4 sm:grid-cols-2">
      <section class="card !border-amber-200 !bg-amber-50">
        <h2
          class="text-sm font-semibold uppercase tracking-wide text-amber-800"
        >
          Top goalscorer
        </h2>
        <template v-if="leaders.scorers.length"
          ><p class="my-3 text-3xl font-bold">
            {{ leaders.highestGoals }} goals
          </p>
          <p class="flex flex-wrap gap-x-3 gap-y-1">
            <RouterLink
              v-for="player in leaders.scorers"
              :key="player.player_id"
              :to="`/players/${player.player_id}`"
              class="font-semibold underline"
              >{{ player.name }}</RouterLink
            >
          </p>
          <p
            v-if="leaders.scorers.length > 1"
            class="mt-2 text-xs text-amber-800"
          >
            Shared lead
          </p></template
        >
        <p v-else class="mt-3 text-slate-600">
          No goals assigned to a player this season yet.
        </p>
      </section>
      <section class="card !border-emerald-200 !bg-emerald-50">
        <h2
          class="text-sm font-semibold uppercase tracking-wide text-emerald-800"
        >
          Highest win rate · 5+ games
        </h2>
        <template v-if="leaders.winners.length"
          ><p class="my-3 text-3xl font-bold">{{ rate(leaders.winners[0]) }}</p>
          <p class="flex flex-wrap gap-x-3 gap-y-1">
            <RouterLink
              v-for="player in leaders.winners"
              :key="player.player_id"
              :to="`/players/${player.player_id}`"
              class="font-semibold underline"
              >{{ player.name }}</RouterLink
            >
          </p>
          <p
            v-if="leaders.winners.length > 1"
            class="mt-2 text-xs text-emerald-800"
          >
            Shared lead
          </p></template
        >
        <p v-else class="mt-3 text-slate-600">
          No player has reached five games this season yet.
        </p>
      </section>
    </div>
    <p
      v-if="missingLineups"
      class="mb-4 rounded-xl bg-amber-50 p-3 text-sm text-amber-900"
    >
      {{ missingLineups }} older match(es) have no recorded lineups. Their goals
      count, but appearances and win rates cannot include them.
    </p>
    <div class="mb-4 flex items-center justify-between">
      <h2 class="text-xl font-bold">Season table</h2>
      <button
        v-if="auth.user"
        class="btn-secondary"
        :disabled="busy"
        @click="openAdd"
      >
        + Add player
      </button>
    </div>
    <section class="card !p-0 overflow-hidden">
      <p v-if="!rows.length" class="p-5 text-slate-500">No players yet.</p>
      <div
        v-else
        class="overflow-x-auto"
        tabindex="0"
        role="region"
        aria-label="Player season statistics. Scroll horizontally to see all columns."
      >
        <table class="w-full whitespace-nowrap text-left text-sm">
          <caption class="sr-only">
            Player results in
            {{
              football.season
            }}
          </caption>
          <thead class="bg-slate-50 text-slate-600">
            <tr>
              <th scope="col" class="p-4">Player</th>
              <th scope="col" class="p-3">Games</th>
              <th scope="col" class="p-3">Won</th>
              <th scope="col" class="p-3">Lost</th>
              <th scope="col" class="p-3">Drawn</th>
              <th scope="col" class="p-3">Win %</th>
              <th scope="col" class="p-3">Goals</th>
              <th v-if="auth.user" scope="col" class="p-3">
                <span class="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="player in rows" :key="player.player_id">
              <th scope="row" class="p-4 font-semibold">
                <RouterLink
                  :to="`/players/${player.player_id}`"
                  class="text-emerald-800 underline"
                  >{{ player.name }}</RouterLink
                ><span
                  v-if="!player.active"
                  class="block text-xs font-normal text-slate-500"
                  >Inactive</span
                >
              </th>
              <td class="p-3">{{ player.games }}</td>
              <td class="p-3">{{ player.wins }}</td>
              <td class="p-3">{{ player.losses }}</td>
              <td class="p-3">{{ player.draws }}</td>
              <td class="p-3">
                <button
                  v-if="Number(player.games) < 5"
                  class="min-h-11 rounded-lg bg-amber-50 px-3 text-amber-800"
                  :title="eligibility(player)"
                  :aria-label="`${rate(player)}. ${eligibility(player)}`"
                  @click="hint = eligibility(player)"
                  @focus="hint = eligibility(player)"
                >
                  {{ rate(player) }} ⓘ</button
                ><span v-else class="px-3 font-semibold text-emerald-800">{{
                  rate(player)
                }}</span>
              </td>
              <td class="p-3 font-semibold">{{ player.goals }}</td>
              <td v-if="auth.user" class="p-3">
                <button
                  class="btn-secondary"
                  :disabled="busy"
                  :aria-label="`Edit ${player.name}`"
                  @click="edit(player)"
                >
                  Edit
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    <p class="mt-3 text-xs text-slate-500">
      Amber win rates are provisional: five games are required for the top card.
      Hover, focus or tap ⓘ for details. Wins ÷ all games, including draws.
      Goals exclude own goals and unassigned scorers.
    </p>
    <p
      v-if="hint"
      role="status"
      class="mt-3 rounded-xl bg-amber-50 p-3 text-sm text-amber-900"
    >
      {{ hint }}
    </p>
  </template>
  <form
    v-if="auth.user && showForm"
    class="card mt-6 space-y-4"
    @submit.prevent="save"
  >
    <h2 class="text-xl font-bold">
      {{ editingId ? "Edit player" : "Add a player" }}
    </h2>
    <fieldset :disabled="busy" class="space-y-4">
      <legend class="sr-only">Player details</legend>
      <div>
        <label for="player-name" class="label">Name</label
        ><input
          id="player-name"
          v-model="form.name"
          class="field"
          maxlength="100"
          required
        />
      </div>
      <label v-if="editingId" class="flex min-h-12 items-center gap-3"
        ><input
          v-model="form.active"
          type="checkbox"
          class="h-5 w-5 accent-emerald-700"
        />Active player</label
      >
      <p v-if="editingId" class="text-sm text-slate-500">
        Inactive players keep their historical goals and results.
      </p>
      <div class="flex gap-3">
        <button class="btn" :disabled="!form.name.trim()">
          {{ busy ? "Saving…" : "Save player" }}</button
        ><button type="button" class="btn-secondary" @click="reset">
          Cancel
        </button>
      </div>
    </fieldset>
  </form>
</template>
