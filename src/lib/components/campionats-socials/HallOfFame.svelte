<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { fkOne, normalizeSociFromFK } from '$lib/utils/supabaseJoins';

  let loading = true;
  let error: string | null = null;
  let selectedSeason = '';
  
  // Dades
  let winners: any[] = [];
  let allPlayers: any[] = [];
  let seasons: string[] = [];
  let lastLoadedSeasonKey: string | null = null;

  function parseSeason(value: string): { start: string; end: string } | null {
    const match = value?.trim().match(/^(\d{4})\D+(\d{4})$/);
    if (!match) return null;
    return { start: match[1], end: match[2] };
  }

  function normalizeSeason(value: string): string {
    const parsed = parseSeason(value);
    return parsed ? `${parsed.start}/${parsed.end}` : value?.trim() ?? '';
  }

  function seasonVariants(value: string): string[] {
    const trimmed = value?.trim();
    if (!trimmed) return [];
    const parsed = parseSeason(trimmed);
    if (!parsed) return [trimmed];
    return [`${parsed.start}/${parsed.end}`, `${parsed.start}-${parsed.end}`];
  }

  function getCurrentSeasonLabel(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const startYear = month >= 8 ? year : year - 1;
    return `${startYear}/${startYear + 1}`;
  }

  async function reloadFilteredData(force = false) {
    const seasonKey = selectedSeason ?? '';
    if (!force && seasonKey === lastLoadedSeasonKey) return;
    lastLoadedSeasonKey = seasonKey;

    await Promise.all([
      loadWinners(),
      loadAllPlayers()
    ]);
  }

  onMount(() => {
    loadData();
  });

  async function loadData() {
    loading = true;
    error = null;

    try {
      await loadSeasons();
      await reloadFilteredData(true);
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
    
    // Obtenir temporades úniques normalitzades (accepta 2025/2026 i 2025-2026)
    const uniqueSeasons = new Set<string>();
    (data || []).forEach((event: any) => {
      if (event?.temporada) {
        uniqueSeasons.add(normalizeSeason(event.temporada));
      }
    });
    seasons = Array.from(uniqueSeasons).sort((a, b) => b.localeCompare(a));
    
    // Seleccionar per defecte la temporada en curs
    if (seasons.length > 0) {
      const currentSeason = getCurrentSeasonLabel();
      selectedSeason = seasons.includes(currentSeason) ? currentSeason : seasons[0];
    }
  }

  async function loadWinners() {
    let query = supabase
      .from('classificacions')
      .select(`
        id,
        event_id,
        soci_numero,
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
        socis:socis!classificacions_soci_numero_fkey (
          numero_soci,
          nom,
          cognoms
        )
      `)
      .lte('posicio', 3)
      .eq('events.estat_competicio', 'finalitzat');

    // Aplicar filtre per temporada si està seleccionat
    if (selectedSeason) {
      query = query.in('events.temporada', seasonVariants(selectedSeason));
    }

    const { data, error: winnersError } = await query;

    if (winnersError) throw winnersError;
    
    // Normalitzar joins (events/categories poden venir com a array o objecte)
    // i ordenar per temporada (desc) + data fi (desc).
    winners = (data || [])
      .map((w: any) => ({
        ...w,
        events: fkOne(w.events),
        categories: fkOne(w.categories)
      }))
      .sort((a: any, b: any) => {
        const tempA = a.events?.temporada || '';
        const tempB = b.events?.temporada || '';
        if (tempA !== tempB) {
          return tempB.localeCompare(tempA);
        }
        const dateA = a.events?.data_fi ? new Date(a.events.data_fi).getTime() : 0;
        const dateB = b.events?.data_fi ? new Date(b.events.data_fi).getTime() : 0;
        return dateB - dateA;
      });
  }

  async function loadAllPlayers() {
    // Obtenir tots els jugadors que han participat en campionats socials
    let query = supabase
      .from('inscripcions')
      .select(`
        event_id,
        soci_numero,
        socis (
          nom,
          cognoms,
          numero_soci
        ),
        events (
          id,
          temporada,
          modalitat
        )
      `)
      .eq('events.tipus_competicio', 'lliga_social')
      .eq('events.estat_competicio', 'finalitzat');

    // Aplicar filtre de temporada al llistat de participants
    if (selectedSeason) {
      query = query.in('events.temporada', seasonVariants(selectedSeason));
    }

    const { data, error: playersError } = await query;

    if (playersError) throw playersError;

    // Crear un conjunt únic de jugadors
    const uniquePlayers = new Map();
    
    (data || []).forEach((inscripcio: any) => {
      const key = inscripcio.soci_numero;
      const soci = normalizeSociFromFK(inscripcio.socis);
      const evt = fkOne(inscripcio.events) as any;
      if (!uniquePlayers.has(key)) {
        uniquePlayers.set(key, {
          numero_soci: inscripcio.soci_numero,
          nom: soci.nom || '',
          cognoms: soci.cognoms || '',
          participations: [],
          participationKeys: new Set<string>()
        });
      }

      // Afegir participació
      if (evt) {
        const participation = {
          temporada: evt?.temporada || '',
          modalitat: evt?.modalitat || ''
        };

        const eventKey = String(inscripcio.event_id || evt?.id || `${participation.temporada}-${participation.modalitat}`);
        const player = uniquePlayers.get(key);

        if (!player.participationKeys.has(eventKey)) {
          player.participationKeys.add(eventKey);
          player.participations.push(participation);
        }
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
  $: if (selectedSeason !== undefined && seasons.length > 0) {
    void reloadFilteredData();
  }

  // Agrupar guanyadors per torneig (events/categories ja normalitzats a loadWinners)
  $: winnersByEvent = winners.reduce((acc: any, winner: any) => {
    const eventKey = `${winner.event_id}-${winner.categories?.id ?? ''}`;
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

<div class="space-y-4">
  <!-- Filtres -->
  <div class="bg-white shadow rounded-lg p-4">
    <h3 class="text-base font-semibold text-gray-900 mb-3">Filtres</h3>
    <div class="grid grid-cols-1 gap-3">
      <div>
        <label for="season-filter" class="block text-xs font-medium text-gray-700 mb-1">
          Temporada
        </label>
        <select
          id="season-filter"
          bind:value={selectedSeason}
          class="block w-full rounded-md border-gray-300 text-sm py-1.5 focus:border-blue-500 focus:ring-blue-500"
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
    <div class="text-center py-8">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant dades...</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-3">
      <p class="text-red-800 text-sm">{error}</p>
    </div>
  {:else}
    <!-- Quadre d'Honor -->
    <div class="bg-white shadow rounded-lg p-4">
      <h3 class="text-lg font-bold text-gray-900 mb-4 flex items-center">
        🏆 Quadre d'Honor
      </h3>

      {#if Object.keys(winnersByEvent).length === 0}
        <p class="text-gray-500 text-center py-6 text-sm">No hi ha classificacions disponibles amb els filtres seleccionats.</p>
      {:else}
        <div class="space-y-4">
          {#each Object.entries(winnersByEvent) as [_, eventData]}
            {@const typedEventData = eventData as any}
            <div class="border border-gray-200 rounded-lg p-3">
              <div class="mb-3">
                <h4 class="font-bold text-base text-gray-900">{typedEventData.event.nom}</h4>
                <div class="flex flex-wrap gap-1.5 mt-1.5">
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-medium bg-blue-100 text-blue-800">
                    {getModalityLabel(typedEventData.event.modalitat)}
                  </span>
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-medium bg-gray-100 text-gray-800">
                    Temporada {typedEventData.event.temporada}
                  </span>
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-medium bg-green-100 text-green-800">
                    {typedEventData.category.nom}
                  </span>
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-2">
                {#each typedEventData.winners.sort((a: any, b: any) => a.posicio - b.posicio) as winner}
                  {@const winnerSoci = normalizeSociFromFK(winner.socis)}
                  <div class="bg-gradient-to-br {winner.posicio === 1 ? 'from-yellow-50 to-yellow-100 border-yellow-300' : winner.posicio === 2 ? 'from-gray-50 to-gray-100 border-gray-300' : 'from-orange-50 to-orange-100 border-orange-300'} border rounded-lg p-3 text-center">
                    <div class="text-3xl mb-1">{getMedalEmoji(winner.posicio)}</div>
                    <div class="font-bold text-base text-gray-900 leading-tight">
                      {winnerSoci.nom ?? ''} {winnerSoci.cognoms ?? ''}
                    </div>
                    <div class="text-xs text-gray-600 mt-1">
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
    <div class="bg-white shadow rounded-lg p-4">
      <h3 class="text-lg font-bold text-gray-900 mb-4 flex items-center">
        👥 Tots els Participants ({allPlayers.length})
      </h3>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="px-3 py-2 text-left text-[11px] font-medium text-gray-500 uppercase tracking-wider">
                Jugador
              </th>
              <th scope="col" class="px-3 py-2 text-left text-[11px] font-medium text-gray-500 uppercase tracking-wider">
                Núm. Soci
              </th>
              <th scope="col" class="px-3 py-2 text-center text-[11px] font-medium text-gray-500 uppercase tracking-wider">
                Participacions
              </th>
              <th scope="col" class="px-3 py-2 text-center text-[11px] font-medium text-gray-500 uppercase tracking-wider">
                Temporades
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each allPlayers as player}
              <tr class="hover:bg-gray-50">
                <td class="px-3 py-2 whitespace-nowrap text-sm font-medium text-gray-900">
                  {player.cognoms}, {player.nom}
                </td>
                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-500">
                  {player.numero_soci}
                </td>
                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-500 text-center">
                  {player.totalParticipations}
                </td>
                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-500 text-center">
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
