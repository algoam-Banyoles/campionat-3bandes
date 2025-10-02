import { writable, get } from 'svelte/store';
import { browser } from '$app/environment';

// Fallback simple per logging si sentry no està disponible
const logAction = (action: string, data?: any) => {
	if (browser) {
		console.log(`[Performance] ${action}:`, data);
	}
};

export interface PerformanceMetric {
	id: string;
	name: string;
	duration: number;
	timestamp: number;
	category: 'database' | 'cache' | 'component' | 'api';
	metadata?: Record<string, any>;
}

export interface CacheMetric {
	key: string;
	hitCount: number;
	missCount: number;
	totalCount: number;
	hitRate: number;
	averageLatency: number;
	lastAccess: number;
	size: number;
}

export interface DatabaseMetric {
	name: string;
	query: string;
	duration: number;
	timestamp: number;
	params?: any;
	resultCount?: number;
	error?: string;
}

export interface ComponentMetric {
	component: string;
	renderTime: number;
	propsCount: number;
	timestamp: number;
	route?: string;
}

export interface PerformanceDashboard {
	metrics: PerformanceMetric[];
	cacheMetrics: Record<string, CacheMetric>;
	databaseMetrics: DatabaseMetric[];
	componentMetrics: ComponentMetric[];
	summary: {
		totalRequests: number;
		averageResponseTime: number;
		slowestQueries: DatabaseMetric[];
		cacheHitRate: number;
		errorRate: number;
		lastUpdated: number;
	};
}

/**
 * Sistema de monitorització de rendiment
 */
class PerformanceMonitor {
	private metrics = writable<PerformanceMetric[]>([]);
	private cacheMetrics = writable<Record<string, CacheMetric>>({});
	private databaseMetrics = writable<DatabaseMetric[]>([]);
	private componentMetrics = writable<ComponentMetric[]>([]);

	private readonly MAX_METRICS = 1000;
	private readonly SLOW_QUERY_THRESHOLD = 500; // ms
	private readonly MAX_CACHE_METRICS = 100;

	constructor() {
		if (browser) {
			// Carregar mètriques guardades
			this.loadFromStorage();
			
			// Guardar periòdicament
			setInterval(() => this.saveToStorage(), 30000); // Cada 30 segons
			
			// Netejar mètriques antigues cada 5 minuts
			setInterval(() => this.cleanOldMetrics(), 5 * 60 * 1000);
		}
	}

	/**
	 * Iniciar mesurament de rendiment
	 */
	startMeasurement(name: string, category: PerformanceMetric['category']): string {
		const id = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
		
		if (browser && performance && performance.mark) {
			performance.mark(`${name}-start-${id}`);
		}
		
		return id;
	}

	/**
	 * Finalitzar mesurament de rendiment
	 */
	endMeasurement(
		id: string, 
		name: string, 
		category: PerformanceMetric['category'], 
		metadata?: Record<string, any>
	): number {
		const endTime = Date.now();
		let duration = 0;

		if (browser && performance && performance.mark && performance.measure) {
			try {
				const startMarkName = `${name}-start-${id}`;
				const endMarkName = `${name}-end-${id}`;
				const measureName = `${name}-duration-${id}`;
				
				performance.mark(endMarkName);
				performance.measure(measureName, startMarkName, endMarkName);
				
				const measure = performance.getEntriesByName(measureName)[0];
				duration = measure ? measure.duration : 0;
				
				// Netejar marks per evitar acumulació
				performance.clearMarks(startMarkName);
				performance.clearMarks(endMarkName);
				performance.clearMeasures(measureName);
			} catch (error) {
				// Fallback si performance API falla
				duration = 0;
			}
		}

		// Si no tenim performance API, usar timestamp estimat
		if (duration === 0) {
			const startTime = parseInt(id.split('_')[0]);
			duration = endTime - startTime;
		}

		const metric: PerformanceMetric = {
			id,
			name,
			duration,
			timestamp: endTime,
			category,
			metadata
		};

		this.addMetric(metric);

		// Log queries lentes
		if (category === 'database' && duration > this.SLOW_QUERY_THRESHOLD) {
			logAction('slow_query_detected', {
				query: name,
				duration,
				threshold: this.SLOW_QUERY_THRESHOLD,
				metadata
			});
		}

		return duration;
	}

