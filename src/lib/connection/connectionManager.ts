import { writable, derived, get } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import type { PostgrestError } from '@supabase/supabase-js';

export interface ConnectionState {
  isOnline: boolean;
  isConnected: boolean;
  lastConnected: Date | null;
  retryCount: number;
  retryDelay: number;
  isRetrying: boolean;
  errorType: 'network' | 'server' | 'auth' | null;
  quality: 'excellent' | 'good' | 'poor' | 'offline';
}

export interface RetryOptions {
  maxRetries: number;
  baseDelay: number;
  maxDelay: number;
  backoffFactor: number;
  immediateRetry?: boolean;
}

export interface ConnectionEvent {
  type: 'online' | 'offline' | 'connected' | 'disconnected' | 'retry' | 'error';
  timestamp: Date;
  details?: any;
}

class ConnectionManager {
  private connectionState = writable<ConnectionState>({
    isOnline: true, // SEMPRE assumir online, validarem amb fetch real
    isConnected: false,
    lastConnected: null,
    retryCount: 0,
    retryDelay: 1000,
    isRetrying: false,
    errorType: null,
    quality: 'offline'
  });

  private connectionEvents = writable<ConnectionEvent[]>([]);
  private retryTimeoutId: number | null = null;
  private healthCheckInterval: number | null = null;
  private lastPingTime: number = 0;

  // Default retry strategies per operation type
  private retryStrategies: Record<string, RetryOptions> = {
    critical: {
      maxRetries: 5,
      baseDelay: 500,
      maxDelay: 10000,
      backoffFactor: 2,
      immediateRetry: true
    },
    standard: {
      maxRetries: 3,
      baseDelay: 1000,
      maxDelay: 8000,
      backoffFactor: 1.5
    },
    background: {
      maxRetries: 2,
      baseDelay: 2000,
      maxDelay: 15000,
      backoffFactor: 2
    }
  };

  constructor() {
    // Only initialize in browser environment
    if (typeof window !== 'undefined') {
      this.initializeConnectionMonitoring();
      this.startHealthChecks();
    }
  }

  private initializeConnectionMonitoring() {
    if (typeof window === 'undefined') return;

    // NO utilitzar navigator.onLine - és poc fiable en Safari/iOS PWA
    // En lloc d'això, confiar únicament en checks amb fetch real

    // Detectar si som en PWA standalone (més propens a falsos offline)
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches
      || (window.navigator as any).standalone === true
      || document.referrer.includes('android-app://');

    if (isStandalone) {
      console.log('[ConnectionManager] Running in standalone PWA mode - using real fetch checks only');
    }

    // NOMÉS escoltar event 'online' (no 'offline') i només en mode navegador
    // En standalone PWA, ignorar completament events del navegador
    if (!isStandalone) {
      window.addEventListener('online', () => {
        console.log('[ConnectionManager] Browser reports online - verifying with real check');
        this.checkConnection();
      });
    }

    // Initial connection check
    this.checkConnection();
  }

  private startHealthChecks() {
    if (typeof window === 'undefined') return;

    // Skip health checks if running in iframe to avoid false offline detection
    if (window.self !== window.top) {
      console.log('[ConnectionManager] Running in iframe, health checks disabled');
      return;
    }

    // Detectar si estem en background/sleep mode (Safari)
    let isVisible = !document.hidden;
    let wakeupCheckDone = false;

    document.addEventListener('visibilitychange', () => {
      const wasHidden = !isVisible;
      isVisible = !document.hidden;

      if (isVisible && wasHidden) {
        // Quan tornem a primer pla després de sleep, esperar 2s abans de check
        // Safari necessita temps per restaurar connexions
        console.log('[ConnectionManager] App woke up from background, checking connection...');
        wakeupCheckDone = false;
        setTimeout(() => {
          this.checkConnection();
          wakeupCheckDone = true;
        }, 2000);
      }
    });

    // Periodic health checks NOMÉS si estem connectats i visibles
    // Reduït a 120s per evitar overhead en Safari
    this.healthCheckInterval = window.setInterval(() => {
      const state = get(this.connectionState);
      // NO fer check si acabem de despertar (ja s'ha fet)
      if (isVisible && (state as any).isConnected && !(state as any).isRetrying && wakeupCheckDone) {
        this.checkConnection();
      }
      wakeupCheckDone = true; // Reset flag
    }, 120000); // 120s = 2 minuts
  }

  private async handleOnlineEvent() {
    // Només update si realment podem connectar (validació real)
    const isReallyOnline = await this.checkConnection();

    if (isReallyOnline) {
      this.addEvent({ type: 'online', timestamp: new Date() });
    }
  }

