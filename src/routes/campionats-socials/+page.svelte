<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
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
  import HeadToHeadPrintModal from '$lib/components/campionats-socials/HeadToHeadPrintModal.svelte';
  import HallOfFame from '$lib/components/campionats-socials/HallOfFame.svelte';
  import { user } from '$lib/stores/auth';
  import { isAdmin, adminUser } from '$lib/stores/adminAuth';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import { getSocialLeagueEvents, exportCalendariToCSV } from '$lib/api/socialLeagues';
  import { generateFinalClassifications } from '$lib/api/classifications';
  import { supabase } from '$lib/supabaseClient';
  import { showSuccess, showError, showWarning, showInfo } from '$lib/stores/toastStore';
  import { showConfirm } from '$lib/stores/confirmDialogStore';
  import {
    subscribeToEventUpdates,
    markEventLocallyMutated
  } from '$lib/services/realtimeEventsService';

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
  // Refs als modals d'impressió de la graella (un per branca; visualment idèntics)
  let h2hPrintModalAdmin: HeadToHeadPrintModal | null = null;
  let h2hPrintModalPublic: HeadToHeadPrintModal | null = null;

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

  // Realtime: canvis a l'event seleccionat (estat, publicació) propagats
  // entre clients per a admins concurrents.
  let unsubscribeEventRealtime: (() => void) | null = null;
  $: {
    if (unsubscribeEventRealtime) {
      unsubscribeEventRealtime();
      unsubscribeEventRealtime = null;
    }
    if (selectedEventId) {
      unsubscribeEventRealtime = subscribeToEventUpdates(supabase, selectedEventId, async (e) => {
        if (e.isLocalEcho) {
          await loadEvents();
          return;
        }
        if (e.type === 'estat_changed') {
          showInfo(`Estat del campionat actualitzat: ${e.newRow?.estat_competicio ?? '?'}`);
        } else if (e.type === 'calendari_published') {
          showInfo('Calendari publicat per un altre admin');
        } else if (e.type === 'actiu_toggled') {
          showInfo(e.newRow?.actiu ? 'Campionat activat' : 'Campionat desactivat');
        }
        await loadEvents();
      });
    }
  }
  onDestroy(() => {
    if (unsubscribeEventRealtime) unsubscribeEventRealtime();
  });

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
    } catch (error: any) {
      console.error('Error exporting calendar:', error);
      const errorMessage = error.message || 'Error desconegut';
      showError(`Error exportant el calendari: ${errorMessage}`);
    }
  }

  // Actualitzar estat del campionat
  async function updateEventStatus(eventId: string, newStatus: string) {
    try {
      markEventLocallyMutated(eventId);
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
    } catch (error: any) {
      console.error('Error updating event status:', error);
      showError(`Error actualitzant l'estat del campionat: ${error.message}`);
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
        showError('Error en inscriure el soci: ' + error.message);
        return;
      }

      // Reload data
      await loadInscriptionsData();
    } catch (error) {
      console.error('Error in handleInscribe:', error);
      showError('Error en inscriure el soci');
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
        showError('Error en moure la inscripció: ' + error.message);
        return;
      }

      // Reload data
      await loadInscriptionsData();
    } catch (error) {
      console.error('Error in handleMoveInscription:', error);
      showError('Error en moure la inscripció');
    }
  }

  async function handleRemoveInscription(event) {
    try {
      const { inscriptionId } = event.detail;

      const ok = await showConfirm({
        title: 'Eliminar inscripció',
        message: 'Estàs segur que vols eliminar aquesta inscripció?',
        severity: 'danger',
        confirmLabel: 'Eliminar'
      });
      if (!ok) return;

      const { data, error } = await supabase
        .from('inscripcions')
        .delete()
        .eq('id', inscriptionId);

      if (error) {
        console.error('Error removing inscription:', error);
        showError('Error en eliminar la inscripció: ' + error.message);
        return;
      }

      // Reload data
      await loadInscriptionsData();
    } catch (error) {
      console.error('Error in handleRemoveInscription:', error);
      showError('Error en eliminar la inscripció');
    }
  }

  function handleIntelligentMovementCompleted(event) {
    const { totalMoved, message } = event.detail;
    console.log('Intelligent movement completed:', message);

    showSuccess(`Moviment completat: ${message}`);

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
        showError('Error al verificar el calendari: ' + matchesError.message);
        return;
      }

      if (!matches || matches.length === 0) {
        showWarning('No hi ha partides generades al calendari. Genera primer el calendari.');
        managementView = 'generate-calendar';
        return;
      }

      // Validate calendar logic (check for conflicts, etc.)
      const conflicts = matches.filter(match => match.estat === 'conflicte');

      if (conflicts.length > 0) {
        const ok = await showConfirm({
          title: 'Conflictes al calendari',
          message: `Hi ha ${conflicts.length} conflictes al calendari.\n\nVols continuar amb la validació?`,
          severity: 'warning',
          confirmLabel: 'Continuar'
        });
        if (!ok) return;
      }

      // Update matches to validated state
      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update({ estat: 'validat', data_validacio: new Date().toISOString() })
        .eq('event_id', selectedEventId)
        .eq('estat', 'generat');

      if (updateError) {
        console.error('Error validating calendar:', updateError);
        showError('Error al validar el calendari: ' + updateError.message);
        return;
      }

      showSuccess('Calendari validat correctament! Ara pots publicar-lo.');

      // Update calendar status
      await checkCalendarStatus();
    } catch (error) {
      console.error('Error in validateCalendar:', error);
      showError('Error al validar el calendari');
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

<div class="socials-page pb-safe">
  <!-- ────────── Mast-head editorial ────────── -->
  <header class="page-mast">
    <div class="page-mast-head">
      <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">
        Campionats Socials
      </div>
      <h1 class="page-title">Socials per categories</h1>
      <p class="page-lede">
        Competicions socials per modalitats: 3 Bandes, Lliure i Banda
      </p>
    </div>
  </header>

  <!-- ────────── Subtabs editorials ────────── -->
  <nav class="page-subtabs" aria-label="Vistes de campionats socials">
    <button
      on:click={() => setView('active')}
      class="subtab"
      class:active={activeView === 'active'}
    >
      Actius
    </button>
    <button
      on:click={() => setView('history')}
      class="subtab"
      class:active={activeView === 'history'}
    >
      Historial
    </button>
    <button
      on:click={() => setView('hall-of-fame')}
      class="subtab"
      class:active={activeView === 'hall-of-fame'}
    >
      Quadre d'honor
    </button>
    {#if isUserAdmin}
      <button
        on:click={() => setView('preparation')}
        class="subtab subtab-admin"
        class:active={activeView === 'preparation'}
      >
        Preparació
      </button>
      <button
        on:click={() => setView('pagaments')}
        class="subtab subtab-admin"
        class:active={activeView === 'pagaments'}
      >
        Pagaments
      </button>
    {/if}
  </nav>

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
                      showError('Error actualitzant pagament: ' + error.message);
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
              <nav class="page-subtabs inner-subtabs" aria-label="Vistes de preparació">
                <button
                  on:click={() => managementView = 'inscriptions'}
                  class="subtab subtab-admin"
                  class:active={managementView === 'inscriptions'}
                >
                  Inscripcions
                </button>
                <button
                  on:click={() => managementView = 'categories'}
                  class="subtab subtab-admin"
                  class:active={managementView === 'categories'}
                >
                  Categories
                </button>
                <button
                  on:click={() => managementView = 'restrictions'}
                  class="subtab subtab-admin"
                  class:active={managementView === 'restrictions'}
                >
                  Restriccions
                </button>
                <button
                  on:click={() => managementView = 'generate-calendar'}
                  class="subtab subtab-admin subtab-with-dot"
                  class:active={managementView === 'generate-calendar'}
                >
                  Generar calendari
                  {#if calendarStatus === 'not-generated'}
                    <span class="status-dot dot-red" title="Calendari no generat"></span>
                  {/if}
                </button>
                <button
                  on:click={() => managementView = 'view-calendar'}
                  class="subtab subtab-admin subtab-with-dot"
                  class:active={managementView === 'view-calendar'}
                  class:disabled={calendarStatus === 'not-generated'}
                  title={calendarStatus === 'not-generated' ? 'Calendari no generat encara' : 'Visualitzar calendari generat'}
                >
                  Visualitzar calendari
                  {#if calendarStatus === 'generated'}
                    <span class="status-dot dot-amber" title="Pendent de validació"></span>
                  {:else if calendarStatus === 'validated'}
                    <span class="status-dot dot-green" title="Validat"></span>
                  {:else if calendarStatus === 'partially-validated'}
                    <span class="status-dot dot-blue" title="Parcialment validat"></span>
                  {/if}
                </button>
              </nav>

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
                <nav class="page-subtabs inner-subtabs" aria-label="Vistes del campionat">
                  <button
                    on:click={() => managementView = 'view-calendar'}
                    class="subtab"
                    class:active={managementView === 'view-calendar'}
                  >
                    Calendari
                  </button>
                  <button
                    on:click={() => managementView = 'results'}
                    class="subtab"
                    class:active={managementView === 'results'}
                  >
                    Resultats
                  </button>
                  <button
                    on:click={() => {
                      managementView = 'head-to-head';
                      if (!selectedHeadToHeadCategory && selectedEvent?.categories?.length > 0) {
                        selectedHeadToHeadCategory = selectedEvent.categories[0];
                      }
                    }}
                    class="subtab"
                    class:active={managementView === 'head-to-head'}
                  >
                    Graelles
                  </button>
                  <button
                    on:click={() => managementView = 'standings'}
                    class="subtab"
                    class:active={managementView === 'standings'}
                  >
                    Classificació
                  </button>
                  <button
                    on:click={() => managementView = 'inscriptions'}
                    class="subtab"
                    class:active={managementView === 'inscriptions'}
                  >
                    Jugadors
                  </button>
                </nav>

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
                  <div class="h2h-public">
                    <div class="h2h-toolbar">
                      <div class="cat-toggle">
                        {#each selectedEvent.categories || [] as category}
                          <button
                            on:click={() => selectedHeadToHeadCategory = category}
                            class="cat-pill"
                            class:active={selectedHeadToHeadCategory?.id === category.id}
                          >
                            {category.nom}
                          </button>
                        {/each}
                      </div>
                      <button
                        type="button"
                        class="h2h-print-btn"
                        on:click={() => h2hPrintModalAdmin?.open()}
                        disabled={!(selectedEvent?.categories?.length)}
                        title="Exportar la graella en format A3 apaïsat"
                      >
                        Imprimir (A3)
                      </button>
                    </div>

                    <!-- Component de graella -->
                    {#if selectedHeadToHeadCategory}
                      <HeadToHeadGrid
                        eventId={selectedEventId}
                        categoriaId={selectedHeadToHeadCategory.id}
                        categoriaNom={selectedHeadToHeadCategory.nom}
                      />
                    {:else}
                      <div class="state-empty">
                        Selecciona una categoria per veure la graella de resultats.
                      </div>
                    {/if}

                    {#if selectedEvent}
                      <HeadToHeadPrintModal
                        bind:this={h2hPrintModalAdmin}
                        event={selectedEvent}
                        categories={selectedEvent.categories || []}
                      />
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
                <!-- Navegació interna del campionat (idèntica a l'admin per congruència visual) -->
                <nav class="page-subtabs inner-subtabs" aria-label="Vistes del campionat">
                  <button
                    on:click={() => managementView = 'view-calendar'}
                    class="subtab"
                    class:active={managementView === 'view-calendar'}
                  >
                    Calendari
                  </button>
                  <button
                    on:click={() => managementView = 'results'}
                    class="subtab"
                    class:active={managementView === 'results'}
                  >
                    Resultats
                  </button>
                  <button
                    on:click={() => {
                      managementView = 'head-to-head';
                      if (!selectedHeadToHeadCategory && selectedEvent?.categories?.length > 0) {
                        selectedHeadToHeadCategory = selectedEvent.categories[0];
                      }
                    }}
                    class="subtab"
                    class:active={managementView === 'head-to-head'}
                  >
                    Graelles
                  </button>
                  <button
                    on:click={() => managementView = 'standings'}
                    class="subtab"
                    class:active={managementView === 'standings'}
                  >
                    Classificació
                  </button>
                  <button
                    on:click={() => managementView = 'inscriptions'}
                    class="subtab"
                    class:active={managementView === 'inscriptions'}
                  >
                    Jugadors
                  </button>
                </nav>

                <!-- Contingut de cada pestanya -->
                <div class="public-tab-content">
                  <div>
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
                      <div class="h2h-public">
                        <div class="h2h-toolbar">
                          <div class="cat-toggle">
                            {#each selectedEvent.categories || [] as category}
                              <button
                                on:click={() => selectedHeadToHeadCategory = category}
                                class="cat-pill"
                                class:active={selectedHeadToHeadCategory?.id === category.id}
                              >
                                {category.nom}
                              </button>
                            {/each}
                          </div>
                          <button
                            type="button"
                            class="h2h-print-btn"
                            on:click={() => h2hPrintModalPublic?.open()}
                            disabled={!(selectedEvent?.categories?.length)}
                            title="Exportar la graella en format A3 apaïsat"
                          >
                            Imprimir (A3)
                          </button>
                        </div>

                        <!-- Component de graella -->
                        {#if selectedHeadToHeadCategory}
                          <HeadToHeadGrid
                            eventId={selectedEventId}
                            categoriaId={selectedHeadToHeadCategory.id}
                            categoriaNom={selectedHeadToHeadCategory.nom}
                          />
                        {:else}
                          <div class="state-empty">
                            Selecciona una categoria per veure la graella de resultats.
                          </div>
                        {/if}

                        {#if selectedEvent}
                          <HeadToHeadPrintModal
                            bind:this={h2hPrintModalPublic}
                            event={selectedEvent}
                            categories={selectedEvent.categories || []}
                          />
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
    <!-- Historial editorial -->
    <section class="hist-section">
      <header class="hist-header">
        <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Campionats finalitzats</div>
        <h2 class="hist-title">Historial</h2>
      </header>

      <!-- Accés a vistes de mitjanes (per temporada i comparativa) -->
      <nav class="hist-extra-nav" aria-label="Mitjanes històriques">
        <a href="/campionats-socials/mitjanes-historiques" class="hist-extra-link">
          <span class="hist-extra-eyebrow">Mitjanes per temporada</span>
          <span class="hist-extra-cta">Veure totes les mitjanes registrades →</span>
        </a>
        <a href="/campionats-socials/mitjanes-comparatives" class="hist-extra-link">
          <span class="hist-extra-eyebrow">Comparativa entre temporades</span>
          <span class="hist-extra-cta">Comparar dues últimes temporades →</span>
        </a>
      </nav>

      <!-- Filtres -->
      <div class="hist-filters">
        <div class="hist-filter-field">
          <label for="history-modalitat" class="filter-legend">Modalitat</label>
          <select
            id="history-modalitat"
            bind:value={historyModalityFilter}
            class="filter-input"
          >
            <option value="">Totes les modalitats</option>
            <option value="tres_bandes">3 Bandes</option>
            <option value="lliure">Lliure</option>
            <option value="banda">Banda</option>
          </select>
        </div>

        <div class="hist-filter-field">
          <label for="history-temporada" class="filter-legend">Temporada</label>
          <select
            id="history-temporada"
            bind:value={historySeasonFilter}
            class="filter-input"
          >
            <option value="">Totes les temporades</option>
            {#each [...new Set(historicalEvents.map(e => e.temporada))].sort().reverse() as temporada}
              <option value={temporada}>{temporada}</option>
            {/each}
          </select>
        </div>

        <div class="hist-filter-field hist-filter-action">
          <button
            on:click={() => {
              historyModalityFilter = '';
              historySeasonFilter = '';
            }}
            class="hist-clear-btn"
          >
            Netejar filtres
          </button>
        </div>
      </div>

      {#if filteredHistoricalEvents.length > 0}
        <ul class="hist-list">
          {#each filteredHistoricalEvents.slice(0, displayLimit) as event}
            <li class="hist-row">
              <div class="hist-row-info">
                <div class="hist-row-name">{event.nom}</div>
                <div class="hist-row-meta">
                  Temporada <strong>{event.temporada}</strong> ·
                  {event.modalitat === 'tres_bandes' ? '3 Bandes' :
                   event.modalitat === 'lliure' ? 'Lliure' : 'Banda'}
                </div>
              </div>
              <div class="hist-row-actions">
                <span class="hist-status">Finalitzat</span>
                <a
                  href="/campionats-socials/{event.id}/classificacio?from=history"
                  class="hist-link"
                >
                  Veure classificació →
                </a>
              </div>
            </li>
          {/each}
        </ul>

        <div class="hist-pagination">
          <div class="hist-pagination-meta tabular-nums">
            Mostrant {Math.min(displayLimit, filteredHistoricalEvents.length)} de {filteredHistoricalEvents.length} campionats
          </div>
          {#if filteredHistoricalEvents.length > displayLimit}
            <button
              on:click={() => displayLimit += 10}
              class="hist-more-btn"
            >
              Mostrar més →
            </button>
          {/if}
        </div>
      {:else}
        <div class="state-empty" style="margin-top: 1.25rem;">
          {#if historyModalityFilter || historySeasonFilter}
            <div class="state-title">No s'han trobat campionats</div>
            <div class="state-sub">No hi ha cap campionat que compleixi els filtres aplicats.</div>
          {:else}
            <div class="state-title">No hi ha campionats històrics</div>
          {/if}
        </div>
      {/if}
    </section>

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
  /* ── Estils editorials del main page ──────────────── */
  .socials-page {
    width: 100%;
    max-width: 1180px;
    margin: 0 auto;
    padding: 0 1rem;
  }

  .page-mast {
    padding: 1.5rem 0 1.25rem;
    border-bottom: 2px solid var(--ink);
  }
  .page-mast-head { max-width: 56ch; }
  .page-title {
    font-family: var(--font-sans);
    font-weight: 800;
    font-size: 2.75rem;
    line-height: 1.05;
    letter-spacing: -0.035em;
    color: var(--ink);
    margin: 0;
    font-variation-settings: 'opsz' 32;
  }
  .page-lede {
    margin: 0.85rem 0 0;
    font-size: 1rem;
    color: var(--ink-2);
    font-weight: 500;
    line-height: 1.55;
  }

  /* Subtabs */
  .page-subtabs {
    display: flex;
    gap: 0;
    border-bottom: 1px solid var(--rule);
    margin-top: 0;
    overflow-x: auto;
    scrollbar-width: thin;
  }
  .subtab {
    background: transparent;
    border: none;
    padding: 0.85rem 0;
    margin-right: 1.75rem;
    color: var(--ink-3);
    font-family: var(--font-sans);
    font-weight: 500;
    font-size: 0.9375rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    position: relative;
    white-space: nowrap;
    min-height: 48px;
  }
  .subtab:hover { color: var(--ink-2); }
  .subtab.active {
    color: var(--ink);
    font-weight: 700;
  }
  .subtab.active::after {
    content: '';
    position: absolute;
    left: 0;
    right: 1.75rem;
    bottom: -1px;
    height: 2px;
    background: var(--ink);
  }
  .subtab.subtab-admin {
    color: var(--accent);
  }
  .subtab.subtab-admin:hover { opacity: 0.8; }
  .subtab.subtab-admin.active::after {
    background: var(--accent);
  }

  @media (max-width: 640px) {
    .page-title { font-size: 2rem; letter-spacing: -0.03em; }
    .page-lede { font-size: 0.9375rem; }
    .subtab { margin-right: 1.25rem; font-size: 0.875rem; }
  }

  /* Subtabs interns d'un campionat (gestió o detall) */
  .inner-subtabs {
    margin-bottom: 1.5rem;
  }

  /* Selector de categoria del head-to-head */
  .h2h-public {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .h2h-toolbar {
    display: flex;
    flex-wrap: wrap;
    gap: 0.6rem;
    align-items: center;
    justify-content: space-between;
  }
  .h2h-print-btn {
    background: var(--paper-elevated);
    border: 1px solid var(--ink);
    color: var(--ink);
    padding: 0.5rem 1rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 40px;
  }
  .h2h-print-btn:hover:not(:disabled) {
    background: var(--ink);
    color: var(--paper);
  }
  .h2h-print-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .cat-toggle {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
  }
  .cat-pill {
    background: transparent;
    border: 1px solid var(--rule-strong);
    color: var(--ink-2);
    padding: 0.5rem 0.95rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 40px;
  }
  .cat-pill:hover {
    color: var(--ink);
    border-color: var(--ink);
  }
  .cat-pill.active {
    background: var(--ink);
    color: var(--paper);
    border-color: var(--ink);
  }
  .subtab.disabled { opacity: 0.5; cursor: not-allowed; }
  .subtab-with-dot {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    position: relative;
  }
  .status-dot {
    display: inline-block;
    width: 0.55rem;
    height: 0.55rem;
    border-radius: 50%;
  }
  .status-dot.dot-red    { background: var(--accent); }
  .status-dot.dot-amber  { background: var(--amber); }
  .status-dot.dot-green  { background: var(--green); }
  .status-dot.dot-blue   { background: var(--blue); }

  /* ── Historial ─────────────────────────────────── */
  .hist-section {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.5rem 1.75rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .hist-header {
    margin-bottom: 1.25rem;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid var(--ink);
  }
  .hist-title {
    font-weight: 800;
    font-size: 1.5rem;
    letter-spacing: -0.022em;
    margin: 0;
    line-height: 1.15;
  }
  .hist-extra-nav {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-bottom: 1.25rem;
  }
  .hist-extra-link {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    padding: 0.95rem 1.1rem;
    border: 1px solid var(--rule-strong);
    background: var(--paper);
    color: var(--ink);
    text-decoration: none;
    transition: background 0.15s ease, border-color 0.15s ease;
  }
  .hist-extra-link:hover {
    background: var(--paper-elevated);
    border-color: var(--ink);
  }
  .hist-extra-eyebrow {
    font-size: 0.6875rem;
    font-weight: 700;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .hist-extra-cta {
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--ink);
    letter-spacing: -0.005em;
  }
  @media (max-width: 600px) {
    .hist-extra-nav { grid-template-columns: 1fr; }
  }
  .hist-filters {
    display: grid;
    grid-template-columns: 1fr 1fr auto;
    gap: 1rem;
    background: var(--paper);
    border: 1px solid var(--rule);
    padding: 1rem;
    margin-bottom: 1.25rem;
  }
  .hist-filter-field { display: flex; flex-direction: column; }
  .hist-filter-field .filter-legend {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--ink-3);
    margin-bottom: 0.4rem;
  }
  .hist-filter-action { justify-content: flex-end; }
  .filter-input {
    width: 100%;
    padding: 0.55rem 0.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    font-family: var(--font-sans);
    font-size: 0.9375rem;
    font-weight: 500;
    min-height: 44px;
  }
  .filter-input:focus {
    outline: 2px solid var(--ink);
    outline-offset: 1px;
    border-color: var(--ink);
  }
  .hist-clear-btn {
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
    padding: 0.55rem 1rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .hist-clear-btn:hover { opacity: 0.92; }
  .hist-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  .hist-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    padding: 1rem 0;
    border-top: 1px solid var(--rule);
    flex-wrap: wrap;
  }
  .hist-row:last-child { border-bottom: 1px solid var(--rule); }
  .hist-row-info { flex: 1; min-width: 0; }
  .hist-row-name {
    font-weight: 700;
    font-size: 1.0625rem;
    color: var(--ink);
    letter-spacing: -0.014em;
  }
  .hist-row-meta {
    margin-top: 0.25rem;
    font-size: 0.875rem;
    color: var(--ink-3);
  }
  .hist-row-meta strong { color: var(--ink-2); font-weight: 700; }
  .hist-row-actions {
    display: flex;
    align-items: center;
    gap: 0.85rem;
    flex-shrink: 0;
  }
  .hist-status {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    border: 1px solid var(--rule-strong);
    padding: 0.18rem 0.5rem;
  }
  .hist-link {
    color: var(--blue);
    font-weight: 600;
    font-size: 0.9375rem;
    text-decoration: none;
    border-bottom: 1px solid var(--blue);
    padding-bottom: 1px;
    white-space: nowrap;
  }
  .hist-link:hover { color: var(--ink); border-color: var(--ink); }
  .hist-pagination {
    margin-top: 1.25rem;
    padding-top: 1rem;
    border-top: 1px solid var(--rule);
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
  }
  .hist-pagination-meta {
    font-size: 0.8125rem;
    color: var(--ink-3);
  }
  .hist-more-btn {
    background: transparent;
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    padding: 0.55rem 1rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .hist-more-btn:hover { border-color: var(--ink); }
  .state-empty {
    padding: 1.5rem 1.75rem;
    background: var(--paper);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    text-align: center;
  }
  .state-title { font-weight: 700; font-size: 1.0625rem; color: var(--ink); }
  .state-sub { margin-top: 0.4rem; font-size: 0.875rem; color: var(--ink-3); }

  @media (max-width: 640px) {
    .hist-section { padding: 1rem 1.1rem; }
    .hist-filters { grid-template-columns: 1fr; padding: 0.85rem; }
    .hist-filter-action { justify-content: stretch; }
    .hist-row { align-items: flex-start; }
    .hist-row-actions { width: 100%; justify-content: space-between; }
  }

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