<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import SociFoto from '$lib/components/admin/SociFoto.svelte';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

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
    jugador1_soci_numero: number;
    jugador2_soci_numero: number;
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
      // Usem la RPC pública (funciona per anònims i autenticats, evita errors de RLS).
      const { data: allInscriptions, error: allInscriptionsError } = await supabase
        .rpc('get_inscripcions_with_socis', { p_event_id: eventId });

      if (allInscriptionsError) throw allInscriptionsError;

      const playerInscription = (allInscriptions || []).find(
        (item: any) => item.soci_numero === playerNumeroSoci
      );

      if (playerInscription?.estat_jugador === 'retirat' || playerInscription?.eliminat_per_incompareixences) {
        return;
      }

      const withdrawnNumbers = new Set(
        (allInscriptions || [])
          .filter((item: any) => item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences)
          .map((item: any) => item.soci_numero)
          .filter((numero: any) => typeof numero === 'number')
      );

      // Fase 5c-S2c-2: filtrem directament per soci_numero, sense passar
      // per la taula `players`.
      // IMPORTANT: no encadenem dos `.or()` — a supabase-js només sobreviu
      // el darrer. En comptes d'això, el filtre de partida_anullada l'expressem
      // amb `.not('partida_anullada', 'is', true)` (equival a: NULL o false).
      let query = supabase
        .from('calendari_partides')
        .select(`
          id,
          data_programada,
          caramboles_jugador1,
          caramboles_jugador2,
          entrades,
          jugador1_soci_numero,
          jugador2_soci_numero,
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
        .in('estat', ['jugada', 'validat'])
        .not('partida_anullada', 'is', true)
        .not('caramboles_jugador1', 'is', null)
        .not('caramboles_jugador2', 'is', null)
        .or(`jugador1_soci_numero.eq.${playerNumeroSoci},jugador2_soci_numero.eq.${playerNumeroSoci}`)
        .order('data_programada', { ascending: false });

      // Filter by category if specified
      if (categoriaId) {
        query = query.eq('categoria_id', categoriaId);
      }

      const { data: matchesData, error: matchesError } = await query;

      if (matchesError) throw matchesError;

      // Fase 5c-S2c-2: socis directes per soci_numero
      const numerosSoci = [...new Set([
        ...((matchesData || []).map((m: any) => m.jugador1_soci_numero) as number[]),
        ...((matchesData || []).map((m: any) => m.jugador2_soci_numero) as number[])
      ].filter((n: any) => typeof n === 'number'))];

      const { data: socisData, error: socisError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .in('numero_soci', numerosSoci);

      if (socisError) {
        console.warn('Error fetching socis:', socisError);
      }

      const playersMap = new Map<number, any>();
      socisData?.forEach((s: any) => playersMap.set(s.numero_soci, { nom: s.nom, cognoms: s.cognoms, numero_soci: s.numero_soci }));

      // Filtrar partides amb jugadors retirats
      const filteredMatches = (matchesData || []).filter((match: any) => {
        if (withdrawnNumbers.size === 0) return true;
        return !withdrawnNumbers.has(match.jugador1_soci_numero)
            && !withdrawnNumbers.has(match.jugador2_soci_numero);
      });

      matches = filteredMatches.map((match: any) => {
        const jugador1 = playersMap.get(match.jugador1_soci_numero);
        const jugador2 = playersMap.get(match.jugador2_soci_numero);

        return {
          ...match,
          jugador1_nom: formatPlayerName(jugador1?.nom, jugador1?.cognoms, jugador1?.numero_soci),
          jugador2_nom: formatPlayerName(jugador2?.nom, jugador2?.cognoms, jugador2?.numero_soci),
          jugador1_numero_soci: jugador1?.numero_soci,
          jugador2_numero_soci: jugador2?.numero_soci
        };
      });

    } catch (e: any) {
      console.error('Error loading player matches:', e);
      error = e.message || 'Error carregant els resultats del jugador';
    } finally {
      loading = false;
    }
  }

  function formatPlayerName(nom: string | undefined, cognoms: string | undefined, _numeroSoci?: number | undefined) {
    return formatarNomJugador(`${nom ?? ''} ${cognoms ?? ''}`.trim()) || 'Sense nom';
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

  function getOpponentNumeroSoci(match: any, playerSoci: number): number {
    return match.jugador1_numero_soci === playerSoci
      ? match.jugador2_numero_soci
      : match.jugador1_numero_soci;
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
        <div class="flex items-center gap-3">
          <SociFoto numeroSoci={playerNumeroSoci} size="lg" alt={playerName} />
          <h2 id="player-results-modal-title" class="modal-title">
            Resultats de
            {#if playerNumeroSoci}
              <a href={`/jugador/${playerNumeroSoci}`} class="player-link">{playerName}</a>
            {:else}
              {playerName}
            {/if}
          </h2>
        </div>
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
          <div class="state-block">
            <p class="state-loading">Carregant resultats…</p>
          </div>
        {:else if error}
          <div class="state-error">
            <h3 class="state-error-title">Error</h3>
            <p>{error}</p>
          </div>
        {:else if matches.length === 0}
          <div class="state-block">
            <h3 class="state-empty-title">No hi ha resultats disponibles</h3>
            <p class="state-empty-sub">Aquest jugador encara no té partides jugades.</p>
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
                {@const opponentNumeroSoci = playerNumeroSoci ? getOpponentNumeroSoci(match, playerNumeroSoci) : null}
                {@const playerCaramboles = playerNumeroSoci ? getPlayerCaramboles(match, playerNumeroSoci) : 0}
                {@const opponentCaramboles = playerNumeroSoci ? getOpponentCaramboles(match, playerNumeroSoci) : 0}
                {@const opponentIncompareixenca = playerNumeroSoci ? getOpponentIncompareixenca(match, playerNumeroSoci) : false}
                {@const playerEntrades = playerNumeroSoci ? getPlayerEntrades(match, playerNumeroSoci) : 0}

                <div class="match-card-compact {result === 'win' ? 'match-win' : result === 'loss' ? 'match-loss' : 'match-draw'}">
                  <div class="match-left">
                    <div class="match-date-compact">{formatDate(match.data_programada)}</div>
                    <div class="match-opponent-compact flex items-center gap-2">
                      <span>vs</span>
                      <SociFoto numeroSoci={opponentNumeroSoci} size="xs" alt={opponentName} />
                      <span>{opponentName}</span>
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
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
    max-width: 800px;
    width: 100%;
    max-height: 90vh;
    overflow-y: auto;
    position: relative;
    font-family: var(--font-sans);
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 24px 24px 0 24px;
    border-bottom: 1px solid var(--rule);
    margin-bottom: 24px;
    padding-bottom: 16px;
    position: sticky;
    top: 0;
    background: var(--paper-elevated);
    z-index: 10;
  }

  .modal-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--ink);
    margin: 0;
  }
  .modal-title .player-link {
    color: var(--ink);
    text-decoration: none;
    border-bottom: 1px solid currentColor;
    transition: color 0.15s ease;
  }
  .modal-title .player-link:hover {
    color: var(--accent, #a30b1e);
  }

  .close-button {
    padding: 8px;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--ink-3);
    transition: color 0.15s ease;
    min-height: 40px;
    min-width: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-button:hover {
    color: var(--ink);
  }

  .close-button:focus-visible {
    outline: 2px solid var(--ink);
    outline-offset: 2px;
  }

  .close-icon {
    width: 20px;
    height: 20px;
  }

  .modal-body {
    padding: 0 24px 24px 24px;
  }

  /* Estats: loading / error / empty */
  .state-block {
    text-align: center;
    padding: 2.5rem 1rem;
  }
  .state-loading {
    color: var(--ink-3);
    font-size: 0.9375rem;
    margin: 0;
  }
  .state-empty-title {
    margin: 0 0 0.4rem;
    font-size: 1rem;
    font-weight: 700;
    color: var(--ink);
  }
  .state-empty-sub {
    margin: 0;
    color: var(--ink-3);
    font-size: 0.875rem;
  }
  .state-error {
    border: 1px solid var(--accent);
    background: var(--paper);
    padding: 1.25rem 1.5rem;
    color: var(--accent);
  }
  .state-error-title {
    margin: 0 0 0.4rem;
    font-size: 1rem;
    font-weight: 700;
  }
  .state-error p { margin: 0; }

  /* Compact Stats */
  .stats-compact {
    background: var(--paper);
    border: 1px solid var(--rule);
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
    color: var(--ink);
    line-height: 1;
  }

  .stat-text {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ink-3);
    text-transform: uppercase;
  }

  .stat-win .stat-number {
    color: var(--green);
  }

  .stat-loss .stat-number {
    color: var(--accent);
  }

  .stat-draw .stat-number {
    color: var(--amber);
  }

  .stat-primary .stat-number {
    color: var(--blue);
  }

  .matches-section {
    margin-top: 24px;
  }

  .matches-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--ink);
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
    border: 1px solid var(--rule);
    border-left: 3px solid var(--rule-strong);
    background: var(--paper-elevated);
    padding: 12px 16px;
    transition: border-color 0.15s ease;
  }

  .match-card-compact:hover {
    border-color: var(--ink);
  }

  .match-card-compact.match-win {
    border-left-color: var(--green);
  }

  .match-card-compact.match-loss {
    border-left-color: var(--accent);
  }

  .match-card-compact.match-draw {
    border-left-color: var(--amber);
  }

  .match-left {
    flex: 1;
    min-width: 0;
  }

  .match-date-compact {
    font-size: 0.75rem;
    color: var(--ink-3);
    font-weight: 500;
    margin-bottom: 2px;
  }

  .match-opponent-compact {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .incompareixenca-badge {
    display: inline-flex;
    align-items: center;
    padding: 2px 6px;
    margin-left: 6px;
    font-size: 0.6875rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    background: var(--paper);
    color: var(--accent);
    border: 1px solid var(--accent);
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
    color: var(--ink);
    min-width: 32px;
    text-align: center;
  }

  .score-compact.score-winner {
    color: var(--green);
  }

  .score-sep {
    font-size: 1.25rem;
    font-weight: 700;
    color: var(--ink-3);
  }

  .match-entrades-compact {
    font-size: 0.75rem;
    color: var(--ink-3);
    white-space: nowrap;
  }

  .match-right {
    display: flex;
    align-items: center;
  }

  .match-badge-compact {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.875rem;
    font-weight: 700;
    color: var(--paper);
  }

  .match-badge-compact.badge-win {
    background: var(--green);
  }

  .match-badge-compact.badge-loss {
    background: var(--accent);
  }

  .match-badge-compact.badge-draw {
    background: var(--amber);
  }

  .modal-footer {
    padding: 16px 24px;
    border-top: 1px solid var(--rule);
    display: flex;
    justify-content: flex-end;
    position: sticky;
    bottom: 0;
    background: var(--paper-elevated);
  }

  .done-button {
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
    padding: 10px 20px;
    font-family: var(--font-sans);
    font-size: 0.9375rem;
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease;
    min-height: 44px;
  }

  .done-button:hover {
    opacity: 0.9;
  }

  .done-button:focus-visible {
    outline: 2px solid var(--ink);
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
