/**
 * Punt d'entrada principal del sistema d'errors robust
 * 
 * @fileoverview Sistema complet per gestionar errors amb:
 * - Classes d'error personalitzades amb contexte
 * - Missatges d'usuari en català
 * - Retry automàtic per errors temporals
 * - Logging amb Sentry
 * - Components UI per mostrar errors
 */

// Types i classes d'error
export type { 
	AppError, 
	ErrorSeverity, 
	ErrorContext, 
	ErrorCode 
} from './types';

export {
	BaseAppError,
	ValidationError,
	DatabaseError,
	AuthenticationError,
	NetworkError,
	BusinessError,
	UnknownError,
	ERROR_CODES
} from './types';

// Gestor central d'errors
export {
	ErrorFactory,
	ErrorHandler,
	errorHandler,
	handleError,
	withRetry,
	safeExecute,
	safeTry,
	withErrorHandling
} from './handler';

// Missatges d'usuari
export {
	getErrorMessage,
	ERROR_MESSAGES,
	CONTEXTUAL_MESSAGES,
	SUCCESS_MESSAGES
} from './messages';

// Sentry i logging
export {
	initializeSentry,
	setSentryUser,
	setSentryContext,
	addBreadcrumb,
	logError,
	logSuccess,
	logAction,
	logNavigation,
	withSentryContext,
	enableSentryForDevelopment,
	isSentryEnabled
} from './sentry';

// Store per toasts
export { toastStore } from '../stores/toastStore';

// Components UI
export { default as ErrorToast } from '../components/ErrorToast.svelte';
export { default as ErrorBoundary } from '../components/ErrorBoundary.svelte';
export { default as ToastContainer } from '../components/ToastContainer.svelte';

/**
 * Exemple d'ús bàsic:
 * 
 * ```typescript
 * import { handleError, ERROR_CODES, toastStore } from '$lib/errors';
 * 
 * try {
 *   await someFunction();
 * } catch (error) {
 *   const appError = handleError(error, ERROR_CODES.DATABASE_QUERY_ERROR, {
 *     component: 'MyComponent',
 *     action: 'load_data'
 *   });
 *   toastStore.showAppError(appError);
 * }
 * ```
 * 
 * Amb retry automàtic:
 * 
 * ```typescript
 * import { withRetry } from '$lib/errors';
 * 
 * const data = await withRetry(
 *   () => supabase.from('table').select('*'),
 *   { component: 'MyComponent', action: 'fetch_data' }
 * );
 * ```
 */