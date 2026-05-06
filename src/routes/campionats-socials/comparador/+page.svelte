<script lang="ts">
  import { searchActivePlayers, getHeadToHeadHistory } from '$lib/api/socialLeagues';
  import type { HeadToHeadHistorySummary } from '$lib/api/socialLeagues';
  import { debounce } from 'lodash-es';
  import { showError } from '$lib/stores/toastStore';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  type Player = Awaited<ReturnType<typeof searchActivePlayers>>[number];

  let player1: Player | null = null;
  let player2: Player | null = null;
  let history: HeadToHeadHistorySummary | null = null;
  let loadingHistory = false;

  // Estats independents per a cada cercador
  let search1 = '';
  let search2 = '';
  let results1: Player[] = [];
  let results2: Player[] = [];
  let loading1 = false;
  let loading2 = false;

  function debounceSearch(side: 1 | 2) {
    return debounce(async (term: string) => {
      const setLoading = side === 1 ? (v: boolean) => (loading1 = v) : (v: boolean) => (loading2 = v);
      const setResults = side === 1 ? (r: Player[]) => (results1 = r) : (r: Player[]) => (results2 = r);
      if (term.length < 3) {
        setResults([]);
        return;
      }
      setLoading(true);
      try {
        const res = await searchActivePlayers(term);
        // Excloure el jugador ja seleccionat a l'altra columna
        const otherSelected = side === 1 ? player2 : player1;
        setResults(otherSelected ? res.filter(p => p.numero_soci !== otherSelected.numero_soci) : res);
      } catch (e) {
        console.error(e);
        showError('Error cercant jugadors');
      } finally {
        setLoading(false);
      }
    }, 300);
  }

  const debouncedSearch1 = debounceSearch(1);
  const debouncedSearch2 = debounceSearch(2);

  $: debouncedSearch1(search1);
  $: debouncedSearch2(search2);

  function selectPlayer(side: 1 | 2, p: Player) {
    if (side === 1) {
      player1 = p;
      search1 = `${p.nom} ${p.cognoms}`;
      results1 = [];
    } else {
      player2 = p;
      search2 = `${p.nom} ${p.cognoms}`;
      results2 = [];
    }
  }

  function clearPlayer(side: 1 | 2) {
    if (side === 1) {
      player1 = null;
      search1 = '';
      results1 = [];
    } else {
      player2 = null;
      search2 = '';
      results2 = [];
    }
    history = null;
  }

  function swapPlayers() {
    const p = player1;
    const s = search1;
    player1 = player2;
    search1 = search2;
    player2 = p;
    search2 = s;
  }

  async function loadHistory() {
    if (!player1 || !player2) return;
    loadingHistory = true;
    try {
      history = await getHeadToHeadHistory(player1.numero_soci, player2.numero_soci);
    } catch (e) {
      console.error(e);
      showError('Error carregant l\'historial');
      history = null;
    } finally {
      loadingHistory = false;
    }
  }

  $: if (player1 && player2) {
    loadHistory();
  }

  function formatDate(d: string | null): string {
    if (!d) return '-';
    return new Date(d).toLocaleDateString('ca-ES', { day: 'numeric', month: 'short', year: 'numeric' });
  }

  function modalitatLabel(m: string | null): string {
    if (!m) return '';
    const map: Record<string, string> = { '3 BANDES': '3 Bandes', LLIURE: 'Lliure', BANDA: 'Banda' };
    return map[m] || m;
  }

  $: player1Mitjana = (() => {
    if (!history || history.totalEntrades === 0) return null;
    return history.player1TotalCaramboles / history.totalEntrades;
  })();
  $: player2Mitjana = (() => {
    if (!history || history.totalEntrades === 0) return null;
    return history.player2TotalCaramboles / history.totalEntrades;
  })();
</script>

<svelte:head>
  <title>Comparador de jugadors</title>
</svelte:head>

