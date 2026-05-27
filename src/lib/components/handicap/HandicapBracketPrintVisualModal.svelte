<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase } from '$lib/supabaseClient';
	import { generateDoublEliminationBracket } from '$lib/utils/handicap-bracket-generator';
	import { printPortal } from '$lib/utils/print-portal';

	export let eventId: string | null = null;
	export let participantCount: number | null = null;
	export let eventNom: string = '';
	export let eventTemporada: string = '';
	export let onClose: () => void = () => {};

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
		posicioMin: number;
		slot1Pos: number;
		slot2Pos: number;
		winnerDest: string;
		loserDest: string;
	};

	type PageDef = {
		title: string;
		sectionLabel: string;
		columns: Array<{ rondaLabel: string; matches: MatchView[] }>;
	};

	let loading = true;
	let error: string | null = null;
	let pages: PageDef[] = [];

	let inputCount = participantCount ?? 32;

	onMount(loadAll);

	async function regenerate() {
		if (eventId) return;
		await loadAll();
	}

	async function loadAll() {
		loading = true;
		error = null;
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
				const fakes = Array.from({ length: inputCount }, (_, i) => ({
					id: `fake-${i + 1}`,
					seed: i + 1,
					distancia: 0
				}));
				const result = generateDoublEliminationBracket('preview', fakes);
				slots = result.slots.map(s => ({
					id: s.id, bracket_type: s.bracket_type, ronda: s.ronda, posicio: s.posicio
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

			const matchViews: MatchView[] = enriched.map(e => {
				const s1 = slotById.get(e.m.slot1_id);
				const s2 = slotById.get(e.m.slot2_id);
				return {
					id: e.m.id,
					code: codeByMatchId.get(e.m.id) ?? '?',
					bracket: e.bracket,
					ronda: e.ronda,
					posicioMin: e.posicioMin,
					slot1Pos: s1?.posicio ?? 0,
					slot2Pos: s2?.posicio ?? 0,
					winnerDest: destinationCode(e.m.winner_slot_dest_id),
					loserDest: destinationCode(e.m.loser_slot_dest_id)
				};
			});

			pages = buildPages(matchViews);
			loading = false;
		} catch (e: any) {
			error = e.message || 'Error carregant el bracket';
			loading = false;
		}
	}

	// Construeix les pàgines del bracket visual:
	//   - Per cada bracket (winners, losers), agrupa per ronda.
	//   - Si la primera ronda té >8 matches, divideix tot el bracket en TOP / BOTTOM
	//     (top = primera meitat de matches per ronda; bottom = segona meitat).
	//   - La grand_final s'afegeix al final de la pàgina de winners (últim full).
	function buildPages(mvs: MatchView[]): PageDef[] {
		const out: PageDef[] = [];

		const winnersAll = mvs.filter(m => m.bracket === 'winners');
		const losersAll = mvs.filter(m => m.bracket === 'losers');
		const gfAll = mvs.filter(m => m.bracket === 'grand_final');

		const winnersByRonda = groupByRonda(winnersAll);
		const losersByRonda = groupByRonda(losersAll);

		const winnersPages = splitBracketPages('Bracket Principal', 'winners', winnersByRonda);
		const losersPages = splitBracketPages('Bracket Repesca', 'losers', losersByRonda);

		// Encolumnar Grand Final al final de l'últim full de winners
		if (gfAll.length > 0 && winnersPages.length > 0) {
			winnersPages[winnersPages.length - 1].columns.push({
				rondaLabel: 'Gran Final',
				matches: gfAll.sort((a, b) => a.ronda - b.ronda)
			});
		}

		return [...winnersPages, ...losersPages];
	}

	function groupByRonda(arr: MatchView[]): Array<[number, MatchView[]]> {
		const map = new Map<number, MatchView[]>();
		for (const m of arr) {
			if (!map.has(m.ronda)) map.set(m.ronda, []);
			map.get(m.ronda)!.push(m);
		}
		// Ordenar cada ronda per posicioMin
		for (const arr of map.values()) {
			arr.sort((a, b) => a.posicioMin - b.posicioMin);
		}
		return [...map.entries()].sort((a, b) => a[0] - b[0]);
	}

	function splitBracketPages(
		baseTitle: string,
		bracket: Bracket,
		rondesSorted: Array<[number, MatchView[]]>
	): PageDef[] {
		if (rondesSorted.length === 0) return [];
		const r1Count = rondesSorted[0][1].length;
		if (r1Count <= 8) {
			return [{
				title: baseTitle,
				sectionLabel: baseTitle,
				columns: rondesSorted.map(([r, matches]) => ({
					rondaLabel: rondaLabel(bracket, r),
					matches
				}))
			}];
		}
		// Top half = primera meitat de matches per ronda
		const topCols: Array<{ rondaLabel: string; matches: MatchView[] }> = [];
		const bottomCols: Array<{ rondaLabel: string; matches: MatchView[] }> = [];
		for (const [r, matches] of rondesSorted) {
			const half = Math.ceil(matches.length / 2);
			topCols.push({ rondaLabel: rondaLabel(bracket, r), matches: matches.slice(0, half) });
			bottomCols.push({ rondaLabel: rondaLabel(bracket, r), matches: matches.slice(half) });
		}
		// Si l'última ronda (final del bracket) acaba al top half buit del bottom, ho deixem així:
		// no és gran problema visual perquè el codi indica on entra cada guanyador.
		const cleanBottom = bottomCols.filter(c => c.matches.length > 0);
		return [
			{ title: baseTitle, sectionLabel: `${baseTitle} — Meitat superior`, columns: topCols },
			{ title: baseTitle, sectionLabel: `${baseTitle} — Meitat inferior`, columns: cleanBottom }
		];
	}

	function rondaLabel(bracket: Bracket, num: number): string {
		const prefix = bracket === 'winners' ? 'R' : 'L';
		return `${prefix}${num}`;
	}

	function doPrint() {
		const previewEl = document.querySelector('.print-portal .preview');
		if (!previewEl) {
			window.print();
			return;
		}

		const logoUrl = `${window.location.origin}${base}/logo-billar.svg`;
		const innerHTML = previewEl.innerHTML.replace(
			/src="[^"]*logo-billar\.svg"/g,
			`src="${logoUrl}"`
		);

		const w = window.open('', '_blank', 'width=1100,height=800');
		if (!w) {
			alert("No s'ha pogut obrir la finestra d'impressió. Permet finestres emergents per a aquest lloc.");
			return;
		}

		const css = String.raw`
			@page { size: A3 landscape; margin: 0; }
			@page { size: 420mm 297mm; margin: 0; }
			* { box-sizing: border-box; }
			html, body { margin: 0; padding: 0; background: white; font-family: 'Helvetica Neue', Arial, sans-serif; color: #1f1f1f; }
			.print-page {
				background: white;
				width: 420mm; height: 297mm;
				padding: 8mm 10mm;
				margin: 0;
				box-sizing: border-box;
				display: flex; flex-direction: column;
				page-break-after: always;
				break-after: page;
			}
			.print-page:last-child { page-break-after: auto; break-after: auto; }
			.page-head {
				display: flex; justify-content: space-between; align-items: center;
				border-bottom: 2px solid #1f1f1f; padding-bottom: 3mm; margin-bottom: 3mm; gap: 6mm; flex: none;
			}
			.page-head-left { display: flex; align-items: center; gap: 5mm; min-width: 0; }
			.page-logo { height: 16mm; width: 11mm; flex: none; object-fit: contain; }
			.page-head-titles { display: flex; flex-direction: column; gap: 1mm; min-width: 0; }
			.page-title-main { font-weight: 800; font-size: 14pt; letter-spacing: 0.02em; line-height: 1.1; text-transform: uppercase; }
			.page-section { font-size: 10pt; color: #444; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
			.page-sub { font-size: 9pt; color: #555; text-align: right; }
			.bracket-flow { display: flex; flex: 1; gap: 4mm; min-height: 0; }
			.round-col { display: flex; flex-direction: column; flex: 1; min-width: 0; gap: 3mm; }
			.round-label {
				font-size: 9pt; font-weight: 700; text-transform: uppercase;
				letter-spacing: 0.06em; color: #1f1f1f;
				border-bottom: 1.5px solid #1f1f1f; padding-bottom: 1.5mm; text-align: center;
			}
			.round-matches { flex: 1; display: flex; flex-direction: column; justify-content: space-around; gap: 2mm; }
			.match-cell {
				border: 1.5px solid #1f1f1f;
				padding: 1.5mm 2mm;
				display: flex; flex-direction: column; gap: 1mm;
				font-size: 8pt; min-height: 24mm;
			}
			.cell-head {
				display: flex; justify-content: space-between; align-items: baseline;
				font-size: 7.5pt; border-bottom: 1px solid #999;
				padding-bottom: 0.5mm; gap: 1.5mm;
			}
			.match-code { font-weight: 800; font-size: 9.5pt; letter-spacing: 0.04em; }
			.arrows { display: flex; gap: 1.5mm; flex-wrap: wrap; font-size: 7pt; color: #333; }
			.arrows strong { font-weight: 700; }
			.player-row, .entries-row { display: flex; align-items: center; gap: 1mm; font-size: 7.5pt; }
			.label { font-weight: 700; font-size: 7pt; color: #555; min-width: 4mm; }
			.kv { font-size: 7pt; color: #555; font-weight: 600; }
			.line { flex: 1; border-bottom: 1px solid #1f1f1f; height: 4.5mm; }
			.box { display: inline-block; border: 1px solid #1f1f1f; height: 4.5mm; width: 10mm; }
			.box.small { width: 7mm; }
		`;

		const scriptOpen = '<' + 'script>';
		const scriptClose = '<' + '/script>';
		const printScript = scriptOpen +
			"window.addEventListener('load', function () {" +
			"  var imgs = Array.from(document.images);" +
			"  var ready = imgs.length === 0 ? Promise.resolve() :" +
			"    Promise.all(imgs.map(function (img) {" +
			"      return img.complete ? null : new Promise(function (r) { img.onload = img.onerror = r; });" +
			"    }));" +
			"  ready.then(function () { setTimeout(function () { window.print(); }, 100); });" +
			"});" +
			scriptClose;

		const html = `<!DOCTYPE html>
<html lang="ca">
<head>
<meta charset="utf-8" />
<title>Bracket visual — ${(eventNom || 'Hàndicap').replace(/[<>&"]/g, '')}</title>
<style>${css}</style>
</head>
<body>
${innerHTML}
${printScript}
</body>
</html>`;

		w.document.open();
		w.document.write(html);
		w.document.close();
	}
</script>

<div class="modal-overlay print-portal" use:printPortal on:click|self={onClose} role="presentation">
	<div class="modal-card" role="dialog" aria-modal="true">
		<div class="modal-head no-print">
			<h2 class="modal-title">Imprimir bracket VISUAL per a la pissarra</h2>
			<button type="button" class="close-btn" on:click={onClose} aria-label="Tancar">×</button>
		</div>

		<div class="modal-toolbar no-print">
			<div class="toolbar-info">
				{#if loading}
					<span>Carregant bracket…</span>
				{:else if error}
					<span class="err">{error}</span>
				{:else}
					<span>{pages.length} fulls A3 landscape</span>
					<span class="hint">
						Al diàleg d'imprimir tria <strong>A3</strong> i orientació <strong>Apaisat / Horitzontal</strong>.
						Per a PDF: destinació <em>Guardar com a PDF</em>.
					</span>
				{/if}
				{#if !eventId}
					<label class="count-label">
						Jugadors:
						<input type="number" min="2" max="128" bind:value={inputCount} class="count-input" />
					</label>
					<button type="button" class="btn-secondary" on:click={regenerate} disabled={loading || inputCount < 2}>
						Recalcular
					</button>
				{/if}
			</div>
			<div class="toolbar-actions">
				<button type="button" class="btn-secondary" on:click={onClose}>Tancar</button>
				<button type="button" class="btn-primary" on:click={doPrint} disabled={loading || !!error}>
					Imprimir / Desar PDF
				</button>
			</div>
		</div>

		{#if !loading && !error}
			<div class="print-warning no-print">
				⚠ <strong>Important:</strong> al diàleg d'imprimir, tria <strong>paper A3</strong> i orientació <strong>Apaisat / Horitzontal</strong>. Si el navegador imprimeix amb A4 vertical, el bracket sortirà tallat.
			</div>
			<div class="preview">
				{#each pages as page}
					<section class="print-page">
						<header class="page-head">
							<div class="page-head-left">
								<img src="/logo-billar.svg" alt="" class="page-logo" />
								<div class="page-head-titles">
									<div class="page-title-main">CAMPIONAT SOCIAL HÀNDICAP{temporadaPretty ? ` ${temporadaPretty}` : ''}</div>
									<div class="page-section">{page.sectionLabel}</div>
								</div>
							</div>
							{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
						</header>

						<div class="bracket-flow">
							{#each page.columns as col}
								<div class="round-col">
									<div class="round-label">{col.rondaLabel}</div>
									<div class="round-matches">
										{#each col.matches as mv}
											<div class="match-cell">
												<div class="cell-head">
													<span class="match-code">{mv.code}</span>
													<span class="arrows">
														<span>↗W:<strong>{mv.winnerDest}</strong></span>
														{#if mv.loserDest !== '—'}
															<span>↘L:<strong>{mv.loserDest}</strong></span>
														{/if}
													</span>
												</div>
												<div class="player-row">
													<span class="label">{mv.bracket === 'winners' && mv.ronda === 1 ? `#${mv.slot1Pos}` : '1'}</span>
													<span class="line"></span>
													<span class="kv">D</span><span class="box small"></span>
													<span class="kv">C</span><span class="box small"></span>
												</div>
												<div class="player-row">
													<span class="label">{mv.bracket === 'winners' && mv.ronda === 1 ? `#${mv.slot2Pos}` : '2'}</span>
													<span class="line"></span>
													<span class="kv">D</span><span class="box small"></span>
													<span class="kv">C</span><span class="box small"></span>
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
	.modal-overlay {
		position: fixed; inset: 0; z-index: 100;
		background: rgba(0,0,0,0.6);
		display: flex; align-items: stretch; justify-content: center;
		padding: 1rem;
	}
	.modal-card {
		background: white; width: 100%; max-width: 1500px;
		max-height: 100%;
		display: flex; flex-direction: column;
	}
	.modal-head {
		display: flex; justify-content: space-between; align-items: center;
		padding: 0.75rem 1rem; border-bottom: 1px solid #ddd;
	}
	.modal-title { font-size: 1.05rem; font-weight: 700; margin: 0; }
	.close-btn { font-size: 1.5rem; background: transparent; border: none; cursor: pointer; }

	.modal-toolbar {
		display: flex; justify-content: space-between; align-items: center;
		padding: 0.5rem 1rem; border-bottom: 1px solid #eee;
		font-size: 0.875rem; color: #444;
		flex-wrap: wrap; gap: 0.5rem;
	}
	.toolbar-info { display: flex; gap: 0.85rem; align-items: center; flex-wrap: wrap; }
	.toolbar-actions { display: flex; gap: 0.5rem; }
	.btn-primary, .btn-secondary {
		padding: 0.4rem 0.85rem; cursor: pointer; font-size: 0.875rem; font-weight: 600;
		border-radius: 0; border: 1px solid #333;
	}
	.btn-primary { background: #1f1f1f; color: white; }
	.btn-secondary { background: white; color: #1f1f1f; }
	.btn-primary:disabled, .btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }
	.err { color: #a30b1e; font-weight: 600; }
	.hint { color: #555; font-size: 0.8125rem; }
	.hint em { font-style: italic; font-weight: 600; color: #1f1f1f; }
	.count-label { display: inline-flex; align-items: center; gap: 0.35rem; font-weight: 600; }
	.count-input { width: 4.5rem; padding: 0.25rem 0.4rem; border: 1px solid #333; border-radius: 0; font-size: 0.875rem; }

	.preview { overflow: auto; flex: 1; padding: 1rem; background: #ececec; }
	.print-warning {
		padding: 0.65rem 1rem;
		background: #fff3cd;
		border-bottom: 1px solid #f0d68c;
		color: #6b4f00;
		font-size: 0.875rem;
		line-height: 1.4;
	}
	.print-warning strong { color: #4d3700; }

	.print-page {
		background: white;
		width: 420mm; height: 297mm;
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
		border-bottom: 2px solid #1f1f1f; padding-bottom: 3mm; margin-bottom: 3mm;
		gap: 6mm; flex: none;
	}
	.page-head-left { display: flex; align-items: center; gap: 5mm; min-width: 0; }
	.page-logo {
		/* viewBox 1024×1536 → ratio 2:3 */
		height: 16mm; width: 11mm; flex: none;
		object-fit: contain;
	}
	.page-head-titles { display: flex; flex-direction: column; gap: 1mm; min-width: 0; }
	.page-title-main { font-weight: 800; font-size: 14pt; letter-spacing: 0.02em; line-height: 1.1; text-transform: uppercase; }
	.page-section { font-size: 10pt; color: #444; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
	.page-sub { font-size: 9pt; color: #555; text-align: right; }

	.bracket-flow {
		display: flex;
		flex: 1;
		gap: 4mm;
		min-height: 0;
	}
	.round-col {
		display: flex; flex-direction: column;
		flex: 1; min-width: 0;
		gap: 3mm;
	}
	.round-label {
		font-size: 9pt; font-weight: 700; text-transform: uppercase;
		letter-spacing: 0.06em; color: #1f1f1f;
		border-bottom: 1.5px solid #1f1f1f;
		padding-bottom: 1.5mm;
		text-align: center;
	}
	.round-matches {
		flex: 1; display: flex; flex-direction: column;
		justify-content: space-around;
		gap: 2mm;
	}
	.match-cell {
		border: 1.5px solid #1f1f1f;
		padding: 1.5mm 2mm;
		display: flex; flex-direction: column; gap: 1mm;
		font-size: 8pt;
		min-height: 24mm;
	}
	.cell-head {
		display: flex; justify-content: space-between; align-items: baseline;
		font-size: 7.5pt;
		border-bottom: 1px solid #999;
		padding-bottom: 0.5mm;
		gap: 1.5mm;
	}
	.match-code { font-weight: 800; font-size: 9.5pt; letter-spacing: 0.04em; }
	.arrows { display: flex; gap: 1.5mm; flex-wrap: wrap; font-size: 7pt; color: #333; }
	.arrows strong { font-weight: 700; }
	.player-row, .entries-row { display: flex; align-items: center; gap: 1mm; font-size: 7.5pt; }
	.label { font-weight: 700; font-size: 7pt; color: #555; min-width: 4mm; }
	.kv { font-size: 7pt; color: #555; font-weight: 600; }
	.line { flex: 1; border-bottom: 1px solid #1f1f1f; height: 4.5mm; }
	.box { display: inline-block; border: 1px solid #1f1f1f; height: 4.5mm; width: 10mm; }
	.box.small { width: 7mm; }

	@media print {
		:global(body > *:not(.print-portal)) { display: none !important; }
		:global(.print-portal) {
			display: block !important;
			position: static !important;
			background: white !important;
			padding: 0 !important;
			inset: auto !important;
			z-index: auto !important;
			width: auto !important;
			height: auto !important;
			max-width: none !important;
			max-height: none !important;
			overflow: visible !important;
		}
		.no-print { display: none !important; }
		.modal-overlay {
			display: block !important;
			position: static !important;
			background: white !important;
			padding: 0 !important;
		}
		.modal-card {
			display: block !important;
			max-width: none !important;
			max-height: none !important;
			width: auto !important;
			height: auto !important;
			box-shadow: none !important;
		}
		.preview {
			display: block !important;
			background: white !important;
			padding: 0 !important;
			overflow: visible !important;
			flex: none !important;
		}
		.print-page {
			margin: 0 !important;
			box-shadow: none !important;
		}
		.print-page:last-child { page-break-after: auto; break-after: auto; }
		@page { size: A3 landscape; margin: 0; }
		@page { size: 420mm 297mm; margin: 0; }
		:global(body) { background: white !important; margin: 0 !important; }
		:global(html) { background: white !important; }
	}
</style>
