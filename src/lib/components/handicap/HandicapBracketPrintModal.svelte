<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { generateDoublEliminationBracket } from '$lib/utils/handicap-bracket-generator';

	// Dos modes:
	//   - eventId definit       → bracket REAL: carrega slots/matches de la BBDD.
	//   - participantCount > 0  → bracket EN BLANC: genera l'estructura al vol per a N
	//     jugadors (sorteig manual). El bracket no es persisteix.
	export let eventId: string | null = null;
	export let participantCount: number | null = null;
	export let eventNom: string = '';
	export let eventTemporada: string = '';
	export let onClose: () => void = () => {};

	// '2025-2026' → '2025/2026'
	$: temporadaPretty = (eventTemporada || '').replace('-', '/');

	type Bracket = 'winners' | 'losers' | 'grand_final';
	type Slot = { id: string; bracket_type: Bracket; ronda: number; posicio: number };
	type MatchRaw = {
		id: string;
		slot1_id: string;
		slot2_id: string;
		winner_slot_dest_id: string | null;
		loser_slot_dest_id: string | null;
		estat?: string;
	};
	type MatchView = {
		id: string;
		code: string;
		bracket: Bracket;
		ronda: number;
		winnerDest: string;
		loserDest: string;
	};

	let loading = true;
	let error: string | null = null;

	let winnersPages: Array<Array<[number, MatchView[]]>> = [];
	let losersPages: Array<Array<[number, MatchView[]]>> = [];
	let totalMatches = 0;

	// Per al mode "blanc": l'usuari pot ajustar el nombre de jugadors sense tancar el modal.
	let inputCount = participantCount ?? 32;

	onMount(loadAll);

	async function regenerate() {
		if (eventId) return;
		await loadAll();
	}

	async function loadAll() {
		loading = true;
		try {
			let slots: Slot[];
			let matches: MatchRaw[];

			if (eventId) {
				const { data: slotsData, error: sErr } = await supabase
					.from('handicap_bracket_slots')
					.select('id, bracket_type, ronda, posicio')
					.eq('event_id', eventId);
				if (sErr) throw sErr;

				const { data: matchesData, error: mErr } = await supabase
					.from('handicap_matches')
					.select('id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id, estat')
					.eq('event_id', eventId);
				if (mErr) throw mErr;

				slots = (slotsData ?? []) as Slot[];
				matches = (matchesData ?? []) as MatchRaw[];
			} else if (inputCount && inputCount >= 2) {
				// Mode BLANC: genera estructura amb participants ficticis (només per dibuixar
				// el bracket). Seeds seqüencials, distancia=0, sense persistir res.
				const fakes = Array.from({ length: inputCount }, (_, i) => ({
					id: `fake-${i + 1}`,
					seed: i + 1,
					distancia: 0
				}));
				const result = generateDoublEliminationBracket('preview', fakes);
				slots = result.slots.map(s => ({
					id: s.id,
					bracket_type: s.bracket_type,
					ronda: s.ronda,
					posicio: s.posicio
				}));
				matches = result.matches.map(m => ({
					id: m.id,
					slot1_id: m.slot1_id,
					slot2_id: m.slot2_id,
					winner_slot_dest_id: m.winner_slot_dest_id,
					loser_slot_dest_id: m.loser_slot_dest_id,
					estat: m.estat
				}));
			} else {
				error = 'Cal un torneig generat o un nombre de participants ≥ 2.';
				loading = false;
				return;
			}

			// Excloure partides "bye" del bracket en blanc (no s'hi escriu res).
			matches = matches.filter(m => m.estat !== 'bye');

			if (matches.length === 0) {
				error = 'No hi ha cap partida amb què muntar el bracket.';
				loading = false;
				return;
			}

			const slotById = new Map<string, Slot>(slots.map(s => [s.id, s]));
			const matchBySlot = new Map<string, MatchRaw>();
			for (const m of matches) {
				matchBySlot.set(m.slot1_id, m);
				matchBySlot.set(m.slot2_id, m);
			}

			// Ordenar matches per bracket → ronda → primera posició
			const order: Record<Bracket, number> = { winners: 0, losers: 1, grand_final: 2 };
			const enriched = matches.map(m => {
				const s1 = slotById.get(m.slot1_id);
				const s2 = slotById.get(m.slot2_id);
				const bracket = (s1?.bracket_type ?? 'winners') as Bracket;
				const ronda = s1?.ronda ?? 0;
				const posicioMin = Math.min(s1?.posicio ?? 9999, s2?.posicio ?? 9999);
				return { m, bracket, ronda, posicioMin };
			}).sort((a, b) => {
				if (a.bracket !== b.bracket) return order[a.bracket] - order[b.bracket];
				if (a.ronda !== b.ronda) return a.ronda - b.ronda;
				return a.posicioMin - b.posicioMin;
			});

			// Codis seqüencials dins de cada (bracket, ronda)
			const codeByMatchId = new Map<string, string>();
			const counterByKey = new Map<string, number>();
			for (const e of enriched) {
				const key = `${e.bracket}-${e.ronda}`;
				const next = (counterByKey.get(key) ?? 0) + 1;
				counterByKey.set(key, next);
				const code = e.bracket === 'grand_final'
					? `GF${e.ronda}`
					: `${e.bracket === 'winners' ? 'W' : 'L'}${e.ronda}.${next}`;
				codeByMatchId.set(e.m.id, code);
			}

			const destinationCode = (slotId: string | null): string => {
				if (!slotId) return '—';
				const m = matchBySlot.get(slotId);
				if (!m) return '—';
				return codeByMatchId.get(m.id) ?? '—';
			};

			const matchViews: MatchView[] = enriched.map(e => ({
				id: e.m.id,
				code: codeByMatchId.get(e.m.id) ?? '?',
				bracket: e.bracket,
				ronda: e.ronda,
				winnerDest: destinationCode(e.m.winner_slot_dest_id),
				loserDest: destinationCode(e.m.loser_slot_dest_id)
			}));

			totalMatches = matchViews.length;

			// Agrupar per bracket (Grand Final s'afegeix al final de winners en l'última pàgina)
			const winnersByRonda = new Map<number, MatchView[]>();
			const losersByRonda = new Map<number, MatchView[]>();
			const gfList: MatchView[] = [];

			for (const mv of matchViews) {
				if (mv.bracket === 'winners') {
					if (!winnersByRonda.has(mv.ronda)) winnersByRonda.set(mv.ronda, []);
					winnersByRonda.get(mv.ronda)!.push(mv);
				} else if (mv.bracket === 'losers') {
					if (!losersByRonda.has(mv.ronda)) losersByRonda.set(mv.ronda, []);
					losersByRonda.get(mv.ronda)!.push(mv);
				} else {
					gfList.push(mv);
				}
			}

			const winnersSorted: Array<[number, MatchView[]]> = [...winnersByRonda.entries()].sort((a, b) => a[0] - b[0]);
			const losersSorted: Array<[number, MatchView[]]> = [...losersByRonda.entries()].sort((a, b) => a[0] - b[0]);

			// Afegir Grand Final com a "ronda" extra al final del bracket Winners
			if (gfList.length > 0) {
				winnersSorted.push([99, gfList]);
			}

			const totalWin = winnersSorted.reduce((acc, [, arr]) => acc + arr.length, 0);
			const totalLos = losersSorted.reduce((acc, [, arr]) => acc + arr.length, 0);

			// Decisió auto: >16 matches en un bracket → 2 fulls
			winnersPages = splitInPages(winnersSorted, totalWin);
			losersPages = splitInPages(losersSorted, totalLos);

			loading = false;
		} catch (e: any) {
			error = e.message || 'Error carregant el bracket';
			loading = false;
		}
	}

	// Divideix un bracket en 1 o 2 pàgines. Si tots els matches ≤16, una pàgina.
	// Si no, parteix per rondes intentant equilibrar.
	function splitInPages(
		rondesSorted: Array<[number, MatchView[]]>,
		total: number
	): Array<Array<[number, MatchView[]]>> {
		if (total <= 16 || rondesSorted.length <= 1) {
			return [rondesSorted];
		}
		const target = Math.ceil(total / 2);
		const page1: Array<[number, MatchView[]]> = [];
		const page2: Array<[number, MatchView[]]> = [];
		let acc = 0;
		for (const entry of rondesSorted) {
			if (acc < target) {
				page1.push(entry);
				acc += entry[1].length;
			} else {
				page2.push(entry);
			}
		}
		return page2.length === 0 ? [page1] : [page1, page2];
	}

	$: totalFulls = winnersPages.length + losersPages.length;

	function rondaLabel(bracket: Bracket, num: number): string {
		if (num === 99) return 'Gran Final';
		const prefix = bracket === 'winners' ? 'Principal' : 'Repesca';
		return `${prefix} — Ronda ${num}`;
	}

	function doPrint() {
		window.print();
	}
