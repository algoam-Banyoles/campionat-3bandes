/**
 * Configuració de Sentry per error tracking i logging estructurat
 */

import { browser, dev } from '$app/environment';
import type { AppError, ErrorContext } from './types';

// Configuració per diferents entorns
const SENTRY_CONFIG = {
	dsn: dev 
		? '' // No tracking en development per defecte
		: 'https://your-sentry-dsn@sentry.io/project-id', // Configurar amb el teu DSN
	environment: dev ? 'development' : 'production',
	tracesSampleRate: dev ? 0 : 0.1, // 10% sampling en producció
	debug: dev,
	enabled: !dev && browser, // Només en producció i al browser
	beforeSend: (event: any) => {
		// Filtrar errors no importants en development
		if (dev && event.exception) {
			const error = event.exception.values?.[0];
			if (error?.type === 'ChunkLoadError' || 
				error?.value?.includes('Loading chunk')) {
				return null; // No enviar errors de chunks
			}
		}
		return event;
	}
};

// Variable per controlar si Sentry està inicialitzat
let sentryInitialized = false;
let Sentry: any = null;

/**
 * Inicialitza Sentry (només al browser i en producció per defecte)
 */
export async function initializeSentry(): Promise<void> {
	if (sentryInitialized || !browser || !SENTRY_CONFIG.enabled) {
		return;
	}

	try {
		// Import dinàmic de Sentry
		const { init, captureException, addBreadcrumb, setContext, setUser } = await import('@sentry/sveltekit');
		
		Sentry = { init, captureException, addBreadcrumb, setContext, setUser };

		// Inicialitzar només si tenim DSN configurat
		if (SENTRY_CONFIG.dsn) {
			Sentry.init({
				dsn: SENTRY_CONFIG.dsn,
				environment: SENTRY_CONFIG.environment,
				tracesSampleRate: SENTRY_CONFIG.tracesSampleRate,
				debug: SENTRY_CONFIG.debug,
				beforeSend: SENTRY_CONFIG.beforeSend,
				integrations: [
					// Afegir integracions específiques si cal
				]
			});

			sentryInitialized = true;
			console.log(`Sentry initialized for ${SENTRY_CONFIG.environment}`);
		} else {
			console.warn('Sentry DSN not configured - error tracking disabled');
		}
	} catch (error) {
		console.error('Failed to initialize Sentry:', error);
	}
}

/**
 * Estableix informació de l'usuari per Sentry
 */
export function setSentryUser(user: {
	id?: string;
	email?: string;
	username?: string;
	numeroSoci?: number;
}): void {
	if (Sentry?.setUser) {
		Sentry.setUser({
			id: user.id,
			email: user.email,
			username: user.username,
			numeroSoci: user.numeroSoci
		});
	}
}

/**
 * Estableix context adicional per Sentry
 */
export function setSentryContext(key: string, context: Record<string, any>): void {
	if (Sentry?.setContext) {
		Sentry.setContext(key, context);
	}
}

/**
 * Afegeix breadcrumb per seguir el flow de l'usuari
 */
export function addBreadcrumb(
	message: string,
	category: string = 'user-action',
	level: 'debug' | 'info' | 'warning' | 'error' = 'info',
	data?: Record<string, any>
): void {
	if (Sentry?.addBreadcrumb) {
		Sentry.addBreadcrumb({
			message,
			category,
			level,
			data,
			timestamp: Date.now() / 1000
		});
	}

	// També log local en development
	if (dev) {
		console.log(`[Breadcrumb] ${category}: ${message}`, data);
	}
}

/**
 * Log d'error estructurat amb Sentry
 */
export function logError(error: AppError | Error): void {
	// Log local sempre (console)
	if (error instanceof Error && 'code' in error && 'userMessage' in error && 'severity' in error) {
		const appError = error as AppError;
		console.group(`🔴 ${appError.severity?.toUpperCase() || 'ERROR'}: ${appError.code}`);
		console.error('Message:', appError.message);
		console.error('User Message:', appError.userMessage);
		console.error('Context:', appError.context);
		console.error('Original Error:', appError.originalError);
		console.error('Stack:', appError.stack);
		console.groupEnd();
	} else {
		console.error('Error:', error);
	}

	// Enviar a Sentry si està configurat
	if (Sentry?.captureException && sentryInitialized) {
		if (error instanceof Error && 'code' in error && 'userMessage' in error && 'severity' in error) {
			const appError = error as AppError;
			
			// Només enviar errors i warnings crítiques
			if (appError.severity === 'error' || 
				(appError.severity === 'warning' && appError.code.includes('CRITICAL'))) {
				
				// Establir context per aquest error
				if (appError.context) {
					setSentryContext('appError', {
						code: appError.code,
						severity: appError.severity,
						userMessage: appError.userMessage,
						retryable: appError.retryable,
						...appError.context
					});
				}

				Sentry.captureException(appError.originalError || appError, {
					tags: {
						errorCode: appError.code,
						severity: appError.severity,
						retryable: appError.retryable
					},
					extra: {
						userMessage: appError.userMessage,
						context: appError.context
					}
				});
			}
		} else {
			// Error genèric
			Sentry.captureException(error);
		}
	}
}

/**
 * Log d'acció exitosa per breadcrumbs
 */
export function logSuccess(
	action: string,
	details?: Record<string, any>
): void {
	addBreadcrumb(
		`Action completed: ${action}`,
		'success',
		'info',
		details
	);

	if (dev) {
		console.log(`✅ ${action}`, details);
	}
}

/**
 * Log d'acció iniciada per breadcrumbs
 */
export function logAction(
	action: string,
	details?: Record<string, any>
): void {
	addBreadcrumb(
		`Action started: ${action}`,
		'action',
		'info',
		details
	);

	if (dev) {
		console.log(`▶️ ${action}`, details);
	}
}

/**
 * Log de navegació per breadcrumbs
 */
export function logNavigation(
	from: string,
	to: string,
	details?: Record<string, any>
): void {
	addBreadcrumb(
		`Navigation: ${from} → ${to}`,
		'navigation',
		'info',
		details
	);
}

/**
 * Wrapper per capturar errors en funcions async amb context automàtic
 */
export function withSentryContext<T extends (...args: any[]) => Promise<any>>(
	fn: T,
	context: ErrorContext
): T {
	return (async (...args: any[]) => {
		// Afegir context temporal
		setSentryContext('functionCall', context);
		
		try {
			const result = await fn(...args);
			logSuccess(`Function completed: ${context.action || 'unknown'}`, {
				context
			});
			return result;
		} catch (error) {
			// L'error ja es processarà pel ErrorHandler
			throw error;
		}
	}) as T;
}

/**
 * Configuració per activar Sentry manualment (útil per development)
 */
export function enableSentryForDevelopment(dsn?: string): void {
	if (dev && dsn) {
		SENTRY_CONFIG.dsn = dsn;
		SENTRY_CONFIG.enabled = true;
		initializeSentry();
	}
}

/**
 * Comprova si Sentry està actiu
 */
export function isSentryEnabled(): boolean {
	return sentryInitialized && SENTRY_CONFIG.enabled;
}

// Auto-inicialització si estem al browser
if (browser) {
	initializeSentry();
}