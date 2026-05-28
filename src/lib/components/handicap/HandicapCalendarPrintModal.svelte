<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase } from '$lib/supabaseClient';
	import {
		generateDoublEliminationBracket,
		type ParticipantInput
	} from '$lib/utils/handicap-bracket-generator';
	import {
		preSchedulingForBracket,
		type ScheduledMatch
	} from '$lib/utils/handicap-pre-scheduler';
	import { printPortal } from '$lib/utils/print-portal';
	import { loadLogoDataUrl } from '$lib/utils/load-logo';

	export let participantCount: number | null = null;
	export let eventNom: string = '';
	export let eventTemporada: string = '';
	export let onClose: () => void = () => {};

	$: temporadaPretty = (eventTemporada || '').replace('-', '/');

	let logoDataUrl = '';
	let loading = true;
	let error: string | null = null;
	let inputCount = participantCount ?? 32;

	// Cada slot del calendari (dia/hora/billar). Si té match assignat,
	// inclou codi i destins; si no, queda buit.
	type CalRow = {
		date: Date;
		hora: string;
		billar: number;
		code: string | null;
		bracket: 'winners' | 'losers' | 'grand_final' | null;
		winnerDest: string | null;
		loserDest: string | null;
	};
	let rows: CalRow[] = [];

	onMount(async () => {
		logoDataUrl = await loadLogoDataUrl();
		await loadAll();
	});

	async function regenerate() {
		await loadAll();
	}

	function ymd(d: Date): string {
		return d.toISOString().slice(0, 10);
	}

	async function loadAll() {
		loading = true;
		error = null;
		rows = [];

		try {
			if (!inputCount || inputCount < 2) {
				error = 'Cal indicar un nombre de participants ≥ 2.';
				loading = false;
				return;
			}

			const fakes: ParticipantInput[] = Array.from({ length: inputCount }, (_, i) => ({
				id: `fake-${i + 1}`,
				seed: i + 1,
				distancia: 0
			}));
			const result = generateDoublEliminationBracket('preview', fakes);
			const slots = result.slots.map(s => ({
				id: s.id,
				bracket_type: s.bracket_type,
				ronda: s.ronda,
				posicio: s.posicio
			}));
			const matches = result.matches
				.filter(m => m.estat !== 'bye')
				.map(m => ({
					id: m.id,
					slot1_id: m.slot1_id,
					slot2_id: m.slot2_id,
					winner_slot_dest_id: m.winner_slot_dest_id,
					loser_slot_dest_id: m.loser_slot_dest_id,
					estat: m.estat
				}));

			const { data: ev } = await supabase
				.from('events')
				.select('id, data_inici, data_fi')
				.eq('tipus_competicio', 'handicap')
				.eq('actiu', true)
				.limit(1)
				.maybeSingle();
			if (!ev?.data_inici || !ev?.data_fi) {
				error = "No s'ha trobat cap event hàndicap actiu amb dates configurades.";
				loading = false;
				return;
			}
			const { data: cfg } = await supabase
				.from('handicap_config')
				.select('horaris_extra')
				.eq('event_id', ev.id)
				.maybeSingle();
			const horarisExtra = cfg?.horaris_extra ?? null;

			const scheduled = preSchedulingForBracket(slots, matches, {
				dataInici: new Date(ev.data_inici),
				dataFi: new Date(ev.data_fi),
				horesEstandard: ['18:00', '19:00'],
				horarisExtra,
				billars: 3
			});

			const order: Record<string, number> = { winners: 0, losers: 1, grand_final: 2 };
			const slotById = new Map(slots.map(s => [s.id, s]));
			const enriched = matches.map(m => {
				const s = slotById.get(m.slot1_id);
				return {
					m,
					bracket: (s?.bracket_type ?? 'winners') as CalRow['bracket'],
					ronda: s?.ronda ?? 0,
					posicio: s?.posicio ?? 0
				};
			}).sort((a, b) => {
				if (a.bracket !== b.bracket) return order[a.bracket] - order[b.bracket];
				if (a.ronda !== b.ronda) return a.ronda - b.ronda;
				return a.posicio - b.posicio;
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

			// Map slot_id → match (per saber a quin match va el winner/loser dest)
			const matchBySlot = new Map<string, typeof matches[number]>();
			for (const m of matches) {
				matchBySlot.set(m.slot1_id, m);
				matchBySlot.set(m.slot2_id, m);
			}
			const destinationCode = (slotId: string | null): string | null => {
				if (!slotId) return null;
				const m = matchBySlot.get(slotId);
				if (!m) return null;
				return codeByMatchId.get(m.id) ?? null;
			};

			// Mapa slotKey → info de match (si n'hi ha)
			type MatchInfo = {
				code: string;
				bracket: NonNullable<CalRow['bracket']>;
				winnerDest: string | null;
				loserDest: string | null;
			};
			const matchAtSlot = new Map<string, MatchInfo>();
			for (const e of enriched) {
				const sched = scheduled.get(e.m.id);
				if (!sched) continue;
				const key = `${ymd(sched.dataProgramada)}|${sched.horaInici}|${sched.taulaAssignada}`;
				matchAtSlot.set(key, {
					code: codeByMatchId.get(e.m.id) ?? '?',
					bracket: e.bracket as MatchInfo['bracket'],
					winnerDest: destinationCode(e.m.winner_slot_dest_id),
					loserDest: destinationCode(e.m.loser_slot_dest_id)
				});
			}

			// Generar TOTS els slots (dia × hora × billar) entre data_inici i data_fi
			// per al rang amb almenys un match programat.
			const allDates = [...new Set(
				[...scheduled.values()].map(s => ymd(s.dataProgramada))
			)].sort();
			if (allDates.length === 0) {
				rows = [];
				loading = false;
				return;
			}
			const minDate = new Date(allDates[0]);
			const maxDate = new Date(allDates[allDates.length - 1]);
			const dies = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];
			const diesActius = ['dl', 'dt', 'dc', 'dj', 'dv'];

			const tmp: CalRow[] = [];
			for (let d = new Date(minDate); d <= maxDate; d.setDate(d.getDate() + 1)) {
				const codi = dies[d.getDay()];
				if (!diesActius.includes(codi)) continue;
				const hores = [...['18:00', '19:00']];
				if (horarisExtra && horarisExtra.dies.includes(codi)) {
					hores.unshift(horarisExtra.franja);
				}
				for (const h of hores) {
					for (let b = 1; b <= 3; b++) {
						const key = `${ymd(d)}|${h}|${b}`;
						const m = matchAtSlot.get(key) ?? null;
						tmp.push({
							date: new Date(d),
							hora: h,
							billar: b,
							code: m?.code ?? null,
							bracket: m?.bracket ?? null,
							winnerDest: m?.winnerDest ?? null,
							loserDest: m?.loserDest ?? null
						});
					}
				}
			}
			rows = tmp;
			loading = false;
		} catch (e: any) {
			error = e.message ?? 'Error generant el calendari';
			loading = false;
		}
	}

	function diaNom(d: Date): string {
		return ['Diumenge', 'Dilluns', 'Dimarts', 'Dimecres', 'Dijous', 'Divendres', 'Dissabte'][d.getDay()];
	}
	function dateLabel(d: Date): string {
		const dd = String(d.getDate()).padStart(2, '0');
		const mm = String(d.getMonth() + 1).padStart(2, '0');
		return `${dd}/${mm}`;
	}

	// Agrupem rows per dia → hora per als rowspans
	type GroupHour = { hora: string; items: CalRow[] };
	type GroupDay = { date: Date; total: number; hours: GroupHour[] };
	$: groupedDays = (() => {
		const byDay = new Map<string, GroupDay>();
		for (const r of rows) {
			const key = ymd(r.date);
			let gd = byDay.get(key);
			if (!gd) {
				gd = { date: r.date, total: 0, hours: [] };
				byDay.set(key, gd);
			}
			let gh = gd.hours.find(h => h.hora === r.hora);
			if (!gh) {
				gh = { hora: r.hora, items: [] };
				gd.hours.push(gh);
			}
			gh.items.push(r);
			gd.total++;
		}
		return [...byDay.values()].sort((a, b) => a.date.getTime() - b.date.getTime());
	})();

	// Per a 2 columnes: dividim els dies en dues meitats balancejades
	let columns: 1 | 2 = 2;
	$: splitDays = (() => {
		if (columns === 1) return [groupedDays];
		const total = groupedDays.reduce((a, g) => a + g.total, 0);
		const target = total / 2;
		const left: GroupDay[] = [];
		const right: GroupDay[] = [];
		let acc = 0;
		for (const g of groupedDays) {
			if (acc < target) {
				left.push(g);
				acc += g.total;
			} else {
				right.push(g);
			}
		}
		return [left, right];
	})();

	function codeColorClass(bracket: CalRow['bracket']): string {
		if (!bracket) return '';
		return bracket === 'winners' ? 'code-w' : bracket === 'losers' ? 'code-l' : 'code-gf';
	}

	function doPrint() {
		const previewEl = document.querySelector('.print-portal .preview');
		if (!previewEl) {
			window.print();
			return;
		}
		const logoUrl = `${window.location.origin}${base}/logo.png`;
		const innerHTML = previewEl.innerHTML.replace(
			/src="(?!data:)[^"]*logo\.png"/g,
			`src="${logoUrl}"`
		);

		const w = window.open('', '_blank', 'width=1100,height=800');
		if (!w) {
			alert("No s'ha pogut obrir la finestra d'impressió. Permet finestres emergents.");
			return;
		}

		const css = String.raw`
			/* A3 portrait per encabir més slots verticalment a 2 columnes. */
			@page { size: A3 portrait; margin: 8mm; }
			@page { size: 297mm 420mm; margin: 8mm; }
			* { box-sizing: border-box; }
			html, body { margin: 0; padding: 0; background: white; font-family: 'Helvetica Neue', Arial, sans-serif; color: #1f1f1f; }
			.print-page {
				background: white;
				padding: 0;
				margin: 0;
				display: flex; flex-direction: column;
				page-break-after: always;
			}
			.print-page:last-child { page-break-after: auto; }
			.page-head {
				display: flex; justify-content: space-between; align-items: center;
				border-bottom: 2px solid #1f1f1f; padding-bottom: 3mm; margin-bottom: 4mm; gap: 6mm;
			}
			.page-head-left { display: flex; align-items: center; gap: 5mm; }
			.page-logo { height: 14mm; width: 10mm; object-fit: contain; flex: none; }
			.page-title-main { font-weight: 800; font-size: 13pt; letter-spacing: 0.02em; text-transform: uppercase; }
			.page-section { font-size: 9pt; color: #444; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }
			.page-sub { font-size: 8pt; color: #555; }
			.two-cols { display: flex; gap: 5mm; }
			.col { flex: 1; min-width: 0; }
			.cal-table {
				width: 100%; border-collapse: collapse;
				font-size: 10pt;
			}
			.cal-table th, .cal-table td {
				border: 1px solid #333;
				padding: 1.2mm 1.5mm;
				text-align: center;
				vertical-align: middle;
			}
			.cal-table th {
				background: #e8e8e8;
				font-weight: 700; font-size: 8pt;
				text-transform: uppercase; letter-spacing: 0.04em;
				padding: 1.5mm 1mm;
			}
			.day-cell {
				background: #f5f5f5;
				font-weight: 700; font-size: 9pt;
				border-right: 2px solid #333;
				white-space: nowrap;
			}
			.day-cell .d-num { font-size: 11pt; font-weight: 800; }
			.day-cell .d-name { font-size: 7.5pt; color: #555; font-weight: 600; }
			.hour-cell {
				background: #fafafa;
				font-weight: 700; font-size: 10pt;
				border-right: 2px solid #333;
			}
			.billar-cell { font-weight: 700; font-size: 9pt; background: #fcfcfc; width: 9mm; }
			.code-cell { font-weight: 800; font-size: 9pt; width: 14mm; }
			.code-w { color: #1d6e3a; }
			.code-l { color: #a30b1e; }
			.code-gf { color: #6b3eb8; }
			.dest-cell { font-size: 7.5pt; font-weight: 600; min-width: 16mm; text-align: left; line-height: 1.25; padding: 1mm 1.5mm; }
			.dest-cell .arrow-win, .dest-cell .arrow-lose { display: block; }
			.dest-cell strong { font-weight: 800; }
			.arrow-win { color: #1d6e3a; }
			.arrow-lose { color: #a30b1e; }
			.player-cell { font-size: 9pt; min-width: 30mm; }
			.player-line { display: inline-block; width: 100%; border-bottom: 1px solid #1f1f1f; height: 4mm; }
		`;

		const scriptOpen = '<' + 'script>';
		const scriptClose = '<' + '/script>';
		const printScript = scriptOpen +
			"window.addEventListener('load', function () {" +
			"  var imgs = Array.from(document.images);" +
			"  var ready = imgs.length === 0 ? Promise.resolve() :" +
			"    Promise.all(imgs.map(function (img) { return img.complete ? null : new Promise(function (r) { img.onload = img.onerror = r; }); }));" +
			"  ready.then(function () { setTimeout(function () { window.print(); }, 100); });" +
			"});" +
			scriptClose;

		const html = `<!DOCTYPE html>
<html lang="ca"><head><meta charset="utf-8" /><title>Calendari — ${(eventNom || 'Hàndicap').replace(/[<>&"]/g, '')}</title><style>${css}</style></head>
<body>${innerHTML}${printScript}</body></html>`;
		w.document.open();
		w.document.write(html);
		w.document.close();
	}
