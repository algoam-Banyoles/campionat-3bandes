<script lang="ts">
	import { formatarNomJugador } from '$lib/utils/playerUtils';
	import { printPortal } from '$lib/utils/print-portal';

	export let participants: any[] = [];
	export let eventNom: string = '';
	export let eventTemporada: string = '';
	export let onClose: () => void = () => {};

	$: temporadaPretty = (eventTemporada || '').replace('-', '/');

	type OrderBy = 'cognoms' | 'distancia';
	let orderBy: OrderBy = 'cognoms';

	$: baseRows = participants.map((p: any) => {
		const raw = p.socis;
		const s = Array.isArray(raw) ? raw[0] : raw;
		return {
			nom: s?.nom ?? '',
			cognoms: s?.cognoms ?? '',
			distancia: p.distancia as number | null
		};
	});

	$: rows = (() => {
		const copy = [...baseRows];
		if (orderBy === 'distancia') {
			copy.sort((a, b) => {
				const da = a.distancia ?? -1;
				const db = b.distancia ?? -1;
				if (db !== da) return db - da;
				return `${a.cognoms} ${a.nom}`.localeCompare(`${b.cognoms} ${b.nom}`, 'ca');
			});
		} else {
			copy.sort((a, b) => `${a.cognoms} ${a.nom}`.localeCompare(`${b.cognoms} ${b.nom}`, 'ca'));
		}
		return copy;
	})();

	$: orderLabel = orderBy === 'distancia'
		? 'distància assignada (de més a menys)'
		: 'cognoms';

	function doPrint() {
		window.print();
	}
</script>

