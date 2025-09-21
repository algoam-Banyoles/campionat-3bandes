// Funcionalitat de notificacions push per al Service Worker
// static/service-worker/notifications.js

// Configuració per defecte de les notificacions
const DEFAULT_NOTIFICATION_OPTIONS = {
  badge: '/icons/badge-96.png',
  icon: '/icons/icon-192.png',
  tag: 'campionat-notification',
  requireInteraction: false,
  silent: false,
  vibrate: [100, 50, 100],
  actions: []
};

// Gestionar esdeveniments push
async function handlePushEvent(event) {
  console.log('[SW] Push event received:', event);
  
  if (!event.data) {
    console.warn('[SW] Push event has no data');
    return;
  }

  try {
    const data = event.data.json();
    console.log('[SW] Push data:', data);
    
    const notificationPromise = showNotification(data);
    
    // També registrar la notificació localment
    const storagePromise = storeNotificationLocally(data);
    
    event.waitUntil(Promise.all([notificationPromise, storagePromise]));
    
  } catch (error) {
    console.error('[SW] Error handling push event:', error);
    
    // Mostrar notificació genèrica en cas d'error
    event.waitUntil(
      self.registration.showNotification('Nova notificació', {
        ...DEFAULT_NOTIFICATION_OPTIONS,
        body: 'Has rebut una nova notificació del Campionat de 3 Bandes'
      })
    );
  }
}

// Mostrar notificació amb configuració específica
async function showNotification(data) {
  const {
    titol: title,
    missatge: body,
    tipus,
    accions,
    url_accio: actionUrl,
    dades_extra: extraData
  } = data;

  // Configurar opcions segons el tipus de notificació
  const options = {
    ...DEFAULT_NOTIFICATION_OPTIONS,
    body,
    tag: `${tipus}-${Date.now()}`,
    data: {
      tipus,
      actionUrl,
      extraData,
      timestamp: Date.now()
    }
  };

  // Personalitzar segons el tipus
  switch (tipus) {
    case 'repte_nou':
      options.icon = '/icons/challenge.png';
      options.badge = '/icons/badge-challenge.png';
      options.actions = [
        {
          action: 'view',
          title: 'Veure repte',
          icon: '/icons/action-view.png'
        },
        {
          action: 'later',
          title: 'Més tard',
          icon: '/icons/action-later.png'
        }
      ];
      options.requireInteraction = true;
      break;

    case 'caducitat_proxima':
      options.icon = '/icons/warning.png';
      options.badge = '/icons/badge-warning.png';
      options.actions = [
        {
          action: 'schedule',
          title: 'Programar',
          icon: '/icons/action-schedule.png'
        },
        {
          action: 'remind',
          title: 'Recordar-me',
          icon: '/icons/action-remind.png'
        }
      ];
      options.requireInteraction = true;
      options.vibrate = [200, 100, 200, 100, 200];
      break;

    case 'repte_caducat':
      options.icon = '/icons/expired.png';
      options.badge = '/icons/badge-expired.png';
      options.actions = [
        {
          action: 'view',
          title: 'Veure detalls',
          icon: '/icons/action-view.png'
        }
      ];
      break;

    case 'partida_recordatori':
      options.icon = '/icons/calendar.png';
      options.badge = '/icons/badge-calendar.png';
      options.actions = [
        {
          action: 'confirm',
          title: 'Confirmar',
          icon: '/icons/action-confirm.png'
        },
        {
          action: 'reschedule',
          title: 'Reprogramar',
          icon: '/icons/action-reschedule.png'
        }
      ];
      options.requireInteraction = true;
      break;

    case 'confirmacio_requerida':
      options.icon = '/icons/question.png';
      options.badge = '/icons/badge-question.png';
      options.actions = [
        {
          action: 'confirm',
          title: 'Confirmar',
          icon: '/icons/action-confirm.png'
        },
        {
          action: 'decline',
          title: 'Declinar',
          icon: '/icons/action-decline.png'
        }
      ];
      options.requireInteraction = true;
      options.vibrate = [100, 50, 100, 50, 100, 50, 100];
      break;

    default:
      // Configuració per defecte
      break;
  }

  // Afegir accions personalitzades si existeixen
  if (accions && Array.isArray(accions)) {
    options.actions = accions.map(accio => ({
      action: accio.id,
      title: accio.titol,
      icon: accio.icona || '/icons/action-default.png'
    }));
  }

  return self.registration.showNotification(title, options);
}

