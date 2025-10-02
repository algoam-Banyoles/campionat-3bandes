import { supabase } from '$lib/supabaseClient';
import { logAction, logError } from '$lib/errors/sentry';

export interface RankingWithPlayers {
	id: string;
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
 */
export class OptimizedQueries {
	private performanceLog: QueryPerformance[] = [];
	private readonly SLOW_QUERY_THRESHOLD = 500; // ms

	/**
	 * Obtenir rànquing complet amb informació de jugadors i reptes actius
	 */
	async getRankingWithPlayers(includeActiveChallenges = false): Promise<RankingWithPlayers[]> {
		const startTime = Date.now();
		const queryName = 'getRankingWithPlayers';

		try {
			let query = supabase
				.from('ranking_positions')
				.select(`
					event_id,
					posicio,
					player_id,
					mitjana,
					estat,
					data_ultim_repte,
					assignat_el,
					socis!inner (
						id,
						numero_soci,
						nom,
						cognoms,
						email,
						telefon,
						de_baixa,
						club,
						avatar_url
					)
				`)
				.order('posicio', { ascending: true });

			const { data, error } = await query;

			if (error) {
				throw error;
			}

			let rankingData: RankingWithPlayers[] = (data || []).map((item: any) => ({
				id: `${item.event_id}-${item.posicio}`,
				posicio: item.posicio,
				player_id: item.player_id,
				mitjana: item.mitjana,
				estat: item.estat,
				data_ultim_repte: item.data_ultim_repte,
				assignat_el: item.assignat_el,
				player: {
					id: item.socis.id,
					numero_soci: item.socis.numero_soci,
					nom: item.socis.nom,
					cognoms: item.socis.cognoms,
					email: item.socis.email,
					telefon: item.socis.telefon,
					de_baixa: item.socis.de_baixa,
					club: item.socis.club,
					avatar_url: item.socis.avatar_url
				}
			}));

			// Afegir reptes actius si es demana (query separada per evitar duplicació)
			if (includeActiveChallenges && rankingData.length > 0) {
				const playerIds = rankingData.map(r => r.player_id);
				const activeChallenges = await this.getActiveChallengesByPlayers(playerIds);

				// Agrupar reptes per jugador
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

				// Afegir reptes a cada jugador
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
	 * Obtenir reptes actius amb informació de jugadors
	 */
	async getActiveChallenges(): Promise<Challenge[]> {
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
	async getActiveChallengesByPlayers(playerIds: string[]): Promise<Challenge[]> {
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
	async getPlayerStats(playerId: string): Promise<PlayerStats | null> {
		const startTime = Date.now();
		const queryName = 'getPlayerStats';

		try {
			// Query en paral·lel per obtenir totes les dades
			const [playerData, rankingData, challengesData, averagesData] = await Promise.all([
				// Informació bàsica del jugador
				supabase
					.from('socis')
					.select('id, numero_soci, nom, cognoms')
					.eq('id', playerId)
					.single(),

				// Posició actual en el rànquing
				supabase
					.from('ranking_positions')
					.select('posicio')
					.eq('player_id', playerId)
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
					.or(`reptador_id.eq.${playerId},reptat_id.eq.${playerId}`)
					.order('data_creacio', { ascending: false })
					.limit(20),

				// Mitjanes històriques
				supabase
					.from('mitjanes_historiques')
					.select('*')
					.eq('soci_id', playerId)
					.eq('modalitat', '3 BANDES')
					.order('year', { ascending: false })
					.limit(5)
			]);

			if (playerData.error) {
				if (playerData.error.code === 'PGRST116') {
					return null; // Jugador no trobat
				}
				throw playerData.error;
			}

			const player = playerData.data;
			const currentPosition = rankingData.data?.posicio || null;
			const challenges = challengesData.data || [];
			const averages = averagesData.data || [];

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
					.from('ranking')
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
		const recentQueries = this.performanceLog.slice(-100); // Últimes 100 queries
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

		// Mantenir només les últimes 1000 entrades
		if (this.performanceLog.length > 1000) {
			this.performanceLog = this.performanceLog.slice(-1000);
		}

		// Log de queries lentes
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