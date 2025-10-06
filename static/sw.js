// Service Worker personalitzat per notificacions push
// Compatible amb Vite-PWA i Workbox

// Importar les utilitats de Workbox si estan disponibles
importScripts('https://storage.googleapis.com/workbox-cdn/releases/6.5.4/workbox-sw.js');

// Timeout per fetch requests (Safari necessita timeouts curts)
const FETCH_TIMEOUT = 8000; // 8 segons

// Helper per afegir timeout a fetch
const fetchWithTimeout = (request, timeout = FETCH_TIMEOUT) => {
  return new Promise((resolve, reject) => {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    fetch(request, { signal: controller.signal })
      .then(response => {
        clearTimeout(timeoutId);
        resolve(response);
      })
      .catch(error => {
        clearTimeout(timeoutId);
        reject(error);
      });
  });
};

if (workbox) {
  console.log('[SW] Workbox carregat correctament');

  // Configurar Workbox
  workbox.core.skipWaiting();
  workbox.core.clientsClaim();

  // Configurar precaching automàtic amb gestió d'errors
  try {
    workbox.precaching.precacheAndRoute(self.__WB_MANIFEST || []);

    // Assegurar que offline.html està disponible
    workbox.precaching.precacheAndRoute([{ url: '/offline.html', revision: null }]);
  } catch (error) {
    console.error('[SW] Error en precaching:', error);
  }

  // *** ESTRATÈGIA MILLORADA: NetworkFirst amb fallback a Cache ***
  // Per navegació (HTML pages)
  workbox.routing.registerRoute(
    ({request}) => request.mode === 'navigate',
    new workbox.strategies.NetworkFirst({
      cacheName: 'pages',
      networkTimeoutSeconds: 5, // Timeout de 5s per Safari
      plugins: [
        {
          handlerDidError: async () => {
            // Si la xarxa falla, tornar offline.html
            return caches.match('/offline.html');
          }
        },
        {
          cacheWillUpdate: async ({response}) => {
            // Només cachear respostes ok
            if (response && response.status === 200) {
              return response;
            }
            return null;
          }
        }
      ]
    })
  );

  // *** ESTRATÈGIA PER ASSETS ESTÀTICS: StaleWhileRevalidate amb fallback ***
  workbox.routing.registerRoute(
    /\.(js|css|png|jpg|jpeg|svg|gif|ico|webp|woff|woff2)$/,
    new workbox.strategies.StaleWhileRevalidate({
      cacheName: 'static-assets',
      plugins: [
        {
          cacheWillUpdate: async ({response}) => {
            // Només cachear respostes vàlides
            if (response && (response.status === 200 || response.status === 0)) {
              return response;
            }
            return null;
          }
        },
        {
          fetchDidFail: async ({originalRequest, error}) => {
            console.log('[SW] Fetch failed for:', originalRequest.url, error);
            // Intentar recuperar del cache
            return caches.match(originalRequest);
          }
        }
      ]
    })
  );

  // *** API REQUESTS: NetworkFirst amb timeout curt ***
  workbox.routing.registerRoute(
    ({url}) => url.pathname.startsWith('/api/') || url.hostname.includes('supabase'),
    new workbox.strategies.NetworkFirst({
      cacheName: 'api-cache',
      networkTimeoutSeconds: 8, // 8s per API calls
      plugins: [
        {
          cacheWillUpdate: async ({response}) => {
            // Només cachear GET requests amb respostes ok
            if (response && response.status === 200 && response.headers.get('content-type')?.includes('application/json')) {
              return response;
            }
            return null;
          }
        },
        {
          handlerDidError: async () => {
            // No retornar res si l'API falla (deixar que l'app ho gestioni)
            return null;
          }
        }
      ]
    })
  );

} else {
  console.log('[SW] Workbox no disponible, usant cache bàsic amb timeouts');

  // Fallback cache bàsic si Workbox no està disponible
  const CACHE_NAME = 'campionat-3bandes-v1';

  self.addEventListener('install', (event) => {
    console.log('[SW] Installing service worker');
    event.waitUntil(
      caches.open(CACHE_NAME).then((cache) => {
        return cache.addAll(['/offline.html']).catch(error => {
          console.error('[SW] Error caching offline.html:', error);
        });
      })
    );
  });

  self.addEventListener('fetch', (event) => {
    event.respondWith(
      fetchWithTimeout(event.request, FETCH_TIMEOUT)
        .then(response => {
          // Clone response per cachear
          const responseToCache = response.clone();

          // Cachear només si és una resposta ok
          if (response.status === 200) {
            caches.open(CACHE_NAME).then(cache => {
              cache.put(event.request, responseToCache);
            });
          }

          return response;
        })
        .catch(error => {
          console.log('[SW] Fetch failed, trying cache:', event.request.url, error);
          // Intentar recuperar del cache
          return caches.match(event.request)
            .then(cachedResponse => {
              if (cachedResponse) {
                return cachedResponse;
              }
              // Si és navegació, retornar offline.html
              if (event.request.mode === 'navigate') {
                return caches.match('/offline.html');
              }
              // Sinó, retornar error
              return new Response('Network error', { status: 503 });
            });
        })
    );
  });
}

