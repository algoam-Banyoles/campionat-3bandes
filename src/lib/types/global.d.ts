// Global type declarations for Svelte 5 compatibility
declare global {
	// Fix svelteHTML namespace issues in Svelte 5
	namespace svelteHTML {
		interface HTMLAttributes<T = any> {
			[key: string]: any;
		}
		interface IntrinsicElements {
			[elemName: string]: any;
		}
	}
	
	// NodeJS namespace for Timeout types
	namespace NodeJS {
		interface Timeout {
			ref(): this;
			unref(): this;
		}
	}
	
	// Additional globals if needed
	var svelteHTML: any;
}

// SvelteKit module declarations
declare module '$app/navigation' {
	export function goto(url: string | URL, opts?: any): Promise<void>;
	export function invalidate(dependency: string | ((url: URL) => boolean)): Promise<void>;
	export function invalidateAll(): Promise<void>;
	export function preloadData(href: string): Promise<any>;
	export function preloadCode(...urls: string[]): Promise<void>;
	export function beforeNavigate(fn: any): void;
	export function afterNavigate(fn: any): void;
	export function disableScrollHandling(): void;
	export function pushState(url: string | URL, state: any): void;
	export function replaceState(url: string | URL, state: any): void;
}

declare module '$app/environment' {
	export const browser: boolean;
	export const building: boolean;
	export const dev: boolean;
	export const version: string;
}

declare module '$app/stores' {
	export const navigating: any;
	export const page: any;
	export const updated: any;
}

declare module 'svelte' {
	export function onMount(fn: () => void | (() => void)): void;
	export function onDestroy(fn: () => void): void;
	export function createEventDispatcher(): any;
	export function tick(): Promise<void>;
	export function getContext(key: any): any;
	export function setContext(key: any, context: any): void;
	export function hasContext(key: any): boolean;
}

declare module 'svelte/store' {
	export function writable<T>(value?: T): any;
	export function readable<T>(value?: T, start?: any): any;
	export function derived<T>(stores: any, fn: any): any;
	export function get<T>(store: any): T;
}

export {};