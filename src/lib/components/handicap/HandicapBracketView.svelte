<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { MatchView } from '$lib/utils/handicap-types';
	import { buildMatchCodeMap, buildLoserDestCodeMap, buildSlotSourceMap } from '$lib/utils/handicap-types';

	const dispatch = createEventDispatcher<{ matchclick: MatchView }>();

	// ── Props ─────────────────────────────────────────────────────────────────

	export let matchViews: MatchView[] = [];
	export let filter: 'all' | 'winners' | 'losers' | 'grand_final' = 'all';
	export let searchTerm: string = '';
	/** Si el torneig ha acabat, ID del campió per mostrar la corona */
	export let championParticipantId: string | null = null;
	/** Sistema de puntuació: 'distancia' | 'percentatge' */
	export let sistemaPuntuacio: string = 'distancia';

	/** Retorna el percentatge formatat (0 decimals) d'una puntuació sobre distància. */
	function pct(caramboles: number | null, distancia: number | null): string {
		if (!caramboles || !distancia) return '—';
		return Math.round((caramboles / distancia) * 100).toString();
	}

	// ── Constants ─────────────────────────────────────────────────────────────

	const MATCH_H = 82; // px – alçada de la targeta (header 18 + P1 + div + P2 + info 17)
	const SLOT_H = 108; // px – unitat base (MATCH_H + 26px per etiqueta sota)
	const COL_W = 155; // px – amplada de cada columna de ronda
	const GAP = 22; // px – separació entre columnes (on van els connectors)

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

	// Nombre total de columnes de la secció guanyadors + gran final
	$: wColCount = wRounds.length + gfRounds.length;
	$: wSectionW = wColCount * (COL_W + GAP) + COL_W;

	$: lColCount = lRounds.length;
	$: lSectionW = lColCount * (COL_W + GAP) + COL_W;

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

	$: wConnectors = buildWinnersConnectors();

	// ── Línies de connector SVG (bracket perdedors) ───────────────────────────

	$: lConnectors = buildLosersConnectors();

	function buildLosersConnectors(): Array<{ x1: number; y1: number; x2: number; y2: number; won: boolean }> {
		const lines: Array<{ x1: number; y1: number; x2: number; y2: number; won: boolean }> = [];
		if (lRounds.length < 2) return lines;

		// Mapa slotId → match per al bracket perdedors
		const slotToLMatch = new Map<string, MatchView>();
		for (const m of lMatches) {
			slotToLMatch.set(m.slot1.id, m);
			slotToLMatch.set(m.slot2.id, m);
		}

		// Mapa ronda losers → índex de columna
		const lRoundToColIdx = new Map<number, number>();
		lRounds.forEach((lr, i) => lRoundToColIdx.set(lr, i));

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
			const destColIdx = lRoundToColIdx.get(destMatch.ronda)!;
			const destColX = destColIdx * (COL_W + GAP);
			const destY = matchTopL(destMatch.ronda, destMatch.matchPos) + MATCH_H / 2;

			if (sources.length === 2) {
				// Dues partides s'uneixen (ronda de consolidació) → estil bracket
				const [m1, m2] = [...sources].sort((a, b) => a.matchPos - b.matchPos);
				const srcColIdx = lRoundToColIdx.get(m1.ronda)!;
				const srcColX = srcColIdx * (COL_W + GAP);
				const midX = srcColX + COL_W + GAP / 2;

				const y1 = matchTopL(m1.ronda, m1.matchPos) + MATCH_H / 2;
				const y2 = matchTopL(m2.ronda, m2.matchPos) + MATCH_H / 2;
				const won1 = m1.estat === 'jugada' || m1.estat === 'walkover' || m1.estat === 'bye';
				const won2 = m2.estat === 'jugada' || m2.estat === 'walkover' || m2.estat === 'bye';
				const bothWon = won1 && won2;

				lines.push({ x1: srcColX + COL_W, y1, x2: midX, y2: y1, won: won1 });
				lines.push({ x1: srcColX + COL_W, y1: y2, x2: midX, y2, won: won2 });
				lines.push({ x1: midX, y1, x2: midX, y2, won: bothWon });
				lines.push({ x1: midX, y1: destY, x2: destColX, y2: destY, won: bothWon });
			} else if (sources.length === 1) {
				// Una sola partida avança (l'altra plaça ve del bracket guanyadors) → L-shape
				const m = sources[0];
				const srcColIdx = lRoundToColIdx.get(m.ronda)!;
				const srcColX = srcColIdx * (COL_W + GAP);
				const midX = srcColX + COL_W + GAP / 2;
				const srcY = matchTopL(m.ronda, m.matchPos) + MATCH_H / 2;
				const won = m.estat === 'jugada' || m.estat === 'walkover' || m.estat === 'bye';

				if (Math.abs(srcY - destY) < 1) {
					lines.push({ x1: srcColX + COL_W, y1: srcY, x2: destColX, y2: srcY, won });
				} else {
					lines.push({ x1: srcColX + COL_W, y1: srcY, x2: midX, y2: srcY, won });
					lines.push({ x1: midX, y1: srcY, x2: midX, y2: destY, won });
					lines.push({ x1: midX, y1: destY, x2: destColX, y2: destY, won });
				}
			}
		}

		return lines;
	}

	function buildWinnersConnectors(): Array<{ x1: number; y1: number; x2: number; y2: number; won: boolean }> {
		const lines: Array<{ x1: number; y1: number; x2: number; y2: number; won: boolean }> = [];
		if (wRounds.length === 0) return lines;

		for (let ri = 0; ri < wRounds.length - 1; ri++) {
			const r = wRounds[ri];
			const colX = ri * (COL_W + GAP);
			const midX = colX + COL_W + GAP / 2;
			const nextColX = (ri + 1) * (COL_W + GAP);

			const roundMatches = getMatchesBT('winners', r).sort((a, b) => a.matchPos - b.matchPos);

			for (let j = 0; j < roundMatches.length; j += 2) {
				const m1 = roundMatches[j];
				const m2 = roundMatches[j + 1];
				if (!m1) continue;

				const c1y = matchTopW(r, m1.matchPos) + MATCH_H / 2;
				const won1 = m1.estat === 'jugada' || m1.estat === 'walkover' || m1.estat === 'bye';

				if (!m2) {
					lines.push({ x1: colX + COL_W, y1: c1y, x2: nextColX, y2: c1y, won: won1 });
					continue;
				}

				const c2y = matchTopW(r, m2.matchPos) + MATCH_H / 2;
				const won2 = m2.estat === 'jugada' || m2.estat === 'walkover' || m2.estat === 'bye';
				const midY = (c1y + c2y) / 2;
				const bothWon = won1 && won2;

				lines.push({ x1: colX + COL_W, y1: c1y, x2: midX, y2: c1y, won: won1 });
				lines.push({ x1: colX + COL_W, y1: c2y, x2: midX, y2: c2y, won: won2 });
				lines.push({ x1: midX, y1: c1y, x2: midX, y2: c2y, won: bothWon });
				lines.push({ x1: midX, y1: midY, x2: nextColX, y2: midY, won: bothWon });
			}
		}

		// W-Final → GF-R1 (línia horitzontal al centre)
		if (gfRounds.length > 0 && wRounds.length > 0) {
			const wFinalColX = (wRounds.length - 1) * (COL_W + GAP);
			const gfColX = wRounds.length * (COL_W + GAP);
			const cy = totalWH / 2;
			const wFinalMatch = getMatchesBT('winners', wRounds[wRounds.length - 1])[0];
			const won = wFinalMatch?.estat === 'jugada' || wFinalMatch?.estat === 'bye';
			lines.push({ x1: wFinalColX + COL_W, y1: cy, x2: gfColX, y2: cy, won });

			// GF-R1 → GF-R2
			if (gfRounds.length > 1) {
				const gfR2ColX = (wRounds.length + 1) * (COL_W + GAP);
				const gfR1Match = getMatchesBT('grand_final', 1)[0];
				const gfWon = gfR1Match?.estat === 'jugada';
				lines.push({ x1: gfColX + COL_W, y1: cy, x2: gfR2ColX, y2: cy, won: gfWon });
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
				{#each wRounds as r, ri}
					{@const colX = ri * (COL_W + GAP)}
					<!-- Capçalera columna -->
					<div
						class="absolute text-center text-[11px] font-semibold text-gray-500"
						style="left: {colX}px; top: 0; width: {COL_W}px;"
					>
						{wRoundLabel(r)}
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
								<!-- Fila d'info: data/hora/taula -->
								<div
									class="flex shrink-0 items-center border-t border-gray-100 px-2"
									style="height: 17px;"
								>
									{#if match.data_hora}
										<span class="truncate text-[9px] text-gray-400">{formatMatchInfo(match)}</span>
									{/if}
								</div>
							</button>
						</div>
					{/each}
				{/each}

				<!-- Columnes Gran Final -->
				{#if filter === 'all' || filter === 'grand_final'}
					{#each gfRounds as gfR, gfi}
						{@const colX = (wRounds.length + gfi) * (COL_W + GAP)}
						<div
							class="absolute text-center text-[11px] font-semibold text-purple-600"
							style="left: {colX}px; top: 0; width: {COL_W}px;"
						>
							{gfR === 1 ? '🏆 Gran Final' : '🔁 Reset'}
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
											<span class="truncate text-[9px] text-purple-400"
												>{formatMatchInfo(match)}</span
											>
										{/if}
									</div>
								</button>
							</div>
						{/each}
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

				{#each lRounds as lr, lri}
					{@const colX = lri * (COL_W + GAP)}
					<div
						class="absolute text-center text-[11px] font-semibold text-orange-500"
						style="left: {colX}px; top: 0; width: {COL_W}px;"
					>
						{lRoundLabel(lr)}
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
										<span class="truncate text-[9px] text-gray-400">{formatMatchInfo(match)}</span>
									{/if}
								</div>
							</button>
						</div>
					{/each}
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

<style>
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
