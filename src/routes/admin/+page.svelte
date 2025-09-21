<script lang="ts">
    import { onMount } from 'svelte';
    import { goto, invalidateAll, invalidate } from '$app/navigation';
    import { user, adminStore } from '$lib/stores/auth';
    import { checkIsAdmin } from '$lib/roles';
  import Banner from '$lib/components/Banner.svelte';
  import Loader from '$lib/components/Loader.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';
  import { runDeadlines, type RunDeadlinesResult } from '$lib/deadlinesService';
  import { authFetch } from '$lib/utils/http';

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

  let captureBusy = false;
  let captureOk: string | null = null;
  let captureErr: string | null = null;

  let deadlinesBusy = false;
  let deadlinesRes: RunDeadlinesResult | null = null;
  let deadlinesErr: string | null = null;

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
      const res = await authFetch('/reptes/penalitzacions', {
        method: 'POST',
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
      const { data: events, error: eventsError } = await supabase.from('events').select('id');
      if (eventsError) throw eventsError;
      for (const event of events) {
        const { error } = await supabase.rpc('apply_pre_inactivity', {
          p_event: event.id
        });
        if (error) throw error;
      }
      preOk = 'Pre-inactivitat executada per a tots els esdeveniments.';
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
      const { data: events, error: eventsError } = await supabase.from('events').select('id');
      if (eventsError) throw eventsError;
      for (const event of events) {
        const { error } = await supabase.rpc('apply_inactivity', {
          p_event: event.id
        });
        if (error) throw error;
      }
      inactOk = 'Inactivitat executada per a tots els esdeveniments.';
    } catch (e) {
      inactErr = formatSupabaseError(e);
    } finally {
      inactBusy = false;
    }
  }


  async function processDeadlines() {
    try {
      deadlinesBusy = true;
      deadlinesErr = null;
      deadlinesRes = null;
      const { supabase } = await import('$lib/supabaseClient');
      const res = await runDeadlines(supabase, $user?.email ?? null);
      deadlinesRes = res;
      await Promise.all([invalidate('/reptes'), invalidate('/admin/reptes')]);
    } catch (e) {
      deadlinesErr = formatSupabaseError(e);
    } finally {
      deadlinesBusy = false;
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
      // Usar la nova funció admin_reset_championship directament
      const { supabase } = await import('$lib/supabaseClient');
      const { data: result, error } = await supabase.rpc('admin_reset_championship');
      
      if (error) {
        throw new Error(`Error executant el reset: ${error.message}`);
      }
      
      if (result) {
        const evId = result.new_event_id;
        const deleted = result.deleted_records ?? {};
        resetOk = `✅ Reset completat — event: ${evId} — esborrats: ${deleted.challenges || 0} reptes, ${deleted.matches || 0} partides, ${deleted.history_position_changes || 0} històric. Base de dades buida i preparada.`;
      } else {
        resetOk = 'Reset del campionat completat correctament';
      }
      await loadRecent();
      await Promise.all([
        invalidate('/reptes'),
        invalidate('/admin/reptes'),
        invalidate('/ranking'),
        invalidate('/llista-espera'),
        invalidateAll()
      ]);
    } catch (e) {
      resetErr = e instanceof Error ? e.message : formatSupabaseError(e);
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

    <!-- Targeta: crear rànquing inicial -->
    <a href="/admin/ranking-inicial" class="block rounded-2xl border p-4 hover:shadow-sm bg-green-50 border-green-200">
      <h2 class="font-semibold text-green-800">🏆 Crear Rànquing Inicial</h2>
      <p class="text-sm text-green-700 mt-1">
        Configura el rànquing inicial del campionat seleccionant 20 jugadors basant-te en les seves mitjanes històriques.
      </p>
    </a>

    <!-- Targeta: mitjanes històriques -->
    <a href="/admin/mitjanes-historiques" class="block rounded-2xl border p-4 hover:shadow-sm bg-purple-50 border-purple-200">
      <h2 class="font-semibold text-purple-800">📊 Mitjanes Històriques</h2>
      <p class="text-sm text-purple-700 mt-1">
        Visualitza, filtra i gestiona les mitjanes històriques dels jugadors. Assigna mitjanes als socis corresponents.
      </p>
    </a>

    <!-- Targeta: Reset complet del campionat -->
    <a href="/admin/reset-campionat?email={$user?.email || ''}" class="block rounded-2xl border-2 border-red-200 bg-red-50 p-4 hover:shadow-sm">
      <h2 class="font-semibold text-red-800">⚠️ Reset Complet del Campionat</h2>
      <p class="text-sm text-red-700 mt-1">
        <strong>ACCIÓ IRREVERSIBLE:</strong> Esborra totes les dades del campionat actual (reptes, partits, rànquing, historial). 
        Es preserven només els socis i mitjanes històriques. Crea un nou esdeveniment de campionat.
      </p>
      <div class="mt-2 text-xs text-red-600">
        ⚠️ Aquesta acció no es pot desfer. Utilitza amb precaució.
      </div>
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

    <!-- Targeta: terminis reptes -->
    <div class="rounded-2xl border p-4">
      <h2 class="font-semibold">⏰ Terminis reptes</h2>
      {#if deadlinesRes}
        <div class="mt-2 space-y-1 text-sm">
          <p>Reptes processats: <strong>{deadlinesRes.challengesProcessed}</strong></p>
          <p>Inactivitats processades: <strong>{deadlinesRes.inactivityProcessed}</strong></p>
          {#if deadlinesRes.raw.length > 0}
            <details class="text-xs">
              <summary class="cursor-pointer text-slate-600">Detall complet</summary>
              <pre class="mt-1 max-h-48 overflow-auto rounded-xl bg-slate-100 p-2">{JSON.stringify(deadlinesRes.raw, null, 2)}</pre>
            </details>
          {/if}
        </div>
      {/if}
      {#if deadlinesErr}
        <Banner type="error" message={deadlinesErr} class="mb-2" />
      {/if}
      <button
        class="mt-2 rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
        on:click={processDeadlines}
        disabled={deadlinesBusy}
      >
        {#if deadlinesBusy}Processant…{:else}Processar terminis{/if}
      </button>
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
