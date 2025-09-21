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
    isOnline: typeof navigator !== 'undefined' ? navigator.onLine : false,
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

    // Monitor browser online/offline events
    window.addEventListener('online', () => {
      this.handleOnlineEvent();
    });

    window.addEventListener('offline', () => {
      this.handleOfflineEvent();
    });

    // Initial connection check
    this.checkConnection();
  }

  private startHealthChecks() {
    if (typeof window === 'undefined') return;

    // Periodic health checks every 30 seconds when online
    this.healthCheckInterval = window.setInterval(() => {
      const state = get(this.connectionState);
      if (state.isOnline && !state.isRetrying) {
        this.checkConnection();
      }
    }, 30000);
  }

  private async handleOnlineEvent() {
    this.connectionState.update(state => ({
      ...state,
      isOnline: true
    }));

    this.addEvent({ type: 'online', timestamp: new Date() });
    
    // Check actual connection to Supabase
    await this.checkConnection();
  }

  private handleOfflineEvent() {
    this.connectionState.update(state => ({
      ...state,
      isOnline: false,
      isConnected: false,
      quality: 'offline',
      errorType: 'network'
    }));

    this.addEvent({ type: 'offline', timestamp: new Date() });
    this.stopRetrying();
  }

  private async checkConnection(): Promise<boolean> {
    const pingStart = performance.now();
    
    try {
      // Use a simple HTTP request to check Supabase availability
      // This avoids auth issues but still checks if Supabase is reachable
      const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
      const supabaseKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
      
      const response = await fetch(`${supabaseUrl}/rest/v1/`, {
        method: 'HEAD',
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`
        }
      });

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
    if (typeof navigator !== 'undefined' && !navigator.onLine) {
      return 'network';
    }

    if (error?.code?.startsWith('PGRST') || error?.message?.includes('JWT')) {
      return 'auth';
    }

    if (error?.message?.includes('fetch') || 
        error?.message?.includes('network') ||
        error?.code === 'NETWORK_ERROR') {
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
    if (!state.isOnline && !options.immediateRetry) {
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