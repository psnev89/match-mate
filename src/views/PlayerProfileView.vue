<script setup>
import { computed, ref, watch } from "vue";
import { RouterLink, useRoute } from "vue-router";
import { getPlayerProfile } from "../services/football";
import { useFootballStore } from "../stores/football";
import SeasonPicker from "../components/SeasonPicker.vue";
const route = useRoute();
const football = useFootballStore();
const profile = ref(null);
const loading = ref(true);
const error = ref("");
let request = 0;
const cards = computed(() => {
  const s = profile.value.stats;
  return [
    ["Appearances", s.games],
    ["Goals", s.goals],
    ["Wins", s.wins],
    ["Draws", s.draws],
    ["Losses", s.losses],
    [
      "Goals / game",
      s.goals_per_game == null ? "—" : Number(s.goals_per_game).toFixed(2),
    ],
    [
      "Win rate",
      s.win_percentage == null
        ? "—"
        : `${Number(s.win_percentage).toFixed(1)}%`,
    ],
  ];
});
async function load() {
  const id = ++request;
  loading.value = true;
  error.value = "";
  const year = football.season;
  if (!Number.isInteger(year) || year < 1900 || year > 2100) {
    loading.value = false;
    error.value = "Enter a season from 1900 to 2100.";
    return;
  }
  try {
    const result = await getPlayerProfile(route.params.id, year);
    if (id === request) profile.value = result;
  } catch (e) {
    if (id === request) error.value = e.message;
  } finally {
    if (id === request) loading.value = false;
  }
}
watch(() => football.season, load, { immediate: true });
</script>
<template>
  <RouterLink to="/leaderboard" class="text-emerald-800 underline"
    >← Player stats</RouterLink
  >
  <div class="my-6 flex flex-wrap items-center justify-between gap-4">
    <h1 class="heading">{{ profile?.player.name ?? "Player profile" }}</h1>
    <SeasonPicker />
  </div>
  <p v-if="loading" role="status">Loading player…</p>
  <div v-else-if="error" class="error" role="alert">
    {{ error }} <button class="underline" @click="load">Retry</button>
  </div>
  <template v-else
    ><p v-if="!profile.player.active" class="mb-4 text-slate-500">
      Inactive player · historical stats preserved
    </p>
    <div class="grid grid-cols-2 gap-4 sm:grid-cols-3">
      <div v-for="[label, value] in cards" :key="label" class="card">
        <p class="text-sm text-slate-500">{{ label }}</p>
        <p class="mt-2 text-3xl font-bold">{{ value }}</p>
      </div>
    </div>
    <p class="success mt-5">
      {{
        Number(profile.stats.games) >= 5
          ? "Qualified for the season win-rate leaderboard."
          : `${5 - Number(profile.stats.games)} more appearance(s) needed to qualify for the win-rate leaderboard.`
      }}
    </p>
    <p class="mt-4 text-sm text-slate-500">
      Own goals are excluded. Total goals include older matches; appearances,
      results, win rate and goals/game use only matches with this player's
      recorded lineup. Draws count as games, not wins.
    </p>
  </template>
</template>