<div class="cmp-root">
  <header class="cmp-mast">
    <div class="editorial-eyebrow">Campionats socials · Anàlisi</div>
    <h1 class="cmp-title">Comparador de jugadors</h1>
    <p class="cmp-sub">Selecciona dos jugadors per veure el seu històric d'enfrontaments directes.</p>
  </header>

  <!-- Selectors -->
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6 relative">
    {#each [1, 2] as side (side)}
      {@const player = side === 1 ? player1 : player2}
      {@const search = side === 1 ? search1 : search2}
      {@const results = side === 1 ? results1 : results2}
      {@const loading = side === 1 ? loading1 : loading2}
      <div class="bg-white border border-gray-200 rounded-lg p-4">
        <h2 class="text-sm font-semibold text-gray-700 mb-3">Jugador {side}</h2>

        {#if player}
          <div class="flex items-center justify-between bg-blue-50 border border-blue-200 rounded p-3">
            <div>
              <div class="font-semibold text-gray-900">{formatarNomJugador(`${player.nom ?? ''} ${player.cognoms ?? ''}`.trim())}</div>
            </div>
            <button
              type="button"
              on:click={() => clearPlayer(side as 1 | 2)}
              class="text-gray-400 hover:text-gray-700"
              aria-label="Canviar jugador"
              title="Canviar jugador"
            >
              ✕
            </button>
          </div>
        {:else}
          <div class="relative">
            <input
              type="text"
              placeholder="Escriu nom o cognoms..."
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              value={search}
              on:input={(e) => {
                const v = (e.target as HTMLInputElement).value;
                if (side === 1) search1 = v;
                else search2 = v;
              }}
            />
            {#if loading}
              <div class="absolute right-2 top-1/2 -translate-y-1/2">
                <div class="animate-spin h-4 w-4 border-b-2 border-blue-600 rounded-full"></div>
              </div>
            {/if}
            {#if results.length > 0}
              <div class="absolute z-10 left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg max-h-60 overflow-y-auto">
                {#each results as r (r.numero_soci)}
                  <button
                    type="button"
                    on:click={() => selectPlayer(side as 1 | 2, r)}
                    class="w-full text-left px-3 py-2 hover:bg-blue-50 border-b border-gray-100 last:border-b-0"
                  >
                    <div class="text-sm font-medium text-gray-900">{formatarNomJugador(`${r.nom ?? ''} ${r.cognoms ?? ''}`.trim())}</div>
                  </button>
                {/each}
              </div>
            {:else if search.length >= 3 && !loading}
              <p class="mt-2 text-xs text-gray-500">Cap jugador trobat</p>
            {:else if search.length > 0 && search.length < 3}
              <p class="mt-2 text-xs text-gray-500">Escriu almenys 3 caràcters</p>
            {/if}
          </div>
        {/if}
      </div>
    {/each}

    <!-- Botó intercanvi -->
    {#if player1 || player2}
      <button
        type="button"
        on:click={swapPlayers}
        class="hidden md:flex absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-20 w-10 h-10 items-center justify-center bg-white border-2 border-gray-300 rounded-full shadow text-gray-600 hover:bg-gray-50 hover:border-gray-400"
        title="Intercanviar jugadors"
        aria-label="Intercanviar jugadors"
      >
        ↔
      </button>
    {/if}
  </div>

  <!-- Resultats -->
  {#if !player1 || !player2}
    <div class="bg-white border border-gray-200 rounded-lg p-12 text-center">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M9 20H4v-2a3 3 0 015.356-1.857M9 12a4 4 0 110-8 4 4 0 010 8zm6 8a3 3 0 100-6 3 3 0 000 6z"/>
      </svg>
      <h3 class="mt-3 text-base font-medium text-gray-900">Selecciona dos jugadors</h3>
      <p class="mt-1 text-sm text-gray-500">Cerca i tria un jugador a cada columna per veure els seus enfrontaments.</p>
    </div>
  {:else if loadingHistory}
    <div class="bg-white border border-gray-200 rounded-lg p-12 text-center">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-3 text-sm text-gray-600">Carregant historial...</p>
    </div>
  {:else if history && history.matches.length === 0}
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-8 text-center">
      <p class="text-base text-yellow-900">
        <a href={`/jugador/${player1.numero_soci}`} class="player-link"><strong>{formatarNomJugador(`${player1.nom ?? ''} ${player1.cognoms ?? ''}`.trim())}</strong></a>
        i
        <a href={`/jugador/${player2.numero_soci}`} class="player-link"><strong>{formatarNomJugador(`${player2.nom ?? ''} ${player2.cognoms ?? ''}`.trim())}</strong></a>
        encara no s'han enfrontat directament en cap campionat.
      </p>
    </div>
  {:else if history}
    <!-- Resum -->
    <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Resum d'enfrontaments</h2>
      <div class="grid grid-cols-3 gap-4">
        <!-- Player 1 wins -->
        <div class="text-center p-4 rounded-lg bg-blue-50 border border-blue-200">
          <div class="text-3xl font-bold text-blue-700">{history.player1Wins}</div>
          <a href={`/jugador/${player1.numero_soci}`} class="text-xs text-gray-600 mt-1 font-medium uppercase player-link block">{formatarNomJugador(`${player1.nom ?? ''} ${player1.cognoms ?? ''}`.trim())}</a>
          <div class="text-xs text-gray-500 mt-1">victòries</div>
        </div>
        <!-- Draws -->
        <div class="text-center p-4 rounded-lg bg-gray-50 border border-gray-200">
          <div class="text-3xl font-bold text-gray-700">{history.draws}</div>
          <div class="text-xs text-gray-600 mt-1 font-medium uppercase">Empats</div>
          <div class="text-xs text-gray-500 mt-1">{history.matches.length} totals</div>
        </div>
        <!-- Player 2 wins -->
        <div class="text-center p-4 rounded-lg bg-purple-50 border border-purple-200">
          <div class="text-3xl font-bold text-purple-700">{history.player2Wins}</div>
          <a href={`/jugador/${player2.numero_soci}`} class="text-xs text-gray-600 mt-1 font-medium uppercase player-link block">{formatarNomJugador(`${player2.nom ?? ''} ${player2.cognoms ?? ''}`.trim())}</a>
          <div class="text-xs text-gray-500 mt-1">victòries</div>
        </div>
      </div>

      <!-- Caramboles + mitjana acumulada -->
      <div class="grid grid-cols-2 gap-4 mt-4 pt-4 border-t border-gray-200">
        <div class="text-center">
          <div class="text-xs text-gray-500 uppercase mb-1">Caramboles totals</div>
          <div class="text-2xl font-bold text-blue-700">{history.player1TotalCaramboles}</div>
          {#if player1Mitjana != null}
            <div class="text-xs text-gray-500 mt-1">Mitjana: <strong>{player1Mitjana.toFixed(3)}</strong></div>
          {/if}
        </div>
        <div class="text-center">
          <div class="text-xs text-gray-500 uppercase mb-1">Caramboles totals</div>
          <div class="text-2xl font-bold text-purple-700">{history.player2TotalCaramboles}</div>
          {#if player2Mitjana != null}
            <div class="text-xs text-gray-500 mt-1">Mitjana: <strong>{player2Mitjana.toFixed(3)}</strong></div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Llista de partides -->
    <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-200">
        <h2 class="text-lg font-semibold text-gray-900">Partides ({history.matches.length})</h2>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Data</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Campionat</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Categoria</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">{formatarNomJugador(`${player1.nom ?? ''} ${player1.cognoms ?? ''}`.trim())}</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">{formatarNomJugador(`${player2.nom ?? ''} ${player2.cognoms ?? ''}`.trim())}</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Entr.</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each history.matches as m (m.id)}
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-700">{formatDate(m.data_joc ?? m.data_programada)}</td>
                <td class="px-4 py-3 text-sm text-gray-900">
                  <div class="font-medium">{m.event_nom ?? '—'}</div>
                  {#if m.event_temporada || m.event_modalitat}
                    <div class="text-xs text-gray-500">
                      {m.event_temporada ?? ''} {m.event_modalitat ? '· ' + modalitatLabel(m.event_modalitat) : ''}
                    </div>
                  {/if}
                </td>
                <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-700">{m.categoria_nom ?? '—'}</td>
                <td class="px-4 py-3 whitespace-nowrap text-sm text-center">
                  <span
                    class="inline-block min-w-[2.5rem] px-2 py-1 rounded font-semibold"
                    class:bg-blue-100={m.winner === 1}
                    class:text-blue-900={m.winner === 1}
                    class:bg-gray-100={m.winner === 0}
                    class:text-gray-700={m.winner === 0}
                    class:text-gray-500={m.winner === 2}
                  >
                    {m.caramboles_player1}
                  </span>
                </td>
                <td class="px-4 py-3 whitespace-nowrap text-sm text-center">
                  <span
                    class="inline-block min-w-[2.5rem] px-2 py-1 rounded font-semibold"
                    class:bg-purple-100={m.winner === 2}
                    class:text-purple-900={m.winner === 2}
                    class:bg-gray-100={m.winner === 0}
                    class:text-gray-700={m.winner === 0}
                    class:text-gray-500={m.winner === 1}
                  >
                    {m.caramboles_player2}
                  </span>
                </td>
                <td class="px-4 py-3 whitespace-nowrap text-sm text-center text-gray-700">{m.entrades ?? '-'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  {/if}
</div>

<style>
  .cmp-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .cmp-mast {
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
  .cmp-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .cmp-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }

  .cmp-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .cmp-root :global(.bg-gray-50),
  .cmp-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .cmp-root :global(.bg-blue-50),
  .cmp-root :global(.bg-blue-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--blue, #1f4a99) !important; }
  .cmp-root :global(.bg-green-50),
  .cmp-root :global(.bg-green-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--green, #1f7a3a) !important; }
  .cmp-root :global(.bg-yellow-50),
  .cmp-root :global(.bg-yellow-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--amber, #b8860b) !important; }
  .cmp-root :global(.bg-blue-600),
  .cmp-root :global(.bg-blue-700) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .cmp-root :global(.text-gray-500),
  .cmp-root :global(.text-gray-600),
  .cmp-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
  .cmp-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
  .cmp-root :global(.text-blue-600),
  .cmp-root :global(.text-blue-700),
  .cmp-root :global(.text-blue-800) { color: var(--blue, #1f4a99) !important; }
  .cmp-root :global(.text-green-600),
  .cmp-root :global(.text-green-700),
  .cmp-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
  .cmp-root :global(.text-red-600),
  .cmp-root :global(.text-red-700),
  .cmp-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
  .cmp-root :global(.border-gray-200),
  .cmp-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
  .cmp-root :global(.rounded),
  .cmp-root :global(.rounded-md),
  .cmp-root :global(.rounded-lg),
  .cmp-root :global(.rounded-xl),
  .cmp-root :global(.rounded-2xl),
  .cmp-root :global(.rounded-full) { border-radius: 0 !important; }
  .cmp-root :global(.shadow),
  .cmp-root :global(.shadow-sm),
  .cmp-root :global(.shadow-md),
  .cmp-root :global(.shadow-lg) { box-shadow: none !important; }
  .cmp-root :global(input),
  .cmp-root :global(select) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .cmp-root :global(input:focus),
  .cmp-root :global(select:focus) {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
  .cmp-root :global(table) { font-family: var(--font-sans, sans-serif); }
  .cmp-root :global(thead.bg-gray-50) {
    background: var(--paper, #fbfaf6) !important;
    border-bottom: 1px solid var(--ink, #1a1814) !important;
  }

  /* Aplica formatarNomJugador inline al display de noms quan no s'usa el helper */
  .cmp-root :global(button) { font-family: var(--font-sans, sans-serif); }

  /* Enllaços a perfil de jugador (clicant un nom va a /jugador/[numero_soci]) */
  .cmp-root :global(.player-link) {
    color: inherit;
    text-decoration: none;
    border-bottom: 1px solid currentColor;
    transition: color 0.15s ease;
  }
  .cmp-root :global(.player-link:hover) {
    color: var(--accent, #a30b1e);
  }
</style>
