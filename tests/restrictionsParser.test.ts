import { describe, it, expect } from 'vitest';
import { parseRestriccionsText } from '../src/lib/utils/handicap-schedule-persist';

// Format LOCAL (no toISOString) per evitar offset de timezone en zones positives.
function localDayKey(d: Date): string {
	return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

describe('parseRestriccionsText', () => {
	it('parseja "1,2,3 i 5 de juny no"', () => {
		const r = parseRestriccionsText('1,2,3 i 5 de juny no', 2026);
		const iso = r.diesNoDisponibles.map(localDayKey).sort();
		expect(iso).toEqual(['2026-06-01', '2026-06-02', '2026-06-03', '2026-06-05']);
	});

	it('parseja "només pot a partir del 9 de juny"', () => {
		const r = parseRestriccionsText('només pot a partir del 9 de juny', 2026);
		expect(r.dataDisponibleDes && localDayKey(r.dataDisponibleDes)).toBe('2026-06-09');
	});

	it('text buit/null no peta', () => {
		expect(parseRestriccionsText(null, 2026).diesNoDisponibles).toEqual([]);
		expect(parseRestriccionsText('', 2026).diesNoDisponibles).toEqual([]);
	});

	it('parseja un sol dia "el 12 d\'agost no"', () => {
		const r = parseRestriccionsText("no pot el 12 d'agost", 2026);
		const iso = r.diesNoDisponibles.map(localDayKey);
		expect(iso).toContain('2026-08-12');
	});
});
