import { cacheStore, type CacheOptions } from './store';
import { logAction } from '$lib/errors/sentry';

export interface CacheStrategy {
	key: string;
	options: CacheOptions;
	refreshInterval?: number;
	dependencies?: readonly string[];
}

/**
 * Estratègies predefinides per diferents tipus de dades
 */
export const CACHE_STRATEGIES = {
	// Rànquing - cache-first, TTL llarg, localStorage
	ranking: {
		key: 'ranking',
		options: {
			ttl: 10 * 60 * 1000, // 10 minuts
			strategy: 'cache-first' as const,
			storage: 'localStorage' as const,
			version: 1
		},
		refreshInterval: 5 * 60 * 1000, // Refresh cada 5 minuts
		dependencies: ['challenges', 'players']
	},

	// Reptes actius - cache-first, TTL mitjà
	activeChallenges: {
		key: 'challenges_active',
		options: {
			ttl: 2 * 60 * 1000, // 2 minuts
			strategy: 'cache-first' as const,
			storage: 'sessionStorage' as const,
			version: 1
		},
		refreshInterval: 1 * 60 * 1000, // Refresh cada minut
		dependencies: ['ranking']
	},

	// Estadístiques de jugador - cache-first, TTL llarg
	playerStats: {
		key: 'player_stats',
		options: {
			ttl: 15 * 60 * 1000, // 15 minuts
			strategy: 'cache-first' as const,
			storage: 'localStorage' as const,
			version: 1
		},
		refreshInterval: 10 * 60 * 1000,
		dependencies: ['challenges', 'mitjanes']
	},

	// Llista de jugadors - cache-first, TTL molt llarg
	players: {
		key: 'players',
		options: {
			ttl: 30 * 60 * 1000, // 30 minuts
			strategy: 'cache-first' as const,
			storage: 'localStorage' as const,
			version: 1
		},
		refreshInterval: 15 * 60 * 1000
	},

	// Dashboard admin - network-first per dades crítiques
	adminDashboard: {
		key: 'admin_dashboard',
		options: {
			ttl: 1 * 60 * 1000, // 1 minut
			strategy: 'network-first' as const,
			storage: 'sessionStorage' as const,
			version: 1
		},
		dependencies: ['ranking', 'challenges', 'players']
	},

	// Mitjanes històriques - cache-first, TTL llarg
	historicalAverages: {
		key: 'historical_averages',
		options: {
			ttl: 60 * 60 * 1000, // 1 hora
			strategy: 'cache-first' as const,
			storage: 'localStorage' as const,
			version: 1
		},
		refreshInterval: 30 * 60 * 1000
	},

	// Cerca de jugadors - cache-first, TTL mitjà
	playerSearch: {
		key: 'player_search',
		options: {
			ttl: 5 * 60 * 1000, // 5 minuts
			strategy: 'cache-first' as const,
			storage: 'sessionStorage' as const,
			version: 1
		}
	},

	// Reptes històrics - cache-first, TTL llarg
	challengeHistory: {
		key: 'challenge_history',
		options: {
			ttl: 20 * 60 * 1000, // 20 minuts
			strategy: 'cache-first' as const,
			storage: 'localStorage' as const,
			version: 1
		}
	},

	// Reptes d'usuari específic - cache-first, TTL mitjà
	userChallenges: {
		key: 'challenges_user',
		options: {
			ttl: 5 * 60 * 1000, // 5 minuts
			strategy: 'cache-first' as const,
			storage: 'sessionStorage' as const,
			version: 1
		}
	}
} as const;

/**
 * Classe per gestionar estratègies de cache avançades
 */
export class CacheManager {
	private refreshTimers = new Map<string, NodeJS.Timeout>();
	private dependencyGraph = new Map<string, Set<string>>();

	constructor() {
		this.buildDependencyGraph();
	}

	/**
	 * Obtenir dades amb estratègia específica
	 */
	async get<T>(
		strategyName: keyof typeof CACHE_STRATEGIES,
		fetchFn: () => Promise<T>,
		keyModifier?: string
	): Promise<T> {
		const strategy = CACHE_STRATEGIES[strategyName];
		const cacheKey = keyModifier ? `${strategy.key}_${keyModifier}` : strategy.key;

		const result = await cacheStore.get(cacheKey, fetchFn, strategy.options);

		// Programar refresh automàtic si s'especifica
		if ('refreshInterval' in strategy && strategy.refreshInterval && !this.refreshTimers.has(cacheKey)) {
			this.scheduleRefresh(cacheKey, fetchFn, strategy as CacheStrategy);
		}

		return result;
	}

	/**
	 * Invalidar cache per estratègia
	 */
	invalidate(strategyName: keyof typeof CACHE_STRATEGIES, keyModifier?: string): void {
		const strategy = CACHE_STRATEGIES[strategyName];
		const cacheKey = keyModifier ? `${strategy.key}_${keyModifier}` : strategy.key;

		cacheStore.invalidate(cacheKey);

		// Cancel·lar refresh timer
		const timer = this.refreshTimers.get(cacheKey);
		if (timer) {
			clearTimeout(timer);
			this.refreshTimers.delete(cacheKey);
		}

		// Invalidar dependències
		this.invalidateDependents(strategy.key);

		logAction('cache_strategy_invalidate', { strategy: strategyName, key: cacheKey });
	}

	/**
	 * Invalidar múltiples estratègies
	 */
	invalidateMultiple(strategies: (keyof typeof CACHE_STRATEGIES)[]): void {
		strategies.forEach(strategy => this.invalidate(strategy));
	}

