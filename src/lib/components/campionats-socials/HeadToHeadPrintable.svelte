<script lang="ts">
  import { getHeadToHeadResults } from '$lib/api/socialLeagues';

  export let eventId: string;
  export let eventName: string = '';
  export let season: string = '';
  export let categories: Array<{
    id: string;
    nom: string;
    distancia_caramboles: number;
    max_entrades?: number;
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

  function sortPlayersByLastName(players: Array<any>): Array<any> {
    return [...players].sort((a, b) => {
      const lastNameA = a.cognoms ? a.cognoms.split(' ')[0].toLowerCase() : '';
      const lastNameB = b.cognoms ? b.cognoms.split(' ')[0].toLowerCase() : '';
      return lastNameA.localeCompare(lastNameB, 'ca');
    });
  }

  function calculateOptimalSizes(numPlayers: number) {
    // Dimensions A3 landscape: ~42cm amplada x ~29.7cm alçada
    // Marges: 0.4cm x 2 = 0.8cm
    // Espai disponible: ~41.2cm amplada x ~29cm alçada
    
    const availableWidth = 41.2; // cm
    const availableHeight = 29; // cm
    const headerHeight = 1.8; // cm per capçalera (augmentat)
    const cornerWidth = 3.5; // cm per columna de noms (augmentat per més llegibilitat)
    
    // Espai disponible per les cel·les
    const gridHeight = availableHeight - headerHeight - 0.8; // menys buffer
    const gridWidth = availableWidth - cornerWidth - 0.5; // menys buffer
    
    // Calcular mida òptima per cel·la
    const cellWidth = Math.min(gridWidth / numPlayers, 2.5); // màxim 2.5cm (augmentat)
    const cellHeight = Math.min(gridHeight / numPlayers, 2.0); // màxim 2.0cm (augmentat)
    
    // Calcular font size proporcional - augmentat substancialment
    const fontSize = Math.max(Math.min(cellHeight * 0.5, 11), 8); // entre 8pt i 11pt
    const playerNameSize = Math.max(Math.min(cellHeight * 0.55, 11), 9); // mínim 9pt, màxim 11pt
    
    return {
      cellWidth: Math.max(cellWidth, 1.2), // mínim 1.2cm (augmentat)
      cellHeight: Math.max(cellHeight, 1.0), // mínim 1.0cm (augmentat)
      fontSize: fontSize,
      playerNameSize: playerNameSize,
      headerHeight: Math.max(cellHeight * 2.0, 2.5), // alçada capçalera més gran per noms complets
      cornerWidth: cornerWidth
    };
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
        <div class="header-center">
          <h1 style="font-size: 12pt !important;">CAMPIONAT SOCIAL DE {eventName.toUpperCase()}</h1>
          {#if season}
            <p class="season-info" style="font-size: 10pt !important;">TEMPORADA {season}</p>
          {/if}
        </div>
        <div class="header-right">
          <p class="category-info" style="font-size: 9pt !important;">{catData.category.nom} - {catData.category.distancia_caramboles} car.</p>
          <p class="entries-info" style="font-size: 8pt !important;">{catData.category.max_entrades || '-'} Entrades</p>
        </div>
      </div>

      <!-- Grid -->
      {#if catData.loading}
        <p class="loading-text">Carregant dades...</p>
      {:else if catData.error}
        <p class="error-text">{catData.error}</p>
      {:else if catData.players.length === 0}
        <p class="empty-text">No hi ha jugadors inscrits en aquesta categoria</p>
      {:else}
        {@const sortedPlayers = sortPlayersByLastName(catData.players)}
        {@const sizes = calculateOptimalSizes(sortedPlayers.length)}
        <table class="print-grid" style="font-size: {sizes.fontSize}pt;">
          <thead>
            <tr>
              <th class="corner-cell" style="width: {sizes.cornerWidth}cm;">
                <img src="/logo.png" alt="Logo Billar" class="corner-logo" style="max-height: {sizes.headerHeight}cm;" />
              </th>
              {#each sortedPlayers as opponent}
                <th class="player-header" style="width: {sizes.cellWidth}cm; height: {sizes.headerHeight}cm; background: #f0f0f0; color: #000; border-left: 0.3px solid #666; border-right: 0.3px solid #666;">
                  <div class="player-name-horizontal" style="font-size: {sizes.playerNameSize * 1.1}pt !important; padding: 2px 1px !important;">
                    {getPlayerShortName(opponent)}
                  </div>
                </th>
              {/each}
            </tr>
          </thead>
          <tbody>
            {#each sortedPlayers as player}
              <tr>
                <th class="player-row-header" style="width: {sizes.cornerWidth}cm; font-size: {sizes.playerNameSize * 1.35}pt !important; padding: 1px 2px !important; border-top: 0.3px solid #666; border-bottom: 0.3px solid #666;">
                  {getPlayerShortName(player)}
                </th>
                {#each sortedPlayers as opponent}
                  <td class="match-cell" style="width: {sizes.cellWidth}cm; height: {sizes.cellHeight}cm; padding: 0;" class:self-cell={player.id === opponent.id}>
                    {#if player.id === opponent.id}
                      <div class="self-match">—</div>
                    {:else}
                      {@const matchData = getMatchData(catData.matches, player.id, opponent.id)}
                      <div class="match-grid" style="font-size: {sizes.fontSize * 0.85}pt;">
                        <div class="grid-cell top-left" style="border-right: 0.3px solid #ccc; border-bottom: 0.3px solid #ccc;">{matchData?.caramboles ?? ''}</div>
                        <div class="grid-cell top-right" style="border-bottom: 0.3px solid #ccc;">{matchData?.entrades ?? ''}</div>
                        <div class="grid-cell middle-full" style="border-bottom: 0.3px solid #ccc;">{matchData?.punts ?? ''}</div>
                        <div class="grid-cell bottom-full">{matchData ? matchData.mitjana.toFixed(3) : ''}</div>
                      </div>
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
    padding: 0.3cm;
    page-break-inside: avoid;
  }

  .page-break {
    page-break-after: always;
    break-after: page;
  }

  /* Header */
  .print-header {
    position: relative;
    margin-bottom: 0.2cm;
    padding-bottom: 0.15cm;
    border-bottom: 1px solid #ccc;
    min-height: 1.2cm;
  }

  .header-center {
    text-align: center;
    margin-bottom: 0;
  }

  .header-center h1 {
    font-size: 10pt;
    margin: 0;
    font-weight: bold;
    color: #000;
    line-height: 1.1;
  }

  .season-info {
    font-size: 8pt;
    margin: 2px 0 0 0;
    font-weight: bold;
    color: #000;
  }

  .header-subtitle {
    font-size: 7pt;
    margin: 0;
    color: #000;
  }

  .header-right {
    position: absolute;
    right: 0;
    top: 0;
    text-align: right;
  }

  .category-info {
    font-size: 7pt;
    margin: 0;
    font-weight: bold;
  }

  .entries-info {
    font-size: 6.5pt;
    margin: 2px 0 0 0;
    font-weight: bold;
    color: #000;
  }

  /* Grid */
  .print-grid {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 0.2cm;
    table-layout: fixed;
    page-break-inside: avoid;
  }

  .print-grid th,
  .print-grid td {
    padding: 0;
    text-align: center;
  }

  .corner-cell {
    background: #fff;
    padding: 1px;
    vertical-align: middle;
  }

  .corner-logo {
    max-width: 100%;
    width: auto;
    display: block;
    margin: 0 auto;
    object-fit: contain;
  }

  .player-header {
    background: #333;
    color: white;
    font-weight: bold;
    padding: 0;
    position: relative;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
    overflow: hidden;
  }

  .player-name-rotated {
    writing-mode: vertical-rl;
    transform: rotate(180deg);
    white-space: nowrap;
    font-weight: 600;
    padding: 2px 0;
    text-align: center;
    width: 100%;
  }

  .player-name-horizontal {
    writing-mode: horizontal-tb;
    white-space: normal;
    word-wrap: break-word;
    font-weight: 600;
    text-align: center;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    line-height: 1.05;
  }

  .player-row-header {
    background: #e8e8e8;
    font-weight: bold;
    text-align: left;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .match-cell {
    padding: 0;
    vertical-align: middle;
  }

  .self-cell {
    background: #d0d0d0;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .self-match {
    color: #666;
    font-size: 10pt;
    font-weight: bold;
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
  }

  .match-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: 1fr 1fr 1fr;
    width: 100%;
    height: 100%;
    gap: 0;
  }

  .grid-cell {
    padding: 1px;
    text-align: center;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    line-height: 1;
    background: #fff;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .grid-cell.top-left {
    grid-column: 1;
    grid-row: 1;
  }

  .grid-cell.top-right {
    grid-column: 2;
    grid-row: 1;
  }

  .grid-cell.middle-full {
    grid-column: 1 / -1;
    grid-row: 2;
    background: #f0f0f0;
    font-weight: bold;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .grid-cell.bottom-full {
    grid-column: 1 / -1;
    grid-row: 3;
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
      margin: 0.4cm;
    }

    .printable-container {
      width: 100%;
    }

    .print-page {
      padding: 0.15cm;
      page-break-inside: avoid;
      page-break-after: always;
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
