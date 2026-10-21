<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "../stores/auth";
import { isConfigured } from "../lib/supabase";
const auth = useAuthStore();
const router = useRouter();
const email = ref("");
const password = ref("");
const busy = ref(false);
const error = ref("");
async function submit() {
  if (busy.value) return;
  busy.value = true;
  error.value = "";
  try {
    await auth.signIn(email.value.trim(), password.value);
    await router.replace("/");
  } catch (e) {
    error.value = e.message;
  } finally {
    busy.value = false;
  }
}
</script>
<template>
  <section class="mx-auto max-w-md py-8">
    <p
      class="mb-3 text-sm font-bold uppercase tracking-widest text-emerald-700"
    >
      Your weekly ritual
    </p>
    <h1 class="heading">Every match counts.</h1>
    <p class="mb-8 mt-3 text-slate-600">
      Keep the score. Chase the Golden Boot. Settle the season.
    </p>
    <div v-if="!isConfigured" class="card space-y-3">
      <h2 class="font-bold">Connect your Supabase project</h2>
      <p class="text-slate-600">
        Copy .env.example to .env.local, enter your project URL and publishable
        key, then restart the app. Follow README.md to create the database and
        member accounts.
      </p>
    </div>
    <form v-else class="card space-y-5" @submit.prevent="submit">
      <h2 class="text-xl font-bold">Sign in to your group</h2>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
      <div>
        <label for="email" class="label">Email</label
        ><input
          id="email"
          v-model="email"
          class="field"
          type="email"
          autocomplete="username"
          required
        />
      </div>
      <div>
        <label for="password" class="label">Password</label
        ><input
          id="password"
          v-model="password"
          class="field"
          type="password"
          autocomplete="current-password"
          required
        />
      </div>
      <button class="btn w-full" :disabled="busy">
        {{ busy ? "Signing in…" : "Sign in" }}
      </button>
      <p class="text-sm text-slate-500">
        Ask your group organizer for an account or a password reset.
      </p>
    </form>
  </section>
</template>
