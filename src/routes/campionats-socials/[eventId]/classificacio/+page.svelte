<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  let loading = true;
  let error: string | null = null;
  let event: any = null;
  let classificacio: any[] = [];

  const eventId = $page.params.eventId;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const competitionTypes = {
    'lliga_social': 'Campionat Social',
    'eliminatories': 'Eliminatòries'
  };

  onMount(async () => {
    try {
      loading = true;
      await loadEvent();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadEvent() {
    // Now we load everything through the API
    console.log('🔍 Loading event and classifications via API for event:', eventId);

    try {
      const response = await fetch(`/api/events/${eventId}/classifications`);
      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to load classifications');
      }

      console.log('📊 API Response:', data);

      // Set event data
      event = data.event;

      // Process classifications or inscriptions
      if (data.hasClassifications && data.classifications.length > 0) {
        console.log('✅ Processing classification data:', data.classifications.length, 'entries');
        processClassifications(data.classifications);
      } else if (data.inscriptions.length > 0) {
        console.log('ℹ️ No classifications found, processing inscriptions:', data.inscriptions.length, 'entries');
        processInscriptions(data.inscriptions);
      } else {
        console.log('❌ No data found for event');
        classificacio = [];
      }

    } catch (err) {
      console.error('❌ Error loading data via API:', err);
      throw err;
    }
  }

  function processClassifications(classificacionsData: any[]) {
    const groupedByCategory = {};

    classificacionsData.forEach(classification => {
      const categoryId = classification.categoria_id || 'sense_categoria';

      if (!groupedByCategory[categoryId]) {
        groupedByCategory[categoryId] = {
          category: classification.categoria || { nom: 'Sense categoria', ordre_categoria: 999 },
          participants: []
        };
      }

      groupedByCategory[categoryId].participants.push({
        ...classification,
        isClassification: true
      });
    });

    // Convert to array and sort by category order
    classificacio = Object.values(groupedByCategory).sort((a: any, b: any) =>
      (a.category.ordre_categoria || 999) - (b.category.ordre_categoria || 999)
    );

    console.log('🏆 Processed classifications:', {
      totalCategories: classificacio.length,
      totalParticipants: classificacio.reduce((sum, cat) => sum + cat.participants.length, 0),
      categories: classificacio.map(cat => ({ name: cat.category.nom, participants: cat.participants.length }))
    });
  }

  function processInscriptions(inscriptionsData: any[]) {
    const groupedByCategory = {};

    inscriptionsData.forEach(inscription => {
      const categoryId = inscription.categoria_assignada_id || 'sense_categoria';

      if (!groupedByCategory[categoryId]) {
        groupedByCategory[categoryId] = {
          category: inscription.categoria_assignada || { nom: 'Sense categoria', ordre_categoria: 999 },
          participants: []
        };
      }

      groupedByCategory[categoryId].participants.push({
        ...inscription,
        posicio: groupedByCategory[categoryId].participants.length + 1,
        isInscription: true
      });
    });

    // Convert to array and sort by category order
    classificacio = Object.values(groupedByCategory).sort((a: any, b: any) =>
      (a.category.ordre_categoria || 999) - (b.category.ordre_categoria || 999)
    );

    console.log('📋 Processed inscriptions:', {
      totalCategories: classificacio.length,
      totalParticipants: classificacio.reduce((sum, cat) => sum + cat.participants.length, 0),
      categories: classificacio.map(cat => ({ name: cat.category.nom, participants: cat.participants.length }))
    });
  }


  function getPlayerAverage(inscription: any) {
    // Try to extract average from observacions
    const observacions = inscription.observacions || '';
    const avgMatch = observacions.match(/Mitjana històrica: ([\d.]+)/);
    return avgMatch ? parseFloat(avgMatch[1]).toFixed(2) : '-';
  }
</script>

<svelte:head>
  <title>Classificació - {event?.nom || 'Campionat Social'}</title>
</svelte:head>

<div class="max-w-6xl mx-auto p-4">
  <div class="mb-6">
    <div class="flex items-center space-x-4 mb-2">
      <a
        href="/campionats-socials/{eventId}"
        class="text-gray-600 hover:text-gray-900"
      >
        ← Tornar a l'event
      </a>
    </div>

    {#if event}
      <h1 class="text-2xl font-semibold text-gray-900">Classificació</h1>
      <div class="flex items-center space-x-4 text-sm text-gray-600 mt-1">
        <span>{event.nom}</span>
        <span>•</span>
        <span>Temporada {event.temporada}</span>
        <span>•</span>
        <span>{competitionTypes[event.tipus_competicio]}</span>
      </div>
    {/if}
  </div>

  <!-- Loading state -->
  {#if loading}
    <div class="flex justify-center py-12">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
    </div>
  {:else if error}
    <!-- Error state -->
    <div class="bg-red-50 border border-red-200 rounded-lg p-4">
      <p class="text-red-700">{error}</p>
    </div>
  {:else if classificacio.length === 0}
    <!-- Empty state -->
    <div class="text-center py-12">
      <p class="text-gray-500">No hi ha classificació disponible per aquest event.</p>
    </div>
  {:else}
    <!-- Classification display -->
    <div class="space-y-8">
      {#each classificacio as categoryGroup}
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <!-- Category header -->
          <div class="bg-gray-100 px-6 py-4 border-b">
            <h2 class="text-xl font-semibold text-gray-900">{categoryGroup.category.nom}</h2>
            {#if categoryGroup.category.distancia_caramboles}
              <p class="text-sm text-gray-600 mt-1">Distància: {categoryGroup.category.distancia_caramboles} caramboles</p>
            {/if}
          </div>

          <!-- Participants table -->
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Posició
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Nom
                  </th>
                  {#if categoryGroup.participants.some((p: any) => p.isClassification)}
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Punts
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Caramboles Totals
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Entrades Totals
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Mitjana General
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Mitjana Particular
                    </th>
                  {:else}
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Mitjana Històrica
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Estat
                    </th>
                  {/if}
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each categoryGroup.participants as participant, index}
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {participant.posicio || index + 1}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900">
                        {#if participant.isClassification}
                          {formatarNomJugador(participant.player?.nom || 'Nom no disponible')}
                        {:else if participant.socis}
                          {formatarNomJugador(`${participant.socis.nom} ${participant.socis.cognoms}`)}
                        {:else}
                          Jugador desconegut
                        {/if}
                      </div>
                    </td>
                    {#if participant.isClassification}
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {participant.punts || 0}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {participant.caramboles_favor || 0}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {participant.caramboles_contra || 0}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {participant.caramboles_favor && participant.caramboles_contra
                          ? (participant.caramboles_favor / participant.caramboles_contra).toFixed(3)
                          : '-'}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {participant.mitjana_particular ? participant.mitjana_particular.toFixed(3) : '-'}
                      </td>
                    {:else}
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {getPlayerAverage(participant)}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="flex flex-col space-y-1">
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {participant.confirmat ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'}">
                            {participant.confirmat ? 'Confirmat' : 'Pendent'}
                          </span>
                          {#if event.quota_inscripcio > 0}
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {participant.pagat ? 'bg-blue-100 text-blue-800' : 'bg-red-100 text-red-800'}">
                              {participant.pagat ? 'Pagat' : 'Pendent pagament'}
                            </span>
                          {/if}
                        </div>
                      </td>
                    {/if}
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>

          <!-- Category summary -->
          <div class="bg-gray-50 px-6 py-3 border-t">
            <p class="text-sm text-gray-600">
              <strong>{categoryGroup.participants.length}</strong> participant{categoryGroup.participants.length !== 1 ? 's' : ''}
              {#if categoryGroup.category.distancia_caramboles}
                • Distància: {categoryGroup.category.distancia_caramboles} caramboles
              {/if}
            </p>
          </div>
        </div>
      {/each}
    </div>

    <!-- Event summary -->
    <div class="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-4">
      <h3 class="text-lg font-medium text-blue-900 mb-2">Resum de l'Event</h3>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
        <div>
          <span class="font-medium text-blue-800">Total participants:</span>
          <span class="text-blue-700">{classificacio.reduce((sum, cat) => sum + cat.participants.length, 0)}</span>
        </div>
        <div>
          <span class="font-medium text-blue-800">Categories:</span>
          <span class="text-blue-700">{classificacio.length}</span>
        </div>
        <div>
          <span class="font-medium text-blue-800">Modalitat:</span>
          <span class="text-blue-700">{modalityNames[event.modalitat]}</span>
        </div>
      </div>
    </div>
  {/if}
</div>
