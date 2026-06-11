/**
 * Càrrega de dates bloquejades del torneig hàndicap.
 *
 * Les dates bloquejades s'emmagatzemen a `handicap_config.blocked_periods`
 * com un array de { start: 'YYYY-MM-DD', end: 'YYYY-MM-DD', description: string }.
 * Un període d'un sol dia té start === end.
 *
 * Retorna un Set<string> de dates en format 'YYYY-MM-DD' que no s'han de
 * programar (festius, períodes vetats per l'admin, etc.).
 */

import type { SupabaseClient } from '@supabase/supabase-js';

interface BlockedPeriod {
	start: string;  // 'YYYY-MM-DD'
	end: string;    // 'YYYY-MM-DD'
	description?: string;
}

/**
 * Expandeix un array de períodes bloquejats en un Set de dates individuals.
 */
export function expandBlockedPeriods(periods: BlockedPeriod[]): Set<string> {
	const result = new Set<string>();
	for (const p of periods) {
		if (!p.start || !p.end) continue;
		const [sy, sm, sd] = p.start.split('-').map(Number);
		const [ey, em, ed] = p.end.split('-').map(Number);
		const cur = new Date(sy, sm - 1, sd);
		const endDate = new Date(ey, em - 1, ed);
		while (cur <= endDate) {
			const yyyy = cur.getFullYear();
			const mm = String(cur.getMonth() + 1).padStart(2, '0');
			const dd = String(cur.getDate()).padStart(2, '0');
			result.add(`${yyyy}-${mm}-${dd}`);
			cur.setDate(cur.getDate() + 1);
		}
	}
	return result;
}

/**
 * Llegeix `handicap_config.blocked_periods` per a l'event donat i retorna un
 * Set<string> de dates 'YYYY-MM-DD' bloquejades.
 *
 * Retorna un Set buit si no hi ha configuració o si `blocked_periods` és null.
 */
export async function loadBlockedDates(
	supabase: SupabaseClient,
	eventId: string
): Promise<Set<string>> {
	const { data: cfg } = await supabase
		.from('handicap_config')
		.select('blocked_periods')
		.eq('event_id', eventId)
		.maybeSingle();

	if (!cfg?.blocked_periods || !Array.isArray(cfg.blocked_periods)) {
		return new Set<string>();
	}

	return expandBlockedPeriods(cfg.blocked_periods as BlockedPeriod[]);
}
