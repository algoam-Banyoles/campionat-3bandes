<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { exportCalendariToCSV } from '$lib/api/socialLeagues';
  import PendingMatchesModal from './PendingMatchesModal.svelte';
  import OldMatchesModal from './OldMatchesModal.svelte';
  import CalendarMatchEditModal from './CalendarMatchEditModal.svelte';
  import CalendarMatchResultModal from './CalendarMatchResultModal.svelte';
  import CalendarIncompareixencaModal from './CalendarIncompareixencaModal.svelte';
  import CalendarTimelineView from './CalendarTimelineView.svelte';
  import CalendarCategoryView from './CalendarCategoryView.svelte';
  import CalendarUnprogrammedMatches from './CalendarUnprogrammedMatches.svelte';
  import CalendarFilterBar from './CalendarFilterBar.svelte';
  import CalendarHeaderControls from './CalendarHeaderControls.svelte';
  import CalendarPrintHeader from './CalendarPrintHeader.svelte';
  import {
    toLocalDateStr,
    getDayOfWeekCode,
    formatDate,
    generateAvailableDates as svcGenerateAvailableDates,
    generateTimelineData as svcGenerateTimelineData,
    groupByCategory as svcGroupByCategory,
    groupTimelineByDayAndHour as svcGroupTimelineByDayAndHour
  } from '$lib/services/calendarTimelineService';
  import {
    formatPlayerName,
    matchPlayerById,
    matchPlayerSearchText,
    generatePlayerSuggestions as svcGeneratePlayerSuggestions
  } from '$lib/services/calendarPlayerSearchService';
  import {
    generatePrintHTML as svcGeneratePrintHTML,
    buildPrintContext as svcBuildPrintContext
  } from '$lib/services/calendarPrintService';
  import {
    loadCalendarData as svcLoadCalendarData,
    loadSociByEmail as svcLoadSociByEmail
  } from '$lib/services/calendarDataService';
  import { downloadAsFile, sanitizeFilename } from '$lib/utils/downloadFile';
  import {
    saveMatchResult as svcSaveMatchResult,
    registerNoShow as svcRegisterNoShow,
    markAsUnprogrammed as svcMarkAsUnprogrammed,
    saveMatchEdit as svcSaveMatchEdit,
    markCalendarPublished as svcMarkCalendarPublished,
    swapMatchSchedule as svcSwapMatchSchedule,
    fetchMatchScores as svcFetchMatchScores
  } from '$lib/services/calendarMutationsService';

  const dispatch = createEventDispatcher();

  export let eventId: string = '';
  export let categories: any[] = [];
  export let isAdmin: boolean = false;
  export let eventData: any = null;
  export let defaultMode: 'category' | 'timeline' = 'timeline';
  export const editMode: boolean = false;

  // Funció per imprimir només la taula cronològica
  function printCalendar() {
    if (!matches || matches.length === 0) {
      alert('No hi ha dades de calendari per imprimir. Assegura\'t que el calendari estigui generat.');
      return;
    }

    const useDoubleColumn = confirm(
      'Tria el format d\'impressió:\n\n' +
      'Acceptar: Dues columnes (més compacte, més partides per pàgina)\n' +
      'Cancel·lar: Una columna (text més gran, més fàcil de llegir)'
    );

    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      alert('No s\'ha pogut obrir la finestra d\'impressió. Comprova que no estiguin bloquejades les finestres emergents.');
      return;
    }

    try {
      const printCtx = svcBuildPrintContext({
        matches,
        timelineData,
        selectedDate,
        selectedCategory,
        eventData,
        isAdmin,
        categories
      });
      const printHTML = svcGeneratePrintHTML(printCtx, useDoubleColumn);

      printWindow.document.open();
      printWindow.document.write(printHTML);
      printWindow.document.close();

      printWindow.onload = () => {
        printWindow.print();
        printWindow.close();
      };
    } catch (e: any) {
      console.error('Error generant la impressió:', e);
      alert('Error generant la impressió: ' + e.message);
      printWindow.close();
    }
  }



  let matches: any[] = [];
  let availableDates: Date[] = [];
  let timelineData: any[] = [];
  let unprogrammedMatches: any[] = [];
  let calendarConfig: any = {
    dies_setmana: ['dl', 'dt', 'dc', 'dj', 'dv'],
    hores_disponibles: ['18:00', '19:00'],
    taules_per_slot: 3
  };
  let loading = true;
  let error: string | null = null;
  let viewMode: 'category' | 'timeline' = defaultMode;
  let publishing = false;

  // Filtres
  let selectedCategory = '';
  let selectedDate = '';
  let selectedWeek = '';
  let playerSearch = '';
  let selectedPlayerId: string | null = null; // ID del jugador seleccionat (filtratge exacte)
  let playerSuggestions = [];
  let showOnlyMyMatches = false;
  let myPlayerData: any = null;

  // Edició (només per admins)
  let editingMatch: any = null;
  let editForm = {
    data_programada: '',
    hora_inici: '',
    taula_assignada: null,
    estat: 'generat',
    observacions_junta: ''
  };

  // Variables per l'intercanvi de partides
  let selectedMatches: Set<string> = new Set();
  let swapMode: boolean = false;

  // Variables per al modal de resultats
  let showResultModal = false;
  let resultMatch: any = null;
  let resultForm = {
    caramboles_jugador1: 0,
    caramboles_jugador2: 0,
    entrades: 0,
    observacions: ''
  };

  // Variables per al modal d'incompareixences
  let showIncompareixencaModal = false;
  let incompareixencaMatch: any = null;

  // Variables per al modal de partides pendents
  let showPendingMatchesModal = false;
  let selectedSlot: any = null;

  // Variable per al modal de partides antigues
  let showOldMatchesModal = false;

  const dayNames = {
    'dl': 'Dilluns',
    'dt': 'Dimarts',
    'dc': 'Dimecres',
    'dj': 'Dijous',
    'dv': 'Divendres',
    'ds': 'Dissabte',
    'dg': 'Diumenge'
  };

  const estatOptions = [
    { value: 'generat', label: 'Generat', color: 'bg-gray-100 text-gray-800' },
    { value: 'validat', label: 'Validat', color: 'bg-blue-100 text-blue-800' },
    { value: 'publicat', label: 'Publicat', color: 'bg-green-100 text-green-800' },
    { value: 'reprogramada', label: 'Reprogramada', color: 'bg-yellow-100 text-yellow-800' },
    { value: 'jugada', label: 'Jugada', color: 'bg-emerald-100 text-emerald-800' },
    { value: 'cancel·lada', label: 'Cancel·lada', color: 'bg-red-100 text-red-800' },
    { value: 'pendent_programar', label: 'Pendent programar', color: 'bg-orange-100 text-orange-800' }
  ];

  // Carregar dades quan canvia l'event
  $: if (eventId) {
    loadCalendarData();
  }

  // Generar dates disponibles per la vista timeline
  $: availableDates = generateAvailableDates(matches);
  $: timelineData = matches.length > 0 ? generateTimelineData(matches, calendarConfig, availableDates) : [];
  
  // Debug reactiu
  // $: {
  //   if (matches.length > 0) {
  //     console.log('🔍 Reactive update - matches:', matches.length);
  //     console.log('🔍 Reactive update - availableDates:', availableDates?.length || 0);
  //     console.log('🔍 Reactive update - timelineData:', timelineData?.length || 0);
  //   }
  // }

  // Estat combinat de loading.
  // IMPORTANT: no depenem de `matches.length > 0` perquè quan es fan múltiples uploads,
  // la llista pot quedar momentàniament buida i la UI pot quedar enganxada en l'estat "Carregant".
  $: isDataReady = !loading;
  
  // Debug per veure quan es considera que les dades estan llestes
  // $: {
  //   console.log('🔍 Data ready check:', {
  //     loading,
  //     matchesLength: matches.length,
  //     isDataReady,
  //     timelineDataLength: timelineData.length
  //   });
  // }

  // Load player data for logged-in user
  async function loadMyPlayerData() {
    if (!$user || !$user.email) {
      myPlayerData = null;
      return;
    }

    try {
      myPlayerData = await svcLoadSociByEmail(supabase, $user.email);
    } catch (e) {
      console.error('Error loading player data:', e);
      myPlayerData = null;
    }
  }

  // React to user changes
  $: if ($user) {
    console.log('🔍 User detected in calendar, loading player data:', $user.id);
    loadMyPlayerData();
  } else {
    console.log('🔍 No user in calendar');
    myPlayerData = null;
    showOnlyMyMatches = false;
  }

  // Debug myPlayerData changes
  $: console.log('🎯 Calendar - myPlayerData:', myPlayerData, 'showOnlyMyMatches:', showOnlyMyMatches);

  async function loadCalendarData() {
    if (!eventId) return;

    loading = true;
    error = null;

    try {
      const result = await svcLoadCalendarData(supabase, {
        eventId,
        isAdmin,
        categories
      });

      if (result.config) {
        calendarConfig = result.config;
      }
      matches = result.matches;
    } catch (e) {
      console.error('Error in loadCalendarData:', e);
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }


  // Wrappers fins que reactive blocks usin directament els serveis.
  function generateAvailableDates(matchesParam: any[] = []): Date[] {
    const currentMatches = matchesParam.length > 0 ? matchesParam : matches;
    return svcGenerateAvailableDates(currentMatches);
  }

  function generateTimelineData(
    matchesParam: any[] = [],
    configParam: any = null,
    datesParam: Date[] = []
  ): any[] {
    const currentMatches = matchesParam.length > 0 ? matchesParam : matches;
    const currentDates = datesParam.length > 0 ? datesParam : availableDates;
    const config = configParam || calendarConfig;
    return svcGenerateTimelineData(currentMatches, config, currentDates);
  }

  function getEstatStyle(estat: string) {
    const option = estatOptions.find(opt => opt.value === estat);
    return option?.color || 'bg-gray-100 text-gray-800';
  }

  // Filtrar dades
  $: filteredMatches = matches.filter(match => {
    // Filtrar partides passades - només mostrar partides futures o d'avui
    if (match.data_programada) {
      const matchDate = new Date(match.data_programada);
      const today = new Date();
      today.setHours(0, 0, 0, 0); // Resetear a inici del dia

      // Si la partida és anterior a avui, no la mostrem
      if (matchDate < today) return false;
    }

    // Filtrar per jugador: prioritzar ID si hi ha jugador seleccionat, sinó text
    if (showOnlyMyMatches && myPlayerData) {
      if (!matchPlayerById(match, myPlayerData.id)) return false;
    } else if (selectedPlayerId) {
      if (!matchPlayerById(match, selectedPlayerId)) return false;
    } else if (playerSearch.length >= 2) {
      const searchLower = playerSearch.toLowerCase().trim();
      const player1Match = matchPlayerSearchText(match.jugador1, searchLower);
      const player2Match = matchPlayerSearchText(match.jugador2, searchLower);
      if (!player1Match && !player2Match) return false;
    }

    if (selectedCategory && match.categoria_id !== selectedCategory) return false;
    if (selectedDate) {
      const matchDate = match.data_programada ?
        toLocalDateStr(new Date(match.data_programada)) : null;
      if (matchDate !== selectedDate) return false;
    }
    return true;
  });

  $: filteredTimeline = timelineData.filter(slot => {
    // Filtrar slots de dates passades - només mostrar dates futures o d'avui
    const slotDate = new Date(slot.dateStr);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (slotDate < today) return false;

    // Filtrar per jugador: prioritzar ID si hi ha jugador seleccionat, sinó text
    if (showOnlyMyMatches && myPlayerData) {
      if (!slot.match) return false;
      if (!matchPlayerById(slot.match, myPlayerData.id)) return false;
    } else if (selectedPlayerId) {
      if (!slot.match) return false;
      if (!matchPlayerById(slot.match, selectedPlayerId)) return false;
    } else if (playerSearch.length >= 2) {
      if (!slot.match) return false;
      const searchLower = playerSearch.toLowerCase().trim();
      const player1Match = matchPlayerSearchText(slot.match.jugador1, searchLower);
      const player2Match = matchPlayerSearchText(slot.match.jugador2, searchLower);
      if (!player1Match && !player2Match) return false;
    }

    if (selectedDate && slot.dateStr !== selectedDate) return false;
    if (selectedCategory && slot.match && slot.match.categoria_id !== selectedCategory) return false;

    return true;
  });


  // Separar partits programats i no programats
  $: programmedMatches = filteredMatches.filter(match => match.data_programada && !['pendent_programar'].includes(match.estat));
  $: {
    unprogrammedMatches = filteredMatches.filter(match =>
      (!match.data_programada || match.estat === 'pendent_programar') &&
      match.caramboles_jugador1 == null &&
      match.caramboles_jugador2 == null
    );

    // Ordenar per categoria
    unprogrammedMatches.sort((a, b) => {
      const catA = categories.find(c => c.id === a.categoria_id);
      const catB = categories.find(c => c.id === b.categoria_id);

      // Si ambdues categories tenen camp 'ordre', ordenar per ordre
      if (catA?.ordre !== undefined && catB?.ordre !== undefined) {
        return catA.ordre - catB.ordre;
      }

      // Si no, ordenar per nom de categoria
      const nomA = catA?.nom || a.categoria_nom || '';
      const nomB = catB?.nom || b.categoria_nom || '';
      return nomA.localeCompare(nomB);
    });
  }
  
  // Comptar slots amb partits del jugador cercat
  $: playerMatchSlots = filteredTimeline.filter(slot => slot.match).length;
    
  // Verificar si s'han generat slots
  $: hasValidSlots = filteredTimeline.length > 0;

  // Agrupar per categoria (vista categoria)
  $: matchesByCategory = groupByCategory(programmedMatches);

  // Agrupar timeline per dies i hores (vista cronològica)
  $: timelineGrouped = groupTimelineByDayAndHour(filteredTimeline);

  // Generar suggeriments de jugadors en temps real
  $: if (playerSearch.length >= 2) {
    generatePlayerSuggestions(playerSearch);
  } else {
    playerSuggestions = [];
  }

  // Wrappers fins que el codi consumidor passi a usar els serveis directament.
  function groupByCategory(arr: any[]) {
    return svcGroupByCategory(arr);
  }

  function groupTimelineByDayAndHour(timeline: any[]) {
    return svcGroupTimelineByDayAndHour(timeline);
  }

  function getCategoryName(categoryId: string) {
    const category = categories.find(c => c.id === categoryId);
    if (!category) return 'Desconeguda';
    return category.nom.replace(/\s*Categoria\s*/gi, '').trim();
  }

  // Mapa de noms de categories (id → nom curt) per a passar als subcomponents.
  $: categoryNames = categories.reduce<Record<string, string>>((acc, cat) => {
    acc[cat.id] = cat.nom?.replace(/\s*Categoria\s*/gi, '').trim() ?? 'Desconeguda';
    return acc;
  }, {});

  function generatePlayerSuggestions(searchText: string) {
    playerSuggestions = svcGeneratePlayerSuggestions(matches, searchText);
  }

  function selectPlayer(suggestion: any) {
    playerSearch = suggestion.displayName;
    selectedPlayerId = suggestion.id;
    playerSuggestions = [];
  }

  function clearPlayerSearch() {
    playerSearch = '';
    selectedPlayerId = null;
    playerSuggestions = [];
  }

  // Tancar suggeriments quan es fa clic fora
  function handleClickOutside(event: MouseEvent) {
    const target = event.target as Element;
    if (!target.closest('.player-search-container')) {
      playerSuggestions = [];
    }
  }

  // Funcions d'edició (només per admins)
  async function startEditing(match: any) {
    if (!isAdmin) return;

    editingMatch = match;
    editForm = {
      data_programada: match.data_programada ?
        toLocalDateStr(new Date(match.data_programada)) : '',
      hora_inici: match.hora_inici || '',
      taula_assignada: match.taula_assignada,
      estat: match.estat,
      observacions_junta: match.observacions_junta || ''
    };
  }

  function cancelEditing() {
    editingMatch = null;
  }

  // Funcions per gestionar resultats
  async function openResultModal(match: any) {
    if (!isAdmin) return;

    try {
      const scores = await svcFetchMatchScores(supabase, match.id);
      resultMatch = { ...match, ...scores };
      resultForm = {
        caramboles_jugador1: scores.caramboles_jugador1 ?? 0,
        caramboles_jugador2: scores.caramboles_jugador2 ?? 0,
        entrades: scores.entrades ?? 0,
        observacions: scores.observacions_junta ?? ''
      };
      showResultModal = true;
    } catch (e) {
      alert('Error carregant les dades de la partida: ' + formatSupabaseError(e));
    }
  }

  function closeResultModal() {
    showResultModal = false;
    resultMatch = null;
    resultForm = {
      caramboles_jugador1: 0,
      caramboles_jugador2: 0,
      entrades: 0,
      observacions: ''
    };
  }

  async function saveResult() {
    if (!resultMatch || !isAdmin) return;
    if (loading) return;

    if (resultForm.caramboles_jugador1 === 0 && resultForm.caramboles_jugador2 === 0) {
      alert('Introdueix les caramboles per ambdós jugadors');
      return;
    }

    loading = true;
    try {
      await svcSaveMatchResult(supabase, resultMatch.id, {
        caramboles_jugador1: resultForm.caramboles_jugador1,
        caramboles_jugador2: resultForm.caramboles_jugador2,
        entrades: resultForm.entrades,
        observacions: resultForm.observacions
      });

      closeResultModal();
      await loadCalendarData();
      dispatch('matchUpdated');
      alert('✅ Resultat guardat correctament!');
    } catch (err) {
      console.error('Error guardant resultat:', err);
      alert('Error guardant el resultat: ' + formatSupabaseError(err));
    } finally {
      loading = false;
    }
  }

  // Funcions per gestionar incompareixences
  function openIncompareixencaModal(match: any) {
    if (!isAdmin) return;
    incompareixencaMatch = match;
    showIncompareixencaModal = true;
  }

  function closeIncompareixencaModal() {
    showIncompareixencaModal = false;
    incompareixencaMatch = null;
  }

  async function marcarIncompareixenca(jugadorQueFalta: 1 | 2) {
    if (!incompareixencaMatch || !isAdmin) return;
    if (loading) return;

    const jugadorNom = jugadorQueFalta === 1
      ? formatPlayerName(incompareixencaMatch.jugador1)
      : formatPlayerName(incompareixencaMatch.jugador2);

    const confirmation = confirm(
      `Estàs segur que vols marcar incompareixença de ${jugadorNom}?\n\n` +
      `Això assignarà:\n` +
      `- Jugador present: 2 punts, 0 entrades\n` +
      `- Jugador absent: 0 punts, 50 entrades\n\n` +
      `Si el jugador té 2 incompareixences, serà eliminat del campionat.`
    );
    if (!confirmation) return;

    try {
      loading = true;
      const result = await svcRegisterNoShow(supabase, incompareixencaMatch.id, jugadorQueFalta);

      closeIncompareixencaModal();
      await loadCalendarData();
      dispatch('matchUpdated');

      if (result.jugador_eliminat) {
        alert(
          `⚠️ INCOMPAREIXENÇA REGISTRADA\n\n` +
          `El jugador ${jugadorNom} té ${result.incompareixences} incompareixences.\n` +
          `HA ESTAT ELIMINAT DEL CAMPIONAT.\n\n` +
          `Totes les seves partides pendents han estat anul·lades.`
        );
      } else {
        alert(
          `✅ INCOMPAREIXENÇA REGISTRADA\n\n` +
          `El jugador ${jugadorNom} té ${result.incompareixences} incompareixença(es).\n` +
          `Partida registrada amb els punts corresponents.`
        );
      }
    } catch (err) {
      console.error('Error registrant incompareixença:', err);
      alert('Error registrant la incompareixença: ' + formatSupabaseError(err));
    } finally {
      loading = false;
    }
  }

  async function convertToUnprogrammed(match: any) {
    if (!isAdmin) return;

    const confirmation = confirm(
      `Estàs segur que vols convertir aquesta partida en no programada?\n\n` +
      `${formatPlayerName(match.jugador1)} vs ${formatPlayerName(match.jugador2)}\n` +
      `Data: ${formatDate(new Date(match.data_programada))} a les ${match.hora_inici}\n\n` +
      `Aquesta acció eliminarà la data i hora programades.`
    );
    if (!confirmation) return;

    try {
      loading = true;
      await svcMarkAsUnprogrammed(supabase, match);
      await loadCalendarData();
      dispatch('matchUpdated');
      alert('Partida convertida a no programada correctament.');
    } catch (e) {
      console.error('Error converting match to unprogrammed:', e);
      error = formatSupabaseError(e);
      alert('Error al convertir la partida: ' + error);
    } finally {
      loading = false;
    }
  }

  async function programEmptySlot(slot: any) {
    if (!isAdmin) return;

    selectedSlot = slot;
    showPendingMatchesModal = true;
  }

  function handleMatchProgrammed() {
    showPendingMatchesModal = false;
    selectedSlot = null;
    loadCalendarData();
    dispatch('matchUpdated');
  }

  function closePendingMatchesModal() {
    showPendingMatchesModal = false;
    selectedSlot = null;
  }

  function convertOldMatchesToPending() {
    if (!isAdmin) return;
    showOldMatchesModal = true;
  }

  function handleMatchesConverted(event: CustomEvent) {
    showOldMatchesModal = false;
    loadCalendarData();
    dispatch('matchUpdated');
    alert(`✅ S'han convertit ${event.detail.count} partides a "Pendent de programar"`);
  }

  function closeOldMatchesModal() {
    showOldMatchesModal = false;
  }

  async function saveMatch() {
    if (!editingMatch || !isAdmin) return;

    try {
      loading = true;
      await svcSaveMatchEdit(supabase, editingMatch.id, {
        data_programada: editForm.data_programada,
        hora_inici: editForm.hora_inici,
        taula_assignada: editForm.taula_assignada,
        estat: editForm.estat,
        observacions_junta: editForm.observacions_junta
      });

      cancelEditing();
      await loadCalendarData();
      dispatch('matchUpdated');
    } catch (e) {
      error = formatSupabaseError(e);
      alert('Error guardant els canvis: ' + error);
    } finally {
      loading = false;
    }
  }

  async function publishCalendar() {
    if (!isAdmin || publishing) return;

    const validatedMatches = matches.filter(match => match.estat === 'validat');
    if (validatedMatches.length === 0) {
      error = 'No hi ha partits validats per publicar';
      return;
    }

    const confirmPublish = confirm(
      `Estàs segur que vols publicar ${validatedMatches.length} partits validats al calendari general?\n\n` +
      `Això farà que les partides apareguin al calendari de la PWA i seran visibles per tots els usuaris.`
    );
    if (!confirmPublish) return;

    publishing = true;
    error = null;

    try {
      await svcMarkCalendarPublished(supabase, eventId);
      await loadCalendarData();
      dispatch('calendarPublished', {
        eventId,
        publishedMatches: validatedMatches.length
      });
      alert(`✅ Calendari publicat correctament!\n\n${validatedMatches.length} partits ara són visibles al calendari general de la PWA.`);
    } catch (e) {
      console.error('Error publicant calendari:', e);
      error = formatSupabaseError(e);
    } finally {
      publishing = false;
    }
  }

  // Funcions per l'intercanvi de partides
  function toggleSwapMode() {
    swapMode = !swapMode;
    if (!swapMode) {
      selectedMatches.clear();
      selectedMatches = selectedMatches; // trigger reactivity
    }
  }

  function toggleMatchSelection(matchId: string) {
    if (selectedMatches.has(matchId)) {
      selectedMatches.delete(matchId);
    } else {
      // Limit to 2 selections for swapping
      if (selectedMatches.size >= 2) {
        alert('Només pots seleccionar 2 partides per intercanviar.');
        return;
      }
      selectedMatches.add(matchId);
    }
    selectedMatches = selectedMatches; // trigger reactivity
  }

  async function swapMatches() {
    if (selectedMatches.size !== 2) {
      error = 'Has de seleccionar exactament 2 partides per intercanviar.';
      return;
    }

    const matchIds = Array.from(selectedMatches);
    const match1 = matches.find(m => m.id === matchIds[0]);
    const match2 = matches.find(m => m.id === matchIds[1]);

    if (!match1 || !match2) {
      error = 'No s\'han pogut trobar les partides seleccionades.';
      return;
    }
    if (!match1.data_programada || !match1.hora_inici || !match2.data_programada || !match2.hora_inici) {
      error = 'Les partides han de tenir data i hora assignades per poder-les intercanviar.';
      return;
    }

    const confirmSwap = confirm(
      `Estàs segur que vols intercanviar aquestes partides?\n\n` +
      `Partida 1: ${formatPlayerName(match1.jugador1)} vs ${formatPlayerName(match1.jugador2)}\n` +
      `Data actual: ${formatDate(new Date(match1.data_programada))} a les ${match1.hora_inici}\n\n` +
      `Partida 2: ${formatPlayerName(match2.jugador1)} vs ${formatPlayerName(match2.jugador2)}\n` +
      `Data actual: ${formatDate(new Date(match2.data_programada))} a les ${match2.hora_inici}\n\n` +
      `Després de l'intercanvi, les dates i hores s'intercanviaran.`
    );
    if (!confirmSwap) return;

    try {
      await svcSwapMatchSchedule(supabase, match1, match2);
      await loadCalendarData();

      selectedMatches.clear();
      selectedMatches = selectedMatches;
      swapMode = false;

      dispatch('matchesSwapped', { match1Id: match1.id, match2Id: match2.id });
      alert('✅ Partides intercanviades correctament!');
    } catch (e) {
      console.error('Error intercanviant partides:', e);
      error = formatSupabaseError(e);
    }
  }

  // Funció per exportar calendari a CSV
  async function downloadCalendariCSV() {
    if (!eventId || !eventData) return;

    try {
      const csvContent = await exportCalendariToCSV(eventId);
      downloadAsFile(
        csvContent,
        `calendari_${sanitizeFilename(eventData.nom)}.csv`,
        'text/csv;charset=utf-8;'
      );
    } catch (e) {
      console.error('Error exporting calendar:', e);
      const errorMessage = e instanceof Error ? e.message : 'Error desconegut';
      alert(`Error exportant el calendari: ${errorMessage}`);
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

<style>
  @media print {
    /* Amagar TOT el contingut de la pàgina */
    :global(body *) {
      visibility: hidden !important;
    }

    /* Mostrar només l'encapçalament i la taula cronològica.
       Tant `.print-title-show` (a CalendarPrintHeader) com
       `.calendar-main-container` (a CalendarTimelineView) viuen ara
       als components fills, per això tot va amb `:global()`. */
    :global(.print-title-show),
    :global(.print-title-show *),
    :global(.calendar-main-container),
    :global(.calendar-main-container *) {
      visibility: visible !important;
    }

    /* Amagar elements específics dins els subcomponents (`:global` perquè
       `.print-hide` també l'usen els fills). */
    :global(.print-hide) {
      visibility: hidden !important;
      display: none !important;
    }

    :global(.no-print) {
      visibility: hidden !important;
      display: none !important;
    }

    /* Mostrar l'encapçalament en impressió (component fill) */
    :global(.print-title-show) {
      display: block !important;
      page-break-after: avoid !important;
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      width: 100% !important;
      z-index: 1000 !important;
      background: white !important;
    }

    /* Configuració de pàgina optimitzada per calendari */
    @page {
      margin: 0.4in 0.3in 0.2in 0.3in; /* top right bottom left - peu més petit */
      size: A4 landscape;
    }

    /* Reset de la pàgina per impressió */
    :global(html), :global(body) {
      width: 100% !important;
      height: auto !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    /* Contenidor de la taula per impressió - mogut a CalendarTimelineView */

    /* Estils generals optimitzats per llegibilitat */
    :global(body) {
      font-family: Arial, sans-serif !important;
      font-size: 12px !important;
      line-height: 1.3 !important;
      color: #000 !important;
    }

    /* Taules optimitzades per calendari cronològic.
       Les taules ara viuen als subcomponents — apliquem `:global()`. */
    :global(table) {
      width: 100% !important;
      border-collapse: collapse !important;
      page-break-inside: auto !important;
      margin-bottom: 10px !important;
    }

    :global(th), :global(td) {
      padding: 4px 6px !important;
      font-size: 10px !important;
      font-weight: normal !important;
      border: 0.5px solid #666 !important;
      text-align: left !important;
      vertical-align: middle !important;
      white-space: nowrap !important;
      overflow: hidden !important;
      text-overflow: ellipsis !important;
      line-height: 1.2 !important;
      height: 18px !important;
      max-height: 18px !important;
    }

    :global(th) {
      background-color: #e8e8e8 !important;
      font-weight: bold !important;
      font-size: 9px !important;
      text-transform: uppercase !important;
      border: 1px solid #333 !important;
      height: 20px !important;
      max-height: 20px !important;
    }

    /* Amplades específiques per columnes — mogudes a CalendarTimelineView */

    :global(.calendar-table .category-column) {
      width: 50px !important;
      min-width: 50px !important;
      max-width: 50px !important;
    }

    :global(.calendar-table .player-column) {
      width: 120px !important;
      min-width: 120px !important;
      max-width: 120px !important;
    }

    /* Estil compacte per noms de jugadors */
    :global(.player-name-compact) {
      font-size: 10px !important;
      font-weight: normal !important;
      margin: 0 !important;
      line-height: 1.2 !important;
      white-space: nowrap !important;
      overflow: hidden !important;
      text-overflow: ellipsis !important;
    }

    :global(.player-name-compact .font-semibold) {
      font-weight: bold !important;
      font-size: 10px !important;
    }

    :global(.vs-separator) {
      font-size: 8px !important;
      color: #666 !important;
      margin: 0 4px !important;
      font-weight: normal !important;
    }

    /* Estils específics per categories compactes */
    :global(.category-compact) {
      font-size: 8px !important;
      padding: 1px 4px !important;
      border-radius: 2px !important;
      font-weight: bold !important;
      background-color: #e0e0e0 !important;
      color: #333 !important;
    }

    /* Estils de billar/dia/hora compactes — moguts a CalendarTimelineView */

    /* Capçaleres de seccions */
    :global(h3), :global(h4) {
      margin: 10px 0 5px 0 !important;
      font-size: 14px !important;
      font-weight: bold !important;
      page-break-after: avoid !important;
    }

    /* Estils per encapçalament professional — moguts a CalendarPrintHeader */

    /* Divisions de dies */
    :global(.calendar-day-section) {
      page-break-inside: avoid !important;
      margin-bottom: 15px !important;
    }

    /* Capçaleres de dia més prominents */
    :global(.day-header) {
      background-color: #e0e0e0 !important;
      font-size: 13px !important;
      font-weight: bold !important;
      padding: 8px !important;
    }

    /* Capçaleres d'hora */
    :global(.hour-header) {
      background-color: #f5f5f5 !important;
      font-size: 12px !important;
      font-weight: bold !important;
      padding: 6px !important;
    }

    /* Cel·les match/empty — mogudes a CalendarTimelineView */

    /* Separadors principals entre dies i hores */
    :global(.day-separator) {
      border-right: 4px solid #333 !important;
      background-color: #e8e8e8 !important;
      font-weight: bold !important;
      font-size: 14px !important;
    }

    :global(.hour-separator) {
      border-right: 4px solid #333 !important;
      background-color: #f0f0f0 !important;
      font-weight: bold !important;
      font-size: 13px !important;
    }

    /* Separadors verticals jeràrquics — moguts a CalendarTimelineView */

    /* Línies de separació horitzontals específiques per calendari */
    :global(.day-separator-row) {
      border-top: 4px solid #333 !important;
    }

    :global(.hour-separator-row) {
      border-top: 2px solid #666 !important;
    }

    /* Millores generals de les línies de divisió */
    :global(tbody tr) {
      border-bottom: 1px solid #ddd !important;
    }

    /* Files de canvi de dia més destacades */
    :global(tbody tr.new-day) {
      border-top: 4px solid #333 !important;
    }

    /* Files de canvi d'hora més destacades */
    :global(tbody tr.new-hour) {
      border-top: 2px solid #666 !important;
    }

    /* Eliminar colors de fons que no siguin necessaris */
    :global(.bg-gray-50), :global(.bg-orange-50), :global(.hover\:bg-gray-50) {
      background-color: transparent !important;
    }

    /* Força salts de pàgina entre dies si cal - compatibilitat multi-navegador */
    :global(.print-page-break) {
      page-break-before: always !important;
      break-before: page !important; /* CSS3 modern */
      display: block !important;
      height: 0 !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    /* Assegurar que no es trenquin files de taula */
    :global(tr) {
      page-break-inside: avoid !important;
    }
  }

  /* Estils responsius del calendari (mòbil/tauleta/pantalla) — moguts a CalendarTimelineView */
</style>

<div class="space-y-6 main-calendar-container">
  <!-- Encapçalament professional per a impressió -->
  <CalendarPrintHeader eventName={eventData?.nom} temporada={eventData?.temporada} />

  <!-- Header amb controls -->
  <div class="bg-white border border-gray-200 rounded-lg p-6 print-header-hide">
    <CalendarHeaderControls
      totalMatches={matches.length}
      publishedCount={programmedMatches.filter(m => m.estat === 'publicat').length}
      isFilteringByPlayer={!!selectedPlayerId || playerSearch.length >= 2}
      {playerSearch}
      filteredMatchesCount={filteredMatches.length}
      {playerMatchSlots}
      {isAdmin}
      canPublish={programmedMatches.some(m => m.estat === 'validat')}
      {publishing}
      {loading}
      {swapMode}
      selectedMatchesCount={selectedMatches.size}
      on:publish={publishCalendar}
      on:convertOldMatches={convertOldMatchesToPending}
      on:toggleSwapMode={toggleSwapMode}
      on:confirmSwap={swapMatches}
      on:exportCSV={downloadCalendariCSV}
      on:print={printCalendar}
    />

    <CalendarFilterBar
      bind:selectedCategory
      bind:selectedDate
      bind:playerSearch
      bind:viewMode
      bind:showOnlyMyMatches
      {categories}
      {playerSuggestions}
      hasMyPlayerData={!!myPlayerData}
      on:playerInput={() => { selectedPlayerId = null; }}
      on:selectSuggestion={(e) => selectPlayer(e.detail.suggestion)}
      on:clearPlayerSearch={clearPlayerSearch}
      on:clearAllFilters={() => { selectedCategory = ''; selectedDate = ''; clearPlayerSearch(); }}
    />
  </div>

  <!-- Missatges d'error -->
  {#if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4 print-header-hide">
      <div class="text-red-800">{error}</div>
    </div>
  {/if}

  <!-- Loading -->
  {#if !isDataReady}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center print-header-hide">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">
        {loading ? 'Carregant calendari...' : 'Esperant dades del calendari...'}
      </p>
    </div>
  {:else if viewMode === 'category'}
    <!-- Vista per Categories -->
    <CalendarCategoryView
      {matchesByCategory}
      totalMatches={filteredMatches.length}
      {categoryNames}
      {isAdmin}
      {swapMode}
      {selectedMatches}
      on:toggleMatch={(e) => toggleMatchSelection(e.detail.matchId)}
      on:openResult={(e) => openResultModal(e.detail.match)}
      on:openIncompareixenca={(e) => openIncompareixencaModal(e.detail.match)}
      on:startEdit={(e) => startEditing(e.detail.match)}
      on:convertUnprogrammed={(e) => convertToUnprogrammed(e.detail.match)}
    />
  {:else}
    <!-- Vista Cronològica -->
    <CalendarTimelineView
      {timelineGrouped}
      {dayNames}
      {isAdmin}
      {swapMode}
      {selectedMatches}
      hasPlayerFilter={!!selectedPlayerId || playerSearch.length >= 2}
      hasOtherFilter={!!selectedDate || !!selectedCategory}
      {playerSearch}
      on:toggleMatch={(e) => toggleMatchSelection(e.detail.matchId)}
      on:openResult={(e) => openResultModal(e.detail.match)}
      on:openIncompareixenca={(e) => openIncompareixencaModal(e.detail.match)}
      on:startEdit={(e) => startEditing(e.detail.match)}
      on:convertUnprogrammed={(e) => convertToUnprogrammed(e.detail.match)}
      on:programSlot={(e) => programEmptySlot(e.detail.slot)}
    />
  {/if}

  <!-- Partides No Programades -->
  <CalendarUnprogrammedMatches
    matches={unprogrammedMatches}
    {isAdmin}
    {categoryNames}
    {estatOptions}
    on:program={(e) => startEditing(e.detail.match)}
  />
</div>

<!-- Modal d'edició (només per admins) -->
{#if isAdmin}
  <CalendarMatchEditModal
    match={editingMatch}
    {estatOptions}
    on:save={(e) => { editForm = { ...editForm, ...e.detail }; saveMatch(); }}
    on:cancel={cancelEditing}
  />
{/if}

<!-- Modal per introduir resultats -->
{#if showResultModal}
  <CalendarMatchResultModal
    match={resultMatch}
    categoryName={resultMatch ? getCategoryName(resultMatch.categoria_id) : ''}
    saving={loading}
    on:save={(e) => { resultForm = { ...resultForm, ...e.detail }; saveResult(); }}
    on:close={closeResultModal}
  />
{/if}

<!-- Modal d'Incompareixença -->
{#if showIncompareixencaModal}
  <CalendarIncompareixencaModal
    match={incompareixencaMatch}
    saving={loading}
    on:selectAbsent={(e) => marcarIncompareixenca(e.detail.player)}
    on:close={closeIncompareixencaModal}
  />
{/if}

<!-- Modal de Partides Pendents -->
{#if showPendingMatchesModal && selectedSlot}
  <PendingMatchesModal
    {eventId}
    {categories}
    slot={selectedSlot}
    on:matchProgrammed={handleMatchProgrammed}
    on:close={closePendingMatchesModal}
  />
{/if}

<!-- Modal de Partides Antigues -->
{#if showOldMatchesModal}
  <OldMatchesModal
    {eventId}
    {categories}
    on:matchesConverted={handleMatchesConverted}
    on:close={closeOldMatchesModal}
  />
{/if}
