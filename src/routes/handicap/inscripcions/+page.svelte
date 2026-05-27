<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import { formatSupabaseError } from '$lib/ui/alerts';
	import Banner from '$lib/components/general/Banner.svelte';
	import HandicapAvailabilityGrid from '$lib/components/handicap/HandicapAvailabilityGrid.svelte';
	import HandicapBracketPrintModal from '$lib/components/handicap/HandicapBracketPrintModal.svelte';
	import HandicapBracketPrintVisualModal from '$lib/components/handicap/HandicapBracketPrintVisualModal.svelte';
	import HandicapInscritsPrintModal from '$lib/components/handicap/HandicapInscritsPrintModal.svelte';
	import { searchActivePlayers } from '$lib/api/socialLeagues';
	import { debounce } from 'lodash-es';
	import { adminChecked } from '$lib/stores/adminAuth';
	import { effectiveIsAdmin } from '$lib/stores/viewMode';
	import { showConfirm } from '$lib/stores/confirmDialogStore';
	import { formatarNomJugador } from '$lib/utils/playerUtils';
	$: if ($adminChecked && !$effectiveIsAdmin) goto('/handicap');

	// ─── State ────────────────────────────────────────────────
	let loading = true;
	let error: string | null = null;
	let success: string | null = null;

	let event: any = null;
	let config: any = null;
	let distanciaGrups: Array<{ nom: string; distancia: number }> = [];

	// Event social de 3 bandes de la mateixa temporada que el hàndicap
	let socialEventId: string | null = null;
	let socialEventNotFound = false;

	let participants: any[] = [];
	let horariesExtra: string[] = [];

	// Dades extra per participant: distància al social actual + millor mitjana 2 anys
	type ParticipantExtra = {
		distSocial: number | null;
		categoriaSocialNom: string | null;
		millorMitjana: number | null;
		millorMitjanaYear: number | null;
	};
	let participantExtras = new Map<number, ParticipantExtra>();

	// ─── Modal: afegir / editar ────────────────────────────────
	let showModal = false;
	let editingId: string | null = null;
	let saving = false;

	// Camps del formulari
	let playerSearch = '';
	let playerResults: any[] = [];
	let selectedSoci: any = null;   // { numero_soci, nom, cognoms, email }

	let distanciaMode: 'grup' | 'custom' = 'grup';
	let distanciaGrupIdx = 0;       // índex a distanciaGrups
	let distanciaCustom = 10;
	let preferencies_dies: string[] = [];
	let preferencies_hores: string[] = [];
	let restriccions_especials = '';

	// Suggeriment automàtic de distància (modal individual)
	let suggestLoading = false;
	let suggestData: {
		categoriaNom: string | null;
		distanciaSocial: number | null;
		millorMitjana: number | null;
		millorMitjanaYear: number | null;
		message: string | null;
	} | null = null;

	// Modal importació massiva
	let showImportModal = false;
	type ImportOrigen = 'social' | 'promig' | 'cap';
	let importPlayers: Array<{
		numero_soci: number;
		nom: string;
		cognoms: string;
		distanciaGrupIdx: number | null;
		origenLabel: string;
		origenTipus: ImportOrigen;
		selected: boolean;
		alreadyInscrit: boolean;
	}> = [];
	let importLoading = false;
	let importSaving = false;
	let importSearch = '';

	// Modal d'impressió del bracket en blanc (per a sorteig manual a la pissarra)
	let showPrintBracketModal = false;
	let showPrintBracketVisualModal = false;
	let printBracketCount = 0;
	// Modal d'impressió del llistat d'inscrits
	let showPrintInscritsModal = false;


	// ─── Inicialització ────────────────────────────────────────
	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		loading = true;
		error = null;
		try {
			// Event actiu handicap
			const { data: events, error: evErr } = await supabase
				.from('events')
				.select('*')
				.eq('tipus_competicio', 'handicap')
				.eq('actiu', true)
				.order('creat_el', { ascending: false })
				.limit(1);
			if (evErr) throw evErr;

			if (!events || events.length === 0) { event = null; loading = false; return; }
			event = events[0];

			// Config (distàncies + horaris extra)
			const { data: cfg } = await supabase
				.from('handicap_config')
				.select('*')
				.eq('event_id', event.id)
				.single();
			config = cfg;
			distanciaGrups = cfg?.distancies_per_categoria || [];

			if (cfg?.horaris_extra?.franja && cfg?.horaris_extra?.dies?.length) {
				horariesExtra = [cfg.horaris_extra.franja];
			} else {
				horariesExtra = [];
			}

			// Event social de 3 bandes de la mateixa temporada (actiu o finalitzat)
			if (event.temporada) {
				const { data: socialEv } = await supabase
					.from('events')
					.select('id')
					.eq('tipus_competicio', 'lliga_social')
					.eq('modalitat', 'tres_bandes')
					.eq('temporada', event.temporada)
					.limit(1)
					.single();
				socialEventId = socialEv?.id ?? null;
				socialEventNotFound = !socialEventId;
			}

			// Participants
			await loadParticipants();
		} catch (e) {
			error = formatSupabaseError(e);
		} finally {
			loading = false;
		}
	}

	async function loadParticipants() {
		const { data, error: pErr } = await supabase
			.from('handicap_participants')
			// Fase 5c-S3: nom via FK directe `soci_numero → socis`.
			// La columna `player_id` ja no existeix.
			.select(`
				id, distancia, seed, preferencies_dies, preferencies_hores,
				restriccions_especials, eliminat, created_at,
				soci_numero,
				socis!handicap_participants_soci_numero_fkey(numero_soci, nom, cognoms, email)
			`)
			.eq('event_id', event.id)
			.order('created_at', { ascending: true });
		if (pErr) throw pErr;
		participants = data || [];
		await loadParticipantExtras();
	}

	async function loadParticipantExtras() {
		const sociNumbers = participants.map((p: any) => p.soci_numero).filter((n: any) => n != null);
		if (sociNumbers.length === 0) {
			participantExtras = new Map();
			return;
		}

		const yearActual = parseInt((event?.temporada || '').split('-').pop() || '0', 10);
		const minYear = yearActual - 1; // últims 2 anys

		const map = new Map<number, ParticipantExtra>();
		for (const n of sociNumbers) {
			map.set(n, { distSocial: null, categoriaSocialNom: null, millorMitjana: null, millorMitjanaYear: null });
		}

		const socialPromise = socialEventId
			? supabase
				.from('inscripcions')
				.select('soci_numero, categories!inscripcions_categoria_assignada_id_fkey(nom, distancia_caramboles)')
				.eq('event_id', socialEventId)
				.in('soci_numero', sociNumbers)
				.not('categoria_assignada_id', 'is', null)
			: Promise.resolve({ data: [], error: null });

		const mitjanaPromise = yearActual > 0
			? supabase
				.from('mitjanes_historiques')
				.select('soci_id, year, mitjana')
				.eq('modalitat', '3 BANDES')
				.gte('year', minYear)
				.lte('year', yearActual)
				.in('soci_id', sociNumbers)
			: Promise.resolve({ data: [], error: null });

		const [socialRes, mitjanaRes] = await Promise.all([socialPromise, mitjanaPromise]);

		for (const ins of (socialRes.data || []) as any[]) {
			const cat: any = Array.isArray(ins.categories) ? ins.categories[0] : ins.categories;
			if (cat?.distancia_caramboles != null) {
				const entry = map.get(ins.soci_numero);
				if (entry) {
					entry.distSocial = cat.distancia_caramboles;
					entry.categoriaSocialNom = cat.nom ?? null;
				}
			}
		}

		for (const m of (mitjanaRes.data || []) as any[]) {
			const entry = map.get(m.soci_id);
			if (entry && (entry.millorMitjana == null || m.mitjana > entry.millorMitjana)) {
				entry.millorMitjana = m.mitjana;
				entry.millorMitjanaYear = m.year;
			}
		}

		participantExtras = map;
	}

	// ─── Cerca de jugadors ─────────────────────────────────────
	const debouncedSearch = debounce(async (term: string) => {
		if (term.length < 3) { playerResults = []; return; }
		try {
			const all = await searchActivePlayers(term);
			// Filtrar els ja inscrits (Fase 5c-S2b: directe via soci_numero)
			const inscritsSocis = new Set(
				participants.map((p: any) => p.soci_numero)
			);
			playerResults = all.filter(s => !inscritsSocis.has(s.numero_soci));
		} catch { playerResults = []; }
	}, 300);

	$: debouncedSearch(playerSearch);

	async function selectSoci(soci: any) {
		selectedSoci = soci;
		playerSearch = `${soci.nom} ${soci.cognoms}`;
		playerResults = [];

		// Suggeriment de distància
		await suggestDistancia(soci.numero_soci);
	}

	async function suggestDistancia(numero_soci: number) {
		if (distanciaGrups.length === 0) return;
		suggestLoading = true;
		suggestData = null;

		try {
			const yearActual = parseInt((event?.temporada || '').split('-').pop() || '0', 10);
			const minYear = yearActual - 1; // últims 2 anys

			// En paral·lel: inscripció social actual (si hi ha event) + millor mitjana 2 anys
			const socialPromise = socialEventId
				? supabase
					.from('inscripcions')
					.select('categoria_assignada_id, categories!inscripcions_categoria_assignada_id_fkey(nom, distancia_caramboles)')
					.eq('soci_numero', numero_soci)
					.eq('event_id', socialEventId)
					.not('categoria_assignada_id', 'is', null)
					.limit(1)
					.maybeSingle()
				: Promise.resolve({ data: null, error: null });

			const mitjanaPromise = yearActual > 0
				? supabase
					.from('mitjanes_historiques')
					.select('year, mitjana')
					.eq('soci_id', numero_soci)
					.eq('modalitat', '3 BANDES')
					.gte('year', minYear)
					.lte('year', yearActual)
					.order('mitjana', { ascending: false })
					.limit(1)
					.maybeSingle()
				: Promise.resolve({ data: null, error: null });

			const [socialRes, mitjanaRes] = await Promise.all([socialPromise, mitjanaPromise]);

			const socialRow: any = socialRes.data;
			const cat: any = socialRow?.categories
				? (Array.isArray(socialRow.categories) ? socialRow.categories[0] : socialRow.categories)
				: null;
			const mitjana: any = mitjanaRes.data;

			let message: string | null = null;

			if (cat?.distancia_caramboles != null) {
				const gIdx = findClosestGroupIdx(cat.distancia_caramboles);
				distanciaMode = 'grup';
				distanciaGrupIdx = gIdx;
				message = `Proposta: ${distanciaGrups[gIdx].nom} (${distanciaGrups[gIdx].distancia} car.)`;
			} else if (socialEventNotFound) {
				message = `No s'ha trobat el campionat social de 3 bandes per a la temporada ${event?.temporada ?? ''}. Assigna manualment.`;
			} else {
				message = `Sense inscripció al social 3 bandes ${event?.temporada ?? ''}. Assigna manualment.`;
			}

			suggestData = {
				categoriaNom: cat?.nom ?? null,
				distanciaSocial: cat?.distancia_caramboles ?? null,
				millorMitjana: mitjana?.mitjana ?? null,
				millorMitjanaYear: mitjana?.year ?? null,
				message
			};
		} catch {
			suggestData = null;
		} finally {
			suggestLoading = false;
		}
	}

	// ─── Hores disponibles ─────────────────────────────────────
	$: horesDisponibles = [...horariesExtra, '18:00', '19:00'];

	// ─── Obrir modal ───────────────────────────────────────────
	function openAddModal() {
		editingId = null;
		selectedSoci = null;

		playerSearch = '';
		playerResults = [];
		distanciaMode = 'grup';
		distanciaGrupIdx = 0;
		distanciaCustom = distanciaGrups[0]?.distancia || 10;
		preferencies_dies = [];
		preferencies_hores = [];
		restriccions_especials = '';
		suggestData = null;
		showModal = true;
	}

	function openEditModal(p: any) {
		editingId = p.id;
		// Fase 5c-S3: socis ve directe via FK soci_numero.
		const rawS = p.socis;
		selectedSoci = (Array.isArray(rawS) ? rawS[0] : rawS) || null;

		playerSearch = selectedSoci ? `${selectedSoci.nom} ${selectedSoci.cognoms}` : '';
		playerResults = [];

		// Detectar si és grup o custom
		const grupsDistances = distanciaGrups.map(g => g.distancia);
		const idx = grupsDistances.indexOf(p.distancia);
		if (idx >= 0) {
			distanciaMode = 'grup';
			distanciaGrupIdx = idx;
		} else {
			distanciaMode = 'custom';
			distanciaCustom = p.distancia;
		}

		preferencies_dies = p.preferencies_dies || [];
		preferencies_hores = p.preferencies_hores || [];
		restriccions_especials = p.restriccions_especials || '';
		suggestData = null;
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		editingId = null;
	}

	// ─── Desar ────────────────────────────────────────────────
	async function handleSave() {
		if (!selectedSoci) { error = 'Selecciona un jugador.'; return; }

		const distancia = distanciaMode === 'grup'
			? distanciaGrups[distanciaGrupIdx]?.distancia
			: distanciaCustom;

		if (!distancia || distancia < 1) { error = 'La distancia ha de ser > 0.'; return; }

		saving = true;
		error = null;
		success = null;

		try {
			const payload: any = {
				event_id: event.id,
				soci_numero: selectedSoci.numero_soci,
				distancia,
				preferencies_dies,
				preferencies_hores,
				restriccions_especials: restriccions_especials || null
			};

			if (editingId) {
				const { error: e } = await supabase
					.from('handicap_participants')
					.update({
						distancia: payload.distancia,
						preferencies_dies: payload.preferencies_dies,
						preferencies_hores: payload.preferencies_hores,
						restriccions_especials: payload.restriccions_especials
					})
					.eq('id', editingId);
				if (e) throw e;
				success = 'Inscripcio actualitzada.';
			} else {
				const { error: e } = await supabase
					.from('handicap_participants')
					.insert(payload);
				if (e) throw e;
				success = 'Jugador inscrit correctament.';
			}

			closeModal();
			await loadParticipants();
		} catch (e) {
			error = formatSupabaseError(e);
		} finally {
			saving = false;
		}
	}

	// ─── Eliminar ─────────────────────────────────────────────
	async function handleDelete(id: string) {
		const ok = await showConfirm({
			title: 'Eliminar inscripció',
			message: 'Eliminar aquesta inscripció?',
			severity: 'danger',
			confirmLabel: 'Eliminar'
		});
		if (!ok) return;
		try {
			const { error: e } = await supabase
				.from('handicap_participants')
				.delete()
				.eq('id', id);
			if (e) throw e;
			await loadParticipants();
		} catch (e) {
			error = formatSupabaseError(e);
		}
	}

	// ─── Importació massiva ────────────────────────────────────
	// Regla d'assignació proposada (l'admin pot modificar tot al selector):
	//   1. Si el soci ha jugat el social 3 bandes d'aquesta temporada
	//      → grup del hàndicap amb `distancia_caramboles` més propera.
	//   2. Si no, busca millor mitjana dels últims 3 anys (3 BANDES)
	//      → grup amb mediana de promig (entre inscrits socials) més propera.
	//   3. Si no té cap dada → proposta buida; l'admin assigna manualment.
	function findClosestGroupIdx(targetDistancia: number): number {
		let bestIdx = 0;
		let bestDiff = Infinity;
		for (let i = 0; i < distanciaGrups.length; i++) {
			const diff = Math.abs(distanciaGrups[i].distancia - targetDistancia);
			if (diff < bestDiff) { bestDiff = diff; bestIdx = i; }
		}
		return bestIdx;
	}

	async function openImportModal() {
		showImportModal = true;
		importLoading = true;
		importPlayers = [];
		importSearch = '';

		try {
			if (distanciaGrups.length === 0) {
				importLoading = false;
				return;
			}

			// Any actual de la temporada (end-year, ex: '2025-2026' → 2026)
			const yearActual = parseInt((event.temporada || '').split('-').pop() || '0', 10);
			const minYear = yearActual - 2; // últims 3 anys: [yearActual-2, yearActual]

			// 1. Socis actius
			const { data: socisActius, error: socisErr } = await supabase
				.from('socis')
				.select('numero_soci, nom, cognoms')
				.eq('de_baixa', false)
				.order('cognoms');
			if (socisErr) throw socisErr;
			const allSocis = socisActius || [];
			if (allSocis.length === 0) {
				importLoading = false;
				return;
			}
			const sociNumbers = allSocis.map(s => s.numero_soci);

			// 2. Inscripcions al social 3 bandes de la mateixa temporada (si existeix)
			const socialInscriptionsByNumero = new Map<number, { distancia_caramboles: number; categoria_nom: string }>();
			if (socialEventId) {
				const { data: inscripcionsSocial } = await supabase
					.from('inscripcions')
					.select(`soci_numero, categories!inscripcions_categoria_assignada_id_fkey(nom, distancia_caramboles)`)
					.eq('event_id', socialEventId)
					.not('categoria_assignada_id', 'is', null);
				for (const ins of (inscripcionsSocial || [])) {
					const cat: any = Array.isArray((ins as any).categories) ? (ins as any).categories[0] : (ins as any).categories;
					if (cat?.distancia_caramboles != null) {
						socialInscriptionsByNumero.set((ins as any).soci_numero, {
							distancia_caramboles: cat.distancia_caramboles,
							categoria_nom: cat.nom ?? ''
						});
					}
				}
			}

			// 3. Millor promig (max mitjana) dels últims 3 anys per soci (modalitat 3 BANDES)
			const { data: mitjanesData } = await supabase
				.from('mitjanes_historiques')
				.select('soci_id, year, mitjana')
				.eq('modalitat', '3 BANDES')
				.gte('year', minYear)
				.lte('year', yearActual)
				.in('soci_id', sociNumbers);
			const bestPromigBySoci = new Map<number, { mitjana: number; year: number }>();
			for (const m of (mitjanesData || []) as any[]) {
				const current = bestPromigBySoci.get(m.soci_id);
				if (!current || m.mitjana > current.mitjana) {
					bestPromigBySoci.set(m.soci_id, { mitjana: m.mitjana, year: m.year });
				}
			}

			// 4. Mediana del millor promig per cada distancia_caramboles del social actual
			const promigsByDistancia = new Map<number, number[]>();
			for (const [soci, info] of socialInscriptionsByNumero) {
				const best = bestPromigBySoci.get(soci);
				if (best != null) {
					if (!promigsByDistancia.has(info.distancia_caramboles)) {
						promigsByDistancia.set(info.distancia_caramboles, []);
					}
					promigsByDistancia.get(info.distancia_caramboles)!.push(best.mitjana);
				}
			}
			const medianaByDistancia = new Map<number, number>();
			for (const [dist, vals] of promigsByDistancia) {
				const sorted = [...vals].sort((a, b) => a - b);
				const mid = Math.floor(sorted.length / 2);
				const mediana = sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
				medianaByDistancia.set(dist, mediana);
			}

			// 5. Filtrar ja inscrits al hàndicap
			const inscritsHandicap = new Set(participants.map((p: any) => p.soci_numero));

			// 6. Construir proposta per a cada soci actiu
			importPlayers = allSocis.map(soci => {
				const isInscritHandicap = inscritsHandicap.has(soci.numero_soci);
				const socialInfo = socialInscriptionsByNumero.get(soci.numero_soci);
				const promigInfo = bestPromigBySoci.get(soci.numero_soci);

				let distanciaGrupIdx: number | null = null;
				let origenTipus: ImportOrigen = 'cap';
				let origenLabel = 'Sense dades';

				if (socialInfo) {
					distanciaGrupIdx = findClosestGroupIdx(socialInfo.distancia_caramboles);
					origenTipus = 'social';
					origenLabel = `Social: ${socialInfo.categoria_nom} (${socialInfo.distancia_caramboles} car.)`;
				} else if (promigInfo && medianaByDistancia.size > 0) {
					let bestDistSocial: number | null = null;
					let bestDiff = Infinity;
					for (const [dist, med] of medianaByDistancia) {
						const diff = Math.abs(med - promigInfo.mitjana);
						if (diff < bestDiff) { bestDiff = diff; bestDistSocial = dist; }
					}
					if (bestDistSocial != null) {
						distanciaGrupIdx = findClosestGroupIdx(bestDistSocial);
						origenTipus = 'promig';
						origenLabel = `Promig ${promigInfo.mitjana.toFixed(3)} (${promigInfo.year})`;
					}
				}

				return {
					numero_soci: soci.numero_soci,
					nom: soci.nom,
					cognoms: soci.cognoms || '',
					distanciaGrupIdx,
					origenLabel,
					origenTipus,
					selected: false,
					alreadyInscrit: isInscritHandicap
				};
			});

			// Ordenar: social primer, després promig, després sense dades; per cognoms dins de cada grup
			const orderMap: Record<ImportOrigen, number> = { social: 0, promig: 1, cap: 2 };
			importPlayers.sort((a, b) => {
				const diff = orderMap[a.origenTipus] - orderMap[b.origenTipus];
				if (diff !== 0) return diff;
				return `${a.cognoms} ${a.nom}`.localeCompare(`${b.cognoms} ${b.nom}`, 'ca');
			});
		} catch (e) {
			error = formatSupabaseError(e);
		} finally {
			importLoading = false;
		}
	}

	$: importPlayersFiltered = (() => {
		const term = importSearch.trim().toLowerCase();
		if (!term) return importPlayers;
		const norm = (s: string) => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
		const t = norm(term);
		return importPlayers.filter(p =>
			norm(p.nom).includes(t) || norm(p.cognoms).includes(t)
		);
	})();
	$: importSelectableCount = importPlayers.filter(
		p => p.selected && !p.alreadyInscrit && p.distanciaGrupIdx != null
	).length;

	async function handleImport() {
		const toInsert = importPlayers.filter(
			p => p.selected && !p.alreadyInscrit && p.distanciaGrupIdx != null
		);
		if (toInsert.length === 0) return;

		importSaving = true;
		try {
			const rows = toInsert.map(p => ({
				event_id: event.id,
				soci_numero: p.numero_soci,
				distancia: distanciaGrups[p.distanciaGrupIdx as number].distancia,
				preferencies_dies: [],
				preferencies_hores: []
			}));
			const { error: e } = await supabase.from('handicap_participants').insert(rows);
			if (e) throw e;
			success = `${rows.length} jugadors inscrits correctament.`;
			showImportModal = false;
			await loadParticipants();
		} catch (e) {
			error = formatSupabaseError(e);
		} finally {
			importSaving = false;
		}
	}

	// ─── Tabs ─────────────────────────────────────────────────
	type Tab = 'llista' | 'disponibilitat' | 'compatibilitat' | 'sorteig';
	let activeTab: Tab = 'llista';

	// ─── Compatibilitat ────────────────────────────────────────
	let showOnlyConflicts = false;

	function sharesSlot(a: any, b: any): boolean {
		const aDies: string[] = a.preferencies_dies || [];
		const aHores: string[] = a.preferencies_hores || [];
		const bDies: string[] = b.preferencies_dies || [];
		const bHores: string[] = b.preferencies_hores || [];

		// No restrictions = available always
		const aAnyDia = aDies.length === 0;
		const aAnyHora = aHores.length === 0;
		const bAnyDia = bDies.length === 0;
		const bAnyHora = bHores.length === 0;

		// Find at least one common (dia, hora) slot
		const dies = ['dl', 'dt', 'dc', 'dj', 'dv'];
		for (const d of dies) {
			const aD = aAnyDia || aDies.includes(d);
			const bD = bAnyDia || bDies.includes(d);
			if (!aD || !bD) continue;
			for (const h of horesDisponibles) {
				const aH = aAnyHora || aHores.includes(h);
				const bH = bAnyHora || bHores.includes(h);
				if (aH && bH) return true;
			}
		}
		return false;
	}

	$: conflictPairs = (() => {
		const pairs: Array<{ a: any; b: any }> = [];
		for (let i = 0; i < participants.length; i++) {
			for (let j = i + 1; j < participants.length; j++) {
				if (!sharesSlot(participants[i], participants[j])) {
					pairs.push({ a: participants[i], b: participants[j] });
				}
			}
		}
		return pairs;
	})();

	// ─── Validació pre-sorteig ─────────────────────────────────
	$: validation = (() => {
		const minPlayers = participants.length >= 4;
		const allDist = participants.every(p => p.distancia > 0);
		const allAvail = participants.every(p => {
			// Consider "no preference declared" as having availability
			return true; // No preference = available everywhere = OK
		});
		const noConflicts = conflictPairs.length === 0;
		const hasConfig = config && distanciaGrups.length > 0;

		return {
			minPlayers: { ok: minPlayers, label: 'Mínim 4 jugadors inscrits', count: participants.length },
			allDist: { ok: allDist, label: 'Tots els jugadors tenen distància assignada' },
			allAvail: { ok: allAvail, label: 'Tots els jugadors han declarat disponibilitat (opcional)' },
			noConflicts: { ok: noConflicts, label: 'Sense parells de jugadors totalment incompatibles', count: conflictPairs.length, warning: true },
			hasConfig: { ok: hasConfig, label: 'Configuració del torneig completa' },
		};
	})();

	$: canProceedSorteig = validation.minPlayers.ok && validation.allDist.ok && validation.hasConfig.ok;

	$: byesNecessaris = (() => {
		let n = participants.length;
		let pot = 1;
		while (pot < n) pot *= 2;
		return pot - n;
	})();
	$: totalMatchesEstimats = participants.length > 1 ? 2 * participants.length - 1 : 0;

	// ─── Helpers ──────────────────────────────────────────────
	function playerNom(p: any): string {
		// Fase 5c-S2b: socis ara ve directe via FK soci_numero
		const raw = p.socis;
		const s = Array.isArray(raw) ? raw[0] : raw;
		return s ? `${s.nom ?? ''} ${s.cognoms ?? ''}`.trim() || `Jugador ${p.id.slice(0, 6)}` : `Jugador ${p.id.slice(0, 6)}`;
	}

	function formatDies(dies: string[]): string {
		return dies?.length ? dies.join(', ') : '—';
	}
