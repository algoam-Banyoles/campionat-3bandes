<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/authStore';
  import { checkIsAdmin, adminStore } from '$lib/roles';
  import Banner from '$lib/components/Banner.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';
  import Loader from '$lib/components/Loader.svelte';

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

  type WaitRow = {
    id: string;
    player_id: string;
    nom: string;
    ordre: number;
    data_inscripcio: string;
  };

  let waitRows: WaitRow[] = [];
  let waitBusy = false;
  let waitErr: string | null = null;
  let waitMsg: string | null = null;

  let availablePlayers: { id: string; nom: string }[] = [];
  let selPlayer = '';
  let selOrder: string = '';
  let availBusy = false;
  let availErr: string | null = null;

  async function getToken(): Promise<string | null> {
    const { supabase } = await import('$lib/supabaseClient');
    const { data } = await supabase.auth.getSession();
    return data.session?.access_token ?? null;
  }

  async function loadWaitingList() {
    try {
      waitBusy = true;
      waitErr = null;
      const token = await getToken();
      const res = await fetch('/admin/waiting-list', {
        headers: token ? { authorization: 'Bearer ' + token } : {}
      });
      const js = await res.json();
      if (!res.ok) throw new Error(js.error || 'Error');
      waitRows = js.rows ?? [];
    } catch (e) {
      waitErr = formatSupabaseError(e);
    } finally {
      waitBusy = false;
    }
  }

  async function loadAvailablePlayers() {
    try {
      availBusy = true;
      availErr = null;
      const { supabase } = await import('$lib/supabaseClient');
      const { data: event, error: eErr } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .limit(1)
        .maybeSingle();
      if (eErr) throw eErr;
      if (!event) throw new Error('No hi ha cap event actiu');

      const eventId = event.id;
      const { data: players, error: pErr } = await supabase
        .from('players')
        .select('id, nom')
        .order('nom');
      if (pErr) throw pErr;

      const { data: ranked, error: rErr } = await supabase
        .from('ranking_positions')
        .select('player_id')
        .eq('event_id', eventId);
      if (rErr) throw rErr;
      const { data: waiting, error: wErr } = await supabase
        .from('waiting_list')
        .select('player_id')
        .eq('event_id', eventId);
      if (wErr) throw wErr;

      const exclude = new Set([
        ...(ranked ?? []).map((r: any) => r.player_id),
        ...(waiting ?? []).map((w: any) => w.player_id)
      ]);

      availablePlayers = (players ?? []).filter((p: any) => !exclude.has(p.id));
    } catch (e) {
      availErr = formatSupabaseError(e);
    } finally {
      availBusy = false;
    }
  }

  async function reloadWaiting() {
    await loadWaitingList();
    await loadAvailablePlayers();
  }

  async function addWaiting() {
    try {
      waitErr = null;
      waitMsg = null;
      const token = await getToken();
      const body: any = { player_id: selPlayer };
      if (selOrder) body.ordre = Number(selOrder);
      const res = await fetch('/admin/waiting-list', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: 'Bearer ' + token
        },
        body: JSON.stringify(body)
      });
      const js = await res.json();
      if (!res.ok || !js.ok) throw new Error(js.error || 'Error');
      waitMsg = 'Jugador afegit';
      selPlayer = '';
      selOrder = '';
      await reloadWaiting();
    } catch (e) {
      waitErr = formatSupabaseError(e);
    }
  }

  async function reorder(id: string, dir: 'up' | 'down') {
    try {
      waitErr = null;
      const token = await getToken();
      const res = await fetch('/admin/waiting-list/reorder', {
        method: 'PATCH',
        headers: {
          'content-type': 'application/json',
          authorization: 'Bearer ' + token
        },
        body: JSON.stringify({ id, direction: dir })
      });
      const js = await res.json();
      if (!res.ok || !js.ok) throw new Error(js.error || 'Error');
      await loadWaitingList();
    } catch (e) {
      waitErr = formatSupabaseError(e);
    }
  }

  async function remove(id: string) {
    try {
      waitErr = null;
      waitMsg = null;
      const token = await getToken();
      const res = await fetch(`/admin/waiting-list/${id}`, {
        method: 'DELETE',
        headers: { authorization: 'Bearer ' + token }
      });
      const js = await res.json();
      if (!res.ok || !js.ok) throw new Error(js.error || 'Error');
      waitMsg = 'Entrada eliminada';
      await reloadWaiting();
    } catch (e) {
      waitErr = formatSupabaseError(e);
    }
  }

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
      await reloadWaiting();
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

    <!-- Targeta: llista d'espera -->
    <div class="rounded-2xl border p-4 sm:col-span-2">
      <h2 class="font-semibold">⌚ Llista d’espera</h2>
      {#if waitMsg}
        <Banner type="success" message={waitMsg} class="mb-2" />
      {/if}
      {#if waitErr}
        <Banner type="error" message={waitErr} class="mb-2" />
      {/if}
      {#if waitBusy}
        <Loader />
      {:else if waitRows.length === 0}
        <p class="text-sm text-slate-600">No hi ha entrades.</p>
      {:else}
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm mt-2">
            <thead class="bg-slate-50">
              <tr>
                <th class="px-3 py-2 text-left font-semibold">#</th>
                <th class="px-3 py-2 text-left font-semibold">Jugador</th>
                <th class="px-3 py-2 text-left font-semibold">Ordre</th>
                <th class="px-3 py-2 text-left font-semibold">Accions</th>
              </tr>
            </thead>
            <tbody>
              {#each waitRows as r, i}
                <tr class="border-t">
                  <td class="px-3 py-2">{i + 1}</td>
                  <td class="px-3 py-2">{r.nom}</td>
                  <td class="px-3 py-2">{r.ordre}</td>
                  <td class="px-3 py-2 space-x-1">
                    <button class="text-blue-600" on:click={() => reorder(r.id, 'up')}>↑</button>
                    <button class="text-blue-600" on:click={() => reorder(r.id, 'down')}>↓</button>
                    <button class="text-red-600" on:click={() => remove(r.id)}>✕</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
      <form class="mt-4 space-y-2" on:submit|preventDefault={addWaiting}>
        {#if availErr}
          <Banner type="error" message={availErr} />
        {/if}
        <select
          class="w-full rounded-xl border px-3 py-2"
          bind:value={selPlayer}
          disabled={availBusy}
        >
          <option value="">— Jugador —</option>
          {#each availablePlayers as p}
            <option value={p.id}>{p.nom}</option>
          {/each}
        </select>
        <input
          class="w-full rounded-xl border px-3 py-2"
          type="number"
          placeholder="Ordre"
          bind:value={selOrder}
        />
        <button
          type="submit"
          class="rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
          disabled={!selPlayer}
        >
          Afegir
        </button>
      </form>
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

    <!-- (espai per futures seccions d’admin) -->
    <div class="rounded-2xl border p-4 opacity-70">
      <h2 class="font-semibold">📈 Rànquing / Penes (properament)</h2>
      <p class="text-sm text-slate-600 mt-1">
        Històric de moviments, aplicació de penes i ajustos de posició segons normativa.
      </p>
    </div>
  </div>
{/if}
