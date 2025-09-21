// Configuració del sistema de notificacions
// src/lib/config/notifications.ts

export interface NotificationConfig {
  vapidPublicKey: string;
  vapidPrivateKey?: string; // Només al servidor
  apiEndpoint: string;
  maxRetries: number;
  retryDelay: number;
  batchSize: number;
  defaultTTL: number;
}

export interface NotificationTypeConfig {
  id: string;
  name: string;
  description: string;
  icon: string;
  defaultEnabled: boolean;
  requiresInteraction: boolean;
  defaultTiming: {
    enabled: boolean;
    minutes: number;
  };
}

// Configuració principal (variables d'entorn en producció)
export const NOTIFICATION_CONFIG: NotificationConfig = {
  // Clau VAPID pública (generar amb: npx web-push generate-vapid-keys)
  vapidPublicKey: process.env.PUBLIC_VAPID_KEY || 'BEl62iUYgUivxIkv69yViEuiBIa40HuWukzpOmHjMtD0p6WIGnLW3qDJJfI8RmZOyN4WAgFNqHwz-KF0Pf6Vfzs',
  
  // Endpoint per a les Edge Functions
  apiEndpoint: process.env.PUBLIC_SUPABASE_URL ? 
    `${process.env.PUBLIC_SUPABASE_URL}/functions/v1` : 
    'http://localhost:54321/functions/v1',
  
  // Configuració de retry
  maxRetries: 3,
  retryDelay: 1000, // ms
  batchSize: 100,
  defaultTTL: 24 * 60 * 60, // 24 hores en segons
};

// Configuració dels tipus de notificació
export const NOTIFICATION_TYPES: Record<string, NotificationTypeConfig> = {
  repte_nou: {
    id: 'repte_nou',
    name: 'Reptes nous',
    description: 'Quan algú et fa un repte nou',
    icon: '🥎',
    defaultEnabled: true,
    requiresInteraction: true,
    defaultTiming: {
      enabled: true,
      minutes: 0 // Immediat
    }
  },
  
  caducitat_proxima: {
    id: 'caducitat_proxima',
    name: 'Caducitat propera',
    description: 'Quan un repte està a punt de caducar',
    icon: '⏰',
    defaultEnabled: true,
    requiresInteraction: true,
    defaultTiming: {
      enabled: true,
      minutes: 60 // 1 hora abans
    }
  },
  
  repte_caducat: {
    id: 'repte_caducat',
    name: 'Repte caducat',
    description: 'Quan un repte ha caducat',
    icon: '❌',
    defaultEnabled: true,
    requiresInteraction: false,
    defaultTiming: {
      enabled: true,
      minutes: 0 // Immediat
    }
  },
  
  partida_recordatori: {
    id: 'partida_recordatori',
    name: 'Recordatori de partida',
    description: 'Recordatori abans d\'una partida programada',
    icon: '📅',
    defaultEnabled: true,
    requiresInteraction: true,
    defaultTiming: {
      enabled: true,
      minutes: 30 // 30 minuts abans
    }
  },
  
  confirmacio_requerida: {
    id: 'confirmacio_requerida',
    name: 'Confirmació requerida',
    description: 'Quan cal confirmar el resultat d\'una partida',
    icon: '❓',
    defaultEnabled: true,
    requiresInteraction: true,
    defaultTiming: {
      enabled: true,
      minutes: 0 // Immediat
    }
  },
  
  ranking_actualitzat: {
    id: 'ranking_actualitzat',
    name: 'Actualització del rànquing',
    description: 'Quan el teu rànquing canvia significativament',
    icon: '📈',
    defaultEnabled: false,
    requiresInteraction: false,
    defaultTiming: {
      enabled: true,
      minutes: 0 // Immediat
    }
  },
  
  esdeveniment_club: {
    id: 'esdeveniment_club',
    name: 'Esdeveniments del club',
    description: 'Notificacions sobre esdeveniments i activitats',
    icon: '🎉',
    defaultEnabled: true,
    requiresInteraction: false,
    defaultTiming: {
      enabled: true,
      minutes: 0 // Immediat
    }
  }
};

// Configuració de les hores de silenci per defecte
export const DEFAULT_QUIET_HOURS = {
  enabled: false,
  start: '22:00',
  end: '08:00'
};

// Configuració de dies de la setmana
export const WEEKDAYS = [
  { id: 'dilluns', name: 'Dilluns', enabled: true },
  { id: 'dimarts', name: 'Dimarts', enabled: true },
  { id: 'dimecres', name: 'Dimecres', enabled: true },
  { id: 'dijous', name: 'Dijous', enabled: true },
  { id: 'divendres', name: 'Divendres', enabled: true },
  { id: 'dissabte', name: 'Dissabte', enabled: true },
  { id: 'diumenge', name: 'Diumenge', enabled: false }
];

// Validació de la configuració
export function validateNotificationConfig(config: Partial<NotificationConfig>): string[] {
  const errors: string[] = [];
  
  if (!config.vapidPublicKey) {
    errors.push('Clau VAPID pública requerida');
  }
  
  if (config.vapidPublicKey && config.vapidPublicKey.length < 80) {
    errors.push('Clau VAPID pública invàlida (massa curta)');
  }
  
  if (!config.apiEndpoint) {
    errors.push('Endpoint API requerit');
  }
  
  if (config.maxRetries !== undefined && config.maxRetries < 0) {
    errors.push('Nombre màxim de retries ha de ser positiu');
  }
  
  if (config.retryDelay !== undefined && config.retryDelay < 100) {
    errors.push('Temps de retry ha de ser almenys 100ms');
  }
  
  return errors;
}

// Generar configuració per defecte per a un usuari nou
export function generateDefaultUserPreferences() {
  const preferences: Record<string, any> = {};
  
  Object.values(NOTIFICATION_TYPES).forEach(type => {
    preferences[type.id] = {
      enabled: type.defaultEnabled,
      timing: { ...type.defaultTiming }
    };
  });
  
  return {
    notifications_enabled: true,
    quiet_hours: { ...DEFAULT_QUIET_HOURS },
    weekdays: WEEKDAYS.map(day => ({ ...day })),
    types: preferences
  };
}

// Funció per obtenir la configuració segons l'entorn
export function getEnvironmentConfig(): NotificationConfig {
  const config = { ...NOTIFICATION_CONFIG };
  
  // En desenvolupament, usar configuració local
  if (process.env.NODE_ENV === 'development') {
    config.apiEndpoint = 'http://localhost:54321/functions/v1';
  }
  
  // Sobreescriure amb variables d'entorn si existeixen
  if (process.env.PUBLIC_VAPID_KEY) {
    config.vapidPublicKey = process.env.PUBLIC_VAPID_KEY;
  }
  
  if (process.env.PUBLIC_SUPABASE_URL) {
    config.apiEndpoint = `${process.env.PUBLIC_SUPABASE_URL}/functions/v1`;
  }
  
  return config;
}

// Funció per validar que el navegador suporta notificacions
export function checkBrowserSupport(): { supported: boolean; reasons: string[] } {
  const reasons: string[] = [];
  
  if (!('serviceWorker' in navigator)) {
    reasons.push('Service Workers no suportats');
  }
  
  if (!('PushManager' in window)) {
    reasons.push('Push API no suportat');
  }
  
  if (!('Notification' in window)) {
    reasons.push('Notification API no suportat');
  }
  
  if (typeof Notification.requestPermission !== 'function') {
    reasons.push('Notification.requestPermission no disponible');
  }
  
  return {
    supported: reasons.length === 0,
    reasons
  };
}

export default NOTIFICATION_CONFIG;