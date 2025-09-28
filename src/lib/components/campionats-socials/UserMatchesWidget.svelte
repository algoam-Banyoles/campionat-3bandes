<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  export let eventId: string = '';
  export let userEmail: string = '';
  export let eventName: string = '';

  let userMatches: any[] = [];
  let nextMatch: any = null;
  let recentMatches: any[] = [];
  let userStats = {
    played: 0,
    won: 0,
    lost: 0,
    carambolesMade: 0,
    carambolesReceived: 0,
    average: 0
  };
  let loading = false;
  let error: string | null = null;

  onMount(() => {
    if (eventId && userEmail) {
      loadUserMatches();
    }
  });

  $: if (eventId && userEmail) {
    loadUserMatches();
  }

  async function loadUserMatches() {
    loading = true;
    error = null;

    try {
      // First, get user's soci_numero from email
      const { data: userData, error: userError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .eq('email', userEmail)
        .single();

      if (userError) throw userError;
      if (!userData) {
        error = 'No s\'ha trobat l\'usuari';
        return;
      }

      const userSociNumber = userData.numero_soci;

      // Load user's matches for this event
      const { data: matchesData, error: matchesError } = await supabase
        .from('calendari_partides')
        .select(`
          id,
          categoria_id,
          data_programada,
          hora_inici,
          jugador1_id,
          jugador2_id,
          estat,
          taula_assignada,
          observacions_junta,
          jugador1:players!calendari_partides_jugador1_id_fkey (
            id,
            numero_soci,
            socis!players_numero_soci_fkey (
              nom,
              cognoms
            )
          ),
          jugador2:players!calendari_partides_jugador2_id_fkey (
            id,
            numero_soci,
            socis!players_numero_soci_fkey (
              nom,
              cognoms
            )
          ),
          categories!calendari_partides_categoria_id_fkey(
            id,
            nom,
            distancia_caramboles
          )
        `)
        .eq('event_id', eventId)
        .or(`jugador1.numero_soci.eq.${userSociNumber},jugador2.numero_soci.eq.${userSociNumber}`)
        .order('data_programada', { ascending: true })
        .order('hora_inici', { ascending: true });

      if (matchesError) throw matchesError;

      userMatches = matchesData || [];

      // Process matches to find next and recent ones
      const now = new Date();
      const upcoming = userMatches.filter(m =>
        m.data_programada && new Date(m.data_programada) >= now && m.estat !== 'completada'
      );
      const completed = userMatches.filter(m => m.estat === 'completada');

      nextMatch = upcoming.length > 0 ? upcoming[0] : null;
      recentMatches = completed.slice(-3).reverse(); // Last 3 matches, most recent first

      // Calculate user stats
      calculateUserStats(userMatches, userSociNumber);

    } catch (e) {
      console.error('Error loading user matches:', e);
      error = 'Error carregant les teves partides';
    } finally {
      loading = false;
    }
  }

  function calculateUserStats(matches: any[], userSociNumber: number) {
    const completedMatches = matches.filter(m => m.estat === 'completada');

    userStats.played = completedMatches.length;
    userStats.won = 0;
    userStats.lost = 0;
    userStats.carambolesMade = 0;
    userStats.carambolesReceived = 0;

    completedMatches.forEach(match => {
      const isPlayer1 = getPlayerSociNumber(match.jugador1) === userSociNumber;
      const userResult = isPlayer1 ? match.resultat_jugador1 : match.resultat_jugador2;
      const opponentResult = isPlayer1 ? match.resultat_jugador2 : match.resultat_jugador1;

      if (userResult !== null && opponentResult !== null) {
        userStats.carambolesMade += userResult;
        userStats.carambolesReceived += opponentResult;

        if (userResult > opponentResult) {
          userStats.won++;
        } else if (userResult < opponentResult) {
          userStats.lost++;
        }
      }
    });

    userStats.average = userStats.played > 0 ? userStats.carambolesMade / userStats.played : 0;
  }

  function getPlayerSociNumber(playerData: any): number {
    if (!playerData) return 0;

    if (typeof playerData === 'string') {
      try {
        const parsed = JSON.parse(playerData);
        return parsed.numero_soci || 0;
      } catch {
        return 0;
      }
    }

    return playerData.numero_soci || 0;
  }

  function formatPlayerName(playerData: any) {
    if (!playerData) return 'Jugador desconegut';

    if (typeof playerData === 'string') {
      try {
        const parsed = JSON.parse(playerData);
        return `${parsed.nom} ${parsed.cognoms}`;
      } catch {
        return playerData;
      }
    }

    // Nova estructura amb joins
    if (playerData.socis?.nom && playerData.socis?.cognoms) {
      return `${playerData.socis.nom} ${playerData.socis.cognoms}`;
    }

    // Fallback a estructura anterior
    return `${playerData.nom || 'N/A'} ${playerData.cognoms || ''}`;
  }

  function getOpponentName(match: any, userSociNumber: number) {
    const isPlayer1 = getPlayerSociNumber(match.jugador1) === userSociNumber;
    return formatPlayerName(isPlayer1 ? match.jugador2 : match.jugador1);
  }

  function getUserResult(match: any, userSociNumber: number) {
    const isPlayer1 = getPlayerSociNumber(match.jugador1) === userSociNumber;
    return isPlayer1 ? match.resultat_jugador1 : match.resultat_jugador2;
  }

  function getOpponentResult(match: any, userSociNumber: number) {
    const isPlayer1 = getPlayerSociNumber(match.jugador1) === userSociNumber;
    return isPlayer1 ? match.resultat_jugador2 : match.resultat_jugador1;
  }

  function getMatchResult(match: any, userSociNumber: number) {
    const userResult = getUserResult(match, userSociNumber);
    const opponentResult = getOpponentResult(match, userSociNumber);

    if (userResult === null || opponentResult === null) return null;

    if (userResult > opponentResult) return 'win';
    if (userResult < opponentResult) return 'loss';
    return 'tie';
  }

  function formatMatchDate(dateStr: string) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleDateString('ca-ES', {
      weekday: 'short',
      day: 'numeric',
      month: 'short'
    });
  }

  function formatMatchTime(timeStr: string) {
    if (!timeStr) return '';
    return timeStr.substring(0, 5); // HH:MM
  }

  function getResultColor(result: string | null) {
    if (result === 'win') return 'text-green-600';
    if (result === 'loss') return 'text-red-600';
    if (result === 'tie') return 'text-yellow-600';
    return 'text-gray-600';
  }

  function getResultIcon(result: string | null) {
    if (result === 'win') return '✅';
    if (result === 'loss') return '❌';
    if (result === 'tie') return '🤝';
    return '⏳';
  }

  function getWinPercentage() {
    if (userStats.played === 0) return 0;
    return Math.round((userStats.won / userStats.played) * 100);
  }

  $: userSociNumber = userEmail ? null : 0; // Will be loaded from database
