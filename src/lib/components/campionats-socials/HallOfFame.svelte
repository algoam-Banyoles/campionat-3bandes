<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  let loading = true;
  let error: string | null = null;
  let selectedSeason = '';
  
  // Dades
  let winners: any[] = [];
  let allPlayers: any[] = [];
  let seasons: string[] = [];

  onMount(() => {
    loadData();
  });

  async function loadData() {
    loading = true;
    error = null;

    try {
      // Carregar guanyadors i jugadors
      await Promise.all([
        loadWinners(),
        loadAllPlayers(),
        loadSeasons()
      ]);
    } catch (e: any) {
      console.error('Error carregant dades:', e);
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function loadSeasons() {
    const { data, error: seasonsError } = await supabase
      .from('events')
      .select('temporada')
      .eq('tipus_competicio', 'lliga_social')
      .order('temporada', { ascending: false });

    if (seasonsError) throw seasonsError;
    
    // Obtenir temporades úniques
    const uniqueSeasons = [...new Set(data?.map(e => e.temporada))];
    seasons = uniqueSeasons.filter(s => s) as string[];
    
    // Establir per defecte la segona temporada (la temporada anterior)
    if (seasons.length > 1) {
      selectedSeason = seasons[1];
    } else if (seasons.length === 1) {
      selectedSeason = seasons[0];
    }
  }

  async function loadWinners() {
    let query = supabase
      .from('classificacions')
      .select(`
        id,
        event_id,
        player_id,
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        caramboles_favor,
        caramboles_contra,
        mitjana_particular,
        events!inner (
          id,
          nom,
          temporada,
          modalitat,
          data_inici,
          data_fi
        ),
        categories!inner (
          id,
          nom,
          ordre_categoria
        ),
        players!inner (
          id,
          numero_soci,
          socis!inner (
            nom,
            cognoms
          )
        )
      `)
      .lte('posicio', 3)
      .not('events.data_fi', 'is', null);

    // Aplicar filtre per temporada si està seleccionat
    if (selectedSeason) {
      query = query.eq('events.temporada', selectedSeason);
    }

    const { data, error: winnersError } = await query;

    if (winnersError) throw winnersError;
    
    // Ordenar manualment per temporada i data
    winners = (data || []).sort((a: any, b: any) => {
      // Primer per temporada (descendent)
      const tempA = a.events.temporada || '';
      const tempB = b.events.temporada || '';
      if (tempA !== tempB) {
        return tempB.localeCompare(tempA);
      }
      // Després per data de fi (descendent)
      const dateA = a.events.data_fi ? new Date(a.events.data_fi).getTime() : 0;
      const dateB = b.events.data_fi ? new Date(b.events.data_fi).getTime() : 0;
      return dateB - dateA;
    });
  }

  async function loadAllPlayers() {
    // Obtenir tots els jugadors que han participat en campionats socials
    const { data, error: playersError } = await supabase
      .from('inscripcions')
      .select(`
        soci_numero,
        socis (
          nom,
          cognoms,
          numero_soci
        ),
        events (
          temporada,
          modalitat
        )
      `)
      .eq('events.tipus_competicio', 'lliga_social');

    if (playersError) throw playersError;

    // Crear un conjunt únic de jugadors
    const uniquePlayers = new Map();
    
    (data || []).forEach((inscripcio: any) => {
      const key = inscripcio.soci_numero;
      if (!uniquePlayers.has(key)) {
        uniquePlayers.set(key, {
          numero_soci: inscripcio.soci_numero,
          nom: inscripcio.socis?.nom || '',
          cognoms: inscripcio.socis?.cognoms || '',
          participations: []
        });
      }
      
      // Afegir participació
      if (inscripcio.events) {
        uniquePlayers.get(key).participations.push({
          temporada: inscripcio.events?.temporada || '',
          modalitat: inscripcio.events?.modalitat || ''
        });
      }
    });

    allPlayers = Array.from(uniquePlayers.values())
      .map(player => ({
        ...player,
        totalParticipations: player.participations.length,
        uniqueSeasons: [...new Set(player.participations.map((p: any) => p.temporada))].length
      }))
      .sort((a, b) => b.totalParticipations - a.totalParticipations);
  }

  // Recarregar quan canvien els filtres
  $: if (selectedSeason !== undefined) {
    loadWinners();
  }

  // Agrupar guanyadors per torneig
  $: winnersByEvent = winners.reduce((acc: any, winner: any) => {
    const eventKey = `${winner.event_id}-${winner.categories.id}`;
    if (!acc[eventKey]) {
      acc[eventKey] = {
        event: winner.events,
        category: winner.categories,
        winners: []
      };
    }
    acc[eventKey].winners.push(winner);
    return acc;
  }, {});

  function getModalityLabel(modality: string) {
    const modalities: Record<string, string> = {
      'tres_bandes': '3 Bandes',
      'lliure': 'Lliure',
      'banda': 'Banda'
    };
    return modalities[modality] || modality;
  }

  function getMedalEmoji(position: number) {
    if (position === 1) return '🥇';
    if (position === 2) return '🥈';
    if (position === 3) return '🥉';
    return '';
  }
</script>

<div class="space-y-6">
  <!-- Filtres -->
  <div class="bg-white shadow rounded-lg p-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4">Filtres</h3>
    <div class="grid grid-cols-1 gap-4">
      <div>
        <label for="season-filter" class="block text-sm font-medium text-gray-700 mb-2">
          Temporada
        </label>
        <select
          id="season-filter"
          bind:value={selectedSeason}
          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        >
          <option value="">Totes les temporades</option>
          {#each seasons as season}
            <option value={season}>{season}</option>
          {/each}
        </select>
      </div>
    </div>
  </div>

  {#if loading}
    <div class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant dades...</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4">
      <p class="text-red-800">{error}</p>
    </div>
  {:else}
    <!-- Quadre d'Honor -->
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-xl font-bold text-gray-900 mb-6 flex items-center">
        🏆 Quadre d'Honor
      </h3>

      {#if Object.keys(winnersByEvent).length === 0}
        <p class="text-gray-500 text-center py-8">No hi ha classificacions disponibles amb els filtres seleccionats.</p>
      {:else}
        <div class="space-y-8">
          {#each Object.entries(winnersByEvent) as [_, eventData]}
            {@const typedEventData = eventData as any}
            <div class="border border-gray-200 rounded-lg p-4">
              <div class="mb-4">
                <h4 class="font-bold text-lg text-gray-900">{typedEventData.event.nom}</h4>
                <div class="flex flex-wrap gap-2 mt-2">
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    {getModalityLabel(typedEventData.event.modalitat)}
                  </span>
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    Temporada {typedEventData.event.temporada}
                  </span>
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    {typedEventData.category.nom}
                  </span>
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                {#each typedEventData.winners.sort((a: any, b: any) => a.posicio - b.posicio) as winner}
                  <div class="bg-gradient-to-br {winner.posicio === 1 ? 'from-yellow-50 to-yellow-100 border-yellow-300' : winner.posicio === 2 ? 'from-gray-50 to-gray-100 border-gray-300' : 'from-orange-50 to-orange-100 border-orange-300'} border-2 rounded-lg p-4 text-center">
                    <div class="text-4xl mb-2">{getMedalEmoji(winner.posicio)}</div>
                    <div class="font-bold text-lg text-gray-900">
                      {winner.players.socis.nom} {winner.players.socis.cognoms}
                    </div>
                    <div class="text-sm text-gray-600 mt-1">
                      {winner.posicio === 1 ? '1r' : winner.posicio === 2 ? '2n' : '3r'} lloc
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Llistat de tots els jugadors -->
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-xl font-bold text-gray-900 mb-6 flex items-center">
        👥 Tots els Participants ({allPlayers.length})
      </h3>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Jugador
              </th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Núm. Soci
              </th>
              <th scope="col" class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                Participacions
              </th>
              <th scope="col" class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                Temporades
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each allPlayers as player}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {player.cognoms}, {player.nom}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {player.numero_soci}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
                  {player.totalParticipations}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
                  {player.uniqueSeasons}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  {/if}
</div>
