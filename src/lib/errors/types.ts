/**
 * Sistema d'errors robust per a l'aplicació de campionat de 3 bandes
 */

export type ErrorSeverity = 'error' | 'warning' | 'info' | 'success';

export type ErrorContext = {
	userId?: string;
	page?: string;
	action?: string;
	component?: string;
	data?: Record<string, any>;
	timestamp?: string;
	userAgent?: string;
	url?: string;
};

export interface AppError {
	code: string;
	message: string;
	userMessage: string;
	severity: ErrorSeverity;
	context?: ErrorContext;
	originalError?: Error;
	retryable?: boolean;
	stack?: string;
}

/**
 * Error base personalitzat que implementa la interface AppError
 */
export abstract class BaseAppError extends Error implements AppError {
	public readonly code: string;
	public readonly userMessage: string;
	public readonly severity: ErrorSeverity;
	public readonly context?: ErrorContext;
	public readonly originalError?: Error;
	public readonly retryable: boolean;

	constructor(
		code: string,
		message: string,
		userMessage: string,
		severity: ErrorSeverity = 'error',
		context?: ErrorContext,
		originalError?: Error,
		retryable: boolean = false
	) {
		super(message);
		this.name = this.constructor.name;
		this.code = code;
		this.userMessage = userMessage;
		this.severity = severity;
		this.context = {
			...context,
			timestamp: new Date().toISOString()
		};
		this.originalError = originalError;
		this.retryable = retryable;

		// Mantenir stack trace
		if (Error.captureStackTrace) {
			Error.captureStackTrace(this, this.constructor);
		}
	}
}

/**
 * Errors de validació (camps obligatoris, formats incorrectes, etc.)
 */
export class ValidationError extends BaseAppError {
	constructor(
		code: string,
		message: string,
		userMessage: string,
		context?: ErrorContext,
		originalError?: Error
	) {
		super(code, message, userMessage, 'warning', context, originalError, false);
	}
}

/**
 * Errors de base de dades (connexió, consultes, integritat, etc.)
 */
export class DatabaseError extends BaseAppError {
	constructor(
		code: string,
		message: string,
		userMessage: string,
		context?: ErrorContext,
		originalError?: Error,
		retryable: boolean = true
	) {
		super(code, message, userMessage, 'error', context, originalError, retryable);
	}
}

/**
 * Errors d'autenticació i autorització
 */
export class AuthenticationError extends BaseAppError {
	constructor(
		code: string,
		message: string,
		userMessage: string,
		context?: ErrorContext,
		originalError?: Error
	) {
		super(code, message, userMessage, 'error', context, originalError, false);
	}
}

/**
 * Errors de xarxa (connexió, timeout, etc.)
 */
export class NetworkError extends BaseAppError {
	constructor(
		code: string,
		message: string,
		userMessage: string,
		context?: ErrorContext,
		originalError?: Error,
		retryable: boolean = true
	) {
		super(code, message, userMessage, 'error', context, originalError, retryable);
	}
}

/**
 * Errors de negoci (regles del campionat, permisos, etc.)
 */
export class BusinessError extends BaseAppError {
	constructor(
		code: string,
		message: string,
		userMessage: string,
		context?: ErrorContext,
		originalError?: Error
	) {
		super(code, message, userMessage, 'warning', context, originalError, false);
	}
}

/**
 * Errors no classificats o inesperats
 */
export class UnknownError extends BaseAppError {
	constructor(
		message: string,
		context?: ErrorContext,
		originalError?: Error
	) {
		super(
			'UNKNOWN_ERROR',
			message,
			'S\'ha produït un error inesperat. Si us plau, torna-ho a intentar.',
			'error',
			context,
			originalError,
			true
		);
	}
}

/**
 * Error codes constants per a tipatge estàtic
 */
export const ERROR_CODES = {
	// Validació
	VALIDATION_REQUIRED_FIELD: 'VALIDATION_REQUIRED_FIELD',
	VALIDATION_INVALID_FORMAT: 'VALIDATION_INVALID_FORMAT',
	VALIDATION_INVALID_RANGE: 'VALIDATION_INVALID_RANGE',
	
	// Base de dades
	DATABASE_CONNECTION_ERROR: 'DATABASE_CONNECTION_ERROR',
	DATABASE_QUERY_ERROR: 'DATABASE_QUERY_ERROR',
	DATABASE_CONSTRAINT_ERROR: 'DATABASE_CONSTRAINT_ERROR',
	
	// Autenticació
	AUTH_INVALID_CREDENTIALS: 'AUTH_INVALID_CREDENTIALS',
	AUTH_SESSION_EXPIRED: 'AUTH_SESSION_EXPIRED',
	AUTH_INSUFFICIENT_PERMISSIONS: 'AUTH_INSUFFICIENT_PERMISSIONS',
	
	// Xarxa
	NETWORK_CONNECTION_ERROR: 'NETWORK_CONNECTION_ERROR',
	NETWORK_TIMEOUT: 'NETWORK_TIMEOUT',
	NETWORK_SERVER_ERROR: 'NETWORK_SERVER_ERROR',
	
	// Reptes
	CHALLENGE_INVALID_PLAYER: 'CHALLENGE_INVALID_PLAYER',
	CHALLENGE_POSITION_INVALID: 'CHALLENGE_POSITION_INVALID',
	CHALLENGE_ALREADY_EXISTS: 'CHALLENGE_ALREADY_EXISTS',
	CHALLENGE_COOLDOWN_ACTIVE: 'CHALLENGE_COOLDOWN_ACTIVE',
	
	// Rànquing
	RANKING_NOT_FOUND: 'RANKING_NOT_FOUND',
	RANKING_INVALID_POSITION: 'RANKING_INVALID_POSITION',
	RANKING_UPDATE_ERROR: 'RANKING_UPDATE_ERROR',
	
	// Socis
	MEMBER_NOT_FOUND: 'MEMBER_NOT_FOUND',
	MEMBER_NOT_ACTIVE: 'MEMBER_NOT_ACTIVE',
	MEMBER_DUPLICATE: 'MEMBER_DUPLICATE',
	
	// General
	UNKNOWN_ERROR: 'UNKNOWN_ERROR',
	PERMISSION_DENIED: 'PERMISSION_DENIED',
	RESOURCE_NOT_FOUND: 'RESOURCE_NOT_FOUND'
} as const;

export type ErrorCode = typeof ERROR_CODES[keyof typeof ERROR_CODES];