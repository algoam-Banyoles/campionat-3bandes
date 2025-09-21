// Store per gestionar notificacions push
// src/lib/stores/notifications.ts

import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import { supabase } from '$lib/supabaseClient';
import { user } from './auth';

// Tipus per subscripcions push
export interface PushSubscription {
  id: string;
  user_id: string;
  endpoint: string;
  p256dh_key: string;
  auth_key: string;
  user_agent?: string;
  activa: boolean;
  created_at: string;
  updated_at: string;
}

// Tipus per preferències de notificacions
export interface NotificationPreferences {
  user_id: string;
  reptes_nous: boolean;
  caducitat_terminis: boolean;
  recordatoris_partides: boolean;
  hores_abans_recordatori: number;
  minuts_abans_caducitat: number;
  silenci_nocturn: boolean;
  hora_inici_silenci: string;
  hora_fi_silenci: string;
}

// Tipus per historial de notificacions
export interface NotificationHistoryItem {
  id: string;
  user_id: string;
  tipus: 'repte_nou' | 'caducitat_proxima' | 'repte_caducat' | 'partida_recordatori' | 'confirmacio_requerida';
  titol: string;
  missatge: string;
  enviada_el: string;
  llegida_el?: string;
  challenge_id?: string;
  event_id?: string;
  payload?: any;
}

// Estats dels stores
export const pushSupported = writable<boolean>(false);
export const pushPermission = writable<NotificationPermission>('default');
export const pushSubscription = writable<PushSubscription | null>(null);
export const notificationPreferences = writable<NotificationPreferences | null>(null);
export const notificationHistory = writable<NotificationHistoryItem[]>([]);
export const notificationsLoading = writable<boolean>(false);
export const notificationsError = writable<string | null>(null);

// Clau pública VAPID (carregada des de variables d'entorn)
const VAPID_PUBLIC_KEY = import.meta.env.VITE_PUBLIC_VAPID_KEY || 'BLXGAD3N80WkTysFnwXi-ZMQ69ebDFw2Y-JphkJQ0ibugLfYPm4Cr8flV05HLHuUA1oGDKK5w33nVpscCEUnZ0M';

// Derived store per comprovar si les notificacions estan habilitades
export const notificationsEnabled = derived(
  [pushSupported, pushPermission, pushSubscription],
  ([$pushSupported, $pushPermission, $pushSubscription]) => {
    return $pushSupported && $pushPermission === 'granted' && $pushSubscription !== null;
  }
);

// Inicialitzar el sistema de notificacions
export function initializeNotifications(): void {
  if (!browser) return;

  // Comprovar suport per notificacions push
  if ('serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window) {
    pushSupported.set(true);
    pushPermission.set(Notification.permission);
    
    // Registrar service worker si no està registrat
    registerServiceWorker();
    
    // Comprovar subscripció existent
    checkExistingSubscription();
  } else {
    console.warn('Notificacions push no compatibles amb aquest navegador');
    pushSupported.set(false);
  }
}

// Usar el service worker generat per Vite-PWA
async function registerServiceWorker(): Promise<void> {
  try {
    // Vite-PWA ja registra automàticament el Service Worker
    // Només esperem que estigui llest
    await navigator.serviceWorker.ready;
    console.log('Service Worker llest (gestionat per Vite-PWA)');
  } catch (error) {
    console.error('Error esperant Service Worker:', error);
    notificationsError.set('Error amb Service Worker');
  }
}

// Comprovar subscripció existent
async function checkExistingSubscription(): Promise<void> {
  try {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    
    if (subscription) {
      // Comprovar si la subscripció està guardada a la base de dades
      const { data, error } = await supabase
        .from('push_subscriptions')
        .select('*')
        .eq('endpoint', subscription.endpoint)
        .eq('activa', true)
        .single();
      
      if (error && error.code !== 'PGRST116') {
        console.error('Error comprovant subscripció existent:', error);
        return;
      }
      
      if (data) {
        pushSubscription.set(data);
      } else {
        // Subscripció al navegador però no a la BD, eliminar-la
        await subscription.unsubscribe();
      }
    }
  } catch (error) {
    console.error('Error comprovant subscripció existent:', error);
  }
}

// Sol·licitar permisos de notificació
export async function requestNotificationPermission(): Promise<boolean> {
  if (!browser || !get(pushSupported)) {
    console.warn('⚠️ Notificacions no suportades o no estem al navegador');
    return false;
  }

  try {
    console.log('🔔 Sol·licitant permisos de notificació...');
    console.log('Estat actual:', Notification.permission);
    
    // Intentar múltiples vegades si cal
    let permission = Notification.permission;
    
    if (permission === 'default') {
      permission = await Notification.requestPermission();
      console.log('📝 Nou permís rebut:', permission);
    }
    
    pushPermission.set(permission);
    
    if (permission === 'granted') {
      console.log('✅ Permisos concedits, subscrivint a push...');
      const subscribed = await subscribeToPush();
      console.log('📨 Subscripció completa:', subscribed);
      return subscribed;
    } else {
      console.warn('❌ Permisos denegats o no concedits:', permission);
      if (permission === 'denied') {
        notificationsError.set('Les notificacions han estat bloquejades. Cal habilitar-les manualment al navegador.');
      }
      return false;
    }
  } catch (error) {
    console.error('💥 Error sol·licitant permisos de notificació:', error);
    notificationsError.set('Error sol·licitant permisos de notificació: ' + error.message);
    return false;
  }
}

