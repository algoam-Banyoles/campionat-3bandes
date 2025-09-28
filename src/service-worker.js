// Import workbox utilities if available (when using generateSW strategy)
// This service worker extends the generated one with push notifications

// Check if we have access to the workbox runtime
const isWorkboxAvailable = typeof workbox !== 'undefined';

console.log('[SW] Custom service worker loaded, Workbox available:', isWorkboxAvailable);

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
      targetUrl = `/campionat-continu/reptes/${data.challengeId}`;
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