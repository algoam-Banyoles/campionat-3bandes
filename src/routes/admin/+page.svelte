<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/authStore';
  import { checkIsAdmin, adminStore } from '$lib/roles';
  import Banner from '$lib/components/Banner.svelte';
  import Loader from '$lib/components/Loader.svelte';
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

  let resetBusy = false;
  let resetOk: string | null = null;
  let resetErr: string | null = null;
  let clearWaiting = false;

  let captureBusy = false;
  let captureOk: string | null = null;
  let captureErr: string | null = null;

  type Change = {
    creat_el: string;
    player_id: string;
    posicio_anterior: number | null;
    posicio_nova: number | null;
    motiu: string | null;
  };

  let recent: Change[] = [];
  let recentPlayers: Record<string, string> = {};
  let histLoading = false;
  let histErr: string | null = null;


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

      await loadRecent();

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
      const { error } = await supabase.rpc('apply_pre_inactivity', {
        p_event_id: null
      });
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
      const { error } = await supabase.rpc('apply_inactivity', {
        p_event_id: null
      });
      if (error) throw error;
      inactOk = 'Inactivitat executada';
    } catch (e) {
      inactErr = formatSupabaseError(e);
    } finally {
      inactBusy = false;
    }
  }

  async function captureInitialRanking() {
    try {
      captureBusy = true;
      captureOk = null;
      captureErr = null;
      const { supabase } = await import('$lib/supabaseClient');
      const { error } = await supabase.rpc('capture_initial_ranking', {
        p_event: null
      });
      if (error) throw error;
      captureOk = 'Rànquing actual desat com a estat inicial';
    } catch (e) {
      captureErr = formatSupabaseError(e);
    } finally {
      captureBusy = false;
    }
  }

  async function resetChampionship() {
    if (!confirm('Segur que vols fer un reset del campionat?')) return;
    try {
      resetBusy = true;
      resetOk = null;
      resetErr = null;
      const { supabase } = await import('$lib/supabaseClient');
      const { data } = await supabase.auth.getSession();
      const token = data?.session?.access_token;
      const res = await fetch('/admin/reset', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: 'Bearer ' + token
        },
        body: JSON.stringify({ clearWaiting })
      });
      const js = await res.json();
      if (!res.ok || !js.ok) throw new Error(js.error || 'Error resetejant campionat');
      resetOk = `Campionat reiniciat (${js.restored})`;
    } catch (e) {
      resetErr = formatSupabaseError(e);
    } finally {
      resetBusy = false;
    }
  }

  async function loadRecent() {
    try {
      histLoading = true;
      histErr = null;
      const { supabase } = await import('$lib/supabaseClient');
      const { data: ev, error: eEv } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .order('creat_el', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (eEv) throw eEv;
      const eventId = ev?.id;
      if (!eventId) return;
      const { data: rows, error: eHist } = await supabase
        .from('history_position_changes')
        .select('creat_el, player_id, posicio_anterior, posicio_nova, motiu')
        .eq('event_id', eventId)
        .order('creat_el', { ascending: false })
        .limit(10);
      if (eHist) throw eHist;
      recent = rows ?? [];
      const ids = Array.from(new Set(recent.map((r) => r.player_id)));
      if (ids.length > 0) {
        const { data: pl, error: ePl } = await supabase
          .from('players')
          .select('id, nom')
          .in('id', ids);
        if (ePl) throw ePl;
        for (const p of pl ?? []) {
          recentPlayers[p.id] = p.nom;
        }
      }
    } catch (e) {
      histErr = formatSupabaseError(e);
    } finally {
      histLoading = false;
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


    <!-- Targeta: historial de moviments -->
    <a href="/admin/historial" class="block rounded-2xl border p-4 hover:shadow-sm">
      <h2 class="font-semibold">🕑 Historial complet</h2>
      <p class="text-sm text-slate-600 mt-1">
        Consulta tots els moviments de posició.
      </p>
    </a>

    <!-- Widget: moviments recents -->
    <div class="rounded-2xl border p-4">
      <h2 class="font-semibold">Moviments recents</h2>
      {#if histErr}
        <Banner type="error" message={histErr} class="mb-2" />
      {/if}
      {#if histLoading}
        <Loader />
      {:else if recent.length > 0}
        <ul class="mt-2 space-y-1 text-sm">
          {#each recent as r}
            <li>
              {new Date(r.creat_el).toLocaleDateString()} ·
              {r.posicio_anterior ?? '—'}→{r.posicio_nova ?? '—'} ·
              {recentPlayers[r.player_id] ?? r.player_id} ·
              {(r.motiu ?? '').slice(0, 30)}
            </li>
          {/each}
        </ul>
      {:else}
        <p class="mt-2 text-sm text-slate-600">Cap moviment</p>
      {/if}

    </div>

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

    <!-- Targeta: inactivitat -->
    <div class="rounded-2xl border p-4">
      <h2 class="font-semibold">😴 Inactivitat</h2>
      <div class="mt-2">
        {#if preOk}
          <Banner type="success" message={preOk} class="mb-2" />
        {/if}
        {#if preErr}
          <Banner type="error" message={preErr} class="mb-2" />
        {/if}
        <button
          class="rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
          on:click={execPreInactivity}
          disabled={preBusy}
        >
          {#if preBusy}Executant…{:else}Executa pre-inactivitat (21 dies){/if}
        </button>
      </div>
      <div class="mt-4">
        {#if inactOk}
          <Banner type="success" message={inactOk} class="mb-2" />
        {/if}
        {#if inactErr}
          <Banner type="error" message={inactErr} class="mb-2" />
        {/if}
        <button
          class="rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
          on:click={execInactivity}
          disabled={inactBusy}
        >
          {#if inactBusy}Executant…{:else}Executa inactivitat (42 dies){/if}
        </button>
      </div>
    </div>

    <!-- Targeta: reset campionat -->
    <div class="rounded-2xl border p-4">
      <h2 class="font-semibold">🧹 Neteja de proves / Reset rànquing</h2>
      {#if captureOk}
        <Banner type="success" message={captureOk} class="mb-2" />
      {/if}
      {#if captureErr}
        <Banner type="error" message={captureErr} class="mb-2" />
      {/if}
      {#if resetOk}
        <Banner type="success" message={resetOk} class="mb-2" />
      {/if}
      {#if resetErr}
        <Banner type="error" message={resetErr} class="mb-2" />
      {/if}
      <div class="mt-2 space-y-2 text-sm">
        <button
          class="rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
          on:click={captureInitialRanking}
          disabled={captureBusy}
        >
          {#if captureBusy}Desant…{:else}Desa rànquing actual com a estat inicial{/if}
        </button>
        <p class="text-xs text-slate-600">
          A partir d’ara, el botó Reset restaurarà aquest estat.
        </p>
        <label class="flex items-center gap-2">
          <input
            type="checkbox"
            bind:checked={clearWaiting}
            class="rounded border"
          />
          Buidar també la llista d’espera
        </label>
        <button
          class="rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
          on:click={resetChampionship}
          disabled={resetBusy}
        >
          {#if resetBusy}Resetant…{:else}Reset campionat{/if}
        </button>
      </div>
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
