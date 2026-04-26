/**
 * Servei pur per a la timeline del calendari de campionats socials.
 *
 * Funcions sense dependència de Svelte ni Supabase: només transformacions
 * de dades. Permet provar-les en isolació i extreure ~250 línies del
 * component `SocialLeagueCalendarViewer.svelte`.
 */

export interface CalendarConfig {
  dies_setmana: string[];
  hores_disponibles: string[];
  taules_per_slot: number;
}

export interface TimelineMatch {
  id?: string;
  data_programada?: string | null;
  hora_inici?: string | null;
  taula_assignada?: number | string | null;
  categoria_id?: string;
  [key: string]: any;
}

export interface TimelineSlot {
  date: Date;
  dateStr: string;
  dayOfWeek: string;
  hora: string;
  taula: number;
  match: TimelineMatch | null;
}

const DAY_CODES = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];

const DEFAULT_CONFIG: CalendarConfig = {
  dies_setmana: ['dl', 'dt', 'dc', 'dj', 'dv'],
  hores_disponibles: ['18:00', '19:00'],
  taules_per_slot: 3
};

/** Format YYYY-MM-DD respectant la zona horària local. */
export function toLocalDateStr(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Codi del dia de la setmana (dl/dt/...) a partir d'un índex 0-6 (Date.getDay). */
export function getDayOfWeekCode(dayIndex: number): string {
  return DAY_CODES[dayIndex];
}

/** Format curt en català ("4 abr"). */
export function formatDate(date: Date): string {
  return date.toLocaleDateString('ca-ES', {
    day: 'numeric',
    month: 'short'
  });
}

/**
 * Genera la llista de dates disponibles a partir d'un conjunt de partides.
 * Si no n'hi ha cap programada, retorna un rang per defecte (-1 setmana,
 * +12 setmanes endavant).
 */
export function generateAvailableDates(matches: TimelineMatch[]): Date[] {
  let startDate: Date;
  let endDate: Date;

  const validMatches = matches.filter(m => m.data_programada);

  if (validMatches.length > 0) {
    const dates = validMatches.map(m => new Date(m.data_programada!));
    startDate = new Date(Math.min(...dates.map(d => d.getTime())));
    endDate = new Date(Math.max(...dates.map(d => d.getTime())));
    endDate.setDate(endDate.getDate() + 1);
  } else {
    startDate = new Date();
    startDate.setDate(startDate.getDate() - 7);
    endDate = new Date();
    endDate.setDate(endDate.getDate() + 12 * 7);
  }

  const weekEnd = new Date(endDate);
  weekEnd.setDate(weekEnd.getDate() + (7 - weekEnd.getDay()));

  const allDates: Date[] = [];
  for (let date = new Date(startDate); date <= weekEnd; date.setDate(date.getDate() + 1)) {
    allDates.push(new Date(date));
  }
  return allDates;
}

/**
 * Construeix la timeline (llista de slots) creuant les dates disponibles
 * amb la configuració d'hores i taules. Cada slot pot contenir una
 * partida o estar buit. Inclou també les partides "orfes" (programades
 * però fora del rang de dates).
 */
export function generateTimelineData(
  matches: TimelineMatch[],
  config: CalendarConfig | null,
  dates: Date[]
): TimelineSlot[] {
  const cfg = config || DEFAULT_CONFIG;
  const timeline: TimelineSlot[] = [];

  for (const date of dates) {
    const dateStr = toLocalDateStr(date);
    const dayOfWeek = getDayOfWeekCode(date.getDay());

    if (!cfg.dies_setmana?.includes(dayOfWeek)) continue;

    const hores = cfg.hores_disponibles ?? DEFAULT_CONFIG.hores_disponibles;
    const taules = cfg.taules_per_slot ?? DEFAULT_CONFIG.taules_per_slot;

    const dateMatches = matches.filter(match => {
      if (!match.data_programada) return false;
      return toLocalDateStr(new Date(match.data_programada)) === dateStr;
    });

    for (const hora of hores) {
      for (let taula = 1; taula <= taules; taula++) {
        const scheduledMatch = dateMatches.find(match => {
          const normalizedMatchHora = match.hora_inici?.substring(0, 5);
          return normalizedMatchHora === hora && parseInt(String(match.taula_assignada)) === taula;
        });

        timeline.push({
          date,
          dateStr,
          dayOfWeek,
          hora,
          taula,
          match: scheduledMatch || null
        });
      }
    }
  }

  // Afegir partides programades fora del rang (orfes)
  const linkedMatchIds = new Set(timeline.filter(s => s.match).map(s => s.match!.id));
  const orphanedMatches = matches.filter(m =>
    m.data_programada && m.id && !linkedMatchIds.has(m.id)
  );

  for (const match of orphanedMatches) {
    const matchDate = new Date(match.data_programada!);
    timeline.push({
      date: matchDate,
      dateStr: toLocalDateStr(matchDate),
      dayOfWeek: getDayOfWeekCode(matchDate.getDay()),
      hora: match.hora_inici?.substring(0, 5) || match.hora_inici || '18:00',
      taula: parseInt(String(match.taula_assignada)) || 1,
      match
    });
  }

  // Ordenació cronològica: data → hora → taula
  timeline.sort((a, b) => {
    const dateComparison = a.dateStr.localeCompare(b.dateStr);
    if (dateComparison !== 0) return dateComparison;
    const timeComparison = a.hora.localeCompare(b.hora);
    if (timeComparison !== 0) return timeComparison;
    return a.taula - b.taula;
  });

  return timeline;
}

/** Agrupa partides per `categoria_id`. */
export function groupByCategory<T extends { categoria_id?: string }>(matches: T[]): Map<string, T[]> {
  const groups = new Map<string, T[]>();
  for (const match of matches) {
    const id = match.categoria_id ?? '';
    if (!groups.has(id)) groups.set(id, []);
    groups.get(id)!.push(match);
  }
  return groups;
}

/**
 * Agrupa la timeline en una estructura `dia → hora → slots[]`.
 */
export function groupTimelineByDayAndHour(
  timeline: TimelineSlot[]
): Map<string, Map<string, TimelineSlot[]>> {
  const grouped = new Map<string, Map<string, TimelineSlot[]>>();

  for (const slot of timeline) {
    if (!grouped.has(slot.dateStr)) {
      grouped.set(slot.dateStr, new Map());
    }
    const dayMap = grouped.get(slot.dateStr)!;
    if (!dayMap.has(slot.hora)) {
      dayMap.set(slot.hora, []);
    }
    dayMap.get(slot.hora)!.push(slot);
  }
  return grouped;
}
