import { writable, get } from 'svelte/store';
import { browser } from '$app/environment';
import { logAction, logError } from '$lib/errors/sentry';

export interface CacheEntry<T = any> {
	data: T;
	timestamp: number;
	ttl: number;
	key: string;
	version?: number;
}

export interface CacheOptions {
	ttl?: number; // Time to live en ms
	strategy?: 'cache-first' | 'network-first' | 'cache-only' | 'network-only';
	version?: number; // Per invalidació per canvis d'esquema
	storage?: 'memory' | 'localStorage' | 'sessionStorage';
	onError?: (error: Error) => void;
}

export interface CacheMetrics {
	hits: number;
	misses: number;
	errors: number;
	totalSize: number;
	hitRate: number;
	lastClearTime: number;
}

class CacheStore {
	private memoryCache = new Map<string, CacheEntry>();
	private metrics = writable<CacheMetrics>({
		hits: 0,
		misses: 0,
		errors: 0,
		totalSize: 0,
		hitRate: 0,
		lastClearTime: Date.now()
	});

	// Configuració per defecte
	private defaultOptions: CacheOptions = {
		ttl: 5 * 60 * 1000, // 5 minuts
		strategy: 'cache-first',
		version: 1,
		storage: 'memory'
	};

	constructor() {
		// Netejar cache expirat cada 5 minuts
		if (browser) {
			setInterval(() => this.cleanExpiredEntries(), 5 * 60 * 1000);
			
			// Restaurar mètriques de localStorage si existeixen
			this.loadMetricsFromStorage();
		}
	}

	/**
	 * Obtenir dada del cache o executar funció per obtenir-la
	 */
	async get<T>(
		key: string,
		fetchFn: () => Promise<T>,
		options: CacheOptions = {}
	): Promise<T> {
		const opts = { ...this.defaultOptions, ...options };
		
		try {
			// Estratègia cache-only: només cache
			if (opts.strategy === 'cache-only') {
				const cached = this.getCachedEntry<T>(key, opts);
				if (cached) {
					this.incrementHits();
					return cached.data;
				}
				throw new Error(`Cache miss per clau: ${key}`);
			}

			// Estratègia network-only: sempre xarxa
			if (opts.strategy === 'network-only') {
				const data = await fetchFn();
				this.setCachedEntry(key, data, opts);
				this.incrementMisses();
				return data;
			}

			// Estratègia cache-first: intentar cache primer
			if (opts.strategy === 'cache-first') {
				const cached = this.getCachedEntry<T>(key, opts);
				if (cached) {
					this.incrementHits();
					logAction('cache_hit', { key, strategy: opts.strategy });
					return cached.data;
				}

				// Cache miss, anar a xarxa
				const data = await fetchFn();
				this.setCachedEntry(key, data, opts);
				this.incrementMisses();
				logAction('cache_miss_fetch', { key, strategy: opts.strategy });
				return data;
			}

			// Estratègia network-first: intentar xarxa primer
			if (opts.strategy === 'network-first') {
				try {
					const data = await fetchFn();
					this.setCachedEntry(key, data, opts);
					logAction('network_first_success', { key });
					return data;
				} catch (error) {
					// Network error, fallback a cache
					const cached = this.getCachedEntry<T>(key, opts);
					if (cached) {
						this.incrementHits();
						logAction('network_first_fallback', { key, error: (error as Error).message });
						return cached.data;
					}
					throw error;
				}
			}

			throw new Error(`Estratègia de cache desconeguda: ${opts.strategy}`);

		} catch (error) {
			this.incrementErrors();
			const err = error as Error;
			logError(err);
			
			if (opts.onError) {
				opts.onError(err);
			}
			
			// Fallback: intentar cache si hi ha error de xarxa
			const cached = this.getCachedEntry<T>(key, opts);
			if (cached) {
				return cached.data;
			}
			
			throw error;
		}
	}

	/**
	 * Establir dada al cache manualment
	 */
	set<T>(key: string, data: T, options: CacheOptions = {}): void {
		const opts = { ...this.defaultOptions, ...options };
		this.setCachedEntry(key, data, opts);
	}

	/**
	 * Invalidar entrada específica del cache
	 */
	invalidate(key: string): void {
		this.memoryCache.delete(key);
		
		if (browser) {
			try {
				localStorage.removeItem(`cache_${key}`);
				sessionStorage.removeItem(`cache_${key}`);
			} catch (error) {
				// Ignorar errors de storage
			}
		}
		
		logAction('cache_invalidate', { key });
	}

