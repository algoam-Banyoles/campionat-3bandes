<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import type { PageData } from './$types';
  import SocialLeagueCalendarViewer from '$lib/components/campionats-socials/SocialLeagueCalendarViewer.svelte';
  import SocialLeagueMatchResults from '$lib/components/campionats-socials/SocialLeagueMatchResults.svelte';
  import SocialLeaguePlayersGrid from '$lib/components/campionats-socials/SocialLeaguePlayersGrid.svelte';
  import SocialLeagueClassifications from '$lib/components/campionats-socials/SocialLeagueClassifications.svelte';
  import DragDropInscriptions from '$lib/components/campionats-socials/DragDropInscriptions.svelte';
  import CategorySetup from '$lib/components/campionats-socials/CategorySetup.svelte';
  import CategoryManagement from '$lib/components/campionats-socials/CategoryManagement.svelte';
  import CalendarGenerator from '$lib/components/admin/CalendarGenerator.svelte';
  import PlayerRestrictionsTable from '$lib/components/campionats-socials/PlayerRestrictionsTable.svelte';
  import HeadToHeadGrid from '$lib/components/campionats-socials/HeadToHeadGrid.svelte';
  import HallOfFame from '$lib/components/campionats-socials/HallOfFame.svelte';
  import { user } from '$lib/stores/auth';
  import { isAdmin, adminUser } from '$lib/stores/adminAuth';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import { getSocialLeagueEvents, exportCalendariToCSV } from '$lib/api/socialLeagues';
  import { generateFinalClassifications } from '$lib/api/classifications';
  import { supabase } from '$lib/supabaseClient';

  export const data: PageData = {} as PageData; // Unused export for type compatibility

  let events: any[] = [];
  let selectedEventId = '';
  let selectedEvent: any = null;
  let loading = false;
  type ViewType = 'preparation' | 'active' | 'history' | 'players' | 'inscriptions' | 'pagaments' | 'hall-of-fame';
  const validViews: ViewType[] = ['preparation', 'active', 'history', 'players', 'inscriptions', 'pagaments', 'hall-of-fame'];

  // Single source of truth: URL search param
  $: activeView = (validViews.includes($page.url.searchParams.get('view') as ViewType)
    ? $page.url.searchParams.get('view')
    : 'active') as ViewType;

  function setView(view: ViewType) {
    goto(`?view=${view}`, { replaceState: true, noScroll: true });
  }

  // Filtres per historial
  let historyModalityFilter = '';
  let historySeasonFilter = '';
  let displayLimit = 10;



  // Variables per la gestió d'inscripcions
  let managementView: 'inscriptions' | 'categories' | 'generate-calendar' | 'view-calendar' | 'restrictions' | 'results' | 'standings' | 'head-to-head' = 'view-calendar';
  let socis: any[] = [];
  let inscriptions: any[] = [];
  let loadingSocis = false;
  let loadingInscriptions = false;
  let _lastLoadedEventId = '';
  let calendarStatus = 'not-generated'; // 'not-generated', 'generated', 'validated', 'published'

  // Variable per la categoria seleccionada a la graella head-to-head
  let selectedHeadToHeadCategory: any = null;

  function getHistoricalModality(modality: string | undefined): string | null {
    const map: Record<string, string> = {
      tres_bandes: '3 BANDES',
      lliure: 'LLIURE',
      banda: 'BANDA'
    };
    return modality ? (map[modality] ?? null) : null;
  }

  function getPreviousTwoSeasonYears(season: string | undefined): number[] {
    const match = season?.match(/^(\d{4})\D+(\d{4})$/);
    if (match) {
      const endYear = Number(match[2]);
      return [endYear - 1, endYear - 2];
    }

    const now = new Date();
    const currentYear = now.getFullYear();
    return [currentYear - 1, currentYear - 2];
  }

  // Computed per verificar si és admin (comprovant tots dos sistemes i view mode)
  $: isUserAdmin = $isAdmin || $effectiveIsAdmin;

  // Categories per la pestanya de pagaments
  $: paymentCategories = selectedEvent?.categories || [];

  // Inscripcions ordenades per pagaments
  $: sortedInscriptions = inscriptions
    .filter(i => i && i.socis && i.socis.nom && i.socis.cognoms)
    .sort((a, b) => {
      const nomA = `${a.socis.cognoms || ''} ${a.socis.nom || ''}`.trim();
      const nomB = `${b.socis.cognoms || ''} ${b.socis.nom || ''}`.trim();
      return nomA.localeCompare(nomB);
    });

  // Funció per imprimir el llistat de pagaments
  function printPaymentList() {
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    const eventName = selectedEvent?.nom || 'Campionat Social';

    // Dividir en dues columnes
    const half = Math.ceil(sortedInscriptions.length / 2);
    const column1 = sortedInscriptions.slice(0, half);
    const column2 = sortedInscriptions.slice(half);

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Llistat de Pagaments - ${eventName}</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: Arial, sans-serif;
            padding: 20mm;
            font-size: 12pt;
          }
          h1 {
            text-align: center;
            margin-bottom: 5mm;
            font-size: 18pt;
          }
          .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 10mm;
            font-size: 11pt;
          }
          .columns {
            display: flex;
            gap: 15mm;
          }
          .column {
            flex: 1;
          }
          .item {
            display: flex;
            align-items: center;
            padding: 3mm 0;
            border-bottom: 1px solid #ddd;
          }
          .checkbox {
            width: 5mm;
            height: 5mm;
            border: 2px solid #000;
            margin-right: 3mm;
            flex-shrink: 0;
            display: inline-block;
          }
          .checkbox.checked::before {
            content: "✓";
            font-size: 14pt;
            font-weight: bold;
            line-height: 5mm;
            display: block;
            text-align: center;
          }
          .name {
            flex: 1;
          }
          @media print {
            body { padding: 10mm; }
          }
        </style>
      </head>
      <body>
        <h1>${eventName}</h1>
        <div class="subtitle">Llistat de Pagaments</div>
        <div class="columns">
          <div class="column">
            ${column1.map(i => `
              <div class="item">
                <span class="checkbox ${i.pagat ? 'checked' : ''}"></span>
                <span class="name">${i.socis.cognoms}, ${i.socis.nom}</span>
              </div>
            `).join('')}
          </div>
          <div class="column">
            ${column2.map(i => `
              <div class="item">
                <span class="checkbox ${i.pagat ? 'checked' : ''}"></span>
                <span class="name">${i.socis.cognoms}, ${i.socis.nom}</span>
              </div>
            `).join('')}
          </div>
        </div>
      </body>
      </html>
    `;

    printWindow.document.write(html);
    printWindow.document.close();
    printWindow.focus();
    setTimeout(() => {
      printWindow.print();
    }, 250);
  }

  // Funció manual per recalcular filtres i fer debug
  function recalculateFilters() {
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

  // Redefinir filtres segons els nous estats de campionat
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
    e.estat_competicio === 'ongoing' ||
    e.estat_competicio === 'pendent_validacio' // Temporalment inclòs fins que es validi
  ));



  $: historicalEvents = events.filter(e => !e.actiu || (
    e.estat_competicio === 'finalitzat' ||
    e.estat_competicio === 'tancat' ||
    e.estat_competicio === 'finished' ||
    e.estat_competicio === 'completed'
  ));

  // Filtrar esdeveniments històrics segons els filtres aplicats
  $: filteredHistoricalEvents = historicalEvents.filter(event => {
    const matchesModality = !historyModalityFilter || event.modalitat === historyModalityFilter;
    const matchesSeason = !historySeasonFilter || event.temporada === historySeasonFilter;
    return matchesModality && matchesSeason;
  });

  // Auto-seleccionar el campionat si només n'hi ha un actiu
  $: if (activeView === 'active' && activeEvents.length === 1 && !selectedEventId) {
    selectedEventId = activeEvents[0].id;
  }

  $: if (selectedEventId) {
    selectedEvent = events.find(e => e.id === selectedEventId);
    if (selectedEvent && selectedEventId !== _lastLoadedEventId && (activeView === 'preparation' || activeView === 'active')) {
      _lastLoadedEventId = selectedEventId;
      loadInscriptionsData();
      if (activeView === 'preparation') {
        checkCalendarStatus();
      }
    }
  }

  // Carregar events
  async function loadEvents() {
    try {
      events = await getSocialLeagueEvents();
    } catch (error) {
      console.error('Error loading events:', error);
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

  // Actualitzar estat del campionat
  async function updateEventStatus(eventId: string, newStatus: string) {
    try {
      const { error } = await supabase
        .from('events')
        .update({ estat_competicio: newStatus })
        .eq('id', eventId);

      if (error) throw error;

      // Si es finalitza el campionat, generar classificacions finals automàticament
      if (newStatus === 'finalitzat') {
        try {
          const result = await generateFinalClassifications(eventId);
        } catch (classError) {
          console.error('⚠️ Error generant classificacions finals:', classError);
          // No bloquejar el canvi d'estat si falla la generació de classificacions
        }
      }

      // Recarregar events per actualitzar la vista
      await loadEvents();

      // Actualitzar selectedEvent si és el mateix
      if (selectedEventId === eventId) {
        selectedEvent = events.find(e => e.id === eventId);
      }
    } catch (error) {
      console.error('Error updating event status:', error);
      alert(`Error actualitzant l'estat del campionat: ${error.message}`);
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
        const currentEvent = selectedEvent || events.find(e => e.id === selectedEventId);
        const lastTwoYears = getPreviousTwoSeasonYears(currentEvent?.temporada);
        const historicalModality = getHistoricalModality(currentEvent?.modalitat);

        let mitjanesQuery = supabase
          .from('mitjanes_historiques')
          .select('soci_id, mitjana, year, modalitat')
          .in('soci_id', socisNumbers)
          .in('year', lastTwoYears);

        if (historicalModality) {
          mitjanesQuery = mitjanesQuery.eq('modalitat', historicalModality);
        }

        const { data: mitjanes, error: mitjErr } = await mitjanesQuery;

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
          socis!inscripcions_soci_numero_fkey(numero_soci, nom, cognoms, email, data_naixement)
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
      return;
    }

    try {
      const { data: matches, error } = await supabase
        .from('calendari_partides')
        .select('id, estat')
        .eq('event_id', selectedEventId);

      if (error) {
        console.error('❌ Error checking calendar status:', error);
        return;
      }

      if (!matches || matches.length === 0) {
        calendarStatus = 'not-generated';
      } else {
        const validatedMatches = matches.filter(match => match.estat === 'validat');
        const publishedMatches = matches.filter(match => match.estat === 'publicat');
        
        if (publishedMatches.length > 0) {
          calendarStatus = 'published';
        } else if (validatedMatches.length === matches.length) {
          calendarStatus = 'validated';
        } else if (validatedMatches.length > 0) {
          calendarStatus = 'partially-validated';
        } else {
          calendarStatus = 'generated';
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

      events = await getSocialLeagueEvents();

      // Auto-seleccionar: campionats actius per defecte, preparació només per admins
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
      
      const hasViewParam = $page.url.searchParams.has('view');

      if (manualActiveEvent) {
        selectedEventId = manualActiveEvent.id;
        if (!hasViewParam) setView('active');
      } else if (activeEvent) {
        selectedEventId = activeEvent.id;
        if (!hasViewParam) setView('active');
      } else if (isUserAdmin && preparationEvent) {
        selectedEventId = preparationEvent.id;
        if (!hasViewParam) setView('preparation');
      } else {
        if (events.length > 0) {
          selectedEventId = events[0].id;
        }
        if (!hasViewParam) setView('active');
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

<div class="px-4 sm:px-6 lg:px-8 space-y-6 sm:space-y-8 lg:space-y-10 pb-safe">
  <!-- Header -->
  <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 sm:gap-6">
    <div class="flex-1 min-w-0">
      <h2 class="text-xl sm:text-2xl lg:text-3xl font-bold leading-7 text-gray-900">
        Campionats Socials
      </h2>
      <p class="mt-1 text-sm sm:text-base text-gray-500">
        Competicions socials per modalitats: Lliure, Banda i 3 Bandes
      </p>
    </div>
    <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:space-x-4">
      <!-- Navegació ràpida amb touch targets millors -->
      <div class="flex bg-gray-100 rounded-lg p-1 w-full sm:w-auto min-h-[44px]">
        <button
          on:click={() => setView('active')}
          class="flex-1 sm:flex-none px-3 sm:px-4 py-2 rounded-md text-sm font-medium transition-colors min-h-[40px] touch-manipulation"
          class:bg-white={activeView === 'active'}
          class:text-gray-900={activeView === 'active'}
          class:shadow-sm={activeView === 'active'}
          class:text-gray-500={activeView !== 'active'}
          class:hover:text-gray-700={activeView !== 'active'}
        >
          🏃 Actius
        </button>
        <button
          on:click={() => setView('history')}
          class="flex-1 sm:flex-none px-3 sm:px-4 py-2 rounded-md text-sm font-medium transition-colors min-h-[40px] touch-manipulation"
          class:bg-white={activeView === 'history'}
          class:text-gray-900={activeView === 'history'}
          class:shadow-sm={activeView === 'history'}
          class:text-gray-500={activeView !== 'history'}
          class:hover:text-gray-700={activeView !== 'history'}
        >
          📚 Historial
        </button>
        <button
          on:click={() => setView('hall-of-fame')}
          class="flex-1 sm:flex-none px-3 sm:px-4 py-2 rounded-md text-sm font-medium transition-colors min-h-[40px] touch-manipulation"
          class:bg-white={activeView === 'hall-of-fame'}
          class:text-gray-900={activeView === 'hall-of-fame'}
          class:shadow-sm={activeView === 'hall-of-fame'}
          class:text-gray-500={activeView !== 'hall-of-fame'}
          class:hover:text-gray-700={activeView !== 'hall-of-fame'}
        >
          🏆 Quadre d'Honor
        </button>
        {#if isUserAdmin}
          <button
            on:click={() => setView('preparation')}
            class="flex-1 sm:flex-none px-3 sm:px-4 py-2 rounded-md text-sm font-medium transition-colors min-h-[40px] touch-manipulation"
            class:bg-white={activeView === 'preparation'}
            class:text-gray-900={activeView === 'preparation'}
            class:shadow-sm={activeView === 'preparation'}
            class:text-gray-500={activeView !== 'preparation'}
            class:hover:text-gray-700={activeView !== 'preparation'}
          >
            🔧 Preparació
          </button>
          <button
            on:click={() => setView('pagaments')}
            class="flex-1 sm:flex-none px-2 sm:px-3 py-1 rounded-md text-xs sm:text-sm font-medium transition-colors"
            class:bg-white={activeView === 'pagaments'}
            class:text-gray-900={activeView === 'pagaments'}
            class:shadow-sm={activeView === 'pagaments'}
            class:text-gray-500={activeView !== 'pagaments'}
            class:hover:text-gray-700={activeView !== 'pagaments'}
          >
            💶 Pagaments
          </button>
        {/if}
      </div>
    </div>
  </div>

  <!-- Pestanya de pagaments (només admins) -->
  {#if activeView === 'pagaments' && isUserAdmin}
    {#if selectedEventId}
      <div class="bg-white border border-gray-200 rounded-lg p-6 mt-4">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h2 class="text-xl font-semibold text-gray-900">Pagaments d'inscripció</h2>
            <p class="text-sm text-gray-600 mt-1">Marca si cada jugador ha pagat la inscripció. Només visible per administradors.</p>
          </div>
          <button
            on:click={printPaymentList}
            class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
          >
            <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
            </svg>
            Imprimir
          </button>
        </div>

        <!-- Llista de pagaments amb millor responsivitat -->
        <div class="space-y-3">
          {#each sortedInscriptions as inscripcio}
            <div class="flex items-center py-3 px-2 border-b border-gray-200 hover:bg-gray-50 rounded">
              <div class="flex items-center min-h-[44px]">
                <input
                  id="payment-{inscripcio.id}"
                  type="checkbox"
                  checked={inscripcio.pagat}
                  on:change={async (e) => {
                    const nouPagat = e.target.checked;
                    const { error } = await supabase
                      .from('inscripcions')
                      .update({ pagat: nouPagat })
                      .eq('id', inscripcio.id);
                    if (!error) {
                      inscripcio.pagat = nouPagat;
                      await loadInscriptionsData();
                    } else {
                      alert('Error actualitzant pagament: ' + error.message);
                    }
                  }}
                  class="h-5 w-5 text-blue-600 border-gray-300 rounded focus:ring-blue-500 focus:ring-2 touch-manipulation"
                />
                <label for="payment-{inscripcio.id}" class="ml-4 text-sm sm:text-base font-medium text-gray-900 flex-1 cursor-pointer touch-manipulation">
                  {inscripcio.socis.cognoms}, {inscripcio.socis.nom}
                  <span class="block sm:inline text-xs text-gray-500 sm:ml-2">
                    ({paymentCategories.find(c => c.id === inscripcio.categoria_assignada_id)?.nom || '-'})
                  </span>
                </label>
              </div>
            </div>
          {/each}
        </div>
      </div>
    {:else}
      <p class="text-sm text-gray-500">Selecciona un campionat per veure els pagaments.</p>
    {/if}
  {/if}

  <!-- Barra d'informació d'usuari -->
  <!-- Info cards removed - no longer needed -->


  <!-- Contingut per Seccions -->
  {#if activeView === 'preparation' && isUserAdmin}
    <!-- Campionats en Preparació - Només admins -->
    {#if loading}
      <div class="text-center py-8">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">Carregant campionats...</p>
      </div>
    {:else if preparationEvents.length > 0}
      <div class="space-y-8">
        <!-- Campionats en Preparació - Vista pública -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              🔧 Campionats en Preparació ({preparationEvents.length})
            </h3>
            

            <div class="space-y-6">
              {#each preparationEvents as event}
                <div class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50">
                  <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                    <div class="flex-1">
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

                      {#if isUserAdmin}
                        <div class="mt-3">
                          <label for="status-{event.id}" class="block text-xs font-medium text-gray-700 mb-1">
                            Estat del Campionat
                          </label>
                          <select
                            id="status-{event.id}"
                            value={event.estat_competicio || 'preparacio'}
                            on:change={(e) => updateEventStatus(event.id, e.currentTarget.value)}
                            class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
                          >
                            <option value="preparacio">Preparació</option>
                            <option value="planificacio">Planificació</option>
                            <option value="inscripcions_obertes">Inscripcions Obertes</option>
                            <option value="pendent">Pendent</option>
                            <option value="pendent_validacio">Pendent Validació</option>
                            <option value="configuracio">Configuració</option>
                            <option value="programacio">Programació</option>
                            <option value="en_curs">En Curs</option>
                            <option value="finalitzat">Finalitzat</option>
                          </select>
                        </div>
                      {/if}
                    </div>
                    <div class="text-right">
                      {#if isUserAdmin}
                        <button
                          on:click={() => { selectedEventId = event.id; }}
                          class="inline-flex items-center justify-center px-4 py-3 border border-transparent text-sm font-medium rounded-lg text-white bg-orange-600 hover:bg-orange-700 min-h-[44px] touch-manipulation"
                        >
                          📋 Gestionar Inscripcions
                        </button>
                      {:else if $user}
                        <span class="inline-flex items-center justify-center px-4 py-3 text-sm text-blue-600 min-h-[44px]">
                          🔧 En preparació - Aviat disponible
                        </span>
                      {:else}
                        <span class="inline-flex items-center justify-center px-4 py-3 text-sm text-gray-500 min-h-[44px]">
                          🔧 En preparació
                        </span>
                      {/if}
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </div>

        <!-- Gestió d'Inscripcions del Campionat Seleccionat (només admins) -->
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
                  <option value="">-- Tria un campionat --</option>
                  {#each preparationEvents as event}
                    <option value={event.id}>
                      {event.nom} - {event.temporada}
                    </option>
                  {/each}
                </select>
              </div>

              <!-- Navegació de gestió -->
              <div class="border-b border-gray-200 mb-6">
                <nav class="-mb-px flex space-x-10 sm:space-x-12">
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
                <div class="space-y-8">
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
                    on:categoryUpdated={async () => {
                      await loadInscriptionsData();
                    }}
                  />

                  <!-- Bulk category setup and player assignment -->
                  <CategorySetup
                    eventId={selectedEventId}
                    {inscriptions}
                    {socis}
                    categories={selectedEvent.categories || []}
                    on:categoriesCreated={async () => {
                      _lastLoadedEventId = '';
                      await loadEvents();
                      await loadInscriptionsData();
                    }}
                    on:error={(e) => { console.error(e.detail.message); }}
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
                <div class="space-y-8">
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
                    <div class="flex flex-col sm:flex-row gap-4">
                      <button
                        on:click={() => managementView = 'generate-calendar'}
                        class="inline-flex items-center justify-center px-4 py-3 border border-blue-300 text-sm sm:text-base font-medium rounded-lg text-blue-700 bg-white hover:bg-blue-50 min-h-[44px] touch-manipulation"
                      >
                        🔨 Regenerar
                      </button>
                      {#if calendarStatus === 'generated' || calendarStatus === 'partially-validated'}
                        <button
                          on:click={validateCalendar}
                          class="inline-flex items-center justify-center px-4 py-3 border border-transparent text-sm sm:text-base font-medium rounded-lg text-white bg-green-600 hover:bg-green-700 min-h-[44px] touch-manipulation"
                        >
                          ✅ Validar Calendari
                        </button>
                      {:else if calendarStatus === 'validated'}
                        <span class="inline-flex items-center justify-center px-4 py-3 text-sm font-medium text-green-700 bg-green-100 rounded-lg min-h-[44px]">
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

                  {#if calendarStatus === 'validated' || calendarStatus === 'partially-validated'}
                    <!-- Llista de jugadors inscrits per categoria -->
                    <div class="mt-8">
                      <h4 class="text-lg font-medium text-gray-900 mb-4">Jugadors Inscrits per Categoria</h4>
                      <SocialLeaguePlayersGrid
                        eventId={selectedEventId}
                        categories={selectedEvent?.categories || []}
                        isAdmin={isUserAdmin}
                        event={selectedEvent}
                      />
                    </div>
                  {/if}
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
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha campionats en preparació</h3>
        <p class="mt-1 text-sm text-gray-500">Actualment no hi ha cap campionat social en fase de preparació d'inscripcions.</p>
      </div>
    {/if}

  {:else if activeView === 'active'}
    <!-- Campionats en Curs -->
    {#if loading}
      <div class="text-center py-8">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">Carregant campionats...</p>
      </div>
    {:else if activeEvents.length > 0}
      <div class="space-y-8">

        <!-- Informació Completa del Campionat Seleccionat - Visible per tots -->
        {#if selectedEventId && selectedEvent && activeEvents.find(e => e.id === selectedEventId)}
          <div class="space-y-8">

            {#if isUserAdmin}
              <!-- Vista Admin: Selector de campionat i navegació completa -->
              <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg leading-6 font-medium text-gray-900">
                      {selectedEvent.nom} - Gestió Admin
                    </h3>
                    <div class="flex flex-col sm:flex-row sm:items-center gap-4">
                      <div class="flex-1 min-w-0">
                        <label for="admin-event-selector" class="block text-sm font-medium text-gray-700 mb-2">Campionat</label>
                        <select
                          id="admin-event-selector"
                          bind:value={selectedEventId}
                          class="w-full px-4 py-3 border border-gray-300 rounded-lg text-sm sm:text-base focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 min-h-[44px] touch-manipulation bg-white"
                        >
                          <option value="">-- Tria un campionat --</option>
                          {#each activeEvents as event}
                            <option value={event.id}>
                              {event.nom} - {event.temporada}
                            </option>
                          {/each}
                        </select>
                      </div>
                    </div>
                  </div>

                <!-- Navegació interna del campionat -->
                <div class="border-b border-gray-200 mb-6">
                  <nav class="-mb-px flex space-x-6 sm:space-x-8">
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
                      on:click={() => managementView = 'results'}
                      class="py-2 px-1 border-b-2 font-medium text-sm"
                      class:border-green-500={managementView === 'results'}
                      class:text-green-600={managementView === 'results'}
                      class:border-transparent={managementView !== 'results'}
                      class:text-gray-500={managementView !== 'results'}
                      class:hover:text-gray-700={managementView !== 'results'}
                      class:hover:border-gray-300={managementView !== 'results'}
                    >
                      ⚡ Resultats
                    </button>
                    <button
                      on:click={() => {
                        managementView = 'head-to-head';
                        if (!selectedHeadToHeadCategory && selectedEvent?.categories?.length > 0) {
                          selectedHeadToHeadCategory = selectedEvent.categories[0];
                        }
                      }}
                      class="py-2 px-1 border-b-2 font-medium text-sm"
                      class:border-green-500={managementView === 'head-to-head'}
                      class:text-green-600={managementView === 'head-to-head'}
                      class:border-transparent={managementView !== 'head-to-head'}
                      class:text-gray-500={managementView !== 'head-to-head'}
                      class:hover:text-gray-700={managementView !== 'head-to-head'}
                      class:hover:border-gray-300={managementView !== 'head-to-head'}
                    >
                      🔲 Graelles
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
                      👥 Jugadors
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

                {:else if managementView === 'results'}
                  <!-- Resultats de partides -->
                  <div class="space-y-6">
                    <h4 class="text-lg font-medium text-gray-900">Resultats de Partides</h4>
                    <SocialLeagueMatchResults
                      eventId={selectedEventId}
                      categories={selectedEvent.categories || []}
                    />
                  </div>

                {:else if managementView === 'standings'}
                  <!-- Classificacions en temps real -->
                  <SocialLeagueClassifications
                    event={selectedEvent}
                    showDetails={true}
                  />

                {:else if managementView === 'inscriptions'}
                  <!-- Component unificat per mostrar jugadors inscrits -->
                  <SocialLeaguePlayersGrid
                    eventId={selectedEventId}
                    categories={selectedEvent?.categories || []}
                    isAdmin={isUserAdmin}
                    event={selectedEvent}
                  />

                {:else if managementView === 'head-to-head'}
                  <!-- Graella de resultats creuats -->
                  <div class="space-y-6">
                    <!-- Selector de categoria amb botons -->
                    <div class="space-y-4">
                      <h3 class="text-lg font-semibold text-gray-900">Graella de Resultats Creuats</h3>
                      <div class="flex flex-wrap gap-2">
                        {#each selectedEvent.categories || [] as category}
                          <button
                            on:click={() => selectedHeadToHeadCategory = category}
                            class="px-4 py-2 rounded-lg font-medium transition-colors"
                            class:bg-green-600={selectedHeadToHeadCategory?.id === category.id}
                            class:text-white={selectedHeadToHeadCategory?.id === category.id}
                            class:bg-gray-200={selectedHeadToHeadCategory?.id !== category.id}
                            class:text-gray-700={selectedHeadToHeadCategory?.id !== category.id}
                            class:hover:bg-green-500={selectedHeadToHeadCategory?.id === category.id}
                            class:hover:bg-gray-300={selectedHeadToHeadCategory?.id !== category.id}
                          >
                            {category.nom}
                          </button>
                        {/each}
                      </div>
                    </div>

                    <!-- Component de graella -->
                    {#if selectedHeadToHeadCategory}
                      <HeadToHeadGrid
                        eventId={selectedEventId}
                        categoriaId={selectedHeadToHeadCategory.id}
                        categoriaNom={selectedHeadToHeadCategory.nom}
                      />
                    {:else}
                      <div class="text-center py-12 text-gray-500">
                        Selecciona una categoria per veure la graella de resultats
                      </div>
                    {/if}
                  </div>
                {/if}
              </div>
            </div>
            {:else}
              <!-- Vista Pública: Auto-selecció del campionat actiu -->
              {#if activeEvents.length > 1}
                <!-- Només mostrem selector si hi ha més d'un campionat (cas excepcional) -->
                <div class="bg-white shadow rounded-lg">
                  <div class="px-4 py-5 sm:p-6">
                    <div class="flex flex-col space-y-4">
                      <h3 class="text-lg leading-6 font-medium text-gray-900">
                        Múltiples campionats actius - Selecciona un
                      </h3>
                      <div>
                        <label for="public-event-selector" class="block text-sm font-medium text-gray-700 mb-2">Campionat</label>
                        <select
                          id="public-event-selector"
                          bind:value={selectedEventId}
                          class="w-full px-4 py-3 border border-gray-300 rounded-lg text-base focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 min-h-[44px] touch-manipulation bg-white"
                        >
                          <option value="">-- Tria un campionat --</option>
                          {#each activeEvents as event}
                            <option value={event.id}>
                              {event.nom} - {event.temporada}
                            </option>
                          {/each}
                        </select>
                      </div>
                    </div>
                  </div>
                </div>
              {/if}

              <!-- Dashboard públic simplificat -->
              {#if selectedEventId && selectedEvent}
                <!-- Navegació per pestanyes públiques -->
                <div class="bg-white shadow rounded-lg">
                  <div class="border-b border-gray-200">
                    <nav class="-mb-px flex space-x-4 md:space-x-6 px-6">
                      <button
                        on:click={() => managementView = 'view-calendar'}
                        class="py-3 px-1 border-b-2 font-medium text-2xl md:text-sm"
                        class:border-blue-500={managementView === 'view-calendar'}
                        class:text-blue-600={managementView === 'view-calendar'}
                        class:border-transparent={managementView !== 'view-calendar'}
                        class:text-gray-500={managementView !== 'view-calendar'}
                        class:hover:text-gray-700={managementView !== 'view-calendar'}
                        title="Calendari"
                      >
                        <span class="md:hidden">📅</span>
                        <span class="hidden md:inline">📅 Calendari</span>
                      </button>
                      <button
                        on:click={() => managementView = 'results'}
                        class="py-3 px-1 border-b-2 font-medium text-2xl md:text-sm"
                        class:border-blue-500={managementView === 'results'}
                        class:text-blue-600={managementView === 'results'}
                        class:border-transparent={managementView !== 'results'}
                        class:text-gray-500={managementView !== 'results'}
                        class:hover:text-gray-700={managementView !== 'results'}
                        title="Resultats"
                      >
                        <span class="md:hidden">⚡</span>
                        <span class="hidden md:inline">⚡ Resultats</span>
                      </button>
                      <button
                        on:click={() => {
                          managementView = 'head-to-head';
                          if (!selectedHeadToHeadCategory && selectedEvent?.categories?.length > 0) {
                            selectedHeadToHeadCategory = selectedEvent.categories[0];
                          }
                        }}
                        class="py-3 px-1 border-b-2 font-medium text-2xl md:text-sm"
                        class:border-blue-500={managementView === 'head-to-head'}
                        class:text-blue-600={managementView === 'head-to-head'}
                        class:border-transparent={managementView !== 'head-to-head'}
                        class:text-gray-500={managementView !== 'head-to-head'}
                        class:hover:text-gray-700={managementView !== 'head-to-head'}
                        title="Graelles"
                      >
                        <span class="md:hidden">🔲</span>
                        <span class="hidden md:inline">🔲 Graelles</span>
                      </button>
                      <button
                        on:click={() => managementView = 'standings'}
                        class="py-3 px-1 border-b-2 font-medium text-2xl md:text-sm"
                        class:border-blue-500={managementView === 'standings'}
                        class:text-blue-600={managementView === 'standings'}
                        class:border-transparent={managementView !== 'standings'}
                        class:text-gray-500={managementView !== 'standings'}
                        class:hover:text-gray-700={managementView !== 'standings'}
                        title="Classificacions"
                      >
                        <span class="md:hidden">📊</span>
                        <span class="hidden md:inline">📊 Classificació</span>
                      </button>
                      <button
                        on:click={() => managementView = 'inscriptions'}
                        class="py-3 px-1 border-b-2 font-medium text-2xl md:text-sm"
                        class:border-blue-500={managementView === 'inscriptions'}
                        class:text-blue-600={managementView === 'inscriptions'}
                        class:border-transparent={managementView !== 'inscriptions'}
                        class:text-gray-500={managementView !== 'inscriptions'}
                        class:hover:text-gray-700={managementView !== 'inscriptions'}
                        title="Jugadors"
                      >
                        <span class="md:hidden">👥</span>
                        <span class="hidden md:inline">👥 Jugadors</span>
                      </button>
                    </nav>
                  </div>

                  <!-- Contingut de cada pestanya -->
                  <div class="p-6">
                    {#if managementView === 'view-calendar'}
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
                      />

                    {:else if managementView === 'standings'}
                      <!-- Classificacions en temps real -->
                      <SocialLeagueClassifications
                        event={selectedEvent}
                        showDetails={true}
                      />

                    {:else if managementView === 'inscriptions'}
                      <!-- Jugadors per categories amb SocialLeaguePlayersGrid -->
                      <SocialLeaguePlayersGrid
                        eventId={selectedEventId}
                        categories={selectedEvent.categories || []}
                        isAdmin={isUserAdmin}
                        event={selectedEvent}
                      />

                    {:else if managementView === 'head-to-head'}
                      <!-- Graella de resultats creuats -->
                      <div class="space-y-6">
                        <!-- Selector de categoria amb botons -->
                        <div class="space-y-4">
                          <h3 class="text-lg font-semibold text-gray-900">Graella de Resultats Creuats</h3>
                          <div class="flex flex-wrap gap-2">
                            {#each selectedEvent.categories || [] as category}
                              <button
                                on:click={() => selectedHeadToHeadCategory = category}
                                class="px-4 py-2 rounded-lg font-medium transition-colors"
                                class:bg-blue-600={selectedHeadToHeadCategory?.id === category.id}
                                class:text-white={selectedHeadToHeadCategory?.id === category.id}
                                class:bg-gray-200={selectedHeadToHeadCategory?.id !== category.id}
                                class:text-gray-700={selectedHeadToHeadCategory?.id !== category.id}
                                class:hover:bg-blue-500={selectedHeadToHeadCategory?.id === category.id}
                                class:hover:bg-gray-300={selectedHeadToHeadCategory?.id !== category.id}
                              >
                                {category.nom}
                              </button>
                            {/each}
                          </div>
                        </div>

                        <!-- Component de graella -->
                        {#if selectedHeadToHeadCategory}
                          <HeadToHeadGrid
                            eventId={selectedEventId}
                            categoriaId={selectedHeadToHeadCategory.id}
                            categoriaNom={selectedHeadToHeadCategory.nom}
                          />
                        {:else}
                          <div class="text-center py-12 text-gray-500">
                            Selecciona una categoria per veure la graella de resultats
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
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha campionats en curs</h3>
        <p class="mt-1 text-sm text-gray-500">Actualment no hi ha cap campionat social en curs.</p>
      </div>
    {/if}

  {:else if activeView === 'history'}
    <!-- Historial -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
          Historial de Campionats
        </h3>

        <!-- Filtres amb millor responsivitat mòbil -->
        <div class="mb-6 bg-gray-50 rounded-lg p-3 sm:p-4">
          <h4 class="text-sm sm:text-base font-medium text-gray-900 mb-3">Filtres</h4>
          <div class="space-y-4 sm:space-y-0 sm:grid sm:grid-cols-2 lg:grid-cols-3 sm:gap-4">
            <!-- Filtre de Modalitat -->
            <div>
              <label for="history-modalitat" class="block text-sm font-medium text-gray-700 mb-2">Modalitat</label>
              <select
                id="history-modalitat"
                bind:value={historyModalityFilter}
                class="w-full px-4 py-3 text-base border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 min-h-[44px] touch-manipulation bg-white"
              >
                <option value="">Totes les modalitats</option>
                <option value="tres_bandes">3 Bandes</option>
                <option value="lliure">Lliure</option>
                <option value="banda">Banda</option>
              </select>
            </div>

            <!-- Filtre de Temporada -->
            <div>
              <label for="history-temporada" class="block text-sm font-medium text-gray-700 mb-2">Temporada</label>
              <select
                id="history-temporada"
                bind:value={historySeasonFilter}
                class="w-full px-4 py-3 text-base border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 min-h-[44px] touch-manipulation bg-white"
              >
                <option value="">Totes les temporades</option>
                {#each [...new Set(historicalEvents.map(e => e.temporada))].sort().reverse() as temporada}
                  <option value={temporada}>{temporada}</option>
                {/each}
              </select>
            </div>

            <!-- Botó per netejar filtres -->
            <div class="flex items-end">
              <button
                on:click={() => {
                  historyModalityFilter = '';
                  historySeasonFilter = '';
                }}
                class="w-full px-4 py-3 text-sm sm:text-base bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors min-h-[44px] touch-manipulation font-medium"
              >
                🗑️ Netejar filtres
              </button>
            </div>
          </div>
        </div>

        {#if filteredHistoricalEvents.length > 0}
          <div class="space-y-4">
            {#each filteredHistoricalEvents.slice(0, displayLimit) as event}
              <div class="border border-gray-200 rounded-lg p-4 sm:p-6 hover:shadow-md transition-shadow">
                <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                  <div class="flex-1 min-w-0">
                    <h4 class="font-medium text-gray-900 text-base sm:text-lg">{event.nom}</h4>
                    <p class="text-sm text-gray-500 mt-1">
                      Temporada {event.temporada} •
                      {event.modalitat === 'tres_bandes' ? '3 Bandes' :
                       event.modalitat === 'lliure' ? 'Lliure' : 'Banda'}
                    </p>
                  </div>
                  <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
                    <span class="inline-flex items-center justify-center px-3 py-2 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      ✅ Finalitzat
                    </span>
                    <a
                      href="/campionats-socials/{event.id}/classificacio?from=history"
                      class="inline-flex items-center justify-center px-4 py-3 border border-transparent text-sm font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 transition-colors min-h-[44px] touch-manipulation"
                    >
                      📊 Classificació
                    </a>
                  </div>
                </div>
              </div>
            {/each}
          </div>

          <!-- Controls de paginació amb millor touch targets -->
          <div class="mt-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div class="text-sm text-gray-500 text-center sm:text-left">
              Mostrant {Math.min(displayLimit, filteredHistoricalEvents.length)} de {filteredHistoricalEvents.length} campionats
            </div>
            {#if filteredHistoricalEvents.length > displayLimit}
              <button
                on:click={() => displayLimit += 10}
                class="inline-flex items-center justify-center px-6 py-3 border border-transparent text-base font-medium rounded-lg text-blue-600 bg-blue-100 hover:bg-blue-200 transition-colors min-h-[44px] touch-manipulation"
              >
                📋 Mostrar més campionats
              </button>
            {/if}
          </div>
        {:else}
          <div class="text-center py-8">
            {#if historyModalityFilter || historySeasonFilter}
              <div class="text-center">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No s'han trobat campionats</h3>
                <p class="mt-1 text-sm text-gray-500">No hi ha cap campionat que compleixi els filtres aplicats.</p>
              </div>
            {:else}
              <p class="text-gray-500">No hi ha campionats històrics disponibles.</p>
            {/if}
          </div>
        {/if}
      </div>
    </div>

  {:else if activeView === 'hall-of-fame'}
    <!-- Quadre d'Honor -->
    <HallOfFame />

  {:else if activeView === 'inscriptions'}
    <!-- Inscripcions Obertes -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
          Inscripcions Obertes
        </h3>
        {#if openRegistrations.length > 0}
          <div class="space-y-6">
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
                    <div class="flex flex-col sm:flex-row gap-3">
                      <button
                        on:click={() => { selectedEventId = event.id; setView('inscriptions'); }}
                        class="inline-flex items-center justify-center px-4 py-3 border border-transparent text-sm font-medium rounded-lg text-blue-700 bg-blue-100 hover:bg-blue-200 min-h-[44px] touch-manipulation"
                      >
                        📋 Veure Calendari
                      </button>
                      {#if isUserAdmin}
                        <button
                          class="inline-flex items-center justify-center px-4 py-3 border border-transparent text-sm font-medium rounded-lg text-white bg-green-600 hover:bg-green-700 min-h-[44px] touch-manipulation"
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
            <p class="mt-1 text-sm text-gray-500">Actualment no hi ha cap campionat social amb inscripcions obertes.</p>
            {#if isUserAdmin}
              <div class="mt-6">
                <button
                  class="inline-flex items-center justify-center w-full sm:w-auto px-6 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 min-h-[48px] touch-manipulation"
                >
                  ➕ Obrir Inscripcions per a un Campionat
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
          Busca la trajectòria i estadístiques de qualsevol jugador dels campionats socials.
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

<style>
  /* Estils normals - ocultar header en pantalla */
  :global(.payment-list-header) {
    display: none;
  }

  @media print {
    /* Ocultar elements no necessaris per imprimir */
    :global(nav),
    :global(header),
    :global(footer),
    :global(.no-print),
    :global(button) {
      display: none !important;
    }

    /* Ocultar wrapper principal */
    :global(.px-4),
    :global(.sm\:px-6),
    :global(.lg\:px-8) {
      padding: 0 !important;
    }

    :global(body) {
      background: white !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    :global(#svelte),
    :global(main) {
      all: unset !important;
      display: block !important;
    }

    /* Assegurar que el contenidor de pagaments sigui visible */
    :global(.payment-list-container) {
      display: block !important;
      visibility: visible !important;
      position: relative !important;
    }

    /* Mostrar títol només en impressió */
    :global(.payment-list-header) {
      display: block !important;
      text-align: center !important;
      margin-bottom: 2rem !important;
    }

    :global(.payment-list-header h1) {
      font-size: 20pt !important;
      font-weight: bold !important;
      color: black !important;
      margin-bottom: 0.5rem !important;
    }

    :global(.payment-list-header p) {
      font-size: 12pt !important;
      color: #666 !important;
    }

    /* Ajustar pàgina */
    @page {
      margin: 1.5cm;
      size: A4;
    }

    /* Dues columnes en impressió */
    :global(.payment-grid) {
      display: grid !important;
      grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
      gap: 0 2rem !important;
      column-gap: 2rem !important;
    }

    /* Estil checkbox per imprimir */
    :global(.payment-grid input[type="checkbox"]) {
      -webkit-appearance: none;
      -moz-appearance: none;
      appearance: none;
      width: 16px !important;
      height: 16px !important;
      border: 2px solid black !important;
      border-radius: 3px !important;
      margin-right: 8px !important;
      position: relative;
      background: white !important;
      flex-shrink: 0 !important;
    }

    :global(.payment-grid input[type="checkbox"]:checked::before) {
      content: "✓";
      position: absolute;
      top: -2px;
      left: 1px;
      font-size: 14px;
      font-weight: bold;
      color: black;
    }

    /* Estils de les línies */
    :global(.payment-grid > div) {
      break-inside: avoid;
      page-break-inside: avoid;
      border-bottom: 1px solid #ccc !important;
      padding: 0.5rem 0 !important;
      display: flex !important;
      align-items: center !important;
    }

    :global(.payment-grid label) {
      font-size: 11pt !important;
      color: black !important;
      margin-left: 0.5rem !important;
      line-height: 1.2 !important;
    }

    /* Assegurar que tot el contingut sigui visible */
    * {
      print-color-adjust: exact !important;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
  }
</style>