	/**
	 * Mesurar funció amb wrapper automàtic
	 */
	async measure<T>(
		name: string,
		category: PerformanceMetric['category'],
		fn: () => Promise<T>,
		metadata?: Record<string, any>
	): Promise<T> {
		const id = this.startMeasurement(name, category);
		
		try {
			const result = await fn();
			this.endMeasurement(id, name, category, metadata);
			return result;
		} catch (error) {
			this.endMeasurement(id, name, category, { 
				...metadata, 
				error: (error as Error).message 
			});
			throw error;
		}
	}

	/**
	 * Registrar mètrica de base de dades
	 */
	recordDatabaseMetric(
		query: string, 
		duration: number, 
		params?: any, 
		resultCount?: number,
		error?: string
	): void {
		const metric: DatabaseMetric = {
			name: query,
			query,
			duration,
			timestamp: Date.now(),
			params,
			resultCount,
			error
		};

		this.databaseMetrics.update(metrics => {
			const newMetrics = [...metrics, metric];
			
			// Mantenir només les últimes mètriques
			if (newMetrics.length > this.MAX_METRICS) {
				return newMetrics.slice(-this.MAX_METRICS);
			}
			
			return newMetrics;
		});

		// Log queries lentes
		if (duration > this.SLOW_QUERY_THRESHOLD) {
			logAction('slow_database_query', {
				query,
				duration,
				params,
				resultCount,
				error
			});
		}
	}

	/**
	 * Actualitzar mètriques de cache
	 */
	updateCacheMetrics(key: string, hit: boolean, latency: number = 0): void {
		this.cacheMetrics.update(currentMetrics => {
			const existing = currentMetrics[key] || {
				key,
				hitCount: 0,
				missCount: 0,
				totalCount: 0,
				hitRate: 0,
				averageLatency: 0,
				lastAccess: Date.now(),
				size: 0
			};

			const totalAccesses = existing.hitCount + existing.missCount;
			const newHitCount = existing.hitCount + (hit ? 1 : 0);
			const newMissCount = existing.missCount + (hit ? 0 : 1);
			const newTotalAccesses = newHitCount + newMissCount;
			
			const updatedMetric: CacheMetric = {
				...existing,
				hitCount: newHitCount,
				missCount: newMissCount,
				totalCount: newTotalAccesses,
				hitRate: newTotalAccesses > 0 ? newHitCount / newTotalAccesses : 0,
				averageLatency: totalAccesses > 0 
					? (existing.averageLatency * totalAccesses + latency) / newTotalAccesses
					: latency,
				lastAccess: Date.now()
			};

			return {
				...currentMetrics,
				[key]: updatedMetric
			};
		});
	}

	/**
	 * Registrar mètrica de component
	 */
	recordComponentMetric(component: string, renderTime: number, propsCount: number = 0, route?: string): void {
		const metric: ComponentMetric = {
			component,
			renderTime,
			propsCount,
			timestamp: Date.now(),
			route
		};

		this.componentMetrics.update(metrics => {
			const newMetrics = [...metrics, metric];
			
			// Mantenir només les últimes mètriques
			if (newMetrics.length > this.MAX_METRICS) {
				return newMetrics.slice(-this.MAX_METRICS);
			}
			
			return newMetrics;
		});
	}

	/**
	 * Obtenir dashboard complet de rendiment
	 */
	async getDashboard(): Promise<PerformanceDashboard> {
		const metrics = get(this.metrics) as PerformanceMetric[];
		const cacheMetrics = get(this.cacheMetrics) as Record<string, CacheMetric>;
		const databaseMetrics = get(this.databaseMetrics) as DatabaseMetric[];
		const componentMetrics = get(this.componentMetrics) as ComponentMetric[];

		// Calcular estadístiques sumàries
		const totalRequests = metrics.length;
		const averageResponseTime = totalRequests > 0 
			? metrics.reduce((sum, m) => sum + m.duration, 0) / totalRequests 
			: 0;

		const slowestQueries = databaseMetrics
			.filter(m => m.duration > this.SLOW_QUERY_THRESHOLD)
			.sort((a, b) => b.duration - a.duration)
			.slice(0, 10);

		const totalCacheAccess = Object.values(cacheMetrics).reduce((sum, m) => sum + m.totalCount, 0);
		const totalCacheHits = Object.values(cacheMetrics).reduce((sum, m) => sum + m.hitCount, 0);
		const cacheHitRate = totalCacheAccess > 0 ? totalCacheHits / totalCacheAccess : 0;

		const totalErrors = metrics.filter(m => m.metadata?.error).length;
		const errorRate = totalRequests > 0 ? totalErrors / totalRequests : 0;

		return {
			metrics,
			cacheMetrics,
			databaseMetrics,
			componentMetrics,
			summary: {
				totalRequests,
				averageResponseTime,
				slowestQueries,
				cacheHitRate,
				errorRate,
				lastUpdated: Date.now()
			}
		};
	}

