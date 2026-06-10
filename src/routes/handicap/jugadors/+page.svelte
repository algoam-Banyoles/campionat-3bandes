<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { formatarNomJugadorParts } from '$lib/utils/playerUtils';

	type JugadorRow = {
		participantId: string;
		sociNumero: number;
		nom: string;
		cognoms: string;
		nomComplet: string;
		distancia: number | null;
		seed: number | null;
	};

	let loading = true;
	let error: string | null = null;
	let eventNom = '';
	let eventTemporada = '';
	let jugadors: JugadorRow[] = [];

	$: temporadaPretty = (eventTemporada || '').replace('-', '/');
	$: jugadorsByDist = (() => {
		const map = new Map<number | null, JugadorRow[]>();
		for (const j of jugadors) {
			const k = j.distancia;
			if (!map.has(k)) map.set(k, []);
			map.get(k)!.push(j);
		}
		const keys = [...map.keys()].sort((a, b) => {
			if (a === null) return 1;
			if (b === null) return -1;
			return b - a;
		});
		return keys.map(k => ({ distancia: k, jugadors: map.get(k)! }));
	})();

	onMount(async () => {
		try {
			const { data: activeEv } = await supabase
				.from('events')
				.select('id, nom, temporada')
				.eq('tipus_competicio', 'handicap')
				.eq('actiu', true)
				.limit(1)
				.maybeSingle();

			let ev = activeEv;
			if (!ev) {
				// Fallback: event hàndicap més recent (pot estar finalitzat)
				const { data: recentEv } = await supabase
					.from('events')
					.select('id, nom, temporada')
					.eq('tipus_competicio', 'handicap')
					.order('data_inici', { ascending: false })
					.limit(1)
					.maybeSingle();
				ev = recentEv ?? null;
			}

			if (!ev) {
				error = 'No hi ha cap torneig hàndicap actiu.';
				loading = false;
				return;
			}

			eventNom = ev.nom ?? '';
			eventTemporada = ev.temporada ?? '';

			const { data: participants, error: pErr } = await supabase
				.from('handicap_participants')
				.select(`
					id,
					soci_numero,
					distancia,
					seed,
					socis!handicap_participants_soci_numero_fkey(nom, cognoms)
				`)
				.eq('event_id', ev.id)
				.order('seed', { ascending: true, nullsFirst: false });

			if (pErr) {
				error = pErr.message;
				loading = false;
				return;
			}

			jugadors = (participants ?? []).map((p: any) => {
				const s = Array.isArray(p.socis) ? p.socis[0] : p.socis;
				const nom = s?.nom ?? '';
				const cognoms = s?.cognoms ?? '';
				return {
					participantId: p.id,
					sociNumero: p.soci_numero,
					nom,
					cognoms,
					nomComplet: formatarNomJugadorParts(nom, cognoms),
					distancia: p.distancia ?? null,
					seed: p.seed ?? null
				};
			});
		} catch (e: any) {
			error = e?.message ?? String(e);
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Jugadors inscrits — Hàndicap</title>
</svelte:head>

<div class="hcap-root">
	<header class="page-mast">
		<div>
			<div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">
				<a href="/handicap" class="back-link">← Hàndicap</a>
			</div>
			<h1 class="page-title">Jugadors inscrits</h1>
			{#if eventNom}
				<p class="page-sub">{eventNom}{temporadaPretty ? ` · ${temporadaPretty}` : ''}</p>
			{/if}
		</div>
		<div class="stat-chip">
			<span class="stat-num">{jugadors.length}</span>
			<span class="stat-lbl">inscrit{jugadors.length === 1 ? '' : 's'}</span>
		</div>
	</header>

	{#if loading}
		<p class="muted">Carregant...</p>
	{:else if error}
		<div class="alert-error">{error}</div>
	{:else if jugadors.length === 0}
		<div class="empty">Encara no hi ha cap jugador inscrit.</div>
	{:else}
		{#each jugadorsByDist as grup}
			<section class="dist-section">
				<h2 class="dist-title">
					{#if grup.distancia !== null}
						Distància {grup.distancia} caramboles
					{:else}
						Sense distància assignada
					{/if}
					<span class="dist-count">({grup.jugadors.length})</span>
				</h2>
				<ol class="jug-list">
					{#each grup.jugadors as j}
						<li class="jug-row">
							{#if j.seed !== null}
								<span class="seed">{j.seed}</span>
							{:else}
								<span class="seed seed-empty">—</span>
							{/if}
							<span class="nom">{j.nomComplet}</span>
						</li>
					{/each}
				</ol>
			</section>
		{/each}
	{/if}
</div>

<style>
	.hcap-root {
		max-width: 56rem;
		margin: 0 auto;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		font-family: var(--font-sans);
		color: var(--ink);
	}
	.page-mast {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		gap: 1rem;
		padding-bottom: 1rem;
		border-bottom: 2px solid var(--ink);
	}
	.editorial-eyebrow {
		font-size: 0.75rem;
		font-weight: 600;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		color: var(--sec-handicap);
	}
	.back-link { color: var(--sec-handicap); text-decoration: none; }
	.back-link:hover { text-decoration: underline; }
	.page-title {
		font-weight: 800;
		font-size: 2rem;
		letter-spacing: -0.025em;
		line-height: 1.05;
		margin: 0;
		color: var(--ink);
	}
	.page-sub { font-size: 0.9rem; color: var(--ink-2); margin: 0.25rem 0 0; }
	.stat-chip {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 0.1rem;
	}
	.stat-num { font-size: 2rem; font-weight: 800; line-height: 1; color: var(--sec-handicap); }
	.stat-lbl { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--ink-2); }
	.muted { color: var(--ink-2); }
	.alert-error {
		border: 1px solid var(--accent);
		background: var(--paper-elevated);
		padding: 0.75rem 1rem;
		color: var(--accent);
	}
	.empty {
		border: 1px dashed var(--rule);
		padding: 2rem;
		text-align: center;
		color: var(--ink-2);
		background: var(--paper-elevated);
	}
	.dist-section { display: flex; flex-direction: column; gap: 0.5rem; }
	.dist-title {
		font-size: 0.95rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: var(--ink);
		margin: 0;
		padding-bottom: 0.35rem;
		border-bottom: 1px solid var(--rule);
		display: flex;
		gap: 0.5rem;
		align-items: baseline;
	}
	.dist-count { font-size: 0.8rem; color: var(--ink-2); font-weight: 500; }
	.jug-list {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr));
		gap: 0.25rem 1rem;
	}
	.jug-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.4rem 0.5rem;
		border-bottom: 1px dotted var(--rule);
	}
	.seed {
		display: inline-block;
		min-width: 1.75rem;
		text-align: right;
		font-variant-numeric: tabular-nums;
		font-weight: 700;
		color: var(--sec-handicap);
	}
	.seed-empty { color: var(--ink-2); font-weight: 400; }
	.nom { color: var(--ink); }
</style>
