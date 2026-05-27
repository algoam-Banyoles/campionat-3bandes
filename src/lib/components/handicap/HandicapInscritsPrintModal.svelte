<script lang="ts">
	import { formatarNomJugador } from '$lib/utils/playerUtils';

	export let participants: any[] = [];
	export let participantExtras: Map<number, {
		distSocial: number | null;
		categoriaSocialNom: string | null;
		millorMitjana: number | null;
		millorMitjanaYear: number | null;
	}> = new Map();
	export let eventNom: string = '';
	export let eventTemporada: string = '';
	export let onClose: () => void = () => {};

	$: temporadaPretty = (eventTemporada || '').replace('-', '/');

	// Ordenar per cognoms (com és el llistat)
	$: rows = [...participants]
		.map((p: any) => {
			const raw = p.socis;
			const s = Array.isArray(raw) ? raw[0] : raw;
			return {
				nom: s?.nom ?? '',
				cognoms: s?.cognoms ?? '',
				distancia: p.distancia,
				extras: participantExtras.get(p.soci_numero) ?? null
			};
		})
		.sort((a, b) => `${a.cognoms} ${a.nom}`.localeCompare(`${b.cognoms} ${b.nom}`, 'ca'));

	function doPrint() {
		window.print();
	}
</script>

<div class="modal-overlay" on:click|self={onClose} role="presentation">
	<div class="modal-card" role="dialog" aria-modal="true">
		<div class="modal-head no-print">
			<h2 class="modal-title">Imprimir llistat d'inscrits</h2>
			<button type="button" class="close-btn" on:click={onClose} aria-label="Tancar">×</button>
		</div>

		<div class="modal-toolbar no-print">
			<span>{rows.length} inscrits</span>
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
							<div class="page-section">Llistat d'inscrits ({rows.length})</div>
						</div>
					</div>
					{#if eventNom}<div class="page-sub">{eventNom}</div>{/if}
				</header>

				<table class="inscrits-table">
					<thead>
						<tr>
							<th class="num-col">#</th>
							<th class="name-col">Jugador</th>
							<th class="dist-col">Dist. assignada</th>
							<th class="dist-col">Dist. social</th>
							<th class="dist-col">Promig considerat</th>
						</tr>
					</thead>
					<tbody>
						{#each rows as r, i}
							<tr>
								<td class="num-col tabular">{i + 1}</td>
								<td class="name-col">{formatarNomJugador(`${r.nom} ${r.cognoms}`.trim())}</td>
								<td class="dist-col tabular">{r.distancia ?? '—'}</td>
								<td class="dist-col tabular">
									{#if r.extras?.distSocial != null}
										{r.extras.distSocial}
									{:else}
										<span class="muted">—</span>
									{/if}
								</td>
								<td class="dist-col tabular">
									{#if r.extras?.millorMitjana != null}
										{r.extras.millorMitjana.toFixed(3)}
										{#if r.extras.millorMitjanaYear}
											<span class="year">({r.extras.millorMitjanaYear})</span>
										{/if}
									{:else}
										<span class="muted">—</span>
									{/if}
								</td>
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
	.page-logo { height: 16mm; width: auto; flex: none; }
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

	.inscrits-table { width: 100%; border-collapse: collapse; font-size: 10pt; flex: 1; }
	.inscrits-table thead th {
		text-align: left; padding: 2mm 1.5mm;
		border-bottom: 1.5px solid #1f1f1f;
		font-size: 8.5pt; font-weight: 700; text-transform: uppercase;
		letter-spacing: 0.04em; color: #1f1f1f;
	}
	.inscrits-table tbody td {
		padding: 1.5mm; border-bottom: 0.5px solid #ccc;
		vertical-align: top;
	}
	.tabular { font-variant-numeric: tabular-nums; }
	.num-col { width: 8mm; text-align: right; color: #555; }
	.name-col { width: auto; }
	.dist-col { width: 28mm; text-align: center; }
	.muted { color: #999; }
	.year { color: #888; font-size: 9pt; margin-left: 1mm; }

	.page-foot {
		display: flex; justify-content: space-between;
		margin-top: auto; padding-top: 4mm;
		border-top: 1px solid #ccc;
		font-size: 8pt; color: #777;
	}

	@media print {
		.no-print { display: none !important; }
		.modal-overlay { position: static; background: white; padding: 0; }
		.modal-card { max-width: none; max-height: none; }
		.preview { background: white; padding: 0; overflow: visible; }
		.print-page { margin: 0; box-shadow: none; }
		@page { size: A4 portrait; margin: 12mm 14mm; }
		:global(body) { background: white; }
	}
</style>
