import { supabase } from '$lib/supabaseClient';
import { logAction, logError } from '$lib/errors/sentry';

export interface RankingWithPlayers {
	event_id: string;
	posicio: number;
	player_id: string;
	mitjana: number | null;
	estat: 'actiu' | 'inactiu' | 'pre_inactiu' | 'baixa';
	data_ultim_repte: string | null;
	assignat_el: string;
	player: {
		id: string;
		numero_soci: number;
		nom: string;
		cognoms: string;
		email: string | null;
		telefon: string | null;
		de_baixa: boolean | null;
		club: string | null;
		avatar_url: string | null;
	};
	activeChallenges?: Challenge[];
}

export interface WaitingListPlayer {
	id: string;
	player_id: string;
	ordre: number;
	estat: 'actiu' | 'inactiu' | 'pre_inactiu' | 'baixa';
	data_ultim_repte: string | null;
	data_inscripcio: string;
	event_id: string;
	player: {
		id: string;
		numero_soci: number;
		nom: string;
		cognoms: string;
		email: string | null;
		telefon: string | null;
		de_baixa: boolean | null;
		club: string | null;
		avatar_url: string | null;
	};
}

export interface Challenge {
	id: string;
	reptador_id: string;
	reptat_id: string;
	estat: 'pendent' | 'acceptat' | 'completat' | 'rebutjat' | 'expirat';
	data_creacio: string;
	data_programada: string | null;
	data_completat: string | null;
	resultat_reptador: number | null;
	resultat_reptat: number | null;
	comentaris: string | null;
	reptador?: PlayerBasic;
	reptat?: PlayerBasic;
}

export interface PlayerBasic {
	id: string;
	numero_soci: number;
	nom: string;
	cognoms: string;
}

export interface PlayerStats {
	player: PlayerBasic;
	currentPosition: number | null;
	totalChallenges: number;
	challengesWon: number;
	challengesLost: number;
	winRate: number;
	averageScore: number | null;
	recentChallenges: Challenge[];
	historicalAverages: HistoricalAverage[];
}

export interface HistoricalAverage {
	id: string;
	soci_id: number;
	year: number;
	modalitat: string;
	mitjana: number;
	partides: number;
	creat_el: string;
}

export interface QueryPerformance {
	query: string;
	duration: number;
	timestamp: number;
	cacheHit: boolean;
}

/**
 * Classe per optimitzar consultes SQL amb JOIN i monitorització
 * Actualitzada per la nova arquitectura socis/events
 */
export class OptimizedQueries {
	private performanceLog: QueryPerformance[] = [];
	private readonly SLOW_QUERY_THRESHOLD = 500; // ms

