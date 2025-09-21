// Tipus TypeScript per al Service Worker i notificacions
// src/lib/types/service-worker.ts

/// <reference lib="webworker" />

// Definicions de tipus simples que no conflicteixin amb globals
export interface SWNotificationAction {
  action: string;
  title: string;
  icon?: string;
}

export interface SWNotificationOptions {
  actions?: SWNotificationAction[];
  badge?: string;
  body?: string;
  data?: any;
  dir?: 'auto' | 'ltr' | 'rtl';
  icon?: string;
  image?: string;
  lang?: string;
  renotify?: boolean;
  requireInteraction?: boolean;
  silent?: boolean;
  tag?: string;
  timestamp?: number;
  vibrate?: number[];
}

// Tipus per a events del service worker sense herència conflictiva
export interface SWPushEvent {
  data: {
    json(): any;
    text(): string;
    arrayBuffer(): ArrayBuffer;
  } | null;
  waitUntil(promise: Promise<any>): void;
}

export interface SWNotificationEvent {
  action: string;
  notification: {
    tag: string;
    data: any;
    close(): void;
  };
  waitUntil(promise: Promise<any>): void;
}

export interface SWSyncEvent {
  tag: string;
  lastChance: boolean;
  waitUntil(promise: Promise<any>): void;
}

// Tipus per clients del service worker
export interface SWClients {
  matchAll(options?: { type?: 'window' }): Promise<SWWindowClient[]>;
  openWindow(url: string): Promise<SWWindowClient | null>;
  claim(): Promise<void>;
}

export interface SWWindowClient {
  url: string;
  focus(): Promise<SWWindowClient>;
  postMessage(message: any): void;
}

export interface SWRegistration {
  showNotification(title: string, options?: SWNotificationOptions): Promise<void>;
}

// Tipus per a les dades de notificació
export interface NotificationData {
  titol: string;
  missatge: string;
  tipus: 'repte_nou' | 'caducitat_proxima' | 'repte_caducat' | 'partida_recordatori' | 'confirmacio_requerida' | 'ranking_actualitzat' | 'esdeveniment_club';
  accions?: NotificationActionData[];
  url_accio?: string;
  dades_extra?: {
    challengeId?: string;
    matchId?: string;
    userId?: string;
    [key: string]: any;
  };
}

export interface NotificationActionData {
  id: string;
  titol: string;
  icona?: string;
}

// Tipus per a l'historial de notificacions (base de dades)
export interface NotificationHistoryRecord {
  id: string;
  user_id: string;
  tipus: string;
  titol: string;
  missatge: string;
  dades_extra: any;
  enviada_el: string;
  llegida_el: string | null;
  url_accio: string | null;
}

// Tipus per a les subscripcions push
export interface PushSubscriptionData {
  id: string;
  user_id: string;
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
  user_agent: string;
  activa: boolean;
  creada_el: string;
  actualitzada_el: string;
}

// Tipus per a les preferències de notificació
export interface NotificationPreferences {
  notifications_enabled: boolean;
  quiet_hours: {
    enabled: boolean;
    start: string;
    end: string;
  };
  weekdays: Array<{
    id: string;
    name: string;
    enabled: boolean;
  }>;
  types: Record<string, {
    enabled: boolean;
    timing: {
      enabled: boolean;
      minutes: number;
    };
  }>;
}

// Tipus per als missatges del service worker
export interface ServiceWorkerMessage {
  type: string;
  data?: any;
}

export interface QuickActionMessage extends ServiceWorkerMessage {
  type: 'QUICK_ACTION';
  action: 'confirm' | 'decline';
  data: {
    challengeId?: string;
    matchId?: string;
    [key: string]: any;
  };
}

export interface NavigationMessage extends ServiceWorkerMessage {
  type: 'NAVIGATE_TO';
  url: string;
}

export interface NotificationMessage extends ServiceWorkerMessage {
  type: 'NEW_NOTIFICATION' | 'MARK_NOTIFICATION_READ' | 'NOTIFICATION_CLOSED';
  data?: any;
  notificationTag?: string;
  notificationType?: string;
}