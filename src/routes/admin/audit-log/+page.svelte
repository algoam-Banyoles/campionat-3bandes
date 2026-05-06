<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { initAdminPage } from '$lib/utils/adminPage';
  import {
    getAuditLog,
    getAuditLogActors,
    actionLabel,
    actionSeverity,
    type AuditLogEntry
  } from '$lib/api/auditLog';

  let loading = true;
  let error: string | null = null;
  let entries: AuditLogEntry[] = [];
  let actors: string[] = [];
  let events: Array<{ id: string; nom: string; temporada: string }> = [];

  // Filtres
  let filterEventId = '';
  let filterActor = '';
  let filterEntity: '' | 'inscripcio' | 'event' = '';
  let filterFromDate = '';
  let filterToDate = '';
  let filterLimit = 200;

  // Detall expandit
  let expandedId: string | null = null;

  onMount(async () => {
    const result = await initAdminPage(
      async () => {
        await loadFiltersData();
        await refresh();
      },
      { redirectIfNoSession: '/login' }
    );
    if (result.error) error = result.error;
  });

  async function loadFiltersData() {
    try {
      const [actorsList, eventsRes] = await Promise.all([
        getAuditLogActors(),
        supabase
          .from('events')
          .select('id, nom, temporada')
          .eq('tipus_competicio', 'lliga_social')
          .order('temporada', { ascending: false })
      ]);
      actors = actorsList;
      events = (eventsRes.data || []) as any[];
    } catch (e) {
      console.error(e);
    }
  }

  async function refresh() {
    loading = true;
    error = null;
    try {
      entries = await getAuditLog({
        eventId: filterEventId || undefined,
        actorEmail: filterActor || undefined,
        entityType: filterEntity || undefined,
        fromDate: filterFromDate ? new Date(filterFromDate).toISOString() : undefined,
        toDate: filterToDate ? new Date(filterToDate + 'T23:59:59').toISOString() : undefined,
        limit: filterLimit
      });
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }

  function formatDateTime(iso: string): string {
    return new Date(iso).toLocaleString('ca-ES', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function severityClasses(action: string): string {
    const sev = actionSeverity(action);
    return sev === 'danger'
      ? 'bg-red-100 text-red-800'
      : sev === 'success'
      ? 'bg-green-100 text-green-800'
      : sev === 'warning'
      ? 'bg-orange-100 text-orange-800'
      : 'bg-blue-100 text-blue-800';
  }

  function clearFilters() {
    filterEventId = '';
    filterActor = '';
    filterEntity = '';
    filterFromDate = '';
    filterToDate = '';
    filterLimit = 200;
    refresh();
  }

  function toggleExpand(id: string) {
    expandedId = expandedId === id ? null : id;
  }

  $: eventNameById = new Map(events.map(e => [e.id, `${e.nom} (${e.temporada})`]));
</script>

<svelte:head>
  <title>Registre d'auditoria</title>
</svelte:head>

<div class="al-root">
  <header class="al-mast">
    <div class="editorial-eyebrow">Rànquing continu · Traçabilitat</div>
    <h1 class="al-title">Registre d'auditoria</h1>
    <p class="al-sub">
      Historial de canvis significatius sobre inscripcions, reptes i estats dels jugadors.
    </p>
  </header>

  <!-- Filtres -->
  <div class="bg-white border border-gray-200 rounded-lg p-4 mb-4">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div>
        <label for="filter-event" class="block text-xs font-medium text-gray-700 mb-1">Campionat</label>
        <select
          id="filter-event"
          bind:value={filterEventId}
          class="w-full text-sm border border-gray-300 rounded px-2 py-1.5"
        >
          <option value="">Tots</option>
          {#each events as e (e.id)}
            <option value={e.id}>{e.nom} ({e.temporada})</option>
          {/each}
        </select>
      </div>

      <div>
        <label for="filter-actor" class="block text-xs font-medium text-gray-700 mb-1">Admin</label>
        <select
          id="filter-actor"
          bind:value={filterActor}
          class="w-full text-sm border border-gray-300 rounded px-2 py-1.5"
        >
          <option value="">Tots</option>
          {#each actors as a (a)}
            <option value={a}>{a}</option>
          {/each}
        </select>
      </div>

      <div>
        <label for="filter-entity" class="block text-xs font-medium text-gray-700 mb-1">Tipus</label>
        <select
          id="filter-entity"
          bind:value={filterEntity}
          class="w-full text-sm border border-gray-300 rounded px-2 py-1.5"
        >
          <option value="">Tots</option>
          <option value="inscripcio">Inscripcions</option>
          <option value="event">Campionats</option>
        </select>
      </div>

      <div>
        <label for="filter-from" class="block text-xs font-medium text-gray-700 mb-1">Des de</label>
        <input
          id="filter-from"
          type="date"
          bind:value={filterFromDate}
          class="w-full text-sm border border-gray-300 rounded px-2 py-1.5"
        />
      </div>

      <div>
        <label for="filter-to" class="block text-xs font-medium text-gray-700 mb-1">Fins a</label>
        <input
          id="filter-to"
          type="date"
          bind:value={filterToDate}
          class="w-full text-sm border border-gray-300 rounded px-2 py-1.5"
        />
      </div>

      <div>
        <label for="filter-limit" class="block text-xs font-medium text-gray-700 mb-1">Límit</label>
        <select
          id="filter-limit"
          bind:value={filterLimit}
          class="w-full text-sm border border-gray-300 rounded px-2 py-1.5"
        >
          <option value={50}>50</option>
          <option value={200}>200</option>
          <option value={500}>500</option>
          <option value={1000}>1000</option>
        </select>
      </div>
    </div>

    <div class="mt-3 flex justify-end gap-2">
      <button
        type="button"
        on:click={clearFilters}
        class="px-3 py-1.5 text-sm bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
      >
        Netejar
      </button>
      <button
        type="button"
        on:click={refresh}
        disabled={loading}
        class="px-3 py-1.5 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
      >
        Aplicar filtres
      </button>
    </div>
  </div>

  <!-- Resultats -->
  {#if error}
    <Banner type="error" message={error} />
  {/if}

  {#if loading}
    <Loader />
  {:else if entries.length === 0}
    <div class="bg-white border border-gray-200 rounded-lg p-12 text-center text-gray-500">
      <p>No hi ha entrades amb els filtres aplicats.</p>
    </div>
  {:else}
    <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div class="px-4 py-2 border-b border-gray-200 bg-gray-50 text-xs text-gray-600">
        {entries.length} entrades
      </div>
      <ul class="divide-y divide-gray-100">
        {#each entries as entry (entry.id)}
          <li class="px-4 py-3 hover:bg-gray-50">
            <div class="flex items-center justify-between gap-3">
              <div class="flex-1 min-w-0">
                <div class="flex flex-wrap items-center gap-2 mb-1">
                  <span class="text-xs px-2 py-0.5 rounded font-semibold {severityClasses(entry.action)}">
                    {actionLabel(entry.action)}
                  </span>
                  {#if entry.event_id && eventNameById.has(entry.event_id)}
                    <span class="text-xs text-gray-500">{eventNameById.get(entry.event_id)}</span>
                  {/if}
                </div>
                <div class="text-sm text-gray-900">
                  <span class="font-medium">{entry.actor_email ?? 'Sistema'}</span>
                  <span class="text-gray-500"> · {formatDateTime(entry.created_at)}</span>
                </div>
              </div>
              <button
                type="button"
                on:click={() => toggleExpand(entry.id)}
                class="text-xs text-blue-600 hover:text-blue-900 flex-shrink-0"
              >
                {expandedId === entry.id ? 'Amaga detalls' : 'Detalls'}
              </button>
            </div>

            {#if expandedId === entry.id}
              <div class="mt-3 grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
                <div>
                  <div class="font-semibold text-gray-700 mb-1">Abans</div>
                  <pre class="bg-gray-50 border border-gray-200 rounded p-2 overflow-x-auto">{JSON.stringify(entry.before_data, null, 2)}</pre>
                </div>
                <div>
                  <div class="font-semibold text-gray-700 mb-1">Després</div>
                  <pre class="bg-gray-50 border border-gray-200 rounded p-2 overflow-x-auto">{JSON.stringify(entry.after_data, null, 2)}</pre>
                </div>
              </div>
              <div class="mt-2 text-xs text-gray-500">
                ID: <code>{entry.id}</code> · Entitat: {entry.entity_type} <code>{entry.entity_id}</code>
              </div>
            {/if}
          </li>
        {/each}
      </ul>
    </div>
  {/if}
</div>

<style>
  .al-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .al-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .al-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .al-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }

  .al-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .al-root :global(.bg-gray-50),
  .al-root :global(.bg-gray-100),
  .al-root :global(.bg-slate-50) { background: var(--paper, #fbfaf6) !important; }
  .al-root :global(.bg-blue-50),
  .al-root :global(.bg-blue-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--blue, #1f4a99) !important; }
  .al-root :global(.bg-green-50),
  .al-root :global(.bg-green-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--green, #1f7a3a) !important; }
  .al-root :global(.bg-yellow-50),
  .al-root :global(.bg-yellow-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--amber, #b8860b) !important; }
  .al-root :global(.bg-red-50),
  .al-root :global(.bg-red-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--accent, #a30b1e) !important; }
  .al-root :global(.bg-blue-600),
  .al-root :global(.bg-blue-700) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .al-root :global(.text-gray-500),
  .al-root :global(.text-gray-600),
  .al-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
  .al-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
  .al-root :global(.text-blue-700),
  .al-root :global(.text-blue-800) { color: var(--blue, #1f4a99) !important; }
  .al-root :global(.text-green-700),
  .al-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
  .al-root :global(.text-yellow-700),
  .al-root :global(.text-yellow-800) { color: var(--amber, #b8860b) !important; }
  .al-root :global(.text-red-700),
  .al-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
  .al-root :global(.border-gray-200),
  .al-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
  .al-root :global(.rounded),
  .al-root :global(.rounded-md),
  .al-root :global(.rounded-lg),
  .al-root :global(.rounded-xl),
  .al-root :global(.rounded-full) { border-radius: 0 !important; }
  .al-root :global(.shadow),
  .al-root :global(.shadow-sm),
  .al-root :global(.shadow-md) { box-shadow: none !important; }
  .al-root :global(input),
  .al-root :global(select),
  .al-root :global(textarea) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .al-root :global(table) { font-family: var(--font-sans, sans-serif); }
</style>