	/**
	 * Invalidar multiple claus amb patró
	 */
	invalidatePattern(pattern: string): void {
		const regex = new RegExp(pattern);
		const keysToDelete: string[] = [];

		// Memory cache
		for (const key of this.memoryCache.keys()) {
			if (regex.test(key)) {
				keysToDelete.push(key);
			}
		}

		keysToDelete.forEach(key => {
			this.memoryCache.delete(key);
		});

		// Storage cache
		if (browser) {
			try {
				// localStorage
				for (let i = 0; i < localStorage.length; i++) {
					const key = localStorage.key(i);
					if (key?.startsWith('cache_') && regex.test(key.substring(6))) {
						localStorage.removeItem(key);
					}
				}

				// sessionStorage
				for (let i = 0; i < sessionStorage.length; i++) {
					const key = sessionStorage.key(i);
					if (key?.startsWith('cache_') && regex.test(key.substring(6))) {
						sessionStorage.removeItem(key);
					}
				}
			} catch (error) {
				// Ignorar errors de storage
			}
		}

		logAction('cache_invalidate_pattern', { pattern, deletedKeys: keysToDelete.length });
	}

	/**
	 * Netejar tot el cache
	 */
	clear(): void {
		this.memoryCache.clear();
		
		if (browser) {
			try {
				// Netejar entries de cache de localStorage
				const keysToRemove: string[] = [];
				for (let i = 0; i < localStorage.length; i++) {
					const key = localStorage.key(i);
					if (key?.startsWith('cache_')) {
						keysToRemove.push(key);
					}
				}
				keysToRemove.forEach(key => localStorage.removeItem(key));

				// Netejar entries de cache de sessionStorage
				const sessionKeysToRemove: string[] = [];
				for (let i = 0; i < sessionStorage.length; i++) {
					const key = sessionStorage.key(i);
					if (key?.startsWith('cache_')) {
						sessionKeysToRemove.push(key);
					}
				}
				sessionKeysToRemove.forEach(key => sessionStorage.removeItem(key));
			} catch (error) {
				// Ignorar errors de storage
			}
		}

		// Reset mètriques
		this.metrics.update(m => ({
			...m,
			lastClearTime: Date.now(),
			totalSize: 0
		}));

		logAction('cache_clear');
	}

	/**
	 * Obtenir mètriques del cache
	 */
	getMetrics() {
		return this.metrics;
	}

	/**
	 * Obtenir informació sobre el cache
	 */
	getInfo(): { memoryEntries: number; totalSize: number; metrics: CacheMetrics } {
		const metrics = get(this.metrics);
		return {
			memoryEntries: this.memoryCache.size,
			totalSize: metrics.totalSize,
			metrics
		};
	}

	// Mètodes privats

	private getCachedEntry<T>(key: string, options: CacheOptions): CacheEntry<T> | null {
		// Memory cache primer
		let entry = this.memoryCache.get(key) as CacheEntry<T> | undefined;
		
		// Si no està en memòria, buscar en storage
		if (!entry && browser && options.storage !== 'memory') {
			const storageEntry = this.getFromStorage<T>(key, options.storage);
			
			// Si es troba en storage, copiar a memòria per accés ràpid
			if (storageEntry) {
				entry = storageEntry;
				this.memoryCache.set(key, entry);
			}
		}

		if (!entry) return null;

		// Comprovar TTL
		const now = Date.now();
		if (now > entry.timestamp + entry.ttl) {
			this.memoryCache.delete(key);
			if (options.storage !== 'memory') {
				this.removeFromStorage(key, options.storage);
			}
			return null;
		}

		// Comprovar versió
		if (options.version && entry.version !== options.version) {
			this.memoryCache.delete(key);
			if (options.storage !== 'memory') {
				this.removeFromStorage(key, options.storage);
			}
			return null;
		}

		return entry;
	}

	private setCachedEntry<T>(key: string, data: T, options: CacheOptions): void {
		const entry: CacheEntry<T> = {
			data,
			timestamp: Date.now(),
			ttl: options.ttl || this.defaultOptions.ttl!,
			key,
			version: options.version
		};

		// Guardar en memòria
		this.memoryCache.set(key, entry);

		// Guardar en storage si s'especifica
		if (browser && options.storage !== 'memory') {
			this.saveToStorage(key, entry, options.storage);
		}

		// Actualitzar mètriques de mida
		this.updateTotalSize();
	}