	/**
	 * Obtenir alertes de rendiment
	 */
	getPerformanceAlerts(): string[] {
		const alerts: string[] = [];
		const cacheMetrics = get(this.cacheMetrics) as Record<string, CacheMetric>;
		const databaseMetrics = get(this.databaseMetrics) as DatabaseMetric[];

		// Alerta per hit rate baix de cache
		const totalCacheAccess = Object.values(cacheMetrics).reduce((sum, m) => sum + m.totalCount, 0);
		const totalCacheHits = Object.values(cacheMetrics).reduce((sum, m) => sum + m.hitCount, 0);
		const cacheHitRate = totalCacheAccess > 0 ? totalCacheHits / totalCacheAccess : 0;

		if (cacheHitRate < 0.7 && totalCacheAccess > 10) {
			alerts.push(`Cache hit rate baix: ${(cacheHitRate * 100).toFixed(1)}%`);
		}

		// Alerta per queries lentes recents
		const recentSlowQueries = databaseMetrics
			.filter(m => m.duration > this.SLOW_QUERY_THRESHOLD && Date.now() - m.timestamp < 5 * 60 * 1000)
			.length;

		if (recentSlowQueries > 0) {
			alerts.push(`${recentSlowQueries} queries lentes en els últims 5 minuts`);
		}

		// Alerta per ús excessiu de memòria de cache
		const totalCacheSize = Object.values(cacheMetrics).reduce((sum, m) => sum + m.size, 0);
		if (totalCacheSize > 50 * 1024 * 1024) { // 50MB
			alerts.push(`Ús de cache alt: ${(totalCacheSize / 1024 / 1024).toFixed(1)}MB`);
		}

		return alerts;
	}

	private addMetric(metric: PerformanceMetric): void {
		this.metrics.update(metrics => {
			const newMetrics = [...metrics, metric];
			
			// Mantenir només les últimes mètriques
			if (newMetrics.length > this.MAX_METRICS) {
				return newMetrics.slice(-this.MAX_METRICS);
			}
			
			return newMetrics;
		});
	}

	private cleanOldMetrics(): void {
		const cutoffTime = Date.now() - (24 * 60 * 60 * 1000); // 24 hores
		
		this.metrics.update(metrics => 
			metrics.filter(m => m.timestamp > cutoffTime)
		);
		
		this.databaseMetrics.update(metrics => 
			metrics.filter(m => m.timestamp > cutoffTime)
		);
		
		this.componentMetrics.update(metrics => 
			metrics.filter(m => m.timestamp > cutoffTime)
		);

		// Neteja de mètriques de cache antigues
		this.cacheMetrics.update(metrics => {
			const filtered: Record<string, CacheMetric> = {};
			Object.entries(metrics as Record<string, CacheMetric>).forEach(([key, metric]) => {
				if (metric.lastAccess > cutoffTime) {
					filtered[key] = metric;
				}
			});
			return filtered;
		});
	}

	private saveToStorage(): void {
		if (!browser) return;

		try {
			const data = {
				cacheMetrics: get(this.cacheMetrics),
				timestamp: Date.now()
			};
			localStorage.setItem('performance_metrics', JSON.stringify(data));
		} catch (error) {
			console.warn('Failed to save performance metrics to storage:', error);
		}
	}

	private loadFromStorage(): void {
		if (!browser) return;

		try {
			const stored = localStorage.getItem('performance_metrics');
			if (stored) {
				const data = JSON.parse(stored);
				
				// Només carregar si no és massa antic (1 hora)
				if (Date.now() - data.timestamp < 60 * 60 * 1000) {
					this.cacheMetrics.set(data.cacheMetrics || {});
				}
			}
		} catch (error) {
			console.warn('Failed to load performance metrics from storage:', error);
		}
	}
}

// Instància global del monitor de rendiment
export const performanceMonitor = new PerformanceMonitor();