</script>

{#if loading}
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="animate-pulse">
      <div class="h-4 bg-gray-200 rounded w-1/4 mb-4"></div>
      <div class="space-y-3">
        <div class="h-3 bg-gray-200 rounded"></div>
        <div class="h-3 bg-gray-200 rounded w-5/6"></div>
      </div>
    </div>
  </div>
{:else if error}
  <div class="bg-red-50 border border-red-200 rounded-lg p-4">
    <p class="text-red-600 text-sm">{error}</p>
  </div>
{:else if userMatches.length > 0}
  <div class="space-y-4">
    <!-- User stats summary -->
    <div class="bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-lg p-6">
      <h3 class="text-lg font-bold mb-4 flex items-center">
        <span class="mr-2">👤</span>
        Les Meves Partides - {eventName}
      </h3>

      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="text-center">
          <div class="text-2xl font-bold">{userStats.played}</div>
          <div class="text-blue-100 text-sm">Jugades</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-green-300">{userStats.won}</div>
          <div class="text-blue-100 text-sm">Guanyades</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-red-300">{userStats.lost}</div>
          <div class="text-blue-100 text-sm">Perdudes</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-yellow-300">{getWinPercentage()}%</div>
          <div class="text-blue-100 text-sm">Victòries</div>
        </div>
      </div>

      <div class="mt-4 pt-4 border-t border-blue-400">
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span class="text-blue-100">Caramboles fetes:</span>
            <span class="font-bold ml-1">{userStats.carambolesMade}</span>
          </div>
          <div>
            <span class="text-blue-100">Mitjana:</span>
            <span class="font-bold ml-1">{userStats.average.toFixed(2)}</span>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <!-- Next match -->
      {#if nextMatch}
        <div class="bg-white border border-gray-200 rounded-lg p-6">
          <h4 class="font-medium text-gray-900 mb-4 flex items-center">
            <span class="mr-2">🕒</span>
            Propera Partida
          </h4>

          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">Opponent:</span>
              <span class="font-medium">{getOpponentName(nextMatch, userSociNumber)}</span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">Data:</span>
              <span class="font-medium">{formatMatchDate(nextMatch.data_programada)}</span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">Hora:</span>
              <span class="font-medium">{formatMatchTime(nextMatch.hora_inici)}</span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">Categoria:</span>
              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                {nextMatch.categories?.nom || 'Sense categoria'}
              </span>
            </div>

            {#if nextMatch.taula_assignada}
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-600">Billar:</span>
                <span class="font-medium">Billar {nextMatch.taula_assignada}</span>
              </div>
            {/if}
          </div>

          <div class="mt-4 p-3 bg-blue-50 rounded-lg">
            <p class="text-sm text-blue-700 flex items-center">
              <span class="mr-2">💡</span>
              Recorda arribar 15 minuts abans de l'hora programada.
            </p>
          </div>
        </div>
      {/if}

      <!-- Recent matches -->
      <div class="bg-white border border-gray-200 rounded-lg p-6">
        <h4 class="font-medium text-gray-900 mb-4 flex items-center">
          <span class="mr-2">📊</span>
          Últimes Partides
        </h4>

        {#if recentMatches.length === 0}
          <p class="text-gray-500 text-sm">Encara no has jugat cap partida.</p>
        {:else}
          <div class="space-y-3">
            {#each recentMatches as match (match.id)}
              {@const result = getMatchResult(match, userSociNumber)}
              {@const userResult = getUserResult(match, userSociNumber)}
              {@const opponentResult = getOpponentResult(match, userSociNumber)}

              <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div class="flex-1">
                  <div class="flex items-center space-x-2">
                    <span class="text-lg">{getResultIcon(result)}</span>
                    <div>
                      <div class="font-medium text-sm {getResultColor(result)}">
                        vs {getOpponentName(match, userSociNumber)}
                      </div>
                      <div class="text-xs text-gray-500">
                        {formatMatchDate(match.data_programada)}
                      </div>
                    </div>
                  </div>
                </div>
                <div class="text-right">
                  <div class="font-mono text-sm">
                    <span class={result === 'win' ? 'font-bold text-green-600' : 'text-gray-700'}>
                      {userResult}
                    </span>
                    <span class="text-gray-400 mx-1">-</span>
                    <span class={result === 'loss' ? 'font-bold text-red-600' : 'text-gray-700'}>
                      {opponentResult}
                    </span>
                  </div>
                  <div class="text-xs text-gray-500">
                    {match.categories?.nom}
                  </div>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  </div>
{:else}
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="text-center">
      <svg class="mx-auto h-8 w-8 text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
      </svg>
      <h3 class="text-sm font-medium text-gray-900">No tens partides en aquest campionat</h3>
      <p class="mt-1 text-sm text-gray-500">Contacta amb l'administració per inscriure't.</p>
    </div>
  </div>
{/if}