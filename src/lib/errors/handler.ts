/**
 * Gestor central d'errors amb factory pattern, retry automàtic i gestió de context
 */

import { browser } from '$app/environment';
import type { 
	AppError, 
	ErrorContext, 
	ErrorCode, 
	ErrorSeverity 
} from './types';
import {
	ValidationError,
	DatabaseError,
	AuthenticationError,
	NetworkError,
	BusinessError,
	UnknownError,
	ERROR_CODES
} from './types';
import { getErrorMessage } from './messages';
import { logError } from './sentry';

/**
 * Configuració per al retry automàtic
 */
interface RetryConfig {
	maxAttempts: number;
	delay: number;
	backoffMultiplier: number;
	retryableErrors: string[];
}

const DEFAULT_RETRY_CONFIG: RetryConfig = {
	maxAttempts: 3,
	delay: 1000,
	backoffMultiplier: 2,
	retryableErrors: [
		ERROR_CODES.NETWORK_CONNECTION_ERROR,
		ERROR_CODES.NETWORK_TIMEOUT,
		ERROR_CODES.DATABASE_CONNECTION_ERROR,
		ERROR_CODES.DATABASE_QUERY_ERROR
	]
};

/**
 * Factory per crear errors específics
 */
export class ErrorFactory {
	static createError(
		code: ErrorCode,
		originalError?: Error,
		context?: ErrorContext
	): AppError {
		const message = originalError?.message || 'Unknown error';
		const errorMessage = getErrorMessage(code, context?.component || context?.page);
		
		// Detectar tipus d'error per código
		if (code.startsWith('VALIDATION_')) {
			return new ValidationError(
				code,
				message,
				errorMessage.userMessage,
				context,
				originalError
			);
		}
		
		if (code.startsWith('DATABASE_')) {
			return new DatabaseError(
				code,
				message,
				errorMessage.userMessage,
				context,
				originalError,
				DEFAULT_RETRY_CONFIG.retryableErrors.includes(code)
			);
		}
		
		if (code.startsWith('AUTH_')) {
			return new AuthenticationError(
				code,
				message,
				errorMessage.userMessage,
				context,
				originalError
			);
		}
		
		if (code.startsWith('NETWORK_')) {
			return new NetworkError(
				code,
				message,
				errorMessage.userMessage,
				context,
				originalError,
				DEFAULT_RETRY_CONFIG.retryableErrors.includes(code)
			);
		}
		
		if (code.startsWith('CHALLENGE_') || code.startsWith('RANKING_') || code.startsWith('MEMBER_')) {
			return new BusinessError(
				code,
				message,
				errorMessage.userMessage,
				context,
				originalError
			);
		}
		
		return new UnknownError(message, context, originalError);
	}
}

/**
 * Gestor central d'errors
 */
export class ErrorHandler {
	private static instance: ErrorHandler;
	private retryConfig: RetryConfig;
	private globalContext: Partial<ErrorContext> = {};

	private constructor(retryConfig: RetryConfig = DEFAULT_RETRY_CONFIG) {
		this.retryConfig = retryConfig;
		this.initializeGlobalContext();
	}

	static getInstance(): ErrorHandler {
		if (!ErrorHandler.instance) {
			ErrorHandler.instance = new ErrorHandler();
		}
		return ErrorHandler.instance;
	}

	/**
	 * Inicialitza context global (URL, user agent, etc.)
	 */
	private initializeGlobalContext(): void {
		if (browser) {
			this.globalContext = {
				userAgent: navigator.userAgent,
				url: window.location.href,
				timestamp: new Date().toISOString()
			};
		}
	}

	/**
	 * Actualitza context global (ex: quan l'usuari fa login)
	 */
	public updateGlobalContext(context: Partial<ErrorContext>): void {
		this.globalContext = { ...this.globalContext, ...context };
	}

	/**
	 * Maneja un error i el converteix en AppError
	 */
	public handleError(
		error: unknown,
		code?: ErrorCode,
		context?: Partial<ErrorContext>
	): AppError {
		const fullContext: ErrorContext = {
			...this.globalContext,
			...context,
			timestamp: new Date().toISOString()
		};

		let appError: AppError;

		// Si ja és un AppError, només actualitzem context
		if (this.isAppError(error)) {
			appError = error;
			appError.context = { ...appError.context, ...fullContext };
		} else {
			// Detectar error automàticament si no es proporciona code
			const detectedCode = code || this.detectErrorCode(error);
			appError = ErrorFactory.createError(
				detectedCode,
				error instanceof Error ? error : new Error(String(error)),
				fullContext
			);
		}

		// Log de l'error
		logError(appError);

		return appError;
	}

	/**
	 * Executa una funció amb retry automàtic
	 */
	public async withRetry<T>(
		fn: () => Promise<T>,
		context?: Partial<ErrorContext>,
		customRetryConfig?: Partial<RetryConfig>
	): Promise<T> {
		const config = { ...this.retryConfig, ...customRetryConfig };
		let lastError: AppError | undefined;

		for (let attempt = 1; attempt <= config.maxAttempts; attempt++) {
			try {
				return await fn();
			} catch (error) {
				const appError = this.handleError(error, undefined, {
					...context,
					action: `${context?.action || 'retry'}_attempt_${attempt}`
				});

				lastError = appError;

				// No retry si no és retryable o és l'últim intent
				if (!appError.retryable || attempt === config.maxAttempts) {
					break;
				}

				// Esperar abans del següent intent amb backoff exponencial
				const delay = config.delay * Math.pow(config.backoffMultiplier, attempt - 1);
				await this.sleep(delay);
			}
		}

		throw lastError;
	}

