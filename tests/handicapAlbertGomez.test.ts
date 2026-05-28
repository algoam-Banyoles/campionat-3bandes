/**
 * Test directe del cas Albert Gómez: dada real de producció.
 * - data_inici 2026-06-01, data_fi 2026-07-03
 * - Albert a slot W1.posicio=1 amb restricció "1 de juny no"
 * - Ibáñez a slot W1.posicio=2 sense restriccions
 *
 * Reprodueix exactament les crides que fa handicap-schedule-persist.ts
 * per detectar si encara queda algun camí pel qual June 1 escapi.
 */
import { describe, expect, it } from 'vitest';
import { preSchedulingForBracket } from '../src/lib/utils/handicap-pre-scheduler';
import { parseRestriccionsText } from '../src/lib/utils/handicap-schedule-persist';

describe('Albert Gómez — cas real producció', () => {
	it('no programa Albert (1 juny no) ni el dia 1 de juny', () => {
		const dataInici = new Date('2026-06-01'); // tal com arriba de la DB
		const dataFi = new Date('2026-07-03');

		// Slots reals (només R1 W1 mínim per al cas)
		const slots = [
			{ id: 'slot-w11-p1', bracket_type: 'winners' as const, ronda: 1, posicio: 1, participant_id: 'albert' },
			{ id: 'slot-w11-p2', bracket_type: 'winners' as const, ronda: 1, posicio: 2, participant_id: 'ibanez' },
			// Necessitem successors perquè els nivells topològics tinguin sentit:
			{ id: 'slot-w2', bracket_type: 'winners' as const, ronda: 2, posicio: 1, participant_id: null },
			{ id: 'slot-l1', bracket_type: 'losers' as const, ronda: 1, posicio: 1, participant_id: null }
		];
		const matches = [
			{
				id: 'm-w11',
				slot1_id: 'slot-w11-p1',
				slot2_id: 'slot-w11-p2',
				winner_slot_dest_id: 'slot-w2',
				loser_slot_dest_id: 'slot-l1',
				estat: 'programada'
			}
		];

		const parsed = parseRestriccionsText('1 de juny no', 2026);
		expect(parsed.diesNoDisponibles.length).toBe(1);
		const dia1 = parsed.diesNoDisponibles[0];
		expect(dia1.getDate()).toBe(1);
		expect(dia1.getMonth()).toBe(5);

		const availabilities = new Map([
			['albert', {
				preferenciesDies: ['dl', 'dt', 'dc', 'dj', 'dv'],
				preferenciesHores: ['18:00', '19:00'],
				diesNoDisponibles: parsed.diesNoDisponibles
			}],
			['ibanez', {
				preferenciesDies: ['dl', 'dt', 'dc', 'dj', 'dv'],
				preferenciesHores: ['18:00', '19:00']
			}]
		]);

		const scheduled = preSchedulingForBracket(slots, matches, {
			dataInici,
			dataFi,
			horesEstandard: ['18:00', '19:00'],
			billars: 3,
			availabilities
		});

		const sm = scheduled.get('m-w11');
		expect(sm).toBeDefined();
		const yyyy = sm!.dataProgramada.getFullYear();
		const mm = String(sm!.dataProgramada.getMonth() + 1).padStart(2, '0');
		const dd = String(sm!.dataProgramada.getDate()).padStart(2, '0');
		const isoLocal = `${yyyy}-${mm}-${dd}`;
		console.log(`Albert match programat: ${isoLocal} ${sm!.horaInici} B${sm!.taulaAssignada}`);
		expect(isoLocal).not.toBe('2026-06-01');
	});
});