// Gestionar clics en notificacions
async function handleNotificationClick(event) {
  console.log('[SW] Notification clicked:', event);
  
  const { notification, action } = event;
  const { tipus, actionUrl, extraData } = notification.data || {};
  
  // Tancar la notificació
  notification.close();
  
  try {
    // Marcar com llegida
    await markNotificationAsRead(notification.tag);
    
    // Gestionar l'acció específica
    if (action) {
      await handleNotificationAction(action, tipus, extraData);
    } else {
      // Clic general en la notificació
      await handleDefaultNotificationAction(tipus, actionUrl, extraData);
    }
    
  } catch (error) {
    console.error('[SW] Error handling notification click:', error);
  }
}

// Gestionar accions específiques de notificacions
async function handleNotificationAction(action, tipus, extraData) {
  const clients = await self.clients.matchAll({ type: 'window' });
  
  switch (action) {
    case 'view':
      const viewUrl = getUrlForNotificationType(tipus, extraData);
      await openOrFocusWindow(clients, viewUrl);
      break;
      
    case 'later':
      // Programar recordatori per més tard
      await scheduleReminder(extraData, 60); // 60 minuts
      break;
      
    case 'schedule':
      await openOrFocusWindow(clients, `/reptes/${extraData?.challengeId}/programar`);
      break;
      
    case 'remind':
      await scheduleReminder(extraData, 30); // 30 minuts
      break;
      
    case 'confirm':
      await handleQuickAction('confirm', extraData);
      break;
      
    case 'decline':
      await handleQuickAction('decline', extraData);
      break;
      
    case 'reschedule':
      await openOrFocusWindow(clients, `/reptes/${extraData?.challengeId}/reprogramar`);
      break;
      
    default:
      console.warn('[SW] Unknown notification action:', action);
  }
}

// Gestionar acció per defecte (clic general)
async function handleDefaultNotificationAction(tipus, actionUrl, extraData) {
  const clients = await self.clients.matchAll({ type: 'window' });
  let targetUrl = actionUrl;
  
  if (!targetUrl) {
    targetUrl = getUrlForNotificationType(tipus, extraData);
  }
  
  await openOrFocusWindow(clients, targetUrl);
}

// Obtenir URL segons el tipus de notificació
function getUrlForNotificationType(tipus, extraData) {
  switch (tipus) {
    case 'repte_nou':
      return extraData?.challengeId ? `/reptes/${extraData.challengeId}` : '/reptes';
      
    case 'caducitat_proxima':
    case 'repte_caducat':
      return extraData?.challengeId ? `/reptes/${extraData.challengeId}` : '/reptes';
      
    case 'partida_recordatori':
      return extraData?.matchId ? `/partides/${extraData.matchId}` : '/calendari';
      
    case 'confirmacio_requerida':
      return extraData?.challengeId ? `/reptes/${extraData.challengeId}/confirmar` : '/reptes';
      
    default:
      return '/';
  }
}

// Obrir o enfocar finestra existent
async function openOrFocusWindow(clients, url) {
  // Buscar finestra existent amb la URL
  for (const client of clients) {
    if (client.url.includes(url.split('?')[0])) {
      await client.focus();
      if (url.includes('?') || url.includes('#')) {
        client.postMessage({
          type: 'NAVIGATE_TO',
          url: url
        });
      }
      return;
    }
  }
  
  // Buscar qualsevol finestra oberta
  if (clients.length > 0) {
    const client = clients[0];
    await client.focus();
    client.postMessage({
      type: 'NAVIGATE_TO',
      url: url
    });
    return;
  }
  
  // Obrir nova finestra
  await self.clients.openWindow(url);
}

