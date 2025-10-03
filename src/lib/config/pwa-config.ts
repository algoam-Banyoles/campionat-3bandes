// Configuració centralitzada per evitar errors de service worker

// Gestionar errors de runtime silenciosament
if (typeof window !== 'undefined') {
  // Evitar errors de "message port closed"
  window.addEventListener('error', (event) => {
    if (event.message && event.message.includes('message port closed')) {
      console.warn('[PWA] Message port closed error suppressed');
      event.preventDefault();
      return false;
    }
  });

  // Evitar errors de runtime de Chrome Extension
  window.addEventListener('error', (event) => {
    if (event.message && (
      event.message.includes('Unchecked runtime.lastError') ||
      event.message.includes('Extension context invalidated')
    )) {
      console.warn('[PWA] Chrome extension error suppressed');
      event.preventDefault();
      return false;
    }
  });

  // Gestionar errors de Workbox silenciosament
  window.addEventListener('error', (event) => {
    if (event.message && (
      event.message.includes('non-precached-url') ||
      event.message.includes('workbox')
    )) {
      console.warn('[PWA] Workbox error suppressed:', event.message);
      event.preventDefault();
      return false;
    }
  });

  // Gestionar errors no capturats de Promise
  window.addEventListener('unhandledrejection', (event) => {
    if (event.reason && typeof event.reason === 'string') {
      if (event.reason.includes('message port closed') ||
          event.reason.includes('non-precached-url') ||
          event.reason.includes('Extension context invalidated')) {
        console.warn('[PWA] Unhandled rejection suppressed:', event.reason);
        event.preventDefault();
        return false;
      }
    }
  });
}

// Configuració per service worker
export const SW_CONFIG = {
  // Timeout per missatges
  MESSAGE_TIMEOUT: 5000,
  
  // URLs que no cal precarregar
  EXCLUDED_URLS: [
    '/api/',
    '/admin/',
    '/auth/',
    '/_app/',
    '/service-worker.js',
    '/sw.js'
  ],
  
  // Recursos que han d'estar sempre disponibles offline
  CRITICAL_RESOURCES: [
    '/',
    '/offline.html',
    '/manifest.json'
  ],
  
  // Cache names
  CACHE_NAMES: {
    STATIC: 'static-assets-v1',
    PAGES: 'pages-v1',
    API: 'api-cache-v1',
    IMAGES: 'images-v1'
  }
};

// Utility per comprovar si un URL ha de ser ignorat
export function shouldExcludeUrl(url: string): boolean {
  return SW_CONFIG.EXCLUDED_URLS.some(pattern => url.includes(pattern));
}

// Utility per gestionar errors de service worker de manera consistent
export function handleSWError(error: any, context: string): void {
  if (typeof error === 'string' && (
    error.includes('message port closed') ||
    error.includes('non-precached-url') ||
    error.includes('Extension context invalidated')
  )) {
    console.warn(`[PWA] ${context} - Known error suppressed:`, error);
    return;
  }
  
  console.error(`[PWA] ${context} - Error:`, error);
}