  private async checkConnection(): Promise<boolean> {
    const pingStart = performance.now();

    try {
      // Use a simple HTTP request to check Supabase availability
      // This avoids auth issues but still checks if Supabase is reachable
      const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
      const supabaseKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

      // Crear AbortController per timeout
      // AUGMENTAT a 15s per Safari iOS en standalone mode (pot ser lent després de sleep)
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 15000);

      const response = await fetch(`${supabaseUrl}/rest/v1/`, {
        method: 'HEAD',
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`
        },
        signal: controller.signal,
        cache: 'no-store', // No usar cache per check de connexió
        // Afegir mode cors explícit per PWA
        mode: 'cors'
      });

      clearTimeout(timeoutId);
      const pingTime = performance.now() - pingStart;
      this.lastPingTime = pingTime;

      // If we get any response (even 401/400), it means Supabase is reachable
      // We just want to know if the service is up, not if we're authenticated
      if (!response.ok && response.status >= 500) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      // Connection successful
      this.connectionState.update(state => ({
        ...state,
        isConnected: true,
        lastConnected: new Date(),
        retryCount: 0,
        retryDelay: this.retryStrategies.standard.baseDelay,
        isRetrying: false,
        errorType: null,
        quality: this.calculateConnectionQuality(pingTime)
      }));

      this.addEvent({ 
        type: 'connected', 
        timestamp: new Date(),
        details: { pingTime }
      });

      return true;

    } catch (error) {
      const errorType = this.determineErrorType(error);
      
      this.connectionState.update(state => ({
        ...state,
        isConnected: false,
        errorType,
        quality: 'offline'
      }));

      this.addEvent({ 
        type: 'error', 
        timestamp: new Date(),
        details: { 
          error: error instanceof Error ? error.message : String(error), 
          type: errorType 
        }
      });

      return false;
    }
  }

  private determineErrorType(error: any): 'network' | 'server' | 'auth' {
    // NO usar navigator.onLine - és poc fiable en Safari/iOS

    if (error?.code?.startsWith('PGRST') || error?.message?.includes('JWT')) {
      return 'auth';
    }

    // Errors de timeout o abort són problemes de xarxa
    if (error?.name === 'AbortError' || error?.message?.includes('aborted')) {
      return 'network';
    }

    if (error?.message?.includes('fetch') ||
        error?.message?.includes('network') ||
        error?.code === 'NETWORK_ERROR' ||
        error?.message?.includes('Failed to fetch')) {
      return 'network';
    }

    return 'server';
  }

  private calculateConnectionQuality(pingTime: number): 'excellent' | 'good' | 'poor' | 'offline' {
    if (pingTime < 200) return 'excellent';
    if (pingTime < 500) return 'good';
    if (pingTime < 2000) return 'poor';
    return 'offline';
  }

  private addEvent(event: ConnectionEvent) {
    this.connectionEvents.update(events => {
      const newEvents = [event, ...events].slice(0, 50); // Keep last 50 events
      return newEvents;
    });
  }

  private stopRetrying() {
    if (this.retryTimeoutId) {
      clearTimeout(this.retryTimeoutId);
      this.retryTimeoutId = null;
    }

    this.connectionState.update(state => ({
      ...state,
      isRetrying: false
    }));
  }

  // Public API
  async executeWithRetry<T>(
    operation: () => Promise<T>,
    strategy: keyof typeof this.retryStrategies = 'standard',
    customOptions?: Partial<RetryOptions>
  ): Promise<T> {
    const options = { ...this.retryStrategies[strategy], ...customOptions };
    const state = get(this.connectionState);

    // If offline and no immediate retry, throw immediately
    if (!(state as any).isOnline && !options.immediateRetry) {
      throw new Error('OFFLINE_MODE');
    }

    let lastError: any;
    let retryCount = 0;

    while (retryCount <= options.maxRetries) {
      try {
        const result = await operation();
        
        // Success - reset retry state if this was a retry
        if (retryCount > 0) {
          this.connectionState.update(s => ({
            ...s,
            retryCount: 0,
            retryDelay: options.baseDelay,
            isRetrying: false
          }));
        }

        return result;

      } catch (error) {
        lastError = error;
        retryCount++;

        // Check if we should retry
        if (retryCount > options.maxRetries) {
          break;
        }

        const errorType = this.determineErrorType(error);
        
        // Don't retry auth errors
        if (errorType === 'auth') {
          break;
        }

        // Calculate delay with exponential backoff
        const delay = Math.min(
          options.baseDelay * Math.pow(options.backoffFactor, retryCount - 1),
          options.maxDelay
        );

        this.connectionState.update(s => ({
          ...s,
          retryCount,
          retryDelay: delay,
          isRetrying: true,
          errorType
        }));

        this.addEvent({
          type: 'retry',
          timestamp: new Date(),
          details: { attempt: retryCount, delay }
        });

        // Wait before retry
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }

    // All retries failed
    this.connectionState.update(s => ({
      ...s,
      isRetrying: false
    }));

    throw lastError;
  }

  async forceConnectionCheck(): Promise<boolean> {
    return await this.checkConnection();
  }

  getConnectionState() {
    return { subscribe: this.connectionState.subscribe };
  }

  getConnectionEvents() {
    return { subscribe: this.connectionEvents.subscribe };
  }

  getConnectionQuality() {
    return derived(this.connectionState, $state => $state.quality);
  }

  isOnline() {
    return derived(this.connectionState, $state => $state.isOnline);
  }

  isConnected() {
    return derived(this.connectionState, $state => $state.isConnected);
  }

  getLastPingTime(): number {
    return this.lastPingTime;
  }

  destroy() {
    this.stopRetrying();
    
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
    }

    if (typeof window !== 'undefined') {
      window.removeEventListener('online', this.handleOnlineEvent);
      window.removeEventListener('offline', this.handleOfflineEvent);
    }
  }
}

// Singleton instance
export const connectionManager = new ConnectionManager();

// Convenient derived stores
export const connectionState = connectionManager.getConnectionState();
export const connectionEvents = connectionManager.getConnectionEvents();
export const connectionQuality = connectionManager.getConnectionQuality();
export const isOnline = connectionManager.isOnline();
export const isConnected = connectionManager.isConnected();

// Utility functions
export async function withConnection<T>(
  operation: () => Promise<T>,
  strategy: 'critical' | 'standard' | 'background' = 'standard'
): Promise<T> {
  return connectionManager.executeWithRetry(operation, strategy);
}

export async function checkConnection(): Promise<boolean> {
  return connectionManager.forceConnectionCheck();
}