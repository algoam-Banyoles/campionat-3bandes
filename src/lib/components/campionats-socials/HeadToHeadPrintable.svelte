<script lang="ts">
  import { getHeadToHeadResults } from '$lib/api/socialLeagues';

  export let eventId: string;
  export let eventName: string = '';
  export let categories: Array<{
    id: string;
    nom: string;
    distancia_caramboles: number;
  }> = [];

  interface CategoryData {
    category: any;
    players: Array<any>;
    matches: Map<string, any>;
    loading: boolean;
    error: string | null;
  }

  let categoriesData: Map<string, CategoryData> = new Map();

  export async function loadCategory(categoryId: string) {
    const category = categories.find(c => c.id === categoryId);
    if (!category) return;

    const data: CategoryData = {
      category,
      players: [],
      matches: new Map(),
      loading: true,
      error: null
    };

    categoriesData.set(categoryId, data);
    categoriesData = categoriesData;

    try {
      const result = await getHeadToHeadResults(eventId, categoryId);
      data.players = result.players;
      data.matches = result.matches;
      data.loading = false;
    } catch (err) {
      data.error = 'Error carregant dades';
      data.loading = false;
    }

    categoriesData.set(categoryId, data);
    categoriesData = categoriesData;
  }

  function getMatchData(matches: Map<string, any>, playerId: string, opponentId: string) {
    const key = `${playerId}_${opponentId}`;
    return matches.get(key);
  }

  function getPlayerShortName(player: any): string {
    const inicial = player.nom ? player.nom.charAt(0).toUpperCase() + '.' : '';
    const primerCognom = player.cognoms ? player.cognoms.split(' ')[0] : '';
    return `${inicial} ${primerCognom}`.trim();
  }
</script>

<div class="printable-container">
  {#each Array.from(categoriesData.values()) as catData, index}
    {#if index > 0}
      <div class="page-break"></div>
    {/if}

    <div class="print-page">
      <!-- Header -->
      <div class="print-header">
        <h1>{eventName}</h1>
        <h2>{catData.category.nom}</h2>
        <p class="print-info">
          Distància: {catData.category.distancia_caramboles} caramboles
          | Data: {new Date().toLocaleDateString('ca-ES')}
        </p>
      </div>

      <!-- Grid -->
      {#if catData.loading}
        <p class="loading-text">Carregant dades...</p>
      {:else if catData.error}
        <p class="error-text">{catData.error}</p>
      {:else if catData.players.length === 0}
        <p class="empty-text">No hi ha resultats disponibles</p>
      {:else}
        <table class="print-grid">
          <thead>
            <tr>
              <th class="corner-cell">
                <img src="/logo.png" alt="Logo Billar" class="corner-logo" />
              </th>
              {#each catData.players as opponent}
                <th class="player-header">
                  <div class="player-name-rotated">
                    {getPlayerShortName(opponent)}
                  </div>
                </th>
              {/each}
            </tr>
          </thead>
          <tbody>
            {#each catData.players as player}
              <tr>
                <th class="player-row-header">
                  {getPlayerShortName(player)}
                </th>
                {#each catData.players as opponent}
                  <td class="match-cell" class:self-cell={player.id === opponent.id}>
                    {#if player.id === opponent.id}
                      <div class="self-match">—</div>
                    {:else}
                      {@const matchData = getMatchData(catData.matches, player.id, opponent.id)}
                      {#if matchData}
                        <div class="match-data">
                          <div class="data-row">
                            <span class="value">{matchData.caramboles}</span>
                            <span class="spacer"></span>
                            <span class="value">{matchData.entrades}</span>
                          </div>
                          <div class="data-row centered">
                            <span class="value points">{matchData.punts}</span>
                          </div>
                          <div class="data-row">
                            <span class="value">{matchData.mitjana.toFixed(3)}</span>
                          </div>
                        </div>
                      {:else}
                        <div class="no-match">—</div>
                      {/if}
                    {/if}
                  </td>
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>
  {/each}
</div>

<style>
  /* Base container */
  .printable-container {
    width: 100%;
  }

  .print-page {
    width: 100%;
    padding: 0.5cm;
  }

  .page-break {
    page-break-after: always;
    break-after: page;
  }

  /* Header */
  .print-header {
    text-align: center;
    margin-bottom: 0.5cm;
    border-bottom: 2px solid #333;
    padding-bottom: 0.3cm;
  }

  .print-header h1 {
    font-size: 18pt;
    margin: 0 0 0.2cm 0;
    font-weight: bold;
    color: #333;
  }

  .print-header h2 {
    font-size: 14pt;
    margin: 0 0 0.2cm 0;
    font-weight: 600;
    color: #555;
  }

  .print-info {
    font-size: 9pt;
    color: #666;
    margin: 0;
  }

  /* Grid */
  .print-grid {
    width: 100%;
    border-collapse: collapse;
    font-size: 7pt;
    margin-bottom: 0.3cm;
  }

  .print-grid th,
  .print-grid td {
    border: 1px solid #333;
    padding: 2px;
    text-align: center;
  }

  .corner-cell {
    background: #fff;
    width: 3cm;
    padding: 4px;
    vertical-align: middle;
  }

  .corner-logo {
    max-width: 100%;
    max-height: 3cm;
    height: auto;
    display: block;
    margin: 0 auto;
  }

  .player-header {
    background: #333;
    color: white;
    font-weight: bold;
    height: 2.5cm;
    width: 1.2cm;
    padding: 2px;
    position: relative;
  }

  .player-name-rotated {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%) rotate(-45deg);
    transform-origin: center;
    white-space: nowrap;
    font-size: 7pt;
    width: 2.5cm;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .player-row-header {
    background: #e8e8e8;
    font-weight: bold;
    text-align: left;
    padding-left: 4px;
    font-size: 7pt;
    white-space: nowrap;
    width: 2cm;
  }

  .match-cell {
    width: 1.2cm;
    height: 0.8cm;
    padding: 1px;
    vertical-align: middle;
  }

  .self-cell {
    background: #f5f5f5;
  }

  .self-match {
    color: #999;
    font-size: 10pt;
    font-weight: bold;
  }

  .match-data {
    display: flex;
    flex-direction: column;
    gap: 1px;
    font-size: 6pt;
  }

  .data-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0 2px;
  }

  .data-row.centered {
    justify-content: center;
    background: #f0f0f0;
    gap: 2px;
  }

  .value {
    font-weight: 600;
    color: #000;
  }

  .value.points {
    font-weight: bold;
    font-size: 7pt;
  }

  .spacer {
    flex: 1;
  }

  .no-match {
    color: #ccc;
    font-size: 8pt;
  }

  /* Status messages */
  .loading-text,
  .error-text,
  .empty-text {
    text-align: center;
    padding: 1cm;
    font-size: 10pt;
  }

  .error-text {
    color: #c00;
  }

  /* Print-specific styles */
  @media print {
    @page {
      size: A3 landscape;
      margin: 1cm;
    }

    .printable-container {
      width: 100%;
    }

    .print-page {
      padding: 0;
    }

    .print-grid {
      font-size: 7pt;
    }

    .player-name-rotated {
      font-size: 7pt;
    }

    .match-data {
      font-size: 6pt;
    }

    .page-break {
      page-break-after: always;
      break-after: page;
    }

    /* Hide screen-only elements when printing */
    :global(.no-print) {
      display: none !important;
    }
  }

  /* Screen preview adjustments */
  @media screen {
    .print-page {
      background: white;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
      margin-bottom: 1rem;
    }
  }
</style>
