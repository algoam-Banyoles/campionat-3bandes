<script lang="ts">
  import { onMount } from 'svelte';
  import { getHeadToHeadResults } from '$lib/api/socialLeagues';

  export let eventId: string;
  export let categoriaId: string;
  export let categoriaNom: string = '';

  let loading = false;
  let error: string | null = null;
  let players: Array<{
    id: string;
    nom: string;
    cognoms: string | null;
    numero_soci: number;
  }> = [];
  let matches: Map<string, {
    caramboles: number;
    entrades: number;
    punts: number;
    mitjana: number;
  }> = new Map();

  onMount(() => {
    loadHeadToHeadData();
  });

  // Recarregar dades quan canviï la categoria
  $: if (categoriaId) {
    loadHeadToHeadData();
  }

  async function loadHeadToHeadData() {
    if (!eventId || !categoriaId) return;

    loading = true;
    error = null;

    try {
      const data = await getHeadToHeadResults(eventId, categoriaId);
      players = data.players;
      matches = data.matches;
    } catch (err) {
      console.error('Error loading head-to-head data:', err);
      error = 'Error carregant les dades de la graella';
    } finally {
      loading = false;
    }
  }

  function getMatchData(playerId: string, opponentId: string) {
    const key = `${playerId}_${opponentId}`;
    return matches.get(key);
  }

  /**
   * Suma de caramboles, entrades i punts del jugador contra tots els oponents.
   * Mitjana = caramboles totals / entrades totals.
   */
  function getPlayerTotals(playerId: string) {
    let car = 0, ent = 0, pts = 0, played = 0;
    for (const opp of players) {
      if (opp.id === playerId) continue;
      const data = matches.get(`${playerId}_${opp.id}`);
      if (data) {
        car += data.caramboles ?? 0;
        ent += data.entrades ?? 0;
        pts += data.punts ?? 0;
        played++;
      }
    }
    const mit = ent > 0 ? car / ent : 0;
    return { car, ent, pts, mit, played };
  }

  function getPlayerShortName(player: any): string {
    // Get all initials from compound names (e.g., "Jose Maria" -> "J.M.")
    const inicials = player.nom
      ? player.nom.split(' ')
          .filter((part: string) => part.length > 0)
          .map((part: string) => part.charAt(0).toUpperCase() + '.')
          .join('')
      : '';
    const primerCognom = player.cognoms ? player.cognoms.split(' ')[0] : '';
    return `${inicials} ${primerCognom}`.trim();
  }

  function getPlayerFullName(player: any): string {
    return `${player.nom} ${player.cognoms || ''}`.trim();
  }

  function sortPlayersByLastName(players: Array<any>): Array<any> {
    return [...players].sort((a, b) => {
      const lastNameA = a.cognoms ? a.cognoms.split(' ')[0].toLowerCase() : '';
      const lastNameB = b.cognoms ? b.cognoms.split(' ')[0].toLowerCase() : '';
      return lastNameA.localeCompare(lastNameB, 'ca');
    });
  }

  $: sortedPlayers = sortPlayersByLastName(players);
</script>