	/**
	 * Executa una funció amb gestió d'errors automàtica
	 */
	public async safeExecute<T>(
		fn: () => Promise<T>,
		fallback?: T,
		context?: Partial<ErrorContext>
	): Promise<T | undefined> {
		try {
			return await fn();
		} catch (error) {
			const appError = this.handleError(error, undefined, context);
			
			// Si és crític, rethrow
			if (appError.severity === 'error') {
				throw appError;
			}

			// Si hi ha fallback, el retornem
			if (fallback !== undefined) {
				return fallback;
			}

			return undefined;
		}
	}

	/**
	 * Detecció automàtica de tipus d'error
	 */
	private detectErrorCode(error: unknown): ErrorCode {
		if (error instanceof Error) {
			const message = error.message.toLowerCase();
			
			// Errors de xarxa
			if (message.includes('fetch') || message.includes('network') || 
				message.includes('connection') || message.includes('timeout')) {
				return ERROR_CODES.NETWORK_CONNECTION_ERROR;
			}
			
			// Errors de Supabase
			if (message.includes('supabase') || message.includes('postgresql')) {
				if (message.includes('connection')) {
					return ERROR_CODES.DATABASE_CONNECTION_ERROR;
				}
				if (message.includes('constraint') || message.includes('unique')) {
					return ERROR_CODES.DATABASE_CONSTRAINT_ERROR;
				}
				return ERROR_CODES.DATABASE_QUERY_ERROR;
			}
			
			// Errors d'autenticació
			if (message.includes('unauthorized') || message.includes('invalid_grant') ||
				message.includes('authentication')) {
				return ERROR_CODES.AUTH_INVALID_CREDENTIALS;
			}
			
			// Errors de validació
			if (message.includes('required') || message.includes('validation') ||
				message.includes('invalid format')) {
				return ERROR_CODES.VALIDATION_REQUIRED_FIELD;
			}
		}

		return ERROR_CODES.UNKNOWN_ERROR;
	}

	/**
	 * Comprova si un error és del tipus AppError
	 */
	private isAppError(error: unknown): error is AppError {
		return typeof error === 'object' && 
			   error !== null && 
			   'code' in error && 
			   'userMessage' in error && 
			   'severity' in error;
	}

	/**
	 * Sleep utility per delays
	 */
	private sleep(ms: number): Promise<void> {
		return new Promise(resolve => setTimeout(resolve, ms));
	}
}

/**
 * Instància global del gestor d'errors
 */
export const errorHandler = ErrorHandler.getInstance();

/**
 * Funció helper per manegar errors de forma simple
 */
export function handleError(
	error: unknown,
	code?: ErrorCode,
	context?: Partial<ErrorContext>
): AppError {
	return errorHandler.handleError(error, code, context);
}

/**
 * Funció helper per retry automàtic
 */
export function withRetry<T>(
	fn: () => Promise<T>,
	context?: Partial<ErrorContext>,
	retryConfig?: Partial<RetryConfig>
): Promise<T> {
	return errorHandler.withRetry(fn, context, retryConfig);
}

/**
 * Funció helper per execució segura
 */
export function safeExecute<T>(
	fn: () => Promise<T>,
	fallback?: T,
	context?: Partial<ErrorContext>
): Promise<T | undefined> {
	return errorHandler.safeExecute(fn, fallback, context);
}

/**
 * Wrapper per funcions síncrones que poden fallar
 */
export function safeTry<T>(
	fn: () => T,
	fallback?: T,
	context?: Partial<ErrorContext>
): T | undefined {
	try {
		return fn();
	} catch (error) {
		const appError = handleError(error, undefined, context);
		
		if (appError.severity === 'error') {
			throw appError;
		}
		
		return fallback;
	}
}

/**
 * Decorador per mètodes que necessitin gestió d'errors automàtica
 */
export function withErrorHandling(
	code?: ErrorCode,
	context?: Partial<ErrorContext>
) {
	return function<T extends (...args: any[]) => any>(
		target: any,
		propertyKey: string,
		descriptor: TypedPropertyDescriptor<T>
	): TypedPropertyDescriptor<T> {
		const originalMethod = descriptor.value;
		
		if (!originalMethod) return descriptor;
		
		descriptor.value = function(this: any, ...args: any[]) {
			try {
				const result = originalMethod.apply(this, args);
				
				// Si és una promesa, manejarem errors async
				if (result instanceof Promise) {
					return result.catch((error: unknown) => {
						throw handleError(error, code, {
							...context,
							component: target.constructor.name,
							action: propertyKey
						});
					});
				}
				
				return result;
			} catch (error) {
				throw handleError(error, code, {
					...context,
					component: target.constructor.name,
					action: propertyKey
				});
			}
		} as T;
		
		return descriptor;
	};
}