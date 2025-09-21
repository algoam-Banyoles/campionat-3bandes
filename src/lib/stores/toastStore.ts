/**
 * Store global per gestionar toasts i notificacions d'error
 */

import { writable } from 'svelte/store';
import type { AppError, ErrorSeverity } from '../errors/types';

export interface Toast {
	id: string;
	error?: AppError;
	message?: string;
	severity: ErrorSeverity;
	autoClose: boolean;
	duration: number;
	timestamp: number;
}

interface ToastStore {
	toasts: Toast[];
}

// Store principal
const { subscribe, update } = writable<ToastStore>({
	toasts: []
});

// Comptador per generar IDs únics
let toastCounter = 0;

/**
 * Afegeix un toast amb un AppError
 */
export function addErrorToast(
	error: AppError,
	options: {
		autoClose?: boolean;
		duration?: number;
	} = {}
): string {
	const id = `toast-error-${++toastCounter}`;
	const toast: Toast = {
		id,
		error,
		severity: error.severity,
		autoClose: options.autoClose ?? (error.severity !== 'error'),
		duration: options.duration ?? (error.severity === 'error' ? 8000 : 5000),
		timestamp: Date.now()
	};

	update(store => ({
		...store,
		toasts: [...store.toasts, toast]
	}));

	return id;
}

/**
 * Afegeix un toast amb missatge personalitzat
 */
export function addToast(
	message: string,
	severity: ErrorSeverity = 'info',
	options: {
		autoClose?: boolean;
		duration?: number;
	} = {}
): string {
	const id = `toast-message-${++toastCounter}`;
	const toast: Toast = {
		id,
		message,
		severity,
		autoClose: options.autoClose ?? true,
		duration: options.duration ?? 4000,
		timestamp: Date.now()
	};

	update(store => ({
		...store,
		toasts: [...store.toasts, toast]
	}));

	return id;
}

/**
 * Elimina un toast per ID
 */
export function removeToast(id: string): void {
	update(store => ({
		...store,
		toasts: store.toasts.filter(toast => toast.id !== id)
	}));
}

/**
 * Neteja tots els toasts
 */
export function clearAllToasts(): void {
	update(store => ({
		...store,
		toasts: []
	}));
}

/**
 * Helpers per diferents tipus de missatges
 */
export function showSuccess(message: string, duration = 3000): string {
	return addToast(message, 'success', { duration });
}

export function showError(message: string, duration = 6000): string {
	return addToast(message, 'error', { duration, autoClose: false });
}

export function showWarning(message: string, duration = 5000): string {
	return addToast(message, 'warning', { duration });
}

export function showInfo(message: string, duration = 4000): string {
	return addToast(message, 'info', { duration });
}

/**
 * Helper per mostrar AppError directament
 */
export function showAppError(error: AppError): string {
	return addErrorToast(error);
}

// Export del store per usar en components
export const toastStore = {
	subscribe,
	addErrorToast,
	addToast,
	removeToast,
	clearAllToasts,
	showSuccess,
	showError,
	showWarning,
	showInfo,
	showAppError
};