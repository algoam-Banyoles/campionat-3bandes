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

  // Funció per imprimir només la taula cronològica
  function printCalendar() {
    // Verificar que hi hagi dades per imprimir
    if (!matches || matches.length === 0) {
      alert('No hi ha dades de calendari per imprimir. Assegura\'t que el calendari estigui generat.');
      return;
    }

    // Preguntar a l'usuari quin format d'impressió vol
    const useDoubleColumn = confirm(
      'Tria el format d\'impressió:\n\n' +
      'Acceptar: Dues columnes (més compacte, més partides per pàgina)\n' +
      'Cancel·lar: Una columna (text més gran, més fàcil de llegir)'
    );

    console.log('Imprimint calendari amb', matches.length, 'partides', useDoubleColumn ? '(dues columnes)' : '(una columna)');
    
    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      alert('No s\'ha pogut obrir la finestra d\'impressió. Comprova que no estiguin bloquejades les finestres emergents.');
      return;
    }
    
    try {
      // Generar HTML per a impressió amb el format escollit
      const printHTML = generatePrintHTML(useDoubleColumn);
      
      printWindow.document.open();
      printWindow.document.write(printHTML);
      printWindow.document.close();
      
      // Esperar que es carregui i imprimir
      printWindow.onload = () => {
        printWindow.print();
        printWindow.close();
      };
    } catch (error) {
      console.error('Error generant la impressió:', error);
      alert('Error generant la impressió: ' + error.message);
      printWindow.close();
    }
  }

  // Generar HTML de capçalera per reutilitzar a cada pàgina
  function generateHeaderHTML(): string {
    return `
      <div class="print-header-container">
        <div class="print-header-left">
          <img src="/logo.png" alt="Foment Martinenc" class="print-logo" />
        </div>
        <div class="print-header-center">
          <h1 class="print-main-title">FOMENT MARTINENC - SECCIÓ BILLAR</h1>
          <h2 class="print-event-title">${eventData?.nom || 'Campionat de Billar'}</h2>
          <h3 class="print-season">Temporada ${eventData?.temporada || new Date().getFullYear()}</h3>
        </div>
        <div class="print-header-right">
        </div>
      </div>
      <hr class="print-divider" />
    `;
  }

  // Generar HTML complet per a impressió
  function generatePrintHTML(useDoubleColumn: boolean = true): string {
    const tableHTML = generateTableHTML(useDoubleColumn);
    
    return `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>Calendari ${eventData?.nom || 'Campionat'}</title>
        <style>
          @page { 
            margin: 0.4in 0.3in 0.2in 0.3in; /* top right bottom left - peu més petit */
            size: A4 landscape; 
          }
          ${getPrintCSS()}
        </style>
      </head>
      <body>
        ${tableHTML}
      </body>
      </html>
    `;
  }

  // Generar HTML de la taula
  function generateTableHTML(useDoubleColumn: boolean = true): string {
    // Generar les dades del timeline per la impressió
    const currentTimelineData = generateTimelineData(matches, calendarConfig, availableDates);
    console.log('Timeline generat per impressió:', currentTimelineData.length, 'slots');
    
    const currentFilteredTimeline = currentTimelineData.filter(slot => {
      // Aplicar els mateixos filtres que a la vista
      if (selectedDate && slot.dateStr !== selectedDate) return false;
      if (selectedCategory && slot.match && slot.match.categoria_id !== selectedCategory) return false;
      return true;
    });
    console.log('Timeline filtrat per impressió:', currentFilteredTimeline.length, 'slots');
    
    const currentTimelineGrouped = groupTimelineByDayAndHour(currentFilteredTimeline);
    console.log('Timeline agrupat per impressió:', currentTimelineGrouped.size, 'dies');

    // Generar partides programades
    const scheduledHTML = useDoubleColumn 
      ? generatePaginatedHTML(currentTimelineGrouped)
      : generateSingleColumnHTML(currentTimelineGrouped);

    // Generar partides pendents
    const pendingHTML = generatePendingMatchesHTML(useDoubleColumn);

    return scheduledHTML + pendingHTML;
  }

  // Generar HTML per partides pendents de programar
  function generatePendingMatchesHTML(useDoubleColumn: boolean = true): string {
    // Identificar partides sense programar (sense data_programada o amb camps buits)
    const pendingMatches = matches.filter(match => {
      if (!match.data_programada || !match.hora_inici || !match.taula_assignada) {
        // Aplicar filtres si estan configurats
        if (selectedCategory && match.categoria_id !== selectedCategory) return false;
        return true;
      }
      return false;
    });

    if (pendingMatches.length === 0) {
      return ''; // No hi ha partides pendents
    }

    console.log(`Partides pendents de programar: ${pendingMatches.length}`);

    const pageBreak = '<div class="print-page-break"></div><div style="page-break-before: always; break-before: page; display: block; height: 1px; width: 100%; clear: both;"></div>';
    const headerHTML = generateHeaderHTML();

    const pendingTableHTML = `
      <div class="pending-matches-section">
        <h3 class="pending-matches-title">PARTIDES PENDENTS DE PROGRAMAR</h3>
        <table class="calendar-table pending-matches-table">
          <thead>
            <tr>
              <th class="category-column">Categoria</th>
              <th class="player-column">Jugador 1</th>
              <th class="player-column">Jugador 2</th>
              <th class="date-column">Data límit</th>
              <th class="observations-column">Observacions</th>
            </tr>
          </thead>
          <tbody>
            ${pendingMatches.map(match => `
              <tr>
                <td class="category-cell">${getCategoryName(match.categoria_id)}</td>
                <td class="player-cell">${formatPlayerName(match.jugador1)}</td>
                <td class="player-cell">${formatPlayerName(match.jugador2)}</td>
                <td class="date-cell">${match.data_limit ? new Date(match.data_limit).toLocaleDateString('ca-ES') : 'Per definir'}</td>
                <td class="observations-cell">${match.observacions || '-'}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;

    return `${pageBreak}${headerHTML}${pendingTableHTML}`;
  }

  // Generar HTML paginat amb dies consecutius
  function generatePaginatedHTML(timelineGrouped: Map<string, Map<string, any[]>>): string {
    // Ordenar dies cronològicament
    const daysArray = Array.from(timelineGrouped.entries()).sort(([dateA], [dateB]) => {
      return new Date(dateA).getTime() - new Date(dateB).getTime();
    });

    console.log(`Total dies per paginar: ${daysArray.length}`);
    console.log('Dies ordenats:', daysArray.map(([dateStr]) => dateStr).join(', '));

    // Calcular slots per dia per estimar la mida de pàgina
    const daysWithSlotCount = daysArray.map(([dateStr, hourGroups]) => {
      const totalSlots = Array.from(hourGroups.values()).reduce((total: number, slots: any[]) => total + slots.length, 0);
      return { dateStr, hourGroups, totalSlots, index: daysArray.findIndex(([d]) => d === dateStr) };
    });

    // Estimar quants dies caben per pàgina (optimitzat amb marges ajustats)
    const maxSlotsPerPage = 60; // Tornat a 60 amb marges de peu optimitzats
    const pages: { leftColumn: any[], rightColumn: any[] }[] = [];
    
    let currentPageDays: typeof daysWithSlotCount = [];
    let currentPageSlots = 0;
    
    for (const day of daysWithSlotCount) {
      // Si afegir aquest dia excedeix la capacitat de la pàgina, crear nova pàgina
      if (currentPageSlots > 0 && currentPageSlots + day.totalSlots > maxSlotsPerPage) {
        // Crear pàgina amb els dies actuals
        pages.push(createPageFromDays(currentPageDays));
        currentPageDays = [];
        currentPageSlots = 0;
      }
      
      currentPageDays.push(day);
      currentPageSlots += day.totalSlots;
    }
    
    // Afegir l'última pàgina si hi ha dies pendents
    if (currentPageDays.length > 0) {
      pages.push(createPageFromDays(currentPageDays));
    }
    
    console.log(`Generades ${pages.length} pàgines:`);
    pages.forEach((page, i) => {
      const leftDates = page.leftColumn.map(([dateStr]) => dateStr).join(', ');
      const rightDates = page.rightColumn.map(([dateStr]) => dateStr).join(', ');
      
      // Calcular slots totals per pàgina per debug
      const leftSlots = page.leftColumn.reduce((total, [, hourGroups]) => {
        return total + Array.from(hourGroups.values()).reduce((sum: number, slots: any[]) => sum + slots.length, 0);
      }, 0);
      const rightSlots = page.rightColumn.reduce((total, [, hourGroups]) => {
        return total + Array.from(hourGroups.values()).reduce((sum: number, slots: any[]) => sum + slots.length, 0);
      }, 0);
      const totalSlots = leftSlots + rightSlots;
      
      console.log(`Pàgina ${i + 1} (${totalSlots} slots): Esquerra=[${leftDates}] (${leftSlots} slots) Dreta=[${rightDates}] (${rightSlots} slots)`);
    });
    
    // Generar HTML per totes les pàgines
    return pages.map((page, pageIndex) => generatePageHTML(page, pageIndex)).join('');
  }

  // Crear pàgina dividint dies consecutivament
  function createPageFromDays(pageDays: any[]): { leftColumn: any[], rightColumn: any[] } {
    const daysForPage = pageDays.map(day => [day.dateStr, day.hourGroups]);
    const splitPoint = Math.ceil(daysForPage.length / 2);
    
    return {
      leftColumn: daysForPage.slice(0, splitPoint),
      rightColumn: daysForPage.slice(splitPoint)
    };
  }

  // Generar HTML per una pàgina específica
  function generatePageHTML(page: { leftColumn: any[], rightColumn: any[] }, pageIndex: number): string {
    // Salt de pàgina més robust per navegadors diversos
    const pageBreak = pageIndex > 0 ? `
      <div class="print-page-break"></div>
      <div style="page-break-before: always; break-before: page; display: block; height: 1px; width: 100%; clear: both;"></div>
    ` : '';
    const headerHTML = generateHeaderHTML();
    
    return `
      ${pageBreak}
      ${headerHTML}
      <div class="two-column-layout">
        <div class="column-left">
          <table class="calendar-table">
            <thead>
              <tr>
                <th class="day-column">Dia</th>
                <th class="hour-column">Hora</th>
                <th class="table-column">Billar</th>
                <th class="category-column">Cat</th>
                <th class="player-column">Jugador 1</th>
                <th class="player-column">Jugador 2</th>
              </tr>
            </thead>
            <tbody>
              ${generateColumnHTML(page.leftColumn)}
            </tbody>
          </table>
        </div>
        <div class="column-right">
          <table class="calendar-table">
            <thead>
              <tr>
                <th class="day-column">Dia</th>
                <th class="hour-column">Hora</th>
                <th class="table-column">Billar</th>
                <th class="category-column">Cat</th>
                <th class="player-column">Jugador 1</th>
                <th class="player-column">Jugador 2</th>
              </tr>
            </thead>
            <tbody>
              ${generateColumnHTML(page.rightColumn)}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }

  // Funció auxiliar per generar HTML d'una columna
  function generateColumnHTML(columnDays: any[]): string {
    let columnHTML = '';

    if (columnDays.length === 0) {
      return `
        <tr>
          <td colspan="6" style="text-align: center; padding: 20px; color: #666; font-style: italic;">
            No hi ha més partides
          </td>
        </tr>
      `;
    }

    for (const [dateStr, hourGroups] of columnDays) {
      const totalSlotsForDay = Array.from(hourGroups.values()).reduce((total: number, slots: any[]) => total + slots.length, 0);
      let dayRowSpanUsed = false;
      
      for (const [hora, slots] of Array.from(hourGroups.entries())) {
        let hourRowSpanUsed = false;
        
        for (let slotIndex = 0; slotIndex < slots.length; slotIndex++) {
          const slot = slots[slotIndex];
          
          columnHTML += '<tr>';
          
          // Columna de dia amb rowspan
          if (!dayRowSpanUsed) {
            columnHTML += `
              <td class="day-cell" rowspan="${totalSlotsForDay}">
                <div class="print-date-main">${formatDate(new Date(dateStr))}</div>
                <div class="print-day-name">${dayNames[getDayOfWeekCode(new Date(dateStr + 'T00:00:00').getDay())]}</div>
              </td>
            `;
            dayRowSpanUsed = true;
          }
          
          // Columna d'hora amb rowspan
          if (!hourRowSpanUsed) {
            columnHTML += `<td class="hour-cell" rowspan="${slots.length}">${hora}</td>`;
            hourRowSpanUsed = true;
          }
          
          // Columnes de contingut
          columnHTML += `
            <td class="table-cell">B${slot.taula}</td>
            <td class="category-cell">${slot.match ? getCategoryName(slot.match.categoria_id) : '-'}</td>
            <td class="player-cell">${slot.match ? formatPlayerName(slot.match.jugador1) : '-'}</td>
            <td class="player-cell">${slot.match ? formatPlayerName(slot.match.jugador2) : '-'}</td>
          `;
          
          columnHTML += '</tr>';
        }
      }
    }

    return columnHTML;
  }

  // Generar HTML per una sola columna (text més gran)
  function generateSingleColumnHTML(timelineGrouped: Map<string, Map<string, any[]>>): string {
    let tableHTML = `
      <table class="calendar-table single-column">
        <thead>
          <tr>
            <th class="day-column">Dia</th>
            <th class="hour-column">Hora</th>
            <th class="table-column">Billar</th>
            <th class="category-column">Cat</th>
            <th class="player-column">Jugador 1</th>
            <th class="player-column">Jugador 2</th>
          </tr>
        </thead>
        <tbody>
    `;

    if (timelineGrouped.size === 0) {
      tableHTML += `
        <tr>
          <td colspan="6" style="text-align: center; padding: 30px; color: #666; font-style: italic; font-size: 18px;">
            No hi ha partides programades per mostrar
          </td>
        </tr>
      `;
    } else {
      const allDays = Array.from(timelineGrouped.entries());
      tableHTML += generateColumnHTML(allDays);
    }

    tableHTML += '</tbody></table>';
    return tableHTML;
  }

  // CSS per a impressió
  function getPrintCSS(): string {
    return `
      @page { 
        margin: 0.5in 0.5in 0.3in 0.5in; /* top right bottom left - peu més petit */
        size: A3 portrait; 
      }
      body { 
        font-family: Arial, sans-serif; 
        font-size: 14px; 
        margin: 0; 
        padding: 0; 
        color: #000; 
        line-height: 1.4;
      }
      .print-header-container { 
        display: flex; 
        align-items: center; 
        justify-content: space-between; 
        margin-bottom: 10px; 
        padding: 8px 0; 
      }
      .print-logo { 
        height: 45px; 
        width: auto; 
      }
      .print-header-center { 
        flex: 1; 
        text-align: center; 
        margin: 0 30px; 
      }
      .print-main-title { 
        font-size: 18px; 
        font-weight: bold; 
        margin: 0 0 6px 0; 
        text-transform: uppercase; 
        letter-spacing: 1px;
      }
      .print-event-title { 
        font-size: 16px; 
        font-weight: bold; 
        margin: 0 0 4px 0; 
      }
      .print-season { 
        font-size: 14px; 
        margin: 0; 
        color: #666; 
      }



      .print-divider { 
        border: none; 
        border-top: 3px solid #333; 
        margin: 0 0 20px 0; 
      }
      .calendar-table { 
        width: 100%; 
        border-collapse: collapse; 
        font-size: 20px; 
        margin-top: 15px;
      }
      .calendar-table th, .calendar-table td { 
        border: 1px solid #333; 
        padding: 8px 4px; 
        text-align: center; 
        vertical-align: middle; 
        line-height: 1.3;
      }
      .calendar-table th { 
        background-color: #e8e8e8; 
        font-weight: bold; 
        font-size: 18px; 
        text-transform: uppercase; 
        text-align: center;
        padding: 12px 6px;
      }
      .day-column { width: 120px; }
      .hour-column { width: 80px; }
      .table-column { width: 70px; }
      .category-column { width: 90px; }
      .player-column { width: 220px; }
      .day-cell { 
        background-color: #f5f5f5; 
        border-right: 3px solid #333; 
        text-align: center; 
        font-weight: bold;
        font-size: 21px;
      }
      .hour-cell { 
        background-color: #f0f0f0; 
        border-right: 3px solid #333; 
        text-align: center; 
        font-weight: bold; 
        font-size: 22px;
      }
      .table-cell {
        text-align: center;
        font-weight: bold;
        background-color: #fafafa;
        font-size: 21px;
      }
      .category-cell {
        text-align: center;
        font-weight: bold;
        background-color: #f8f8f8;
        font-size: 20px;
      }
      .player-cell {
        font-weight: normal;
        text-align: center;
        font-size: 19px;
        padding: 8px 4px;
      }
      .print-date-main { 
        font-size: 14px; 
        font-weight: bold; 
        margin-bottom: 3px;
      }
      .print-day-name { 
        font-size: 12px; 
        color: #666; 
        font-style: italic;
      }
      
      /* Layout de dues columnes */
      .two-column-layout {
        display: flex;
        gap: 20px;
        width: 100%;
      }
      .column-left, .column-right {
        flex: 1;
        width: 48%;
      }
      .column-left .calendar-table,
      .column-right .calendar-table {
        width: 100%;
        font-size: 16px;
      }
      
      /* Ajustaments per columnes més estretes */
      .two-column-layout .day-column { width: 85px; }
      .two-column-layout .hour-column { width: 55px; }
      .two-column-layout .table-column { width: 45px; }
      .two-column-layout .category-column { width: 55px; }
      .two-column-layout .player-column { width: 150px; }
      
      /* Tamanys de font ajustats per dues columnes */
      .two-column-layout .calendar-table th { font-size: 14px; }
      .two-column-layout .day-cell { font-size: 15px; }
      .two-column-layout .hour-cell { font-size: 16px; }
      .two-column-layout .table-cell { font-size: 15px; }
      .two-column-layout .category-cell { font-size: 14px; }
      .two-column-layout .player-cell { font-size: 15px; }
      .two-column-layout .print-date-main { font-size: 13px; }
      .two-column-layout .print-day-name { font-size: 11px; }
      
      /* Estils per vista d'una sola columna (text més gran) */
      .calendar-table.single-column {
        font-size: 22px;
      }
      .calendar-table.single-column th {
        font-size: 20px;
        padding: 12px 8px;
      }
      .calendar-table.single-column .day-cell {
        font-size: 24px;
      }
      .calendar-table.single-column .hour-cell {
        font-size: 25px;
      }
      .calendar-table.single-column .table-cell {
        font-size: 24px;
      }
      .calendar-table.single-column .category-cell {
        font-size: 23px;
      }
      .calendar-table.single-column .player-cell {
        font-size: 22px;
      }
      .calendar-table.single-column .print-date-main {
        font-size: 19px;
      }
      .calendar-table.single-column .print-day-name {
        font-size: 17px;
      }

      /* Estils per partides pendents */
      .pending-matches-section {
        margin-top: 30px;
      }
      .pending-matches-title {
        font-size: 20px;
        font-weight: bold;
        text-align: center;
        margin-bottom: 20px;
        color: #d97706;
        text-transform: uppercase;
      }
      .pending-matches-table .date-column {
        width: 15%;
        text-align: center;
      }
      .pending-matches-table .observations-column {
        width: 25%;
      }
      .pending-matches-table .date-cell {
        text-align: center;
        font-weight: bold;
        color: #dc2626;
      }
      .pending-matches-table .observations-cell {
        font-size: 12px;
        color: #666;
      }
    `;
  }


  let matches: any[] = [];
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
  $: timelineData = generateTimelineData(matches, calendarConfig, availableDates);

  async function loadCalendarData() {
    if (!eventId) return;

    loading = true;
    error = null;

    try {
      // Carregar configuració del calendari (només per admins per evitar errors RLS)
      if (isAdmin) {
        try {
          const { data: config, error: configError } = await supabase
            .from('configuracio_calendari')
            .select('*')
            .eq('event_id', eventId)
            .single();

          if (config) {
            calendarConfig = config;
          }
          
          if (configError && configError.code !== 'PGRST116') { // PGRST116 = no rows found
            console.warn('Error loading calendar config:', configError);
          }
        } catch (configErr) {
          console.warn('Could not load calendar config - insufficient permissions:', configErr);
          // Continuar sense configuració del calendari
        }
      }

      // Carregar partits
      const { data: matchData, error: matchError } = await supabase
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
          )
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
    // Filtrar per data seleccionada
    if (selectedDate && slot.dateStr !== selectedDate) return false;
    
    // Filtrar per categoria seleccionada
    if (selectedCategory && slot.match && slot.match.categoria_id !== selectedCategory) return false;
    
    // Si hi ha cerca de jugador, NOMÉS mostrar slots amb partits del jugador cercat
    if (playerSearch.length >= 2) {
      // Si no té partit, no mostrar aquest slot
      if (!slot.match) return false;
      
      const searchLower = playerSearch.toLowerCase().trim();
      const player1Match = matchPlayerSearchText(slot.match.jugador1, searchLower);
      const player2Match = matchPlayerSearchText(slot.match.jugador2, searchLower);
      
      // Si el partit no té el jugador cercat, no mostrar aquest slot
      if (!player1Match && !player2Match) return false;
    }
    
    return true;
  });

  // Separar partits programats i no programats
  $: programmedMatches = filteredMatches.filter(match => match.data_programada && !['pendent_programar'].includes(match.estat));
  $: unprogrammedMatches = filteredMatches.filter(match => !match.data_programada || match.estat === 'pendent_programar');
  
  // Comptar slots amb partits del jugador cercat (per debugging)
  $: playerMatchSlots = playerSearch.length >= 2 
    ? filteredTimeline.filter(slot => slot.match).length 
    : filteredTimeline.filter(slot => slot.match).length;
    
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

    // Nova estructura amb joins - buscar en socis
    if (playerData.socis?.nom && playerData.socis?.cognoms) {
      const nomComplet = `${playerData.socis.nom} ${playerData.socis.cognoms}`.toLowerCase();
      if (nomComplet.includes(searchLower)) return true;

      // Buscar en nom individualment
      if (playerData.socis.nom.toLowerCase().includes(searchLower)) return true;

      // Buscar en cognoms individualment  
      if (playerData.socis.cognoms.toLowerCase().includes(searchLower)) return true;
    }

    // Buscar en número de soci
    if (playerData.numero_soci && playerData.numero_soci.toString().includes(searchLower)) return true;

    // Fallback a estructura anterior (per compatibilitat)
    if (playerData.nom && playerData.cognoms) {
      const nomComplet = `${playerData.nom} ${playerData.cognoms}`.toLowerCase();
      if (nomComplet.includes(searchLower)) return true;
    }

    if (playerData.nom && playerData.nom.toLowerCase().includes(searchLower)) return true;
    if (playerData.cognoms && playerData.cognoms.toLowerCase().includes(searchLower)) return true;

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

  // Funció per publicar el calendari al calendari general
  async function publishCalendar() {
    if (!isAdmin || publishing) return;
    
    const validatedMatches = matches.filter(match => match.estat === 'validat');
    
    if (validatedMatches.length === 0) {
      error = 'No hi ha partits validats per publicar';
      return;
    }

    // Confirmar la publicació
    const confirmPublish = confirm(`Estàs segur que vols publicar ${validatedMatches.length} partits validats al calendari general?\n\nAixò farà que les partides apareguin al calendari de la PWA i seran visibles per tots els usuaris.`);
    
    if (!confirmPublish) return;

    publishing = true;
    error = null;

    try {
      // Actualitzar l'esdeveniment per marcar-lo com a publicat
      const { error: updateEventError } = await supabase
        .from('events')
        .update({ calendari_publicat: true })
        .eq('id', eventId);

      if (updateEventError) {
        console.error('Error actualitzant esdeveniment:', updateEventError);
        error = 'Error al marcar l\'esdeveniment com a publicat: ' + updateEventError.message;
        return;
      }

      // Recarregar les dades per actualitzar la vista
      await loadCalendarData();
      
      // Emetre esdeveniment per notificar que s'ha publicat
      dispatch('calendarPublished', { 
        eventId,
        publishedMatches: validatedMatches.length 
      });

      // Mostrar missatge d'èxit
      console.log(`✅ Calendari publicat! ${validatedMatches.length} partits ara són visibles al calendari general.`);
      
      // Opcional: mostrar una notificació toast
      if (typeof window !== 'undefined') {
        // Si tens un sistema de notificacions, pots usar-lo aquí
        alert(`✅ Calendari publicat correctament!\n\n${validatedMatches.length} partits ara són visibles al calendari general de la PWA.`);
      }

    } catch (e) {
      console.error('Error publicant calendari:', e);
      error = formatSupabaseError(e);
    } finally {
      publishing = false;
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

<style>
  @media print {
    /* Amagar TOT el contingut de la pàgina */
    body * {
      visibility: hidden !important;
    }

    /* Mostrar només l'encapçalament i la taula cronològica */
    .print-title-show,
    .print-title-show *,
    .calendar-main-container,
    .calendar-main-container * {
      visibility: visible !important;
    }

    /* Amagar elements específics dins la taula visible */
    .print-hide {
      visibility: hidden !important;
      display: none !important;
    }

    .no-print {
      visibility: hidden !important;
      display: none !important;
    }

    /* Mostrar l'encapçalament en impressió */
    .print-title-show {
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
    html, body {
      width: 100% !important;
      height: auto !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    /* Contenidor de la taula per impressió */
    .calendar-main-container {
      border: none !important;
      border-radius: 0 !important;
      box-shadow: none !important;
      margin-top: 140px !important; /* Espai per l'encapçalament fix */
      position: relative !important;
    }

    .calendar-main-container .overflow-x-auto {
      overflow: visible !important;
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

    /* Cel·les optimitzades per una sola fila */
    th, td {
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

    /* Capçaleres de taula destacades */
    th {
      background-color: #e8e8e8 !important;
      font-weight: bold !important;
      font-size: 9px !important;
      text-transform: uppercase !important;
      border: 1px solid #333 !important;
      height: 20px !important;
      max-height: 20px !important;
    }

    /* Amplades específiques per columnes */
    .calendar-table .day-column {
      width: 80px !important;
      min-width: 80px !important;
      max-width: 80px !important;
    }

    .calendar-table .hour-column {
      width: 50px !important;
      min-width: 50px !important;
      max-width: 50px !important;
    }

    .calendar-table .table-column {
      width: 40px !important;
      min-width: 40px !important;
      max-width: 40px !important;
    }

    .calendar-table .category-column {
      width: 50px !important;
      min-width: 50px !important;
      max-width: 50px !important;
    }

    .calendar-table .player-column {
      width: 120px !important;
      min-width: 120px !important;
      max-width: 120px !important;
    }

    /* Estil compacte per noms de jugadors */
    .player-name-compact {
      font-size: 10px !important;
      font-weight: normal !important;
      margin: 0 !important;
      line-height: 1.2 !important;
      white-space: nowrap !important;
      overflow: hidden !important;
      text-overflow: ellipsis !important;
    }

    .player-name-compact .font-semibold {
      font-weight: bold !important;
      font-size: 10px !important;
    }

    .vs-separator {
      font-size: 8px !important;
      color: #666 !important;
      margin: 0 4px !important;
      font-weight: normal !important;
    }

    /* Estils específics per categories compactes */
    .category-compact {
      font-size: 8px !important;
      padding: 1px 4px !important;
      border-radius: 2px !important;
      font-weight: bold !important;
      background-color: #e0e0e0 !important;
      color: #333 !important;
    }

    /* Estils per número de billar */
    .table-number-compact {
      font-size: 9px !important;
      font-weight: bold !important;
      background-color: #f0f0f0 !important;
      padding: 1px 3px !important;
      border-radius: 2px !important;
    }

    /* Estils per capçaleres de dia i hora compactes */
    .print-day-header {
      text-align: center !important;
    }

    .print-date-main {
      font-size: 10px !important;
      font-weight: bold !important;
      line-height: 1.1 !important;
      margin: 0 !important;
    }

    .print-day-name {
      font-size: 8px !important;
      font-weight: normal !important;
      color: #666 !important;
      line-height: 1.1 !important;
      margin: 1px 0 0 0 !important;
    }

    .print-hour-header {
      font-size: 11px !important;
      font-weight: bold !important;
      text-align: center !important;
      line-height: 1.1 !important;
      margin: 0 !important;
    }

    /* Capçaleres de seccions */
    h3, h4, h5 {
      margin: 10px 0 5px 0 !important;
      font-size: 14px !important;
      font-weight: bold !important;
      page-break-after: avoid !important;
    }

    /* Estils per encapçalament professional */
    .print-header-container {
      display: flex !important;
      align-items: center !important;
      justify-content: space-between !important;
      margin-bottom: 20px !important;
      padding: 15px 20px !important;
    }

    .print-header-left {
      flex: 0 0 auto !important;
    }

    .print-logo {
      height: 60px !important;
      width: auto !important;
      object-fit: contain !important;
    }

    .print-header-center {
      flex: 1 !important;
      text-align: center !important;
      margin: 0 20px !important;
    }

    .print-main-title {
      font-size: 16px !important;
      font-weight: bold !important;
      margin: 0 0 8px 0 !important;
      color: #000 !important;
      text-transform: uppercase !important;
      letter-spacing: 0.5px !important;
    }

    .print-event-title {
      font-size: 14px !important;
      font-weight: bold !important;
      margin: 0 0 6px 0 !important;
      color: #333 !important;
    }

    .print-season {
      font-size: 12px !important;
      font-weight: normal !important;
      margin: 0 0 6px 0 !important;
      color: #666 !important;
    }

    .print-date {
      font-size: 10px !important;
      font-style: italic !important;
      margin: 0 !important;
      color: #888 !important;
    }

    .print-header-right {
      flex: 0 0 auto !important;
    }

    .print-contact {
      text-align: right !important;
      font-size: 10px !important;
      line-height: 1.4 !important;
    }

    .print-contact-line {
      margin-bottom: 2px !important;
      color: #666 !important;
    }

    .print-divider {
      border: none !important;
      border-top: 2px solid #333 !important;
      margin: 0 0 20px 0 !important;
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

    /* Força salts de pàgina entre dies si cal - compatibilitat multi-navegador */
    .print-page-break {
      page-break-before: always !important;
      break-before: page !important; /* CSS3 modern */
      display: block !important;
      height: 0 !important;
      margin: 0 !important;
      padding: 0 !important;
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

<div class="space-y-6 main-calendar-container">
  <!-- Encapçalament professional per a impressió -->
  <div class="print-title-show" style="display: none;">
    <div class="print-header-container">
      <div class="print-header-left">
        <img src="/logo.png" alt="Foment Martinenc" class="print-logo" />
      </div>
      <div class="print-header-center">
        <h1 class="print-main-title">
          FOMENT MARTINENC - SECCIÓ BILLAR
        </h1>
        <h2 class="print-event-title">
          {eventData?.nom || 'Campionat de Billar'}
        </h2>
        <h3 class="print-season">
          Temporada {eventData?.temporada || new Date().getFullYear()}
        </h3>
      </div>
      <div class="print-header-right">
      </div>
    </div>
    <hr class="print-divider" />
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
            
            <!-- Mostrar resum per estats -->
            {#if programmedMatches.some(match => match.estat === 'validat')}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800 mr-2">
                📋 {programmedMatches.filter(match => match.estat === 'validat').length} validats
              </span>
            {/if}
            {#if programmedMatches.some(match => match.estat === 'publicat')}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-emerald-100 text-emerald-800 mr-2">
                📢 {programmedMatches.filter(match => match.estat === 'publicat').length} publicats
              </span>
            {/if}
            
            {#if unprogrammedMatches.length > 0}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-orange-100 text-orange-800 mr-2">
                ⏳ {unprogrammedMatches.length} pendents
              </span>
            {/if}
            {#if playerSearch.length >= 2}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                🔍 Filtrant per: {playerSearch} | Partits trobats: {filteredMatches.length}/{matches.length} | Slots amb partits: {playerMatchSlots}
              </span>
            {/if}
          </div>
        {/if}
      </div>

      <!-- Controls de vista -->
      <div class="flex items-center gap-3">
        <!-- Botó de publicar calendari (només per admins i si hi ha partits validats) -->
        {#if isAdmin && programmedMatches.some(match => match.estat === 'validat')}
          <button
            on:click={publishCalendar}
            class="no-print px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 flex items-center gap-2 font-semibold"
            title="Publicar calendari al calendari general de la PWA"
            disabled={loading}
          >
            {#if publishing}
              <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
              Publicant...
            {:else}
              📢 Publicar Calendari
            {/if}
          </button>
        {/if}

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
          on:click={printCalendar}
          class="no-print px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 flex items-center gap-1"
          title="Imprimir calendari cronològic"
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
          {#if playerSearch.length >= 2}
            <p class="mt-2">Cap partit trobat per "{playerSearch}"</p>
            <p class="text-sm text-gray-400">Prova amb un altre nom o neteja els filtres</p>
          {:else if selectedDate || selectedCategory}
            <p class="mt-2">Cap partit trobat amb els filtres aplicats</p>
            <p class="text-sm text-gray-400">Prova eliminant alguns filtres</p>
          {:else}
            <p class="mt-2">No s'han generat slots de calendari</p>
            <p class="text-sm text-gray-400">Comprova la configuració del calendari o que hi hagi partits programats</p>
          {/if}
        </div>
      </div>
    {:else}
      <!-- Unified table view with merged columns for days and hours -->
      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden calendar-main-container">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-500 calendar-table border-collapse">
            <thead class="bg-gray-100">
              <tr>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-4 border-gray-800 day-column">Dia</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-4 border-gray-800 hour-column">Hora</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 table-column">Billar</th>
                <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 category-column">Cat</th>
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
                          <div class="sticky top-0 print-day-header">
                            <div class="print-date-main">{formatDate(new Date(dateStr))}</div>
                            <div class="print-day-name">{dayNames[getDayOfWeekCode(new Date(dateStr + 'T00:00:00').getDay())]}</div>
                          </div>
                        </td>
                      {/if}

                      <!-- Hour column with rowspan for each hour group -->
                      {#if slotIndex === 0}
                        <td class="px-3 py-4 text-sm md:text-base font-bold text-gray-800 border-r-4 border-gray-800 bg-gray-100 align-top hour-column" rowspan={slots.length}>
                          <div class="print-hour-header">{hora}</div>
                        </td>
                      {/if}

                      <!-- Table column -->
                      <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base text-gray-900 border-r-2 border-gray-400 table-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        <span class="table-number-compact">B{slot.taula}</span>
                      </td>

                      <!-- Category column -->
                      <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base text-gray-900 border-r-2 border-gray-400 category-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <span class="category-compact">
                            {getCategoryName(slot.match.categoria_id)}
                          </span>
                        {:else}
                          <span class="text-gray-500 text-sm md:text-base font-medium">-</span>
                        {/if}
                      </td>

                      <!-- Jugador 1 -->
                      <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <span class="font-semibold">{formatPlayerName(slot.match.jugador1)}</span>
                        {:else}
                          <span class="text-gray-500 text-sm md:text-base font-medium">-</span>
                        {/if}
                      </td>

                      <!-- Jugador 2 -->
                      <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <span class="font-semibold">{formatPlayerName(slot.match.jugador2)}</span>
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