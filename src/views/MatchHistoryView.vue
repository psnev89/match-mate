<script setup>
import { ref, watch } from "vue";
import { RouterLink } from "vue-router";
import { useAuthStore } from "../stores/auth";
import { useFootballStore } from "../stores/football";
import { getMatches } from "../services/football";
import { formatDate } from "../lib/stats";
import SeasonPicker from "../components/SeasonPicker.vue";
const auth = useAuthStore();
const football = useFootballStore();
const matches = ref([]);
const loading = ref(false);
const error = ref("");
let request = 0;
function teamName(id) {
  return football.teams.find((team) => team.id === id)?.name ?? "Team";
}
function missingScorers(match) {
  return match.goals.filter((goal) => !goal.player_id).length;
}
async function load() {
  const id = ++request;
  const year = football.season;
  error.value = "";
  if (!Number.isInteger(year) || year < 1900 || year > 2100) {
    loading.value = false;
    error.value = "Enter a season from 1900 to 2100.";
    return;
  }
  loading.value = true;
  try {
    const [, results] = await Promise.all([
      football.loadRoster(),
      getMatches(year),
    ]);
    if (id === request) matches.value = results;
  } catch (e) {
    if (id === request) error.value = e.message;
  } finally {
    if (id === request) loading.value = false;
  }
}
watch(() => football.season, load, { immediate: true });
</script>
<template>
  <div class="mb-6 flex flex-wrap items-center justify-between gap-4">
    <h1 class="heading">Match history</h1>
    <SeasonPicker />
  </div>
  <RouterLink v-if="auth.user" to="/matches/new" class="btn mb-5"
    >+ Log a match</RouterLink
  >
  <p v-if="loading" role="status">Loading matches…</p>
  <div v-else-if="error" role="alert" class="error">
    {{ error }} <button class="underline" @click="load">Retry</button>
  </div>
  <template v-else>
    <p class="mb-4 text-sm text-slate-500">
      {{ matches.length }} matches in {{ football.season }} · newest first
    </p>
    <p v-if="!matches.length" class="card">
      No matches recorded for this season yet.
    </p>
    <ul v-else class="space-y-4">
      <li v-for="match in matches" :key="match.id" class="card">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <RouterLink
            :to="`/matches/${match.id}`"
            class="font-semibold text-emerald-800 underline"
            >{{ formatDate(match.date) }}</RouterLink
          ><RouterLink
            v-if="auth.user"
            :to="`/matches/${match.id}/edit`"
            class="btn-secondary"
            :aria-label="`Edit match on ${match.date}`"
            >Edit match</RouterLink
          >
        </div>
        <p class="mt-3 text-lg font-bold">
          {{ teamName(match.team_a_id) }} {{ match.team_a_score }}–{{
            match.team_b_score
          }}
          {{ teamName(match.team_b_id) }}
        </p>
        <p v-if="missingScorers(match)" class="mt-2 text-sm text-amber-800">
          {{ missingScorers(match) }} goal(s) without a recorded scorer{{
            auth.user ? " — edit to fill them in." : "."
          }}
        </p>
      </li>
    </ul>
  </template>
</template>
