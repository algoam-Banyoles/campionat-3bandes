// Service Worker per al Campionat de 3 Bandes
// Implementa cache estratègic per a funcionament offline

const CACHE_NAME = 'campionat-3bandes-v1';
const STATIC_CACHE_NAME = 'campionat-static-v1';
const DATA_CACHE_NAME = 'campionat-data-v1';

// Assets estàtics crítics per al funcionament offline
const STATIC_ASSETS = [
  '/',
  '/offline',
  '/manifest.json',
  
  // CSS i JS principals (SvelteKit)
  '/_app/immutable/assets/',
  '/_app/immutable/chunks/',
  '/_app/immutable/entry/',
  
  // Fonts essencials
  '/fonts/inter-var.woff2',
  
  // Imatges de la interfície
  '/favicon.ico',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  
  // Pàgines essencials
  '/login',
  '/ranking',
  '/challenges'
];

// URLs d'API que s'han de cachear per funcionament offline
const DATA_ENDPOINTS = [
  '/api/ranking',
  '/api/challenges/active',
  '/api/players',
  '/api/auth/profile'
];

// Estratègies de cache per diferents tipus de recursos
const CACHE_STRATEGIES = {
  // Recursos estàtics - cache first amb long TTL
  static: {
    strategy: 'cacheFirst',
    ttl: 7 * 24 * 60 * 60 * 1000, // 7 dies
    fallback: '/offline'
  },
  
  // API data - network first amb fallback a cache
  api: {
    strategy: 'networkFirst',
    ttl: 5 * 60 * 1000, // 5 minuts
    fallback: null
  },
  
  // Imatges - cache first amb long TTL
  images: {
    strategy: 'cacheFirst',
    ttl: 30 * 24 * 60 * 60 * 1000, // 30 dies
    fallback: '/images/placeholder.png'
  },
  
  // Documents - network first amb cache backup
  documents: {
    strategy: 'networkFirst',
    ttl: 24 * 60 * 60 * 1000, // 24 hores
    fallback: '/offline'
  }
};

// Instal·lació del Service Worker
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');
  
  event.waitUntil(
    Promise.all([
      // Cache recursos estàtics
      caches.open(STATIC_CACHE_NAME).then(cache => {
        console.log('[SW] Caching static assets');
        return cache.addAll(STATIC_ASSETS.filter(url => !url.endsWith('/')));
      }),
      
      // Activar immediatament
      self.skipWaiting()
    ])
  );
});

// Activació del Service Worker
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');
  
  event.waitUntil(
    Promise.all([
      // Neteja de caches antics
      caches.keys().then(cacheNames => {
        return Promise.all(
          cacheNames.map(cacheName => {
            if (![CACHE_NAME, STATIC_CACHE_NAME, DATA_CACHE_NAME].includes(cacheName)) {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      }),
      
      // Prendre control immediat
      self.clients.claim()
    ])
  );
});

// Intercepció de requests
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Només interceptar requests del mateix origin o APIs conegudes
  if (!url.origin.includes(self.location.origin) && !isKnownApiEndpoint(url)) {
    return;
  }
  
  // Determinar estratègia segons el tipus de recurs
  const strategy = getStrategyForRequest(request);
  
  event.respondWith(
    handleRequest(request, strategy)
  );
});

// Gestió de missatges des de la app
self.addEventListener('message', (event) => {
  const { type, data } = event.data;
  
  switch (type) {
    case 'CACHE_API_RESPONSE':
      cacheApiResponse(data.url, data.response);
      break;
      
    case 'INVALIDATE_CACHE':
      invalidateCache(data.pattern);
      break;
      
    case 'PREFETCH_RESOURCES':
      prefetchResources(data.urls);
      break;
      
    case 'GET_CACHE_STATUS':
      getCacheStatus().then(status => {
        event.ports[0].postMessage({ type: 'CACHE_STATUS', data: status });
      });
      break;
  }
});

// Funcions auxiliars

function isKnownApiEndpoint(url) {
  return DATA_ENDPOINTS.some(endpoint => url.pathname.startsWith(endpoint)) ||
         url.hostname.includes('supabase.co');
}

function getStrategyForRequest(request) {
  const url = new URL(request.url);
  
  // API requests
  if (url.pathname.startsWith('/api') || url.hostname.includes('supabase.co')) {
    return CACHE_STRATEGIES.api;
  }
  
  // Imatges
  if (request.destination === 'image' || url.pathname.match(/\.(jpg|jpeg|png|gif|webp|svg)$/)) {
    return CACHE_STRATEGIES.images;
  }
  
  // Assets estàtics (CSS, JS, fonts)
  if (request.destination === 'style' || 
      request.destination === 'script' || 
      request.destination === 'font' ||
      url.pathname.includes('/_app/')) {
    return CACHE_STRATEGIES.static;
  }
  
  // Documents HTML
  if (request.destination === 'document' || request.mode === 'navigate') {
    return CACHE_STRATEGIES.documents;
  }
  
  // Default: network first
  return CACHE_STRATEGIES.api;
}

