<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { buildMatchCodeMap } from '$lib/utils/handicap-types';

	interface ParticipantStat {
		id: string;
		nom: string;
		distancia: number | null;
		seed: number | null;
		eliminat: boolean;
		jugades: number;
		guanyades: number;
		perdudes: number;
		walkover: number;
		estat: 'campió' | 'subcampió' | 'actiu' | 'eliminat';
	}

	interface JornadaEntry {
		matchCode: string;
		rival: string;
		bracket_type: string;
		ronda: number;
		estat: string;
		caramboles_propies: number | null;
		caramboles_rival: number | null;
		distancia_propia: number | null;
		resultat: 'victoria' | 'derrota' | 'walkover' | 'pendent';
		data: string | null;
	}

	let loading = true;
	let error: string | null = null;

	let participants: ParticipantStat[] = [];
	let expandedId: string | null = null;
	let journeyMap = new Map<string, JornadaEntry[]>();
	let loadingJourney = false;
	let searchTerm = '';
	let eventNom = '';

	$: filtered = participants.filter((p) => {
		if (!searchTerm.trim()) return true;
		return p.nom.toLowerCase().includes(searchTerm.toLowerCase());
	});

	const BRACKET_LABELS: Record<string, string> = {
		winners: 'Guanyadors',
		losers: 'Perdedors',
		grand_final: 'Gran Final'
	};

	onMount(async () => {
		// Event actiu o el més recent
		const { data: activeEv } = await supabase
			.from('events')
			.select('id, nom')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.limit(1)
			.maybeSingle();

		let { data: ev } = activeEv
			? { data: activeEv }
			: await supabase
					.from('events')
					.select('id, nom')
					.eq('tipus_competicio', 'handicap')
					.order('creat_el', { ascending: false })
					.limit(1)
					.maybeSingle();

		if (!ev) {
			error = 'No hi ha cap event hàndicap.';
			loading = false;
			return;
		}
		eventNom = (ev as any).nom ?? '';
		const eventId = (ev as any).id as string;

		// Participants (Fase 5c-S2b: FK directe via soci_numero)
		const { data: parts, error: pErr } = await supabase
			.from('handicap_participants')
			.select('id, distancia, seed, eliminat, soci_numero, socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
			.eq('event_id', eventId);

		if (pErr || !parts) {
			error = pErr?.message ?? 'Error carregant participants';
			loading = false;
			return;
		}

		// Matches jugats
		const { data: matches } = await supabase
			.from('handicap_matches')
			.select('id, estat, guanyador_participant_id, slot1_id, slot2_id')
			.eq('event_id', eventId)
			.in('estat', ['jugada', 'walkover']);

		// Slots
		const matchIds = (matches ?? []).flatMap((m: any) => [m.slot1_id, m.slot2_id]);
		const { data: slots } = matchIds.length
			? await supabase.from('handicap_bracket_slots').select('id, participant_id, bracket_type').in('id', matchIds)
			: { data: [] };
		const slotMap = new Map((slots ?? []).map((s: any) => [s.id as string, s]));

		// Detectar campió i subcampió (darrera GF jugada)
		const { data: gfSlots } = await supabase
			.from('handicap_bracket_slots')
			.select('id')
			.eq('event_id', eventId)
			.eq('bracket_type', 'grand_final');
		const gfSlotIds = new Set((gfSlots ?? []).map((s: any) => s.id as string));
		const gfMatch = (matches ?? []).find((m: any) => gfSlotIds.has(m.slot1_id));
		const championId: string | null = gfMatch?.guanyador_participant_id ?? null;
		const subchampionId: string | null = gfMatch
			? (slotMap.get(gfMatch.slot1_id)?.participant_id === championId
					? slotMap.get(gfMatch.slot2_id)?.participant_id
					: slotMap.get(gfMatch.slot1_id)?.participant_id) ?? null
			: null;

		// Comptar stats per participant
		const statsMap = new Map<string, { jugades: number; guanyades: number; perdudes: number; walkover: number }>();
		for (const p of parts) {
			statsMap.set((p as any).id, { jugades: 0, guanyades: 0, perdudes: 0, walkover: 0 });
		}
		for (const m of matches ?? []) {
			const s1 = slotMap.get((m as any).slot1_id);
			const s2 = slotMap.get((m as any).slot2_id);
			if (!s1 || !s2) continue;
			const p1id = s1.participant_id as string | null;
			const p2id = s2.participant_id as string | null;
			const winner = (m as any).guanyador_participant_id as string | null;
			const isWO = (m as any).estat === 'walkover';
			for (const pid of [p1id, p2id]) {
				if (!pid || !statsMap.has(pid)) continue;
				const st = statsMap.get(pid)!;
				st.jugades++;
				if (winner === pid) { st.guanyades++; if (isWO) st.walkover++; }
				else st.perdudes++;
			}
		}

		participants = (parts as any[]).map((p) => {
			const rawS = p.socis;
			const soci = Array.isArray(rawS) ? rawS[0] : rawS;
			const st = statsMap.get(p.id) ?? { jugades: 0, guanyades: 0, perdudes: 0, walkover: 0 };
			const estat: ParticipantStat['estat'] =
				p.id === championId ? 'campió' :
				p.id === subchampionId ? 'subcampió' :
				p.eliminat ? 'eliminat' : 'actiu';
			return {
				id: p.id,
				nom: soci ? `${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim() : '?',
				distancia: p.distancia,
				seed: p.seed,
				eliminat: p.eliminat,
				...st,
				estat
			} satisfies ParticipantStat;
		}).sort((a, b) => {
			const order = { 'campió': 0, 'subcampió': 1, 'actiu': 2, 'eliminat': 3 };
			if (order[a.estat] !== order[b.estat]) return order[a.estat] - order[b.estat];
			return b.guanyades - a.guanyades;
		});

		loading = false;
	});

	async function toggleJourney(participantId: string) {
		if (expandedId === participantId) {
			expandedId = null;
			return;
		}
		expandedId = participantId;
		if (journeyMap.has(participantId)) return;

		loadingJourney = true;
		const { data: ev } = await supabase
			.from('events')
			.select('id')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.limit(1)
			.maybeSingle();
		const eventId = ev?.id;
		if (!eventId) { loadingJourney = false; return; }

		// Slots del participant
		const { data: mySlots } = await supabase
			.from('handicap_bracket_slots')
			.select('id, bracket_type, ronda, posicio')
			.eq('event_id', eventId)
			.eq('participant_id', participantId);
		const mySlotIds = new Set((mySlots ?? []).map((s: any) => s.id as string));

		// Matches on apareix
		const { data: allMatches } = await supabase
			.from('handicap_matches')
			.select('id, estat, guanyador_participant_id, slot1_id, slot2_id, distancia_jugador1, distancia_jugador2, calendari_partides(caramboles_jugador1, caramboles_jugador2, data_programada)')
			.eq('event_id', eventId)
			.neq('estat', 'bye');

		const { data: allSlots } = await supabase
			.from('handicap_bracket_slots')
			.select('id, participant_id, bracket_type, ronda, posicio')
			.eq('event_id', eventId);
		const slotMap2 = new Map((allSlots ?? []).map((s: any) => [s.id as string, s]));

		// Build match code map
		const matchViews = (allMatches ?? []).map((m: any) => {
			const s1 = slotMap2.get(m.slot1_id);
			if (!s1) return null;
			return { id: m.id, bracket_type: s1.bracket_type, ronda: s1.ronda, matchPos: Math.ceil(s1.posicio / 2) } as any;
		}).filter(Boolean);
		const codeMap = buildMatchCodeMap(matchViews);

		const participantMap = new Map((allSlots ?? []).map((s: any) => [s.id as string, s.participant_id as string | null]));

		// Participants names
		const partIds = [...new Set((allSlots ?? []).filter((s: any) => s.participant_id).map((s: any) => s.participant_id as string))];
		const { data: partNames } = partIds.length
			? await supabase.from('handicap_participants').select('id, socis!handicap_participants_soci_numero_fkey(nom, cognoms)').in('id', partIds)
			: { data: [] };
		const nameMap = new Map((partNames ?? []).map((p: any) => {
			const raw = p.socis;
			const s = Array.isArray(raw) ? raw[0] : raw;
			return [p.id as string, s ? `${s.nom ?? ''} ${s.cognoms ?? ''}`.trim() : '?'];
		}));

		const entries: JornadaEntry[] = [];
		for (const m of allMatches ?? []) {
			if (!mySlotIds.has(m.slot1_id) && !mySlotIds.has(m.slot2_id)) continue;
			const s1 = slotMap2.get(m.slot1_id);
			const s2 = slotMap2.get(m.slot2_id);
			if (!s1 || !s2) continue;
			const iSlot1 = mySlotIds.has(m.slot1_id);
			const myDist = iSlot1 ? m.distancia_jugador1 : m.distancia_jugador2;
			const rivId = iSlot1 ? participantMap.get(m.slot2_id) : participantMap.get(m.slot1_id);
			const cal = m.calendari_partides as any;
			const myCar = iSlot1 ? cal?.caramboles_jugador1 : cal?.caramboles_jugador2;
			const rivCar = iSlot1 ? cal?.caramboles_jugador2 : cal?.caramboles_jugador1;
			const resultat: JornadaEntry['resultat'] =
				m.estat === 'jugada' || m.estat === 'walkover'
					? m.guanyador_participant_id === participantId ? (m.estat === 'walkover' ? 'walkover' : 'victoria') : 'derrota'
					: 'pendent';
			entries.push({
				matchCode: codeMap.get(m.id) ?? '?',
				rival: rivId ? (nameMap.get(rivId) ?? '?') : '—',
				bracket_type: s1.bracket_type,
				ronda: s1.ronda,
				estat: m.estat,
				caramboles_propies: myCar ?? null,
				caramboles_rival: rivCar ?? null,
				distancia_propia: myDist ?? null,
				resultat,
				data: cal?.data_programada ? (cal.data_programada as string).substring(0, 10) : null
			});
		}
		entries.sort((a, b) => {
			if (a.bracket_type !== b.bracket_type) return 0;
			return a.ronda - b.ronda;
		});
		journeyMap.set(participantId, entries);
		journeyMap = new Map(journeyMap);
		loadingJourney = false;
	}

	function estatBadge(estat: ParticipantStat['estat']): string {
		return {
			'campió': 'bg-yellow-100 text-yellow-800',
			'subcampió': 'bg-gray-100 text-gray-700',
			'actiu': 'bg-green-100 text-green-700',
			'eliminat': 'bg-red-100 text-red-600'
		}[estat];
	}
</script>

<div class="mx-auto max-w-4xl p-4">
	<div class="mb-4 flex items-center gap-3">
		<a href="/handicap" class="text-sm text-purple-600 hover:underline">← Hàndicap</a>
		<h1 class="text-xl font-bold text-gray-900">Estadístiques</h1>
		{#if eventNom}
			<span class="text-sm text-gray-500">{eventNom}</span>
		{/if}
	</div>

	{#if loading}
		<p class="text-gray-500">Carregant...</p>
	{:else if error}
		<div class="rounded border border-red-300 bg-red-50 p-4 text-red-800">{error}</div>
	{:else}
		<div class="mb-4">
			<input
				type="search"
				placeholder="Cerca jugador..."
				bind:value={searchTerm}
				class="w-full max-w-xs rounded border border-gray-300 px-3 py-1.5 text-sm focus:border-purple-400 focus:outline-none"
			/>
		</div>

		<div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
			<table class="w-full text-sm">
				<thead>
					<tr class="border-b border-gray-100 bg-gray-50 text-xs font-semibold text-gray-600">
						<th class="px-3 py-2 text-left">#</th>
						<th class="px-3 py-2 text-left">Jugador</th>
						<th class="px-3 py-2 text-center">Dist.</th>
						<th class="px-3 py-2 text-center">Jugades</th>
						<th class="px-3 py-2 text-center">Guanyades</th>
						<th class="px-3 py-2 text-center">Perdudes</th>
						<th class="px-3 py-2 text-center">Estat</th>
						<th class="px-3 py-2 text-center">Recorregut</th>
					</tr>
				</thead>
				<tbody>
					{#each filtered as p, i}
						<tr class="border-b border-gray-100 hover:bg-gray-50/50 {p.estat === 'campió' ? 'bg-yellow-50/40' : p.estat === 'eliminat' ? 'opacity-60' : ''}">
							<td class="px-3 py-2 text-xs text-gray-400">
								{#if p.seed}<span class="font-mono">[{p.seed}]</span>{/if}
							</td>
							<td class="px-3 py-2 font-medium text-gray-900">
								{#if p.estat === 'campió'}🏆 {/if}{#if p.estat === 'subcampió'}🥈 {/if}{p.nom}
							</td>
							<td class="px-3 py-2 text-center text-gray-600">{p.distancia ?? '—'}</td>
							<td class="px-3 py-2 text-center text-gray-700">{p.jugades}</td>
							<td class="px-3 py-2 text-center font-semibold text-green-700">{p.guanyades}</td>
							<td class="px-3 py-2 text-center text-red-600">{p.perdudes}</td>
							<td class="px-3 py-2 text-center">
								<span class="rounded px-1.5 py-0.5 text-xs font-medium capitalize {estatBadge(p.estat)}">{p.estat}</span>
							</td>
							<td class="px-3 py-2 text-center">
								<button
									type="button"
									on:click={() => toggleJourney(p.id)}
									class="rounded border border-gray-200 px-2 py-0.5 text-xs text-gray-600 hover:bg-gray-100"
								>
									{expandedId === p.id ? '▲ Tancar' : '▼ Veure'}
								</button>
							</td>
						</tr>
						{#if expandedId === p.id}
							<tr>
								<td colspan="8" class="bg-gray-50 px-4 py-3">
									{#if loadingJourney && !journeyMap.has(p.id)}
										<p class="text-xs text-gray-400">Carregant...</p>
									{:else}
										{@const journey = journeyMap.get(p.id) ?? []}
										{#if journey.length === 0}
											<p class="text-xs text-gray-400">Sense partides registrades.</p>
										{:else}
											<div class="flex flex-wrap gap-2">
												{#each journey as j}
													<div class="rounded border {j.resultat === 'victoria' || j.resultat === 'walkover' ? 'border-green-300 bg-green-50' : j.resultat === 'derrota' ? 'border-red-200 bg-red-50' : 'border-gray-200 bg-white'} px-3 py-2 text-xs min-w-[130px]">
														<div class="font-mono font-bold text-gray-700">{j.matchCode}</div>
														<div class="text-gray-500">{BRACKET_LABELS[j.bracket_type] ?? j.bracket_type} R{j.ronda}</div>
														<div class="mt-1 font-medium {j.resultat === 'victoria' || j.resultat === 'walkover' ? 'text-green-700' : j.resultat === 'derrota' ? 'text-red-600' : 'text-gray-500'}">
															vs {j.rival}
														</div>
														{#if j.caramboles_propies !== null}
															<div class="mt-0.5 text-gray-600">{j.caramboles_propies}/{j.distancia_propia} · {j.caramboles_rival}</div>
														{/if}
														{#if j.data}
															<div class="text-gray-400">{j.data}</div>
														{/if}
													</div>
												{/each}
											</div>
										{/if}
									{/if}
								</td>
							</tr>
						{/if}
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>
