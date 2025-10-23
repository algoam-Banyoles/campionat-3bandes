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
  <h2 class="title">Graella de Resultats - {categoriaNom}</h2>

  {#if loading}
    <div class="loading">
      <div class="spinner"></div>
      <p>Carregant graella de resultats...</p>
    </div>
  {:else if error}
    <div class="error">
      <p>{error}</p>
      <button on:click={loadHeadToHeadData}>Tornar a intentar</button>
    </div>
  {:else if players.length === 0}
    <div class="empty">
      <p>No hi ha resultats disponibles per aquesta categoria.</p>
    </div>
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
            </tr>
          </thead>
          <tbody>
            {#each sortedPlayers as player}
              <tr>
                <th class="player-name" title={getPlayerFullName(player)}>
                  {getPlayerShortName(player)}
                </th>
                {#each sortedPlayers as opponent}
                  <td class="match-cell" class:self={player.id === opponent.id}>
                    {#if player.id === opponent.id}
                      <div class="self-match">-</div>
                    {:else}
                      {@const matchData = getMatchData(player.id, opponent.id)}
                      {#if matchData}
                        <div class="match-grid">
                          <div class="cell top-left">
                            <span class="label">C:</span>
                            <span class="value">{matchData.caramboles}</span>
                          </div>
                          <div class="cell top-right">
                            <span class="label">E:</span>
                            <span class="value">{matchData.entrades}</span>
                          </div>
                          <div class="cell middle">
                            <span class="label">P:</span>
                            <span class="value points">{matchData.punts}</span>
                          </div>
                          <div class="cell bottom-left">
                            <span class="label">M:</span>
                            <span class="value">{matchData.mitjana.toFixed(3)}</span>
                          </div>
                        </div>
                      {:else}
                        <div class="no-match">Pendent</div>
                      {/if}
                    {/if}
                  </td>
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>

    <div class="legend">
      <h3>Llegenda:</h3>
      <ul>
        <li><strong>C:</strong> Caramboles</li>
        <li><strong>E:</strong> Entrades</li>
        <li><strong>P:</strong> Punts (2=victòria, 1=empat, 0=derrota)</li>
        <li><strong>M:</strong> Mitjana (caramboles/entrades)</li>
      </ul>
    </div>
  {/if}
</div>

<style>
  .head-to-head-container {
    width: 100%;
    padding: 1rem;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .title {
    font-size: 1.5rem;
    font-weight: bold;
    margin-bottom: 1.5rem;
    color: #333;
    text-align: center;
  }

  .loading, .error, .empty {
    text-align: center;
    padding: 2rem;
  }

  .spinner {
    border: 4px solid #f3f3f3;
    border-top: 4px solid #3498db;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
    margin: 0 auto 1rem;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .error {
    color: #e74c3c;
  }

  .error button {
    margin-top: 1rem;
    padding: 0.5rem 1rem;
    background: #3498db;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }

  .error button:hover {
    background: #2980b9;
  }

  .grid-wrapper {
    overflow-x: auto;
    margin-bottom: 1.5rem;
  }

  .grid-scroll {
    min-width: 100%;
  }

  .head-to-head-grid {
    border-collapse: collapse;
    width: 100%;
    font-size: 0.85rem;
  }

  .head-to-head-grid th,
  .head-to-head-grid td {
    border: 1px solid #ddd;
    padding: 0.5rem;
    text-align: center;
  }

  .player-header {
    background: #34495e;
    color: white;
    font-weight: bold;
    position: sticky;
    top: 0;
    z-index: 10;
  }

  .player-header.corner {
    position: sticky;
    left: 0;
    z-index: 20;
  }

  .player-name {
    background: #ecf0f1;
    font-weight: bold;
    text-align: left;
    padding-left: 1rem;
    position: sticky;
    left: 0;
    z-index: 5;
    min-width: 150px;
    white-space: nowrap;
  }

  .opponent-name {
    min-width: 100px;
    max-width: 100px;
    height: 150px;
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
    width: 140px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .match-cell {
    min-width: 100px;
    max-width: 100px;
    height: 80px;
    padding: 0.25rem;
    vertical-align: middle;
  }

  .match-cell.self {
    background: #f8f9fa;
  }

  .self-match {
    color: #95a5a6;
    font-size: 1.5rem;
    font-weight: bold;
  }

  .match-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: auto auto auto;
    gap: 2px;
    width: 100%;
    height: 100%;
  }

  .cell {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 2px 4px;
    background: #f8f9fa;
    border-radius: 2px;
    font-size: 0.7rem;
  }

  .cell.top-left {
    grid-column: 1;
    grid-row: 1;
  }

  .cell.top-right {
    grid-column: 2;
    grid-row: 1;
  }

  .cell.middle {
    grid-column: 1 / -1;
    grid-row: 2;
    background: #e8f4f8;
  }

  .cell.bottom-left {
    grid-column: 1 / -1;
    grid-row: 3;
  }

  .label {
    font-weight: bold;
    color: #555;
    margin-right: 2px;
  }

  .value {
    font-weight: 600;
    color: #2c3e50;
  }

  .value.points {
    color: #27ae60;
    font-weight: bold;
  }

  .no-match {
    color: #95a5a6;
    font-size: 0.75rem;
    font-style: italic;
  }

  .legend {
    background: #f8f9fa;
    padding: 1rem;
    border-radius: 4px;
    border-left: 4px solid #3498db;
  }

  .legend h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1rem;
    color: #2c3e50;
  }

  .legend ul {
    list-style: none;
    padding: 0;
    margin: 0;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.5rem;
  }

  .legend li {
    font-size: 0.875rem;
    color: #555;
  }

  .legend strong {
    color: #2c3e50;
  }

  @media (max-width: 768px) {
    .head-to-head-container {
      padding: 0.5rem;
    }

    .title {
      font-size: 1.2rem;
    }

    .head-to-head-grid {
      font-size: 0.75rem;
    }

    .player-name {
      min-width: 120px;
      font-size: 0.75rem;
    }

    .match-cell {
      min-width: 80px;
      max-width: 80px;
      height: 70px;
    }

    .cell {
      font-size: 0.65rem;
      padding: 1px 2px;
    }

    .legend ul {
      grid-template-columns: 1fr;
    }
  }
</style>
