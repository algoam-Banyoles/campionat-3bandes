/**
 * Detecció d'incompatibilitats horàries entre matches programats i les
 * preferències dels jugadors, i proposta de slots alternatius.
 *
 * Una partida és INCOMPATIBLE quan, per algun dels seus dos participants,
 * la seva `preferencies_dies` és no buida i NO inclou el codi de dia
 * (dl..dv) del slot, o la seva `preferencies_hores` és no buida i NO
 * inclou l'hora del slot. Les preferències buides es consideren
 * "disponible sempre".
 */

import type { ParticipantAvailability, OccupiedSlot } from './handicap-scheduler';

const DIES_SETMANA = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];

export interface CompatibilityMatchInput {
	matchId: string;
	matchCode: string;
	player1Name: string;
	player2Name: string;
	player1: ParticipantAvailability;
	player2: ParticipantAvailability;
	data: string; // 'YYYY-MM-DD' actual del slot programat
	hora: string; // 'HH:MM'
	taula: number;
}

export interface AlternativeSlot {
	data: string;
	hora: string;
	taula: number;
}

export interface CompatibilityIssue {
	matchId: string;
	matchCode: string;
	player1Name: string;
	player2Name: string;
	current: { data: string; hora: string; taula: number };
	/** Motiu (text humà). */
	motiu: string;
	/** Slots alternatius proposats, ordenats per proximitat. */
	alternatives: AlternativeSlot[];
}

export interface CompatibilityCheckOptions {
	dataInici: string; // 'YYYY-MM-DD'
	dataFi: string;
	horesEstandard: string[]; // ex ['18:00', '19:00']
	horarisExtra?: { franja: string; dies: string[] } | null;
	billars?: number;
	diesActius?: string[];
	diesBloquejats?: string[]; // 'YYYY-MM-DD'
	occupiedSlots: OccupiedSlot[];
	maxAlternatives?: number;
}

function pad(n: number): string {
	return String(n).padStart(2, '0');
}
function ymd(d: Date): string {
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
function parseDate(s: string): Date {
	const [y, m, d] = s.split('-').map(Number);
	return new Date(y, m - 1, d);
}
function diaCodi(d: Date): string {
	return DIES_SETMANA[d.getDay()];
}

function isPlayerAvail(p: ParticipantAvailability, dayCode: string, hora: string): boolean {
	const diaOk = p.preferencies_dies.length === 0 || p.preferencies_dies.includes(dayCode);
	const horaOk = p.preferencies_hores.length === 0 || p.preferencies_hores.includes(hora);
	return diaOk && horaOk;
}

/** Diferència en dies absoluta entre dues dates ISO. */
function dayDiff(a: string, b: string): number {
	const da = parseDate(a).getTime();
	const db = parseDate(b).getTime();
	return Math.abs(Math.round((da - db) / (1000 * 60 * 60 * 24)));
}

export function checkCompatibility(
	matches: CompatibilityMatchInput[],
	options: CompatibilityCheckOptions
): CompatibilityIssue[] {
	const billars = options.billars ?? 3;
	const diesActius = options.diesActius ?? ['dl', 'dt', 'dc', 'dj', 'dv'];
	const bloquejats = new Set(options.diesBloquejats ?? []);
	const maxAlt = options.maxAlternatives ?? 3;

	// Construïm mapa de slots ocupats per (data|hora|taula) i de jugadors busy
	// per (data|hora) (en qualsevol taula).
	const occBillar = new Set<string>();
	const occJugador = new Map<string, Set<string>>();
	for (const s of options.occupiedSlots) {
		occBillar.add(`${s.data}|${s.hora}|${s.taula}`);
		if (s.participantIds && s.participantIds.length > 0) {
			const key = `${s.data}|${s.hora}`;
			let set = occJugador.get(key);
			if (!set) { set = new Set(); occJugador.set(key, set); }
			for (const pid of s.participantIds) set.add(pid);
		}
	}

	// Genera la llista cronològica de slots vàlids del període.
	const allSlots: Array<{ data: string; hora: string; taula: number; dayCode: string }> = [];
	const dStart = parseDate(options.dataInici);
	const dEnd = parseDate(options.dataFi);
	for (let d = new Date(dStart); d <= dEnd; d.setDate(d.getDate() + 1)) {
		const codi = diaCodi(d);
		if (!diesActius.includes(codi)) continue;
		const data = ymd(d);
		if (bloquejats.has(data)) continue;
		const hores = [...options.horesEstandard];
		if (options.horarisExtra && options.horarisExtra.dies.includes(codi)) {
			hores.unshift(options.horarisExtra.franja);
		}
		for (const h of hores) {
			for (let b = 1; b <= billars; b++) {
				allSlots.push({ data, hora: h, taula: b, dayCode: codi });
			}
		}
	}

	const issues: CompatibilityIssue[] = [];
	for (const m of matches) {
		const dayCode = diaCodi(parseDate(m.data));
		const p1Ok = isPlayerAvail(m.player1, dayCode, m.hora);
		const p2Ok = isPlayerAvail(m.player2, dayCode, m.hora);
		if (p1Ok && p2Ok) continue;

		const motius: string[] = [];
		if (!p1Ok) motius.push(`${m.player1Name} no pot ${dayCode}/${m.hora}`);
		if (!p2Ok) motius.push(`${m.player2Name} no pot ${dayCode}/${m.hora}`);

		// Cerca alternatives: slots on tots dos jugadors són disponibles,
		// el billar no està ocupat i cap dels dos juga ja en aquesta franja
		// (a qualsevol taula), excloent el propi slot actual.
		const candidates: AlternativeSlot[] = [];
		for (const s of allSlots) {
			if (s.data === m.data && s.hora === m.hora && s.taula === m.taula) continue;
			if (!isPlayerAvail(m.player1, s.dayCode, s.hora)) continue;
			if (!isPlayerAvail(m.player2, s.dayCode, s.hora)) continue;
			if (occBillar.has(`${s.data}|${s.hora}|${s.taula}`)) continue;
			const busy = occJugador.get(`${s.data}|${s.hora}`);
			if (busy && (busy.has(m.player1.participant_id) || busy.has(m.player2.participant_id))) continue;
			candidates.push({ data: s.data, hora: s.hora, taula: s.taula });
		}
		// Ordena per proximitat al dia actual; trenca empats per hora i billar
		candidates.sort((a, b) => {
			const da = dayDiff(a.data, m.data) - dayDiff(b.data, m.data);
			if (da !== 0) return da;
			if (a.data !== b.data) return a.data.localeCompare(b.data);
			if (a.hora !== b.hora) return a.hora.localeCompare(b.hora);
			return a.taula - b.taula;
		});

		issues.push({
			matchId: m.matchId,
			matchCode: m.matchCode,
			player1Name: m.player1Name,
			player2Name: m.player2Name,
			current: { data: m.data, hora: m.hora, taula: m.taula },
			motiu: motius.join('; '),
			alternatives: candidates.slice(0, maxAlt)
		});
	}

	return issues;
}
