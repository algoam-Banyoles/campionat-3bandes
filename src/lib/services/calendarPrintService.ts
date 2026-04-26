/**
 * Servei pur per a la generació d'HTML d'impressió del calendari de
 * campionats socials. Extret de `SocialLeagueCalendarViewer.svelte`
 * per separar la lògica de presentació de la d'estat.
 *
 * Cap funció toca el DOM, supabase ni window; tot són transformacions
 * `(input) → string`. La crida al `window.open()` queda al component.
 */

import { formatDate, getDayOfWeekCode, type TimelineSlot } from './calendarTimelineService';
import { formatPlayerName } from './calendarPlayerSearchService';

const DAY_NAMES: Record<string, string> = {
  dl: 'Dilluns',
  dt: 'Dimarts',
  dc: 'Dimecres',
  dj: 'Dijous',
  dv: 'Divendres',
  ds: 'Dissabte',
  dg: 'Diumenge'
};

export interface PrintContext {
  eventData: { nom?: string; temporada?: string } | null;
  isAdmin: boolean;
  /** Partides filtrades, només per generar la secció "pendents". */
  pendingMatches: any[];
  /** Timeline ja filtrat i agrupat per dia/hora (slots ordenats). */
  timelineGrouped: Map<string, Map<string, TimelineSlot[]>>;
  categories: any[];
}