</script>

<svelte:head>
	<title>Inscripcions Handicap</title>
</svelte:head>

<div class="hcap-page-root">
	<header class="page-mast">
		<div>
			<div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">
				<a href="/handicap" class="back-link">← Hàndicap</a>
			</div>
			<h1 class="page-title">Inscripcions</h1>
		</div>
		{#if event}
			<div class="flex flex-wrap gap-2">
				<button
					on:click={openImportModal}
					class="rounded-md border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
				>
					Importar de campionats socials
				</button>
				<button
					on:click={() => (showPrintInscritsModal = true)}
					disabled={participants.length === 0}
					class="rounded-md border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
					title="Imprimir llistat d'inscrits amb distàncies i promigs"
				>
					Imprimir llistat
				</button>
				<button
					on:click={() => {
						printBracketCount = Math.max(participants.length, 4);
						showPrintBracketModal = true;
					}}
					class="rounded-md border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
					title="Bracket compacte en graella per ronda"
				>
					Bracket A3 compacte
				</button>
				<button
					on:click={() => {
						printBracketCount = Math.max(participants.length, 4);
						showPrintBracketVisualModal = true;
					}}
					class="rounded-md border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
					title="Bracket visual amb columnes per ronda (més fulls, més espai per casella)"
				>
					Bracket A3 visual
				</button>
				<button
					on:click={openAddModal}
					class="rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700"
				>
					+ Afegir jugador
				</button>
			</div>
		{/if}
	</header>

	{#if error}
		<Banner type="error" message={error} class="mb-4" />
	{/if}
	{#if success}
		<div class="mb-4 rounded border border-green-300 bg-green-50 p-3 text-sm text-green-800">{success}</div>
	{/if}

	{#if loading}
		<div class="rounded border border-blue-200 bg-blue-50 p-4 text-blue-800">Carregant...</div>
	{:else if !event}
		<div class="rounded-lg border-2 border-dashed border-gray-300 p-8 text-center">
			<p class="mb-4 text-gray-600">No hi ha cap torneig handicap actiu.</p>
			<a href="/admin/events/nou" class="inline-flex items-center rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700">
				Crear Torneig Handicap
			</a>
		</div>
	{:else}
		<!-- Capçalera event -->
		<div class="mb-4 rounded-lg border border-gray-200 bg-white p-3 shadow-sm">
			<div class="flex items-center justify-between">
				<div>
					<span class="font-semibold text-gray-900">{event.nom}</span>
					<span class="ml-2 text-sm text-gray-500">Temporada {event.temporada}</span>
				</div>
				<span class="text-sm font-semibold text-purple-700">
					{participants.length} jugador{participants.length !== 1 ? 's' : ''} inscrit{participants.length !== 1 ? 's' : ''}
				</span>
			</div>
		</div>

		{#if !config || distanciaGrups.length === 0}
			<div class="mb-4 rounded border border-yellow-300 bg-yellow-50 p-3 text-sm text-yellow-800">
				Configura primer les distancies per grup a
				<a href="/handicap/configuracio" class="underline">Configuracio</a>.
			</div>
		{/if}

		<!-- Tabs -->
		<div class="mb-4 border-b border-gray-200">
			<nav class="flex gap-1">
				{#each [
					{ id: 'llista', label: 'Llista' },
					{ id: 'disponibilitat', label: 'Disponibilitat' },
					{ id: 'compatibilitat', label: `Compatibilitat${conflictPairs.length > 0 ? ` (${conflictPairs.length} ⚠)` : ''}` },
					{ id: 'sorteig', label: `Sorteig ${canProceedSorteig ? '✓' : ''}` }
				] as tab}
					<button
						on:click={() => activeTab = tab.id as Tab}
						class="px-4 py-2 text-sm font-medium border-b-2 transition-colors {
							activeTab === tab.id
								? 'border-purple-600 text-purple-700'
								: 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
						}"
					>
						{tab.label}
					</button>
				{/each}
			</nav>
		</div>

		<!-- ── Tab: Llista ─────────────────────────────────────── -->
		{#if activeTab === 'llista'}
			{#if participants.length === 0}
				<div class="rounded-lg border-2 border-dashed border-gray-200 p-8 text-center text-gray-500">
					Cap jugador inscrit encara. Usa els botons de dalt per afegir jugadors.
				</div>
			{:else}
				<div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
					<table class="w-full text-sm">
						<thead class="bg-gray-50">
							<tr>
								<th class="px-4 py-2 text-left font-medium text-gray-700">Jugador</th>
								<th class="px-4 py-2 text-center font-medium text-gray-700" title="Distància al torneig hàndicap">Dist.</th>
								<th class="px-4 py-2 text-center font-medium text-gray-700" title="Distància de la categoria al social 3 bandes d'aquesta temporada">Social</th>
								<th class="px-4 py-2 text-center font-medium text-gray-700" title="Millor mitjana 3 bandes dels últims 2 anys">Promig</th>
								<th class="px-4 py-2 text-left font-medium text-gray-700">Dies</th>
								<th class="px-4 py-2 text-left font-medium text-gray-700">Hores</th>
								<th class="px-4 py-2 text-left font-medium text-gray-700">Restriccions</th>
								<th class="px-4 py-2 text-center font-medium text-gray-700">Estat</th>
								<th class="px-4 py-2 text-center font-medium text-gray-700">Accions</th>
							</tr>
						</thead>
						<tbody>
							{#each participants as p, i}
								{@const extra = participantExtras.get(p.soci_numero)}
								<tr class="border-t border-gray-100 {i % 2 === 0 ? '' : 'bg-gray-50'}">
									<td class="px-4 py-2 font-medium text-gray-900">{playerNom(p)}</td>
									<td class="px-4 py-2 text-center">
										<span class="rounded-full bg-purple-100 px-2 py-0.5 text-xs font-bold text-purple-800">
											{p.distancia}
										</span>
									</td>
									<td class="px-4 py-2 text-center text-xs text-gray-700">
										{#if extra?.distSocial != null}
											<span title={extra.categoriaSocialNom ?? ''}>{extra.distSocial}</span>
										{:else}
											<span class="text-gray-400">—</span>
										{/if}
									</td>
									<td class="px-4 py-2 text-center text-xs text-gray-700">
										{#if extra?.millorMitjana != null}
											{extra.millorMitjana.toFixed(3)}
											{#if extra.millorMitjanaYear}
												<span class="ml-1 text-gray-400">({extra.millorMitjanaYear})</span>
											{/if}
										{:else}
											<span class="text-gray-400">—</span>
										{/if}
									</td>
									<td class="px-4 py-2 text-gray-600 text-xs">{formatDies(p.preferencies_dies)}</td>
									<td class="px-4 py-2 text-gray-600 text-xs">{formatDies(p.preferencies_hores)}</td>
									<td class="px-4 py-2 text-gray-500 text-xs">{p.restriccions_especials || '—'}</td>
									<td class="px-4 py-2 text-center">
										{#if p.eliminat}
											<span class="rounded-full bg-red-100 px-2 py-0.5 text-xs text-red-700">Eliminat</span>
										{:else}
											<span class="rounded-full bg-green-100 px-2 py-0.5 text-xs text-green-700">Actiu</span>
										{/if}
									</td>
									<td class="px-4 py-2 text-center">
										<div class="flex items-center justify-center gap-2">
											<button on:click={() => openEditModal(p)} class="text-xs text-blue-600 hover:text-blue-800">Editar</button>
											{#if !p.eliminat}
												<button on:click={() => handleDelete(p.id)} class="text-xs text-red-500 hover:text-red-700">Eliminar</button>
											{/if}
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}

		<!-- ── Tab: Disponibilitat ──────────────────────────────── -->
		{:else if activeTab === 'disponibilitat'}
			<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
				<h3 class="mb-3 text-base font-semibold text-gray-900">Disponibilitat agregada</h3>
				<p class="mb-3 text-sm text-gray-600">
					Cada cel·la mostra quants jugadors estan disponibles en aquell slot (dia × hora).
					Un jugador sense preferències declarades es compta disponible a tots els slots.
				</p>
				<HandicapAvailabilityGrid
					{participants}
					{horesDisponibles}
					mode="resum"
				/>
			</div>

		<!-- ── Tab: Compatibilitat ─────────────────────────────── -->
		{:else if activeTab === 'compatibilitat'}
			<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
				<div class="mb-3 flex items-center justify-between">
					<h3 class="text-base font-semibold text-gray-900">Matriu de compatibilitat horaria</h3>
					{#if conflictPairs.length > 0}
						<label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
							<input type="checkbox" bind:checked={showOnlyConflicts} class="rounded border-gray-300" />
							Mostra només conflictes ({conflictPairs.length})
						</label>
					{/if}
				</div>

				{#if participants.length < 2}
					<p class="text-sm text-gray-500">Cal almenys 2 jugadors per veure la matriu.</p>
				{:else}
					{#if conflictPairs.length === 0}
						<div class="mb-3 rounded border border-green-300 bg-green-50 p-2 text-sm text-green-800">
							Cap conflicte: tots els parells de jugadors comparteixen almenys un slot horari.
						</div>
					{:else}
						<div class="mb-3 rounded border border-red-300 bg-red-50 p-2 text-sm text-red-800">
							<strong>{conflictPairs.length} parell{conflictPairs.length !== 1 ? 's' : ''} sense cap slot horari en comú.</strong>
							Pot ser difícil programar les seves partides. Considera demanar-los que ampliïn disponibilitat.
						</div>
					{/if}

					{#if showOnlyConflicts}
						<!-- Llista de conflictes -->
						{#if conflictPairs.length === 0}
							<p class="text-sm text-gray-500">Cap conflicte detectat.</p>
						{:else}
							<div class="space-y-1">
								{#each conflictPairs as pair}
									<div class="flex items-center gap-3 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm">
										<span class="text-red-600">⚠</span>
										<span class="font-medium">{playerNom(pair.a)}</span>
										<span class="text-gray-400">vs</span>
										<span class="font-medium">{playerNom(pair.b)}</span>
										<span class="ml-auto text-xs text-red-500">Sense slots comuns</span>
									</div>
								{/each}
							</div>
						{/if}
					{:else}
						<!-- Matriu completa -->
						<div class="overflow-x-auto">
							<table class="text-xs border-collapse">
								<thead>
									<tr>
										<th class="border border-gray-200 bg-gray-50 px-2 py-1 text-left min-w-[120px]"></th>
										{#each participants as p}
											<th class="border border-gray-200 bg-gray-50 px-1 py-1 text-center min-w-[28px]"
												title={playerNom(p)}>
												<span class="block max-w-[24px] overflow-hidden text-ellipsis whitespace-nowrap">
													{playerNom(p).split(' ')[0].slice(0,3)}
												</span>
											</th>
										{/each}
									</tr>
								</thead>
								<tbody>
									{#each participants as rowP, ri}
										<tr>
											<td class="border border-gray-200 px-2 py-1 font-medium text-gray-700 whitespace-nowrap max-w-[150px] overflow-hidden text-ellipsis"
												title={playerNom(rowP)}>
												{playerNom(rowP)}
											</td>
											{#each participants as colP, ci}
												{@const compatible = ri === ci || sharesSlot(rowP, colP)}
												<td class="border border-gray-200 px-1 py-1 text-center {
													ri === ci ? 'bg-gray-100' :
													compatible ? 'bg-green-50' : 'bg-red-100'
												}" title="{playerNom(rowP)} vs {playerNom(colP)}: {ri === ci ? '—' : compatible ? 'OK' : 'Conflicte'}">
													{#if ri === ci}
														—
													{:else if compatible}
														<span class="text-green-600">✓</span>
													{:else}
														<span class="text-red-600 font-bold">✗</span>
													{/if}
												</td>
											{/each}
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<p class="mt-2 text-xs text-gray-500">
							<span class="text-green-600">✓</span> = almenys un slot en comú &nbsp;
							<span class="text-red-600">✗</span> = cap slot compatible (conflicte)
						</p>
					{/if}
				{/if}
			</div>

		<!-- ── Tab: Sorteig ────────────────────────────────────── -->
		{:else if activeTab === 'sorteig'}
			<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
				<h3 class="mb-4 text-base font-semibold text-gray-900">Preparacio per al Sorteig</h3>

				<div class="space-y-3 mb-6">
					<!-- Validació 1: mínim jugadors -->
					<div class="flex items-start gap-3 rounded border p-3 {validation.minPlayers.ok ? 'border-green-300 bg-green-50' : 'border-red-300 bg-red-50'}">
						<span class="text-lg">{validation.minPlayers.ok ? '✅' : '❌'}</span>
						<div>
							<p class="text-sm font-medium {validation.minPlayers.ok ? 'text-green-800' : 'text-red-800'}">
								{validation.minPlayers.label}
							</p>
							<p class="text-xs text-gray-600">{participants.length} jugadors inscrits</p>
						</div>
					</div>

					<!-- Validació 2: tots amb distància -->
					<div class="flex items-start gap-3 rounded border p-3 {validation.allDist.ok ? 'border-green-300 bg-green-50' : 'border-red-300 bg-red-50'}">
						<span class="text-lg">{validation.allDist.ok ? '✅' : '❌'}</span>
						<div>
							<p class="text-sm font-medium {validation.allDist.ok ? 'text-green-800' : 'text-red-800'}">
								{validation.allDist.label}
							</p>
							{#if !validation.allDist.ok}
								<p class="text-xs text-red-600">
									Jugadors sense distància: {participants.filter(p => !p.distancia || p.distancia <= 0).map(p => playerNom(p)).join(', ')}
								</p>
							{/if}
						</div>
					</div>

					<!-- Validació 3: configuració completa -->
					<div class="flex items-start gap-3 rounded border p-3 {validation.hasConfig.ok ? 'border-green-300 bg-green-50' : 'border-red-300 bg-red-50'}">
						<span class="text-lg">{validation.hasConfig.ok ? '✅' : '❌'}</span>
						<div>
							<p class="text-sm font-medium {validation.hasConfig.ok ? 'text-green-800' : 'text-red-800'}">
								{validation.hasConfig.label}
							</p>
							{#if !validation.hasConfig.ok}
								<a href="/handicap/configuracio" class="text-xs text-red-600 underline">Ves a configuració</a>
							{/if}
						</div>
					</div>

					<!-- Validació 4 (warning): disponibilitat -->
					<div class="flex items-start gap-3 rounded border p-3 border-gray-300 bg-gray-50">
						<span class="text-lg">ℹ️</span>
						<div>
							<p class="text-sm font-medium text-gray-700">{validation.allAvail.label}</p>
							<p class="text-xs text-gray-500">
								{participants.filter(p => (p.preferencies_dies || []).length === 0 && (p.preferencies_hores || []).length === 0).length}
								jugadors sense restriccions (disponibles sempre)
							</p>
						</div>
					</div>

					<!-- Validació 5 (warning): compatibilitat -->
					<div class="flex items-start gap-3 rounded border p-3 {validation.noConflicts.ok ? 'border-green-300 bg-green-50' : 'border-amber-300 bg-amber-50'}">
						<span class="text-lg">{validation.noConflicts.ok ? '✅' : '⚠️'}</span>
						<div>
							<p class="text-sm font-medium {validation.noConflicts.ok ? 'text-green-800' : 'text-amber-800'}">
								{validation.noConflicts.label}
							</p>
							{#if !validation.noConflicts.ok}
								<p class="text-xs text-amber-700">
									{conflictPairs.length} parell{conflictPairs.length !== 1 ? 's' : ''} conflictiu{conflictPairs.length !== 1 ? 's' : ''}.
									Revisa la pestanya "Compatibilitat".
									<strong>No bloqueja el sorteig.</strong>
								</p>
							{/if}
						</div>
					</div>
				</div>

				<!-- Resum numèric -->
				<div class="mb-6 grid grid-cols-3 gap-3">
					<div class="rounded border border-gray-200 p-3 text-center">
						<div class="text-2xl font-bold text-purple-700">{participants.length}</div>
						<div class="text-xs text-gray-500">Jugadors</div>
					</div>
					<div class="rounded border border-gray-200 p-3 text-center">
						<div class="text-2xl font-bold text-gray-700">{byesNecessaris}</div>
						<div class="text-xs text-gray-500">Byes necessaris</div>
					</div>
					<div class="rounded border border-gray-200 p-3 text-center">
						<div class="text-2xl font-bold text-gray-700">~{totalMatchesEstimats}</div>
						<div class="text-xs text-gray-500">Partides estimades</div>
					</div>
				</div>

				<!-- Botó sorteig -->
				<div class="flex items-center gap-4">
					<a
						href={canProceedSorteig ? '/handicap/sorteig' : undefined}
						class="inline-flex items-center rounded-md px-6 py-3 text-sm font-medium shadow-sm {
							canProceedSorteig
								? 'bg-purple-600 text-white hover:bg-purple-700'
								: 'bg-gray-200 text-gray-400 cursor-not-allowed pointer-events-none'
						}"
					>
						Procedir al sorteig →
					</a>
					{#if !canProceedSorteig}
						<p class="text-xs text-gray-500">
							Resol les validacions obligatòries (❌) per continuar.
						</p>
					{/if}
				</div>
			</div>
		{/if}
	{/if}
</div>

<!-- ═══ MODAL afegir/editar ═════════════════════════════════════ -->
{#if showModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" on:click|self={closeModal}>
		<div class="w-full max-w-lg rounded-lg bg-white shadow-xl" on:click|stopPropagation>
			<div class="flex items-center justify-between border-b px-5 py-4">
				<h2 class="text-lg font-semibold text-gray-900">
					{editingId ? 'Editar inscripcio' : 'Afegir jugador'}
				</h2>
				<button on:click={closeModal} class="text-gray-400 hover:text-gray-600">&#10005;</button>
			</div>

			<div class="space-y-5 px-5 py-4">
				<!-- Seleccionar jugador (només en mode afegir) -->
				{#if !editingId}
					<div>
						<label for="hcp-jugador-search" class="mb-1 block text-sm font-medium text-gray-700">Jugador *</label>
						<input
							id="hcp-jugador-search"
							type="text"
							bind:value={playerSearch}
							placeholder="Escriu el nom (min 3 lletres)..."
							class="block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-purple-500 focus:ring-purple-500"
						/>
						{#if playerResults.length > 0}
							<div class="mt-1 max-h-48 overflow-y-auto rounded border border-gray-200 bg-white shadow-lg">
								{#each playerResults as s}
									<button
										type="button"
										on:click={() => selectSoci(s)}
										class="flex w-full items-center justify-between px-3 py-2 text-left text-sm hover:bg-purple-50"
									>
										<span class="font-medium">{formatarNomJugador(`${s.nom ?? ''} ${s.cognoms ?? ''}`.trim())}</span>
									</button>
								{/each}
							</div>
						{/if}
						{#if selectedSoci}
							<p class="mt-1 text-xs text-purple-700">
								Seleccionat: {formatarNomJugador(`${selectedSoci.nom ?? ''} ${selectedSoci.cognoms ?? ''}`.trim())}
							</p>
						{/if}
					</div>
				{:else}
					<div>
						<p class="text-sm font-medium text-gray-700">Jugador</p>
						<p class="text-sm text-gray-900">{playerSearch}</p>
					</div>
				{/if}

				<!-- Suggeriment distància + dades del jugador -->
				{#if suggestLoading}
					<p class="text-xs text-gray-500">Consultant categoria social i mitjanes...</p>
				{:else if suggestData}
					<div class="rounded border border-blue-200 bg-blue-50 p-2 text-xs text-blue-800 space-y-1">
						{#if suggestData.categoriaNom}
							<p>
								<strong>Social {event?.temporada}:</strong>
								{suggestData.categoriaNom}{#if suggestData.distanciaSocial != null} ({suggestData.distanciaSocial} caramboles){/if}
							</p>
						{:else}
							<p>Sense inscripció al campionat social 3 bandes {event?.temporada}.</p>
						{/if}
						{#if suggestData.millorMitjana != null}
							<p>
								<strong>Millor mitjana 3 bandes (últims 2 anys):</strong>
								{suggestData.millorMitjana.toFixed(3)}
								{#if suggestData.millorMitjanaYear} ({suggestData.millorMitjanaYear}){/if}
							</p>
						{:else}
							<p>Sense mitjanes registrades els últims 2 anys.</p>
						{/if}
						{#if suggestData.message}
							<p class="italic">{suggestData.message}</p>
						{/if}
					</div>
				{/if}

				<!-- Distància -->
				<div>
					<span class="mb-1 block text-sm font-medium text-gray-700">Distancia *</span>
					<div class="flex gap-3">
						<label class="flex items-center gap-1 text-sm">
							<input type="radio" bind:group={distanciaMode} value="grup" /> Per grup
						</label>
						<label class="flex items-center gap-1 text-sm">
							<input type="radio" bind:group={distanciaMode} value="custom" /> Personalitzada
						</label>
					</div>

					{#if distanciaMode === 'grup'}
						{#if distanciaGrups.length === 0}
							<p class="mt-1 text-xs text-red-600">No hi ha grups definits a la configuracio.</p>
						{:else}
							<select
								bind:value={distanciaGrupIdx}
								class="mt-1 block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-purple-500 focus:ring-purple-500"
							>
								{#each distanciaGrups as g, i}
									<option value={i}>{g.nom} ({g.distancia} caramboles)</option>
								{/each}
							</select>
						{/if}
					{:else}
						<div class="mt-1 flex items-center gap-2">
							<input
								type="number"
								bind:value={distanciaCustom}
								min="1"
								class="w-24 rounded-md border-gray-300 text-sm shadow-sm focus:border-purple-500 focus:ring-purple-500"
							/>
							<span class="text-sm text-gray-500">caramboles</span>
						</div>
					{/if}
				</div>

				<!-- Disponibilitat: graella individual -->
				<div>
					<p class="mb-1 text-sm font-medium text-gray-700">Disponibilitat horaria</p>
					<HandicapAvailabilityGrid
						{horesDisponibles}
						mode="individual"
						bind:preferencies_dies
						bind:preferencies_hores
						participants={[]}
					/>
				</div>

				<!-- Restriccions especials -->
				<div>
					<label for="hcp-restriccions" class="mb-1 block text-sm font-medium text-gray-700">Restriccions especials</label>
					<textarea
						id="hcp-restriccions"
						bind:value={restriccions_especials}
						rows="2"
						placeholder="Ex: No pot jugar dimarts..."
						class="block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-purple-500 focus:ring-purple-500"
					></textarea>
				</div>
			</div>

			<div class="flex justify-end gap-3 border-t px-5 py-4">
				<button
					on:click={closeModal}
					class="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
				>
					Cancel·lar
				</button>
				<button
					on:click={handleSave}
					disabled={saving || (!editingId && !selectedSoci)}
					class="rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 disabled:opacity-50"
				>
					{saving ? 'Desant...' : (editingId ? 'Actualitzar' : 'Inscriure')}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- ═══ MODAL importació massiva ════════════════════════════════ -->
{#if showImportModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" on:click|self={() => showImportModal = false}>
		<div class="w-full max-w-2xl rounded-lg bg-white shadow-xl" on:click|stopPropagation>
			<div class="flex items-center justify-between border-b px-5 py-4">
				<h2 class="text-lg font-semibold text-gray-900">Importar des de campionats socials</h2>
				<button on:click={() => showImportModal = false} class="text-gray-400 hover:text-gray-600">&#10005;</button>
			</div>

			<div class="px-5 py-4">
				{#if importLoading}
					<p class="text-sm text-gray-500">Carregant socis i proposta de grup...</p>
				{:else if distanciaGrups.length === 0}
					<div class="rounded border border-amber-300 bg-amber-50 p-3 text-sm text-amber-800">
						Configura primer els grups de distància a
						<a href="/handicap/configuracio" class="underline">Configuració</a>.
					</div>
				{:else if importPlayers.length === 0}
					<p class="text-sm text-gray-500">No hi ha socis actius per importar.</p>
				{:else}
					<p class="mb-2 text-sm text-gray-600">
						Proposta automàtica: socis amb inscripció al campionat social 3 bandes {event?.temporada} → grup amb la mateixa distància.
						Resta: millor mitjana 3 bandes (últimes 3 temporades) mapejat segons mediana del grup social.
						Sense dades → assigna manualment. Tot es pot modificar al selector.
					</p>
					<div class="mb-2">
						<input
							type="search"
							bind:value={importSearch}
							placeholder="Filtra per nom o cognoms..."
							class="block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-purple-500 focus:ring-purple-500"
						/>
					</div>
					<div class="mb-2 text-xs text-gray-500">
						{importPlayersFiltered.length} de {importPlayers.length} mostrats — {importPlayers.filter(p => !p.alreadyInscrit).length} no inscrits.
					</div>
					<div class="max-h-80 overflow-y-auto">
						<table class="w-full text-sm">
							<thead class="sticky top-0 bg-gray-50">
								<tr>
									<th class="px-3 py-2 text-left">
										<input
											type="checkbox"
											title="Selecciona tots els visibles amb proposta"
											on:change={e => {
												const checked = (e.target as HTMLInputElement).checked;
												const visibles = new Set(importPlayersFiltered.map(p => p.numero_soci));
												importPlayers = importPlayers.map(p => {
													if (!visibles.has(p.numero_soci)) return p;
													if (p.alreadyInscrit || p.distanciaGrupIdx == null) return p;
													return { ...p, selected: checked };
												});
											}}
										/>
									</th>
									<th class="px-3 py-2 text-left font-medium text-gray-700">Jugador</th>
									<th class="px-3 py-2 text-left font-medium text-gray-700">Origen proposta</th>
									<th class="px-3 py-2 text-center font-medium text-gray-700">Distància</th>
								</tr>
							</thead>
							<tbody>
								{#each importPlayersFiltered as imp (imp.numero_soci)}
									<tr class="border-t border-gray-100 {imp.alreadyInscrit ? 'opacity-40' : ''}">
										<td class="px-3 py-2">
											<input
												type="checkbox"
												bind:checked={imp.selected}
												disabled={imp.alreadyInscrit || imp.distanciaGrupIdx == null}
												title={imp.distanciaGrupIdx == null ? 'Selecciona primer un grup' : ''}
											/>
										</td>
										<td class="px-3 py-2">
											<span class="font-medium">{formatarNomJugador(`${imp.nom ?? ''} ${imp.cognoms ?? ''}`.trim())}</span>
											{#if imp.alreadyInscrit}
												<span class="ml-1 text-xs text-green-600">(ja inscrit)</span>
											{/if}
										</td>
										<td class="px-3 py-2 text-xs">
											{#if imp.origenTipus === 'social'}
												<span class="text-gray-700">{imp.origenLabel}</span>
											{:else if imp.origenTipus === 'promig'}
												<span class="text-gray-700">{imp.origenLabel}</span>
											{:else}
												<span class="text-gray-400 italic">{imp.origenLabel}</span>
											{/if}
										</td>
										<td class="px-3 py-2 text-center">
											<select
												bind:value={imp.distanciaGrupIdx}
												disabled={imp.alreadyInscrit}
												class="rounded-md border-gray-300 text-xs shadow-sm focus:border-purple-500 focus:ring-purple-500"
											>
												<option value={null}>—</option>
												{#each distanciaGrups as g, gi}
													<option value={gi}>{g.nom} ({g.distancia})</option>
												{/each}
											</select>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>

			<div class="flex justify-end gap-3 border-t px-5 py-4">
				<button
					on:click={() => showImportModal = false}
					class="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
				>
					Cancel·lar
				</button>
				{#if importPlayers.length > 0}
					<button
						on:click={handleImport}
						disabled={importSaving || importSelectableCount === 0}
						class="rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 disabled:opacity-50"
					>
						{importSaving ? 'Important...' : `Importar ${importSelectableCount} jugador${importSelectableCount === 1 ? '' : 's'}`}
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}

{#if showPrintBracketModal}
	<HandicapBracketPrintModal
		participantCount={printBracketCount}
		eventNom={event?.nom ?? ''}
		eventTemporada={event?.temporada ?? ''}
		onClose={() => (showPrintBracketModal = false)}
	/>
{/if}

{#if showPrintBracketVisualModal}
	<HandicapBracketPrintVisualModal
		participantCount={printBracketCount}
		eventNom={event?.nom ?? ''}
		eventTemporada={event?.temporada ?? ''}
		onClose={() => (showPrintBracketVisualModal = false)}
	/>
{/if}

{#if showPrintInscritsModal}
	<HandicapInscritsPrintModal
		{participants}
		eventNom={event?.nom ?? ''}
		eventTemporada={event?.temporada ?? ''}
		onClose={() => (showPrintInscritsModal = false)}
	/>
{/if}

<style>
	.hcap-page-root {
		max-width: 56rem; margin: 0 auto; padding: 1rem;
		display: flex; flex-direction: column; gap: 1.25rem;
		font-family: var(--font-sans); color: var(--ink);
	}
	.page-mast {
		display: flex; justify-content: space-between; align-items: flex-end; gap: 1rem;
		flex-wrap: wrap;
		padding-bottom: 1rem;
		border-bottom: 2px solid var(--ink);
	}
	.editorial-eyebrow {
		font-size: 0.75rem; font-weight: 600;
		letter-spacing: 0.16em; text-transform: uppercase;
		color: var(--sec-handicap);
	}
	.back-link { color: var(--sec-handicap); text-decoration: none; }
	.back-link:hover { color: var(--ink); }
	.page-title {
		font-weight: 800; font-size: 2rem;
		letter-spacing: -0.025em; margin: 0;
	}
	.hcap-page-root :global(.bg-white),
	.hcap-page-root :global(.bg-purple-50),
	.hcap-page-root :global(.bg-blue-50),
	.hcap-page-root :global(.bg-yellow-50),
	.hcap-page-root :global(.bg-green-50),
	.hcap-page-root :global(.bg-gray-50),
	.hcap-page-root :global(.bg-slate-50) {
		background: var(--paper-elevated) !important;
		border-radius: 0 !important;
	}
	.hcap-page-root :global(.bg-red-50) {
		background: var(--paper-elevated) !important;
		border: 1px solid var(--accent) !important;
		color: var(--accent) !important;
		border-radius: 0 !important;
	}
	.hcap-page-root :global(.text-purple-600),
	.hcap-page-root :global(.text-purple-700) { color: var(--sec-handicap) !important; }
	.hcap-page-root :global(.text-yellow-600),
	.hcap-page-root :global(.text-yellow-700) { color: var(--amber) !important; }
	.hcap-page-root :global(.text-green-600),
	.hcap-page-root :global(.text-green-700),
	.hcap-page-root :global(.text-green-800) { color: var(--green) !important; }
	.hcap-page-root :global(.text-red-600),
	.hcap-page-root :global(.text-red-700) { color: var(--accent) !important; }
	.hcap-page-root :global(.text-gray-500),
	.hcap-page-root :global(.text-gray-600),
	.hcap-page-root :global(.text-gray-700) { color: var(--ink-2) !important; }
	.hcap-page-root :global(.text-gray-900) { color: var(--ink) !important; }
	.hcap-page-root :global(button.bg-purple-600),
	.hcap-page-root :global(button[class*="bg-purple"]) {
		background: var(--sec-handicap) !important;
		color: white !important;
		border: 1px solid var(--sec-handicap) !important;
		border-radius: 0 !important;
		font-weight: 600 !important;
	}
	.hcap-page-root :global(button.bg-blue-600),
	.hcap-page-root :global(button[class*="bg-blue"]) {
		background: var(--ink) !important;
		color: var(--paper) !important;
		border: 1px solid var(--ink) !important;
		border-radius: 0 !important;
		font-weight: 600 !important;
	}
	.hcap-page-root :global(input),
	.hcap-page-root :global(select),
	.hcap-page-root :global(textarea) {
		background: var(--paper-elevated) !important;
		border: 1px solid var(--rule-strong) !important;
		border-radius: 0 !important;
		color: var(--ink) !important;
	}
	.hcap-page-root :global(input:focus),
	.hcap-page-root :global(select:focus),
	.hcap-page-root :global(textarea:focus) {
		outline: 2px solid var(--ink) !important;
		border-color: var(--ink) !important;
	}
	.hcap-page-root :global(.rounded),
	.hcap-page-root :global(.rounded-lg),
	.hcap-page-root :global(.rounded-md),
	.hcap-page-root :global(.rounded-xl),
	.hcap-page-root :global(.rounded-full) { border-radius: 0 !important; }
	.hcap-page-root :global(.shadow),
	.hcap-page-root :global(.shadow-sm),
	.hcap-page-root :global(.shadow-md) { box-shadow: none !important; }
</style>
