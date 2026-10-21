import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "./stores/auth";
import { isConfigured } from "./lib/supabase";
import LoginView from "./views/LoginView.vue";
import DashboardView from "./views/DashboardView.vue";
import LogMatchView from "./views/LogMatchView.vue";
import LeaderboardView from "./views/LeaderboardView.vue";
import RosterView from "./views/RosterView.vue";

import MatchHistoryView from "./views/MatchHistoryView.vue";
import MatchDetailView from "./views/MatchDetailView.vue";
import PlayerProfileView from "./views/PlayerProfileView.vue";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", component: LoginView },
    { path: "/", component: DashboardView },
    { path: "/matches", component: MatchHistoryView },
    {
      path: "/matches/new",
      component: LogMatchView,
      meta: { requiresAuth: true },
    },
    {
      path: "/matches/:id/edit",
      component: LogMatchView,
      meta: { requiresAuth: true },
    },
    { path: "/matches/:id", component: MatchDetailView },
    { path: "/players/:id", component: PlayerProfileView },
    { path: "/leaderboard", component: LeaderboardView },
    { path: "/roster", component: RosterView },
    { path: "/:pathMatch(.*)*", redirect: "/" },
  ],
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  try {
    await auth.init();
  } catch {
    if (to.meta.requiresAuth) return "/login";
  }
  if (!isConfigured && to.path !== "/login") return "/login";
  if (to.meta.requiresAuth && !auth.user) return "/login";
  if (auth.user && to.path === "/login") return "/";
});
export default router;