<div class="modal-overlay print-portal" use:printPortal on:click|self={onClose} role="presentation">
	<div class="modal-card" role="dialog" aria-modal="true">
		<div class="modal-head no-print">
			<h2 class="modal-title">Imprimir llistat d'inscrits</h2>
			<button type="button" class="close-btn" on:click={onClose} aria-label="Tancar">×</button>
		</div>

		<div class="modal-toolbar no-print">
			<div class="toolbar-info">
				<span>{rows.length} inscrits</span>
				<label class="order-label">
					Ordenar per:
					<select bind:value={orderBy} class="order-select">
						<option value="cognoms">Cognoms (alfabètic)</option>
						<option value="distancia">Caramboles (distància assignada)</option>
					</select>
				</label>
			</div>
			<div class="toolbar-actions">
				<button type="button" class="btn-secondary" on:click={onClose}>Tancar</button>
				<button
					type="button"
					class="btn-primary"
					on:click={doPrint}
					title="Al diàleg d'imprimir tria 'Guardar com a PDF' per descarregar"
				>
					Imprimir / Desar PDF
				</button>
			</div>
		</div>

		<div class="preview">
			<section class="print-page">
				<header class="page-head">
					<div class="page-head-left">
						<img src="/logo-billar.svg" alt="" class="page-logo" />
						<div class="page-head-titles">
							<div class="page-title-main">CAMPIONAT SOCIAL HÀNDICAP{temporadaPretty ? ` ${temporadaPretty}` : ''}</div>
							<div class="page-section">Llistat d'inscrits ({rows.length}) · per {orderLabel}</div>
						</div>
					</div>
					{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
				</header>

				<table class="inscrits-table">
					<thead>
						<tr>
							<th class="num-col">#</th>
							<th class="name-col">Jugador</th>
							<th class="dist-col">Distància assignada</th>
						</tr>
					</thead>
					<tbody>
						{#each rows as r, i}
							<tr>
								<td class="num-col tabular">{i + 1}</td>
								<td class="name-col">{formatarNomJugador(`${r.nom} ${r.cognoms}`.trim())}</td>
								<td class="dist-col tabular">{r.distancia ?? '—'}</td>
							</tr>
						{/each}
					</tbody>
				</table>

				<footer class="page-foot">
					<span>Imprès: {new Date().toLocaleDateString('ca-ES', { day: 'numeric', month: 'long', year: 'numeric' })}</span>
					<span>Foment Martinenc · Secció billar 3 bandes</span>
				</footer>
			</section>
		</div>
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
		background: white; width: 100%; max-width: 900px;
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
	}
	.toolbar-actions { display: flex; gap: 0.5rem; }
	.toolbar-info { display: flex; gap: 0.85rem; align-items: center; flex-wrap: wrap; }
	.order-label { display: inline-flex; align-items: center; gap: 0.35rem; font-weight: 600; }
	.order-select {
		padding: 0.25rem 0.4rem;
		border: 1px solid #333; border-radius: 0;
		font-size: 0.8125rem; background: white;
	}
	.btn-primary, .btn-secondary {
		padding: 0.4rem 0.85rem; cursor: pointer; font-size: 0.875rem; font-weight: 600;
		border-radius: 0; border: 1px solid #333;
	}
	.btn-primary { background: #1f1f1f; color: white; }
	.btn-secondary { background: white; color: #1f1f1f; }
	.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

	.preview { overflow: auto; flex: 1; padding: 1rem; background: #ececec; }

	.print-page {
		background: white;
		width: 210mm; min-height: 297mm; /* A4 portrait */
		padding: 12mm 14mm;
		margin: 0 auto 1rem auto;
		box-sizing: border-box;
		display: flex; flex-direction: column;
	}

	.page-head {
		display: flex; justify-content: space-between; align-items: center;
		border-bottom: 2px solid #1f1f1f; padding-bottom: 4mm; margin-bottom: 4mm;
		gap: 6mm;
	}
	.page-head-left { display: flex; align-items: center; gap: 5mm; min-width: 0; }
	.page-logo {
		/* viewBox 1024×1536 → ratio 2:3 */
		height: 16mm; width: 11mm; flex: none;
		object-fit: contain;
	}
	.page-head-titles { display: flex; flex-direction: column; gap: 1mm; min-width: 0; }
	.page-title-main {
		font-weight: 800; font-size: 14pt;
		letter-spacing: 0.02em; line-height: 1.1; text-transform: uppercase;
	}
	.page-section {
		font-size: 10pt; color: #444; font-weight: 600;
		letter-spacing: 0.04em; text-transform: uppercase;
	}
	.page-sub { font-size: 9pt; color: #555; text-align: right; }

	.inscrits-table {
		width: 100%; border-collapse: collapse; font-size: 10pt; flex: 1;
		page-break-inside: avoid;
		break-inside: avoid;
	}
	.inscrits-table thead {
		page-break-after: avoid;
		break-after: avoid;
	}
	.inscrits-table thead th {
		text-align: left; padding: 1.5mm 1.5mm;
		border-bottom: 1.5px solid #1f1f1f;
		font-size: 8.5pt; font-weight: 700; text-transform: uppercase;
		letter-spacing: 0.04em; color: #1f1f1f;
	}
	.inscrits-table tbody tr {
		page-break-inside: avoid;
		break-inside: avoid;
	}
	.inscrits-table tbody td {
		padding: 1mm 1.5mm; border-bottom: 0.5px solid #ccc;
		vertical-align: middle;
	}
	.tabular { font-variant-numeric: tabular-nums; }
	.num-col { width: 12mm; text-align: right; color: #555; }
	.name-col { width: auto; }
	.dist-col { width: 40mm; text-align: center; }

	.page-foot {
		display: flex; justify-content: space-between;
		margin-top: auto; padding-top: 4mm;
		border-top: 1px solid #ccc;
		font-size: 8pt; color: #777;
	}

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
			padding: 0 !important; /* els marges del paper els dóna @page */
			min-height: 0 !important;
			width: auto !important;
			box-shadow: none !important;
			page-break-after: avoid;
			break-after: avoid;
		}
		@page { size: A4 portrait; margin: 10mm 12mm; }
		:global(body) { background: white !important; margin: 0 !important; }
		:global(html) { background: white !important; }
	}
</style>
