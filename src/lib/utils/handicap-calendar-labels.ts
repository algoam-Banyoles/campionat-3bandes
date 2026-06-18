/**
 * Etiquetes dels jugadors d'una partida d'hàndicap programada al calendari
 * general (taula `calendari_partides`).
 *
 * Problema que resol: quan una partida d'hàndicap es programa amb data
 * orientativa abans de conèixer els dos contrincants, les columnes
 * `jugador1_soci_numero` / `jugador2_soci_numero` de `calendari_partides`
 * queden a NULL per al slot encara no resolt. Els consumidors del calendari
 * general (home, /general/calendari, widget de properes partides) mostraven
 * llavors "Desconegut" o el nom en blanc.
 *
 * Aquesta utilitat replica la lògica de `/handicap/calendari` per resoldre
 * l'origen del slot pendent ("Guanyador W1.1", "Perdedor L2.3" o, si no es pot
 * determinar, "Per determinar") i retorna un mapa
 * `calendari_partida_id → etiquetes dels dos jugadors`.
 *
 * L'alineació slot1↔jugador1 / slot2↔jugador2 és la que escriu
 * `handicap-schedule-persist.ts` en sincronitzar el bracket amb el calendari.
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import { buildMatchCodeMap, buildSlotSourceMap } from '$lib/utils/handicap-types';
import { formatarNomJugadorParts } from '$lib/utils/playerUtils';

export interface HandicapCalendarLabels {
	/** Nom real del jugador 1 si està resolt; si no, l'origen ("Guanyador W1.1"). */
	player1: string;
	/** Nom real del jugador 2 si està resolt; si no, l'origen ("Perdedor L2.3"). */
	player2: string;
	/** True si el slot 1 té un participant real assignat. */
	player1Resolved: boolean;
	/** True si el slot 2 té un participant real assignat. */
	player2Resolved: boolean;
	/** True només quan els dos jugadors són reals (data definitiva). */
	playersResolved: boolean;
}

/**
 * Donat un conjunt d'events d'hàndicap, retorna un mapa
 * `calendari_partida_id → HandicapCalendarLabels`. Els slots no resolts es
 * mostren amb el seu origen en comptes de quedar buits.
 *
 * Retorna un mapa buit si no hi ha cap event d'hàndicap o cap partida lligada
 * al calendari.
 */
export async function loadHandicapCalendarLabels(
	client: SupabaseClient,
	eventIds: string[]
): Promise<Map<string, HandicapCalendarLabels>> {
	const out = new Map<string, HandicapCalendarLabels>();
	const ids = [...new Set(eventIds.filter(Boolean))];
	if (ids.length === 0) return out;

	const { data: rawMatches } = await client
		.from('handicap_matches')
		.select(
			'id, slot1_id, slot2_id, calendari_partida_id, winner_slot_dest_id, loser_slot_dest_id'
		)
		.in('event_id', ids)
		.neq('estat', 'bye')
		.not('calendari_partida_id', 'is', null);

	if (!rawMatches || rawMatches.length === 0) return out;

	const slotIds = rawMatches.flatMap((m: any) => [m.slot1_id, m.slot2_id]).filter(Boolean);
	const { data: slots } = await client
		.from('handicap_bracket_slots')
		.select('id, bracket_type, ronda, posicio, participant_id')
		.in('id', slotIds);
	const slotMap = new Map((slots ?? []).map((s: any) => [s.id as string, s]));

	// Noms reals dels participants ja resolts (FK directe soci_numero → socis).
	const partIds = [
		...new Set(
			(slots ?? [])
				.filter((s: any) => s.participant_id)
				.map((s: any) => s.participant_id as string)
		)
	];
	const nameMap = new Map<string, string>();
	if (partIds.length > 0) {
		const { data: parts } = await client
			.from('handicap_participants')
			.select('id, socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
			.in('id', partIds);
		for (const p of parts ?? []) {
			const s = Array.isArray((p as any).socis) ? (p as any).socis[0] : (p as any).socis;
			nameMap.set((p as any).id as string, s ? formatarNomJugadorParts(s.nom, s.cognoms) || '?' : '?');
		}
	}

	// Codis de match (W1.1, L2.3, GF1) + origen de cada slot pendent.
	const codeInputs = rawMatches.map((m: any) => {
		const s1: any = slotMap.get(m.slot1_id);
		return {
			id: m.id as string,
			bracket_type: (s1?.bracket_type ?? 'winners') as string,
			ronda: (s1?.ronda ?? 1) as number,
			matchPos: s1 ? Math.ceil((s1.posicio as number) / 2) : 0
		};
	});
	const codeMap = buildMatchCodeMap(codeInputs);
	const slotSourceMap = buildSlotSourceMap(
		rawMatches.map((m: any) => ({
			id: m.id as string,
			winner_slot_dest_id: m.winner_slot_dest_id as string | null,
			loser_slot_dest_id: m.loser_slot_dest_id as string | null
		})),
		codeMap
	);
	const sourceLabel = (slotId: string): string => {
		const src = slotSourceMap.get(slotId);
		return src ? `${src.role} ${src.code}` : 'Per determinar';
	};

	for (const m of rawMatches as any[]) {
		const s1: any = slotMap.get(m.slot1_id);
		const s2: any = slotMap.get(m.slot2_id);
		if (!s1 || !s2) continue;
		const p1Resolved = !!s1.participant_id;
		const p2Resolved = !!s2.participant_id;
		out.set(m.calendari_partida_id as string, {
			player1: p1Resolved ? nameMap.get(s1.participant_id) ?? '?' : sourceLabel(s1.id),
			player2: p2Resolved ? nameMap.get(s2.participant_id) ?? '?' : sourceLabel(s2.id),
			player1Resolved: p1Resolved,
			player2Resolved: p2Resolved,
			playersResolved: p1Resolved && p2Resolved
		});
	}
	return out;
}
