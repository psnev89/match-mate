<script setup>
import { useFootballStore } from "../stores/football";
const football = useFootballStore();
const currentYear = new Date().getFullYear();
// Older seasons remain accessible via the numeric input.
</script>
<template>
  <label class="flex items-center gap-3 text-sm font-semibold"
    >Season
    <input
      v-model.number="football.season"
      aria-label="Season year"
      class="field max-w-28"
      type="number"
      min="1900"
      max="2100"
      :placeholder="String(currentYear)"
    />
  </label>
</template>
