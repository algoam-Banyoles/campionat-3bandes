/**
 * Insereix un bracket d'eliminació doble a la BD.
 *
 * La taula handicap_bracket_slots té una FK circular:
 *   slots.source_match_id → matches
 *   matches.slot1_id / slot2_id → slots
 *
 * Per trencar el cicle, la inserció es fa en 3 passos:
 *   1. INSERT slots amb source_match_id = NULL
 *   2. INSERT matches (ja existeixen els slots referenciats)
 *   3. UPDATE slots per posar el source_match_id correcte
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import type { BracketResult } from './handicap-bracket-generator';

export async function insertBracketToDb(
	supabase: SupabaseClient,
	result: BracketResult
): Promise<void> {
	// 1. Insertar slots sense source_match_id (evita la FK circular)
	const slotsWithoutSource = result.slots.map((s) => ({ ...s, source_match_id: null }));
	const { error: slotErr } = await supabase
		.from('handicap_bracket_slots')
		.insert(slotsWithoutSource);
	if (slotErr) throw slotErr;

	// 2. Insertar matches (els slots ja existeixen → FK vàlida)
	const { error: matchErr } = await supabase.from('handicap_matches').insert(result.matches);
	if (matchErr) throw matchErr;

	// 3. UPDATE slots que tenen source_match_id (ara els matches existeixen → FK vàlida)
	const slotsToUpdate = result.slots.filter((s) => s.source_match_id !== null);
	if (slotsToUpdate.length > 0) {
		const updateResults = await Promise.all(
			slotsToUpdate.map((s) =>
				supabase
					.from('handicap_bracket_slots')
					.update({ source_match_id: s.source_match_id })
					.eq('id', s.id)
			)
		);
		const updateErr = updateResults.find((r) => r.error)?.error;
		if (updateErr) throw updateErr;
	}
}
