<script setup>
import { RouterLink } from "vue-router";
import { onMounted, reactive, ref } from "vue";
import { useFootballStore } from "../stores/football";
import { addPlayer, updatePlayer } from "../services/football";
const football = useFootballStore();
const loading = ref(true);
const busy = ref(false);
const error = ref("");
const success = ref("");
const editingId = ref(null);
const form = reactive({ name: "", active: true });
function reset() {
  editingId.value = null;
  form.name = "";
  form.active = true;
}
function edit(player) {
  editingId.value = player.id;
  Object.assign(form, {
    name: player.name,
    active: player.active,
  });
  success.value = "";
  document.getElementById("player-name")?.focus();
}
async function load() {
  loading.value = true;
  error.value = "";
  try {
    await football.loadRoster();
    reset();
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}
async function save() {
  if (busy.value || !form.name.trim()) return;
  busy.value = true;
  error.value = "";
  success.value = "";
  try {
    if (editingId.value) await updatePlayer(editingId.value, form);
    else await addPlayer(form.name);
    success.value = "Player saved.";
    reset();
    // A refresh failure must not imply the successful write failed.
    try {
      await football.loadRoster();
    } catch {
      error.value =
        "Player saved, but refreshing the list failed. Please reload.";
    }
  } catch (e) {
    error.value = e.message;
  } finally {
    busy.value = false;
  }
}
onMounted(load);
</script>
<template>
  <h1 class="heading">The squad</h1>
  <p class="mb-6 mt-2 text-slate-600">
    Add your friends by name. Pick their teams when logging each match.
  </p>
  <p v-if="loading" role="status">Loading players…</p>
  <template v-else>
    <div v-if="error" role="alert" class="error mb-4">
      {{ error }}
      <button :disabled="busy" class="underline" @click="load">Refresh</button>
    </div>
    <p v-if="success" role="status" class="success mb-4">{{ success }}</p>
    <form class="card mb-6 space-y-4" @submit.prevent="save">
      <h2 class="text-xl font-bold">
        {{ editingId ? "Edit player" : "Add a player" }}
      </h2>
      <fieldset :disabled="busy" class="space-y-4">
        <legend class="sr-only">Player details</legend>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label class="label" for="player-name">Name</label
            ><input
              id="player-name"
              v-model="form.name"
              class="field"
              maxlength="100"
              required
            />
          </div>
        </div>
        <label v-if="editingId" class="flex min-h-12 items-center gap-3"
          ><input
            v-model="form.active"
            type="checkbox"
            class="h-5 w-5 accent-emerald-700"
          />Active player</label
        >
        <p v-if="editingId" class="text-sm text-slate-500">
          Inactive players disappear from goalscorer selectors. Their historical
          goals remain.
        </p>
        <div class="flex gap-3">
          <button class="btn" :disabled="!form.name.trim()">
            {{ busy ? "Saving…" : "Save player" }}</button
          ><button
            v-if="editingId"
            type="button"
            class="btn-secondary"
            @click="reset"
          >
            Cancel
          </button>
        </div>
      </fieldset>
    </form>
    <section class="card">
      <h2 class="mb-3 text-xl font-bold">All players</h2>
      <p v-if="!football.players.length" class="text-slate-500">
        No players yet. Add at least ten active players for a 5v5 match.
      </p>
      <ul class="divide-y divide-slate-100">
        <li
          v-for="player in football.players"
          :key="player.id"
          class="flex items-center justify-between gap-3 py-3"
        >
          <span
            ><RouterLink
              :to="`/players/${player.id}`"
              class="text-emerald-800 underline"
              >{{ player.name }}</RouterLink
            ><span v-if="!player.active" class="block text-xs text-slate-500"
              >Inactive</span
            ></span
          >
          <button
            class="btn-secondary"
            :disabled="busy"
            :aria-label="`Edit ${player.name}`"
            @click="edit(player)"
          >
            Edit
          </button>
        </li>
      </ul>
    </section>
  </template>
</template>