</script>

<div class="print-modal-overlay" on:click|self={onClose} role="presentation">
	<div class="print-modal-card" role="dialog" aria-modal="true">
		<div class="print-modal-head no-print">
			<h2 class="print-modal-title">Imprimir bracket per a la pissarra</h2>
			<button type="button" class="close-btn" on:click={onClose} aria-label="Tancar">×</button>
		</div>

		<div class="print-modal-toolbar no-print">
			<div class="toolbar-info">
				{#if loading}
					<span>Carregant bracket…</span>
				{:else if error}
					<span class="err">{error}</span>
				{:else}
					<span>
						{totalMatches} partides · {totalFulls} fulls A3
						({winnersPages.length} principal + {losersPages.length} repesca)
					</span>
					<span class="hint">Per a PDF: <em>Imprimir / Desar PDF</em> → al diàleg, destinació <em>Guardar com a PDF</em>.</span>
				{/if}
				{#if !eventId}
					<label class="count-label">
						Jugadors:
						<input
							type="number"
							min="2"
							max="128"
							bind:value={inputCount}
							class="count-input"
						/>
					</label>
					<button type="button" class="btn-secondary" on:click={regenerate} disabled={loading || inputCount < 2}>
						Recalcular
					</button>
				{/if}
			</div>
			<div class="toolbar-actions">
				<button type="button" class="btn-secondary" on:click={onClose}>Tancar</button>
				<button
					type="button"
					class="btn-primary"
					on:click={doPrint}
					disabled={loading || !!error}
					title="Al diàleg d'imprimir, tria 'Guardar com a PDF' per descarregar el bracket"
				>
					Imprimir / Desar PDF
				</button>
			</div>
		</div>

		{#if !loading && !error}
			<div class="print-preview">
				{#each winnersPages as page, pi}
					<section class="print-page">
						<header class="page-head">
							<div class="page-head-left">
								<img src="/logo-billar.svg" alt="" class="page-logo" />
								<div class="page-head-titles">
									<div class="page-title-main">CAMPIONAT SOCIAL HÀNDICAP{temporadaPretty ? ` ${temporadaPretty}` : ''}</div>
									<div class="page-section">Bracket Principal {winnersPages.length > 1 ? `(${pi + 1}/${winnersPages.length})` : ''}</div>
								</div>
							</div>
							{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
						</header>
						<div class="rounds">
							{#each page as [ronda, items]}
								<div class="round-section">
									<h3 class="round-title">{rondaLabel(items[0].bracket, ronda)}</h3>
									<div class="match-grid">
										{#each items as mv}
											<div class="match-cell">
												<div class="cell-head">
													<span class="match-code">{mv.code}</span>
													<span class="arrows">
														<span>↗W: <strong>{mv.winnerDest}</strong></span>
														{#if mv.loserDest !== '—'}
															<span>↘L: <strong>{mv.loserDest}</strong></span>
														{/if}
													</span>
												</div>
												<div class="player-row">
													<span class="label">Jug 1</span>
													<span class="line"></span>
													<span class="kv">Dist</span><span class="box small"></span>
													<span class="kv">Car</span><span class="box small"></span>
												</div>
												<div class="player-row">
													<span class="label">Jug 2</span>
													<span class="line"></span>
													<span class="kv">Dist</span><span class="box small"></span>
													<span class="kv">Car</span><span class="box small"></span>
												</div>
												<div class="entries-row">
													<span class="kv">Entrades</span><span class="box"></span>
												</div>
											</div>
										{/each}
									</div>
								</div>
							{/each}
						</div>
					</section>
				{/each}

				{#each losersPages as page, pi}
					<section class="print-page">
						<header class="page-head">
							<div class="page-head-left">
								<img src="/logo-billar.svg" alt="" class="page-logo" />
								<div class="page-head-titles">
									<div class="page-title-main">CAMPIONAT SOCIAL HÀNDICAP{temporadaPretty ? ` ${temporadaPretty}` : ''}</div>
									<div class="page-section">Bracket Repesca {losersPages.length > 1 ? `(${pi + 1}/${losersPages.length})` : ''}</div>
								</div>
							</div>
							{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
						</header>
						<div class="rounds">
							{#each page as [ronda, items]}
								<div class="round-section">
									<h3 class="round-title">{rondaLabel(items[0].bracket, ronda)}</h3>
									<div class="match-grid">
										{#each items as mv}
											<div class="match-cell">
												<div class="cell-head">
													<span class="match-code">{mv.code}</span>
													<span class="arrows">
														<span>↗W: <strong>{mv.winnerDest}</strong></span>
													</span>
												</div>
												<div class="player-row">
													<span class="label">Jug 1</span>
													<span class="line"></span>
													<span class="kv">Dist</span><span class="box small"></span>
													<span class="kv">Car</span><span class="box small"></span>
												</div>
												<div class="player-row">
													<span class="label">Jug 2</span>
													<span class="line"></span>
													<span class="kv">Dist</span><span class="box small"></span>
													<span class="kv">Car</span><span class="box small"></span>
												</div>
												<div class="entries-row">
													<span class="kv">Entrades</span><span class="box"></span>
												</div>
											</div>
										{/each}
									</div>
								</div>
							{/each}
						</div>
					</section>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.print-modal-overlay {
		position: fixed; inset: 0; z-index: 100;
		background: rgba(0,0,0,0.6);
		display: flex; align-items: stretch; justify-content: center;
		padding: 1rem;
	}
	.print-modal-card {
		background: white; width: 100%; max-width: 1400px;
		max-height: 100%;
		display: flex; flex-direction: column;
	}
	.print-modal-head {
		display: flex; justify-content: space-between; align-items: center;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #ddd;
	}
	.print-modal-title { font-size: 1.05rem; font-weight: 700; margin: 0; }
	.close-btn {
		font-size: 1.5rem; background: transparent; border: none; cursor: pointer;
	}
	.print-modal-toolbar {
		display: flex; justify-content: space-between; align-items: center;
		padding: 0.5rem 1rem; border-bottom: 1px solid #eee;
		font-size: 0.875rem; color: #444;
	}
	.toolbar-info { display: flex; gap: 0.85rem; align-items: center; flex-wrap: wrap; }
	.toolbar-actions { display: flex; gap: 0.5rem; }
	.count-label { display: inline-flex; align-items: center; gap: 0.35rem; font-weight: 600; }
	.count-input {
		width: 4.5rem; padding: 0.25rem 0.4rem;
		border: 1px solid #333; border-radius: 0;
		font-size: 0.875rem;
	}
	.hint { color: #555; font-size: 0.8125rem; }
	.hint em { font-style: italic; font-weight: 600; color: #1f1f1f; }
	.btn-primary, .btn-secondary {
		padding: 0.4rem 0.85rem; cursor: pointer; font-size: 0.875rem; font-weight: 600;
		border-radius: 0; border: 1px solid #333;
	}
	.btn-primary { background: #1f1f1f; color: white; }
	.btn-secondary { background: white; color: #1f1f1f; }
	.err { color: #a30b1e; font-weight: 600; }

	.print-preview { overflow: auto; flex: 1; padding: 1rem; background: #ececec; }

	.print-page {
		background: white;
		width: 420mm; height: 297mm; /* A3 landscape */
		padding: 8mm 10mm;
		margin: 0 auto 1rem auto;
		box-sizing: border-box;
		display: flex; flex-direction: column;
		page-break-after: always;
		break-after: page;
	}
	.print-page:last-child { page-break-after: auto; break-after: auto; }

	.page-head {
		display: flex; justify-content: space-between; align-items: center;
		border-bottom: 2px solid #1f1f1f; padding-bottom: 4mm; margin-bottom: 4mm;
		gap: 6mm;
	}
	.page-head-left {
		display: flex; align-items: center; gap: 5mm; min-width: 0;
	}
	.page-logo {
		height: 18mm; width: auto; flex: none;
	}
	.page-head-titles { display: flex; flex-direction: column; gap: 1mm; min-width: 0; }
	.page-title-main {
		font-weight: 800; font-size: 16pt;
		letter-spacing: 0.02em; line-height: 1.1;
		text-transform: uppercase;
	}
	.page-section {
		font-size: 11pt; color: #444; font-weight: 600;
		letter-spacing: 0.04em; text-transform: uppercase;
	}
	.page-sub { font-size: 10pt; color: #555; text-align: right; }

	.rounds {
		display: flex; flex-direction: column; gap: 4mm; flex: 1;
		overflow: hidden;
	}
	.round-section { display: flex; flex-direction: column; gap: 2mm; }
	.round-title {
		font-size: 10pt; font-weight: 700; letter-spacing: 0.05em;
		text-transform: uppercase; color: #1f1f1f;
		border-left: 4px solid #1f1f1f; padding-left: 3mm;
		margin: 0;
	}
	.match-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(70mm, 1fr));
		gap: 3mm;
	}
	.match-cell {
		border: 1.5px solid #1f1f1f;
		padding: 2mm 2.5mm;
		display: flex; flex-direction: column; gap: 1.5mm;
		min-height: 32mm;
		font-size: 9pt;
	}
	.cell-head {
		display: flex; justify-content: space-between; align-items: baseline;
		font-size: 8.5pt;
		border-bottom: 1px solid #999;
		padding-bottom: 1mm;
	}
	.match-code { font-weight: 800; font-size: 11pt; letter-spacing: 0.04em; }
	.arrows {
		display: flex; gap: 3mm; flex-wrap: wrap; font-size: 8pt; color: #333;
	}
	.arrows strong { font-weight: 700; }

	.player-row, .entries-row {
		display: flex; align-items: center; gap: 1.5mm;
		font-size: 8pt;
	}
	.label {
		font-weight: 700; font-size: 7.5pt; text-transform: uppercase;
		color: #555; min-width: 11mm;
	}
	.kv { font-size: 7.5pt; color: #555; font-weight: 600; }
	.line {
		flex: 1; border-bottom: 1px solid #1f1f1f; height: 5mm;
	}
	.box {
		display: inline-block;
		border: 1px solid #1f1f1f;
		height: 5mm; width: 14mm;
	}
	.box.small { width: 9mm; }

	@media print {
		.no-print { display: none !important; }
		.print-modal-overlay {
			position: static; background: white; padding: 0;
		}
		.print-modal-card { max-width: none; max-height: none; }
		.print-preview { background: white; padding: 0; overflow: visible; }
		.print-page {
			margin: 0;
			page-break-after: always;
			break-after: page;
			box-shadow: none;
		}
		@page { size: A3 landscape; margin: 0; }
		:global(body) { background: white; }
	}
</style>