	/**
	 * Obtenir rànquing complet amb informació de jugadors i reptes actius per un event específic
	 */
	async getRankingWithPlayers(eventId: string, includeActiveChallenges = false): Promise<RankingWithPlayers[]> {
		const startTime = Date.now();
		const queryName = 'getRankingWithPlayers';

		try {
			// Estructura actual: ranking_positions -> players -> socis
			let query = supabase
				.from('ranking_positions')
				.select(`
					event_id,
					posicio,
					player_id,
					assignat_el,
					players!inner (
						id,
						nom,
						email,
						mitjana,
						estat,
						club,
						avatar_url,
						data_ultim_repte,
						numero_soci,
						socis (
							numero_soci,
							nom,
							cognoms,
							email,
							de_baixa
						)
					)
				`)
				.eq('event_id', eventId)
				.order('posicio', { ascending: true });

			const { data, error } = await query;

			if (error) {
				throw error;
			}

			let rankingData: RankingWithPlayers[] = (data || []).map((item: any) => ({
				event_id: item.event_id,
				posicio: item.posicio,
				player_id: item.player_id,
				mitjana: item.players?.mitjana || null,
				estat: item.players?.estat || 'actiu',
				data_ultim_repte: item.players?.data_ultim_repte || null,
				assignat_el: item.assignat_el,
				player: {
					id: item.players?.id,
					numero_soci: item.players?.numero_soci || 0,
					nom: item.players?.socis?.nom || item.players?.nom || 'Desconegut',
					cognoms: item.players?.socis?.cognoms || null,
					email: item.players?.socis?.email || item.players?.email,
					telefon: null, // No disponible en l'estructura actual
					de_baixa: item.players?.socis?.de_baixa || false,
					club: item.players?.club,
					avatar_url: item.players?.avatar_url
				}
			}));

			// Afegir reptes actius si es demana
			if (includeActiveChallenges && rankingData.length > 0) {
				const playerIds = rankingData.map(r => r.player_id);
				const activeChallenges = await this.getActiveChallengesByPlayers(playerIds, eventId);

				const challengesByPlayer = new Map<string, Challenge[]>();
				activeChallenges.forEach(challenge => {
					const reptadorId = challenge.reptador_id;
					const reptatId = challenge.reptat_id;

					if (!challengesByPlayer.has(reptadorId)) {
						challengesByPlayer.set(reptadorId, []);
					}
					if (!challengesByPlayer.has(reptatId)) {
						challengesByPlayer.set(reptatId, []);
					}

					challengesByPlayer.get(reptadorId)!.push(challenge);
					challengesByPlayer.get(reptatId)!.push(challenge);
				});

				rankingData = rankingData.map(ranking => ({
					...ranking,
					activeChallenges: challengesByPlayer.get(ranking.player_id) || []
				}));
			}

			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);

			return rankingData;

		} catch (error) {
			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);
			logError(error as Error);
			throw error;
		}
	}

	/**
	 * Obtenir llista d'espera per un event específic
	 */
	async getWaitingList(eventId: string): Promise<WaitingListPlayer[]> {
		const startTime = Date.now();
		const queryName = 'getWaitingList';

		try {
			const { data, error } = await supabase
				.from('waiting_list')
				.select(`
					id,
					player_id,
					ordre,
					data_inscripcio,
					event_id,
					players!inner (
						id,
						nom,
						email,
						estat,
						club,
						avatar_url,
						data_ultim_repte,
						numero_soci,
						socis (
							numero_soci,
							nom,
							cognoms,
							email,
							de_baixa
						)
					)
				`)
				.eq('event_id', eventId)
				.order('ordre', { ascending: true });

			if (error) {
				throw error;
			}

			const waitingData: WaitingListPlayer[] = (data || []).map((item: any) => ({
				id: item.id,
				player_id: item.player_id,
				ordre: item.ordre,
				estat: item.players?.estat || 'actiu',
				data_ultim_repte: item.players?.data_ultim_repte || null,
				data_inscripcio: item.data_inscripcio,
				event_id: item.event_id,
				player: {
					id: item.players?.id,
					numero_soci: item.players?.numero_soci || 0,
					nom: item.players?.socis?.nom || item.players?.nom || 'Desconegut',
					cognoms: item.players?.socis?.cognoms || null,
					email: item.players?.socis?.email || item.players?.email,
					telefon: null, // No disponible en l'estructura actual
					de_baixa: item.players?.socis?.de_baixa || false,
					club: item.players?.club,
					avatar_url: item.players?.avatar_url
				}
			}));

			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);

			return waitingData;

		} catch (error) {
			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);
			logError(error as Error);
			throw error;
		}
	}

	/**
	 * Obtenir reptes actius amb informació de jugadors per un event específic
	 */
	async getActiveChallenges(eventId: string): Promise<Challenge[]> {
		const startTime = Date.now();
		const queryName = 'getActiveChallenges';

		try {
			const { data, error } = await supabase
				.from('challenges')
				.select(`
					id,
					reptador_id,
					reptat_id,
					estat,
					data_creacio,
					data_programada,
					data_completat,
					resultat_reptador,
					resultat_reptat,
					comentaris,
					reptador:reptador_id (
						id,
						numero_soci,
						nom,
						cognoms
					),
					reptat:reptat_id (
						id,
						numero_soci,
						nom,
						cognoms
					)
				`)
				.eq('event_id', eventId)
				.in('estat', ['pendent', 'acceptat'])
				.order('data_creacio', { ascending: false });

			if (error) {
				throw error;
			}

			const challenges: Challenge[] = (data || []).map((item: any) => ({
				id: item.id,
				reptador_id: item.reptador_id,
				reptat_id: item.reptat_id,
				estat: item.estat,
				data_creacio: item.data_creacio,
				data_programada: item.data_programada,
				data_completat: item.data_completat,
				resultat_reptador: item.resultat_reptador,
				resultat_reptat: item.resultat_reptat,
				comentaris: item.comentaris,
				reptador: item.reptador,
				reptat: item.reptat
			}));

			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);

			return challenges;

		} catch (error) {
			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);
			logError(error as Error);
			throw error;
		}
	}

	/**
	 * Obtenir reptes actius per llista de jugadors específics
	 */
	async getActiveChallengesByPlayers(playerIds: string[], eventId: string): Promise<Challenge[]> {
		const startTime = Date.now();
		const queryName = 'getActiveChallengesByPlayers';

		try {
			const { data, error } = await supabase
				.from('challenges')
				.select(`
					id,
					reptador_id,
					reptat_id,
					estat,
					data_creacio,
					data_programada,
					data_completat,
					resultat_reptador,
					resultat_reptat,
					comentaris,
					reptador:reptador_id (
						id,
						numero_soci,
						nom,
						cognoms
					),
					reptat:reptat_id (
						id,
						numero_soci,
						nom,
						cognoms
					)
				`)
				.eq('event_id', eventId)
				.in('estat', ['pendent', 'acceptat'])
				.or(`reptador_id.in.(${playerIds.join(',')}),reptat_id.in.(${playerIds.join(',')})`)
				.order('data_creacio', { ascending: false });

			if (error) {
				throw error;
			}

			const challenges: Challenge[] = (data || []).map((item: any) => ({
				id: item.id,
				reptador_id: item.reptador_id,
				reptat_id: item.reptat_id,
				estat: item.estat,
				data_creacio: item.data_creacio,
				data_programada: item.data_programada,
				data_completat: item.data_completat,
				resultat_reptador: item.resultat_reptador,
				resultat_reptat: item.resultat_reptat,
				comentaris: item.comentaris,
				reptador: item.reptador,
				reptat: item.reptat
			}));

			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);

			return challenges;

		} catch (error) {
			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);
			logError(error as Error);
			throw error;
		}
	}

	/**
	 * Obtenir estadístiques completes d'un jugador
	 */
	async getPlayerStats(playerId: string, eventId: string): Promise<PlayerStats | null> {
		const startTime = Date.now();
		const queryName = 'getPlayerStats';

		try {
			const [playerData, rankingData, challengesData, averagesData] = await Promise.all([
				// Informació bàsica del jugador (via players)
				supabase
					.from('players')
					.select('id, numero_soci, nom, socis(numero_soci, nom, cognoms)')
					.eq('id', playerId)
					.single(),

				// Posició actual en el rànquing
				supabase
					.from('ranking_positions')
					.select('posicio')
					.eq('player_id', playerId)
					.eq('event_id', eventId)
					.single(),

				// Reptes del jugador (últims 20)
				supabase
					.from('challenges')
					.select(`
						id,
						reptador_id,
						reptat_id,
						estat,
						data_creacio,
						data_programada,
						data_completat,
						resultat_reptador,
						resultat_reptat,
						comentaris,
						reptador:reptador_id (id, numero_soci, nom, cognoms),
						reptat:reptat_id (id, numero_soci, nom, cognoms)
					`)
					.eq('event_id', eventId)
					.or(`reptador_id.eq.${playerId},reptat_id.eq.${playerId}`)
					.order('data_creacio', { ascending: false })
					.limit(20),

				// Mitjanes històriques - obtindrem després amb el numero_soci del player
				Promise.resolve({ data: [], error: null })
			]);

			if (playerData.error) {
				if (playerData.error.code === 'PGRST116') {
					return null;
				}
				throw playerData.error;
			}

			const playerRaw = playerData.data;
			const player = {
				id: playerRaw.id,
				numero_soci: playerRaw.numero_soci,
				nom: playerRaw.socis?.[0]?.nom || playerRaw.nom,
				cognoms: playerRaw.socis?.[0]?.cognoms || ''
			};
			
			const currentPosition = rankingData.data?.posicio || null;
			const challenges = challengesData.data || [];
			
			// Obtenir mitjanes històriques si tenim numero_soci
			let averages: any[] = [];
			if (player.numero_soci) {
				const { data: avgData } = await supabase
					.from('mitjanes_historiques')
					.select('*')
					.eq('soci_id', player.numero_soci)
					.eq('modalitat', '3 BANDES')
					.order('year', { ascending: false })
					.limit(5);
				averages = avgData || [];
			}

			// Calcular estadístiques
			const completedChallenges = challenges.filter(c => c.estat === 'completat');
			const challengesAsReptador = completedChallenges.filter(c => c.reptador_id === playerId);
			const challengesAsReptat = completedChallenges.filter(c => c.reptat_id === playerId);

			let challengesWon = 0;
			let challengesLost = 0;
			let totalScore = 0;
			let scoreCount = 0;

			challengesAsReptador.forEach(c => {
				if (c.resultat_reptador !== null && c.resultat_reptat !== null) {
					if (c.resultat_reptador > c.resultat_reptat) {
						challengesWon++;
					} else {
						challengesLost++;
					}
					totalScore += c.resultat_reptador;
					scoreCount++;
				}
			});

			challengesAsReptat.forEach(c => {
				if (c.resultat_reptador !== null && c.resultat_reptat !== null) {
					if (c.resultat_reptat > c.resultat_reptador) {
						challengesWon++;
					} else {
						challengesLost++;
					}
					totalScore += c.resultat_reptat;
					scoreCount++;
				}
			});

			const totalChallenges = challengesWon + challengesLost;
			const winRate = totalChallenges > 0 ? challengesWon / totalChallenges : 0;
			const averageScore = scoreCount > 0 ? totalScore / scoreCount : null;

			const stats: PlayerStats = {
				player,
				currentPosition,
				totalChallenges,
				challengesWon,
				challengesLost,
				winRate,
				averageScore,
				recentChallenges: challenges.map(c => ({
					id: c.id,
					reptador_id: c.reptador_id,
					reptat_id: c.reptat_id,
					estat: c.estat,
					data_creacio: c.data_creacio,
					data_programada: c.data_programada,
					data_completat: c.data_completat,
					resultat_reptador: c.resultat_reptador,
					resultat_reptat: c.resultat_reptat,
					comentaris: c.comentaris,
					reptador: Array.isArray(c.reptador) ? c.reptador[0] : c.reptador,
					reptat: Array.isArray(c.reptat) ? c.reptat[0] : c.reptat
				})),
				historicalAverages: averages
			};

			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);

			return stats;

		} catch (error) {
			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);
			logError(error as Error);
			throw error;
		}
	}

	/**
	 * Cerca de jugadors amb filtratge optimitzat
	 */
	async searchPlayers(query: string, limit = 20): Promise<PlayerBasic[]> {
		const startTime = Date.now();
		const queryName = 'searchPlayers';

		try {
			const searchTerm = query.trim().toLowerCase();

			// Si és un número, buscar per número de soci
			if (/^\d+$/.test(searchTerm)) {
				const { data, error } = await supabase
					.from('socis')
					.select('id, numero_soci, nom, cognoms')
					.eq('numero_soci', parseInt(searchTerm))
					.or('de_baixa.is.null,de_baixa.eq.false')
					.limit(1);

				if (error) throw error;

				const duration = Date.now() - startTime;
				this.logPerformance(queryName, duration, false);

				return data || [];
			}

			// Cerca per nom/cognoms
			const { data, error } = await supabase
				.from('socis')
				.select('id, numero_soci, nom, cognoms')
				.or(`nom.ilike.%${searchTerm}%,cognoms.ilike.%${searchTerm}%`)
				.or('de_baixa.is.null,de_baixa.eq.false')
				.order('cognoms')
				.limit(limit);

			if (error) throw error;

			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);

			return data || [];

		} catch (error) {
			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);
			logError(error as Error);
			throw error;
		}
	}

	/**
	 * Obtenir dashboard admin amb dades agregades
	 */
	async getAdminDashboard() {
		const startTime = Date.now();
		const queryName = 'getAdminDashboard';

		try {
			const [playersCount, activeChallengesCount, completedChallengesCount, rankingCount] = await Promise.all([
				supabase
					.from('socis')
					.select('*', { count: 'exact', head: true })
					.or('de_baixa.is.null,de_baixa.eq.false'),

				supabase
					.from('challenges')
					.select('*', { count: 'exact', head: true })
					.in('estat', ['pendent', 'acceptat']),

				supabase
					.from('challenges')
					.select('*', { count: 'exact', head: true })
					.eq('estat', 'completat'),

				supabase
					.from('ranking_positions')
					.select('*', { count: 'exact', head: true })
			]);

			const dashboard = {
				totalActivePlayers: playersCount.count || 0,
				activeChallenges: activeChallengesCount.count || 0,
				completedChallenges: completedChallengesCount.count || 0,
				playersInRanking: rankingCount.count || 0,
				lastUpdated: new Date().toISOString()
			};

			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);

			return dashboard;

		} catch (error) {
			const duration = Date.now() - startTime;
			this.logPerformance(queryName, duration, false);
			logError(error as Error);
			throw error;
		}
	}

	/**
	 * Obtenir mètriques de rendiment
	 */
	getPerformanceMetrics() {
		const recentQueries = this.performanceLog.slice(-100);
		const slowQueries = recentQueries.filter(q => q.duration > this.SLOW_QUERY_THRESHOLD);

		const avgDuration = recentQueries.length > 0
			? recentQueries.reduce((sum, q) => sum + q.duration, 0) / recentQueries.length
			: 0;

		return {
			totalQueries: this.performanceLog.length,
			recentQueries: recentQueries.length,
			slowQueries: slowQueries.length,
			averageDuration: Math.round(avgDuration),
			slowestQuery: recentQueries.reduce((slowest, current) =>
				current.duration > slowest.duration ? current : slowest,
				{ duration: 0, query: '', timestamp: 0, cacheHit: false }
			)
		};
	}

	/**
	 * Netejar log de rendiment
	 */
	clearPerformanceLog(): void {
		this.performanceLog = [];
	}

	// Mètodes privats

	private logPerformance(query: string, duration: number, cacheHit: boolean): void {
		const logEntry: QueryPerformance = {
			query,
			duration,
			timestamp: Date.now(),
			cacheHit
		};

		this.performanceLog.push(logEntry);

		if (this.performanceLog.length > 1000) {
			this.performanceLog = this.performanceLog.slice(-1000);
		}

		if (duration > this.SLOW_QUERY_THRESHOLD) {
			logAction('slow_query_detected', {
				query,
				duration,
				threshold: this.SLOW_QUERY_THRESHOLD
			});
		}
	}
}

// Instància singleton
export const optimizedQueries = new OptimizedQueries();