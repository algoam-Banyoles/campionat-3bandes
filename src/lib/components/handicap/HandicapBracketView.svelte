<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { MatchView } from '$lib/utils/handicap-types';
	import { buildMatchCodeMap, buildLoserDestCodeMap, buildSlotSourceMap } from '$lib/utils/handicap-types';
	import {
		deadlineStatus,
		formatDeadlineShort,
		todayLocalIso,
		type DeadlineStatus
	} from '$lib/utils/handicap-deadlines';

	const dispatch = createEventDispatcher<{ matchclick: MatchView }>();

	// ── Props ─────────────────────────────────────────────────────────────────

	export let matchViews: MatchView[] = [];
	export let filter: 'all' | 'winners' | 'losers' | 'grand_final' = 'all';
	export let searchTerm: string = '';
	/** Si el torneig ha acabat, ID del campió per mostrar la corona */
	export let championParticipantId: string | null = null;
	/** Sistema de puntuació: 'distancia' | 'percentatge' */
	export let sistemaPuntuacio: string = 'distancia';
	/** Si true, col·lapsa les rondes ja completes en "stubs" també a escriptori
	 *  (a mòbil ja es col·lapsen sempre). Redueix targetes i connectors al quadre. */
	export let compactCompleted: boolean = false;

	/** Retorna el percentatge formatat (0 decimals) d'una puntuació sobre distància. */
	function pct(caramboles: number | null, distancia: number | null): string {
		if (!caramboles || !distancia) return '—';
		return Math.round((caramboles / distancia) * 100).toString();
	}

	// ── Constants ─────────────────────────────────────────────────────────────

	const MATCH_H = 82; // px – alçada de la targeta (header 18 + P1 + div + P2 + info 17)
	const SLOT_H = 108; // px – unitat base (MATCH_H + 26px per etiqueta sota)
	const COL_W = 155; // px – amplada de cada columna de ronda
	const STUB_W = 64; // px – amplada d'una columna col·lapsada (stub) a mòbil
	const GAP = 22; // px – separació entre columnes (on van els connectors)

	// ── Detecció de mòbil ─────────────────────────────────────────────────────

	let viewportW = 1200;
	$: isMobile = viewportW > 0 && viewportW < 768;

	// Conjunts de rondes que l'usuari ha expandit manualment (override del col·lapse automàtic)
	let expandedW = new Set<number>();
	let expandedL = new Set<number>();
	let expandedGF = new Set<number>();

	function toggleW(r: number) {
		expandedW = expandedW.has(r)
			? new Set([...expandedW].filter((x) => x !== r))
			: new Set([...expandedW, r]);
	}
	function toggleL(r: number) {
		expandedL = expandedL.has(r)
			? new Set([...expandedL].filter((x) => x !== r))
			: new Set([...expandedL, r]);
	}
	function toggleGF(r: number) {
		expandedGF = expandedGF.has(r)
			? new Set([...expandedGF].filter((x) => x !== r))
			: new Set([...expandedGF, r]);
	}

	// ── Computed ──────────────────────────────────────────────────────────────

	$: wMatches = matchViews.filter((m) => m.bracket_type === 'winners');
	$: lMatches = matchViews.filter((m) => m.bracket_type === 'losers');
	$: gfMatches = matchViews.filter((m) => m.bracket_type === 'grand_final');

	$: wRounds = [...new Set(wMatches.map((m) => m.ronda))].sort((a, b) => a - b);
	$: lRounds = [...new Set(lMatches.map((m) => m.ronda))].sort((a, b) => a - b);
	$: gfRounds = [...new Set(gfMatches.map((m) => m.ronda))].sort((a, b) => a - b);

	$: numR1 = wMatches.filter((m) => m.ronda === 1).length; // partides R1 (= size/2)
	$: totalWH = Math.max(numR1 * SLOT_H, 2 * SLOT_H); // alçada bracket guanyadors + GF
	$: totalLH = Math.max((numR1 / 2) * SLOT_H, 2 * SLOT_H); // alçada bracket perdedors

	// Una ronda és "completa" quan totes les seves partides no-bye estan jugades/walkover.
	function isRoundComplete(matches: MatchView[]): boolean {
		const nonBye = matches.filter((m) => m.estat !== 'bye');
		return nonBye.length > 0 && nonBye.every((m) => m.estat === 'jugada' || m.estat === 'walkover');
	}

	// Rondes col·lapsades: només a mòbil, rondes completes que l'usuari NO ha expandit explícitament.
	$: hiddenW = new Set(
		(isMobile || compactCompleted)
			? wRounds.filter((r) => isRoundComplete(getMatchesBT('winners', r)) && !expandedW.has(r))
			: []
	);
	$: hiddenL = new Set(
		(isMobile || compactCompleted)
			? lRounds.filter((r) => isRoundComplete(getMatchesBT('losers', r)) && !expandedL.has(r))
			: []
	);
	$: hiddenGF = new Set(
		(isMobile || compactCompleted)
			? gfRounds.filter((r) => isRoundComplete(getMatchesBT('grand_final', r)) && !expandedGF.has(r))
			: []
	);

	// Layout amb amplades variables (stubs per a rondes col·lapsades)
	$: wgfLayout = (() => {
		const wList: Array<{ r: number; x: number; w: number; hidden: boolean }> = [];
		const gfList: Array<{ r: number; x: number; w: number; hidden: boolean }> = [];
		let x = 0;
		for (const r of wRounds) {
			const h = hiddenW.has(r);
			const w = h ? STUB_W : COL_W;
			wList.push({ r, x, w, hidden: h });
			x += w + GAP;
		}
		for (const r of gfRounds) {
			const h = hiddenGF.has(r);
			const w = h ? STUB_W : COL_W;
			gfList.push({ r, x, w, hidden: h });
			x += w + GAP;
		}
		return { wList, gfList, totalW: x - GAP + COL_W };
	})();

	$: lLayout = (() => {
		const list: Array<{ r: number; x: number; w: number; hidden: boolean }> = [];
		let x = 0;
		for (const r of lRounds) {
			const h = hiddenL.has(r);
			const w = h ? STUB_W : COL_W;
			list.push({ r, x, w, hidden: h });
			x += w + GAP;
		}
		return { list, totalW: x - GAP + COL_W };
	})();

	$: wRoundX = new Map(wgfLayout.wList.map((it) => [it.r, it]));
	$: gfRoundX = new Map(wgfLayout.gfList.map((it) => [it.r, it]));
	$: lRoundX = new Map(lLayout.list.map((it) => [it.r, it]));

	$: wSectionW = wgfLayout.totalW;
	$: lSectionW = lLayout.totalW;

	// ── Helpers de posicionament ───────────────────────────────────────────────

	/**
	 * Posició top d'una partida dins la seva columna (bracket winners).
	 * r = ronda (1-based), idx = posició dins la ronda (1-based).
	 */
	function matchTopW(r: number, idx: number): number {
		const factor = Math.pow(2, r - 1);
		return (idx - 0.5) * factor * SLOT_H - MATCH_H / 2;
	}

	/** Posició top per a la Gran Final (centrada verticalment). */
	function matchTopGF(): number {
		return totalWH / 2 - MATCH_H / 2;
	}

	/**
	 * Posició top per al bracket losers.
	 * lr = ronda losers (1-based), idx = posició (1-based).
	 */
	function matchTopL(lr: number, idx: number): number {
		const phase = Math.ceil(lr / 2);
		const factor = Math.pow(2, phase - 1);
		return (idx - 0.5) * factor * SLOT_H - MATCH_H / 2;
	}

	// ── Línies de connector SVG (bracket guanyadors) ──────────────────────────

	$: wConnectors = buildWinnersConnectors(wRounds, hiddenW, hiddenGF, wRoundX, gfRoundX, matchViews, gfRounds, totalWH);

	// ── Línies de connector SVG (bracket perdedors) ───────────────────────────

	$: lConnectors = buildLosersConnectors(lRounds, hiddenL, lRoundX, matchViews);

	function buildLosersConnectors(
		_lRounds: number[], _hiddenL: Set<number>, _lRoundX: Map<number, { x: number; w: number; hidden: boolean }>, _matchViews: MatchView[]
	): Array<{ x1: number; y1: number; x2: number; y2: number; won: boolean }> {
		const lines: Array<{ x1: number; y1: number; x2: number; y2: number; won: boolean }> = [];
		if (lRounds.length < 2) return lines;

		// Mapa slotId → match per al bracket perdedors
		const slotToLMatch = new Map<string, MatchView>();
		for (const m of lMatches) {
			slotToLMatch.set(m.slot1.id, m);
			slotToLMatch.set(m.slot2.id, m);
		}

		// Agrupa les partides font per la seva partida destí (dins losers)
		const destGroups = new Map<string, MatchView[]>();
		for (const m of lMatches) {
			if (!m.winner_slot_dest_id) continue;
			const dest = slotToLMatch.get(m.winner_slot_dest_id);
			if (!dest) continue; // destí fora del bracket perdedors (GF)
			const group = destGroups.get(dest.id) ?? [];
			group.push(m);
			destGroups.set(dest.id, group);
		}

		for (const [destId, sources] of destGroups) {
			const destMatch = lMatches.find((m) => m.id === destId)!;
			// Saltem connector si la ronda destí està col·lapsada
			if (hiddenL.has(destMatch.ronda)) continue;
			const destLayout = lRoundX.get(destMatch.ronda);
			if (!destLayout) continue;
			const destColX = destLayout.x;
			const destY = matchTopL(destMatch.ronda, destMatch.matchPos) + MATCH_H / 2;

			if (sources.length === 2) {
				// Dues partides s'uneixen (ronda de consolidació) → estil bracket
				const [m1, m2] = [...sources].sort((a, b) => a.matchPos - b.matchPos);
				if (hiddenL.has(m1.ronda)) continue; // si l'origen és col·lapsat, salta
				const srcLayout = lRoundX.get(m1.ronda);
				if (!srcLayout) continue;
				const srcColX = srcLayout.x;
				const srcRight = srcColX + srcLayout.w;
				const midX = srcRight + (destColX - srcRight) / 2;

				const y1 = matchTopL(m1.ronda, m1.matchPos) + MATCH_H / 2;
				const y2 = matchTopL(m2.ronda, m2.matchPos) + MATCH_H / 2;
				const won1 = m1.estat === 'jugada' || m1.estat === 'walkover' || m1.estat === 'bye';
				const won2 = m2.estat === 'jugada' || m2.estat === 'walkover' || m2.estat === 'bye';
				const bothWon = won1 && won2;

				lines.push({ x1: srcRight, y1, x2: midX, y2: y1, won: won1 });
				lines.push({ x1: srcRight, y1: y2, x2: midX, y2, won: won2 });
				lines.push({ x1: midX, y1, x2: midX, y2, won: bothWon });
				lines.push({ x1: midX, y1: destY, x2: destColX, y2: destY, won: bothWon });
			} else if (sources.length === 1) {
				// Una sola partida avança (l'altra plaça ve del bracket guanyadors) → L-shape
				const m = sources[0];
				if (hiddenL.has(m.ronda)) continue;
				const srcLayout = lRoundX.get(m.ronda);
				if (!srcLayout) continue;
				const srcColX = srcLayout.x;
				const srcRight = srcColX + srcLayout.w;
				const midX = srcRight + (destColX - srcRight) / 2;
				const srcY = matchTopL(m.ronda, m.matchPos) + MATCH_H / 2;
				const won = m.estat === 'jugada' || m.estat === 'walkover' || m.estat === 'bye';

				if (Math.abs(srcY - destY) < 1) {
					lines.push({ x1: srcRight, y1: srcY, x2: destColX, y2: srcY, won });
				} else {
					lines.push({ x1: srcRight, y1: srcY, x2: midX, y2: srcY, won });
					lines.push({ x1: midX, y1: srcY, x2: midX, y2: destY, won });
					lines.push({ x1: midX, y1: destY, x2: destColX, y2: destY, won });
				}
			}
		}

		return lines;
	}

	function buildWinnersConnectors(
		_wRounds: number[], _hiddenW: Set<number>, _hiddenGF: Set<number>,
		_wRoundX: Map<number, { x: number; w: number; hidden: boolean }>,
		_gfRoundX: Map<number, { x: number; w: number; hidden: boolean }>,
		_matchViews: MatchView[], _gfRounds: number[], _totalWH: number
	): Array<{ x1: number; y1: number; x2: number; y2: number; won: boolean }> {
		const lines: Array<{ x1: number; y1: number; x2: number; y2: number; won: boolean }> = [];
		if (wRounds.length === 0) return lines;

		for (let ri = 0; ri < wRounds.length - 1; ri++) {
			const r = wRounds[ri];
			const nextR = wRounds[ri + 1];
			// Si alguna de les dues rondes adjacents està col·lapsada, no dibuixem el connector
			if (hiddenW.has(r) || hiddenW.has(nextR)) continue;

			const cur = wRoundX.get(r);
			const next = wRoundX.get(nextR);
			if (!cur || !next) continue;
			const colX = cur.x;
			const colRight = colX + cur.w;
			const nextColX = next.x;
			const midX = colRight + (nextColX - colRight) / 2;

			const roundMatches = getMatchesBT('winners', r).sort((a, b) => a.matchPos - b.matchPos);

			for (let j = 0; j < roundMatches.length; j += 2) {
				const m1 = roundMatches[j];
				const m2 = roundMatches[j + 1];
				if (!m1) continue;

				const c1y = matchTopW(r, m1.matchPos) + MATCH_H / 2;
				const won1 = m1.estat === 'jugada' || m1.estat === 'walkover' || m1.estat === 'bye';

				if (!m2) {
					lines.push({ x1: colRight, y1: c1y, x2: nextColX, y2: c1y, won: won1 });
					continue;
				}

				const c2y = matchTopW(r, m2.matchPos) + MATCH_H / 2;
				const won2 = m2.estat === 'jugada' || m2.estat === 'walkover' || m2.estat === 'bye';
				const midY = (c1y + c2y) / 2;
				const bothWon = won1 && won2;

				lines.push({ x1: colRight, y1: c1y, x2: midX, y2: c1y, won: won1 });
				lines.push({ x1: colRight, y1: c2y, x2: midX, y2: c2y, won: won2 });
				lines.push({ x1: midX, y1: c1y, x2: midX, y2: c2y, won: bothWon });
				lines.push({ x1: midX, y1: midY, x2: nextColX, y2: midY, won: bothWon });
			}
		}

		// W-Final → GF-R1 (línia horitzontal al centre)
		if (gfRounds.length > 0 && wRounds.length > 0) {
			const wFinalR = wRounds[wRounds.length - 1];
			const gfR1 = gfRounds[0];
			if (!hiddenW.has(wFinalR) && !hiddenGF.has(gfR1)) {
				const wFinal = wRoundX.get(wFinalR);
				const gf1 = gfRoundX.get(gfR1);
				if (wFinal && gf1) {
					const cy = totalWH / 2;
					const wFinalMatch = getMatchesBT('winners', wFinalR)[0];
					const won = wFinalMatch?.estat === 'jugada' || wFinalMatch?.estat === 'bye';
					lines.push({ x1: wFinal.x + wFinal.w, y1: cy, x2: gf1.x, y2: cy, won });

					// GF-R1 → GF-R2
					if (gfRounds.length > 1) {
						const gfR2 = gfRounds[1];
						if (!hiddenGF.has(gfR2)) {
							const gf2 = gfRoundX.get(gfR2);
							if (gf2) {
								const gfR1Match = getMatchesBT('grand_final', 1)[0];
								const gfWon = gfR1Match?.estat === 'jugada';
								lines.push({ x1: gf1.x + gf1.w, y1: cy, x2: gf2.x, y2: cy, won: gfWon });
							}
						}
					}
				}
			}
		}

		return lines;
	}

	// ── Utilitats de dades ────────────────────────────────────────────────────

	function getMatchesBT(bt: string, r: number): MatchView[] {
		return matchViews
			.filter((m) => m.bracket_type === bt && m.ronda === r)
			.sort((a, b) => a.matchPos - b.matchPos);
	}

	function isHighlighted(match: MatchView): boolean {
		if (!searchTerm.trim()) return false;
		const q = searchTerm.toLowerCase();
		return !!(
			match.player1?.name?.toLowerCase().includes(q) ||
			match.player2?.name?.toLowerCase().includes(q)
		);
	}

	function isWinner(match: MatchView, slot: 1 | 2): boolean {
		if (!match.guanyador_participant_id) return false;
		const pid = slot === 1 ? match.slot1.participant_id : match.slot2.participant_id;
		return pid === match.guanyador_participant_id;
	}

	function isChampionSlot(match: MatchView, slot: 1 | 2): boolean {
		if (!championParticipantId) return false;
		const pid = slot === 1 ? match.slot1.participant_id : match.slot2.participant_id;
		return pid === championParticipantId;
	}

	// ── Estils ────────────────────────────────────────────────────────────────

	function cardBorder(estat: string): string {
		switch (estat) {
			case 'jugada':
				return 'border-green-400';
			case 'programada':
				return 'border-blue-400';
			case 'walkover':
				return 'border-orange-400';
			case 'bye':
				return 'border-gray-200';
			default:
				return 'border-gray-300';
		}
	}

	function statusPill(estat: string): string {
		switch (estat) {
			case 'jugada':
				return 'bg-green-100 text-green-800';
			case 'programada':
				return 'bg-blue-100 text-blue-800';
			case 'walkover':
				return 'bg-orange-100 text-orange-800';
			default:
				return '';
		}
	}

	function statusLabel(estat: string): string {
		switch (estat) {
			case 'jugada':
				return 'Jugada';
			case 'programada':
				return 'Prog.';
			case 'walkover':
				return 'W.O.';
			case 'bye':
				return 'BYE';
			default:
				return '';
		}
	}

	function wRoundLabel(r: number): string {
		if (r === wRounds[wRounds.length - 1]) return 'Final G.';
		if (r === wRounds[wRounds.length - 2] && wRounds.length > 2) return 'Semifinals G.';
		return `G-R${r}`;
	}

	function lRoundLabel(lr: number): string {
		if (lr === lRounds[lRounds.length - 1]) return 'Final P.';
		return `P-R${lr}`;
	}

	/** Retorna "dd/mm HH:MM · Tx" per a partides amb data/hora assignada. */
	function formatMatchInfo(m: MatchView): string {
		if (!m.data_hora) return '';
		// Format: 'YYYY-MM-DD HH:MM' (sense timezone, per evitar conversions UTC)
		const [datePart, timePart] = m.data_hora.split(' ');
		if (!datePart || !timePart) return '';
		const [, month, day] = datePart.split('-');
		let s = `${day}/${month} ${timePart}`;
		if (m.taula) s += ` · B${m.taula}`;
		return s;
	}

	const today = todayLocalIso();
	function deadlineStatusFor(m: MatchView): DeadlineStatus {
		return deadlineStatus(m.dataMaximaDisputa, today, m.estat);
	}
	/** Una partida té data orientativa quan està programada però algun
	 *  dels jugadors encara no s'ha resolt (típicament R2+ abans que els
	 *  predecessors hagin acabat). La data s'haurà de confirmar quan els
	 *  jugadors es determinin. */
	function isTentative(m: MatchView): boolean {
		if (!m.data_hora) return false;
		return !m.player1 || !m.player2;
	}
	const TENTATIVE_TITLE = 'Data orientativa, a confirmar quan es determinin els jugadors';
	function deadlineLabelFor(m: MatchView): string {
		return formatDeadlineShort(m.dataMaximaDisputa);
	}
	function deadlineClassFor(m: MatchView): string {
		const st = deadlineStatusFor(m);
		if (st === 'passed') return 'hcap-deadline hcap-deadline-passed';
		if (st === 'soon') return 'hcap-deadline hcap-deadline-soon';
		if (st === 'safe') return 'hcap-deadline hcap-deadline-safe';
		return '';
	}

	$: showWinners = filter === 'all' || filter === 'winners' || filter === 'grand_final';
	$: showLosers = filter === 'all' || filter === 'losers';

	// ── Numeració i destinació del perdedor ──────────────────────────────────

	$: matchCodeMap = buildMatchCodeMap(matchViews);
	$: loserDestCodeMap = buildLoserDestCodeMap(matchViews, matchCodeMap);
	$: slotSourceMap = buildSlotSourceMap(matchViews, matchCodeMap);

	function matchCode(m: MatchView): string {
		return matchCodeMap.get(m.id) ?? '';
	}

	/** Etiqueta per a un slot pendent: "Guanyador W3", "Perdedor L5" o "Per determinar". */
	function pendingLabel(slotId: string): string {
		const src = slotSourceMap.get(slotId);
		return src ? `${src.role} ${src.code}` : 'Per determinar';
	}

	/**
	 * Un match guaranteed-bye té exactament un slot is_bye i l'altre pendent (is_bye=false, no participant).
	 * Es pre-resol automàticament; el jugador real que arribi avançarà sense jugar.
	 */
	function isGuaranteedBye(match: MatchView): boolean {
		return (
			match.estat === 'bye' &&
			((match.slot1.is_bye && !match.slot2.is_bye && match.slot2.participant_id === null) ||
				(!match.slot1.is_bye && match.slot1.participant_id === null && match.slot2.is_bye))
		);
	}

	/**
	 * Per a un match guaranteed-bye, l'etiqueta del slot pendent s'obté del winner_slot_dest
	 * (que té source_match_id re-cablat al W-Rn match real gràcies al Canvi 1 del generador).
	 */
	function guaranteedByeSourceLabel(match: MatchView): string {
		if (!match.winner_slot_dest_id) return 'Per determinar';
		const src = slotSourceMap.get(match.winner_slot_dest_id);
		return src ? `${src.role} ${src.code}` : 'Per determinar';
	}