/** Genera l'HTML complet per a la finestra d'impressió. */
export function generatePrintHTML(ctx: PrintContext, useDoubleColumn: boolean): string {
  const tableHTML = generateTableHTML(ctx, useDoubleColumn);

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Calendari ${ctx.eventData?.nom || 'Campionat'}</title>
      <style>
        @page {
          margin: 0.4in 0.3in 0.2in 0.3in;
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

/** HTML de la capçalera (logotip + títol + temporada). */
export function generateHeaderHTML(eventData: PrintContext['eventData']): string {
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
      <div class="print-header-right"></div>
    </div>
    <hr class="print-divider" />
  `;
}

/** HTML del cos: timeline programada + secció de pendents. */
export function generateTableHTML(ctx: PrintContext, useDoubleColumn: boolean): string {
  const scheduledHTML = useDoubleColumn
    ? generatePaginatedHTML(ctx, ctx.timelineGrouped)
    : generateSingleColumnHTML(ctx, ctx.timelineGrouped);

  const pendingHTML = generatePendingMatchesHTML(ctx);

  return scheduledHTML + pendingHTML;
}

/** HTML per a la secció "Partides pendents de programar". */
export function generatePendingMatchesHTML(ctx: PrintContext): string {
  if (ctx.pendingMatches.length === 0) return '';

  // Ordenar per categoria
  const sorted = [...ctx.pendingMatches].sort((a, b) => {
    const catA = ctx.categories.find(c => c.id === a.categoria_id);
    const catB = ctx.categories.find(c => c.id === b.categoria_id);
    if (catA?.ordre !== undefined && catB?.ordre !== undefined) {
      return catA.ordre - catB.ordre;
    }
    const nomA = catA?.nom || a.categoria_nom || '';
    const nomB = catB?.nom || b.categoria_nom || '';
    return nomA.localeCompare(nomB);
  });

  const pageBreak = '<div class="print-page-break"></div><div style="page-break-before: always; break-before: page; display: block; height: 1px; width: 100%; clear: both;"></div>';
  const headerHTML = generateHeaderHTML(ctx.eventData);

  const rowsHTML = sorted
    .map(match => {
      const categoria = ctx.categories.find(c => c.id === match.categoria_id);
      const categoriaText = categoria?.nom
        ? categoria.nom.replace(/categoria/i, '').trim()
        : (match.categoria_nom ? match.categoria_nom.replace(/categoria/i, '').trim() : '');
      const jugador1Text = match.jugador1?.nom
        ? `${match.jugador1.nom} ${match.jugador1.cognoms ?? ''}`.trim()
        : formatPlayerName(match.jugador1);
      const jugador2Text = match.jugador2?.nom
        ? `${match.jugador2.nom} ${match.jugador2.cognoms ?? ''}`.trim()
        : formatPlayerName(match.jugador2);

      return `
        <tr>
          ${ctx.isAdmin ? `<td class="category-cell">${categoriaText}</td>` : ''}
          <td class="player-cell">${jugador1Text}</td>
          <td class="player-cell">${jugador2Text}</td>
          <td class="observations-cell">${match.observacions || ''}</td>
        </tr>
      `;
    })
    .join('');

  return `
    ${pageBreak}
    ${headerHTML}
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
            ${ctx.isAdmin ? '<th class="category-column">Categoria</th>' : ''}
            <th class="player-column">Jugador 1</th>
            <th class="player-column">Jugador 2</th>
            <th class="observations-column">Observacions</th>
          </tr>
        </thead>
        <tbody>
          ${rowsHTML}
        </tbody>
      </table>
    </div>
  `;
}

/** Layout paginat de dues columnes: dies cronològics distribuïts. */
export function generatePaginatedHTML(
  ctx: PrintContext,
  timelineGrouped: Map<string, Map<string, TimelineSlot[]>>
): string {
  const daysArray = Array.from(timelineGrouped.entries()).sort(
    ([dateA], [dateB]) => new Date(dateA).getTime() - new Date(dateB).getTime()
  );

  const daysWithSlotCount = daysArray.map(([dateStr, hourGroups], idx) => {
    const totalSlots = Array.from(hourGroups.values()).reduce(
      (total, slots) => total + slots.length,
      0
    );
    return { dateStr, hourGroups, totalSlots, index: idx };
  });

  const maxSlotsPerPage = 60;
  const pages: { leftColumn: [string, Map<string, TimelineSlot[]>][]; rightColumn: [string, Map<string, TimelineSlot[]>][] }[] = [];

  let currentPageDays: typeof daysWithSlotCount = [];
  let currentPageSlots = 0;

  for (const day of daysWithSlotCount) {
    if (currentPageSlots > 0 && currentPageSlots + day.totalSlots > maxSlotsPerPage) {
      pages.push(createPageFromDays(currentPageDays));
      currentPageDays = [];
      currentPageSlots = 0;
    }
    currentPageDays.push(day);
    currentPageSlots += day.totalSlots;
  }

  if (currentPageDays.length > 0) {
    pages.push(createPageFromDays(currentPageDays));
  }

  return pages.map((page, i) => generatePageHTML(ctx, page, i)).join('');
}

function createPageFromDays(
  pageDays: { dateStr: string; hourGroups: Map<string, TimelineSlot[]> }[]
): { leftColumn: [string, Map<string, TimelineSlot[]>][]; rightColumn: [string, Map<string, TimelineSlot[]>][] } {
  const daysForPage: [string, Map<string, TimelineSlot[]>][] = pageDays.map(d => [d.dateStr, d.hourGroups]);
  const splitPoint = Math.ceil(daysForPage.length / 2);
  return {
    leftColumn: daysForPage.slice(0, splitPoint),
    rightColumn: daysForPage.slice(splitPoint)
  };
}

function generatePageHTML(
  ctx: PrintContext,
  page: { leftColumn: [string, Map<string, TimelineSlot[]>][]; rightColumn: [string, Map<string, TimelineSlot[]>][] },
  pageIndex: number
): string {
  const pageBreak =
    pageIndex > 0
      ? `<div class="print-page-break"></div><div style="page-break-before: always; break-before: page; display: block; height: 1px; width: 100%; clear: both;"></div>`
      : '';
  const headerHTML = generateHeaderHTML(ctx.eventData);

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
            ${generateColumnHTML(ctx, page.leftColumn)}
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
            ${generateColumnHTML(ctx, page.rightColumn)}
          </tbody>
        </table>
      </div>
    </div>
  `;
}

function generateColumnHTML(
  ctx: PrintContext,
  columnDays: [string, Map<string, TimelineSlot[]>][]
): string {
  if (columnDays.length === 0) {
    return `
      <tr>
        <td colspan="${ctx.isAdmin ? '6' : '5'}" style="text-align: center; padding: 20px; color: #666; font-style: italic;">
          No hi ha més partides
        </td>
      </tr>
    `;
  }

  let html = '';
  for (const [dateStr, hourGroups] of columnDays) {
    const totalSlotsForDay = Array.from(hourGroups.values()).reduce(
      (total, slots) => total + slots.length,
      0
    );
    let dayRowSpanUsed = false;

    for (const [hora, slots] of Array.from(hourGroups.entries())) {
      let hourRowSpanUsed = false;

      for (const slot of slots) {
        html += '<tr>';

        if (!dayRowSpanUsed) {
          const dayCode = getDayOfWeekCode(new Date(dateStr + 'T00:00:00').getDay());
          html += `
            <td class="day-cell" rowspan="${totalSlotsForDay}">
              <div class="print-date-main">${formatDate(new Date(dateStr))}</div>
              <div class="print-day-name">${DAY_NAMES[dayCode] ?? ''}</div>
            </td>
          `;
          dayRowSpanUsed = true;
        }

        if (!hourRowSpanUsed) {
          html += `<td class="hour-cell" rowspan="${slots.length}">${hora}</td>`;
          hourRowSpanUsed = true;
        }

        html += `
          <td class="table-cell">B${slot.taula}</td>
          <td class="player-cell">${slot.match ? formatPlayerName(slot.match.jugador1) : '-'}</td>
          <td class="player-cell">${slot.match ? formatPlayerName(slot.match.jugador2) : '-'}</td>
        `;

        html += '</tr>';
      }
    }
  }
  return html;
}

/** Layout d'una sola columna (text més gran). */
export function generateSingleColumnHTML(
  ctx: PrintContext,
  timelineGrouped: Map<string, Map<string, TimelineSlot[]>>
): string {
  let tableHTML = `
    <table class="calendar-table single-column">
      <thead>
        <tr>
          <th class="day-column">Dia</th>
          <th class="hour-column">Hora</th>
          <th class="table-column">Billar</th>
          ${ctx.isAdmin ? '<th class="category-column">Cat</th>' : ''}
          <th class="player-column">Jugador 1</th>
          <th class="player-column">Jugador 2</th>
        </tr>
      </thead>
      <tbody>
  `;

  if (timelineGrouped.size === 0) {
    tableHTML += `
      <tr>
        <td colspan="${ctx.isAdmin ? '6' : '5'}" style="text-align: center; padding: 30px; color: #666; font-style: italic; font-size: 18px;">
          No hi ha partides programades per mostrar
        </td>
      </tr>
    `;
  } else {
    const allDays = Array.from(timelineGrouped.entries());
    tableHTML += generateColumnHTML(ctx, allDays);
  }

  tableHTML += '</tbody></table>';
  return tableHTML;
}

/** CSS per a la finestra d'impressió. */
export function getPrintCSS(): string {
  return `
    @page {
      margin: 0.5in 0.5in 0.3in 0.5in;
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
    .print-logo { height: 45px; width: auto; }
    .print-header-center { flex: 1; text-align: center; margin: 0 30px; }
    .print-main-title {
      font-size: 18px; font-weight: bold; margin: 0 0 6px 0;
      text-transform: uppercase; letter-spacing: 1px;
    }
    .print-event-title { font-size: 16px; font-weight: bold; margin: 0 0 4px 0; }
    .print-season { font-size: 14px; margin: 0; color: #666; }
    .print-divider { border: none; border-top: 3px solid #333; margin: 0 0 20px 0; }
    .calendar-table {
      width: 100%; border-collapse: collapse; font-size: 20px; margin-top: 15px;
    }
    .calendar-table th, .calendar-table td {
      border: 1px solid #333; padding: 8px 4px; text-align: center;
      vertical-align: middle; line-height: 1.3;
    }
    .calendar-table th {
      background-color: #e8e8e8; font-weight: bold; font-size: 18px;
      text-transform: uppercase; text-align: center; padding: 12px 6px;
    }
    .day-column { width: 120px; }
    .hour-column { width: 80px; }
    .table-column { width: 70px; }
    .category-column { width: 90px; }
    .player-column { width: 220px; }
    .day-cell {
      background-color: #f5f5f5; border-right: 3px solid #333;
      text-align: center; font-weight: bold; font-size: 21px;
    }
    .hour-cell {
      background-color: #f0f0f0; border-right: 3px solid #333;
      text-align: center; font-weight: bold; font-size: 22px;
    }
    .table-cell {
      text-align: center; font-weight: bold;
      background-color: #fafafa; font-size: 21px;
    }
    .category-cell { text-align: center; background-color: #f8f8f8; font-size: 20px; }
    .player-cell { font-weight: normal; text-align: center; font-size: 19px; padding: 8px 4px; }
    .print-date-main { font-size: 14px; font-weight: bold; margin-bottom: 3px; }
    .print-day-name { font-size: 12px; color: #666; font-style: italic; }

    /* Layout de dues columnes */
    .two-column-layout { display: flex; gap: 20px; width: 100%; }
    .column-left, .column-right { flex: 1; width: 48%; }
    .column-left .calendar-table,
    .column-right .calendar-table { width: 100%; font-size: 16px; }
    .two-column-layout .day-column { width: 85px; }
    .two-column-layout .hour-column { width: 55px; }
    .two-column-layout .table-column { width: 45px; }
    .two-column-layout .category-column { width: 55px; }
    .two-column-layout .player-column { width: 150px; }
    .two-column-layout .calendar-table th { font-size: 14px; }
    .two-column-layout .day-cell { font-size: 15px; }
    .two-column-layout .hour-cell { font-size: 16px; }
    .two-column-layout .table-cell { font-size: 15px; }
    .two-column-layout .category-cell { font-size: 14px; }
    .two-column-layout .player-cell { font-size: 15px; }
    .two-column-layout .print-date-main { font-size: 13px; }
    .two-column-layout .print-day-name { font-size: 11px; }

    /* Una sola columna (text més gran) */
    .calendar-table.single-column { font-size: 22px; }
    .calendar-table.single-column th { font-size: 20px; padding: 12px 8px; }
    .calendar-table.single-column .day-cell { font-size: 24px; }
    .calendar-table.single-column .hour-cell { font-size: 25px; }
    .calendar-table.single-column .table-cell { font-size: 24px; }
    .calendar-table.single-column .category-cell { font-size: 23px; }
    .calendar-table.single-column .player-cell { font-size: 22px; }
    .calendar-table.single-column .print-date-main { font-size: 19px; }
    .calendar-table.single-column .print-day-name { font-size: 17px; }

    /* Partides pendents */
    .pending-matches-section { margin-top: 30px; }
    .pending-matches-title {
      font-size: 20px; font-weight: bold; text-align: center;
      margin-bottom: 20px; color: #d97706; text-transform: uppercase;
    }
    .pending-matches-table .date-column { width: 15%; text-align: center; }
    .pending-matches-table .observations-column { width: 25%; }
    .pending-matches-table .date-cell {
      text-align: center; font-weight: bold; color: #dc2626;
    }
    .pending-matches-table .observations-cell { font-size: 12px; color: #666; }
  `;
}