async function handleRequest(request, strategy) {
  const cacheName = getCacheNameForStrategy(strategy);
  
  switch (strategy.strategy) {
    case 'cacheFirst':
      return handleCacheFirst(request, cacheName, strategy);
      
    case 'networkFirst':
      return handleNetworkFirst(request, cacheName, strategy);
      
    case 'staleWhileRevalidate':
      return handleStaleWhileRevalidate(request, cacheName, strategy);
      
    default:
      return fetch(request);
  }
}

function getCacheNameForStrategy(strategy) {
  if (strategy === CACHE_STRATEGIES.static) return STATIC_CACHE_NAME;
  if (strategy === CACHE_STRATEGIES.api) return DATA_CACHE_NAME;
  return CACHE_NAME;
}

async function handleCacheFirst(request, cacheName, strategy) {
  try {
    const cache = await caches.open(cacheName);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse && !isCacheExpired(cachedResponse, strategy.ttl)) {
      return cachedResponse;
    }
    
    // Cache miss o expirat - fetch from network
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok) {
      const responseToCache = networkResponse.clone();
      await cache.put(request, responseToCache);
    }
    
    return networkResponse;
    
  } catch (error) {
    console.warn('[SW] Cache first error:', error);
    
    // Fallback a cache expirat si existeix
    const cache = await caches.open(cacheName);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // Últim recurs: fallback definit
    if (strategy.fallback) {
      return caches.match(strategy.fallback);
    }
    
    throw error;
  }
}

async function handleNetworkFirst(request, cacheName, strategy) {
  try {
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok) {
      const cache = await caches.open(cacheName);
      const responseToCache = networkResponse.clone();
      await cache.put(request, responseToCache);
    }
    
    return networkResponse;
    
  } catch (error) {
    console.warn('[SW] Network first fallback to cache:', error);
    
    // Fallback a cache
    const cache = await caches.open(cacheName);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // Últim recurs: resposta offline personalitzada
    if (request.destination === 'document') {
      return caches.match('/offline');
    }
    
    throw error;
  }
}

async function handleStaleWhileRevalidate(request, cacheName, strategy) {
  const cache = await caches.open(cacheName);
  const cachedResponse = await cache.match(request);
  
  // Sempre intentar actualitzar en background
  const fetchPromise = fetch(request).then(response => {
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  }).catch(error => {
    console.warn('[SW] Background fetch failed:', error);
  });
  
  // Retornar cache si existeix, sinon esperar network
  if (cachedResponse) {
    return cachedResponse;
  }
  
  return fetchPromise;
}

function isCacheExpired(response, ttl) {
  if (!ttl || ttl === Infinity) return false;
  
  const dateHeader = response.headers.get('date');
  if (!dateHeader) return false;
  
  const responseTime = new Date(dateHeader).getTime();
  const now = Date.now();
  
  return (now - responseTime) > ttl;
}

async function cacheApiResponse(url, responseData) {
  try {
    const cache = await caches.open(DATA_CACHE_NAME);
    const response = new Response(JSON.stringify(responseData), {
      headers: {
        'Content-Type': 'application/json',
        'Date': new Date().toISOString()
      }
    });
    
    await cache.put(url, response);
    console.log('[SW] Cached API response:', url);
  } catch (error) {
    console.error('[SW] Error caching API response:', error);
  }
}

async function invalidateCache(pattern) {
  try {
    const cacheNames = await caches.keys();
    
    for (const cacheName of cacheNames) {
      const cache = await caches.open(cacheName);
      const requests = await cache.keys();
      
      for (const request of requests) {
        if (request.url.includes(pattern)) {
          await cache.delete(request);
          console.log('[SW] Invalidated cache for:', request.url);
        }
      }
    }
  } catch (error) {
    console.error('[SW] Error invalidating cache:', error);
  }
}

async function prefetchResources(urls) {
  try {
    const cache = await caches.open(CACHE_NAME);
    
    for (const url of urls) {
      try {
        const response = await fetch(url);
        if (response.ok) {
          await cache.put(url, response);
          console.log('[SW] Prefetched:', url);
        }
      } catch (error) {
        console.warn('[SW] Failed to prefetch:', url, error);
      }
    }
  } catch (error) {
    console.error('[SW] Error prefetching resources:', error);
  }
}

async function getCacheStatus() {
  try {
    const cacheNames = await caches.keys();
    const status = {};
    
    for (const cacheName of cacheNames) {
      const cache = await caches.open(cacheName);
      const requests = await cache.keys();
      status[cacheName] = {
        size: requests.length,
        urls: requests.map(req => req.url)
      };
    }
    
    return status;
  } catch (error) {
    console.error('[SW] Error getting cache status:', error);
    return {};
  }
}

// Background sync per a operacions pendents
self.addEventListener('sync', (event) => {
  if (event.tag === 'background-sync-challenges') {
    event.waitUntil(doBackgroundSync());
  }
});

async function doBackgroundSync() {
  try {
    // Notificar a la app que hi ha connexió per processar la cua offline
    const clients = await self.clients.matchAll();
    clients.forEach(client => {
      client.postMessage({ type: 'BACKGROUND_SYNC_AVAILABLE' });
    });
  } catch (error) {
    console.error('[SW] Background sync error:', error);
  }
}

console.log('[SW] Service Worker loaded and ready');