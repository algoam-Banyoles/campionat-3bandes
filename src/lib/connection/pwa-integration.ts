// Integració PWA per gestionar service workers de manera coordinada

interface PWAManager {
  init(): Promise<void>;
  checkForUpdates(): Promise<void>;
  getOfflineStatus(): Promise<boolean>;
}

class PWAIntegration implements PWAManager {
  private vitePwaRegistration: ServiceWorkerRegistration | null = null;
  private customSWRegistration: ServiceWorkerRegistration | null = null;
  private readonly APP_VERSION = '2.0.0'; // Incrementar aquesta versió per forçar neteja de cache

  async init(): Promise<void> {
    if (!('serviceWorker' in navigator)) {
      console.warn('[PWA] Service Workers not supported');
      return;
    }

    try {
      // Només esborrar caches obsolets si ha canviat la versió
      await this.cleanupOutdatedCaches();

      // Primer, registrar el service worker generat per Vite-PWA (per precaching i offline)
      await this.registerVitePWA();

      // Després, registrar el nostre service worker personalitzat per notificacions
      await this.registerCustomSW();

      // Configurar listeners d'actualitzacions
      this.setupUpdateListeners();

    } catch (error) {
      console.error('[PWA] Error initializing PWA:', error);
    }
  }

  private async cleanupOutdatedCaches(): Promise<void> {
    try {
      const storedVersion = localStorage.getItem('pwa-version');

      // Només netejar si la versió ha canviat
      if (storedVersion && storedVersion !== this.APP_VERSION) {
        console.log('[PWA] Nova versió detectada (', storedVersion, '→', this.APP_VERSION, '), forçant reinstal·lació');

        // FORÇAR REINSTAL·LACIÓ COMPLETA
        // 1. Desregistrar TOTS els service workers
        const registrations = await navigator.serviceWorker.getRegistrations();
        console.log('[PWA] Desregistrant', registrations.length, 'service workers...');
        await Promise.all(
          registrations.map(registration => {
            console.log('[PWA] Desregistrant SW:', registration.scope);
            return registration.unregister();
          })
        );

        // 2. Esborrar TOTS els caches
        const cacheNames = await caches.keys();
        console.log('[PWA] Esborrant tots els caches:', cacheNames);
        await Promise.all(
          cacheNames.map(cacheName => {
            console.log('[PWA] Esborrant cache:', cacheName);
            return caches.delete(cacheName);
          })
        );

        // 3. Netejar localStorage relacionat amb PWA
        const keysToRemove = [];
        for (let i = 0; i < localStorage.length; i++) {
          const key = localStorage.key(i);
          if (key && (key.includes('workbox') || key.includes('sw-') || key.includes('cache'))) {
            keysToRemove.push(key);
          }
        }
        keysToRemove.forEach(key => {
          console.log('[PWA] Esborrant localStorage:', key);
          localStorage.removeItem(key);
        });

        console.log('[PWA] Reinstal·lació completa, recarregant pàgina...');

        // Actualitzar versió
        localStorage.setItem('pwa-version', this.APP_VERSION);

        // 4. Forçar reload per registrar els nous service workers
        window.location.reload();
      } else if (!storedVersion) {
        // Primera instal·lació
        console.log('[PWA] Primera instal·lació, versió', this.APP_VERSION);
        localStorage.setItem('pwa-version', this.APP_VERSION);
      } else {
        // Mateixa versió, no fer res
        console.log('[PWA] Versió actual:', this.APP_VERSION);
      }
    } catch (error) {
      console.error('[PWA] Error netejant caches:', error);
    }
  }

  private async registerVitePWA(): Promise<void> {
    // Vite-PWA desactivat - usem sw.js personalitzat
    console.log('[PWA] Vite-PWA disabled - using custom sw.js');
    return Promise.resolve();
  }

  private async registerCustomSW(): Promise<void> {
    try {
      // Esperar que el SW estigui registrat (app.html ho fa)
      const registration = await navigator.serviceWorker.ready;
      this.customSWRegistration = registration;
      console.log('[PWA] Service worker ready:', registration.scope);
    } catch (error) {
      console.error('[PWA] Failed to get service worker registration:', error);
    }
  }

  private setupUpdateListeners(): void {
    // Escoltar actualitzacions del SW personalitzat
    if (this.customSWRegistration) {
      this.customSWRegistration.addEventListener('updatefound', () => {
        const newWorker = this.customSWRegistration?.installing;
        if (newWorker) {
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              console.log('[PWA] Nova versió del SW disponible');
            }
          });
        }
      });
    }

    // Escoltar canvis de controlador
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      console.log('[PWA] Service worker controller changed');
    });
  }

  private notifyUpdateAvailable(): void {
    // Notificar a l'aplicació que hi ha una actualització disponible
    window.dispatchEvent(new CustomEvent('pwa-update-available', {
      detail: { 
        registration: this.vitePwaRegistration,
        timestamp: new Date()
      }
    }));
  }

  async checkForUpdates(): Promise<void> {
    if (this.customSWRegistration) {
      try {
        await this.customSWRegistration.update();
      } catch (error) {
        console.error('[PWA] Failed to check for updates:', error);
      }
    }
  }

  async getOfflineStatus(): Promise<boolean> {
    // Comprovar si estem offline i si el cache està disponible
    if (!navigator.onLine) {
      try {
        const cache = await caches.open('pages');
        const cachedResponse = await cache.match('/');
        return !!cachedResponse;
      } catch {
        return false;
      }
    }
    return true;
  }

  // Mètodes per notificacions (delegats al custom SW)
  async getNotificationRegistration(): Promise<ServiceWorkerRegistration | null> {
    return this.customSWRegistration || this.vitePwaRegistration;
  }

  async sendMessageToSW(message: any): Promise<any> {
    const registration = this.customSWRegistration || this.vitePwaRegistration;
    if (!registration?.active) {
      throw new Error('No active service worker available');
    }

    return new Promise((resolve, reject) => {
      const messageChannel = new MessageChannel();
      const timeout = setTimeout(() => {
        messageChannel.port1.close();
        reject(new Error('Service worker message timeout'));
      }, 5000);

      messageChannel.port1.onmessage = (event) => {
        clearTimeout(timeout);
        messageChannel.port1.close();
        resolve(event.data);
      };

      messageChannel.port1.onmessageerror = () => {
        clearTimeout(timeout);
        messageChannel.port1.close();
        reject(new Error('Service worker message error'));
      };

      try {
        registration.active.postMessage(message, [messageChannel.port2]);
      } catch (error) {
        clearTimeout(timeout);
        messageChannel.port1.close();
        reject(error);
      }
    });
  }
}

// Singleton instance
export const pwaManager = new PWAIntegration();

// Auto-init en production
if (typeof window !== 'undefined' && import.meta.env.PROD) {
  pwaManager.init().catch(console.error);
}