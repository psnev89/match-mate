<script setup>
import { ref, watch } from "vue";
import { RouterLink, RouterView, useRouter } from "vue-router";
import { useRegisterSW } from "virtual:pwa-register/vue";
import { useAuthStore } from "./stores/auth";
import { useFootballStore } from "./stores/football";

const auth = useAuthStore();
const football = useFootballStore();
const router = useRouter();
const error = ref("");
const signingOut = ref(false);
const { needRefresh, updateServiceWorker } = useRegisterSW();
const links = [
  { to: "/", label: "Overview" },
  { to: "/matches/new", label: "Log match" },
  { to: "/leaderboard", label: "Player stats" },
  { to: "/roster", label: "Players" },
];
watch(
  () => auth.user,
  (user) => {
    if (!user) {
      football.clear();
      router.replace("/login");
    }
  },
);
async function signOut() {
  signingOut.value = true;
  error.value = "";
  try {
    await auth.signOut();
  } catch (e) {
    error.value = e.message;
  } finally {
    signingOut.value = false;
  }
}
</script>
<template>
  <header class="border-b border-slate-200 bg-white">
    <div class="mx-auto flex max-w-5xl items-center justify-between px-4 py-4">
      <RouterLink to="/" class="flex items-center gap-3 font-bold"
        ><img src="/pwa-192x192.png" alt="" class="h-10 w-10 rounded-xl" /><span
          >Match Mate<span class="block text-xs font-normal text-slate-500"
            >Same friends. New bragging rights.</span
          ></span
        ></RouterLink
      >
      <button
        v-if="auth.user"
        class="min-h-12 px-3 text-sm font-semibold"
        :disabled="signingOut"
        @click="signOut"
      >
        Sign out
      </button>
    </div>
  </header>
  <div v-if="error" role="alert" class="error mx-auto max-w-5xl">
    {{ error }}
  </div>
  <div
    v-if="needRefresh"
    class="mx-auto flex max-w-5xl flex-wrap items-center gap-3 bg-amber-50 p-4"
    role="status"
  >
    <p>New version available. Save your work before updating.</p>
    <button class="btn-secondary" @click="updateServiceWorker()">Update</button
    ><button class="btn-secondary" @click="needRefresh = false">Later</button>
  </div>
  <main class="mx-auto max-w-5xl px-4 py-7 pb-28">
    <RouterView :key="$route.fullPath" />
  </main>
  <nav
    v-if="auth.user"
    aria-label="Main navigation"
    class="fixed inset-x-0 bottom-0 border-t border-slate-200 bg-white pb-[env(safe-area-inset-bottom)]"
  >
    <div class="mx-auto grid max-w-3xl grid-cols-4">
      <RouterLink
        v-for="link in links"
        :key="link.to"
        :to="link.to"
        class="flex min-h-16 items-center justify-center px-1 text-center text-sm font-semibold text-slate-500"
        exact-active-class="!bg-emerald-50 !text-emerald-800"
        >{{ link.label }}</RouterLink
      >
    </div>
  </nav>
</template>
