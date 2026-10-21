<script setup>
import { RouterLink } from "vue-router";
import { computed, ref, watch } from "vue";
import { getLeaderboard, getWinRates, getMatches } from "../services/football";
import { useFootballStore } from "../stores/football";
import SeasonPicker from "../components/SeasonPicker.vue";
const football = useFootballStore();
const scorers = ref([]);
const winRates = ref([]);
const matches = ref([]);
const loading = ref(false);
const error = ref("");
let request = 0;
const missingLineups = computed(
  () => matches.value.filter((match) => !match.lineup_recorded).length,
);
async function load() {
  const id = ++request;
  error.value = "";
  const year = football.season;
  if (!Number.isInteger(year) || year < 1900 || year > 2100) {
    loading.value = false;
    error.value = "Enter a season from 1900 to 2100.";
    return;
  }
  loading.value = true;
  try {
    const [goals, rates, results] = await Promise.all([
      getLeaderboard(year),
      getWinRates(year),
      getMatches(year),
    ]);
    if (id === request) {
      scorers.value = goals;
      winRates.value = rates;
      matches.value = results;
    }
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
      <p class="mb-1 text-sm font-semibold text-amber-700">
        THE SEASON'S PLAYERS
      </p>
      <h1 class="heading">Player stats</h1>
    </div>
    <SeasonPicker />
  </div>
  <p v-if="loading" role="status">Loading player stats…</p>
  <div v-else-if="error" class="error" role="alert">
    {{ error }} <button class="ml-3 underline" @click="load">Retry</button>
  </div>
  <div v-else class="grid items-start gap-5 md:grid-cols-2">
    <section class="card">
      <h2 class="text-xl font-bold">Golden Boot</h2>
      <p class="mb-3 mt-2 text-sm text-slate-500">
        Assigned goals this season. Own goals and goals without a scorer are
        excluded.
      </p>
      <p v-if="!scorers.length" class="text-slate-600">
        Add your players to start the Golden Boot race.
      </p>
      <ol v-else class="divide-y divide-slate-100">
        <li
          v-for="row in scorers"
          :key="row.player_id"
          class="flex items-center gap-4 py-4"
        >
          <span
            class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-amber-50 font-bold text-amber-800"
            >{{ row.rank }}</span
          ><span class="flex-1 font-semibold"
            ><RouterLink
              :to="`/players/${row.player_id}`"
              class="text-emerald-800 underline"
              >{{ row.name }}</RouterLink
            ></span
          ><span class="text-right"
            ><strong class="block text-2xl">{{ row.goals }}</strong
            ><span class="text-xs text-slate-500">goals</span></span
          >
        </li>
      </ol>
      <p class="mt-4 text-xs text-slate-500">
        Goals stay with the player even when they switch sides. Tied scorers
        share a rank.
      </p>
    </section>
    <section class="card">
      <h2 class="text-xl font-bold">Highest win rate</h2>
      <p class="mb-3 mt-2 text-sm text-slate-500">
        At least 5 games played this season. Wins ÷ games played; draws count as
        games, not wins.
      </p>
      <p
        v-if="missingLineups"
        role="status"
        class="mb-4 rounded-xl bg-amber-50 p-3 text-sm text-amber-900"
      >
        {{ missingLineups }} older match{{ missingLineups === 1 ? "" : "es" }}
        without recorded lineups
        {{ missingLineups === 1 ? "is" : "are" }} excluded from win rates. Their
        scores and goals still count elsewhere.
      </p>
      <p v-if="!winRates.length" class="py-4 text-slate-600">
        No player has 5 recorded appearances yet. Keep logging everyone's match
        lineup.
      </p>
      <ol v-else class="divide-y divide-slate-100">
        <li
          v-for="row in winRates"
          :key="row.player_id"
          class="flex items-center gap-4 py-4"
        >
          <span
            class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-emerald-50 font-bold text-emerald-800"
            >{{ row.rank }}</span
          ><span class="flex-1"
            ><strong class="block"
              ><RouterLink
                :to="`/players/${row.player_id}`"
                class="text-emerald-800 underline"
                >{{ row.name }}</RouterLink
              ></strong
            ><span class="text-xs text-slate-500"
              >{{ row.wins }} wins / {{ row.games }} games</span
            ></span
          ><strong class="text-xl"
            >{{ Number(row.win_percentage).toFixed(1) }}%</strong
          >
        </li>
      </ol>
      <p class="mt-4 text-xs text-slate-500">
        Uses the team each player actually played for in each match. Equal win
        rates share a rank; ordering uses the unrounded rate.
      </p>
    </section>
  </div>
</template>