	private getFromStorage<T>(key: string, storage?: 'localStorage' | 'sessionStorage'): CacheEntry<T> | null {
		if (!browser) return null;

		try {
			const storageKey = `cache_${key}`;
			let item: string | null = null;

			if (storage === 'localStorage') {
				item = localStorage.getItem(storageKey);
			} else if (storage === 'sessionStorage') {
				item = sessionStorage.getItem(storageKey);
			} else {
				// Provar localStorage primer, després sessionStorage
				item = localStorage.getItem(storageKey) || sessionStorage.getItem(storageKey);
			}

			if (item) {
				return JSON.parse(item) as CacheEntry<T>;
			}
		} catch (error) {
			// Ignorar errors de parsing/storage
		}

		return null;
	}

	private saveToStorage<T>(key: string, entry: CacheEntry<T>, storage?: 'localStorage' | 'sessionStorage'): void {
		if (!browser) return;

		try {
			const storageKey = `cache_${key}`;
			const serialized = JSON.stringify(entry);

			if (storage === 'localStorage') {
				localStorage.setItem(storageKey, serialized);
			} else if (storage === 'sessionStorage') {
				sessionStorage.setItem(storageKey, serialized);
			}
		} catch (error) {
			// Ignorar errors de storage (quota exceeded, etc.)
		}
	}

	private removeFromStorage(key: string, storage?: 'localStorage' | 'sessionStorage'): void {
		if (!browser) return;

		try {
			const storageKey = `cache_${key}`;

			if (storage === 'localStorage') {
				localStorage.removeItem(storageKey);
			} else if (storage === 'sessionStorage') {
				sessionStorage.removeItem(storageKey);
			} else {
				// Eliminar de tots dos
				localStorage.removeItem(storageKey);
				sessionStorage.removeItem(storageKey);
			}
		} catch (error) {
			// Ignorar errors de storage
		}
	}

	private cleanExpiredEntries(): void {
		const now = Date.now();
		const expiredKeys: string[] = [];

		for (const [key, entry] of this.memoryCache.entries()) {
			if (now > entry.timestamp + entry.ttl) {
				expiredKeys.push(key);
			}
		}

		expiredKeys.forEach(key => {
			this.memoryCache.delete(key);
		});

		if (expiredKeys.length > 0) {
			logAction('cache_cleanup', { expiredEntries: expiredKeys.length });
			this.updateTotalSize();
		}
	}

	private incrementHits(): void {
		this.metrics.update(m => {
			const newHits = m.hits + 1;
			return {
				...m,
				hits: newHits,
				hitRate: newHits / (newHits + m.misses)
			};
		});
	}

	private incrementMisses(): void {
		this.metrics.update(m => {
			const newMisses = m.misses + 1;
			return {
				...m,
				misses: newMisses,
				hitRate: m.hits / (m.hits + newMisses)
			};
		});
	}

	private incrementErrors(): void {
		this.metrics.update(m => ({
			...m,
			errors: m.errors + 1
		}));
	}

	private updateTotalSize(): void {
		const size = this.calculateMemoryCacheSize();
		this.metrics.update(m => ({
			...m,
			totalSize: size
		}));
	}

	private calculateMemoryCacheSize(): number {
		let size = 0;
		for (const entry of this.memoryCache.values()) {
			// Estimació aproximada de la mida en bytes
			size += JSON.stringify(entry).length * 2; // UTF-16 encoding
		}
		return size;
	}

	private loadMetricsFromStorage(): void {
		try {
			const saved = localStorage.getItem('cache_metrics');
			if (saved) {
				const metrics = JSON.parse(saved);
				this.metrics.set(metrics);
			}
		} catch (error) {
			// Ignorar errors de càrrega
		}
	}

	private saveMetricsToStorage(): void {
		try {
			const metrics = get(this.metrics);
			localStorage.setItem('cache_metrics', JSON.stringify(metrics));
		} catch (error) {
			// Ignorar errors de guardat
		}
	}
}

// Instància singleton del cache store
export const cacheStore = new CacheStore();

// Guardar mètriques periòdicament
if (browser) {
	setInterval(() => {
		(cacheStore as any).saveMetricsToStorage();
	}, 30 * 1000); // Cada 30 segons
}