</script>

<svelte:window bind:innerWidth={viewportW} />

<div class="hcap-bracket-root">
<!-- ── Bracket de Guanyadors + Gran Final ─────────────────────────────────── -->
{#if showWinners && wMatches.length > 0}
	<div class="mb-6 bracket-section-winners">
		<h3 class="mb-2 text-xs font-semibold uppercase tracking-wide text-gray-500">
			Bracket de Guanyadors
			{#if gfRounds.length > 0}&amp; Gran Final{/if}
		</h3>
		<div class="bracket-scroll overflow-x-auto rounded border border-gray-100 bg-white p-3 shadow-sm">
			<div class="relative" style="width: {wSectionW}px; height: {totalWH + 32}px;">
				<!-- Connector SVG -->
				<svg
					class="pointer-events-none absolute inset-0"
					width={wSectionW}
					height={totalWH + 32}
					style="top: 32px;"
				>
					{#each wConnectors as line}
						<line
							x1={line.x1}
							y1={line.y1}
							x2={line.x2}
							y2={line.y2}
							stroke={line.won ? '#86efac' : '#d1d5db'}
							stroke-width="2"
						/>
					{/each}
				</svg>

				<!-- Columnes winners -->
				{#each wgfLayout.wList as item}
					{@const r = item.r}
					{@const colX = item.x}
					{#if item.hidden}
						{@const matches = getMatchesBT('winners', r)}
						{@const nonBye = matches.filter((m) => m.estat !== 'bye')}
						<button
							type="button"
							class="hcap-stub absolute"
							on:click={() => toggleW(r)}
							style="left: {colX}px; top: 0; width: {item.w}px; height: {totalWH + 32}px;"
							title="Mostrar {wRoundLabel(r)} ({nonBye.length} jugades)"
						>
							<span class="hcap-stub-label">{wRoundLabel(r)}</span>
							<span class="hcap-stub-count">{nonBye.length} ✓</span>
							<span class="hcap-stub-cta">Mostrar</span>
						</button>
					{:else}
					<!-- Capçalera columna -->
					<div
						class="absolute text-center text-[11px] font-semibold text-gray-500"
						style="left: {colX}px; top: 0; width: {COL_W}px;"
					>
						{wRoundLabel(r)}
						{#if (isMobile || compactCompleted) && isRoundComplete(getMatchesBT('winners', r))}
							<button
								type="button"
								class="hcap-collapse-btn"
								on:click={() => toggleW(r)}
								title="Col·lapsar {wRoundLabel(r)}"
							>−</button>
						{/if}
					</div>
					<!-- Partides -->
					{#each getMatchesBT('winners', r) as match}
						<div
							class="absolute"
							style="left: {colX}px; top: {32 + matchTopW(r, match.matchPos)}px; width: {COL_W}px;"
						>
							<button
								type="button"
								on:click={() => dispatch('matchclick', match)}
								class="flex w-full flex-col overflow-hidden rounded border-2 text-left shadow-sm transition-shadow hover:shadow-md
									{cardBorder(match.estat)}
									{isHighlighted(match) ? 'ring-2 ring-yellow-400 ring-offset-1' : ''}"
								style="height: {MATCH_H}px;"
							>
								<!-- Capçalera: codi + estat -->
								<div
									class="flex shrink-0 items-center justify-between border-b border-gray-100 bg-gray-50/60 px-2"
									style="height: 18px;"
								>
									<span class="font-mono text-[10px] font-bold leading-none
										{match.estat !== 'pendent' && match.estat !== 'bye' ? 'text-gray-700' : 'text-gray-400'}"
									>{matchCode(match)}</span>
									{#if match.estat !== 'pendent' && match.estat !== 'bye'}
										<span class="rounded px-1 text-[8px] leading-tight {statusPill(match.estat)}"
											>{statusLabel(match.estat)}</span
										>
									{/if}
								</div>
								<!-- Jugador 1 -->
								<div
									class="flex min-h-0 flex-1 items-center gap-1 px-2 text-[11px] leading-none
										{isWinner(match, 1) ? 'bg-green-50 font-bold' : ''}
										{match.slot1.is_bye ? 'opacity-40' : ''}"
								>
									{#if match.player1?.seed}
										<span class="w-4 shrink-0 text-right text-[9px] text-gray-400"
											>[{match.player1.seed}]</span
										>
									{/if}
									<span class="min-w-0 flex-1 truncate {!match.slot1.is_bye && !match.player1 ? 'italic text-gray-400' : ''}">
										{match.slot1.is_bye ? 'BYE' : (match.player1?.shortName ?? match.player1?.name ?? pendingLabel(match.slot1.id))}
									</span>
									{#if !match.slot1.is_bye}
										{#if match.estat === 'jugada' && match.caramboles1 !== null}
											<span class="shrink-0 text-[9px] font-semibold {isWinner(match, 1) ? 'text-green-700' : 'text-gray-400'}"
												>{match.caramboles1}{#if match.distancia_jugador1}<span class="font-normal text-gray-400">/{match.distancia_jugador1}</span>{#if sistemaPuntuacio === 'percentatge'}<span class="font-normal text-gray-400"> ({pct(match.caramboles1, match.distancia_jugador1)}%)</span>{/if}{/if}</span
											>
										{:else if match.estat === 'walkover' && !isWinner(match, 1)}
											<span class="shrink-0 text-[9px] font-semibold text-orange-500">W.O.</span>
										{:else if match.distancia_jugador1}
											<span class="shrink-0 text-[9px] text-gray-400">{match.distancia_jugador1}c</span>
										{/if}
									{/if}
								</div>
								<div class="shrink-0 border-t border-gray-100"></div>
								<!-- Jugador 2 -->
								<div
									class="flex min-h-0 flex-1 items-center gap-1 px-2 text-[11px] leading-none
										{isWinner(match, 2) ? 'bg-green-50 font-bold' : ''}
										{match.slot2.is_bye ? 'opacity-40' : ''}"
								>
									{#if match.player2?.seed}
										<span class="w-4 shrink-0 text-right text-[9px] text-gray-400"
											>[{match.player2.seed}]</span
										>
									{/if}
									<span class="min-w-0 flex-1 truncate {!match.slot2.is_bye && !match.player2 ? 'italic text-gray-400' : ''}">
										{match.slot2.is_bye ? 'BYE' : (match.player2?.shortName ?? match.player2?.name ?? pendingLabel(match.slot2.id))}
									</span>
									{#if !match.slot2.is_bye}
										{#if match.estat === 'jugada' && match.caramboles2 !== null}
											<span class="shrink-0 text-[9px] font-semibold {isWinner(match, 2) ? 'text-green-700' : 'text-gray-400'}"
												>{match.caramboles2}{#if match.distancia_jugador2}<span class="font-normal text-gray-400">/{match.distancia_jugador2}</span>{#if sistemaPuntuacio === 'percentatge'}<span class="font-normal text-gray-400"> ({pct(match.caramboles2, match.distancia_jugador2)}%)</span>{/if}{/if}</span
											>
										{:else if match.estat === 'walkover' && !isWinner(match, 2)}
											<span class="shrink-0 text-[9px] font-semibold text-orange-500">W.O.</span>
										{:else if match.distancia_jugador2}
											<span class="shrink-0 text-[9px] text-gray-400">{match.distancia_jugador2}c</span>
										{/if}
									{/if}
								</div>
								<!-- Fila d'info: data/hora/taula + deadline -->
								<div
									class="flex shrink-0 items-center justify-between gap-1 border-t border-gray-100 px-2"
									style="height: 17px;"
								>
									{#if match.data_hora}
										{#if isTentative(match)}
											<span class="truncate text-[9px] italic text-gray-400" title={TENTATIVE_TITLE}>{formatMatchInfo(match)} *</span>
										{:else}
											<span class="truncate text-[9px] text-gray-400">{formatMatchInfo(match)}</span>
										{/if}
									{:else}
										<span></span>
									{/if}
									{#if match.dataMaximaDisputa}
										<span class={deadlineClassFor(match)} title="Data màxima de disputa: {match.dataMaximaDisputa}">màx {deadlineLabelFor(match)}</span>
									{/if}
								</div>
							</button>
						</div>
					{/each}
					{/if}
				{/each}

				<!-- Columnes Gran Final -->
				{#if filter === 'all' || filter === 'grand_final'}
					{#each wgfLayout.gfList as gfItem}
						{@const gfR = gfItem.r}
						{@const colX = gfItem.x}
						{#if gfItem.hidden}
							{@const gfNonBye = getMatchesBT('grand_final', gfR).filter((m) => m.estat !== 'bye')}
							<button
								type="button"
								class="hcap-stub absolute"
								on:click={() => toggleGF(gfR)}
								style="left: {colX}px; top: 0; width: {gfItem.w}px; height: {totalWH + 32}px;"
								title="Mostrar {gfR === 1 ? 'Gran Final' : 'Reset'}"
							>
								<span class="hcap-stub-label">{gfR === 1 ? '🏆 GF' : '🔁 Reset'}</span>
								<span class="hcap-stub-count">{gfNonBye.length} ✓</span>
								<span class="hcap-stub-cta">Mostrar</span>
							</button>
						{:else}
						<div
							class="absolute text-center text-[11px] font-semibold text-purple-600"
							style="left: {colX}px; top: 0; width: {COL_W}px;"
						>
							{gfR === 1 ? '🏆 Gran Final' : '🔁 Reset'}
							{#if (isMobile || compactCompleted) && isRoundComplete(getMatchesBT('grand_final', gfR))}
								<button
									type="button"
									class="hcap-collapse-btn"
									on:click={() => toggleGF(gfR)}
									title="Col·lapsar"
								>−</button>
							{/if}
						</div>
						{#each getMatchesBT('grand_final', gfR) as match}
							<div
								class="absolute"
								style="left: {colX}px; top: {32 + matchTopGF()}px; width: {COL_W}px;"
							>
								<button
									type="button"
									on:click={() => dispatch('matchclick', match)}
									class="flex w-full flex-col overflow-hidden rounded border-2 text-left shadow-sm transition-shadow hover:shadow-md
										{cardBorder(match.estat)}
										{isHighlighted(match) ? 'ring-2 ring-yellow-400 ring-offset-1' : ''}
										{gfR === 1 ? 'border-purple-300' : 'border-purple-200'}"
									style="height: {MATCH_H}px;"
								>
									<!-- Capçalera: codi + estat -->
									<div
										class="flex shrink-0 items-center justify-between border-b border-purple-100 bg-purple-50/40 px-2"
										style="height: 18px;"
									>
										<span class="font-mono text-[10px] font-bold leading-none text-purple-600"
											>{matchCode(match)}</span
										>
										{#if match.estat !== 'pendent' && match.estat !== 'bye'}
											<span class="rounded px-1 text-[8px] leading-tight {statusPill(match.estat)}"
												>{statusLabel(match.estat)}</span
											>
										{/if}
									</div>
									<!-- Jugador 1 -->
									<div
										class="flex min-h-0 flex-1 items-center gap-1 px-2 text-[11px] leading-none
											{isChampionSlot(match, 1) ? 'bg-yellow-50 font-bold' : isWinner(match, 1) ? 'bg-green-50 font-bold' : ''}"
									>
										<span class="min-w-0 flex-1 truncate {match.player1 ? 'text-purple-700' : 'italic text-purple-300'}">
											{match.player1?.shortName ?? match.player1?.name ?? pendingLabel(match.slot1.id)}
										</span>
										{#if match.estat === 'jugada' && match.caramboles1 !== null}
											<span class="shrink-0 text-[9px] font-semibold {isWinner(match, 1) ? 'text-green-700' : 'text-gray-500'}">{match.caramboles1}{#if match.distancia_jugador1}<span class="font-normal text-gray-400">/{match.distancia_jugador1}</span>{#if sistemaPuntuacio === 'percentatge'}<span class="font-normal text-gray-400"> ({pct(match.caramboles1, match.distancia_jugador1)}%)</span>{/if}{/if}</span>
										{:else if match.estat === 'walkover' && !isWinner(match, 1)}
											<span class="shrink-0 text-[9px] font-semibold text-orange-500">W.O.</span>
										{/if}
										{#if isChampionSlot(match, 1)}
											<span class="shrink-0 text-yellow-500" title="Campió">👑</span>
										{/if}
									</div>
									<div class="shrink-0 border-t border-purple-100"></div>
									<!-- Jugador 2 -->
									<div
										class="flex min-h-0 flex-1 items-center gap-1 px-2 text-[11px] leading-none
											{isChampionSlot(match, 2) ? 'bg-yellow-50 font-bold' : isWinner(match, 2) ? 'bg-green-50 font-bold' : ''}"
									>
										<span class="min-w-0 flex-1 truncate {match.player2 ? 'text-purple-700' : 'italic text-purple-300'}">
											{match.player2?.shortName ?? match.player2?.name ?? pendingLabel(match.slot2.id)}
										</span>
										{#if match.estat === 'jugada' && match.caramboles2 !== null}
											<span class="shrink-0 text-[9px] font-semibold {isWinner(match, 2) ? 'text-green-700' : 'text-gray-500'}">{match.caramboles2}{#if match.distancia_jugador2}<span class="font-normal text-gray-400">/{match.distancia_jugador2}</span>{#if sistemaPuntuacio === 'percentatge'}<span class="font-normal text-gray-400"> ({pct(match.caramboles2, match.distancia_jugador2)}%)</span>{/if}{/if}</span>
										{:else if match.estat === 'walkover' && !isWinner(match, 2)}
											<span class="shrink-0 text-[9px] font-semibold text-orange-500">W.O.</span>
										{/if}
										{#if isChampionSlot(match, 2)}
											<span class="shrink-0 text-yellow-500" title="Campió">👑</span>
										{/if}
									</div>
									<!-- Fila d'info: data/hora/taula -->
									<div
										class="flex shrink-0 items-center border-t border-purple-100 px-2"
										style="height: 17px;"
									>
										{#if match.data_hora}
											{#if isTentative(match)}
												<span class="truncate text-[9px] italic text-purple-400" title={TENTATIVE_TITLE}
													>{formatMatchInfo(match)} *</span
												>
											{:else}
												<span class="truncate text-[9px] text-purple-400"
													>{formatMatchInfo(match)}</span
												>
											{/if}
										{/if}
									</div>
								</button>
							</div>
						{/each}
						{/if}
					{/each}
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- ── Bracket de Perdedors ────────────────────────────────────────────────── -->
{#if showLosers && lMatches.length > 0}
	<div class="mb-4 bracket-section-losers">
		<h3 class="mb-2 text-xs font-semibold uppercase tracking-wide text-gray-500">
			Bracket de Perdedors
		</h3>
		<div class="bracket-scroll overflow-x-auto rounded border border-gray-100 bg-white p-3 shadow-sm">
			<div class="relative" style="width: {lSectionW}px; height: {totalLH + 32}px;">
				<!-- Connector SVG -->
				<svg
					class="pointer-events-none absolute inset-0"
					width={lSectionW}
					height={totalLH + 32}
					style="top: 32px;"
				>
					{#each lConnectors as line}
						<line
							x1={line.x1}
							y1={line.y1}
							x2={line.x2}
							y2={line.y2}
							stroke={line.won ? '#86efac' : '#d1d5db'}
							stroke-width="2"
						/>
					{/each}
				</svg>

				{#each lLayout.list as lItem}
					{@const lr = lItem.r}
					{@const colX = lItem.x}
					{#if lItem.hidden}
						{@const lNonBye = getMatchesBT('losers', lr).filter((m) => m.estat !== 'bye')}
						<button
							type="button"
							class="hcap-stub hcap-stub-losers absolute"
							on:click={() => toggleL(lr)}
							style="left: {colX}px; top: 0; width: {lItem.w}px; height: {totalLH + 32}px;"
							title="Mostrar {lRoundLabel(lr)} ({lNonBye.length} jugades)"
						>
							<span class="hcap-stub-label">{lRoundLabel(lr)}</span>
							<span class="hcap-stub-count">{lNonBye.length} ✓</span>
							<span class="hcap-stub-cta">Mostrar</span>
						</button>
					{:else}
					<div
						class="absolute text-center text-[11px] font-semibold text-orange-500"
						style="left: {colX}px; top: 0; width: {COL_W}px;"
					>
						{lRoundLabel(lr)}
						{#if (isMobile || compactCompleted) && isRoundComplete(getMatchesBT('losers', lr))}
							<button
								type="button"
								class="hcap-collapse-btn"
								on:click={() => toggleL(lr)}
								title="Col·lapsar {lRoundLabel(lr)}"
							>−</button>
						{/if}
					</div>
					{#each getMatchesBT('losers', lr) as match}
						{@const gBye = isGuaranteedBye(match)}
						<div
							class="absolute {gBye ? 'opacity-50' : ''}"
							style="left: {colX}px; top: {32 + matchTopL(lr, match.matchPos)}px; width: {COL_W}px;"
						>
							<button
								type="button"
								on:click={() => dispatch('matchclick', match)}
								class="flex w-full flex-col overflow-hidden rounded border-2 text-left shadow-sm
									{gBye ? 'cursor-default border-gray-200 bg-gray-50 shadow-none' : 'transition-shadow hover:shadow-md ' + cardBorder(match.estat)}
									{isHighlighted(match) ? 'ring-2 ring-yellow-400 ring-offset-1' : ''}"
								style="height: {MATCH_H}px;"
							>
								<!-- Capçalera: codi + estat -->
								<div
									class="flex shrink-0 items-center justify-between border-b px-2
										{gBye ? 'border-gray-200 bg-gray-100/40' : 'border-gray-100 bg-orange-50/30'}"
									style="height: 18px;"
								>
									<span class="font-mono text-[10px] font-bold leading-none
										{gBye ? 'text-gray-400' : 'text-orange-500'}"
										>{matchCode(match)}</span
									>
									{#if gBye}
										<span class="text-[8px] italic text-gray-400">pas automàtic</span>
									{:else if match.estat !== 'pendent' && match.estat !== 'bye'}
										<span class="rounded px-1 text-[8px] leading-tight {statusPill(match.estat)}"
											>{statusLabel(match.estat)}</span
										>
									{/if}
								</div>
								<!-- Jugador 1 -->
								<div
									class="flex min-h-0 flex-1 items-center gap-1 px-2 text-[11px] leading-none
										{!gBye && isWinner(match, 1) ? 'bg-green-50 font-bold' : ''}
										{match.slot1.is_bye ? 'opacity-40' : ''}"
								>
									{#if !gBye && match.player1?.seed}
										<span class="w-4 shrink-0 text-right text-[9px] text-gray-400"
											>[{match.player1.seed}]</span
										>
									{/if}
									<span class="min-w-0 flex-1 truncate
										{gBye && !match.slot1.is_bye ? 'italic text-gray-500' : ''}
										{!gBye && !match.slot1.is_bye && !match.player1 ? 'italic text-gray-400' : ''}">
										{#if match.slot1.is_bye}
											BYE
										{:else if gBye}
											{guaranteedByeSourceLabel(match)}
										{:else}
											{match.player1?.shortName ?? match.player1?.name ?? pendingLabel(match.slot1.id)}
										{/if}
									</span>
									{#if !gBye && !match.slot1.is_bye}
										{#if match.estat === "jugada" && match.caramboles1 !== null}
											<span class="shrink-0 text-[9px] font-semibold {isWinner(match, 1) ? 'text-green-700' : 'text-gray-500'}">{match.caramboles1}{#if match.distancia_jugador1}<span class="font-normal text-gray-400">/{match.distancia_jugador1}</span>{#if sistemaPuntuacio === 'percentatge'}<span class="font-normal text-gray-400"> ({pct(match.caramboles1, match.distancia_jugador1)}%)</span>{/if}{/if}</span>
										{:else if match.estat === "walkover" && !isWinner(match, 1)}
											<span class="shrink-0 text-[9px] font-semibold text-orange-500">W.O.</span>
										{:else if match.distancia_jugador1}
											<span class="shrink-0 text-[9px] text-gray-400">{match.distancia_jugador1}c</span>
										{/if}
									{/if}
								</div>
								<div class="shrink-0 border-t {gBye ? 'border-gray-200' : 'border-gray-100'}"></div>
								<!-- Jugador 2 -->
								<div
									class="flex min-h-0 flex-1 items-center gap-1 px-2 text-[11px] leading-none
										{!gBye && isWinner(match, 2) ? 'bg-green-50 font-bold' : ''}
										{match.slot2.is_bye ? 'opacity-40' : ''}"
								>
									{#if !gBye && match.player2?.seed}
										<span class="w-4 shrink-0 text-right text-[9px] text-gray-400"
											>[{match.player2.seed}]</span
										>
									{/if}
									<span class="min-w-0 flex-1 truncate
										{gBye && !match.slot2.is_bye ? 'italic text-gray-500' : ''}
										{!gBye && !match.slot2.is_bye && !match.player2 ? 'italic text-gray-400' : ''}">
										{#if match.slot2.is_bye}
											BYE
										{:else if gBye}
											{guaranteedByeSourceLabel(match)}
										{:else}
											{match.player2?.shortName ?? match.player2?.name ?? pendingLabel(match.slot2.id)}
										{/if}
									</span>
									{#if !gBye && !match.slot2.is_bye}
										{#if match.estat === "jugada" && match.caramboles2 !== null}
											<span class="shrink-0 text-[9px] font-semibold {isWinner(match, 2) ? 'text-green-700' : 'text-gray-500'}">{match.caramboles2}{#if match.distancia_jugador2}<span class="font-normal text-gray-400">/{match.distancia_jugador2}</span>{#if sistemaPuntuacio === 'percentatge'}<span class="font-normal text-gray-400"> ({pct(match.caramboles2, match.distancia_jugador2)}%)</span>{/if}{/if}</span>
										{:else if match.estat === "walkover" && !isWinner(match, 2)}
											<span class="shrink-0 text-[9px] font-semibold text-orange-500">W.O.</span>
										{:else if match.distancia_jugador2}
											<span class="shrink-0 text-[9px] text-gray-400">{match.distancia_jugador2}c</span>
										{/if}
									{/if}
								</div>
								<!-- Fila d'info: data/hora/taula -->
								<div
									class="flex shrink-0 items-center border-t px-2
										{gBye ? 'border-gray-200' : 'border-gray-100'}"
									style="height: 17px;"
								>
									{#if !gBye && match.data_hora}
										{#if isTentative(match)}
											<span class="truncate text-[9px] italic text-gray-400" title={TENTATIVE_TITLE}>{formatMatchInfo(match)} *</span>
										{:else}
											<span class="truncate text-[9px] text-gray-400">{formatMatchInfo(match)}</span>
										{/if}
									{/if}
								</div>
							</button>
						</div>
					{/each}
					{/if}
				{/each}
			</div>
		</div>
	</div>
{/if}

<!-- ── Llegenda ─────────────────────────────────────────────────────────────── -->
<div class="mt-2 flex flex-wrap gap-4 text-xs text-gray-500">
	<span class="flex items-center gap-1">
		<span class="inline-block h-3 w-3 rounded border-2 border-gray-300 bg-white"></span>Pendent
	</span>
	<span class="flex items-center gap-1">
		<span class="inline-block h-3 w-3 rounded border-2 border-blue-400 bg-blue-50"></span>Programada
	</span>
	<span class="flex items-center gap-1">
		<span class="inline-block h-3 w-3 rounded border-2 border-green-400 bg-green-50"></span>Jugada
	</span>
	<span class="flex items-center gap-1">
		<span class="inline-block h-3 w-3 rounded border-2 border-orange-400 bg-orange-50"></span>Walkover
	</span>
	{#if searchTerm}
		<span class="flex items-center gap-1">
			<span class="inline-block h-3 w-3 rounded border-2 border-yellow-400 ring-2 ring-yellow-400"></span>Cerca ressaltada
		</span>
	{/if}
</div>

</div>

<style>
	.hcap-bracket-root {
		font-family: var(--font-sans);
		color: var(--ink);
	}
	/* Section titles (Bracket de Guanyadors / Perdedors) */
	.hcap-bracket-root :global(h3.uppercase) {
		font-size: 0.6875rem !important;
		font-weight: 600 !important;
		letter-spacing: 0.16em !important;
		text-transform: uppercase !important;
		color: var(--ink-3) !important;
	}
	/* Bracket scroll containers (cartes blanques amb shadow) */
	.hcap-bracket-root :global(.bracket-scroll) {
		background: var(--paper-elevated) !important;
		border: 1px solid var(--rule) !important;
		border-radius: 0 !important;
		box-shadow: none !important;
		/* Momentum + snap horitzontal a mòbil per fer l'scroll més natural */
		-webkit-overflow-scrolling: touch;
		scroll-behavior: smooth;
		scroll-snap-type: x proximity;
	}
	/* Match cards i botons del bracket */
	.hcap-bracket-root :global(button.bg-white),
	.hcap-bracket-root :global(.bg-white) {
		background: var(--paper-elevated) !important;
	}
	.hcap-bracket-root :global(.bg-blue-50),
	.hcap-bracket-root :global(button.bg-blue-50) {
		background: var(--paper) !important;
		border-color: var(--blue) !important;
	}
	.hcap-bracket-root :global(.bg-green-50),
	.hcap-bracket-root :global(button.bg-green-50) {
		background: var(--paper) !important;
		border-color: var(--green) !important;
	}
	.hcap-bracket-root :global(.bg-orange-50),
	.hcap-bracket-root :global(button.bg-orange-50) {
		background: var(--paper) !important;
		border-color: var(--amber) !important;
	}
	.hcap-bracket-root :global(.bg-yellow-50),
	.hcap-bracket-root :global(button.bg-yellow-50) {
		background: var(--paper) !important;
		border-color: var(--amber) !important;
	}
	.hcap-bracket-root :global(.bg-red-50) {
		background: var(--paper) !important;
		border-color: var(--accent) !important;
	}
	.hcap-bracket-root :global(.border-blue-400),
	.hcap-bracket-root :global(.border-blue-300) {
		border-color: var(--blue) !important;
	}
	.hcap-bracket-root :global(.border-green-400),
	.hcap-bracket-root :global(.border-green-300) {
		border-color: var(--green) !important;
	}
	.hcap-bracket-root :global(.border-orange-400),
	.hcap-bracket-root :global(.border-orange-300) {
		border-color: var(--amber) !important;
	}
	.hcap-bracket-root :global(.border-yellow-400),
	.hcap-bracket-root :global(.border-yellow-300) {
		border-color: var(--amber) !important;
	}
	.hcap-bracket-root :global(.border-gray-300),
	.hcap-bracket-root :global(.border-gray-200),
	.hcap-bracket-root :global(.border-gray-100) {
		border-color: var(--rule-strong) !important;
	}
	/* Text colors */
	.hcap-bracket-root :global(.text-gray-500),
	.hcap-bracket-root :global(.text-gray-600) { color: var(--ink-3) !important; }
	.hcap-bracket-root :global(.text-gray-700),
	.hcap-bracket-root :global(.text-gray-800),
	.hcap-bracket-root :global(.text-gray-900) { color: var(--ink) !important; }
	.hcap-bracket-root :global(.text-blue-600),
	.hcap-bracket-root :global(.text-blue-700),
	.hcap-bracket-root :global(.text-blue-800),
	.hcap-bracket-root :global(.text-blue-900) { color: var(--blue) !important; }
	.hcap-bracket-root :global(.text-green-600),
	.hcap-bracket-root :global(.text-green-700),
	.hcap-bracket-root :global(.text-green-800) { color: var(--green) !important; }
	.hcap-bracket-root :global(.text-orange-600),
	.hcap-bracket-root :global(.text-orange-700),
	.hcap-bracket-root :global(.text-orange-800),
	.hcap-bracket-root :global(.text-amber-700) { color: var(--amber) !important; }
	.hcap-bracket-root :global(.text-yellow-600),
	.hcap-bracket-root :global(.text-yellow-700),
	.hcap-bracket-root :global(.text-yellow-800) { color: var(--amber) !important; }
	.hcap-bracket-root :global(.text-red-600),
	.hcap-bracket-root :global(.text-red-700) { color: var(--accent) !important; }
	.hcap-bracket-root :global(.text-purple-600),
	.hcap-bracket-root :global(.text-purple-700) { color: var(--sec-handicap) !important; }
	/* Connector SVG lines: usar tinta editorial per al connector */
	.hcap-bracket-root :global(svg line) {
		stroke: var(--rule-strong);
	}
	/* Cantos i ombres */
	.hcap-bracket-root :global(.rounded),
	.hcap-bracket-root :global(.rounded-sm),
	.hcap-bracket-root :global(.rounded-md),
	.hcap-bracket-root :global(.rounded-lg),
	.hcap-bracket-root :global(.rounded-xl),
	.hcap-bracket-root :global(.rounded-full) { border-radius: 0 !important; }
	.hcap-bracket-root :global(.shadow),
	.hcap-bracket-root :global(.shadow-sm),
	.hcap-bracket-root :global(.shadow-md),
	.hcap-bracket-root :global(.shadow-lg) { box-shadow: none !important; }
	/* Ring (per highlight de cerca) */
	.hcap-bracket-root :global(.ring-2.ring-yellow-400) {
		box-shadow: 0 0 0 2px var(--amber) !important;
	}

	/* ── Pill de data màxima de disputa ─────────────────────────────── */
	.hcap-bracket-root :global(.hcap-deadline) {
		display: inline-flex;
		align-items: center;
		font-size: 8.5px;
		font-weight: 700;
		line-height: 1;
		letter-spacing: 0.02em;
		padding: 1px 4px;
		border: 1px solid currentColor;
		border-radius: 2px;
		white-space: nowrap;
		flex: none;
	}
	.hcap-bracket-root :global(.hcap-deadline-safe) {
		color: var(--ink-3);
		opacity: 0.7;
	}
	.hcap-bracket-root :global(.hcap-deadline-soon) {
		color: var(--amber);
		background: rgba(255, 176, 0, 0.08);
	}
	.hcap-bracket-root :global(.hcap-deadline-passed) {
		color: var(--accent);
		background: rgba(217, 25, 25, 0.08);
		font-weight: 800;
	}

	/* ── Stub de ronda col·lapsada ─────────────────────────────────── */
	.hcap-bracket-root :global(.hcap-stub) {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		padding: 0.5rem 0.25rem;
		background: var(--paper);
		border: 1px dashed var(--rule-strong);
		cursor: pointer;
		font-family: var(--font-sans);
		color: var(--ink-soft);
		writing-mode: vertical-rl;
		text-orientation: mixed;
		transition: background 0.15s ease, border-color 0.15s ease;
	}
	.hcap-bracket-root :global(.hcap-stub:hover) {
		background: var(--paper-elevated);
		border-color: var(--ink);
		color: var(--ink);
	}
	.hcap-bracket-root :global(.hcap-stub-label) {
		font-size: 0.75rem;
		font-weight: 700;
		letter-spacing: 0.03em;
		color: var(--ink);
	}
	.hcap-bracket-root :global(.hcap-stub-count) {
		font-size: 0.625rem;
		font-weight: 600;
		color: var(--green);
		letter-spacing: 0.04em;
	}
	.hcap-bracket-root :global(.hcap-stub-cta) {
		font-size: 0.625rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.12em;
		color: var(--ink-3);
	}
	.hcap-bracket-root :global(.hcap-stub-losers .hcap-stub-label) {
		color: var(--amber);
	}

	/* Botó "−" per col·lapsar a mòbil al costat del títol de ronda */
	.hcap-bracket-root :global(.hcap-collapse-btn) {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 18px;
		height: 18px;
		margin-left: 0.25rem;
		background: transparent;
		border: 1px solid var(--rule-strong);
		color: var(--ink-3);
		font-size: 0.875rem;
		font-weight: 700;
		line-height: 1;
		cursor: pointer;
		vertical-align: middle;
	}
	.hcap-bracket-root :global(.hcap-collapse-btn:hover) {
		background: var(--paper);
		color: var(--ink);
	}

	/* ── Mobile: simplifica scroll del bracket ─────────────────────── */
	@media (max-width: 767px) {
		.hcap-bracket-root :global(.bracket-scroll) {
			padding: 0.5rem !important;
			/* Edge-to-edge: aprofita tota l'amplada de la pantalla */
			margin-left: -1rem;
			margin-right: -1rem;
			border-left: none !important;
			border-right: none !important;
			/* Indicador visual de més contingut a la dreta */
			background-image: linear-gradient(
				to right,
				transparent 0%,
				transparent calc(100% - 24px),
				color-mix(in srgb, var(--ink) 8%, transparent) 100%
			);
			background-attachment: local, scroll;
		}
		/* Cada carta de partida fa de "snap point" → swipe natural per ronda */
		.hcap-bracket-root :global(.bracket-scroll button) {
			scroll-snap-align: start;
			scroll-margin-left: 0.5rem;
		}
		/* Compacta els títols Bracket de Guanyadors/Perdedors */
		.hcap-bracket-root :global(h3.uppercase) {
			margin-bottom: 0.4rem !important;
			padding-left: 0.25rem;
		}
		/* Redueix la separació entre seccions winners/losers */
		.hcap-bracket-root :global(.bracket-section-winners),
		.hcap-bracket-root :global(.bracket-section-losers) {
			margin-bottom: 1rem !important;
		}
	}

	@media print {
		/* Eliminar scroll horitzontal: mostrar tot el contingut del bracket */
		.bracket-scroll {
			overflow: visible !important;
			max-width: none !important;
			width: auto !important;
		}

		/* Salt de pàgina entre bracket de guanyadors i de perdedors */
		.bracket-section-losers {
			page-break-before: always;
			break-before: page;
		}

		/* Evitar que les caixes de partida es tallin entre pàgines */
		button {
			page-break-inside: avoid !important;
			break-inside: avoid !important;
		}

		/* Reduir lletra per a brackets amb molts jugadors */
		.bracket-section-winners,
		.bracket-section-losers {
			font-size: 9px;
		}
	}
</style>
