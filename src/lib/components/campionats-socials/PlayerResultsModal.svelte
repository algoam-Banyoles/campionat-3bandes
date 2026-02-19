<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  export let isOpen = false;
  export let playerName = '';
  export let playerNumeroSoci: number | null = null;
  export let eventId: string | null = null;
  export let categoriaId: string | null = null;

  const dispatch = createEventDispatcher();

  let modalElement: HTMLElement;
  let previousActiveElement: HTMLElement | null = null;
  let loading = false;
  let error: string | null = null;
  let matches: any[] = [];

  interface MatchResult {
    id: string;
    data_programada: string;
    caramboles_jugador1: number | null;
    caramboles_jugador2: number | null;
    entrades: number;
    jugador1_id: string;
    jugador2_id: string;
    jugador1_nom: string;
    jugador2_nom: string;
    jugador1_numero_soci: number;
    jugador2_numero_soci: number;
    estat: string;
    incompareixenca_jugador1?: boolean;
    incompareixenca_jugador2?: boolean;
    punts_jugador1?: number;
    punts_jugador2?: number;
    entrades_jugador1?: number;
    entrades_jugador2?: number;
  }

  $: if (isOpen && playerNumeroSoci && eventId) {
    loadPlayerMatches();
  }

  $: if (isOpen) {
    // Focus the modal when it opens
    setTimeout(() => {
      if (modalElement) {
        modalElement.focus();
      }
    }, 100);

    // Prevent body scroll
    document.body.style.overflow = 'hidden';
  } else {
    // Restore body scroll
    document.body.style.overflow = '';

    // Return focus to the element that opened the modal
    if (previousActiveElement) {
      previousActiveElement.focus();
    }
  }

  async function loadPlayerMatches() {
    if (!playerNumeroSoci || !eventId) return;

    loading = true;
    error = null;
    matches = [];

    try {
      const { data: inscriptionData, error: inscriptionError } = await supabase
        .from('inscripcions')
        .select('estat_jugador, eliminat_per_incompareixences')
        .eq('event_id', eventId)
        .eq('soci_numero', playerNumeroSoci)
        .single();

      if (inscriptionError) throw inscriptionError;

      if (inscriptionData?.estat_jugador === 'retirat' || inscriptionData?.eliminat_per_incompareixences) {
        return;
      }

      const { data: allInscriptions, error: allInscriptionsError } = await supabase
        .from('inscripcions')
        .select('soci_numero, estat_jugador, eliminat_per_incompareixences')
        .eq('event_id', eventId);

      if (allInscriptionsError) throw allInscriptionsError;

      const withdrawnNumbers = new Set(
        (allInscriptions || [])
          .filter((item: any) => item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences)
          .map((item: any) => item.soci_numero)
          .filter((numero: any) => typeof numero === 'number')
      );

      // Get player ID from numero_soci
      const { data: playerData, error: playerError } = await supabase
        .from('players')
        .select('id')
        .eq('numero_soci', playerNumeroSoci)
        .single();

      if (playerError) throw playerError;
      if (!playerData) throw new Error('Jugador no trobat');

      const playerId = playerData.id;

      // Build query for matches
      let query = supabase
        .from('calendari_partides')
        .select(`
          id,
          data_programada,
          caramboles_jugador1,
          caramboles_jugador2,
          entrades,
          jugador1_id,
          jugador2_id,
          partida_anullada,
          estat,
          incompareixenca_jugador1,
          incompareixenca_jugador2,
          punts_jugador1,
          punts_jugador2,
          entrades_jugador1,
          entrades_jugador2
        `)
        .eq('event_id', eventId)
        .eq('estat', 'validat')
        .or('partida_anullada.is.null,partida_anullada.eq.false')
        .not('caramboles_jugador1', 'is', null)
        .not('caramboles_jugador2', 'is', null)
        .or(`jugador1_id.eq.${playerId},jugador2_id.eq.${playerId}`)
        .order('data_programada', { ascending: false });

      // Filter by category if specified
      if (categoriaId) {
        query = query.eq('categoria_id', categoriaId);
      }

      const { data: matchesData, error: matchesError } = await query;

      if (matchesError) throw matchesError;

      // Get all unique player IDs from matches
      const playerIds = new Set<string>();
      matchesData?.forEach(match => {
        playerIds.add(match.jugador1_id);
        playerIds.add(match.jugador2_id);
      });

      // Fetch player info for all players in matches
      const { data: playersData, error: playersError } = await supabase
        .from('players')
        .select('id, numero_soci')
        .in('id', Array.from(playerIds));

      if (playersError) throw playersError;

      // Get unique numero_soci values
      const numerosSoci = [...new Set(playersData?.map(p => p.numero_soci).filter(Boolean))];

      // Fetch socis info to get nom AND cognoms (igual que a les classificacions)
      const { data: socisData, error: socisError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .in('numero_soci', numerosSoci);

      if (socisError) {
        console.warn('Error fetching socis:', socisError);
      }

      // Create a map of socis with nom and cognoms
      const socisMap = new Map();
      socisData?.forEach(s => {
        socisMap.set(s.numero_soci, {
          nom: s.nom,
          cognoms: s.cognoms
        });
      });

      // Create a map of player info
      const playersMap = new Map();
      const playerNumeroMap = new Map();
      playersData?.forEach(p => {
        const sociData = p.numero_soci ? socisMap.get(p.numero_soci) : null;
        playersMap.set(p.id, {
          nom: sociData?.nom || '',
          cognoms: sociData?.cognoms || '',
          numero_soci: p.numero_soci
        });
        playerNumeroMap.set(p.id, p.numero_soci);
      });

      // Enrich matches with player names
      const filteredMatches = matchesData?.filter(match => {
        if (withdrawnNumbers.size === 0) return true;
        const j1Numero = playerNumeroMap.get(match.jugador1_id);
        const j2Numero = playerNumeroMap.get(match.jugador2_id);
        return !withdrawnNumbers.has(j1Numero) && !withdrawnNumbers.has(j2Numero);
      }) || [];

      matches = filteredMatches.map(match => {
        const jugador1 = playersMap.get(match.jugador1_id);
        const jugador2 = playersMap.get(match.jugador2_id);

        return {
          ...match,
          jugador1_nom: formatPlayerName(jugador1?.nom, jugador1?.cognoms, jugador1?.numero_soci),
          jugador2_nom: formatPlayerName(jugador2?.nom, jugador2?.cognoms, jugador2?.numero_soci),
          jugador1_numero_soci: jugador1?.numero_soci,
          jugador2_numero_soci: jugador2?.numero_soci
        };
      }) || [];

    } catch (e: any) {
      console.error('Error loading player matches:', e);
      error = e.message || 'Error carregant els resultats del jugador';
    } finally {
      loading = false;
    }
  }

  function formatPlayerName(nom: string | undefined, cognoms: string | undefined, numeroSoci: number | undefined) {
    if (!nom && !cognoms) return `Soci #${numeroSoci}`;

    // Format: inicial(s) del nom + primer cognom (igual que a les classificacions)
    // Si el nom té múltiples paraules (ex: "Jose Maria"), agafem inicials de totes
    // Però del cognom només el primer (ex: "Campos Garcia" -> "Campos")
    let inicials = '';
    if (nom) {
      const noms = nom.trim().split(/\s+/);
      inicials = noms.map(n => n.charAt(0).toUpperCase() + '.').join('');
    }

    const primerCognom = cognoms ? cognoms.trim().split(/\s+/)[0] : '';

    if (inicials && primerCognom) {
      return `${inicials} ${primerCognom}`;
    } else if (inicials) {
      return inicials;
    } else if (primerCognom) {
      return primerCognom;
    }

    return `Soci #${numeroSoci}`;
  }

  function getPlayerInitials(nom: string | undefined): string {
    if (!nom) return '?';
    const noms = nom.trim().split(/\s+/);
    return noms.map(n => n.charAt(0).toUpperCase()).join('');
  }

  function closeModal() {
    isOpen = false;
    dispatch('close');
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      closeModal();
    }
  }

  function handleBackdropClick(event: MouseEvent) {
    if (event.target === event.currentTarget) {
      closeModal();
    }
  }

  function trapFocus(event: KeyboardEvent) {
    if (event.key !== 'Tab') return;

    const focusableElements = modalElement.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const firstElement = focusableElements[0] as HTMLElement;
    const lastElement = focusableElements[focusableElements.length - 1] as HTMLElement;

    if (event.shiftKey) {
      if (document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      }
    } else {
      if (document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    }
  }

  function isPlayerWinner(match: any, playerSoci: number): boolean {
    // Determine winner based on caramboles
    if (match.caramboles_jugador1 === null || match.caramboles_jugador2 === null) {
      return false;
    }

    const playerIsJugador1 = match.jugador1_numero_soci === playerSoci;
    const playerCaramboles = playerIsJugador1 ? match.caramboles_jugador1 : match.caramboles_jugador2;
    const opponentCaramboles = playerIsJugador1 ? match.caramboles_jugador2 : match.caramboles_jugador1;

    return playerCaramboles > opponentCaramboles;
  }

  function getOpponentName(match: any, playerSoci: number): string {
    return match.jugador1_numero_soci === playerSoci
      ? match.jugador2_nom
      : match.jugador1_nom;
  }

  function getOpponentIncompareixenca(match: any, playerSoci: number): boolean {
    return match.jugador1_numero_soci === playerSoci
      ? (match.incompareixenca_jugador2 || false)
      : (match.incompareixenca_jugador1 || false);
  }

  function getPlayerCaramboles(match: any, playerSoci: number): number {
    return match.jugador1_numero_soci === playerSoci
      ? match.caramboles_jugador1
      : match.caramboles_jugador2;
  }

  function getOpponentCaramboles(match: any, playerSoci: number): number {
    return match.jugador1_numero_soci === playerSoci
      ? match.caramboles_jugador2
      : match.caramboles_jugador1;
  }

  function getPlayerEntrades(match: any, playerSoci: number): number {
    const playerIsJugador1 = match.jugador1_numero_soci === playerSoci;

    // Utilitzar entrades_jugador1/jugador2 si està disponible
    if (playerIsJugador1 && match.entrades_jugador1 !== null && match.entrades_jugador1 !== undefined) {
      return match.entrades_jugador1;
    }
    if (!playerIsJugador1 && match.entrades_jugador2 !== null && match.entrades_jugador2 !== undefined) {
      return match.entrades_jugador2;
    }

    // Fallback al camp entrades genèric
    return match.entrades || 0;
  }

  function formatDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('ca-ES', {
      day: 'numeric',
      month: 'short',
      year: 'numeric'
    });
  }

  function getMatchResult(match: any, playerSoci: number): 'win' | 'loss' | 'draw' {
    if (match.caramboles_jugador1 === null || match.caramboles_jugador2 === null) {
      return 'draw';
    }

    const playerIsJugador1 = match.jugador1_numero_soci === playerSoci;

    // Utilitzar punts si estan disponibles (més precís per incompareixences)
    if (match.punts_jugador1 !== null && match.punts_jugador1 !== undefined &&
        match.punts_jugador2 !== null && match.punts_jugador2 !== undefined) {
      const playerPunts = playerIsJugador1 ? match.punts_jugador1 : match.punts_jugador2;

      if (playerPunts === 2) return 'win';
      if (playerPunts === 1) return 'draw';
      if (playerPunts === 0) return 'loss';
    }

    // Fallback a comparar caramboles si no hi ha punts
    const playerCaramboles = playerIsJugador1 ? match.caramboles_jugador1 : match.caramboles_jugador2;
    const opponentCaramboles = playerIsJugador1 ? match.caramboles_jugador2 : match.caramboles_jugador1;

    if (playerCaramboles > opponentCaramboles) return 'win';
    if (playerCaramboles < opponentCaramboles) return 'loss';
    return 'draw';
  }

  // Calculate statistics
  $: stats = matches.reduce((acc, match) => {
    if (!playerNumeroSoci) return acc;

    const result = getMatchResult(match, playerNumeroSoci);
    const playerCaramboles = getPlayerCaramboles(match, playerNumeroSoci);
    const opponentCaramboles = getOpponentCaramboles(match, playerNumeroSoci);
    const playerEntrades = getPlayerEntrades(match, playerNumeroSoci);

    return {
      totalMatches: acc.totalMatches + 1,
      wins: acc.wins + (result === 'win' ? 1 : 0),
      losses: acc.losses + (result === 'loss' ? 1 : 0),
      draws: acc.draws + (result === 'draw' ? 1 : 0),
      totalCaramboles: acc.totalCaramboles + playerCaramboles,
      totalOpponentCaramboles: acc.totalOpponentCaramboles + opponentCaramboles,
      totalEntrades: acc.totalEntrades + playerEntrades
    };
  }, { totalMatches: 0, wins: 0, losses: 0, draws: 0, totalCaramboles: 0, totalOpponentCaramboles: 0, totalEntrades: 0 });

  $: average = stats.totalEntrades > 0 ? (stats.totalCaramboles / stats.totalEntrades).toFixed(3) : '0.000';
  $: winPercentage = stats.totalMatches > 0 ? Math.round((stats.wins / stats.totalMatches) * 100) : 0;
