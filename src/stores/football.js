import { ref } from "vue";
import { defineStore } from "pinia";
import * as service from "../services/football";

export const useFootballStore = defineStore("football", () => {
  const season = ref(new Date().getFullYear());
  const teams = ref([]);
  const players = ref([]);

  async function loadRoster() {
    const [newTeams, newPlayers] = await Promise.all([
      service.getTeams(),
      service.getPlayers(),
    ]);
    teams.value = newTeams;
    players.value = newPlayers;
  }

  function clear() {
    teams.value = [];
    players.value = [];
  }
  return { season, teams, players, loadRoster, clear };
});