// Gestionar accions ràpides sense obrir interfície
async function handleQuickAction(action, extraData) {
  try {
    const clients = await self.clients.matchAll({ type: 'window' });
    
    // Enviar missatge a l'aplicació per processar l'acció
    const message = {
      type: 'QUICK_ACTION',
      action: action,
      data: extraData
    };
    
    if (clients.length > 0) {
      clients.forEach(client => client.postMessage(message));
    } else {
      // Emmagatzemar acció per processar quan s'obri l'app
      await storeOfflineAction(message);
    }
    
    // Mostrar confirmació
    await self.registration.showNotification('Acció processada', {
      ...DEFAULT_NOTIFICATION_OPTIONS,
      body: `${action === 'confirm' ? 'Confirmació' : 'Declinació'} registrada correctament`,
      tag: 'quick-action-feedback',
      actions: []
    });
    
  } catch (error) {
    console.error('[SW] Error handling quick action:', error);
    
    await self.registration.showNotification('Error', {
      ...DEFAULT_NOTIFICATION_OPTIONS,
      body: 'No s\'ha pogut processar l\'acció. Obre l\'aplicació per completar-la.',
      tag: 'quick-action-error',
      actions: []
    });
  }
}

// Programar recordatori
async function scheduleReminder(extraData, minutesFromNow) {
  const reminderTime = Date.now() + (minutesFromNow * 60 * 1000);
  
  const reminderData = {
    type: 'SCHEDULED_REMINDER',
    scheduledFor: reminderTime,
    data: extraData
  };
  
  // Emmagatzemar recordatori (en un entorn real usaríem una base de dades)
  await storeScheduledReminder(reminderData);
  
  // Mostrar confirmació
  await self.registration.showNotification('Recordatori programat', {
    ...DEFAULT_NOTIFICATION_OPTIONS,
    body: `Et recordarem en ${minutesFromNow} minuts`,
    tag: 'reminder-scheduled',
    actions: []
  });
}

// Gestionar tancament de notificacions
function handleNotificationClose(event) {
  console.log('[SW] Notification closed:', event.notification.tag);
  
  // Registrar estadístiques de notificació (si és necessari)
  const { tipus } = event.notification.data || {};
  
  // Enviar event a l'aplicació si està oberta
  self.clients.matchAll({ type: 'window' }).then(clients => {
    clients.forEach(client => {
      client.postMessage({
        type: 'NOTIFICATION_CLOSED',
        notificationTag: event.notification.tag,
        notificationType: tipus
      });
    });
  });
}

// Emmagatzemar notificació localment
async function storeNotificationLocally(data) {
  try {
    // En un service worker real, utilitzaríem IndexedDB
    // Aquí simulem l'emmagatzematge
    const storageKey = `notification_${Date.now()}`;
    const notificationData = {
      ...data,
      receivedAt: Date.now(),
      read: false
    };
    
    // Enviar a l'aplicació si està oberta
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach(client => {
      client.postMessage({
        type: 'NEW_NOTIFICATION',
        data: notificationData
      });
    });
    
  } catch (error) {
    console.error('[SW] Error storing notification locally:', error);
  }
}

// Marcar notificació com llegida
async function markNotificationAsRead(notificationTag) {
  try {
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach(client => {
      client.postMessage({
        type: 'MARK_NOTIFICATION_READ',
        notificationTag: notificationTag
      });
    });
  } catch (error) {
    console.error('[SW] Error marking notification as read:', error);
  }
}

// Emmagatzemar acció offline
async function storeOfflineAction(action) {
  try {
    // En un entorn real, utilitzaríem IndexedDB
    console.log('[SW] Storing offline action:', action);
  } catch (error) {
    console.error('[SW] Error storing offline action:', error);
  }
}

// Emmagatzemar recordatori programat
async function storeScheduledReminder(reminderData) {
  try {
    // En un entorn real, utilitzaríem una cua persistent
    console.log('[SW] Storing scheduled reminder:', reminderData);
  } catch (error) {
    console.error('[SW] Error storing scheduled reminder:', error);
  }
}

console.log('[SW] Notification handlers loaded');