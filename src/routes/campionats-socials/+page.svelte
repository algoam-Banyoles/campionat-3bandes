<script lang="ts">
  import { onMount } from 'svelte';
  import type { PageData } from './$types';
  import SocialLeagueCalendarViewer from '$lib/components/campionats-socials/SocialLeagueCalendarViewer.svelte';
  import SocialLeagueMatchResults from '$lib/components/campionats-socials/SocialLeagueMatchResults.svelte';
  import SocialLeaguePlayersGrid from '$lib/components/campionats-socials/SocialLeaguePlayersGrid.svelte';
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
  let activeView: 'preparation' | 'active' | 'history' | 'players' | 'inscriptions' = 'active';



  // Variables per la gestió d'inscripcions
  let managementView: 'inscriptions' | 'categories' | 'generate-calendar' | 'view-calendar' | 'restrictions' | 'results' | 'standings' = 'inscriptions';
  let socis: any[] = [];
  let inscriptions: any[] = [];
  let loadingSocis = false;
  let loadingInscriptions = false;
  let calendarStatus = 'not-generated'; // 'not-generated', 'generated', 'validated', 'published'

  // Computed per verificar si és admin (comprovant tots dos sistemes)
  $: isUserAdmin = $adminStore || $isAdminNew;

  // Funció manual per recalcular filtres i fer debug
  function recalculateFilters() {
    console.log('� MANUAL RECOMPUTE amb', events.length, 'events:');
    
    events.forEach((event, i) => {
      console.log(`${i+1}. "${event.nom}" - actiu: ${event.actiu}, estat: "${event.estat_competicio}"`);
    });
    
    // Test manual dels filtres
    const prep = events.filter(e => e.actiu && (
      e.estat_competicio === 'preparacio' ||
      e.estat_competicio === 'planificacio' ||
      e.estat_competicio === 'inscripcions_obertes' ||
      e.estat_competicio === 'pendent' ||
      e.estat_competicio === 'pendent_validacio' ||
      e.estat_competicio === 'inscripcions' ||
      e.estat_competicio === 'configuracio' ||
      e.estat_competicio === 'programacio' ||
      !e.estat_competicio ||
      e.estat_competicio === ''
    ));
    
    const active = events.filter(e => e.actiu && (
      e.estat_competicio === 'en_curs' ||
      e.estat_competicio === 'en_progres' ||
      e.estat_competicio === 'actiu' ||
      e.estat_competicio === 'ongoing'
    ));
    
    console.log('✅ Manual results: prep =', prep.length, ', active =', active.length);
    
    // També escriu l'info en el document
    if (typeof document !== 'undefined') {
      const debugDiv = document.createElement('div');
      debugDiv.style.cssText = 'position:fixed;top:50px;left:0;background:lightblue;padding:10px;z-index:9999;font-size:12px;';
      debugDiv.innerHTML = `🔧 Manual recompute: prep = ${prep.length}, active = ${active.length}`;
      document.body.appendChild(debugDiv);
      
      // Eliminar després de 5 segons
      setTimeout(() => debugDiv.remove(), 5000);
    }
    
    // Forçar reassignació per triggerejar reactius
    preparationEvents = prep;
    activeEvents = active;
  }

  // Events amb inscripcions obertes
  $: openRegistrations = events.filter(e => e.actiu && (
    e.estat_competicio === 'inscripcions_obertes' ||
    e.estat_competicio === 'pendent' ||
    e.estat_competicio === 'preparacio'
  ));

  // Redefinir filtres segons els nous estats de lliga
  $: preparationEvents = events.filter(e => e.actiu && (
    e.estat_competicio === 'preparacio' ||
    e.estat_competicio === 'planificacio' ||
    e.estat_competicio === 'inscripcions_obertes' ||
    e.estat_competicio === 'pendent' ||
    e.estat_competicio === 'pendent_validacio' ||
    e.estat_competicio === 'inscripcions' ||
    e.estat_competicio === 'configuracio' ||
    e.estat_competicio === 'programacio' ||
    !e.estat_competicio ||
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
    console.log('🎯 Selected event:', selectedEvent?.nom, 'Categories:', selectedEvent?.categories?.length || 0);
    if (selectedEvent && (activeView === 'preparation' || activeView === 'active')) {
      loadInscriptionsData();
      if (activeView === 'preparation') {
        checkCalendarStatus();
      }
    }
  }

  // Carregar dades quan es canvia la vista de gestió a inscripcions, classificació o calendari
  $: if (selectedEventId && selectedEvent && managementView === 'inscriptions' && activeView === 'active' && isUserAdmin) {
    if (!loadingInscriptions) {
      loadInscriptionsData();
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
    if (!selectedEventId) {
      console.log('🔍 checkCalendarStatus: No selectedEventId');
      return;
    }

    try {
      console.log('🔍 Checking calendar status for event:', selectedEventId);
      
      const { data: matches, error } = await supabase
        .from('calendari_partides')
        .select('id, estat')
        .eq('event_id', selectedEventId);

      if (error) {
        console.error('❌ Error checking calendar status:', error);
        return;
      }

      console.log('📊 Found matches:', matches?.length || 0);
      
      if (!matches || matches.length === 0) {
        calendarStatus = 'not-generated';
        console.log('📅 Calendar status: NOT GENERATED');
      } else {
        const validatedMatches = matches.filter(match => match.estat === 'validat');
        const publishedMatches = matches.filter(match => match.estat === 'publicat');
        
        console.log('📈 Match stats:');
        console.log('  - Total:', matches.length);
        console.log('  - Validated:', validatedMatches.length);
        console.log('  - Published:', publishedMatches.length);
        
        if (publishedMatches.length > 0) {
          calendarStatus = 'published';
          console.log('📅 Calendar status: PUBLISHED');
        } else if (validatedMatches.length === matches.length) {
          calendarStatus = 'validated';
          console.log('📅 Calendar status: VALIDATED');
        } else if (validatedMatches.length > 0) {
          calendarStatus = 'partially-validated';
          console.log('📅 Calendar status: PARTIALLY VALIDATED');
        } else {
          calendarStatus = 'generated';
          console.log('📅 Calendar status: GENERATED');
        }
      }
    } catch (error) {
      console.error('❌ Error in checkCalendarStatus:', error);
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
      


      events.forEach((event, index) => {
        console.log(`\n${index + 1}. "${event.nom}"`);
        console.log(`   Temporada: ${event.temporada}`);
        console.log(`   Modalitat: ${event.modalitat}`);
        console.log(`   Actiu: ${event.actiu}`);
        console.log(`   Estat Competició: "${event.estat_competicio}"`);
        console.log(`   Categories: ${event.categories?.length || 0}`);
        if (event.categories?.length > 0) {
          event.categories.forEach(cat => {
            console.log(`     - ${cat.nom} (${cat.distancia_caramboles} car.)`);
          });
        }
        const isActiveEvent = event.actiu && (
          event.estat_competicio === 'en_curs' ||
          event.estat_competicio === 'en_progres' ||
          event.estat_competicio === 'actiu' ||
          event.estat_competicio === 'ongoing'
        );
        console.log(`   Seria ACTIU: ${isActiveEvent ? '✅' : '❌'}`);
      });

      console.log('\nValors únics estat_competicio:', [...new Set(events.map(e => e.estat_competicio))]);

      // DEBUG DETALLAT: Verificar cada event individualment
      console.log('\n🔍 EVENTS DETALLATS:');
      events.forEach((event, index) => {
        console.log(`${index + 1}. "${event.nom}"`);
        console.log(`   actiu: ${event.actiu} (type: ${typeof event.actiu})`);
        console.log(`   estat_competicio: "${event.estat_competicio}"`);
        console.log(`   temporada: ${event.temporada}`);
        
        // Test filtres individuals
        const isActive = event.actiu && (
          event.estat_competicio === 'en_curs' ||
          event.estat_competicio === 'en_progres' ||
          event.estat_competicio === 'actiu' ||
          event.estat_competicio === 'ongoing'
        );
        console.log(`   ➜ Seria ACTIU?: ${isActive}`);
        console.log('');
      });

      // DEBUG: Verificar filtres
      console.log('\n🔍 FILTRES DEBUG:');
      console.log('Preparation events:', preparationEvents.length, preparationEvents.map(e => e.nom));
      console.log('Active events:', activeEvents.length, activeEvents.map(e => e.nom));
      console.log('Historical events:', historicalEvents.length);

      // Auto-seleccionar: lligues actives per defecte, preparació només per admins
      const preparationEvent = preparationEvents[0];
      const activeEvent = activeEvents[0];

      // Buscar manualment esdeveniments actius per evitar problemes de timing
      const manualActiveEvent = events.find(e => 
        e.actiu && 
        (e.estat_competicio === 'en_curs' || 
         e.estat_competicio === 'en_progres' || 
         e.estat_competicio === 'actiu' || 
         e.estat_competicio === 'ongoing')
      );
      
      if (manualActiveEvent) {
        selectedEventId = manualActiveEvent.id;
        activeView = 'active';
        console.log('🔍 Manual active event, isUserAdmin:', isUserAdmin);
        // Per usuaris no logats, començar amb la vista de jugadors
        if (!isUserAdmin) {
          managementView = 'inscriptions';
          console.log('🔍 Setting managementView to inscriptions for non-admin');
        }
      } else if (activeEvent) {
        selectedEventId = activeEvent.id;
        activeView = 'active';
        // Per usuaris no logats, començar amb la vista de jugadors
        if (!isUserAdmin) {
          managementView = 'inscriptions';
        }
      } else if (isUserAdmin && preparationEvent) {
        selectedEventId = preparationEvent.id;
        activeView = 'preparation';
      } else {
        // Si no hi ha lligues actives ni en preparació, va a historial
        activeView = 'history';
        if (events.length > 0) {
          selectedEventId = events[0].id;
        }
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
    <div class="flex items-center space-x-4">
      {#if isUserAdmin}
        <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
          👑 Administrator
        </span>
      {:else if $user}
        <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
          👤 {$user.email}
        </span>
      {:else}
        <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
          👤 Visitant anònim
        </span>
      {/if}
    </div>
  </div>

  <!-- Barra d'informació d'usuari -->
  {#if !$user}
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-blue-800">
            Informació pública disponible
          </h3>
          <div class="mt-1 text-sm text-blue-700">
            <p>Pots veure els calendaris i resultats públics sense registrar-te. Per accedir a funcionalitats addicionals, inicia sessió.</p>
          </div>
        </div>
      </div>
    </div>
  {:else if $user && !isUserAdmin}
    <div class="bg-green-50 border border-green-200 rounded-lg p-4">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-green-800">
            Benvingut/da, {$user.email}!
          </h3>
          <div class="mt-1 text-sm text-green-700">
            <p>Com a usuari registrat, pots veure tots els calendaris i resultats detallats de les competicions.</p>
          </div>
        </div>
      </div>
    </div>
  {/if}


  <!-- Navegació per Seccions -->
  <div class="border-b border-gray-200">
    <nav class="-mb-px flex space-x-8">
      {#if isUserAdmin}
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
      {/if}
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
  {#if activeView === 'preparation' && isUserAdmin}
    <!-- Lligues en Preparació - Només admins -->
    {#if loading}
      <div class="text-center py-8">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">Carregant lligues...</p>
      </div>
    {:else if preparationEvents.length > 0}
      <div class="space-y-6">
        <!-- Lligues en Preparació - Vista pública -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              🔧 Lligues en Preparació ({preparationEvents.length})
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
                      {#if event.data_inici}
                        <p class="text-sm text-gray-500 mt-1">
                          📅 Inici previst: {new Date(event.data_inici).toLocaleDateString('ca-ES')}
                        </p>
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
                      {:else if $user}
                        <span class="inline-flex items-center px-3 py-2 text-sm text-blue-600">
                          En preparació - Aviat disponible
                        </span>
                      {:else}
                        <span class="inline-flex items-center px-3 py-2 text-sm text-gray-500">
                          En preparació
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
                    class:text-gray-500={managementView !== 'view-calendar' && calendarStatus === 'not-generated'}
                    class:hover:text-gray-700={managementView !== 'view-calendar' && calendarStatus !== 'not-generated'}
                    class:hover:border-gray-300={managementView !== 'view-calendar' && calendarStatus !== 'not-generated'}
                    disabled={false}
                    class:opacity-50={calendarStatus === 'not-generated'}
                    title={calendarStatus === 'not-generated' ? 'Calendari no generat encara' : 'Visualitzar calendari generat'}
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

        <!-- Informació Completa de la Lliga Seleccionada - Visible per tots -->
        {#if selectedEventId && selectedEvent && activeEvents.find(e => e.id === selectedEventId)}
          <div class="space-y-6">

            {#if isUserAdmin}
              <!-- Vista Admin: Selector de lliga i navegació completa -->
              <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg leading-6 font-medium text-gray-900">
                      {selectedEvent.nom} - Gestió Admin
                    </h3>
                    <div class="flex space-x-3">
                      <button
                        on:click={() => downloadCalendariCSV(selectedEventId, selectedEvent.nom)}
                        class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                        title="Exportar calendari a CSV"
                      >
                        📄 Exportar CSV
                      </button>
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

                <!-- Navegació interna de la lliga -->
                <div class="border-b border-gray-200 mb-6">
                  <nav class="-mb-px flex space-x-8">
                    <button
                      on:click={() => managementView = 'view-calendar'}
                      class="py-2 px-1 border-b-2 font-medium text-sm"
                      class:border-green-500={managementView === 'view-calendar'}
                      class:text-green-600={managementView === 'view-calendar'}
                      class:border-transparent={managementView !== 'view-calendar'}
                      class:text-gray-500={managementView !== 'view-calendar'}
                      class:hover:text-gray-700={managementView !== 'view-calendar'}
                      class:hover:border-gray-300={managementView !== 'view-calendar'}
                    >
                      📅 Calendari
                    </button>
                    <button
                      on:click={() => managementView = 'inscriptions'}
                      class="py-2 px-1 border-b-2 font-medium text-sm"
                      class:border-green-500={managementView === 'inscriptions'}
                      class:text-green-600={managementView === 'inscriptions'}
                      class:border-transparent={managementView !== 'inscriptions'}
                      class:text-gray-500={managementView !== 'inscriptions'}
                      class:hover:text-gray-700={managementView !== 'inscriptions'}
                      class:hover:border-gray-300={managementView !== 'inscriptions'}
                    >
                      👥 Jugadors i Categories
                    </button>
                    <button
                      on:click={() => managementView = 'results'}
                      class="py-2 px-1 border-b-2 font-medium text-sm"
                      class:border-green-500={managementView === 'results'}
                      class:text-green-600={managementView === 'results'}
                      class:border-transparent={managementView !== 'results'}
                      class:text-gray-500={managementView !== 'results'}
                      class:hover:text-gray-700={managementView !== 'results'}
                      class:hover:border-gray-300={managementView !== 'results'}
                    >
                      🏆 Resultats
                    </button>
                    <button
                      on:click={() => managementView = 'standings'}
                      class="py-2 px-1 border-b-2 font-medium text-sm"
                      class:border-green-500={managementView === 'standings'}
                      class:text-green-600={managementView === 'standings'}
                      class:border-transparent={managementView !== 'standings'}
                      class:text-gray-500={managementView !== 'standings'}
                      class:hover:text-gray-700={managementView !== 'standings'}
                      class:hover:border-gray-300={managementView !== 'standings'}
                    >
                      📊 Classificació
                    </button>
                  </nav>
                </div>

                <!-- Contingut segons la vista seleccionada -->
                {#if managementView === 'view-calendar'}
                  <!-- Calendari de partides -->
                  <SocialLeagueCalendarViewer
                    eventId={selectedEventId}
                    categories={selectedEvent.categories || []}
                    isAdmin={isUserAdmin}
                    eventData={selectedEvent}
                    defaultMode="timeline"
                    editMode={isUserAdmin}
                    on:matchUpdated={() => {
                      console.log('Match updated');
                    }}
                  />

                {:else if managementView === 'inscriptions'}
                  <!-- Component unificat per mostrar jugadors inscrits -->
                  <SocialLeaguePlayersGrid 
                    eventId={selectedEventId} 
                    categories={selectedEvent?.categories || []} 
                  />

                {:else if managementView === 'results'}
                  <!-- Resultats de partides -->
                  <div class="space-y-4">
                    <h4 class="text-lg font-medium text-gray-900">Resultats de Partides</h4>
                    <SocialLeagueMatchResults
                      eventId={selectedEventId}
                      categories={selectedEvent.categories || []}
                      isAdmin={isUserAdmin}
                      isPublicView={true}
                    />
                  </div>

                {:else if managementView === 'standings'}
                  <!-- Classificació -->
                  <div class="space-y-6">
                    <h4 class="text-lg font-medium text-gray-900">Classificació per Categories</h4>

                    {#if selectedEvent.categories && selectedEvent.categories.length > 0}
                      <div class="space-y-6">
                        {#each selectedEvent.categories as category}
                          {@const categoryInscriptions = inscriptions.filter(i => i.categoria_assignada_id === category.id)}
                          <div class="bg-gray-50 rounded-lg p-6">
                            <div class="flex items-center justify-between mb-4">
                              <h5 class="text-lg font-medium text-gray-900">{category.nom}</h5>
                              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                                {categoryInscriptions.length} participants
                              </span>
                            </div>

                            {#if categoryInscriptions.length > 0}
                              <div class="bg-white rounded-lg overflow-hidden shadow">
                                <table class="min-w-full divide-y divide-gray-200">
                                  <thead class="bg-gray-50">
                                    <tr>
                                      <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        Posició
                                      </th>
                                      <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        Jugador
                                      </th>
                                      <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        PJ
                                      </th>
                                      <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        PG
                                      </th>
                                      <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        PP
                                      </th>
                                      <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        Punts
                                      </th>
                                      <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        %
                                      </th>
                                    </tr>
                                  </thead>
                                  <tbody class="bg-white divide-y divide-gray-200">
                                    {#each categoryInscriptions.sort((a, b) => (b.socis?.nom || '').localeCompare(a.socis?.nom || '')) as inscription, index}
                                      <tr class="hover:bg-gray-50">
                                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                          {index + 1}
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap">
                                          <div class="flex items-center">
                                            <div>
                                              <div class="text-sm font-medium text-gray-900">
                                                {inscription.socis?.nom} {inscription.socis?.cognoms}
                                              </div>
                                            </div>
                                          </div>
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                          0
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                          0
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                          0
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                          0
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                          0%
                                        </td>
                                      </tr>
                                    {/each}
                                  </tbody>
                                </table>
                              </div>
                              <div class="mt-3 text-center">
                                <p class="text-sm text-gray-500">
                                  💡 Les estadístiques es calcularan automàticament quan es juguin les partides
                                </p>
                              </div>
                            {:else}
                              <div class="text-center py-8">
                                <p class="text-gray-500">No hi ha participants en aquesta categoria</p>
                              </div>
                            {/if}
                          </div>
                        {/each}
                      </div>
                    {:else}
                      <div class="bg-gray-50 rounded-lg p-8 text-center">
                        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha categories configurades</h3>
                        <p class="mt-1 text-sm text-gray-500">Les categories es mostraran aquí quan estiguin disponibles</p>
                      </div>
                    {/if}
                  </div>
                {/if}
              </div>
            </div>
            {:else}
              <!-- Vista Pública: Dashboard simplificat per usuaris no admin -->
              <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg leading-6 font-medium text-gray-900">
                      Selecciona una lliga per veure la informació
                    </h3>
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
              </div>

              <!-- Dashboard públic simplificat -->
              {#if selectedEventId && selectedEvent}
                <!-- Navegació per pestanyes públiques -->
                <div class="bg-white shadow rounded-lg">
                  <div class="border-b border-gray-200">
                    <nav class="-mb-px flex space-x-8 px-6">
                      <button
                        on:click={() => managementView = 'inscriptions'}
                        class="py-3 px-1 border-b-2 font-medium text-sm"
                        class:border-blue-500={managementView === 'inscriptions'}
                        class:text-blue-600={managementView === 'inscriptions'}
                        class:border-transparent={managementView !== 'inscriptions'}
                        class:text-gray-500={managementView !== 'inscriptions'}
                        class:hover:text-gray-700={managementView !== 'inscriptions'}
                      >
                        👥 Jugadors per Categories
                      </button>
                      <button
                        on:click={() => managementView = 'view-calendar'}
                        class="py-3 px-1 border-b-2 font-medium text-sm"
                        class:border-blue-500={managementView === 'view-calendar'}
                        class:text-blue-600={managementView === 'view-calendar'}
                        class:border-transparent={managementView !== 'view-calendar'}
                        class:text-gray-500={managementView !== 'view-calendar'}
                        class:hover:text-gray-700={managementView !== 'view-calendar'}
                      >
                        📅 Calendari
                      </button>
                      <button
                        on:click={() => managementView = 'results'}
                        class="py-3 px-1 border-b-2 font-medium text-sm"
                        class:border-blue-500={managementView === 'results'}
                        class:text-blue-600={managementView === 'results'}
                        class:border-transparent={managementView !== 'results'}
                        class:text-gray-500={managementView !== 'results'}
                        class:hover:text-gray-700={managementView !== 'results'}
                      >
                        ⚡ Resultats
                      </button>
                      <button
                        on:click={() => managementView = 'standings'}
                        class="py-3 px-1 border-b-2 font-medium text-sm"
                        class:border-blue-500={managementView === 'standings'}
                        class:text-blue-600={managementView === 'standings'}
                        class:border-transparent={managementView !== 'standings'}
                        class:text-gray-500={managementView !== 'standings'}
                        class:hover:text-gray-700={managementView !== 'standings'}
                      >
                        🏆 Classificacions
                      </button>
                    </nav>
                  </div>

                  <!-- Contingut de cada pestanya -->
                  <div class="p-6">
                    {#if managementView === 'inscriptions'}
                      <!-- Jugadors per categories amb SocialLeaguePlayersGrid -->
                      <SocialLeaguePlayersGrid
                        eventId={selectedEventId}
                        categories={selectedEvent.categories || []}
                      />

                    {:else if managementView === 'view-calendar'}
                      <!-- Calendari -->
                      <SocialLeagueCalendarViewer
                        eventId={selectedEventId}
                        categories={selectedEvent.categories || []}
                        isAdmin={false}
                        eventData={selectedEvent}
                        defaultMode="timeline"
                        editMode={false}
                      />

                    {:else if managementView === 'results'}
                      <!-- Resultats -->
                      <SocialLeagueMatchResults
                        eventId={selectedEventId}
                        categories={selectedEvent.categories || []}
                        isAdmin={false}
                        isPublicView={true}
                      />

                    {:else if managementView === 'standings'}
                      <!-- Classificacions -->
                      <div class="space-y-6">
                        <h4 class="text-lg font-medium text-gray-900">Classificació per Categories</h4>

                        {#if selectedEvent.categories && selectedEvent.categories.length > 0}
                          <div class="space-y-6">
                            {#each selectedEvent.categories as category}
                              {@const categoryInscriptions = inscriptions.filter(i => i.categoria_assignada_id === category.id)}
                              <div class="bg-gray-50 rounded-lg p-6">
                                <div class="flex items-center justify-between mb-4">
                                  <h5 class="text-lg font-medium text-gray-900">{category.nom}</h5>
                                  <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                                    {categoryInscriptions.length} participants
                                  </span>
                                </div>

                                {#if categoryInscriptions.length > 0}
                                  <div class="bg-white rounded-lg overflow-hidden shadow">
                                    <table class="min-w-full divide-y divide-gray-200">
                                      <thead class="bg-gray-50">
                                        <tr>
                                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Posició
                                          </th>
                                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Jugador
                                          </th>
                                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            PJ
                                          </th>
                                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            PG
                                          </th>
                                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            PP
                                          </th>
                                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Punts
                                          </th>
                                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            %
                                          </th>
                                        </tr>
                                      </thead>
                                      <tbody class="bg-white divide-y divide-gray-200">
                                        {#each categoryInscriptions.sort((a, b) => (b.socis?.nom || '').localeCompare(a.socis?.nom || '')) as inscription, index}
                                          <tr class="hover:bg-gray-50">
                                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                              {index + 1}
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap">
                                              <div class="flex items-center">
                                                <div>
                                                  <div class="text-sm font-medium text-gray-900">
                                                    {inscription.socis?.nom} {inscription.socis?.cognoms}
                                                  </div>
                                                </div>
                                              </div>
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                              0
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                              0
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                              0
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                              0
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                              0%
                                            </td>
                                          </tr>
                                        {/each}
                                      </tbody>
                                    </table>
                                  </div>
                                  <div class="mt-3 text-center">
                                    <p class="text-sm text-gray-500">
                                      💡 Les estadístiques es calcularan automàticament quan es juguin les partides
                                    </p>
                                  </div>
                                {:else}
                                  <div class="text-center py-8">
                                    <p class="text-gray-500">No hi ha participants en aquesta categoria</p>
                                  </div>
                                {/if}
                              </div>
                            {/each}
                          </div>
                        {:else}
                          <div class="bg-gray-50 rounded-lg p-8 text-center">
                            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                            </svg>
                            <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha categories configurades</h3>
                            <p class="mt-1 text-sm text-gray-500">Les categories es mostraran aquí quan estiguin disponibles</p>
                          </div>
                        {/if}
                      </div>
                    {/if}
                  </div>
                </div>
              {/if}
            {/if}
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