</script>

<div class="modal-overlay print-portal" use:printPortal on:click|self={onClose} role="presentation">
	<div class="modal-card" role="dialog" aria-modal="true">
		<div class="modal-head no-print">
			<h2 class="modal-title">Calendari A3 vertical — pre-programació hàndicap</h2>
			<button type="button" class="close-btn" on:click={onClose} aria-label="Tancar">×</button>
		</div>

		<div class="modal-toolbar no-print">
			<div class="toolbar-info">
				{#if loading}
					<span>Carregant…</span>
				{:else if error}
					<span class="err">{error}</span>
				{:else}
					<span>{rows.length} partides programades</span>
					<label class="count-label">
						Jugadors:
						<input type="number" min="2" max="128" bind:value={inputCount} class="count-input" />
					</label>
					<label class="count-label">
						Format:
						<select bind:value={columns} class="count-input">
							<option value={2}>2 columnes (compacte)</option>
							<option value={1}>1 columna (text gran)</option>
						</select>
					</label>
					<button type="button" class="btn-secondary" on:click={regenerate} disabled={loading}>Recalcular</button>
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
			<div class="preview">
				<section class="print-page">
					<header class="page-head">
						<div class="page-head-left">
							<img src={logoDataUrl || `${base}/logo.png`} alt="" class="page-logo" />
							<div>
								<div class="page-title-main">CAMPIONAT SOCIAL HÀNDICAP{temporadaPretty ? ` ${temporadaPretty}` : ''}</div>
								<div class="page-section">Calendari de partides ({rows.length})</div>
							</div>
						</div>
						{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
					</header>

					<div class="two-cols">
						{#each splitDays as colDays}
							<div class="col">
								<table class="cal-table">
									<thead>
										<tr>
											<th>Dia</th>
											<th>Hora</th>
											<th>B</th>
											<th>Match</th>
											<th>Destí</th>
											<th>Jugador 1</th>
											<th>Jugador 2</th>
										</tr>
									</thead>
									<tbody>
										{#each colDays as gd}
											{#each gd.hours as gh, hIdx}
												{#each gh.items as it, iIdx}
													<tr>
														{#if hIdx === 0 && iIdx === 0}
															<td class="day-cell" rowspan={gd.total}>
																<div class="d-num">{dateLabel(gd.date)}</div>
																<div class="d-name">{diaNom(gd.date)}</div>
															</td>
														{/if}
														{#if iIdx === 0}
															<td class="hour-cell" rowspan={gh.items.length}>{gh.hora}</td>
														{/if}
														<td class="billar-cell">B{it.billar}</td>
														<td class="code-cell {codeColorClass(it.bracket)}">{it.code ?? ''}</td>
														<td class="dest-cell">
															{#if it.winnerDest}<div class="arrow-win">↗G: <strong>{it.winnerDest}</strong></div>{/if}
															{#if it.loserDest}<div class="arrow-lose">↘P: <strong>{it.loserDest}</strong></div>{/if}
														</td>
														<td class="player-cell"><span class="player-line"></span></td>
														<td class="player-cell"><span class="player-line"></span></td>
													</tr>
												{/each}
											{/each}
										{/each}
									</tbody>
								</table>
							</div>
						{/each}
					</div>
				</section>
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
		background: white; width: 100%; max-width: 1400px;
		max-height: 100%; display: flex; flex-direction: column;
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
	.count-label { display: inline-flex; align-items: center; gap: 0.35rem; font-weight: 600; }
	.count-input {
		padding: 0.25rem 0.4rem;
		border: 1px solid #333; border-radius: 0;
		font-size: 0.8125rem; background: white;
	}

	.preview { overflow: auto; flex: 1; padding: 1rem; background: #ececec; }

	.print-page {
		background: white;
		width: 297mm; min-height: 410mm; /* A3 portrait (297×420mm) */
		padding: 8mm 8mm 6mm 8mm;
		margin: 0 auto 1rem auto;
		box-sizing: border-box;
		display: flex; flex-direction: column;
	}

	.page-head {
		display: flex; justify-content: space-between; align-items: center;
		border-bottom: 2px solid #1f1f1f; padding-bottom: 3mm; margin-bottom: 4mm; gap: 6mm;
	}
	.page-head-left { display: flex; align-items: center; gap: 5mm; }
	.page-logo {
		height: 14mm; width: 10mm; flex: none;
		object-fit: contain;
		display: inline-flex; align-items: center; justify-content: center;
	}
	.page-title-main { font-weight: 800; font-size: 13pt; letter-spacing: 0.02em; text-transform: uppercase; }
	.page-section { font-size: 9pt; color: #444; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }
	.page-sub { font-size: 8pt; color: #555; }

	.two-cols { display: flex; gap: 5mm; }
	.col { flex: 1; min-width: 0; }
	.cal-table { width: 100%; border-collapse: collapse; font-size: 10pt; }
	.cal-table th, .cal-table td {
		border: 1px solid #333;
		padding: 1.2mm 1.5mm;
		text-align: center; vertical-align: middle;
	}
	.cal-table th {
		background: #e8e8e8;
		font-weight: 700; font-size: 8pt;
		text-transform: uppercase; letter-spacing: 0.04em;
		padding: 1.5mm 1mm;
	}
	.day-cell {
		background: #f5f5f5;
		font-weight: 700; font-size: 9pt;
		border-right: 2px solid #333;
		white-space: nowrap;
	}
	.day-cell .d-num { font-size: 11pt; font-weight: 800; }
	.day-cell .d-name { font-size: 7.5pt; color: #555; font-weight: 600; }
	.hour-cell {
		background: #fafafa;
		font-weight: 700; font-size: 10pt;
		border-right: 2px solid #333;
	}
	.billar-cell { font-weight: 700; font-size: 9pt; background: #fcfcfc; }
	.code-cell { font-weight: 800; font-size: 9pt; }
	.code-w { color: #1d6e3a; }
	.code-l { color: #a30b1e; }
	.code-gf { color: #6b3eb8; }
	.dest-cell { font-size: 7.5pt; font-weight: 600; min-width: 16mm; text-align: left; line-height: 1.25; padding: 1mm 1.5mm; }
	.dest-cell .arrow-win, .dest-cell .arrow-lose { display: block; }
	.dest-cell strong { font-weight: 800; }
	.arrow-win { color: #1d6e3a; }
	.arrow-lose { color: #a30b1e; }
	.player-cell { font-size: 9pt; min-width: 30mm; }
	.player-line { display: inline-block; width: 100%; border-bottom: 1px solid #1f1f1f; height: 4mm; }

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
		.modal-overlay { display: block !important; position: static !important; background: white !important; padding: 0 !important; }
		.modal-card { display: block !important; max-width: none !important; max-height: none !important; box-shadow: none !important; }
		.preview { display: block !important; background: white !important; padding: 0 !important; overflow: visible !important; flex: none !important; }
		.print-page { margin: 0 !important; box-shadow: none !important; width: auto !important; min-height: 0 !important; }
		@page { size: A3 portrait; margin: 8mm; }
		@page { size: 297mm 420mm; margin: 8mm; }
		:global(body) { background: white !important; margin: 0 !important; }
		:global(html) { background: white !important; }
	}
</style>
