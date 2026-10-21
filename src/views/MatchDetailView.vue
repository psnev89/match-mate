<script setup>
import { computed, onMounted, ref } from "vue";
import { RouterLink, useRoute } from "vue-router";
import { getMatch } from "../services/football";
import { useFootballStore } from "../stores/football";
import { formatDate } from "../lib/stats";
import { matchSummary } from "../lib/share";
const route = useRoute();
const football = useFootballStore();
const match = ref(null);
const loading = ref(true);
const error = ref("");
const message = ref("");
const summary = computed(() =>
  match.value ? matchSummary(match.value, football.teams) : "",
);
const whatsappUrl = computed(
  () => `https://wa.me/?text=${encodeURIComponent(summary.value)}`,
);
function teamName(id) {
  return football.teams.find((team) => team.id === id)?.name ?? "Team";
}
async function load() {
  loading.value = true;
  error.value = "";
  try {
    const [result] = await Promise.all([
      getMatch(route.params.id),
      football.loadRoster(),
    ]);
    match.value = result;
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}
async function copy() {
  try {
    await navigator.clipboard.writeText(summary.value);
    message.value = "Summary copied. Paste it into your group chat.";
  } catch {
    message.value =
      "Copy is unavailable. Select and copy the text below manually.";
  }
}
onMounted(load);
</script>
<template>
  <RouterLink to="/" class="text-emerald-800 underline">← Dashboard</RouterLink>
  <p v-if="loading" class="mt-5" role="status">Loading match…</p>
  <div v-else-if="error" class="error mt-5" role="alert">
    {{ error }} <button class="underline" @click="load">Retry</button>
  </div>
  <template v-else>
    <div class="my-6 flex flex-wrap items-center justify-between gap-4">
      <div>
        <p class="text-slate-500">{{ formatDate(match.date) }}</p>
        <h1 class="heading">
          {{ teamName(match.team_a_id) }} {{ match.team_a_score }}–{{
            match.team_b_score
          }}
          {{ teamName(match.team_b_id) }}
        </h1>
      </div>
      <RouterLink :to="`/matches/${match.id}/edit`" class="btn"
        >Edit match</RouterLink
      >
    </div>
    <p v-if="!match.lineup_recorded" class="mb-4 rounded-xl bg-amber-50 p-4">
      This older match has no recorded lineup. Editing it lets you add all ten
      players.
    </p>
    <div class="grid gap-4 sm:grid-cols-2">
      <section
        v-for="teamId in [match.team_a_id, match.team_b_id]"
        :key="teamId"
        class="card"
      >
        <h2 class="text-xl font-bold">{{ teamName(teamId) }}</h2>
        <h3 class="mb-2 mt-4 font-semibold">Lineup</h3>
        <p
          v-if="!match.match_players.some((row) => row.team_id === teamId)"
          class="text-slate-500"
        >
          Not recorded
        </p>
        <ul class="space-y-2">
          <li
            v-for="row in match.match_players.filter(
              (row) => row.team_id === teamId,
            )"
            :key="row.player_id"
          >
            <RouterLink
              :to="`/players/${row.player_id}`"
              class="text-emerald-800 underline"
              >{{ row.player.name }}</RouterLink
            >
          </li>
        </ul>
        <h3 class="mb-2 mt-5 font-semibold">
          Goals credited to {{ teamName(teamId) }}
        </h3>
        <p
          v-if="!match.goals.some((goal) => goal.team_id === teamId)"
          class="text-slate-500"
        >
          None
        </p>
        <ul class="space-y-2">
          <li
            v-for="goal in match.goals.filter(
              (goal) => goal.team_id === teamId,
            )"
            :key="goal.id"
          >
            ⚽ {{ goal.player.name }}
            <span v-if="goal.is_own_goal" class="text-sm text-amber-800"
              >(own goal)</span
            >
          </li>
        </ul>
      </section>
    </div>
    <section class="card mt-6">
      <h2 class="text-xl font-bold">Share the match</h2>
      <p class="mb-4 mt-2 text-sm text-slate-600">
        Copy this summary, or open WhatsApp and choose your group. You review
        and send it yourself.
      </p>
      <div class="mb-4 flex flex-wrap gap-3">
        <button class="btn" @click="copy">Copy text</button
        ><a
          :href="whatsappUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="btn-secondary"
          >Open WhatsApp</a
        >
      </div>
      <p v-if="message" role="status" class="mb-3 text-sm text-emerald-800">
        {{ message }}
      </p>
      <label for="share-text" class="sr-only">Match summary</label
      ><textarea
        id="share-text"
        :value="summary"
        readonly
        rows="14"
        class="field !min-h-64 text-sm"
      />
    </section>
  </template>
</template>