<div class="head-to-head-container">
  <div class="grid-head no-print">
    <div>
      <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Graella de resultats</div>
      <h2 class="title">{categoriaNom || 'Categoria'}</h2>
    </div>
  </div>

  {#if loading}
    <div class="state-empty">Carregant graella de resultats…</div>
  {:else if error}
    <div class="state-empty error-state">
      <p>{error}</p>
      <button on:click={loadHeadToHeadData}>Tornar a intentar</button>
    </div>
  {:else if players.length === 0}
    <div class="state-empty">No hi ha jugadors inscrits en aquesta categoria.</div>
  {:else}
    <div class="grid-wrapper">
      <div class="grid-scroll">
        <table class="head-to-head-grid">
          <thead>
            <tr>
              <th class="player-header corner">Jugadors</th>
              {#each sortedPlayers as opponent}
                <th class="player-header opponent-name" title={getPlayerFullName(opponent)}>
                  <div class="opponent-name-vertical">
                    {getPlayerShortName(opponent)}
                  </div>
                </th>
              {/each}
              <th class="player-header total-header">
                <div class="total-header-text">Totals</div>
              </th>
            </tr>
          </thead>
          <tbody>
            {#each sortedPlayers as player}
              {@const totals = getPlayerTotals(player.id)}
              <tr>
                <th class="player-name" title={getPlayerFullName(player)}>
                  {#if player.numero_soci}
                    <a href={`/jugador/${player.numero_soci}`} class="h2h-player-link">{getPlayerShortName(player)}</a>
                  {:else}
                    {getPlayerShortName(player)}
                  {/if}
                </th>
                {#each sortedPlayers as opponent}
                  <td class="match-cell" class:self={player.id === opponent.id} class:empty={player.id !== opponent.id && !getMatchData(player.id, opponent.id)}>
                    {#if player.id === opponent.id}
                      <div class="self-match" aria-hidden="true"></div>
                    {:else}
                      {@const matchData = getMatchData(player.id, opponent.id)}
                      <div class="match-grid">
                        <div class="cell top-left car" class:win={matchData && matchData.punts === 2} class:lose={matchData && matchData.punts === 0}>
                          {matchData?.caramboles ?? ''}
                        </div>
                        <div class="cell top-right ent">
                          {matchData?.entrades ?? ''}
                        </div>
                        <div class="cell middle pts">
                          {matchData?.punts ?? ''}
                        </div>
                        <div class="cell bottom mit">
                          {matchData && matchData.entrades > 0 ? matchData.mitjana.toFixed(3) : ''}
                        </div>
                      </div>
                    {/if}
                  </td>
                {/each}
                <!-- Columna de totals del jugador (suma de tots els oponents) -->
                <td class="match-cell totals-cell">
                  <div class="match-grid">
                    <div class="cell top-left car">{totals.played > 0 ? totals.car : ''}</div>
                    <div class="cell top-right ent">{totals.played > 0 ? totals.ent : ''}</div>
                    <div class="cell middle pts">{totals.played > 0 ? totals.pts : ''}</div>
                    <div class="cell bottom mit">{totals.ent > 0 ? totals.mit.toFixed(3) : ''}</div>
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>

    <div class="legend">
      <div class="legend-grid">
        <div class="legend-cell">
          <table class="legend-table">
            <tbody>
              <tr>
                <td class="legend-cell-inner">
                  <div class="match-grid">
                    <div class="cell top-left car win">50</div>
                    <div class="cell top-right ent">28</div>
                    <div class="cell middle pts">2</div>
                    <div class="cell bottom mit">1,786</div>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="legend-text">
          <div class="legend-rows">
            <div><span class="legend-pos">Fila 1</span> caramboles del jugador (verd = victòria, vermell = derrota) · entrades</div>
            <div><span class="legend-pos">Fila 2</span> punts (2 = victòria, 1 = empat, 0 = derrota)</div>
            <div><span class="legend-pos">Fila 3</span> mitjana (caramboles / entrades)</div>
          </div>
          <p class="legend-note">
            Cada cel·la mostra les dades del jugador de la <strong>fila</strong> contra el de la columna.
            Les cel·les buides (sense fons) corresponen a partides pendents — la graella es manté dibuixada per omplir-la a mà.
            Optimitzada per imprimir.
          </p>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .head-to-head-container {
    width: 100%;
    background: var(--paper-elevated);
    color: var(--ink);
    font-family: var(--font-sans);
  }

  /* ── Capçalera ─────────────────────────────────────── */
  .grid-head {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    gap: 1rem;
    margin-bottom: 1.25rem;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid var(--ink);
  }
  .title {
    font-weight: 800;
    font-size: 1.75rem;
    line-height: 1.1;
    letter-spacing: -0.025em;
    color: var(--ink);
    margin: 0;
    font-variation-settings: 'opsz' 32;
  }
  .editorial-eyebrow {
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .print-btn {
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
    padding: 0.5rem 1rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 44px;
  }
  .print-btn:hover {
    opacity: 0.92;
  }

  /* ── Estats ─────────────────────────────────────────── */
  .state-empty {
    padding: 1.5rem 1.75rem;
    background: var(--paper);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    font-size: 0.9375rem;
  }
  .error-state button {
    margin-top: 0.75rem;
    padding: 0.55rem 1rem;
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
    font-family: var(--font-sans);
    font-weight: 600;
    cursor: pointer;
  }

  /* ── Graella ────────────────────────────────────────── */
  .grid-wrapper {
    overflow-x: auto;
    border: 1px solid var(--rule);
    background: var(--paper-elevated);
    margin-bottom: 1.25rem;
  }
  .grid-scroll {
    min-width: 100%;
  }
  .head-to-head-grid {
    border-collapse: collapse;
    width: 100%;
  }
  .head-to-head-grid th,
  .head-to-head-grid td {
    border: 1px solid var(--rule);
    text-align: center;
  }

  /* Headers (fila superior — noms d'oponents en diagonal) */
  .player-header {
    background: var(--paper);
    color: var(--ink);
    font-weight: 600;
    font-size: 0.6875rem;
    letter-spacing: 0.04em;
    position: sticky;
    top: 0;
    z-index: 10;
  }
  .player-header.corner {
    position: sticky;
    left: 0;
    z-index: 20;
    background: var(--paper);
  }
  .opponent-name {
    min-width: 5.5rem;
    max-width: 5.5rem;
    height: 7rem;
    position: relative;
    padding: 0;
  }
  .opponent-name-vertical {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%) rotate(-45deg);
    transform-origin: center;
    white-space: nowrap;
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ink);
    width: 7.5rem;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Cel·les esquerra (noms de jugadors fila) */
  .player-name {
    background: var(--paper);
    font-weight: 600;
    font-size: 0.8125rem;
    color: var(--ink);
    text-align: left;
    padding: 0.6rem 0.875rem;
    position: sticky;
    left: 0;
    z-index: 5;
    min-width: 7.5rem;
    max-width: 7.5rem;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    letter-spacing: -0.012em;
  }

  /* Cel·les de partida (3-row grid) */
  .match-cell {
    min-width: 5.5rem;
    max-width: 5.5rem;
    padding: 0;
    vertical-align: middle;
    background: var(--paper-elevated);
    font-feature-settings: 'tnum' 1, 'lnum' 1;
  }
  /* Cel·la de totals: fons subtil i borde esquerre reforçat per separar-la */
  .match-cell.totals-cell {
    background: var(--paper);
    border-left: 2px solid var(--ink) !important;
  }
  .match-cell.totals-cell .cell {
    font-weight: 700;
  }
  .match-cell.totals-cell .cell.top-left.car {
    color: var(--ink);
  }
  /* Header de la columna de totals */
  .player-header.total-header {
    background: var(--ink);
    color: var(--paper);
    border-left: 2px solid var(--ink);
    min-width: 5.5rem;
    height: 7rem;
    padding: 0;
  }
  .total-header-text {
    font-weight: 700;
    font-size: 0.75rem;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    writing-mode: vertical-rl;
    transform: rotate(180deg);
    margin: auto;
  }
  /* Cel·les buides: graella dibuixada però sense valors, fons subtil */
  .match-cell.empty {
    background: repeating-linear-gradient(45deg, transparent 0 12px, rgba(163, 107, 28, 0.04) 12px 13px);
  }
  /* Cel·les diagonal (mateix jugador) */
  .match-cell.self {
    background: repeating-linear-gradient(135deg, var(--paper) 0 6px, var(--rule) 6px 7px);
  }
  .self-match {
    height: 4.5rem;
  }

  .match-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: auto auto auto;
    line-height: 1.1;
  }
  .cell {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0.32rem 0.4rem;
    font-feature-settings: 'tnum' 1, 'lnum' 1;
    min-height: 1.6rem;
  }
  .cell.top-left {
    grid-column: 1;
    grid-row: 1;
    border-right: 1px solid var(--rule);
    border-bottom: 1px solid var(--rule);
    font-weight: 800;
    font-size: 1.0625rem;
    letter-spacing: -0.02em;
    color: var(--ink);
    min-height: 2rem;
  }
  .cell.top-left.win  { color: var(--green); }
  .cell.top-left.lose { color: var(--accent); }
  .cell.top-right {
    grid-column: 2;
    grid-row: 1;
    border-bottom: 1px solid var(--rule);
    font-weight: 600;
    font-size: 0.875rem;
    color: var(--ink-2);
    min-height: 2rem;
  }
  .cell.middle {
    grid-column: 1 / -1;
    grid-row: 2;
    border-bottom: 1px solid var(--rule);
    font-weight: 600;
    font-size: 0.8125rem;
    color: var(--ink-2);
  }
  .cell.bottom {
    grid-column: 1 / -1;
    grid-row: 3;
    font-weight: 500;
    font-size: 0.8125rem;
    color: var(--ink-2);
  }

  /* ── Llegenda ───────────────────────────────────────── */
  .legend {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.25rem 1.5rem;
  }
  .legend-grid {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 1.5rem;
    align-items: start;
  }
  .legend-table {
    border-collapse: collapse;
  }
  .legend-cell-inner {
    border: 1px solid var(--rule-strong);
    padding: 0;
    min-width: 5.5rem;
  }
  .legend-text {
    font-size: 0.8125rem;
    color: var(--ink-2);
    line-height: 1.55;
  }
  .legend-rows {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }
  .legend-pos {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--ink-3);
    margin-right: 0.5rem;
  }
  .legend-note {
    margin: 0.85rem 0 0;
    font-size: 0.75rem;
    color: var(--ink-3);
    line-height: 1.55;
  }
  .legend-note strong {
    color: var(--ink-2);
    font-weight: 700;
  }

  /* ── Responsiu ─────────────────────────────────────── */
  @media (max-width: 768px) {
    .grid-head {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.75rem;
    }
    .title {
      font-size: 1.5rem;
    }
    .player-name {
      min-width: 6rem;
      max-width: 6rem;
      font-size: 0.75rem;
      padding: 0.5rem 0.5rem;
    }
    .opponent-name {
      min-width: 4.5rem;
      max-width: 4.5rem;
      height: 6rem;
    }
    .match-cell {
      min-width: 4.5rem;
      max-width: 4.5rem;
    }
    .cell.top-left {
      font-size: 0.9375rem;
    }
    .cell.top-right {
      font-size: 0.75rem;
    }
    .cell.middle, .cell.bottom {
      font-size: 0.6875rem;
    }
    .legend-grid {
      grid-template-columns: 1fr;
    }
  }

  /* ── Print ────────────────────────────────────────── */
  @media print {
    :global(body) { background: white; }
    :global(.topbar), :global(nav.sections), :global(.subtabs),
    .no-print, .legend { display: none !important; }
    .head-to-head-container { padding: 0; box-shadow: none; }
    .grid-wrapper { border-color: #333 !important; overflow: visible; }
    .head-to-head-grid th,
    .head-to-head-grid td { border-color: #333 !important; }
    .cell { border-color: #999 !important; }
    .cell.top-left.win,
    .cell.top-left.lose { color: #000 !important; }
    .match-cell.empty { background: white !important; }
    .match-cell.self {
      background: repeating-linear-gradient(135deg, white 0 6px, #999 6px 7px) !important;
    }
    .player-header,
    .player-name,
    .player-header.corner { background: #f5f5f5 !important; color: #000 !important; }
  }

  .h2h-player-link {
    color: inherit;
    text-decoration: none;
    border-bottom: 1px solid transparent;
    transition: color 0.15s ease, border-color 0.15s ease;
  }
  .h2h-player-link:hover {
    color: var(--accent, #a30b1e);
    border-bottom-color: var(--accent, #a30b1e);
  }

  @media print {
    .h2h-player-link {
      color: inherit !important;
      border: none !important;
      text-decoration: none !important;
    }
  }
</style>