	/**
	 * Pre-carregar dades amb estratègia específica
	 */
	async preload<T>(
		strategyName: keyof typeof CACHE_STRATEGIES,
		fetchFn: () => Promise<T>,
		keyModifier?: string
	): Promise<void> {
		try {
			await this.get(strategyName, fetchFn, keyModifier);
			logAction('cache_preload_success', { strategy: strategyName });
		} catch (error) {
			logAction('cache_preload_error', { strategy: strategyName, error: (error as Error).message });
		}
	}

	/**
	 * Cache diferencial - només actualitzar si han canviat les dades
	 */
	async getDifferential<T>(
		strategyName: keyof typeof CACHE_STRATEGIES,
		fetchFn: () => Promise<T>,
		compareFn: (cached: T, fresh: T) => boolean,
		keyModifier?: string
	): Promise<T> {
		const strategy = CACHE_STRATEGIES[strategyName];
		const cacheKey = keyModifier ? `${strategy.key}_${keyModifier}` : strategy.key;

		// Intentar obtenir del cache primer
		try {
			const cached = await cacheStore.get(cacheKey, async () => {
				throw new Error('Force network fetch');
			}, { ...strategy.options, strategy: 'cache-only' });

			// Obtenir dades fresques
			const fresh = await fetchFn();

			// Comparar i actualitzar només si han canviat
			if (!compareFn(cached, fresh)) {
				cacheStore.set(cacheKey, fresh, strategy.options);
				logAction('cache_differential_update', { strategy: strategyName, key: cacheKey });
				return fresh;
			}

			logAction('cache_differential_unchanged', { strategy: strategyName, key: cacheKey });
			return cached;

		} catch (error) {
			// Si no hi ha cache, obtenir dades fresques
			const fresh = await fetchFn();
			cacheStore.set(cacheKey, fresh, strategy.options);
			return fresh;
		}
	}

	/**
	 * Warmup del cache - pre-carregar dades crítiques
	 */
	async warmup(): Promise<void> {
		const criticalStrategies: (keyof typeof CACHE_STRATEGIES)[] = [
			'players',
			'ranking'
		];

		const warmupPromises = criticalStrategies.map(async (strategy) => {
			try {
				// Només carregarem si té sentit (amb dades mock per warmup)
				await this.preload(strategy, async () => {
					// Dades buides per warmup del sistema de cache
					return {} as any;
				});
			} catch (error) {
				// Ignorar errors de warmup
			}
		});

		await Promise.allSettled(warmupPromises);
		logAction('cache_warmup_complete');
	}

	/**
	 * Obtenir estadístiques de totes les estratègies
	 */
	getStrategiesInfo(): Record<string, any> {
		const info = cacheStore.getInfo();
		const strategies = Object.keys(CACHE_STRATEGIES).reduce((acc, key) => {
			acc[key] = {
				...CACHE_STRATEGIES[key as keyof typeof CACHE_STRATEGIES],
				hasRefreshTimer: this.refreshTimers.has(key)
			};
			return acc;
		}, {} as Record<string, any>);

		return {
			...info,
			strategies,
			refreshTimersActive: this.refreshTimers.size
		};
	}

	/**
	 * Netejar tots els timers
	 */
	cleanup(): void {
		for (const timer of this.refreshTimers.values()) {
			clearTimeout(timer);
		}
		this.refreshTimers.clear();
	}

	// Mètodes privats

	private buildDependencyGraph(): void {
		Object.entries(CACHE_STRATEGIES).forEach(([key, strategy]) => {
			if ('dependencies' in strategy && strategy.dependencies) {
				strategy.dependencies.forEach((dep: string) => {
					if (!this.dependencyGraph.has(dep)) {
						this.dependencyGraph.set(dep, new Set());
					}
					this.dependencyGraph.get(dep)!.add(key);
				});
			}
		});
	}

	private invalidateDependents(key: string): void {
		const dependents = this.dependencyGraph.get(key);
		if (dependents) {
			dependents.forEach(dependent => {
				cacheStore.invalidate(dependent);
				
				// Cancel·lar refresh timer del dependent
				const timer = this.refreshTimers.get(dependent);
				if (timer) {
					clearTimeout(timer);
					this.refreshTimers.delete(dependent);
				}
			});
		}
	}

	private scheduleRefresh<T>(
		cacheKey: string,
		fetchFn: () => Promise<T>,
		strategy: CacheStrategy
	): void {
		const timer = setTimeout(async () => {
			try {
				// Refresh silenciós
				const fresh = await fetchFn();
				cacheStore.set(cacheKey, fresh, strategy.options);
				
				// Re-programar següent refresh
				this.refreshTimers.delete(cacheKey);
				this.scheduleRefresh(cacheKey, fetchFn, strategy);
				
				logAction('cache_auto_refresh', { key: cacheKey });
			} catch (error) {
				// Re-programar amb backoff en cas d'error
				this.refreshTimers.delete(cacheKey);
				setTimeout(() => {
					this.scheduleRefresh(cacheKey, fetchFn, strategy);
				}, strategy.refreshInterval! * 2); // Doble delay en cas d'error
			}
		}, strategy.refreshInterval);

		this.refreshTimers.set(cacheKey, timer);
	}
}

// Instància singleton del cache manager
export const cacheManager = new CacheManager();

// Cleanup al tancar la pàgina
if (typeof window !== 'undefined') {
	window.addEventListener('beforeunload', () => {
		cacheManager.cleanup();
	});
}