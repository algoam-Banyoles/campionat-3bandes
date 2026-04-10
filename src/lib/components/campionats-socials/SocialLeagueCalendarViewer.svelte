<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { exportCalendariToCSV } from '$lib/api/socialLeagues';
  import PendingMatchesModal from './PendingMatchesModal.svelte';
  import OldMatchesModal from './OldMatchesModal.svelte';

  const dispatch = createEventDispatcher();

  export let eventId: string = '';
  export let categories: any[] = [];
  export let isAdmin: boolean = false;
  export let eventData: any = null;
  export let defaultMode: 'category' | 'timeline' = 'timeline';
  export const editMode: boolean = false;

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
      const hasResult = match.caramboles_jugador1 != null && match.caramboles_jugador2 != null;
      if (hasResult) return false;
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

    // Ordenar per categoria
    pendingMatches.sort((a, b) => {
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

    console.log(`Partides pendents de programar: ${pendingMatches.length}`);

    const pageBreak = '<div class="print-page-break"></div><div style="page-break-before: always; break-before: page; display: block; height: 1px; width: 100%; clear: both;"></div>';
    const headerHTML = generateHeaderHTML();

    const pendingTableHTML = `
      <div class="pending-matches-section">
        <h3 class="pending-matches-title">PARTIDES PENDENTS DE PROGRAMAR</h3>
        <div class="pending-matches-info">
          <span class="pending-matches-info-text">
            Informació: Aquestes partides no s'han pogut programar automàticament dins el període establert del campionat. Caldrà programar-les per part dels jugadors implicats.
          </span>
        </div>
        <table class="calendar-table pending-matches-table">
          <thead>
            <tr>
              ${isAdmin ? '<th class="category-column">Categoria</th>' : ''}
              <th class="player-column">Jugador 1</th>
              <th class="player-column">Jugador 2</th>
              <th class="observations-column">Observacions</th>
            </tr>
          </thead>
          <tbody>
            ${pendingMatches.map(match => {
              // Trobar la categoria per obtenir l'ordre
              const categoria = categories.find(c => c.id === match.categoria_id);
              // Simplificar el text de categoria a només el número ordinal
              const categoriaText = categoria?.nom ? categoria.nom.replace(/categoria/i, '').trim() : (match.categoria_nom ? match.categoria_nom.replace(/categoria/i, '').trim() : '');
              // Si tenim jugador1.nom, mostrar-lo; si no, usar formatPlayerName
              const jugador1Text = match.jugador1 && match.jugador1.nom ? `${match.jugador1.nom} ${match.jugador1.cognoms}` : formatPlayerName(match.jugador1);
              const jugador2Text = match.jugador2 && match.jugador2.nom ? `${match.jugador2.nom} ${match.jugador2.cognoms}` : formatPlayerName(match.jugador2);
              return `
                <tr>
                  ${isAdmin ? `<td class="category-cell">${categoriaText}</td>` : ''}
                  <td class="player-cell">${jugador1Text}</td>
                  <td class="player-cell">${jugador2Text}</td>
                  <td class="observations-cell">${match.observacions || ''}</td>
                </tr>
              `;
            }).join('')}
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
    const pages: { leftColumn: [string, Map<string, any[]>][], rightColumn: [string, Map<string, any[]>][] }[] = [];
    
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
  function createPageFromDays(pageDays: { dateStr: string, hourGroups: Map<string, any[]>, totalSlots: number, index: number }[]): { leftColumn: [string, Map<string, any[]>][], rightColumn: [string, Map<string, any[]>][] } {
    const daysForPage: [string, Map<string, any[]>][] = pageDays.map(day => [day.dateStr, day.hourGroups]);
    const splitPoint = Math.ceil(daysForPage.length / 2);
    
    return {
      leftColumn: daysForPage.slice(0, splitPoint),
      rightColumn: daysForPage.slice(splitPoint)
    };
  }

  // Generar HTML per una pàgina específica
  function generatePageHTML(page: { leftColumn: [string, Map<string, any[]>][], rightColumn: [string, Map<string, any[]>][] }, pageIndex: number): string {
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
  function generateColumnHTML(columnDays: [string, Map<string, any[]>][]): string {
    let columnHTML = '';

    if (columnDays.length === 0) {
      return `
        <tr>
          <td colspan="${isAdmin ? '6' : '5'}" style="text-align: center; padding: 20px; color: #666; font-style: italic;">
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
            ${isAdmin ? '<th class="category-column">Cat</th>' : ''}
            <th class="player-column">Jugador 1</th>
            <th class="player-column">Jugador 2</th>
          </tr>
        </thead>
        <tbody>
    `;

    if (timelineGrouped.size === 0) {
      tableHTML += `
        <tr>
          <td colspan="${isAdmin ? '6' : '5'}" style="text-align: center; padding: 30px; color: #666; font-style: italic; font-size: 18px;">
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
    if (!$user) {
      myPlayerData = null;
      return;
    }

    try {
      // Fase 5c-S2c-2: directe via socis.email
      const { data: sociData, error: sociError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms, email')
        .eq('email', $user.email)
        .maybeSingle();

      if (sociError || !sociData) {
        console.log('No soci data found for user email:', $user.email);
        myPlayerData = null;
      } else {
        myPlayerData = {
          id: sociData.numero_soci,
          numero_soci: sociData.numero_soci,
          nom: `${sociData.nom ?? ''} ${sociData.cognoms ?? ''}`.trim(),
          email: sociData.email
        };
      }
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

  let categoriesMap = new Map();
  let playersMap = new Map();
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
            console.log('📅 Configuració del calendari carregada:', {
              dies_setmana: config.dies_setmana,
              hores_disponibles: config.hores_disponibles,
              taules_per_slot: config.taules_per_slot
            });
          }
          
          if (configError && configError.code !== 'PGRST116') { // PGRST116 = no rows found
            console.warn('Error loading calendar config:', configError);
          }
        } catch (configErr) {
          console.warn('Could not load calendar config - insufficient permissions:', configErr);
          // Continuar sense configuració del calendari
        }
      }

      // Carregar partits amb funció RPC per accés públic
      console.log('🔍 Loading calendar matches with RPC for event:', eventId);
      const { data: matchDataRaw, error: matchError } = await supabase
        .rpc('get_calendar_matches_public', {
          p_event_id: eventId
        });

      if (matchError) {
        console.error('❌ Error loading calendar with RPC:', matchError);
        throw matchError;
      }

      console.log('✅ Loaded calendar matches:', matchDataRaw?.length || 0);

      // Carregar també partides no programades (només si l'usuari està autenticat)
      console.log('🔍 Loading unprogrammed matches (only for authenticated users)...');
      let unprogrammedRaw = [];
      let unprogrammedError = null;
      const withdrawnSocis = new Set<number>();
      
      // Verificar si l'usuari està autenticat
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      console.log('🔍 User authentication status:', user ? 'Authenticated' : 'Anonymous');
      
      if (user) {
        try {
          // Carregar jugadors retirats/desqualificats per excloure les seves partides pendents
          const { data: inscriptionsData, error: inscriptionsError } = await supabase
            .rpc('get_inscripcions_with_socis', {
              p_event_id: eventId
            });

          if (!inscriptionsError) {
            (inscriptionsData || [])
              .filter((item: any) => item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences)
              .forEach((item: any) => {
                if (typeof item.soci_numero === 'number') {
                  withdrawnSocis.add(item.soci_numero);
                }
              });
          }

          // Carregar partides no programades amb els filtres correctes
          console.log('🔍 User authenticated, loading unprogrammed matches (estat=pendent_programar, data_programada=null)...');
          const result = await supabase
            .from('calendari_partides')
            .select('*')
            .eq('event_id', eventId)
            .eq('estat', 'pendent_programar')
            .is('caramboles_jugador1', null)
            .is('caramboles_jugador2', null)
            .is('data_programada', null);

          unprogrammedRaw = result.data;
          unprogrammedError = result.error;

          // Si hi ha partides, buscar noms reals de jugadors i categories
          // Fase 5c-S2c-2: query directa a `socis` per `*_soci_numero`
          if (unprogrammedRaw && unprogrammedRaw.length > 0) {
            const sociNumbers = Array.from(new Set([
              ...unprogrammedRaw.map((m: any) => m.jugador1_soci_numero),
              ...unprogrammedRaw.map((m: any) => m.jugador2_soci_numero)
            ].filter((n: any) => typeof n === 'number'))) as number[];

            if (sociNumbers.length > 0) {
              // Excloure partides pendents amb jugadors retirats
              if (withdrawnSocis.size > 0) {
                unprogrammedRaw = unprogrammedRaw.filter((match: any) => {
                  return !withdrawnSocis.has(match.jugador1_soci_numero ?? -1)
                      && !withdrawnSocis.has(match.jugador2_soci_numero ?? -1);
                });
              }

              const { data: socisData } = await supabase
                .from('socis')
                .select('numero_soci, nom, cognoms')
                .in('numero_soci', sociNumbers);
              if (socisData) {
                socisData.forEach((soci: any) => {
                  const inicialNom = soci.nom ? soci.nom.trim().charAt(0).toUpperCase() : '';
                  const primerCognom = soci.cognoms ? soci.cognoms.trim().split(' ')[0] : '';
                  // playersMap aquí es composa per soci_numero (no UUID).
                  playersMap.set(soci.numero_soci, { nom: inicialNom, cognoms: primerCognom });
                });
              }
            }
            const categoriaIds = [...new Set(unprogrammedRaw.map((m: any) => m.categoria_id).filter(Boolean))];

            // Carregar categories
            if (categoriaIds.length > 0) {
              const { data: categoriesData } = await supabase
                .from('categories')
                .select('id, nom')
                .in('id', categoriaIds);
              if (categoriesData) {
                categoriesData.forEach(c => {
                  categoriesMap.set(c.id, c.nom);
                });
              }
            }

            // Afegir noms reals a les partides (lookup per soci_numero)
            unprogrammedRaw = unprogrammedRaw.map(match => ({
              ...match,
              categoria_nom: categoriesMap.get(match.categoria_id) || '',
              jugador1: playersMap.get(match.jugador1_soci_numero) || { nom: 'J.', cognoms: '(No programat)' },
              jugador2: playersMap.get(match.jugador2_soci_numero) || { nom: 'J.', cognoms: '(No programat)' }
            }));
          }
        } catch (err) {
          console.warn('⚠️ Error loading unprogrammed matches for authenticated user:', err);
          unprogrammedError = err;
        }
      } else {
        console.log('ℹ️ Anonymous user - unprogrammed matches not available due to RLS policies');
      }

      console.log('🔍 Unprogrammed query result:', { 
        data: unprogrammedRaw?.length || 0, 
        error: unprogrammedError 
      });

      if (unprogrammedError) {
        console.warn('⚠️ Could not load unprogrammed matches:', unprogrammedError);
        // Continuar sense partides no programades si hi ha error de permisos
      }

      console.log('✅ Loaded unprogrammed matches:', unprogrammedRaw?.length || 0);

      // Transformar les dades RPC al format esperat pel component
      const matchData = matchDataRaw?.map(match => ({
        id: match.id,
        categoria_id: match.categoria_id,
        data_programada: match.data_programada,
        hora_inici: match.hora_inici,
        jugador1_soci_numero: match.jugador1_numero_soci,
        jugador2_soci_numero: match.jugador2_numero_soci,
        estat: match.estat,
        taula_assignada: match.taula_assignada,
        observacions_junta: match.observacions_junta,
        jugador1: {
          numero_soci: match.jugador1_numero_soci,
          socis: {
            nom: match.jugador1_nom,
            cognoms: match.jugador1_cognoms
          }
        },
        jugador2: {
          numero_soci: match.jugador2_numero_soci,
          socis: {
            nom: match.jugador2_nom,
            cognoms: match.jugador2_cognoms
          }
        }
      })) || [];

      // Transformar les partides no programades al mateix format
      // (Fase 5c-S2c-2: lookup per soci_numero)
      const unprogrammedData = unprogrammedRaw?.map((match: any) => ({
        id: match.id,
        categoria_id: match.categoria_id,
        categoria_nom: categoriesMap.get(match.categoria_id) || '',
        data_programada: match.data_programada,
        hora_inici: match.hora_inici,
        jugador1_soci_numero: match.jugador1_soci_numero,
        jugador2_soci_numero: match.jugador2_soci_numero,
        estat: match.estat,
        taula_assignada: match.taula_assignada,
        observacions_junta: match.observacions_junta,
        jugador1: playersMap.get(match.jugador1_soci_numero) || { nom: 'J.', cognoms: '(No programat)' },
        jugador2: playersMap.get(match.jugador2_soci_numero) || { nom: 'J.', cognoms: '(No programat)' }
      })) || [];

      console.log('🔍 Unprogrammed data processed:', unprogrammedData.length);

      // Combinar les dades programades i no programades
      const allMatchData = [...matchData, ...unprogrammedData];
      console.log('📊 Total matches (programmed + unprogrammed):', allMatchData.length);

      // Debug: comprovar taules assignades
      // const withTables = matchData.filter(m => m.taula_assignada).length;
      // const withoutTables = matchData.filter(m => !m.taula_assignada).length;
      // console.log('🔍 Matches with taula_assignada:', withTables, 'without:', withoutTables);
      // if (matchData.length > 0) {
      //   console.log('🔍 Sample match taula_assignada:', matchData[0].taula_assignada, typeof matchData[0].taula_assignada);
      // }

      // Carregar categories si no es passen per prop
      let finalCategories = categories;
      if (categories.length === 0) {
        console.log('🔍 Loading categories for calendar with RPC:', eventId);
        const { data: categoriesData, error: categoriesError } = await supabase
          .rpc('get_categories_for_event', {
            p_event_id: eventId
          });
        
        if (!categoriesError && categoriesData) {
          finalCategories = categoriesData;
          console.log('✅ Loaded categories for calendar:', finalCategories.length);
        } else {
          console.error('❌ Error loading categories for calendar:', categoriesError);
        }
      }

      // Combinar dades de partits amb categories
      const matchesWithCategories = (allMatchData || []).map(match => {
        const category = finalCategories.find(c => c.id === match.categoria_id);
        return {
          ...match,
          categoria: category || null
        };
      });

      matches = matchesWithCategories;
      
      console.log('✅ Final matches processed:', matches.length);
      console.log('🔍 Sample match structure:', matches[0] ? {
        id: matches[0].id,
        data_programada: matches[0].data_programada,
        hora_inici: matches[0].hora_inici,
        jugador1: matches[0].jugador1?.socis?.nom,
        jugador2: matches[0].jugador2?.socis?.nom,
        categoria: matches[0].categoria?.nom,
        taula_assignada: matches[0].taula_assignada
      } : 'No matches');

    } catch (e) {
      console.error('❌ Error in loadCalendarData:', e);
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
      startDate = new Date(Math.min(...dates.map(d => d.getTime())));
      endDate = new Date(Math.max(...dates.map(d => d.getTime())));

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
      const dateStr = toLocalDateStr(date);
      const dayOfWeek = getDayOfWeekCode(date.getDay());

      // Només mostrar dies de la setmana configurats
      if (config.dies_setmana && config.dies_setmana.includes(dayOfWeek)) {
        validDays++;
        const hores = config.hores_disponibles || ['18:00', '19:00'];
        const taules = config.taules_per_slot || 3;
        
        // Pre-filter matches for this specific date to optimize performance
        const dateMatches = currentMatches.filter(match => {
          if (!match.data_programada) return false;
          const matchDate = toLocalDateStr(new Date(match.data_programada));
          return matchDate === dateStr;
        });

        hores.forEach(hora => {
          for (let taula = 1; taula <= taules; taula++) {
            totalSlots++;

            // Buscar partit programat per aquest slot (només entre els partits d'aquest dia)
            const scheduledMatch = dateMatches.find(match => {
              // Normalitzar format d'hores - eliminar segons si existeixen
              const normalizedSlotHora = hora; // ja ve en format HH:MM
              const normalizedMatchHora = match.hora_inici?.substring(0, 5); // eliminar :SS si existeix
              const matchesTime = normalizedMatchHora === normalizedSlotHora;

              const matchesTable = parseInt(match.taula_assignada) === taula;
              


              return matchesTime && matchesTable;
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

    // Detectar partits orfes (programats però no vinculats a cap slot de la timeline)
    const linkedMatchIds = new Set(timeline.filter(s => s.match).map(s => s.match.id));
    const orphanedMatches = currentMatches.filter(m =>
      m.data_programada && m.id && !linkedMatchIds.has(m.id)
    );

    if (orphanedMatches.length > 0) {
      console.warn(`⚠️ ${orphanedMatches.length} partits programats no vinculats a cap slot de la timeline. Afegint-los...`);
      orphanedMatches.forEach(match => {
        const matchDate = new Date(match.data_programada);
        const matchDateStr = toLocalDateStr(matchDate);
        const matchHora = match.hora_inici?.substring(0, 5) || match.hora_inici || '18:00';
        const matchTaula = parseInt(match.taula_assignada) || 1;

        timeline.push({
          date: matchDate,
          dateStr: matchDateStr,
          dayOfWeek: getDayOfWeekCode(matchDate.getDay()),
          hora: matchHora,
          taula: matchTaula,
          match: match
        });
      });
    }

    // Ordenar cronològicament: primer per data, després per hora, finalment per taula
    timeline.sort((a, b) => {
      // Primer comparar dates
      const dateComparison = a.dateStr.localeCompare(b.dateStr);
      if (dateComparison !== 0) return dateComparison;

      // Si són el mateix dia, comparar hores
      const timeComparison = a.hora.localeCompare(b.hora);
      if (timeComparison !== 0) return timeComparison;

      // Si són la mateixa hora, comparar taules
      return a.taula - b.taula;
    });

    return timeline;
  }

  function toLocalDateStr(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
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

  function groupTimelineByDayAndHour(timeline: any[]): Map<string, Map<string, any[]>> {
    const grouped = new Map<string, Map<string, any[]>>();

    timeline.forEach(slot => {
      const dateKey = slot.dateStr;
      const hourKey = slot.hora;

      if (!grouped.has(dateKey)) {
        grouped.set(dateKey, new Map<string, any[]>());
      }

      const dayMap = grouped.get(dateKey)!;
      if (!dayMap.has(hourKey)) {
        dayMap.set(hourKey, []);
      }

      dayMap.get(hourKey)!.push(slot);
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

  function matchPlayerById(match: any, playerId: string | number): boolean {
    // Fase 5c-S3: comparem només per soci_numero (les columnes UUID ja no existeixen).
    return (
      match.jugador1_soci_numero === playerId ||
      match.jugador2_soci_numero === playerId
    );
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
      const sides = [
        { jugador: match.jugador1, sociNumero: match.jugador1_soci_numero },
        { jugador: match.jugador2, sociNumero: match.jugador2_soci_numero }
      ];
      sides.forEach(({ jugador, sociNumero }) => {
        if (!jugador || !sociNumero) return;
        if (uniquePlayers.has(sociNumero)) return;

        if (matchPlayerSearchText(jugador, searchLower)) {
          uniquePlayers.set(sociNumero, {
            id: sociNumero,
            jugador,
            displayName: formatPlayerName(jugador),
          });
        }
      });
    });

    playerSuggestions = Array.from(uniquePlayers.values())
      .sort((a, b) => a.displayName.localeCompare(b.displayName))
      .slice(0, 10); // Limitar a 10 suggeriments
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

    // Fetch full match data to get existing scores
    const { data: fullMatchData, error: fetchError } = await supabase
      .from('calendari_partides')
      .select('caramboles_jugador1, caramboles_jugador2, entrades, observacions_junta')
      .eq('id', match.id)
      .single();

    if (fetchError) {
        alert('Error carregant les dades de la partida: ' + formatSupabaseError(fetchError));
        return;
    }

    // Combine original match data (with player names) with fresh score data
    resultMatch = {
        ...match,
        ...fullMatchData
    };

    resultForm = {
      caramboles_jugador1: resultMatch.caramboles_jugador1 || 0,
      caramboles_jugador2: resultMatch.caramboles_jugador2 || 0,
      entrades: resultMatch.entrades || 0,
      observacions: resultMatch.observacions_junta || ''
    };
    showResultModal = true;
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
    if (loading) return; // evita submissions concurrents (doble click)

    // Empats permesos: 1 punt per cada jugador
    if (resultForm.caramboles_jugador1 === 0 && resultForm.caramboles_jugador2 === 0) {
      alert('Introdueix les caramboles per ambdós jugadors');
      return;
    }

    loading = true;

    try {
      // Calcular punts segons el resultat
      let punts_j1 = 0;
      let punts_j2 = 0;

      if (resultForm.caramboles_jugador1 > resultForm.caramboles_jugador2) {
        punts_j1 = 2;  // Jugador 1 guanya
        punts_j2 = 0;
      } else if (resultForm.caramboles_jugador2 > resultForm.caramboles_jugador1) {
        punts_j1 = 0;
        punts_j2 = 2;  // Jugador 2 guanya
      } else {
        punts_j1 = 1;  // Empat
        punts_j2 = 1;
      }

      const { data: updateData, error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          caramboles_jugador1: resultForm.caramboles_jugador1,
          caramboles_jugador2: resultForm.caramboles_jugador2,
          entrades: resultForm.entrades,
          punts_jugador1: punts_j1,
          punts_jugador2: punts_j2,
          data_joc: new Date().toISOString(),
          estat: 'jugada',
          validat_per: (await supabase.auth.getUser()).data.user?.id,
          data_validacio: new Date().toISOString(),
          observacions_junta: resultForm.observacions
        })
        .eq('id', resultMatch.id);

      if (updateError) {
        throw updateError;
      }

      // Tancar modal i recarregar dades
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
    if (loading) return; // evita RPC concurrents

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

      const { data, error: rpcError } = await supabase
        .rpc('registrar_incompareixenca', {
          p_partida_id: incompareixencaMatch.id,
          p_jugador_que_falta: jugadorQueFalta
        });

      if (rpcError) throw rpcError;

      closeIncompareixencaModal();

      // Recarregar dades
      await loadCalendarData();
      dispatch('matchUpdated');

      // Mostrar missatge segons el resultat
      if (data.jugador_eliminat) {
        alert(
          `⚠️ INCOMPAREIXENÇA REGISTRADA\n\n` +
          `El jugador ${jugadorNom} té ${data.incompareixences} incompareixences.\n` +
          `HA ESTAT ELIMINAT DEL CAMPIONAT.\n\n` +
          `Totes les seves partides pendents han estat anul·lades.`
        );
      } else {
        alert(
          `✅ INCOMPAREIXENÇA REGISTRADA\n\n` +
          `El jugador ${jugadorNom} té ${data.incompareixences} incompareixença(es).\n` +
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

      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          data_programada: null,
          hora_inici: null,
          taula_assignada: null,
          estat: 'pendent_programar',
          observacions_junta: match.observacions_junta ?
            `${match.observacions_junta}\n[${new Date().toLocaleDateString('ca-ES')}] Convertida a no programada per indisponibilitat de jugador.` :
            `[${new Date().toLocaleDateString('ca-ES')}] Convertida a no programada per indisponibilitat de jugador.`
        })
        .eq('id', match.id);

      if (updateError) throw updateError;

      // Recarregar dades
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

      const updates: any = {
        estat: editForm.estat,
        taula_assignada: editForm.taula_assignada,
        observacions_junta: editForm.observacions_junta || null
      };

      if (editForm.data_programada && editForm.hora_inici) {
        updates.data_programada = editForm.data_programada + 'T' + editForm.hora_inici + ':00';
        updates.hora_inici = editForm.hora_inici;
      }

      // Comprovar conflicte de billar abans de desar
      if (updates.data_programada && updates.hora_inici && updates.taula_assignada) {
        const dia = updates.data_programada.split('T')[0];
        const { data: conflict } = await supabase
          .from('calendari_partides')
          .select('id, jugador1_soci_numero, jugador2_soci_numero, socis!calendari_partides_jugador1_soci_numero_fkey(nom)')
          .eq('data_programada::date', dia)
          .eq('hora_inici', updates.hora_inici)
          .eq('taula_assignada', updates.taula_assignada)
          .neq('id', editingMatch.id)
          .or('partida_anullada.is.null,partida_anullada.eq.false')
          .maybeSingle();
        if (conflict) {
          throw new Error(`El billar ${updates.taula_assignada} ja té una partida programada el ${dia} a les ${updates.hora_inici}. Tria un altre billar o una altra hora.`);
        }
      }

      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update(updates)
        .eq('id', editingMatch.id);

      if (updateError) {
        if (updateError.message?.includes('idx_unique_billar_slot')) {
          throw new Error(`El billar ${updates.taula_assignada} ja té una partida a aquesta hora. Tria un altre billar o una altra hora.`);
        }
        throw updateError;
      }

      // Tancar edició abans de recarregar
      cancelEditing();

      // Recarregar dades
      await loadCalendarData();
      dispatch('matchUpdated');

    } catch (e) {
      error = formatSupabaseError(e);
      alert('Error guardant els canvis: ' + error);
    } finally {
      loading = false;
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

    // Validar que les partides tinguin dates i hores assignades
    if (!match1.data_programada || !match1.hora_inici || !match2.data_programada || !match2.hora_inici) {
      error = 'Les partides han de tenir data i hora assignades per poder-les intercanviar.';
      return;
    }

    // Confirmar l'intercanvi
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
      // Intercanviar les dates i hores
      const { error: error1 } = await supabase
        .from('calendari_partides')
        .update({
          data_programada: match2.data_programada,
          hora_inici: match2.hora_inici,
          taula_assignada: match2.taula_assignada
        })
        .eq('id', match1.id);

      if (error1) throw error1;

      const { error: error2 } = await supabase
        .from('calendari_partides')
        .update({
          data_programada: match1.data_programada,
          hora_inici: match1.hora_inici,
          taula_assignada: match1.taula_assignada
        })
        .eq('id', match2.id);

      if (error2) throw error2;

      // Recarregar les dades
      await loadCalendarData();

      // Resetear la selecció
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

      // Crear i descarregar el fitxer
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');
      if (link.download !== undefined) {
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `calendari_${eventData.nom.replace(/[^a-zA-Z0-9]/g, '_')}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }
    } catch (error) {
      console.error('Error exporting calendar:', error);
      const errorMessage = error instanceof Error ? error.message : 'Error desconegut';
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
    :global(html), :global(body) {
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
    :global(body) {
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
      width: 60px !important;
      min-width: 60px !important;
      max-width: 60px !important;
      visibility: visible !important;
      display: table-cell !important;
    }

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
    :global(h3), :global(h4) {
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

    :global(.print-date) {
      font-size: 10px !important;
      font-style: italic !important;
      margin: 0 !important;
      color: #888 !important;
    }

    .print-header-right {
      flex: 0 0 auto !important;
    }

    :global(.print-contact) {
      text-align: right !important;
      font-size: 10px !important;
      line-height: 1.4 !important;
    }

    :global(.print-contact-line) {
      margin-bottom: 2px !important;
      color: #666 !important;
    }

    .print-divider {
      border: none !important;
      border-top: 2px solid #333 !important;
      margin: 0 0 20px 0 !important;
    }

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
    :global(.day-separator-row) {
      border-top: 4px solid #333 !important;
    }

    :global(.hour-separator-row) {
      border-top: 2px solid #666 !important;
    }

    /* Millores generals de les línies de divisió */
    tbody tr {
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

  /* Estils específics per a la pantalla (no print) */
  @media screen {
    .table-column {
      min-width: 100px !important;
      width: 100px !important;
      visibility: visible !important;
      display: table-cell !important;
    }

    .table-number-compact {
      display: inline-block !important;
      visibility: visible !important;
    }

    /* Forçar visibilitat de la columna del billar */
    .calendar-table .table-column {
      opacity: 1 !important;
      visibility: visible !important;
      display: table-cell !important;
    }
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
            {#if programmedMatches.some(match => match.estat === 'publicat')}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-emerald-100 text-emerald-800 mr-2">
                📢 {programmedMatches.filter(match => match.estat === 'publicat').length} publicats
              </span>
            {/if}

            {#if selectedPlayerId || playerSearch.length >= 2}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                🔍 Filtrant per: {playerSearch} | Partits trobats: {filteredMatches.length}/{matches.length} | Slots amb partits: {playerMatchSlots}
              </span>
            {/if}
          </div>
        {/if}
      </div>

      <!-- Controls de vista - Botons d'acció admin -->
      <div class="flex flex-wrap items-center gap-3">
        <!-- Botó de publicar calendari (només per admins i si hi ha partits validats) -->
        {#if isAdmin && programmedMatches.some(match => match.estat === 'validat')}
          <button
            on:click={publishCalendar}
            class="no-print px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 flex items-center gap-2 font-medium"
            title="Publicar calendari al calendari general de la PWA"
            disabled={loading}
          >
            {#if publishing}
              <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
              Publicant...
            {:else}
              📢 Publicar
            {/if}
          </button>
        {/if}

        <!-- Botó per convertir partides antigues (només per admins) -->
        {#if isAdmin}
          <button
            on:click={convertOldMatchesToPending}
            class="no-print px-4 py-2 bg-purple-600 text-white text-sm rounded hover:bg-purple-700 flex items-center gap-2 font-medium"
            title="Convertir partides antigues sense resultats a pendent de programar"
            disabled={loading}
          >
            🔄 Reciclar Antigues
          </button>
        {/if}

        <!-- Controls d'intercanvi de partides (només per admins) -->
        {#if isAdmin}
          <div class="flex items-center gap-2">
            <button
              on:click={toggleSwapMode}
              class="no-print px-4 py-2 text-sm rounded font-medium flex items-center justify-center gap-2"
              class:bg-orange-600={swapMode}
              class:text-white={swapMode}
              class:hover:bg-orange-700={swapMode}
              class:bg-orange-100={!swapMode}
              class:text-orange-800={!swapMode}
              class:hover:bg-orange-200={!swapMode}
              title="Activar/desactivar mode d'intercanvi de partides"
            >
              🔄 <span class="hidden sm:inline">{swapMode ? 'Cancel·lar' : 'Intercanviar'}</span>
            </button>

            {#if swapMode && selectedMatches.size === 2}
              <button
                on:click={swapMatches}
                class="no-print px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 font-medium flex items-center justify-center gap-1"
                title="Confirmar intercanvi de les partides seleccionades"
              >
                ✅ <span class="hidden sm:inline">Confirmar</span>
              </button>
            {/if}

            {#if swapMode}
              <span class="text-sm text-gray-600 font-medium">
                {selectedMatches.size}/2
              </span>
            {/if}
          </div>
        {/if}

        <!-- Botó d'exportar CSV (només per admins) -->
        {#if isAdmin}
          <button
            on:click={downloadCalendariCSV}
            class="no-print px-4 py-2 bg-purple-600 text-white text-sm rounded hover:bg-purple-700 items-center gap-2 font-medium flex"
            title="Exportar calendari a CSV"
          >
            📄 Exportar
          </button>
        {/if}

        <!-- Botó d'impressió -->
        <button
          on:click={printCalendar}
          class="no-print hidden md:flex px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 items-center gap-2 font-medium"
          title="Imprimir calendari cronològic"
        >
          🖨️ Imprimir
        </button>
      </div>
    </div>

    <!-- Filtres - Primera fila -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div>
        <label for="category-filter" class="block text-sm font-medium text-gray-700 mb-2">Categoria</label>
        <select
          id="category-filter"
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
        <label for="date-filter" class="block text-sm font-medium text-gray-700 mb-2">Data</label>
        <input
          id="date-filter"
          type="date"
          bind:value={selectedDate}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div class="relative print-header-hide player-search-container">
        <label for="player-search" class="block text-sm font-medium text-gray-700 mb-2">Jugador</label>
        <div class="relative">
          <input
            id="player-search"
            type="text"
            bind:value={playerSearch}
            on:input={() => { selectedPlayerId = null; }}
            placeholder="Escriu nom o cognoms..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 pr-8"
            disabled={showOnlyMyMatches}
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
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div>
        <div class="block text-sm font-medium text-gray-700 mb-2 invisible" aria-hidden="true">Accions</div>
        <button
          on:click={() => { selectedCategory = ''; selectedDate = ''; clearPlayerSearch(); }}
          class="w-full px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700 font-medium"
        >
          Netejar Filtres
        </button>
      </div>
    </div>

    <!-- Filtres - Segona fila: Selector de vista i checkbox -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-2">
      <div class="flex items-end">
        <div class="flex bg-gray-100 rounded-lg p-1">
          <button
            on:click={() => viewMode = 'category'}
            class="px-3 py-1.5 rounded text-sm transition-colors font-medium"
            class:bg-white={viewMode === 'category'}
            class:shadow-sm={viewMode === 'category'}
            class:text-gray-900={viewMode === 'category'}
            class:text-gray-600={viewMode !== 'category'}
          >
            📋 Per Categoria
          </button>
          <button
            on:click={() => viewMode = 'timeline'}
            class="px-3 py-1.5 rounded text-sm transition-colors font-medium"
            class:bg-white={viewMode === 'timeline'}
            class:shadow-sm={viewMode === 'timeline'}
            class:text-gray-900={viewMode === 'timeline'}
            class:text-gray-600={viewMode !== 'timeline'}
          >
            📅 Cronològica
          </button>
        </div>
      </div>

      <div>
        <!-- Columna buida per mantenir el grid -->
      </div>

      <div class="flex items-start">
        {#if myPlayerData}
          <label class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
            <input
              type="checkbox"
              bind:checked={showOnlyMyMatches}
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <span class="font-medium">🎯 Les meves partides</span>
          </label>
        {/if}
      </div>

      <div>
        <!-- Columna buida per mantenir el grid -->
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
  {#if !isDataReady}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center print-header-hide">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">
        {loading ? 'Carregant calendari...' : 'Esperant dades del calendari...'}
      </p>
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
                  {#if isAdmin && swapMode}
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-center text-xs font-medium text-gray-500 uppercase print-hide">Sel.</th>
                  {/if}
                  <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">Data</th>
                  <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">Hora</th>
                  <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase hidden sm:table-cell">Taula</th>
                  <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">Enfrontament</th>
                  {#if isAdmin}
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase print-hide">Accions</th>
                  {/if}
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each categoryMatches as match}
                  <tr class="hover:bg-gray-50" class:bg-blue-50={swapMode && selectedMatches.has(match.id)}>
                    {#if isAdmin && swapMode}
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-center print-hide">
                        <input
                          type="checkbox"
                          checked={selectedMatches.has(match.id)}
                          on:change={() => toggleMatchSelection(match.id)}
                          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                          disabled={!match.data_programada || !match.hora_inici}
                        />
                      </td>
                    {/if}
                    <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-sm sm:text-base text-gray-900">
                      <div class="flex flex-col">
                        <span>{match.data_programada ? formatDate(new Date(match.data_programada)) : 'No programada'}</span>
                        <span class="text-xs text-gray-500 sm:hidden">
                          {match.hora_inici || '-'}
                          {#if match.taula_assignada}• B{match.taula_assignada}{/if}
                        </span>
                      </div>
                    </td>
                    <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-sm sm:text-base text-gray-900">
                      {match.hora_inici || '-'}
                    </td>
                    <td class="hidden sm:table-cell px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-sm sm:text-base text-gray-900">
                      {match.taula_assignada ? `B${match.taula_assignada}` : 'No assignada'}
                    </td>
                    <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-sm sm:text-base text-gray-900">
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
                    {#if isAdmin}
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium print-hide">
                        <div class="flex flex-col space-y-1">
                          {#if match.estat !== 'jugada' && match.estat !== 'validat'}
                            <button
                              on:click={() => openResultModal(match)}
                              class="text-green-600 hover:text-green-900 font-medium"
                              title="Introduir resultat de la partida"
                            >
                              📝 Resultat
                            </button>
                            <button
                              on:click={() => openIncompareixencaModal(match)}
                              class="text-red-600 hover:text-red-900 font-medium text-xs"
                              title="Marcar incompareixença"
                            >
                              ⚠️ Incompareixença
                            </button>
                          {/if}
                          <button
                            on:click={() => startEditing(match)}
                            class="text-blue-600 hover:text-blue-900"
                          >
                            Editar
                          </button>
                          {#if match.data_programada}
                            <button
                              on:click={() => convertToUnprogrammed(match)}
                              class="text-orange-600 hover:text-orange-900 text-xs"
                              title="Convertir a no programada"
                            >
                              No programar
                            </button>
                          {/if}
                        </div>
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
          {#if selectedPlayerId || playerSearch.length >= 2}
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
                {#if isAdmin && swapMode}
                  <th class="px-3 py-4 text-center text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 print-hide">Seleccionar</th>
                {/if}
                <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-4 border-gray-800 day-column">Dia</th>
                <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-4 border-gray-800 hour-column">Hora</th>
                <th class="px-2 sm:px-6 py-2 sm:py-4 text-center text-xs sm:text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 table-column min-w-[60px] sm:min-w-[100px]">Billar</th>
                <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-2 border-gray-400 player-column hidden sm:table-cell">Jugador 1</th>
                <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-2 border-gray-400 player-column hidden sm:table-cell">Jugador 2</th>
                <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-2 border-gray-400 player-column sm:hidden">Partida</th>
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
                        class:border-t-gray-400={hourIndex > 0 && slotIndex === 0}
                        class:bg-blue-50={swapMode && slot.match && selectedMatches.has(slot.match.id)}>

                      <!-- Checkbox column for swap mode -->
                      {#if isAdmin && swapMode}
                        <td class="px-3 py-4 whitespace-nowrap text-center border-r-2 border-gray-400 print-hide">
                          {#if slot.match}
                            <input
                              type="checkbox"
                              checked={selectedMatches.has(slot.match.id)}
                              on:change={() => toggleMatchSelection(slot.match.id)}
                              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                              disabled={!slot.match.data_programada || !slot.match.hora_inici}
                            />
                          {/if}
                        </td>
                      {/if}

                      <!-- Day column with rowspan -->
                      {#if hourIndex === 0 && slotIndex === 0}
                        <td class="px-2 sm:px-3 py-2 sm:py-4 text-base sm:text-lg lg:text-xl xl:text-2xl font-bold text-gray-900 border-r-4 border-gray-800 bg-gray-50 align-top day-column" rowspan={totalSlotsForDay}>
                          <div class="sticky top-0 print-day-header">
                            <div class="print-date-main text-base sm:text-lg lg:text-xl xl:text-2xl">{formatDate(new Date(dateStr))}</div>
                            <div class="print-day-name text-xs sm:text-sm hidden sm:block">{dayNames[getDayOfWeekCode(new Date(dateStr + 'T00:00:00').getDay())]}</div>
                          </div>
                        </td>
                      {/if}

                      <!-- Hour column with rowspan for each hour group -->
                      {#if slotIndex === 0}
                        <td class="px-2 sm:px-3 py-2 sm:py-4 text-base sm:text-lg lg:text-xl xl:text-2xl font-bold text-gray-800 border-r-4 border-gray-800 bg-gray-100 align-top hour-column" rowspan={slots.length}>
                          <div class="print-hour-header">{hora}</div>
                        </td>
                      {/if}

                      <!-- Table column -->
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm md:text-base text-gray-900 border-r-2 border-gray-400 table-column text-center font-medium min-w-[60px] sm:min-w-[100px]" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match && slot.match.taula_assignada}
                          <span class="table-number-compact bg-green-100 px-3 py-2 rounded-full text-green-800 font-bold text-lg">B{slot.match.taula_assignada}</span>
                        {:else if slot.match}
                          <!-- Match but no taula_assignada -->
                          <span class="table-number-compact bg-orange-100 px-3 py-2 rounded-full text-orange-800 font-bold text-lg">B{slot.taula}</span>
                        {:else}
                          <!-- Empty slot -->
                          <span class="table-number-compact bg-blue-100 px-3 py-2 rounded-full text-blue-800 font-bold text-lg">B{slot.taula}</span>
                        {/if}
                      </td>



                      <!-- Jugador 1 (hidden on mobile) -->
                      <td class="hidden sm:table-cell px-2 sm:px-3 py-2 sm:py-4 whitespace-nowrap text-base sm:text-lg lg:text-xl xl:text-2xl text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <span class="font-semibold">{formatPlayerName(slot.match.jugador1)}</span>
                        {/if}
                      </td>

                      <!-- Jugador 2 (hidden on mobile) -->
                      <td class="hidden sm:table-cell px-2 sm:px-3 py-2 sm:py-4 whitespace-nowrap text-base sm:text-lg lg:text-xl xl:text-2xl text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <span class="font-semibold">{formatPlayerName(slot.match.jugador2)}</span>
                        {/if}
                      </td>

                      <!-- Combined players column (visible only on mobile) -->
                      <td class="sm:hidden px-2 py-2 text-sm text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                        {#if slot.match}
                          <div class="flex flex-col">
                            <span class="font-semibold text-sm">{formatPlayerName(slot.match.jugador1)}</span>
                            <span class="text-xs text-gray-500">vs</span>
                            <span class="font-semibold text-sm">{formatPlayerName(slot.match.jugador2)}</span>
                          </div>
                        {/if}
                      </td>



                      <!-- Actions column -->
                      {#if isAdmin}
                        <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base font-medium print-hide">
                          {#if slot.match}
                            <div class="flex flex-col space-y-1">
                              {#if slot.match.estat !== 'jugada' && slot.match.estat !== 'cancel·lada'}
                                <button
                                  on:click={() => openResultModal(slot.match)}
                                  class="text-green-600 hover:text-green-900 text-sm md:text-base font-semibold"
                                  title="Introduir resultat de la partida"
                                >
                                  📝 Resultat
                                </button>
                                <button
                                  on:click={() => openIncompareixencaModal(slot.match)}
                                  class="text-red-600 hover:text-red-900 text-xs md:text-sm font-semibold"
                                  title="Marcar incompareixença"
                                >
                                  ⚠️ Incompareixença
                                </button>
                              {/if}
                              <button
                                on:click={() => startEditing(slot.match)}
                                class="text-blue-600 hover:text-blue-900 text-sm md:text-base font-medium"
                              >
                                Editar
                              </button>
                              {#if slot.match.data_programada}
                                <button
                                  on:click={() => convertToUnprogrammed(slot.match)}
                                  class="text-orange-600 hover:text-orange-900 text-xs md:text-sm font-medium"
                                  title="Convertir a no programada"
                                >
                                  No programar
                                </button>
                              {/if}
                            </div>
                          {:else}
                            <!-- Empty slot actions -->
                            <button
                              on:click={() => programEmptySlot(slot)}
                              class="text-green-600 hover:text-green-900 text-sm md:text-base font-semibold"
                              title="Programar partida en aquest slot"
                            >
                              + Programar
                            </button>
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
              <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Jugador 1</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Jugador 2</th>
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
                  {match.categoria_nom || getCategoryName(match.categoria_id)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <span class="font-medium">
                    {formatPlayerName(match.jugador1)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <span class="font-medium">
                    {formatPlayerName(match.jugador2)}
                  </span>
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
          <label for="edit-date" class="block text-sm font-medium text-gray-700 mb-1">Data</label>
          <input
            id="edit-date"
            type="date"
            bind:value={editForm.data_programada}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label for="edit-time" class="block text-sm font-medium text-gray-700 mb-1">Hora</label>
          <input
            id="edit-time"
            type="time"
            bind:value={editForm.hora_inici}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label for="edit-table-input" class="block text-sm font-medium text-gray-700 mb-1">Taula</label>
          <input
            id="edit-table-input"
            type="number"
            min="1"
            max="10"
            bind:value={editForm.taula_assignada}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label for="edit-status" class="block text-sm font-medium text-gray-700 mb-1">Estat</label>
          <select
            id="edit-status"
            bind:value={editForm.estat}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            {#each estatOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>

        <div>
          <label for="edit-observations" class="block text-sm font-medium text-gray-700 mb-1">Observacions</label>
          <textarea
            id="edit-observations"
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

<!-- Modal per introduir resultats -->
{#if showResultModal && resultMatch}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex items-center justify-center p-4">
    <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-medium text-gray-900">
            📝 Introduir Resultat de la Partida
          </h3>
          <button
            on:click={closeResultModal}
            class="text-gray-400 hover:text-gray-600"
            aria-label="Tancar modal de resultat"
          >
            <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <div class="px-6 py-4">
        <!-- Info partida -->
        <div class="bg-gray-50 rounded-lg p-4 mb-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <div class="text-sm text-gray-600">Jugador 1</div>
              <div class="text-lg font-semibold text-gray-900">
                {formatPlayerName(resultMatch.jugador1)}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-600">Jugador 2</div>
              <div class="text-lg font-semibold text-gray-900">
                {formatPlayerName(resultMatch.jugador2)}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-600">Data</div>
              <div class="font-medium">
                {resultMatch.data_programada ? formatDate(new Date(resultMatch.data_programada)) : '-'}
                {#if resultMatch.hora_inici}
                  · {resultMatch.hora_inici}
                {/if}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-600">Categoria</div>
              <div class="font-medium">{resultMatch.categoria_nom || getCategoryName(resultMatch.categoria_id)}</div>
            </div>
          </div>
        </div>

        <!-- Formulari resultats -->
        <form on:submit|preventDefault={saveResult} class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label for="result-car1" class="block text-sm font-medium text-gray-700 mb-2">
                Caramboles {formatPlayerName(resultMatch.jugador1)}
              </label>
              <input
                id="result-car1"
                type="number"
                min="0"
                bind:value={resultForm.caramboles_jugador1}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-lg font-semibold text-center"
                required
              />
            </div>

            <div>
              <label for="result-car2" class="block text-sm font-medium text-gray-700 mb-2">
                Caramboles {formatPlayerName(resultMatch.jugador2)}
              </label>
              <input
                id="result-car2"
                type="number"
                min="0"
                bind:value={resultForm.caramboles_jugador2}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-lg font-semibold text-center"
                required
              />
            </div>

            <div>
              <label for="result-entrades" class="block text-sm font-medium text-gray-700 mb-2">
                Entrades
              </label>
              <input
                id="result-entrades"
                type="number"
                min="0"
                bind:value={resultForm.entrades}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-lg font-semibold text-center"
                required
              />
            </div>
          </div>

          <!-- Guanyador calculat -->
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div class="text-sm font-medium text-blue-900">
              🏆 Guanyador:
              {#if resultForm.caramboles_jugador1 > resultForm.caramboles_jugador2}
                <span class="font-bold">{formatPlayerName(resultMatch.jugador1)}</span>
              {:else if resultForm.caramboles_jugador2 > resultForm.caramboles_jugador1}
                <span class="font-bold">{formatPlayerName(resultMatch.jugador2)}</span>
              {:else}
                <span class="text-gray-600">Empat (introdueix més caramboles)</span>
              {/if}
            </div>
          </div>

          <div>
            <label for="result-obs" class="block text-sm font-medium text-gray-700 mb-2">
              Observacions (opcional)
            </label>
            <textarea
              id="result-obs"
              bind:value={resultForm.observacions}
              rows="3"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Incidències, comentaris..."
            ></textarea>
          </div>

          <div class="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              on:click={closeResultModal}
              class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400 font-medium"
              disabled={loading}
            >
              Cancel·lar
            </button>
            <button
              type="submit"
              class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 font-medium flex items-center gap-2"
              disabled={loading}
            >
              {#if loading}
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                Guardant...
              {:else}
                💾 Guardar Resultat
              {/if}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
{/if}

<!-- Modal d'Incompareixença -->
{#if showIncompareixencaModal && incompareixencaMatch}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex items-center justify-center p-4">
    <div class="relative bg-white rounded-lg shadow-xl max-w-2xl w-full mx-auto">
      <div class="bg-red-50 border-b border-red-200 px-6 py-4">
        <h3 class="text-xl font-bold text-red-900 flex items-center">
          <span class="mr-2">⚠️</span> Registrar Incompareixença
        </h3>
      </div>

      <div class="p-6">
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
          <p class="text-sm text-yellow-800 font-medium mb-2">
            ℹ️ Informació sobre incompareixences:
          </p>
          <ul class="text-sm text-yellow-800 list-disc list-inside space-y-1">
            <li>El jugador que <strong>no s'ha presentat</strong> rebrà: 0 punts, 50 entrades</li>
            <li>El jugador que <strong>s'ha presentat</strong> rebrà: 2 punts, 0 entrades</li>
            <li>Si un jugador té <strong>2 incompareixences</strong>, serà eliminat automàticament del campionat</li>
            <li>Totes les partides pendents del jugador eliminat quedaran <strong>anul·lades</strong></li>
          </ul>
        </div>

        <div class="mb-6">
          <h4 class="font-medium text-gray-900 mb-4 text-center">Quin jugador NO s'ha presentat?</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <!-- Jugador 1 -->
            <button
              on:click={() => marcarIncompareixenca(1)}
              class="p-6 border-2 border-red-300 rounded-lg hover:bg-red-50 hover:border-red-500 transition-colors"
              disabled={loading}
            >
              <div class="text-center">
                <div class="text-3xl mb-2">👤</div>
                <div class="font-bold text-lg text-gray-900 mb-1">Jugador 1</div>
                <div class="text-base text-gray-700">
                  {formatPlayerName(incompareixencaMatch.jugador1)}
                </div>
                <div class="mt-3 text-sm text-red-600 font-medium">
                  ⚠️ Marcar incompareixença
                </div>
              </div>
            </button>

            <!-- Jugador 2 -->
            <button
              on:click={() => marcarIncompareixenca(2)}
              class="p-6 border-2 border-red-300 rounded-lg hover:bg-red-50 hover:border-red-500 transition-colors"
              disabled={loading}
            >
              <div class="text-center">
                <div class="text-3xl mb-2">👤</div>
                <div class="font-bold text-lg text-gray-900 mb-1">Jugador 2</div>
                <div class="text-base text-gray-700">
                  {formatPlayerName(incompareixencaMatch.jugador2)}
                </div>
                <div class="mt-3 text-sm text-red-600 font-medium">
                  ⚠️ Marcar incompareixença
                </div>
              </div>
            </button>
          </div>
        </div>

        <div class="bg-gray-50 border-t border-gray-200 -mx-6 -mb-6 px-6 py-4 flex justify-end">
          <button
            on:click={closeIncompareixencaModal}
            class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 font-medium"
            disabled={loading}
          >
            ❌ Cancel·lar
          </button>
        </div>
      </div>
    </div>
  </div>
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