// *** GESTORS DE NOTIFICACIONS PUSH ***

// Gestió d'esdeveniments push (quan arriba una notificació)
self.addEventListener('push', (event) => {
  console.log('[SW] Push event received:', event);

  let notificationData = {
    title: 'Campionat 3 Bandes',
    body: 'Tens una nova notificació',
    icon: '/icons/icon-192x192.png',
    badge: '/icons/icon-192x192.png',
    tag: 'general',
    data: {}
  };

  // Processar les dades del push si existeixen
  if (event.data) {
    try {
      const pushData = event.data.json();
      notificationData = {
        title: pushData.title || notificationData.title,
        body: pushData.body || notificationData.body,
        icon: pushData.icon || notificationData.icon,
        badge: pushData.badge || notificationData.badge,
        tag: pushData.tag || notificationData.tag,
        data: pushData.data || {},
        actions: pushData.actions || [],
        requireInteraction: pushData.requireInteraction || false,
        silent: pushData.silent || false
      };
    } catch (e) {
      console.error('[SW] Error parsing push data:', e);
    }
  }

  // Mostrar la notificació amb gestió d'errors
  const notificationPromise = self.registration.showNotification(notificationData.title, {
    body: notificationData.body,
    icon: notificationData.icon,
    badge: notificationData.badge,
    tag: notificationData.tag,
    data: notificationData.data,
    actions: notificationData.actions,
    requireInteraction: notificationData.requireInteraction,
    silent: notificationData.silent,
    vibrate: [200, 100, 200], // Vibració per mòbil
    timestamp: Date.now()
  }).catch(error => {
    console.error('[SW] Error showing notification:', error);
  });

  event.waitUntil(notificationPromise);
});

// Gestió de clics en notificacions
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification click received:', event);

  // Tancar la notificació
  event.notification.close();

  // Extreure dades de la notificació
  const data = event.notification.data || {};
  const action = event.action;

  // Determinar l'URL de destinació
  let targetUrl = '/';

  if (action) {
    // Si s'ha fet clic en una acció específica
    switch (action) {
      case 'view_challenge':
        targetUrl = data.challengeUrl || '/campionat-continu/reptes';
        break;
      case 'view_ranking':
        targetUrl = '/campionat-continu/ranking';
        break;
      case 'view_profile':
        targetUrl = '/campionat-continu/reptes/me';
        break;
      default:
        targetUrl = data.url || '/';
    }
  } else {
    // Clic general en la notificació
    if (data.challengeId) {
      targetUrl = `/reptes/${data.challengeId}`;
    } else if (data.url) {
      targetUrl = data.url;
    }
  }

  // Obrir o enfocar la finestra de l'aplicació
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Buscar si ja hi ha una finestra oberta
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          // Si trobem una finestra, naveguem i la enfoquem
          return Promise.resolve(client.navigate(targetUrl))
            .then(() => client.focus())
            .catch(error => {
              console.error('[SW] Error navigating to URL:', error);
              return client.focus();
            });
        }
      }

      // Si no hi ha finestra oberta, n'obrim una de nova
      if (clients.openWindow) {
        return clients.openWindow(targetUrl).catch(error => {
          console.error('[SW] Error opening window:', error);
        });
      }
    }).catch(error => {
      console.error('[SW] Error handling notification click:', error);
    })
  );
});

// Gestió de tancar notificacions
self.addEventListener('notificationclose', (event) => {
  console.log('[SW] Notification closed:', event.notification.tag);

  // Aquí es podria enviar tracking analytics si cal
  // Per exemple, registrar que l'usuari ha tancat la notificació sense fer clic
});
