/**
 * Validació d'integritat d'un bracket de doble eliminació.
 * Comprova que les relacions entre slots i matches siguin consistents.
 */

export interface ValidationResult {
	valid: boolean;
	errors: string[];
	warnings: string[];
}

interface SlotInput {
	id: string;
	event_id: string;
	bracket_type: 'winners' | 'losers' | 'grand_final';
	ronda: number;
	posicio: number;
	participant_id: string | null;
	is_bye: boolean;
	source_match_id: string | null;
}

interface MatchInput {
	id: string;
	event_id: string;
	slot1_id: string;
	slot2_id: string;
	winner_slot_dest_id: string | null;
	loser_slot_dest_id: string | null;
	estat: string;
	guanyador_participant_id: string | null;
}

function isPowerOfTwo(n: number): boolean {
	return n > 0 && (n & (n - 1)) === 0;
}

function nextPow2(n: number): number {
	if (n <= 1) return 1;
	let p = 1;
	while (p < n) p <<= 1;
	return p;
}

export function validateBracket(
	slots: SlotInput[],
	matches: MatchInput[],
	participantCount: number
): ValidationResult {
	const errors: string[] = [];
	const warnings: string[] = [];

	const slotIds = new Set(slots.map((s) => s.id));
	const matchIds = new Set(matches.map((m) => m.id));

	// ── 1. No duplicats (bracket_type, ronda, posicio) ───────────────────────
	const slotKeys = new Set<string>();
	for (const s of slots) {
		const key = `${s.bracket_type}:${s.ronda}:${s.posicio}`;
		if (slotKeys.has(key)) {
			errors.push(`Slot duplicat: (${s.bracket_type}, ronda ${s.ronda}, posicio ${s.posicio})`);
		}
		slotKeys.add(key);
	}

	// ── 2. Cada match referencia slots vàlids ─────────────────────────────────
	for (const m of matches) {
		if (!slotIds.has(m.slot1_id)) {
			errors.push(`Match ${m.id}: slot1_id "${m.slot1_id}" no existeix`);
		}
		if (!slotIds.has(m.slot2_id)) {
			errors.push(`Match ${m.id}: slot2_id "${m.slot2_id}" no existeix`);
		}
		if (m.winner_slot_dest_id && !slotIds.has(m.winner_slot_dest_id)) {
			errors.push(`Match ${m.id}: winner_slot_dest_id "${m.winner_slot_dest_id}" no existeix`);
		}
		if (m.loser_slot_dest_id && !slotIds.has(m.loser_slot_dest_id)) {
			errors.push(`Match ${m.id}: loser_slot_dest_id "${m.loser_slot_dest_id}" no existeix`);
		}
		if (m.guanyador_participant_id) {
			const s1 = slots.find((s) => s.id === m.slot1_id);
			const s2 = slots.find((s) => s.id === m.slot2_id);
			const validPids = [s1?.participant_id, s2?.participant_id].filter(Boolean);
			if (!validPids.includes(m.guanyador_participant_id)) {
				errors.push(
					`Match ${m.id}: guanyador_participant_id no coincideix amb cap dels dos slots`
				);
			}
		}
	}

	// ── 3. No cicles: la destinació winner ha de ser de ronda superior ────────
	const slotById = new Map(slots.map((s) => [s.id, s]));
	for (const m of matches) {
		const s1 = slotById.get(m.slot1_id);
		if (!s1 || !m.winner_slot_dest_id) continue;
		const dest = slotById.get(m.winner_slot_dest_id);
		if (!dest) continue;
		// Dins el mateix bracket_type, la ronda de destí ha de ser > ronda origen
		// (excepció: winners → grand_final és un canvi de bracket_type)
		if (dest.bracket_type === s1.bracket_type && dest.ronda <= s1.ronda) {
			errors.push(
				`Cicle detectat: match a ${s1.bracket_type} R${s1.ronda} té winner_dest a R${dest.ronda} (no avança)`
			);
		}
	}

	// ── 4. Gran Final: R1 ha de tenir exactament 2 slots ─────────────────────
	const gfSlots = slots.filter((s) => s.bracket_type === 'grand_final');
	const gfR1Slots = gfSlots.filter((s) => s.ronda === 1);
	const gfR2Slots = gfSlots.filter((s) => s.ronda === 2);

	if (gfR1Slots.length !== 2) {
		errors.push(
			`Gran Final R1 ha de tenir exactament 2 slots, però en té ${gfR1Slots.length}`
		);
	}
	// GF-R2 (reset match) és opcional si no cal, però si existeix ha de tenir 2
	if (gfR2Slots.length > 0 && gfR2Slots.length !== 2) {
		errors.push(
			`Gran Final R2 (reset) ha de tenir 0 o 2 slots, però en té ${gfR2Slots.length}`
		);
	}

	// ── 5. GF-R1 rep exactament un guanyador del bracket winners i un del losers
	if (gfR1Slots.length === 2) {
		// Els source_match_id dels GF slots han de ser matches d'un bracket diferent cadascun
		const gfR1Sources = gfR1Slots
			.map((s) => s.source_match_id)
			.filter(Boolean) as string[];

		if (gfR1Sources.length > 0) {
			// Verificar que un ve de winners i l'altre de losers (via els slots dels matches)
			const sourceMatches = matches.filter((m) => gfR1Sources.includes(m.id));
			const sourceBrackets = sourceMatches
				.map((m) => slotById.get(m.slot1_id)?.bracket_type)
				.filter(Boolean);
			const hasWinners = sourceBrackets.includes('winners');
			const hasLosers = sourceBrackets.includes('losers');
			if (gfR1Sources.length === 2 && (!hasWinners || !hasLosers)) {
				warnings.push(
					'Gran Final R1: no es pot confirmar que un slot ve de winners i l\'altre de losers'
				);
			}
		}
	}

	// ── 6. Nombre de rondes consistent amb el nombre de jugadors ─────────────
	if (participantCount >= 2) {
		const bracketSize = nextPow2(participantCount);
		const k = Math.log2(bracketSize); // rondes del winners bracket

		const wSlots = slots.filter((s) => s.bracket_type === 'winners');
		const lSlots = slots.filter((s) => s.bracket_type === 'losers');

		const maxWRound = wSlots.length > 0 ? Math.max(...wSlots.map((s) => s.ronda)) : 0;
		const maxLRound = lSlots.length > 0 ? Math.max(...lSlots.map((s) => s.ronda)) : 0;

		if (maxWRound !== k) {
			errors.push(
				`Bracket winners hauria de tenir ${k} rondes per a ${participantCount} jugadors, però en té ${maxWRound}`
			);
		}

		const expectedLRounds = 2 * (k - 1);
		if (maxLRound !== expectedLRounds && expectedLRounds > 0) {
			errors.push(
				`Bracket losers hauria de tenir ${expectedLRounds} rondes, però en té ${maxLRound}`
			);
		}

		// Nombre total de matches (excloent byes) = 2*bracketSize - 1
		const nonByeMatches = matches.filter((m) => m.estat !== 'bye').length;
		const expectedMatches = 2 * bracketSize - 1;
		// Inclou el reset match de la GF, però és opcional; avisa si molt diferent
		if (nonByeMatches < expectedMatches - 1 || nonByeMatches > expectedMatches + 1) {
			warnings.push(
				`S'esperaven ~${expectedMatches} partides per a bracketSize=${bracketSize}, però n'hi ha ${nonByeMatches}`
			);
		}
	}

	// ── 7. source_match_id dels slots apunten a matches vàlids ───────────────
	for (const s of slots) {
		if (s.source_match_id && !matchIds.has(s.source_match_id)) {
			errors.push(
				`Slot ${s.id} (${s.bracket_type} R${s.ronda} P${s.posicio}): source_match_id "${s.source_match_id}" no existeix`
			);
		}
	}

	return {
		valid: errors.length === 0,
		errors,
		warnings
	};
}