</script>

{#if isOpen}
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div
    class="modal-backdrop"
    on:click={handleBackdropClick}
    on:keydown={handleKeydown}
    role="dialog"
    aria-modal="true"
    aria-labelledby="player-results-modal-title"
    tabindex="0"
  >
    <!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
    <div
      bind:this={modalElement}
      class="modal-content"
      on:keydown={trapFocus}
      role="document"
      tabindex="-1"
    >
      <div class="modal-header">
        <h2 id="player-results-modal-title" class="modal-title">
          Resultats de {playerName}
        </h2>
        <button
          type="button"
          class="close-button"
          on:click={closeModal}
          aria-label="Tancar resultats del jugador"
        >
          <svg class="close-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>

      <div class="modal-body">
        {#if loading}
          <div class="text-center py-12">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <p class="mt-2 text-gray-600">Carregant resultats...</p>
          </div>
        {:else if error}
          <div class="bg-red-50 border border-red-200 rounded-lg p-6">
            <h3 class="text-lg font-medium text-red-800 mb-2">Error</h3>
            <p class="text-red-600">{error}</p>
          </div>
        {:else if matches.length === 0}
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha resultats disponibles</h3>
            <p class="mt-1 text-sm text-gray-500">Aquest jugador encara no té partides jugades.</p>
          </div>
        {:else}
          <!-- Statistics Summary - Compact -->
          <div class="stats-compact">
            <div class="stat-row">
              <div class="stat-item">
                <span class="stat-number">{stats.totalMatches}</span>
                <span class="stat-text">PJ</span>
              </div>
              <div class="stat-item stat-win">
                <span class="stat-number">{stats.wins}</span>
                <span class="stat-text">G</span>
              </div>
              {#if stats.draws > 0}
              <div class="stat-item stat-draw">
                <span class="stat-number">{stats.draws}</span>
                <span class="stat-text">E</span>
              </div>
              {/if}
              <div class="stat-item stat-loss">
                <span class="stat-number">{stats.losses}</span>
                <span class="stat-text">P</span>
              </div>
              <div class="stat-item stat-primary">
                <span class="stat-number">{average}</span>
                <span class="stat-text">Mitj</span>
              </div>
              <div class="stat-item">
                <span class="stat-number">{stats.totalCaramboles}</span>
                <span class="stat-text">Car</span>
              </div>
            </div>
          </div>

          <!-- Matches List -->
          <div class="matches-section">
            <h3 class="matches-title">Historial de Partides</h3>
            <div class="matches-list">
              {#each matches as match (match.id)}
                {@const result = playerNumeroSoci ? getMatchResult(match, playerNumeroSoci) : 'draw'}
                {@const opponentName = playerNumeroSoci ? getOpponentName(match, playerNumeroSoci) : ''}
                {@const playerCaramboles = playerNumeroSoci ? getPlayerCaramboles(match, playerNumeroSoci) : 0}
                {@const opponentCaramboles = playerNumeroSoci ? getOpponentCaramboles(match, playerNumeroSoci) : 0}
                {@const opponentIncompareixenca = playerNumeroSoci ? getOpponentIncompareixenca(match, playerNumeroSoci) : false}
                {@const playerEntrades = playerNumeroSoci ? getPlayerEntrades(match, playerNumeroSoci) : 0}

                <div class="match-card-compact {result === 'win' ? 'match-win' : result === 'loss' ? 'match-loss' : 'match-draw'}">
                  <div class="match-left">
                    <div class="match-date-compact">{formatDate(match.data_programada)}</div>
                    <div class="match-opponent-compact">
                      vs {opponentName}
                      {#if opponentIncompareixenca}
                        <span class="incompareixenca-badge">No presentat</span>
                      {/if}
                    </div>
                  </div>

                  <div class="match-center">
                    <div class="match-score-compact">
                      <span class="score-compact {result === 'win' ? 'score-winner' : ''}">{playerCaramboles}</span>
                      <span class="score-sep">-</span>
                      <span class="score-compact {result === 'loss' ? 'score-winner' : ''}">{opponentCaramboles}</span>
                    </div>
                    <div class="match-entrades-compact">{playerEntrades} ent.</div>
                  </div>

                  <div class="match-right">
                    <div class="match-badge-compact {result === 'win' ? 'badge-win' : result === 'loss' ? 'badge-loss' : 'badge-draw'}">
                      {result === 'win' ? 'G' : result === 'loss' ? 'P' : 'E'}
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>

      <div class="modal-footer">
        <button
          type="button"
          class="done-button"
          on:click={closeModal}
        >
          Tancar
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.6);
    z-index: 10000;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }

  .modal-content {
    background: white;
    border-radius: 16px;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
    max-width: 800px;
    width: 100%;
    max-height: 90vh;
    overflow-y: auto;
    position: relative;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 24px 24px 0 24px;
    border-bottom: 1px solid #e5e7eb;
    margin-bottom: 24px;
    padding-bottom: 16px;
    position: sticky;
    top: 0;
    background: white;
    z-index: 10;
  }

  .modal-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
    margin: 0;
  }

  .close-button {
    padding: 8px;
    background: none;
    border: none;
    cursor: pointer;
    color: #6b7280;
    border-radius: 6px;
    transition: all 0.2s ease;
    min-height: 40px;
    min-width: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-button:hover {
    background: #f3f4f6;
    color: #374151;
  }

  .close-button:focus-visible {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }

  .close-icon {
    width: 20px;
    height: 20px;
  }

  .modal-body {
    padding: 0 24px 24px 24px;
  }

  /* Compact Stats */
  .stats-compact {
    background: linear-gradient(to right, #f9fafb, #f3f4f6);
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 20px;
  }

  .stat-row {
    display: flex;
    justify-content: space-around;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .stat-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    min-width: 60px;
  }

  .stat-number {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
    line-height: 1;
  }

  .stat-text {
    font-size: 0.75rem;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
  }

  .stat-win .stat-number {
    color: #16a34a;
  }

  .stat-loss .stat-number {
    color: #dc2626;
  }

  .stat-draw .stat-number {
    color: #f59e0b;
  }

  .stat-primary .stat-number {
    color: #7c3aed;
  }

  .matches-section {
    margin-top: 24px;
  }

  .matches-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 16px;
  }

  .matches-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  /* Compact Match Cards */
  .match-card-compact {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-left: 4px solid #e5e7eb;
    background: white;
    border-radius: 8px;
    padding: 12px 16px;
    transition: all 0.2s ease;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .match-card-compact:hover {
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    transform: translateX(2px);
  }

  .match-card-compact.match-win {
    border-left-color: #22c55e;
    background: linear-gradient(to right, #f0fdf4, #ffffff);
  }

  .match-card-compact.match-loss {
    border-left-color: #ef4444;
    background: linear-gradient(to right, #fef2f2, #ffffff);
  }

  .match-card-compact.match-draw {
    border-left-color: #f59e0b;
    background: linear-gradient(to right, #fefce8, #ffffff);
  }

  .match-left {
    flex: 1;
    min-width: 0;
  }

  .match-date-compact {
    font-size: 0.75rem;
    color: #6b7280;
    font-weight: 500;
    margin-bottom: 2px;
  }

  .match-opponent-compact {
    font-size: 0.875rem;
    font-weight: 600;
    color: #1f2937;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .incompareixenca-badge {
    display: inline-flex;
    align-items: center;
    padding: 2px 6px;
    margin-left: 6px;
    font-size: 0.75rem;
    font-weight: 500;
    border-radius: 4px;
    background-color: #fee2e2;
    color: #991b1b;
  }

  .match-center {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 0 16px;
  }

  .match-score-compact {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .score-compact {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
    min-width: 32px;
    text-align: center;
  }

  .score-compact.score-winner {
    color: #16a34a;
  }

  .score-sep {
    font-size: 1.25rem;
    font-weight: 700;
    color: #9ca3af;
  }

  .match-entrades-compact {
    font-size: 0.75rem;
    color: #6b7280;
    white-space: nowrap;
  }

  .match-right {
    display: flex;
    align-items: center;
  }

  .match-badge-compact {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.875rem;
    font-weight: 700;
    color: white;
  }

  .match-badge-compact.badge-win {
    background: #22c55e;
  }

  .match-badge-compact.badge-loss {
    background: #ef4444;
  }

  .match-badge-compact.badge-draw {
    background: #f59e0b;
  }

  .modal-footer {
    padding: 16px 24px;
    border-top: 1px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
    position: sticky;
    bottom: 0;
    background: white;
  }

  .done-button {
    background: #3b82f6;
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    min-height: 48px;
  }

  .done-button:hover {
    background: #2563eb;
  }

  .done-button:focus-visible {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }

  /* Mobile adjustments */
  @media (max-width: 640px) {
    .modal-backdrop {
      padding: 8px;
    }

    .modal-content {
      border-radius: 12px;
      max-height: 95vh;
    }

    .modal-header {
      padding: 16px 16px 0 16px;
      padding-bottom: 12px;
    }

    .modal-title {
      font-size: 1.125rem;
    }

    .modal-body {
      padding: 0 16px 16px 16px;
    }

    .stats-compact {
      padding: 12px;
      margin-bottom: 16px;
    }

    .stat-row {
      gap: 4px;
    }

    .stat-item {
      min-width: 50px;
    }

    .stat-number {
      font-size: 1.25rem;
    }

    .stat-text {
      font-size: 0.625rem;
    }

    .matches-title {
      font-size: 0.875rem;
      margin-bottom: 12px;
    }

    .match-card-compact {
      padding: 10px 12px;
    }

    .match-center {
      padding: 0 8px;
    }

    .score-compact {
      font-size: 1.25rem;
      min-width: 28px;
    }

    .match-badge-compact {
      width: 28px;
      height: 28px;
      font-size: 0.75rem;
    }

    .modal-footer {
      padding: 12px 16px;
    }
  }

  /* Respect reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .close-button,
    .done-button,
    .match-card-compact {
      transition: none;
    }

    .match-card-compact:hover {
      transform: none;
    }
  }
</style>
