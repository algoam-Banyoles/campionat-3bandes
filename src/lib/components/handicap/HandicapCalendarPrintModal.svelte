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

	// Per cada slot (data+hora+billar) → info del match programat
	type SlotCell = {
		code: string;
		bracket: 'winners' | 'losers' | 'grand_final';
		ronda: number;
		jugador1Nom: string | null;
		jugador2Nom: string | null;
	};
	// Estructura: mapWeekDays[weekIdx] = [dies de la setmana]; cellMap[dateISO][hora][billar] = SlotCell
	let weeks: Array<{ start: Date; days: Date[] }> = [];
	let cellMap = new Map<string, SlotCell>(); // key: 'YYYY-MM-DD|HH:MM|B'
	let horesUsades: string[] = ['18:00', '19:00'];
	let billarsUsats: number[] = [1, 2, 3];

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

	function addDays(d: Date, n: number): Date {
		const r = new Date(d);
		r.setDate(r.getDate() + n);
		return r;
	}

	async function loadAll() {
		loading = true;
		error = null;
		weeks = [];
		cellMap = new Map();

		try {
			if (!inputCount || inputCount < 2) {
				error = 'Cal indicar un nombre de participants ≥ 2.';
				loading = false;
				return;
			}

			// Generar bracket fake (estructural). Mateix patró que als altres modals.
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

			// Carregar event actiu per a dates i horaris extra
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

			// Codis seqüencials per match
			const order: Record<string, number> = { winners: 0, losers: 1, grand_final: 2 };
			const slotById = new Map(slots.map(s => [s.id, s]));
			const enriched = matches.map(m => {
				const s = slotById.get(m.slot1_id);
				return {
					m,
					bracket: s?.bracket_type ?? 'winners',
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

			// Omplir cellMap i recollir hores usades
			const horesSet = new Set<string>();
			for (const e of enriched) {
				const sched = scheduled.get(e.m.id);
				if (!sched) continue;
				const key = `${ymd(sched.dataProgramada)}|${sched.horaInici}|${sched.taulaAssignada}`;
				cellMap.set(key, {
					code: codeByMatchId.get(e.m.id) ?? '?',
					bracket: e.bracket,
					ronda: e.ronda,
					jugador1Nom: null,
					jugador2Nom: null
				});
				horesSet.add(sched.horaInici);
			}
			horesUsades = [...horesSet].sort();

			// Construir setmanes (de dilluns a divendres) entre dataInici i dataFi
			const inici = new Date(ev.data_inici);
			const fi = new Date(ev.data_fi);
			// Comencem a dilluns d'aquesta setmana
			let cursor = new Date(inici);
			const dayMonday = cursor.getDay() === 0 ? -6 : 1 - cursor.getDay();
			cursor = addDays(cursor, dayMonday);
			while (cursor <= fi) {
				const days: Date[] = [];
				for (let i = 0; i < 5; i++) days.push(addDays(cursor, i)); // dl..dv
				// Mantenim setmana només si conté algun dia dins el rang i amb match
				const hasMatch = days.some(d => {
					if (d < inici || d > fi) return false;
					for (const h of horesUsades) {
						for (const b of billarsUsats) {
							if (cellMap.has(`${ymd(d)}|${h}|${b}`)) return true;
						}
					}
					return false;
				});
				if (hasMatch) {
					weeks.push({ start: cursor, days });
				}
				cursor = addDays(cursor, 7);
			}
			weeks = weeks; // trigger reactivity

			loading = false;
		} catch (e: any) {
			error = e.message ?? 'Error generant el calendari';
			loading = false;
		}
	}

	function diaNom(d: Date): string {
		return ['Dg', 'Dl', 'Dt', 'Dc', 'Dj', 'Dv', 'Ds'][d.getDay()];
	}
	function dateLabel(d: Date): string {
		const dd = String(d.getDate()).padStart(2, '0');
		const mm = String(d.getMonth() + 1).padStart(2, '0');
		return `${diaNom(d)} ${dd}/${mm}`;
	}
	function cellAt(date: Date, hora: string, billar: number): SlotCell | undefined {
		return cellMap.get(`${ymd(date)}|${hora}|${billar}`);
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
			@page { size: A3 landscape; margin: 0; }
			@page { size: 420mm 297mm; margin: 0; }
			* { box-sizing: border-box; }
			html, body { margin: 0; padding: 0; background: white; font-family: 'Helvetica Neue', Arial, sans-serif; color: #1f1f1f; }
			.print-page {
				background: white;
				width: 420mm; height: 297mm;
				padding: 8mm 10mm;
				margin: 0;
				display: flex; flex-direction: column;
				page-break-after: always;
			}
			.print-page:last-child { page-break-after: auto; }
			.page-head {
				display: flex; justify-content: space-between; align-items: center;
				border-bottom: 2px solid #1f1f1f; padding-bottom: 4mm; margin-bottom: 4mm;
				gap: 6mm;
			}
			.page-head-left { display: flex; align-items: center; gap: 5mm; }
			.page-logo { height: 16mm; width: 11mm; object-fit: contain; flex: none; }
			.page-title-main { font-weight: 800; font-size: 14pt; letter-spacing: 0.02em; text-transform: uppercase; }
			.page-section { font-size: 10pt; color: #444; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }
			.page-sub { font-size: 9pt; color: #555; }
			.cal-grid {
				flex: 1; display: grid;
				grid-template-columns: 22mm repeat(5, 1fr);
				gap: 1.5mm;
				min-height: 0;
			}
			.cal-head, .cal-hour-label, .cal-cell {
				border: 1px solid #1f1f1f;
				padding: 1.5mm;
				font-size: 8pt;
				display: flex; flex-direction: column;
			}
			.cal-head {
				font-weight: 800; font-size: 10pt;
				background: #1f1f1f; color: white;
				justify-content: center; text-align: center;
			}
			.cal-hour-label {
				background: #f0f0f0;
				font-weight: 700; font-size: 9pt;
				justify-content: center; align-items: center;
			}
			.cal-cell { min-height: 30mm; gap: 1mm; }
			.cell-empty { background: repeating-linear-gradient(45deg, #fafafa, #fafafa 3mm, white 3mm, white 6mm); }
			.cell-head {
				display: flex; justify-content: space-between; align-items: baseline;
				font-size: 8pt; font-weight: 700;
				border-bottom: 1px solid #999; padding-bottom: 0.5mm;
			}
			.code-w { color: #1d6e3a; }
			.code-l { color: #a30b1e; }
			.code-gf { color: #6b3eb8; }
			.cell-line { display: flex; align-items: center; gap: 1mm; font-size: 7.5pt; }
			.line { flex: 1; border-bottom: 1px solid #1f1f1f; height: 3.5mm; }
			.kv { font-size: 7pt; color: #555; font-weight: 600; }
			.box { display: inline-block; border: 1px solid #1f1f1f; height: 3.5mm; width: 8mm; }
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
<html lang="ca">
<head><meta charset="utf-8" /><title>Calendari — ${(eventNom || 'Hàndicap').replace(/[<>&"]/g, '')}</title><style>${css}</style></head>
<body>${innerHTML}${printScript}</body>
</html>`;
		w.document.open();
		w.document.write(html);
		w.document.close();
	}
</script>

<div class="modal-overlay print-portal" use:printPortal on:click|self={onClose} role="presentation">
	<div class="modal-card" role="dialog" aria-modal="true">
		<div class="modal-head no-print">
			<h2 class="modal-title">Calendari A3 — pre-programació hàndicap</h2>
			<button type="button" class="close-btn" on:click={onClose} aria-label="Tancar">×</button>
		</div>

		<div class="modal-toolbar no-print">
			<div class="toolbar-info">
				{#if loading}
					<span>Carregant…</span>
				{:else if error}
					<span class="err">{error}</span>
				{:else}
					<span>{weeks.length} setmana(es) · A3 apaisat</span>
					<span class="hint">Al diàleg d'imprimir tria <strong>A3</strong> i orientació <strong>Apaisat</strong>.</span>
				{/if}
				<label class="count-label">
					Jugadors:
					<input type="number" min="2" max="128" bind:value={inputCount} class="count-input" />
				</label>
				<button type="button" class="btn-secondary" on:click={regenerate} disabled={loading}>Recalcular</button>
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
				{#each weeks as week, wi}
					<section class="print-page">
						<header class="page-head">
							<div class="page-head-left">
								<img src={logoDataUrl || `${base}/logo.png`} alt="" class="page-logo" />
								<div>
									<div class="page-title-main">CAMPIONAT SOCIAL HÀNDICAP{temporadaPretty ? ` ${temporadaPretty}` : ''}</div>
									<div class="page-section">Calendari setmana {wi + 1}/{weeks.length} · {dateLabel(week.days[0])} — {dateLabel(week.days[4])}</div>
								</div>
							</div>
							{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
						</header>

						<div class="cal-grid" style="grid-template-rows: 10mm repeat({horesUsades.length * billarsUsats.length}, 1fr);">
							<!-- Capçalera columnes (dies) -->
							<div class="cal-hour-label">Slot</div>
							{#each week.days as day}
								<div class="cal-head">{dateLabel(day)}</div>
							{/each}

							<!-- Files: hora + billar -->
							{#each horesUsades as hora}
								{#each billarsUsats as billar}
									<div class="cal-hour-label">{hora}<br />B{billar}</div>
									{#each week.days as day}
										{@const cell = cellAt(day, hora, billar)}
										<div class="cal-cell" class:cell-empty={!cell}>
											{#if cell}
												<div class="cell-head">
													<span class="match-code {cell.bracket === 'winners' ? 'code-w' : cell.bracket === 'losers' ? 'code-l' : 'code-gf'}">{cell.code}</span>
												</div>
												<div class="cell-line">
													<span class="line"></span>
												</div>
												<div class="cell-line">
													<span class="line"></span>
												</div>
											{/if}
										</div>
									{/each}
								{/each}
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
	.hint { color: #555; font-size: 0.8125rem; }
	.count-label { display: inline-flex; align-items: center; gap: 0.35rem; font-weight: 600; }
	.count-input {
		width: 4.5rem; padding: 0.25rem 0.4rem;
		border: 1px solid #333; border-radius: 0;
		font-size: 0.875rem;
	}

	.preview { overflow: auto; flex: 1; padding: 1rem; background: #ececec; }

	.print-page {
		background: white;
		width: 420mm; height: 297mm;
		padding: 8mm 10mm;
		margin: 0 auto 1rem auto;
		box-sizing: border-box;
		display: flex; flex-direction: column;
		page-break-after: always;
	}
	.print-page:last-child { page-break-after: auto; }

	.page-head {
		display: flex; justify-content: space-between; align-items: center;
		border-bottom: 2px solid #1f1f1f; padding-bottom: 4mm; margin-bottom: 4mm;
		gap: 6mm;
	}
	.page-head-left { display: flex; align-items: center; gap: 5mm; }
	.page-logo {
		height: 16mm; width: 11mm; flex: none;
		object-fit: contain;
		display: inline-flex; align-items: center; justify-content: center;
	}
	.page-title-main { font-weight: 800; font-size: 14pt; letter-spacing: 0.02em; text-transform: uppercase; }
	.page-section { font-size: 10pt; color: #444; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }
	.page-sub { font-size: 9pt; color: #555; }

	.cal-grid {
		flex: 1; display: grid;
		grid-template-columns: 22mm repeat(5, 1fr);
		gap: 1.5mm;
		min-height: 0;
	}
	.cal-head, .cal-hour-label, .cal-cell {
		border: 1px solid #1f1f1f;
		padding: 1.5mm;
		font-size: 8pt;
		display: flex; flex-direction: column;
	}
	.cal-head {
		font-weight: 800; font-size: 10pt;
		background: #1f1f1f; color: white;
		justify-content: center; text-align: center;
	}
	.cal-hour-label {
		background: #f0f0f0;
		font-weight: 700; font-size: 9pt;
		justify-content: center; align-items: center;
		text-align: center;
	}
	.cal-cell { min-height: 30mm; gap: 1mm; }
	.cell-empty { background: repeating-linear-gradient(45deg, #fafafa, #fafafa 3mm, white 3mm, white 6mm); }
	.cell-head {
		display: flex; justify-content: space-between; align-items: baseline;
		font-size: 8pt; font-weight: 700;
		border-bottom: 1px solid #999; padding-bottom: 0.5mm;
	}
	.code-w { color: #1d6e3a; }
	.code-l { color: #a30b1e; }
	.code-gf { color: #6b3eb8; }
	.cell-line { display: flex; align-items: center; gap: 1mm; font-size: 7.5pt; }
	.line { flex: 1; border-bottom: 1px solid #1f1f1f; height: 3.5mm; }

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
		.print-page { margin: 0 !important; box-shadow: none !important; }
		@page { size: A3 landscape; margin: 0; }
		@page { size: 420mm 297mm; margin: 0; }
		:global(body) { background: white !important; margin: 0 !important; }
		:global(html) { background: white !important; }
	}
</style>
