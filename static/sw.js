// Service Worker - NO intercepta APIs per preservar capçaleres
const CACHE_VERSION = 'v-no-api-cache-2025-10-12';

console.log('🌐 SW actiu - versió:', CACHE_VERSION);

// Instal·lació: netejar caches antigues
self.addEventListener('install', (event) => {
  console.log('🔧 SW: Install');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          console.log('🗑️ Eliminant cache antiga:', cacheName);
          return caches.delete(cacheName);
        })
      );
    })
  );
  self.skipWaiting();
});

// Activació: prendre control
self.addEventListener('activate', (event) => {
  console.log('✅ SW: Activate');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          console.log('🗑️ Netejant cache:', cacheName);
          return caches.delete(cacheName);
        })
      );
    }).then(() => {
      console.log('✅ Caches netes - prenent control');
      return self.clients.claim();
    })
  );
});

// Estratègia: NO interceptar res que pugui tenir capçaleres importants
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // NO interceptar ABSOLUTAMENT RES relacionat amb APIs
  if (
    url.hostname.includes('supabase.co') ||
    url.pathname.startsWith('/api/') ||
    url.pathname.includes('/rest/v1/') ||
    url.pathname.includes('/auth/v1/') ||
    url.pathname.includes('/storage/v1/') ||
    event.request.method !== 'GET'
  ) {
    // Deixar passar sense tocar ABSOLUTAMENT RES
    return;
  }

  // Per tot el resta (HTML, CSS, JS, imatges), també deixar passar
  // NO cacheem res per evitar problemes
});

// *** GESTORS DE NOTIFICACIONS PUSH ***

// Gestió d'esdeveniments push
self.addEventListener('push', (event) => {
  console.log('[SW] Push event received:', event);

  let notificationData = {
    title: 'Foment Martinenc',
    body: 'Tens una nova notificació',
    icon: '/icons/icon-192.svg',
    badge: '/icons/icon-144.svg',
    tag: 'general',
    data: {}
  };

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

  const notificationPromise = self.registration.showNotification(notificationData.title, {
    body: notificationData.body,
    icon: notificationData.icon,
    badge: notificationData.badge,
    tag: notificationData.tag,
    data: notificationData.data,
    actions: notificationData.actions,
    requireInteraction: notificationData.requireInteraction,
    silent: notificationData.silent,
    vibrate: [200, 100, 200],
    timestamp: Date.now()
  }).catch(error => {
    console.error('[SW] Error showing notification:', error);
  });

  event.waitUntil(notificationPromise);
});

// Gestió de clics en notificacions
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification click received:', event);
  event.notification.close();

  const data = event.notification.data || {};
  const action = event.action;
  let targetUrl = '/';

  if (action) {
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
    if (data.challengeId) {
      targetUrl = `/reptes/${data.challengeId}`;
    } else if (data.url) {
      targetUrl = data.url;
    }
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return Promise.resolve(client.navigate(targetUrl))
            .then(() => client.focus())
            .catch(error => {
              console.error('[SW] Error navigating:', error);
              return client.focus();
            });
        }
      }

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
});
