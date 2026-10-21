<script setup>
import { useAuthStore } from "../stores/auth";
const auth = useAuthStore();
import { computed, ref, watch } from "vue";
import { RouterLink } from "vue-router";
import { useFootballStore } from "../stores/football";
import { getMatches } from "../services/football";
import { calculateTeamSummary, formatDate } from "../lib/stats";
import SeasonPicker from "../components/SeasonPicker.vue";
const football = useFootballStore();
const matches = ref([]);
const loading = ref(false);
const error = ref("");
let request = 0;
const teamSummary = computed(() =>
  calculateTeamSummary(football.teams, matches.value),
);
const draws = computed(
  () => matches.value.filter((m) => m.team_a_score === m.team_b_score).length,
);
function teamName(id) {
  return football.teams.find((t) => t.id === id)?.name ?? "Team";
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
  <div class="mb-7 flex flex-wrap items-center justify-between gap-4">
    <div>
      <p class="mb-1 text-sm font-semibold text-emerald-700">
        THE SEASON SO FAR
      </p>
      <h1 class="heading">Scoreboard</h1>
    </div>
    <SeasonPicker />
  </div>
  <p v-if="loading" role="status">Loading the season…</p>
  <div v-else-if="error" class="error" role="alert">
    {{ error }} <button class="ml-3 underline" @click="load">Retry</button>
  </div>
  <template v-else>
    <section class="rounded-3xl bg-emerald-950 p-6 text-white sm:p-8">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 class="text-lg font-semibold">
          The race for {{ football.season }}
        </h2>
        <span class="rounded-full bg-white/10 px-3 py-1 text-sm"
          >{{ matches.length }} matches played</span
        >
      </div>
      <div class="my-7 grid grid-cols-3 gap-3 text-center">
        <div v-for="team in football.teams" :key="team.id">
          <p class="text-sm text-emerald-100">{{ team.name }}</p>
          <p class="mt-2 text-5xl font-bold">
            {{ teamSummary.find((row) => row.id === team.id)?.wins ?? 0 }}
          </p>
          <p class="mt-2 text-sm text-emerald-100">wins</p>
          <p class="mt-3 text-xs text-emerald-200">
            Goal difference:
            {{
              (teamSummary.find((row) => row.id === team.id)?.goalDifference ??
                0) > 0
                ? "+"
                : ""
            }}{{
              teamSummary.find((row) => row.id === team.id)?.goalDifference ?? 0
            }}
          </p>
        </div>
        <div>
          <p class="text-sm text-emerald-100">All square</p>
          <p class="mt-2 text-5xl font-bold">{{ draws }}</p>
          <p class="mt-2 text-sm text-emerald-100">draws</p>
        </div>
      </div>
      <RouterLink
        v-if="auth.user"
        to="/matches/new"
        class="btn !bg-white !text-emerald-950"
        >+ Log a new match</RouterLink
      >
    </section>
    <section class="mt-7">
      <div class="mb-4 flex items-center justify-between">
        <h2 class="text-xl font-bold">Recent matches</h2>
        <RouterLink to="/matches" class="text-emerald-800 underline"
          >View all</RouterLink
        >
      </div>
      <div v-if="!matches.length" class="card text-slate-600">
        The season starts here. Log your first match after the final whistle.
      </div>
      <ul v-else class="space-y-3">
        <li v-for="match in matches.slice(0, 10)" :key="match.id" class="card">
          <p class="mb-3 text-xs text-slate-500">
            <RouterLink
              :to="`/matches/${match.id}`"
              class="font-semibold text-emerald-800 underline"
              >{{ formatDate(match.date) }} · View match</RouterLink
            >
          </p>
          <div class="grid grid-cols-[1fr_auto_1fr] items-center gap-3">
            <span class="font-semibold">{{ teamName(match.team_a_id) }}</span
            ><strong class="rounded-lg bg-slate-100 px-4 py-2 text-xl"
              >{{ match.team_a_score }} : {{ match.team_b_score }}</strong
            ><span class="text-right font-semibold">{{
              teamName(match.team_b_id)
            }}</span>
          </div>
        </li>
      </ul>
    </section>
  </template>
</template>
