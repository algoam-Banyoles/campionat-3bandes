// Service Worker personalitzat per notificacions push
// Compatible amb Vite-PWA i Workbox

// Importar les utilitats de Workbox si estan disponibles
importScripts('https://storage.googleapis.com/workbox-cdn/releases/6.5.4/workbox-sw.js');

if (workbox) {
  console.log('[SW] Workbox carregat correctament');

  // Configurar Workbox
  workbox.core.skipWaiting();
  workbox.core.clientsClaim();

  // Configurar precaching automàtic
  workbox.precaching.precacheAndRoute(self.__WB_MANIFEST || []);

  // Configurar estratègies de cache
  workbox.routing.registerRoute(
    /\.(js|css|png|jpg|jpeg|svg|gif|ico)$/,
    new workbox.strategies.CacheFirst({
      cacheName: 'static-assets',
      plugins: [{
        cacheKeyWillBeUsed: async ({request}) => `${request.url}?v=${Date.now()}`
      }]
    })
  );

} else {
  console.log('[SW] Workbox no disponible, usant cache bàsic');

  // Fallback cache bàsic si Workbox no està disponible
  const CACHE_NAME = 'campionat-3bandes-v1';

  self.addEventListener('install', (event) => {
    console.log('[SW] Installing service worker');
    event.waitUntil(
      caches.open(CACHE_NAME).then((cache) => {
        return cache.addAll(['/']);
      })
    );
  });

  self.addEventListener('fetch', (event) => {
    event.respondWith(
      caches.match(event.request).then((response) => {
        return response || fetch(event.request);
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
    icon: '/icons/icon-192.svg',
    badge: '/icons/icon-96.png',
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

  // Mostrar la notificació
  event.waitUntil(
    self.registration.showNotification(notificationData.title, {
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
    })
  );
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
        targetUrl = data.challengeUrl || '/reptes';
        break;
      case 'view_ranking':
        targetUrl = '/ranking';
        break;
      case 'view_profile':
        targetUrl = '/reptes/me';
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
          client.navigate(targetUrl);
          return client.focus();
        }
      }

      // Si no hi ha finestra oberta, n'obrim una de nova
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

// Gestió de tancar notificacions
self.addEventListener('notificationclose', (event) => {
  console.log('[SW] Notification closed:', event.notification.tag);

  // Aquí es podria enviar tracking analytics si cal
  // Per exemple, registrar que l'usuari ha tancat la notificació sense fer clic
});