// Subscriure a notificacions push
export async function subscribeToPush(): Promise<boolean> {
  if (!browser || !get(pushSupported) || get(pushPermission) !== 'granted') {
    return false;
  }

  const currentUser = get(user);
  if (!currentUser) {
    notificationsError.set('Cal estar autenticat per subscriure\'s a notificacions');
    return false;
  }

  try {
    notificationsLoading.set(true);
    notificationsError.set(null);

    const registration = await navigator.serviceWorker.ready;
    
    // Crear nova subscripció
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY) as BufferSource
    });

    // Extreure claus de la subscripció
    const p256dhKey = arrayBufferToBase64(subscription.getKey('p256dh'));
    const authKey = arrayBufferToBase64(subscription.getKey('auth'));

    // Guardar subscripció a la base de dades
    const { data, error } = await supabase
      .from('push_subscriptions')
      .insert({
        user_id: (currentUser as any)?.id || '',
        endpoint: subscription.endpoint,
        p256dh_key: p256dhKey,
        auth_key: authKey,
        user_agent: navigator.userAgent,
        activa: true
      })
      .select()
      .single();

    if (error) {
      throw error;
    }

    pushSubscription.set(data);
    console.log('Subscripció push creada correctament');
    return true;

  } catch (error: any) {
    console.error('Error creant subscripció push:', error);
    notificationsError.set(error.message || 'Error creant subscripció push');
    return false;
  } finally {
    notificationsLoading.set(false);
  }
}

// Desubscriure de notificacions push
export async function unsubscribeFromPush(): Promise<boolean> {
  if (!browser) return false;

  const currentSubscription = get(pushSubscription);
  if (!currentSubscription) return true;

  try {
    notificationsLoading.set(true);
    notificationsError.set(null);

    // Eliminar subscripció del navegador
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    
    if (subscription) {
      await subscription.unsubscribe();
    }

    // Marcar com inactiva a la base de dades
    const { error } = await supabase
      .from('push_subscriptions')
      .update({ activa: false })
      .eq('id', (currentSubscription as any).id);

    if (error) {
      throw error;
    }

    pushSubscription.set(null);
    console.log('Desubscripció completada');
    return true;

  } catch (error: any) {
    console.error('Error desubscrivint:', error);
    notificationsError.set(error.message || 'Error desubscrivint');
    return false;
  } finally {
    notificationsLoading.set(false);
  }
}

// Carregar preferències de notificacions
export async function loadNotificationPreferences(): Promise<void> {
  const currentUser = get(user);
  if (!user) return;

  try {
    notificationsLoading.set(true);
    notificationsError.set(null);

    const { data, error } = await supabase
      .from('notification_preferences')
      .select('*')
      .eq('user_id', (currentUser as any)?.id || '')
      .single();

    if (error && error.code !== 'PGRST116') {
      throw error;
    }

    notificationPreferences.set(data || null);
  } catch (error: any) {
    console.error('Error carregant preferències:', error);
    notificationsError.set(error.message || 'Error carregant preferències');
  } finally {
    notificationsLoading.set(false);
  }
}

// Actualitzar preferències de notificacions
export async function updateNotificationPreferences(preferences: Partial<NotificationPreferences>): Promise<boolean> {
  const currentUser = get(user);
  if (!user) return false;

  try {
    notificationsLoading.set(true);
    notificationsError.set(null);

    const { data, error } = await supabase
      .from('notification_preferences')
      .upsert({
        user_id: (currentUser as any)?.id || '',
        ...preferences
      })
      .select()
      .single();

    if (error) {
      throw error;
    }

    notificationPreferences.set(data);
    return true;
  } catch (error: any) {
    console.error('Error actualitzant preferències:', error);
    notificationsError.set(error.message || 'Error actualitzant preferències');
    return false;
  } finally {
    notificationsLoading.set(false);
  }
}

// Carregar historial de notificacions
export async function loadNotificationHistory(): Promise<void> {
  const currentUser = get(user);
  if (!user) return;

  try {
    notificationsLoading.set(true);
    notificationsError.set(null);

    const { data, error } = await supabase
      .from('notification_history')
      .select('*')
      .eq('user_id', (currentUser as any)?.id || '')
      .order('enviada_el', { ascending: false })
      .limit(50);

    if (error) {
      throw error;
    }

    notificationHistory.set(data || []);
  } catch (error: any) {
    console.error('Error carregant historial:', error);
    notificationsError.set(error.message || 'Error carregant historial');
  } finally {
    notificationsLoading.set(false);
  }
}

// Marcar notificació com llegida
export async function markNotificationAsRead(notificationId: string): Promise<void> {
  try {
    const { error } = await supabase
      .from('notification_history')
      .update({ llegida_el: new Date().toISOString() })
      .eq('id', notificationId);

    if (error) {
      throw error;
    }

    // Actualitzar l'historial local
    notificationHistory.update(history => 
      history.map(item => 
        item.id === notificationId 
          ? { ...item, llegida_el: new Date().toISOString() }
          : item
      )
    );
  } catch (error) {
    console.error('Error marcant notificació com llegida:', error);
  }
}

// Funcions d'utilitat
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding)
    .replace(/-/g, '+')
    .replace(/_/g, '/');

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

function arrayBufferToBase64(buffer: ArrayBuffer | null): string {
  if (!buffer) return '';
  
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return window.btoa(binary);
}

// Export principal per facilitar la importació
export const notificationStore = {
  // Stores reactius
  supported: pushSupported,
  permission: pushPermission,
  subscription: pushSubscription,
  preferences: notificationPreferences,
  history: notificationHistory,
  loading: notificationsLoading,
  error: notificationsError,
  enabled: notificationsEnabled,

  // Funcions
  initialize: initializeNotifications,
  requestPermission: requestNotificationPermission,
  subscribe: subscribeToPush,
  unsubscribe: unsubscribeFromPush,
  updatePreferences: updateNotificationPreferences,
  loadHistory: loadNotificationHistory,
  markAsRead: markNotificationAsRead
};
