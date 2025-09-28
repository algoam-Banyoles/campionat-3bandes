<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { formatSupabaseError } from '$lib/ui/alerts';

  const dispatch = createEventDispatcher();

  export let eventId: string = '';
  export let categories: any[] = [];
  export let isAdmin: boolean = false;
  export let eventData: any = null;
  export let defaultMode: 'category' | 'timeline' = 'timeline';
  export let editMode: boolean = false;


  let matches: any[] = [];
  let calendarConfig: any = {
    dies_setmana: ['dl', 'dt', 'dc', 'dj', 'dv'],
    hores_disponibles: ['18:00', '19:00'],
    taules_per_slot: 3
  };
  let loading = true;
  let error: string | null = null;
  let viewMode: 'category' | 'timeline' = defaultMode;

  // Filtres
  let selectedCategory = '';
  let selectedDate = '';
  let selectedWeek = '';
  let playerSearch = '';
  let playerSuggestions = [];

  // Edició (només per admins)
  let editingMatch: any = null;
  let editForm = {
    data_programada: '',
    hora_inici: '',
    taula_assignada: null,
    estat: 'generat',
    observacions_junta: ''
  };

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
    { value: 'reprogramada', label: 'Reprogramada', color: 'bg-yellow-100 text-yellow-800' },
    { value: 'jugada', label: 'Jugada', color: 'bg-green-100 text-green-800' },
    { value: 'cancel·lada', label: 'Cancel·lada', color: 'bg-red-100 text-red-800' },
    { value: 'pendent_programar', label: 'Pendent programar', color: 'bg-orange-100 text-orange-800' }
  ];

  // Carregar dades quan canvia l'event
  $: if (eventId) {
    loadCalendarData();
  }

  // Generar dates disponibles per la vista timeline
  $: availableDates = generateAvailableDates(matches);
  $: timelineData = generateTimelineData(matches, calendarConfig, availableDates);

  async function loadCalendarData() {
    if (!eventId) return;

    loading = true;
    error = null;

    try {
      // Carregar configuració del calendari
      const { data: config, error: configError } = await supabase
        .from('configuracio_calendari')
        .select('*')
        .eq('event_id', eventId)
        .single();

      if (config) {
        calendarConfig = config;
      }

      // Carregar partits
      const { data: matchData, error: matchError } = await supabase
        .from('calendari_partides')
        .select(`
          id,
          categoria_id,
          data_programada,
          hora_inici,
          jugador1,
          jugador2,
          resultat_jugador1,
          resultat_jugador2,
          estat,
          observacions,
          taula_assignada
        `)
        .eq('event_id', eventId)
        .order('data_programada', { ascending: true });

      if (matchError) throw matchError;

      // Combinar dades de partits amb categories
      const matchesWithCategories = (matchData || []).map(match => {
        const category = categories.find(c => c.id === match.categoria_id);
        return {
          ...match,
          categories: category || null
        };
      });

      matches = matchesWithCategories;

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }


  function generateAvailableDates(matchesParam = []) {
    // SEMPRE generar un rang ampli de dates per mostrar tots els slots possibles
    let startDate, endDate;

    // Usar paràmetres passats o variables globals com a fallback
    const currentMatches = matchesParam.length > 0 ? matchesParam : matches;

    // Si hi ha partits programats, usar el rang de dates dels partits
    const validMatches = currentMatches.filter(m => m.data_programada);

    if (validMatches.length > 0) {
      // Usar dates dels partits programats
      const dates = validMatches.map(m => new Date(m.data_programada));
      startDate = new Date(Math.min(...dates));
      endDate = new Date(Math.max(...dates));

      // Per la vista cronològica: limitar fins a la data màxima del calendari
      // Afegir només 1 dia després de l'últim partit programat
      endDate.setDate(endDate.getDate() + 1);
    } else {
      // Si no hi ha partits programats, usar un rang per defecte
      // Començar des de fa 1 setmana i mostrar les properes 12 setmanes
      startDate = new Date();
      startDate.setDate(startDate.getDate() - 7); // Una setmana enrere
      endDate = new Date();
      endDate.setDate(endDate.getDate() + (12 * 7)); // 12 setmanes endavant
    }

    // Per la vista cronològica: començar exactament el primer dia amb partits
    const weekStart = new Date(startDate);
    // No ajustar al dilluns de la setmana, començar el dia exacte

    const weekEnd = new Date(endDate);
    weekEnd.setDate(weekEnd.getDate() + (7 - weekEnd.getDay())); // Diumenge

    const allDates = [];
    for (let date = new Date(weekStart); date <= weekEnd; date.setDate(date.getDate() + 1)) {
      allDates.push(new Date(date));
    }


    return allDates;
  }

  function generateTimelineData(matchesParam = [], configParam = null, datesParam = []) {
    const timeline = [];

    // Usar paràmetres passats o variables globals com a fallback
    const currentMatches = matchesParam.length > 0 ? matchesParam : matches;
    const currentDates = datesParam.length > 0 ? datesParam : availableDates;

    // Assegurar-nos que tenim configuració vàlida
    const config = configParam || calendarConfig || {
      dies_setmana: ['dl', 'dt', 'dc', 'dj', 'dv'],
      hores_disponibles: ['18:00', '19:00'],
      taules_per_slot: 3
    };


    let totalSlots = 0;
    let matchedSlots = 0;
    let validDays = 0;

    currentDates.forEach((date, index) => {
      const dayOfWeek = getDayOfWeekCode(date.getDay());

      // Només mostrar dies de la setmana configurats
      if (config.dies_setmana && config.dies_setmana.includes(dayOfWeek)) {
        validDays++;
        const hores = config.hores_disponibles || ['18:00', '19:00'];
        const taules = config.taules_per_slot || 3;


        hores.forEach(hora => {
          for (let taula = 1; taula <= taules; taula++) {
            const dateStr = date.toISOString().split('T')[0];
            totalSlots++;

            // Buscar partit programat per aquest slot
            const scheduledMatch = currentMatches.find(match => {
              if (!match.data_programada) return false;
              const matchDate = new Date(match.data_programada).toISOString().split('T')[0];
              const matchesDate = matchDate === dateStr;

              // Normalitzar format d'hores - eliminar segons si existeixen
              const normalizedSlotHora = hora; // ja ve en format HH:MM
              const normalizedMatchHora = match.hora_inici?.substring(0, 5); // eliminar :SS si existeix
              const matchesTime = normalizedMatchHora === normalizedSlotHora;

              const matchesTable = match.taula_assignada === taula;


              return matchesDate && matchesTime && matchesTable;
            });

            if (scheduledMatch) {
              matchedSlots++;
            }

            timeline.push({
              date,
              dateStr,
              dayOfWeek,
              hora,
              taula,
              match: scheduledMatch || null
            });
          }
        });
      }
    });

    return timeline;
  }

  function getDayOfWeekCode(dayIndex: number) {
    const days = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];
    return days[dayIndex];
  }

  function formatDate(date: Date) {
    return date.toLocaleDateString('ca-ES', {
      weekday: 'short',
      day: 'numeric',
      month: 'short'
    });
  }

  function getEstatStyle(estat: string) {
    const option = estatOptions.find(opt => opt.value === estat);
    return option?.color || 'bg-gray-100 text-gray-800';
  }

  // Filtrar dades
  $: filteredMatches = matches.filter(match => {
    if (selectedCategory && match.categoria_id !== selectedCategory) return false;
    if (selectedDate) {
      const matchDate = match.data_programada ?
        new Date(match.data_programada).toISOString().split('T')[0] : null;
      if (matchDate !== selectedDate) return false;
    }
    if (playerSearch.length >= 2) {
      const searchLower = playerSearch.toLowerCase().trim();
      const player1Match = matchPlayerSearchText(match.jugador1, searchLower);
      const player2Match = matchPlayerSearchText(match.jugador2, searchLower);
      if (!player1Match && !player2Match) return false;
    }
    return true;
  });

  $: filteredTimeline = timelineData.filter(slot => {
    if (selectedDate && slot.dateStr !== selectedDate) return false;
    if (selectedCategory && slot.match && slot.match.categoria_id !== selectedCategory) return false;
    if (playerSearch.length >= 2) {
      const searchLower = playerSearch.toLowerCase().trim();

      // Si hi ha cerca de jugador, només mostrar dies i hores on el jugador té partits
      const hasPlayerMatchAtThisSlot = matches.some(match => {
        if (!match.data_programada) return false;
        const matchDate = new Date(match.data_programada).toISOString().split('T')[0];
        const matchTime = match.hora_inici;

        // Verificar que coincideix data i hora
        if (matchDate !== slot.dateStr || matchTime !== slot.hour) return false;

        const player1Match = matchPlayerSearchText(match.jugador1, searchLower);
        const player2Match = matchPlayerSearchText(match.jugador2, searchLower);
        return player1Match || player2Match;
      });

      // Si no hi ha cap partit del jugador en aquest slot específic, no mostrar el slot
      if (!hasPlayerMatchAtThisSlot) return false;

      // Si és un slot amb partit, verificar que el jugador hi participa
      if (slot.match) {
        const player1Match = matchPlayerSearchText(slot.match.jugador1, searchLower);
        const player2Match = matchPlayerSearchText(slot.match.jugador2, searchLower);
        if (!player1Match && !player2Match) return false;
      }
    }
    return true;
  });

  // Separar partits programats i no programats
  $: programmedMatches = filteredMatches.filter(match => match.data_programada && match.estat !== 'pendent_programar');
  $: unprogrammedMatches = filteredMatches.filter(match => !match.data_programada || match.estat === 'pendent_programar');

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

  function groupByCategory(matches: any[]) {
    const groups = new Map();

    matches.forEach(match => {
      const categoryId = match.categoria_id;
      if (!groups.has(categoryId)) {
        groups.set(categoryId, []);
      }
      groups.get(categoryId).push(match);
    });

    return groups;
  }

  function groupTimelineByDayAndHour(timeline: any[]) {
    const grouped = new Map();

    timeline.forEach(slot => {
      const dateKey = slot.dateStr;
      const hourKey = slot.hora;

      if (!grouped.has(dateKey)) {
        grouped.set(dateKey, new Map());
      }

      if (!grouped.get(dateKey).has(hourKey)) {
        grouped.get(dateKey).set(hourKey, []);
      }

      grouped.get(dateKey).get(hourKey).push(slot);
    });

    return grouped;
  }

  function getCategoryName(categoryId: string) {
    const category = categories.find(c => c.id === categoryId);
    if (!category) return 'Desconeguda';

    // Eliminar la paraula "Categoria" del nom si existeix
    return category.nom.replace(/\s*Categoria\s*/gi, '').trim();
  }

  function formatPlayerName(jugador: any) {
    if (!jugador) return 'Jugador desconegut';

    // Handle JSON string data
    let playerData = jugador;
    if (typeof jugador === 'string') {
      try {
        playerData = JSON.parse(jugador);
      } catch {
        return jugador;
      }
    }

    // Si tenim nom i cognoms
    if (playerData.nom && playerData.cognoms) {
      const nom = playerData.nom.trim();
      const cognoms = playerData.cognoms.trim();

      // Obtenir primera inicial del nom
      const inicialNom = nom.charAt(0).toUpperCase();

      // Obtenir primer cognom (dividir per espais i agafar el primer)
      const primerCognom = cognoms.split(' ')[0];

      return `${inicialNom}. ${primerCognom}`;
    }

    // Prioritzar dades de socis (estructura antiga)
    if (playerData.socis?.nom && playerData.socis?.cognoms) {
      const nom = playerData.socis.nom.trim();
      const cognoms = playerData.socis.cognoms.trim();

      // Obtenir primera inicial del nom
      const inicialNom = nom.charAt(0).toUpperCase();

      // Obtenir primer cognom (dividir per espais i agafar el primer)
      const primerCognom = cognoms.split(' ')[0];

      return `${inicialNom}. ${primerCognom}`;
    }

    // Fallback només al nom
    if (playerData.nom) {
      return playerData.nom;
    }

    return 'Nom no disponible';
  }

  function matchPlayerSearchText(jugador: any, searchLower: string) {
    if (!jugador) return false;

    // Handle JSON string data
    let playerData = jugador;
    if (typeof jugador === 'string') {
      try {
        playerData = JSON.parse(jugador);
      } catch {
        return jugador.toLowerCase().includes(searchLower);
      }
    }

    // Buscar en nom complet
    if (playerData.nom && playerData.cognoms) {
      const nomComplet = `${playerData.nom} ${playerData.cognoms}`.toLowerCase();
      if (nomComplet.includes(searchLower)) return true;
    }

    // Buscar en nom
    if (playerData.nom && playerData.nom.toLowerCase().includes(searchLower)) return true;

    // Buscar en cognoms
    if (playerData.cognoms && playerData.cognoms.toLowerCase().includes(searchLower)) return true;

    // Buscar en número de soci
    if (playerData.numero_soci && playerData.numero_soci.toString().includes(searchLower)) return true;

    return false;
  }

  function generatePlayerSuggestions(searchText: string) {
    if (searchText.length < 2) {
      playerSuggestions = [];
      return;
    }

    const searchLower = searchText.toLowerCase().trim();
    const uniquePlayers = new Map();

    // Recollir tots els jugadors únics dels partits
    matches.forEach(match => {
      [match.jugador1, match.jugador2].forEach(jugador => {
        if (!jugador) return;

        // Handle JSON string data
        let playerData = jugador;
        if (typeof jugador === 'string') {
          try {
            playerData = JSON.parse(jugador);
          } catch {
            return;
          }
        }

        const playerId = playerData.numero_soci || playerData.id || `player_${Math.random()}`;
        if (uniquePlayers.has(playerId)) return;

        if (matchPlayerSearchText(jugador, searchLower)) {
          const fullName = playerData.nom && playerData.cognoms
            ? `${playerData.nom} ${playerData.cognoms}`
            : (playerData.socis?.nom && playerData.socis?.cognoms
              ? `${playerData.socis.nom} ${playerData.socis.cognoms}`
              : playerData.nom || 'Desconegut');

          uniquePlayers.set(playerId, {
            id: playerId,
            jugador,
            displayName: formatPlayerName(jugador),
            fullName: fullName
          });
        }
      });
    });

    playerSuggestions = Array.from(uniquePlayers.values())
      .sort((a, b) => a.displayName.localeCompare(b.displayName))
      .slice(0, 10); // Limitar a 10 suggeriments
  }

  function selectPlayer(suggestion: any) {
    playerSearch = suggestion.fullName;
    playerSuggestions = [];
  }

  function clearPlayerSearch() {
    playerSearch = '';
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
        new Date(match.data_programada).toISOString().split('T')[0] : '',
      hora_inici: match.hora_inici || '',
      taula_assignada: match.taula_assignada,
      estat: match.estat,
      observacions_junta: match.observacions_junta || ''
    };
  }

  function cancelEditing() {
    editingMatch = null;
  }

  async function saveMatch() {
    if (!editingMatch || !isAdmin) return;

    try {
      const updates: any = {
        estat: editForm.estat,
        taula_assignada: editForm.taula_assignada,
        observacions_junta: editForm.observacions_junta || null
      };

      if (editForm.data_programada && editForm.hora_inici) {
        updates.data_programada = editForm.data_programada + 'T' + editForm.hora_inici + ':00';
        updates.hora_inici = editForm.hora_inici;
      }

      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update(updates)
        .eq('id', editingMatch.id);

      if (updateError) throw updateError;

      await loadCalendarData();
      cancelEditing();
      dispatch('matchUpdated');

    } catch (e) {
      error = formatSupabaseError(e);
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

<style>
  @media print {
    /* Amagar tot excepte la vista cronològica */
    .no-print,
    .print-header-hide,
    .print-category-hide {
      display: none !important;
    }

    /* Mostrar títol només en impressió */
    .print-title-show {
      display: block !important;
      page-break-after: avoid !important;
    }

    /* Amagar columnes específiques */
    .print-hide {
      display: none !important;
    }

    /* Configuració de pàgina optimitzada */
    @page {
      margin: 0.3in;
      size: A4 landscape;
    }

    /* Estils generals optimitzats per llegibilitat */
    body {
      font-family: Arial, sans-serif !important;
      font-size: 12px !important;
      line-height: 1.3 !important;
      color: #000 !important;
    }

    /* Taules optimitzades per calendari cronològic */
    table {
      width: 100% !important;
      border-collapse: collapse !important;
      page-break-inside: auto !important;
      margin-bottom: 10px !important;
    }

    /* Cel·les amb text més gran i llegible */
    th, td {
      padding: 8px 10px !important;
      font-size: 13px !important;
      font-weight: normal !important;
      border: 1px solid #333 !important;
      text-align: left !important;
      vertical-align: middle !important;
    }

    /* Capçaleres de taula destacades */
    th {
      background-color: #f0f0f0 !important;
      font-weight: bold !important;
      font-size: 12px !important;
    }

    /* Capçaleres de seccions */
    h3, h4, h5 {
      margin: 10px 0 5px 0 !important;
      font-size: 14px !important;
      font-weight: bold !important;
      page-break-after: avoid !important;
    }

    /* Títols d'impressió */
    .print-title-show h1 {
      font-size: 18px !important;
      font-weight: bold !important;
      margin-bottom: 5px !important;
    }

    .print-title-show h2 {
      font-size: 16px !important;
      font-weight: normal !important;
      margin-bottom: 3px !important;
    }

    .print-title-show h3 {
      font-size: 14px !important;
      font-weight: normal !important;
      margin-bottom: 15px !important;
    }

    /* Divisions de dies */
    .calendar-day-section {
      page-break-inside: avoid !important;
      margin-bottom: 15px !important;
    }

    /* Capçaleres de dia més prominents */
    .day-header {
      background-color: #e0e0e0 !important;
      font-size: 13px !important;
      font-weight: bold !important;
      padding: 8px !important;
    }

    /* Capçaleres d'hora */
    .hour-header {
      background-color: #f5f5f5 !important;
      font-size: 12px !important;
      font-weight: bold !important;
      padding: 6px !important;
    }

    /* Cel·les amb partits - més visibles */
    .match-cell {
      background-color: #fafafa !important;
      font-weight: bold !important;
      font-size: 14px !important;
    }

    /* Cel·les buides */
    .empty-cell {
      color: #666 !important;
      font-style: italic !important;
    }

    /* Separadors principals entre dies i hores */
    .day-separator {
      border-right: 4px solid #333 !important;
      background-color: #e8e8e8 !important;
      font-weight: bold !important;
      font-size: 14px !important;
    }

    .hour-separator {
      border-right: 4px solid #333 !important;
      background-color: #f0f0f0 !important;
      font-weight: bold !important;
      font-size: 13px !important;
    }

    /* Separadors verticals jeràrquics */
    .calendar-table .day-column,
    .calendar-table .hour-column {
      border-right: 4px solid #1f2937 !important;
    }

    .calendar-table th:nth-child(3),
    .calendar-table td:nth-child(3) {
      border-right: 2px solid #6b7280 !important;
    }

    .calendar-table th,
    .calendar-table td {
      border-right: 2px solid #666 !important;
    }

    /* Línies de separació horitzontals específiques per calendari */
    .day-separator-row {
      border-top: 4px solid #333 !important;
    }

    .hour-separator-row {
      border-top: 2px solid #666 !important;
    }

    /* Millores generals de les línies de divisió */
    tbody tr {
      border-bottom: 1px solid #ddd !important;
    }

    /* Files de canvi de dia més destacades */
    tbody tr.new-day {
      border-top: 4px solid #333 !important;
    }

    /* Files de canvi d'hora més destacades */
    tbody tr.new-hour {
      border-top: 2px solid #666 !important;
    }

    /* Eliminar colors de fons que no siguin necessaris */
    .bg-blue-50, .bg-gray-50, .bg-orange-50, .hover\:bg-gray-50 {
      background-color: transparent !important;
    }

    /* Força salts de pàgina entre dies si cal */
    .print-page-break {
      page-break-before: always !important;
    }

    /* Assegurar que no es trenquin files de taula */
    tr {
      page-break-inside: avoid !important;
    }
  }

  /* Estils responsivos per dispositius mòbils */
  @media (max-width: 768px) {
    .calendar-table {
      font-size: 16px !important;
    }

    .calendar-table th,
    .calendar-table td {
      padding: 8px 6px !important;
      font-size: 14px !important;
      line-height: 1.4 !important;
    }

    .calendar-table .day-column {
      min-width: 80px !important;
    }

    .calendar-table .hour-column {
      min-width: 60px !important;
    }

    .calendar-table .player-column {
      min-width: 100px !important;
    }

    /* Text més gran per gent gran en mòbil */
    .calendar-table .font-bold {
      font-size: 16px !important;
    }

    .calendar-table .font-semibold {
      font-size: 15px !important;
    }
  }

  /* Estils per tablets */
  @media (min-width: 769px) and (max-width: 1024px) {
    .calendar-table th,
    .calendar-table td {
      font-size: 15px !important;
      padding: 10px 8px !important;
    }
  }

  /* Millores generals per línies de divisió més visibles */
  .calendar-table {
    border: 2px solid #374151 !important;
  }

  .calendar-table th,
  .calendar-table td {
    border: 1px solid #d1d5db !important;
  }

  .calendar-table tbody tr {
    border-bottom: 1px solid #d1d5db !important;
  }

  /* Separadors especials per dies i hores més destacats */
  .calendar-table tbody tr:where(.border-t-4) {
    border-top: 4px solid #374151 !important;
  }

  .calendar-table tbody tr:where(.border-t-2) {
    border-top: 2px solid #6b7280 !important;
  }
</style>

<div class="space-y-6">
  <!-- Títol d'impressió (només visible en impressió) -->
  <div class="print-title-show" style="display: none;">
    <div class="text-center mb-6">
      <h1 class="text-2xl font-bold text-gray-900 mb-2">
        {eventData?.nom || 'Campionat de Billar'}
      </h1>
      <h2 class="text-lg text-gray-700">
        Temporada {eventData?.temporada || new Date().getFullYear()}
      </h2>
      <h3 class="text-md text-gray-600 mt-2">
        Calendari de Partits - Vista Cronològica
      </h3>
    </div>
  </div>

  <!-- Header amb controls -->
  <div class="bg-white border border-gray-200 rounded-lg p-6 print-header-hide">
    <div class="flex items-center justify-between mb-4">
      <div>
        <h3 class="text-lg font-medium text-gray-900">Calendari de Partits</h3>
        {#if matches.length > 0}
          <div class="mt-1 text-sm text-gray-600">
            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 mr-2">
              ✅ {programmedMatches.length} programats
            </span>
            {#if unprogrammedMatches.length > 0}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-orange-100 text-orange-800 mr-2">
                ⏳ {unprogrammedMatches.length} pendents
              </span>
            {/if}
            {#if playerSearch.length >= 2}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                🔍 Filtrant per: {playerSearch}
              </span>
            {/if}
          </div>
        {/if}
      </div>

      <!-- Controls de vista -->
      <div class="flex items-center gap-3">
        <!-- Selecció de vista -->
        <div class="flex bg-gray-100 rounded-lg p-1">
          <button
            on:click={() => viewMode = 'category'}
            class="px-3 py-1 rounded text-sm transition-colors"
            class:bg-white={viewMode === 'category'}
            class:shadow-sm={viewMode === 'category'}
            class:text-gray-900={viewMode === 'category'}
            class:text-gray-600={viewMode !== 'category'}
          >
            📋 Per Categoria
          </button>
          <button
            on:click={() => viewMode = 'timeline'}
            class="px-3 py-1 rounded text-sm transition-colors"
            class:bg-white={viewMode === 'timeline'}
            class:shadow-sm={viewMode === 'timeline'}
            class:text-gray-900={viewMode === 'timeline'}
            class:text-gray-600={viewMode !== 'timeline'}
          >
            📅 Cronològica
          </button>
        </div>

        <!-- Botó d'impressió -->
        <button
          on:click={() => window.print()}
          class="no-print px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 flex items-center gap-1"
          title="Imprimir calendari"
        >
          🖨️ Imprimir
        </button>
      </div>
    </div>

    <!-- Filtres -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Categoria</label>
        <select
          bind:value={selectedCategory}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">Totes les categories</option>
          {#each categories.sort((a, b) => a.ordre_categoria - b.ordre_categoria) as category}
            <option value={category.id}>{category.nom}</option>
          {/each}
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Data</label>
        <input
          type="date"
          bind:value={selectedDate}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div class="relative print-header-hide player-search-container">
        <label class="block text-sm font-medium text-gray-700 mb-2">Jugador</label>
        <div class="relative">
          <input
            type="text"
            bind:value={playerSearch}
            placeholder="Escriu nom o cognoms..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 pr-8"
          />
          {#if playerSearch}
            <button
              on:click={clearPlayerSearch}
              class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
              title="Netejar cerca"
            >
              ✕
            </button>
          {/if}
        </div>

        <!-- Suggeriments de jugadors -->
        {#if playerSuggestions.length > 0}
          <div class="absolute top-full left-0 right-0 z-50 bg-white border border-gray-300 rounded-md shadow-lg max-h-64 overflow-y-auto mt-1">
            {#each playerSuggestions as suggestion}
              <button
                on:click={() => selectPlayer(suggestion)}
                class="w-full px-3 py-2 text-left hover:bg-gray-50 border-b border-gray-100 last:border-b-0 focus:outline-none focus:bg-gray-50"
              >
                <div class="text-sm font-medium text-gray-900">
                  {suggestion.displayName}
                </div>
                <div class="text-xs text-gray-500">
                  {suggestion.fullName}
                </div>
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div class="flex items-end">
        <button
          on:click={() => { selectedCategory = ''; selectedDate = ''; clearPlayerSearch(); }}
          class="px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700"
        >
          Netejar Filtres
        </button>
      </div>
    </div>
  </div>

  <!-- Missatges d'error -->
  {#if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4 print-header-hide">
      <div class="text-red-800">{error}</div>
    </div>
  {/if}

  <!-- Loading -->
  {#if loading}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center print-header-hide">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant calendari...</p>
    </div>
  {:else if viewMode === 'category'}
    <!-- Vista per Categories -->
    <div class="print-category-hide">
    {#if filteredMatches.length === 0}
      <div class="bg-white border border-gray-200 rounded-lg p-8 text-center">
        <div class="text-gray-500">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          <p class="mt-2">No hi ha partits programats</p>
        </div>
      </div>
    {:else}
      {#each Array.from(matchesByCategory.entries()) as [categoryId, categoryMatches]}
        <div class="bg-white border border-gray-200 rounded-lg p-6">
          <h4 class="text-lg font-medium text-gray-900 mb-4">
            {getCategoryName(categoryId)} ({categoryMatches.length} partits)
          </h4>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Data</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Hora</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Taula</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Enfrontament</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase print-hide">Estat</th>
                  {#if isAdmin}
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase print-hide">Accions</th>
                  {/if}
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each categoryMatches as match}
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {match.data_programada ? formatDate(new Date(match.data_programada)) : 'No programada'}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {match.hora_inici || '-'}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {match.taula_assignada ? `B${match.taula_assignada}` : 'No assignada'}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <div class="flex flex-col">
                        <span class="font-medium">
                          {formatPlayerName(match.jugador1)}
                        </span>
                        <span class="text-xs text-gray-500">vs</span>
                        <span class="font-medium">
                          {formatPlayerName(match.jugador2)}
                        </span>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap print-hide">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getEstatStyle(match.estat)}">
                        {estatOptions.find(opt => opt.value === match.estat)?.label || match.estat}
                      </span>
                    </td>
                    {#if isAdmin}
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium print-hide">
                        <button
                          on:click={() => startEditing(match)}
                          class="text-blue-600 hover:text-blue-900"
                        >
                          Editar
                        </button>
                      </td>
                    {/if}
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        </div>
      {/each}
    {/if}
    </div>
  {:else}
    <!-- Vista Cronològica -->
    {#if timelineGrouped.size === 0}
      <div class="bg-white border border-gray-200 rounded-lg p-8 text-center">
        <div class="text-gray-500">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 002 2z"/>
          </svg>
          <p class="mt-2">No s'han generat slots de calendari</p>
          <p class="text-sm text-gray-400">Comprova la configuració del calendari</p>
        </div>
      </div>
    {:else}
      <!-- Unified table view with merged columns for days and hours -->
      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-500 calendar-table border-collapse">
            <thead class="bg-gray-100">
              <tr>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-4 border-gray-800 day-column">Dia</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-4 border-gray-800 hour-column">Hora</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400">Billar</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400">Cat</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 player-column">Jugador 1</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 player-column">Jugador 2</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 print-hide">Estat</th>
                {#if isAdmin}
                  <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase print-hide">Accions</th>
                {/if}
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-300">
              {#each Array.from(timelineGrouped.entries()) as [dateStr, hourGroups], dayIndex}
                {@const totalSlotsForDay = Array.from(hourGroups.values()).reduce((total, slots) => total + slots.length, 0)}
                {#each Array.from(hourGroups.entries()) as [hora, slots], hourIndex}
                  {#each slots as slot, slotIndex}
                    <tr class="hover:bg-gray-50"
                        class:border-t-4={hourIndex === 0 && slotIndex === 0 && dayIndex > 0}
                        class:border-t-gray-600={hourIndex === 0 && slotIndex === 0 && dayIndex > 0}
                        class:border-t-2={hourIndex > 0 && slotIndex === 0}
                        class:border-t-gray-400={hourIndex > 0 && slotIndex === 0}>
                      <!-- Day column with rowspan -->
                      {#if hourIndex === 0 && slotIndex === 0}
                        <td class="px-3 py-4 text-sm md:text-base font-bold text-gray-900 border-r-4 border-gray-800 bg-gray-50 align-top day-column" rowspan={totalSlotsForDay}>
                          <div class="sticky top-0">
                            <div class="font-bold text-gray-900 text-sm md:text-base">{formatDate(new Date(dateStr))}</div>
                            <div class="text-xs md:text-sm text-gray-700 mt-1 font-medium">{dayNames[getDayOfWeekCode(new Date(dateStr + 'T00:00:00').getDay())]}</div>
                          </div>
                        </td>
                      {/if}

                      <!-- Hour column with rowspan for each hour group -->
                      {#if slotIndex === 0}
                        <td class="px-3 py-4 text-sm md:text-base font-bold text-gray-800 border-r-4 border-gray-800 bg-gray-100 align-top hour-column" rowspan={slots.length}>
                          <div class="font-bold text-base md:text-lg">{hora}</div>
                        </td>
                      {/if}

                      <!-- Table column -->
                      <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base text-gray-900 border-r-2 border-gray-400" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        <span class="font-mono text-sm md:text-base bg-gray-200 px-2 py-1 rounded font-semibold">B{slot.taula}</span>
                      </td>

                      <!-- Category column -->
                      <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base text-gray-900 border-r-2 border-gray-400" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-sm md:text-base font-semibold bg-blue-100 text-blue-800">
                            {getCategoryName(slot.match.categoria_id)}
                          </span>
                        {:else}
                          <span class="text-gray-500 text-sm md:text-base font-medium">-</span>
                        {/if}
                      </td>

                      <!-- Player 1 column -->
                      <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <div class="font-semibold text-sm md:text-base">{formatPlayerName(slot.match.jugador1)}</div>
                        {:else}
                          <span class="text-gray-500 text-sm md:text-base font-medium">-</span>
                        {/if}
                      </td>

                      <!-- Player 2 column -->
                      <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <div class="font-semibold text-sm md:text-base">{formatPlayerName(slot.match.jugador2)}</div>
                        {:else}
                          <span class="text-gray-500 text-sm md:text-base font-medium">-</span>
                        {/if}
                      </td>

                      <!-- Status column -->
                      <td class="px-3 py-4 whitespace-nowrap border-r-2 border-gray-400 print-hide">
                        {#if slot.match}
                          <span class="inline-flex items-center px-2.5 py-1 rounded-full text-sm md:text-base font-medium {getEstatStyle(slot.match.estat)}">
                            {estatOptions.find(opt => opt.value === slot.match.estat)?.label || slot.match.estat}
                          </span>
                        {:else}
                          <span class="text-gray-500 text-sm md:text-base font-medium">Lliure</span>
                        {/if}
                      </td>

                      <!-- Actions column -->
                      {#if isAdmin}
                        <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base font-medium print-hide">
                          {#if slot.match}
                            <button
                              on:click={() => startEditing(slot.match)}
                              class="text-blue-600 hover:text-blue-900 text-sm md:text-base font-semibold"
                            >
                              Editar
                            </button>
                          {:else}
                            <span class="text-gray-500 font-medium">-</span>
                          {/if}
                        </td>
                      {/if}
                    </tr>
                  {/each}
                {/each}
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/if}
  {/if}

  <!-- Partides No Programades -->
  {#if unprogrammedMatches.length > 0}
    <div class="bg-white border border-orange-300 rounded-lg p-6 mt-6">
      <h3 class="text-lg font-medium text-orange-900 mb-4 flex items-center">
        <span class="mr-2">⏳</span> Partides Pendents de Programar ({unprogrammedMatches.length})
      </h3>

      <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-4">
        <p class="text-sm text-orange-800">
          <strong>ℹ️ Informació:</strong> Aquestes partides no s'han pogut programar automàticament dins el període establert del campionat.
          Caldrà programar-les manualment o ampliar el període del campionat.
        </p>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-orange-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Categoria</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Enfrontament</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Estat</th>
              {#if isAdmin}
                <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Accions</th>
              {/if}
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each unprogrammedMatches as match}
              <tr class="hover:bg-orange-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {getCategoryName(match.categoria_id)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <div class="flex flex-col">
                    <span class="font-medium">
                      {formatPlayerName(match.jugador1)}
                    </span>
                    <span class="text-xs text-gray-500">vs</span>
                    <span class="font-medium">
                      {formatPlayerName(match.jugador2)}
                    </span>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-800">
                    {estatOptions.find(opt => opt.value === match.estat)?.label || 'Pendent programar'}
                  </span>
                </td>
                {#if isAdmin}
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <button
                      on:click={() => startEditing(match)}
                      class="text-orange-600 hover:text-orange-900"
                    >
                      Programar
                    </button>
                  </td>
                {/if}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  {/if}
</div>

<!-- Modal d'edició (només per admins) -->
{#if editingMatch && isAdmin}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <h3 class="text-lg font-medium text-gray-900 mb-4">
        Editar Partit
      </h3>

      <form on:submit|preventDefault={saveMatch} class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Data</label>
          <input
            type="date"
            bind:value={editForm.data_programada}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Hora</label>
          <input
            type="time"
            bind:value={editForm.hora_inici}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Taula</label>
          <input
            type="number"
            min="1"
            max="10"
            bind:value={editForm.taula_assignada}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Estat</label>
          <select
            bind:value={editForm.estat}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            {#each estatOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Observacions</label>
          <textarea
            bind:value={editForm.observacions_junta}
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Observacions opcionals..."
          ></textarea>
        </div>

        <div class="flex justify-end space-x-3 pt-4">
          <button
            type="button"
            on:click={cancelEditing}
            class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400"
          >
            Cancel·lar
          </button>
          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            Desar
          </button>
        </div>
      </form>

      <div class="mt-4 pt-4 border-t border-gray-200">
        <div class="text-sm text-gray-600">
          <strong>Jugadors:</strong><br>
          {formatPlayerName(editingMatch.jugador1)} vs {formatPlayerName(editingMatch.jugador2)}
        </div>
      </div>
    </div>
  </div>
{/if}