<script lang="ts">
  import { onMount } from 'svelte';
  import type { PageData } from './$types';
  import SocialLeagueCalendarViewer from '$lib/components/campionats-socials/SocialLeagueCalendarViewer.svelte';
  import DragDropInscriptions from '$lib/components/campionats-socials/DragDropInscriptions.svelte';
  import CategorySetup from '$lib/components/campionats-socials/CategorySetup.svelte';
  import CategoryManagement from '$lib/components/campionats-socials/CategoryManagement.svelte';
  import CalendarGenerator from '$lib/components/admin/CalendarGenerator.svelte';
  import PlayerRestrictionsTable from '$lib/components/campionats-socials/PlayerRestrictionsTable.svelte';
  import { adminStore, user } from '$lib/stores/auth';
  import { isAdmin as isAdminNew, adminUser } from '$lib/stores/adminAuth';
  import { getSocialLeagueEvents, exportCalendariToCSV } from '$lib/api/socialLeagues';
  import { supabase } from '$lib/supabaseClient';

  export const data: PageData = {} as PageData; // Unused export for type compatibility

  let events: any[] = [];
  let selectedEventId = '';
  let selectedEvent: any = null;
  let loading = false;
  let activeView: 'preparation' | 'active' | 'history' | 'players' | 'inscriptions' = 'preparation';

  // Variables per la gestió d'inscripcions
  let managementView: 'inscriptions' | 'categories' | 'generate-calendar' | 'view-calendar' | 'restrictions' = 'inscriptions';
  let socis: any[] = [];
  let inscriptions: any[] = [];
  let loadingSocis = false;
  let loadingInscriptions = false;
  let calendarStatus = 'not-generated'; // 'not-generated', 'generated', 'validated', 'published'

  // Computed per verificar si és admin (comprovant tots dos sistemes)
  $: isUserAdmin = $adminStore || $isAdminNew;

  // Events amb inscripcions obertes
  $: openRegistrations = events.filter(e => e.actiu && (
    e.estat_competicio === 'inscripcions_obertes' ||
    e.estat_competicio === 'pendent' ||
    e.estat_competicio === 'preparacio'
  ));

  // Redefinir filtres segons els nous estats de lliga
  $: preparationEvents = events.filter(e => e.actiu && (
    e.estat_competicio === 'preparacio' ||
    e.estat_competicio === 'inscripcions_obertes' ||
    e.estat_competicio === 'pendent' ||
    e.estat_competicio === 'pendent_validacio' || // Afegit l'estat real!
    !e.estat_competicio || // Events sense estat definit es consideren en preparació
    e.estat_competicio === ''
  ));

  $: activeEvents = events.filter(e => e.actiu && (
    e.estat_competicio === 'en_curs' ||
    e.estat_competicio === 'en_progres' ||
    e.estat_competicio === 'actiu' ||
    e.estat_competicio === 'ongoing'
  ));

  $: historicalEvents = events.filter(e => !e.actiu || (
    e.estat_competicio === 'finalitzat' ||
    e.estat_competicio === 'tancat' ||
    e.estat_competicio === 'finished' ||
    e.estat_competicio === 'completed'
  ));

  $: if (selectedEventId) {
    selectedEvent = events.find(e => e.id === selectedEventId);
    if (selectedEvent && activeView === 'preparation') {
      loadInscriptionsData();
      checkCalendarStatus();
    }
  }

  // Exportar calendari a CSV
  async function downloadCalendariCSV(eventId: string, eventName: string) {
    try {
      const csvContent = await exportCalendariToCSV(eventId);

      // Crear blob i descarregar
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');

      if (link.download !== undefined) {
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `calendari_${eventName.replace(/[^a-zA-Z0-9]/g, '_')}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }
    } catch (error) {
      console.error('Error exporting calendar:', error);
      const errorMessage = error.message || 'Error desconegut';
      alert(`Error exportant el calendari: ${errorMessage}`);
    }
  }

  // Carregar dades d'inscripcions i socis
  async function loadInscriptionsData() {
    if (!selectedEventId) return;

    try {
      loadingSocis = true;
      loadingInscriptions = true;

      // Carregar socis actius
      const { data: socisData, error: socisError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms, email, de_baixa')
        .eq('de_baixa', false)
        .order('nom');

      if (socisError) {
        console.error('Error loading socis:', socisError);
      }

      // Obtenir mitjanes històriques per als socis
      let socisWithAverages = [];
      if (socisData && socisData.length > 0) {
        const socisNumbers = socisData.map(s => s.numero_soci);
        const currentYear = new Date().getFullYear();
        const lastTwoYears = [currentYear, currentYear - 1];

        const { data: mitjanes, error: mitjErr } = await supabase
          .from('mitjanes_historiques')
          .select('soci_id, mitjana, year, modalitat')
          .in('soci_id', socisNumbers)
          .in('year', lastTwoYears)
          .eq('modalitat', '3 BANDES');

        if (mitjErr) {
          console.warn('Error fetching historical averages:', mitjErr);
        }

        // Combinar dades dels socis amb les seves millors mitjanes històriques
        socisWithAverages = socisData.map(soci => {
          const playerMitjanes = mitjanes?.filter(m => m.soci_id === soci.numero_soci) || [];
          const bestMitjana = playerMitjanes.length > 0
            ? Math.max(...playerMitjanes.map(m => m.mitjana))
            : null;

          return {
            ...soci,
            historicalAverage: bestMitjana
          };
        });
      }

      socis = socisWithAverages;

      // Carregar inscripcions de l'event
      const { data: inscriptionsData, error: inscriptionsError } = await supabase
        .from('inscripcions')
        .select(`
          id,
          soci_numero,
          categoria_assignada_id,
          data_inscripcio,
          pagat,
          confirmat,
          preferencies_dies,
          preferencies_hores,
          restriccions_especials,
          socis!inscripcions_soci_numero_fkey(numero_soci, nom, cognoms, email)
        `)
        .eq('event_id', selectedEventId);

      if (inscriptionsError) {
        console.error('Error loading inscriptions:', inscriptionsError);
      }

      inscriptions = inscriptionsData || [];

    } catch (error) {
      console.error('Error loading inscriptions data:', error);
    } finally {
      loadingSocis = false;
      loadingInscriptions = false;
    }
  }

  // Check calendar status
  async function checkCalendarStatus() {
    if (!selectedEventId) return;

    try {
      const { data: matches, error } = await supabase
        .from('calendari_partides')
        .select('id, estat')
        .eq('event_id', selectedEventId);

      if (error) {
        console.error('Error checking calendar status:', error);
        return;
      }

      if (!matches || matches.length === 0) {
        calendarStatus = 'not-generated';
      } else {
        const validatedMatches = matches.filter(match => match.estat === 'validat');
        if (validatedMatches.length === matches.length) {
          calendarStatus = 'validated';
        } else if (validatedMatches.length > 0) {
          calendarStatus = 'partially-validated';
        } else {
          calendarStatus = 'generated';
        }
      }
    } catch (error) {
      console.error('Error in checkCalendarStatus:', error);
    }
  }

  // Event handlers for DragDropInscriptions
  async function handleInscribe(event) {
    try {
      const { soci, categoryId } = event.detail;

      const { data, error } = await supabase
        .from('inscripcions')
        .insert([{
          event_id: selectedEventId,
          soci_numero: soci.numero_soci,
          categoria_assignada_id: categoryId,
          data_inscripcio: new Date().toISOString(),
          pagat: false,
          confirmat: false
        }]);

      if (error) {
        console.error('Error inscribing soci:', error);
        alert('Error en inscriure el soci: ' + error.message);
        return;
      }

      // Reload data
      await loadInscriptionsData();
    } catch (error) {
      console.error('Error in handleInscribe:', error);
      alert('Error en inscriure el soci');
    }
  }

  async function handleMoveInscription(event) {
    try {
      const { inscriptionId, categoryId } = event.detail;

      const { data, error } = await supabase
        .from('inscripcions')
        .update({ categoria_assignada_id: categoryId })
        .eq('id', inscriptionId);

      if (error) {
        console.error('Error moving inscription:', error);
        alert('Error en moure la inscripció: ' + error.message);
        return;
      }

      // Reload data
      await loadInscriptionsData();
    } catch (error) {
      console.error('Error in handleMoveInscription:', error);
      alert('Error en moure la inscripció');
    }
  }

  async function handleRemoveInscription(event) {
    try {
      const { inscriptionId } = event.detail;

      if (!confirm('Estàs segur que vols eliminar aquesta inscripció?')) {
        return;
      }

      const { data, error } = await supabase
        .from('inscripcions')
        .delete()
        .eq('id', inscriptionId);

      if (error) {
        console.error('Error removing inscription:', error);
        alert('Error en eliminar la inscripció: ' + error.message);
        return;
      }

      // Reload data
      await loadInscriptionsData();
    } catch (error) {
      console.error('Error in handleRemoveInscription:', error);
      alert('Error en eliminar la inscripció');
    }
  }

  function handleIntelligentMovementCompleted(event) {
    const { totalMoved, message } = event.detail;
    console.log('Intelligent movement completed:', message);

    // Show success message
    alert(`Moviment completat: ${message}`);

    // Reload data
    loadInscriptionsData();
  }

  // Calendar management functions
  async function validateCalendar() {
    try {
      // Check if calendar has matches generated
      const { data: matches, error: matchesError } = await supabase
        .from('calendari_partides')
        .select('id, estat')
        .eq('event_id', selectedEventId);

      if (matchesError) {
        console.error('Error checking calendar matches:', matchesError);
        alert('Error al verificar el calendari: ' + matchesError.message);
        return;
      }

      if (!matches || matches.length === 0) {
        alert('No hi ha partides generades al calendari. Genera primer el calendari.');
        managementView = 'generate-calendar';
        return;
      }

      // Validate calendar logic (check for conflicts, etc.)
      const conflicts = matches.filter(match => match.estat === 'conflicte');

      if (conflicts.length > 0) {
        if (!confirm(`Hi ha ${conflicts.length} conflictes al calendari. Vols continuar amb la validació?`)) {
          return;
        }
      }

      // Update matches to validated state
      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update({ estat: 'validat', data_validacio: new Date().toISOString() })
        .eq('event_id', selectedEventId)
        .eq('estat', 'generat');

      if (updateError) {
        console.error('Error validating calendar:', updateError);
        alert('Error al validar el calendari: ' + updateError.message);
        return;
      }

      alert('Calendari validat correctament! Ara pots publicar-lo.');

      // Update calendar status
      await checkCalendarStatus();
    } catch (error) {
      console.error('Error in validateCalendar:', error);
      alert('Error al validar el calendari');
    }
  }

  async function publishCalendar() {
    try {
      // Check if calendar is validated
      const { data: matches, error: matchesError } = await supabase
        .from('calendari_partides')
        .select('id, estat')
        .eq('event_id', selectedEventId);

      if (matchesError) {
        console.error('Error checking calendar:', matchesError);
        alert('Error al verificar el calendari: ' + matchesError.message);
        return;
      }

      const validatedMatches = matches?.filter(match => match.estat === 'validat') || [];

      if (validatedMatches.length === 0) {
        alert('El calendari no està validat. Valida primer el calendari abans de publicar-lo.');
        return;
      }

      if (!confirm('Estàs segur que vols publicar el calendari? Una vegada publicat, l\'event passarà a estar en curs.')) {
        return;
      }

      // Update event status to "en_curs"
      const { error: eventError } = await supabase
        .from('events')
        .update({
          estat_competicio: 'en_curs',
          data_inici: new Date().toISOString().split('T')[0] // Set start date to today
        })
        .eq('id', selectedEventId);

      if (eventError) {
        console.error('Error publishing event:', eventError);
        alert('Error al publicar l\'event: ' + eventError.message);
        return;
      }

      alert('Calendari publicat correctament! L\'event ara està en curs.');

      // Reload events to reflect the change
      window.location.reload();
    } catch (error) {
      console.error('Error in publishCalendar:', error);
      alert('Error al publicar el calendari');
    }
  }

  onMount(async () => {
    try {
      loading = true;

      // DEBUG: Verificar autenticació d'admin
      console.log('🔍 DEBUG ADMIN AUTH:');
      console.log('$adminStore (old system):', $adminStore);
      console.log('$isAdminNew (new system):', $isAdminNew);
      console.log('isUserAdmin (combined):', isUserAdmin);
      console.log('$user:', $user);

      // Verificar si tenim usuari logat
      if ($user?.email) {
        console.log('User email:', $user.email);

        // Importar i verificar amb el nou sistema
        const { checkAdminStatus } = await import('$lib/stores/adminAuth');
        const isAdminNewSystem = await checkAdminStatus($user.email);
        console.log('Admin status (manual check):', isAdminNewSystem);
      }

      events = await getSocialLeagueEvents();

      console.log('🔍 EVENTS DEBUG:');
      console.log('Total events:', events.length);

      events.forEach((event, index) => {
        console.log(`\n${index + 1}. "${event.nom}"`);
        console.log(`   Temporada: ${event.temporada}`);
        console.log(`   Modalitat: ${event.modalitat}`);
        console.log(`   Actiu: ${event.actiu}`);
        console.log(`   Estat Competició: "${event.estat_competicio}"`);
        const isActiveEvent = event.actiu && (
          event.estat_competicio === 'en_curs' ||
          event.estat_competicio === 'en_progres' ||
          event.estat_competicio === 'actiu' ||
          event.estat_competicio === 'ongoing'
        );
        console.log(`   Seria ACTIU: ${isActiveEvent ? '✅' : '❌'}`);
      });

      console.log('\nValors únics estat_competicio:', [...new Set(events.map(e => e.estat_competicio))]);

      // DEBUG: Verificar filtres
      console.log('\n🔍 FILTRES DEBUG:');
      console.log('Preparation events:', preparationEvents.length, preparationEvents.map(e => e.nom));
      console.log('Active events:', activeEvents.length, activeEvents.map(e => e.nom));
      console.log('Historical events:', historicalEvents.length);

      // Auto-seleccionar: prioritzar preparació > actiu > qualsevol
      const preparationEvent = preparationEvents[0];
      const activeEvent = activeEvents[0];

      if (preparationEvent) {
        selectedEventId = preparationEvent.id;
        activeView = 'preparation';
      } else if (activeEvent) {
        selectedEventId = activeEvent.id;
        activeView = 'active';
      } else if (events.length > 0) {
        selectedEventId = events[0].id;
        activeView = 'history';
      }
    } catch (error) {
      console.error('Error loading events:', error);
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Campionats Socials - Campionat 3 Bandes</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="md:flex md:items-center md:justify-between">
    <div class="flex-1 min-w-0">
      <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
        Campionats Socials
      </h2>
      <p class="mt-1 text-sm text-gray-500">
        Competicions socials per modalitats: Lliure, Banda i 3 Bandes
      </p>
    </div>
  </div>

  <!-- Estadístiques Reals -->
  {#if !loading}
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
      <!-- Lligues en Preparació -->
      <button class="bg-white overflow-hidden shadow rounded-lg cursor-pointer hover:bg-gray-50 w-full text-left" on:click={() => activeView = 'preparation'}>
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-orange-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Lligues en Preparació</dt>
                <dd class="text-lg font-medium text-gray-900">{preparationEvents.length}</dd>
                {#if preparationEvents.length > 0}
                  <dd class="text-xs text-orange-600 font-medium">▶ Clic per gestionar</dd>
                {/if}
              </dl>
            </div>
          </div>
        </div>
      </button>

      <!-- Lligues en Curs -->
      <button class="bg-white overflow-hidden shadow rounded-lg cursor-pointer hover:bg-gray-50 w-full text-left" on:click={() => activeView = 'active'}>
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Lligues en Curs</dt>
                <dd class="text-lg font-medium text-gray-900">{activeEvents.length}</dd>
                {#if activeEvents.length > 0}
                  <dd class="text-xs text-green-600 font-medium">▶ Clic per veure</dd>
                {/if}
              </dl>
            </div>
          </div>
        </div>
      </button>

      <!-- Total Lligues -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Lligues</dt>
                <dd class="text-lg font-medium text-gray-900">{events.length}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>
  {/if}

  <!-- Navegació per Seccions -->
  <div class="border-b border-gray-200">
    <nav class="-mb-px flex space-x-8">
      <button
        on:click={() => activeView = 'preparation'}
        class="py-2 px-1 border-b-2 font-medium text-sm"
        class:border-orange-500={activeView === 'preparation'}
        class:text-orange-600={activeView === 'preparation'}
        class:border-transparent={activeView !== 'preparation'}
        class:text-gray-500={activeView !== 'preparation'}
        class:hover:text-gray-700={activeView !== 'preparation'}
        class:hover:border-gray-300={activeView !== 'preparation'}
      >
        🔧 Lligues en Preparació
      </button>
      <button
        on:click={() => activeView = 'active'}
        class="py-2 px-1 border-b-2 font-medium text-sm"
        class:border-green-500={activeView === 'active'}
        class:text-green-600={activeView === 'active'}
        class:border-transparent={activeView !== 'active'}
        class:text-gray-500={activeView !== 'active'}
        class:hover:text-gray-700={activeView !== 'active'}
        class:hover:border-gray-300={activeView !== 'active'}
      >
        🏆 Lligues en Curs
      </button>
      <button
        on:click={() => activeView = 'history'}
        class="py-2 px-1 border-b-2 font-medium text-sm"
        class:border-blue-500={activeView === 'history'}
        class:text-blue-600={activeView === 'history'}
        class:border-transparent={activeView !== 'history'}
        class:text-gray-500={activeView !== 'history'}
        class:hover:text-gray-700={activeView !== 'history'}
        class:hover:border-gray-300={activeView !== 'history'}
      >
        📜 Historial
      </button>
      <button
        on:click={() => activeView = 'players'}
        class="py-2 px-1 border-b-2 font-medium text-sm"
        class:border-blue-500={activeView === 'players'}
        class:text-blue-600={activeView === 'players'}
        class:border-transparent={activeView !== 'players'}
        class:text-gray-500={activeView !== 'players'}
        class:hover:text-gray-700={activeView !== 'players'}
        class:hover:border-gray-300={activeView !== 'players'}
      >
        🔍 Cerca Jugadors
      </button>
    </nav>
  </div>


  <!-- Contingut per Seccions -->
  {#if activeView === 'preparation'}
    <!-- Lligues en Preparació -->
    {#if loading}
      <div class="text-center py-8">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">Carregant lligues...</p>
      </div>
    {:else if preparationEvents.length > 0}
      <div class="space-y-6">
        <!-- Lligues en Preparació -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              🔧 Lligues en Preparació - Gestió d'Inscripcions
            </h3>
            <div class="space-y-4">
              {#each preparationEvents as event}
                <div class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50">
                  <div class="flex items-center justify-between">
                    <div>
                      <h4 class="font-medium text-gray-900">{event.nom}</h4>
                      <p class="text-sm text-gray-500">
                        Temporada {event.temporada} •
                        {event.modalitat === 'tres_bandes' ? '3 Bandes' :
                         event.modalitat === 'lliure' ? 'Lliure' : 'Banda'}
                      </p>
                      {#if event.actiu}
                        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-orange-100 text-orange-800 mt-1">
                          En Preparació
                        </span>
                      {/if}
                    </div>
                    <div class="text-right">
                      {#if isUserAdmin}
                        <button
                          on:click={() => { selectedEventId = event.id; }}
                          class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-orange-600 hover:bg-orange-700"
                        >
                          Gestionar Inscripcions
                        </button>
                      {:else}
                        <span class="inline-flex items-center px-3 py-2 text-sm text-gray-500">
                          Només visible per admins
                        </span>
                      {/if}
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </div>

        <!-- Gestió d'Inscripcions de la Lliga Seleccionada (només admins) -->
        {#if isUserAdmin && selectedEventId && selectedEvent && preparationEvents.find(e => e.id === selectedEventId)}
          <div class="bg-white shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg leading-6 font-medium text-gray-900">
                  Gestió: {selectedEvent.nom}
                </h3>
                <select
                  bind:value={selectedEventId}
                  class="px-3 py-2 border border-gray-300 rounded-md text-sm"
                >
                  <option value="">-- Tria una lliga --</option>
                  {#each preparationEvents as event}
                    <option value={event.id}>
                      {event.nom} - {event.temporada}
                    </option>
                  {/each}
                </select>
              </div>

              <!-- Navegació de gestió -->
              <div class="border-b border-gray-200 mb-6">
                <nav class="-mb-px flex space-x-8">
                  <button
                    on:click={() => managementView = 'inscriptions'}
                    class="py-2 px-1 border-b-2 font-medium text-sm"
                    class:border-orange-500={managementView === 'inscriptions'}
                    class:text-orange-600={managementView === 'inscriptions'}
                    class:border-transparent={managementView !== 'inscriptions'}
                    class:text-gray-500={managementView !== 'inscriptions'}
                    class:hover:text-gray-700={managementView !== 'inscriptions'}
                    class:hover:border-gray-300={managementView !== 'inscriptions'}
                  >
                    👥 Inscripcions
                  </button>
                  <button
                    on:click={() => managementView = 'categories'}
                    class="py-2 px-1 border-b-2 font-medium text-sm"
                    class:border-orange-500={managementView === 'categories'}
                    class:text-orange-600={managementView === 'categories'}
                    class:border-transparent={managementView !== 'categories'}
                    class:text-gray-500={managementView !== 'categories'}
                    class:hover:text-gray-700={managementView !== 'categories'}
                    class:hover:border-gray-300={managementView !== 'categories'}
                  >
                    📂 Categories
                  </button>
                  <button
                    on:click={() => managementView = 'restrictions'}
                    class="py-2 px-1 border-b-2 font-medium text-sm"
                    class:border-orange-500={managementView === 'restrictions'}
                    class:text-orange-600={managementView === 'restrictions'}
                    class:border-transparent={managementView !== 'restrictions'}
                    class:text-gray-500={managementView !== 'restrictions'}
                    class:hover:text-gray-700={managementView !== 'restrictions'}
                    class:hover:border-gray-300={managementView !== 'restrictions'}
                  >
                    🚫 Restriccions
                  </button>
                  <button
                    on:click={() => managementView = 'generate-calendar'}
                    class="py-2 px-1 border-b-2 font-medium text-sm relative"
                    class:border-orange-500={managementView === 'generate-calendar'}
                    class:text-orange-600={managementView === 'generate-calendar'}
                    class:border-transparent={managementView !== 'generate-calendar'}
                    class:text-gray-500={managementView !== 'generate-calendar'}
                    class:hover:text-gray-700={managementView !== 'generate-calendar'}
                    class:hover:border-gray-300={managementView !== 'generate-calendar'}
                  >
                    🔨 Generar Calendari
                    {#if calendarStatus === 'not-generated'}
                      <span class="absolute -top-1 -right-1 h-3 w-3 bg-red-500 rounded-full"></span>
                    {/if}
                  </button>
                  <button
                    on:click={() => managementView = 'view-calendar'}
                    class="py-2 px-1 border-b-2 font-medium text-sm relative"
                    class:border-orange-500={managementView === 'view-calendar'}
                    class:text-orange-600={managementView === 'view-calendar'}
                    class:border-transparent={managementView !== 'view-calendar'}
                    class:text-gray-500={managementView !== 'view-calendar'}
                    class:hover:text-gray-700={managementView !== 'view-calendar'}
                    class:hover:border-gray-300={managementView !== 'view-calendar'}
                    disabled={calendarStatus === 'not-generated'}
                    class:opacity-50={calendarStatus === 'not-generated'}
                    class:cursor-not-allowed={calendarStatus === 'not-generated'}
                  >
                    📅 Visualitzar Calendari
                    {#if calendarStatus === 'generated'}
                      <span class="absolute -top-1 -right-1 h-3 w-3 bg-yellow-500 rounded-full"></span>
                    {:else if calendarStatus === 'validated'}
                      <span class="absolute -top-1 -right-1 h-3 w-3 bg-green-500 rounded-full"></span>
                    {:else if calendarStatus === 'partially-validated'}
                      <span class="absolute -top-1 -right-1 h-3 w-3 bg-blue-500 rounded-full"></span>
                    {/if}
                  </button>
                </nav>
              </div>

              <!-- Contingut segons la vista de gestió -->
              {#if managementView === 'inscriptions'}
                <DragDropInscriptions
                  {socis}
                  {inscriptions}
                  categories={selectedEvent.categories || []}
                  eventId={selectedEventId}
                  currentEvent={selectedEvent}
                  loading={loadingSocis || loadingInscriptions}
                  on:inscribe={handleInscribe}
                  on:moveInscription={handleMoveInscription}
                  on:removeInscription={handleRemoveInscription}
                  on:intelligentMovementCompleted={handleIntelligentMovementCompleted}
                  on:inscriptionUpdated={loadInscriptionsData}
                />
              {:else if managementView === 'categories'}
                <div class="space-y-6">
                  <!-- Individual category management -->
                  <CategoryManagement
                    eventId={selectedEventId}
                    categories={selectedEvent.categories || []}
                    {inscriptions}
                    on:categoryCreated={() => {
                      // Reload events to get updated categories
                      window.location.reload();
                    }}
                    on:categoryDeleted={() => {
                      // Reload events to get updated categories
                      window.location.reload();
                    }}
                    on:categoryUpdated={() => {
                      // Reload events to get updated categories
                      window.location.reload();
                    }}
                  />

                  <!-- Bulk category setup and player assignment -->
                  <CategorySetup
                    eventId={selectedEventId}
                    {inscriptions}
                    {socis}
                    categories={selectedEvent.categories || []}
                    on:categoriesUpdated={() => {
                      // Reload events to get updated categories
                      window.location.reload();
                    }}
                  />
                </div>
              {:else if managementView === 'restrictions'}
                <PlayerRestrictionsTable
                  eventId={selectedEventId}
                  {inscriptions}
                  {socis}
                  categories={selectedEvent.categories || []}
                  on:restrictionsUpdated={loadInscriptionsData}
                />
              {:else if managementView === 'generate-calendar'}
                <CalendarGenerator
                  eventId={selectedEventId}
                  {inscriptions}
                  categories={selectedEvent?.categories || []}
                  on:calendarGenerated={async () => {
                    console.log('Calendar generated');
                    // Update calendar status
                    await checkCalendarStatus();
                    // Switch to view calendar after generation
                    managementView = 'view-calendar';
                  }}
                />
              {:else if managementView === 'view-calendar'}
                <div class="space-y-6">
                  <!-- Header with validation/publish buttons -->
                  <div class="flex items-center justify-between bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <div>
                      <h4 class="text-lg font-medium text-blue-900">Calendari Generat - {selectedEvent.nom}</h4>
                      <div class="flex items-center space-x-2 mt-1">
                        <p class="text-sm text-blue-700">Estat:</p>
                        {#if calendarStatus === 'generated'}
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                            🔧 Pendent de validació
                          </span>
                        {:else if calendarStatus === 'partially-validated'}
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            🔄 Parcialment validat
                          </span>
                        {:else if calendarStatus === 'validated'}
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            ✅ Validat - Llest per publicar
                          </span>
                        {:else}
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                            📋 No generat
                          </span>
                        {/if}
                      </div>
                    </div>
                    <div class="flex space-x-3">
                      <button
                        on:click={() => downloadCalendariCSV(selectedEventId, selectedEvent.nom)}
                        class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                        title="Exportar calendari a CSV"
                      >
                        📄 Exportar CSV
                      </button>
                      <button
                        on:click={() => managementView = 'generate-calendar'}
                        class="inline-flex items-center px-3 py-2 border border-blue-300 text-sm leading-4 font-medium rounded-md text-blue-700 bg-white hover:bg-blue-50"
                      >
                        🔨 Regenerar
                      </button>
                      {#if calendarStatus === 'generated' || calendarStatus === 'partially-validated'}
                        <button
                          on:click={validateCalendar}
                          class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
                        >
                          ✅ Validar Calendari
                        </button>
                      {:else if calendarStatus === 'validated'}
                        <span class="inline-flex items-center px-3 py-2 text-sm leading-4 font-medium text-green-700 bg-green-100 rounded-md">
                          ✅ Calendari Validat
                        </span>
                      {/if}

                      {#if calendarStatus === 'validated'}
                        <button
                          on:click={publishCalendar}
                          class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                        >
                          📢 Publicar Calendari
                        </button>
                      {:else}
                        <span
                          class="inline-flex items-center px-3 py-2 text-sm leading-4 font-medium text-gray-500 bg-gray-100 rounded-md cursor-not-allowed"
                          title="Cal validar el calendari primer"
                        >
                          📢 Publicar Calendari
                        </span>
                      {/if}
                    </div>
                  </div>

                  <!-- Calendar Viewer with editing capabilities -->
                  <SocialLeagueCalendarViewer
                    eventId={selectedEventId}
                    categories={selectedEvent.categories || []}
                    isAdmin={isUserAdmin}
                    eventData={selectedEvent}
                    defaultMode="timeline"
                    editMode={true}
                    on:matchUpdated={() => {
                      console.log('Match updated in preparation');
                    }}
                  />
                </div>
              {/if}
            </div>
          </div>
        {/if}
      </div>
    {:else}
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha lligues en preparació</h3>
        <p class="mt-1 text-sm text-gray-500">Actualment no hi ha cap lliga social en fase de preparació d'inscripcions.</p>
      </div>
    {/if}

  {:else if activeView === 'active'}
    <!-- Lligues en Curs -->
    {#if loading}
      <div class="text-center py-8">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">Carregant lligues...</p>
      </div>
    {:else if activeEvents.length > 0}
      <div class="space-y-6">
        <!-- Lligues en Curs -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              🏆 Lligues en Curs - Calendaris i Resultats
            </h3>
            <div class="space-y-4">
              {#each activeEvents as event}
                <div class="border border-green-200 rounded-lg p-4 hover:bg-gray-50">
                  <div class="flex items-center justify-between">
                    <div>
                      <h4 class="font-medium text-gray-900">{event.nom}</h4>
                      <p class="text-sm text-gray-500">
                        Temporada {event.temporada} •
                        {event.modalitat === 'tres_bandes' ? '3 Bandes' :
                         event.modalitat === 'lliure' ? 'Lliure' : 'Banda'}
                      </p>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800 mt-1">
                        En Curs
                      </span>
                    </div>
                    <div class="text-right space-y-2">
                      <div class="flex space-x-2">
                        <button
                          on:click={() => { selectedEventId = event.id; }}
                          class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
                        >
                          Veure Calendari Oficial
                        </button>
                        {#if isUserAdmin}
                          <button
                            on:click={() => downloadCalendariCSV(event.id, event.nom)}
                            class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                            title="Exportar calendari a CSV"
                          >
                            📄 CSV
                          </button>
                        {/if}
                      </div>
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </div>

        <!-- Calendari de la Lliga Seleccionada -->
        {#if selectedEventId && selectedEvent && activeEvents.find(e => e.id === selectedEventId)}
          <div class="bg-white shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg leading-6 font-medium text-gray-900">
                  Calendari Oficial: {selectedEvent.nom}
                </h3>
                <div class="flex space-x-3">
                  {#if isUserAdmin}
                    <button
                      on:click={() => downloadCalendariCSV(selectedEventId, selectedEvent.nom)}
                      class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                      title="Exportar calendari a CSV"
                    >
                      📄 Exportar CSV
                    </button>
                  {/if}
                  <select
                    bind:value={selectedEventId}
                    class="px-3 py-2 border border-gray-300 rounded-md text-sm"
                  >
                    <option value="">-- Tria una lliga --</option>
                    {#each activeEvents as event}
                      <option value={event.id}>
                        {event.nom} - {event.temporada}
                      </option>
                    {/each}
                  </select>
                </div>
              </div>

              <SocialLeagueCalendarViewer
                eventId={selectedEventId}
                categories={selectedEvent.categories || []}
                isAdmin={isUserAdmin}
                eventData={selectedEvent}
                defaultMode="timeline"
                on:matchUpdated={() => {
                  console.log('Match updated');
                }}
              />
            </div>
          </div>
        {/if}
      </div>
    {:else}
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha lligues en curs</h3>
        <p class="mt-1 text-sm text-gray-500">Actualment no hi ha cap lliga social en curs.</p>
      </div>
    {/if}

  {:else if activeView === 'history'}
    <!-- Historial -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
          Historial de Lligues
        </h3>
        {#if historicalEvents.length > 0}
          <div class="space-y-4">
            {#each historicalEvents.slice(0, 10) as event}
              <div class="border border-gray-200 rounded-lg p-4">
                <div class="flex items-center justify-between">
                  <div>
                    <h4 class="font-medium text-gray-900">{event.nom}</h4>
                    <p class="text-sm text-gray-500">
                      Temporada {event.temporada} •
                      {event.modalitat === 'tres_bandes' ? '3 Bandes' :
                       event.modalitat === 'lliure' ? 'Lliure' : 'Banda'}
                    </p>
                  </div>
                  <div class="text-right">
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      Finalitzat
                    </span>
                  </div>
                </div>
              </div>
            {/each}
          </div>
          {#if historicalEvents.length > 10}
            <p class="mt-4 text-sm text-gray-500 text-center">
              ... i {historicalEvents.length - 10} lligues més
            </p>
          {/if}
        {:else}
          <div class="text-center py-8">
            <p class="text-gray-500">No hi ha lligues històriques disponibles.</p>
          </div>
        {/if}
      </div>
    </div>

  {:else if activeView === 'inscriptions'}
    <!-- Inscripcions Obertes -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
          Inscripcions Obertes
        </h3>
        {#if openRegistrations.length > 0}
          <div class="space-y-4">
            {#each openRegistrations as event}
              <div class="border border-green-200 rounded-lg p-4 bg-green-50">
                <div class="flex items-center justify-between">
                  <div>
                    <h4 class="font-medium text-gray-900">{event.nom}</h4>
                    <p class="text-sm text-gray-600">
                      Temporada {event.temporada} •
                      {event.modalitat === 'tres_bandes' ? '3 Bandes' :
                       event.modalitat === 'lliure' ? 'Lliure' : 'Banda'}
                    </p>
                    <div class="mt-2 space-y-2">
                      {#if event.data_inici}
                        <p class="text-sm text-gray-500">
                          📅 Inici: {new Date(event.data_inici).toLocaleDateString('ca-ES')}
                        </p>
                      {/if}
                      {#if event.data_fi}
                        <p class="text-sm text-gray-500">
                          🏁 Fi: {new Date(event.data_fi).toLocaleDateString('ca-ES')}
                        </p>
                      {/if}
                    </div>
                  </div>
                  <div class="text-right space-y-2">
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                      ✅ Inscripcions Obertes
                    </span>
                    <div class="flex space-x-2">
                      <button
                        on:click={() => { selectedEventId = event.id; activeView = 'inscriptions'; }}
                        class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-blue-700 bg-blue-100 hover:bg-blue-200"
                      >
                        📋 Veure Calendari
                      </button>
                      {#if isUserAdmin}
                        <button
                          class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
                        >
                          ⚙️ Gestionar Inscripcions
                        </button>
                      {/if}
                    </div>
                  </div>
                </div>

                <!-- Categories disponibles -->
                {#if event.categories && event.categories.length > 0}
                  <div class="mt-4 border-t border-green-200 pt-4">
                    <h5 class="text-sm font-medium text-gray-700 mb-2">Categories disponibles:</h5>
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
                      {#each event.categories as category}
                        <div class="bg-white rounded border border-gray-200 p-2">
                          <p class="text-sm font-medium text-gray-900">{category.nom}</p>
                          <p class="text-xs text-gray-500">
                            📏 {category.distancia_caramboles} caramboles
                          </p>
                          <p class="text-xs text-gray-500">
                            👥 {category.min_jugadors}-{category.max_jugadors} jugadors
                          </p>
                        </div>
                      {/each}
                    </div>
                  </div>
                {/if}
              </div>
            {/each}
          </div>
        {:else}
          <div class="text-center py-8">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha inscripcions obertes</h3>
            <p class="mt-1 text-sm text-gray-500">Actualment no hi ha cap lliga social amb inscripcions obertes.</p>
            {#if isUserAdmin}
              <div class="mt-6">
                <button
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                >
                  ➕ Obrir Inscripcions per a una Lliga
                </button>
              </div>
            {/if}
          </div>
        {/if}
      </div>
    </div>

  {:else if activeView === 'players'}
    <!-- Cerca Jugadors -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
          Cerca de Jugadors
        </h3>
        <p class="text-sm text-gray-500 mb-6">
          Busca la trajectòria i estadístiques de qualsevol jugador de les lligues socials.
        </p>
        <!-- Aquí aniria el component PlayerSearcher simplificat -->
        <div class="text-center py-8 text-gray-500">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
          </svg>
          <p class="mt-2">Funcionalitat de cerca de jugadors proximament disponible</p>
        </div>
      </div>
    </div>
  {/if}
</div>