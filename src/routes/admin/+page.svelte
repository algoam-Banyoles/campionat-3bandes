<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/authStore';
  import { checkIsAdmin, adminStore } from '$lib/roles';
  import Banner from '$lib/components/Banner.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';

  let loading = true;
  let error: string | null = null;

  let challenge_id = '';
  let tipus: 'incompareixenca' | 'desacord_dates' = 'incompareixenca';
  let penaltyBusy = false;
  let penaltyOk: string | null = null;
  let penaltyErr: string | null = null;

  let preBusy = false;
  let preOk: string | null = null;
  let preErr: string | null = null;

  let inactBusy = false;
  let inactOk: string | null = null;
  let inactErr: string | null = null;

  onMount(async () => {
    try {
      loading = true;
      error = null;

      const u = $user;
      if (!u?.email) {
        // si no hi ha sessió, cap a login
        goto('/login');
        return;
      }

      const adm = await checkIsAdmin();
      if (!adm) {
        error = errText('Només els administradors poden accedir a aquesta pàgina.');
        return;
      }
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function applyPenalty() {
    try {
      penaltyBusy = true;
      penaltyOk = null;
      penaltyErr = null;
      const { supabase } = await import('$lib/supabaseClient');
      const { data } = await supabase.auth.getSession();
      const token = data?.session?.access_token;
      const res = await fetch('/admin/penalitzacions', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: 'Bearer ' + token
        },
        body: JSON.stringify({ challenge_id, tipus })
      });
      const js = await res.json();
      if (!res.ok || !js.ok) throw new Error(js.error || 'Error aplicant penalització');
      penaltyOk = 'Penalització aplicada';
      challenge_id = '';
      tipus = 'incompareixenca';
    } catch (e) {
      penaltyErr = formatSupabaseError(e);
    } finally {
      penaltyBusy = false;
    }
  }

  async function execPreInactivity() {
    try {
      preBusy = true;
      preOk = null;
      preErr = null;
      const { supabase } = await import('$lib/supabaseClient');
      const { error } = await supabase.rpc('run_pre_inactivity');
      if (error) throw error;
      preOk = 'Pre-inactivitat executada';
    } catch (e) {
      preErr = formatSupabaseError(e);
    } finally {
      preBusy = false;
    }
  }

  async function execInactivity() {
    try {
      inactBusy = true;
      inactOk = null;
      inactErr = null;
      const { supabase } = await import('$lib/supabaseClient');
      const { error } = await supabase.rpc('run_inactivity');
      if (error) throw error;
      inactOk = 'Inactivitat executada';
    } catch (e) {
      inactErr = formatSupabaseError(e);
    } finally {
      inactBusy = false;
    }
  }
</script>

<svelte:head>
  <title>Administració</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Administració</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else if error}
  <Banner type="error" message={error} />
{:else if $adminStore}
  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
    <!-- Targeta: crear repte -->
    <a href="/admin/reptes/nou" class="block rounded-2xl border p-4 hover:shadow-sm">
      <h2 class="font-semibold">➕ Crear repte</h2>
      <p class="text-sm text-slate-600 mt-1">
        Dona d’alta un repte entre dos jugadors. Pots forçar excepcions i programar-lo directament.
      </p>
    </a>

    <!-- Targeta: gestió de reptes (llistat i filtres) -->
    <a href="/admin/reptes" class="block rounded-2xl border p-4 hover:shadow-sm">
      <h2 class="font-semibold">🗂️ Reptes — Gestió</h2>
      <p class="text-sm text-slate-600 mt-1">
        Visualitza, filtra i actualitza l’estat dels reptes (proposats, acceptats, programats, jugats…).
      </p>
    </a>

    <!-- Targeta: penalitzacions -->
    <div class="rounded-2xl border p-4">
      <h2 class="font-semibold">⚖️ Penalitzacions</h2>
      {#if penaltyOk}
        <Banner type="success" message={penaltyOk} class="mb-2" />
      {/if}
      {#if penaltyErr}
        <Banner type="error" message={penaltyErr} class="mb-2" />
      {/if}
      <form class="space-y-2" on:submit|preventDefault={applyPenalty}>
        <input
          class="w-full rounded-xl border px-3 py-2"
          placeholder="ID repte"
          bind:value={challenge_id}
        />
        <select class="w-full rounded-xl border px-3 py-2" bind:value={tipus}>
          <option value="incompareixenca">incompareixenca</option>
          <option value="desacord_dates">desacord_dates</option>
        </select>
        <button
          type="submit"
          class="rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
          disabled={penaltyBusy}
        >
          {#if penaltyBusy}Aplicant…{:else}Aplica{/if}
        </button>
      </form>
    </div>

    <!-- Targeta: pre-inactivitat -->
    <div class="rounded-2xl border p-4">
      <h2 class="font-semibold">⏳ Executa pre-inactivitat</h2>
      {#if preOk}
        <Banner type="success" message={preOk} class="mb-2" />
      {/if}
      {#if preErr}
        <Banner type="error" message={preErr} class="mb-2" />
      {/if}
      <button
        class="mt-2 rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
        on:click={execPreInactivity}
        disabled={preBusy}
      >
        {#if preBusy}Executant…{:else}Executa{/if}
      </button>
    </div>

    <!-- Targeta: inactivitat -->
    <div class="rounded-2xl border p-4">
      <h2 class="font-semibold">😴 Executa inactivitat</h2>
      {#if inactOk}
        <Banner type="success" message={inactOk} class="mb-2" />
      {/if}
      {#if inactErr}
        <Banner type="error" message={inactErr} class="mb-2" />
      {/if}
      <button
        class="mt-2 rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
        on:click={execInactivity}
        disabled={inactBusy}
      >
        {#if inactBusy}Executant…{:else}Executa{/if}
      </button>
    </div>

    <!-- (espai per futures seccions d’admin) -->
    <div class="rounded-2xl border p-4 opacity-70">
      <h2 class="font-semibold">📈 Rànquing / Penes (properament)</h2>
      <p class="text-sm text-slate-600 mt-1">
        Històric de moviments, aplicació de penes i ajustos de posició segons normativa.
      </p>
    </div>
  </div>
{/if}
