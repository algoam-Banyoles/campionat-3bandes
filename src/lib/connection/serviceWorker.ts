// Service Worker registration and management utilities

export interface ServiceWorkerManager {
  register(): Promise<ServiceWorkerRegistration | null>;
  unregister(): Promise<boolean>;
  checkForUpdates(): Promise<void>;
  getRegistration(): Promise<ServiceWorkerRegistration | null>;
  isSupported(): boolean;
  sendMessage(message: any): Promise<any>;
}

class CampionatServiceWorker implements ServiceWorkerManager {
  private registration: ServiceWorkerRegistration | null = null;
  private updateAvailable = false;

  constructor() {
    if (this.isSupported()) {
      this.setupEventListeners();
    }
  }

  isSupported(): boolean {
    return 'serviceWorker' in navigator && 'caches' in window;
  }

  async register(): Promise<ServiceWorkerRegistration | null> {
    if (!this.isSupported()) {
      console.warn('[SW] Service Worker not supported');
      return null;
    }

    try {
      // Vite-PWA registra automàticament el Service Worker
      // Només obtenim la registració existent
      this.registration = await navigator.serviceWorker.ready;

      console.log('[SW] Service Worker ready (managed by Vite-PWA)');

      // Handle updates
      this.registration.addEventListener('updatefound', () => {
        const newWorker = this.registration?.installing;
        if (newWorker) {
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              this.updateAvailable = true;
              this.notifyUpdateAvailable();
            }
          });
        }
      });

      return this.registration;

    } catch (error) {
      console.error('[SW] Service Worker registration failed:', error);
      return null;
    }
  }

  async unregister(): Promise<boolean> {
    if (!this.registration) {
      const registration = await navigator.serviceWorker.getRegistration();
      if (registration) {
        return registration.unregister();
      }
      return true;
    }

    return this.registration.unregister();
  }

  async checkForUpdates(): Promise<void> {
    if (!this.registration) {
      console.warn('[SW] No registration available for update check');
      return;
    }

    try {
      await this.registration.update();
    } catch (error) {
      console.error('[SW] Update check failed:', error);
    }
  }

  async getRegistration(): Promise<ServiceWorkerRegistration | null> {
    if (this.registration) {
      return this.registration;
    }

    const registration = await navigator.serviceWorker.getRegistration();
    return registration || null;
  }

  async sendMessage(message: any): Promise<any> {
    return new Promise((resolve, reject) => {
      if (!navigator.serviceWorker.controller) {
        reject(new Error('No service worker controller'));
        return;
      }

      const messageChannel = new MessageChannel();
      
      messageChannel.port1.onmessage = (event) => {
        resolve(event.data);
      };

      navigator.serviceWorker.controller.postMessage(message, [messageChannel.port2]);
    });
  }

  private setupEventListeners() {
    // Listen for messages from service worker
    navigator.serviceWorker.addEventListener('message', (event) => {
      const { type, data } = event.data;

      switch (type) {
        case 'BACKGROUND_SYNC_AVAILABLE':
          this.handleBackgroundSync();
          break;
        case 'CACHE_STATUS':
          this.handleCacheStatus(data);
          break;
      }
    });

    // Listen for controller changes (new SW taking over)
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      console.log('[SW] Controller changed, reloading page');
      window.location.reload();
    });
  }

  private notifyUpdateAvailable() {
    // Dispatch custom event for app to handle
    window.dispatchEvent(new CustomEvent('sw-update-available', {
      detail: { registration: this.registration }
    }));
  }

  private handleBackgroundSync() {
    // Notify offline queue manager
    window.dispatchEvent(new CustomEvent('sw-background-sync', {
      detail: { timestamp: new Date() }
    }));
  }

  private handleCacheStatus(status: any) {
    console.log('[SW] Cache status:', status);
    window.dispatchEvent(new CustomEvent('sw-cache-status', {
      detail: status
    }));
  }

  // Public methods for app integration

  async cacheApiResponse(url: string, responseData: any): Promise<void> {
    try {
      await this.sendMessage({
        type: 'CACHE_API_RESPONSE',
        data: { url, response: responseData }
      });
    } catch (error) {
      console.warn('[SW] Failed to cache API response:', error);
    }
  }

  async invalidateCache(pattern: string): Promise<void> {
    try {
      await this.sendMessage({
        type: 'INVALIDATE_CACHE',
        data: { pattern }
      });
    } catch (error) {
      console.warn('[SW] Failed to invalidate cache:', error);
    }
  }

  async prefetchResources(urls: string[]): Promise<void> {
    try {
      await this.sendMessage({
        type: 'PREFETCH_RESOURCES',
        data: { urls }
      });
    } catch (error) {
      console.warn('[SW] Failed to prefetch resources:', error);
    }
  }

  async getCacheStatus(): Promise<any> {
    try {
      return await this.sendMessage({
        type: 'GET_CACHE_STATUS'
      });
    } catch (error) {
      console.warn('[SW] Failed to get cache status:', error);
      return {};
    }
  }

  hasUpdateAvailable(): boolean {
    return this.updateAvailable;
  }

  async applyUpdate(): Promise<void> {
    if (!this.registration || !this.updateAvailable) {
      return;
    }

    const newWorker = this.registration.waiting;
    if (newWorker) {
      newWorker.postMessage({ type: 'SKIP_WAITING' });
    }
  }
}

// Singleton instance
export const serviceWorkerManager = new CampionatServiceWorker();

// Auto-register on load (only in production)
if (typeof window !== 'undefined' && import.meta.env.PROD) {
  window.addEventListener('load', () => {
    serviceWorkerManager.register().catch(console.error);
  });
}

// Utility functions
export async function registerServiceWorker(): Promise<ServiceWorkerRegistration | null> {
  return serviceWorkerManager.register();
}

export async function checkForServiceWorkerUpdates(): Promise<void> {
  return serviceWorkerManager.checkForUpdates();
}

export function isServiceWorkerSupported(): boolean {
  return serviceWorkerManager.isSupported();
}