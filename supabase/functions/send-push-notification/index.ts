// Edge Function per enviar notificació push individual
// supabase/functions/send-push-notification/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  userId: string;
  tipus: 'repte_nou' | 'caducitat_proxima' | 'repte_caducat' | 'partida_recordatori' | 'confirmacio_requerida';
  titol: string;
  missatge: string;
  challengeId?: string;
  eventId?: string;
  url?: string;
  actions?: Array<{
    action: string;
    title: string;
    icon?: string;
  }>;
}

interface PushMessage {
  notification: {
    title: string;
    body: string;
    icon?: string;
    badge?: string;
    tag?: string;
    data?: any;
  };
}

// Clau privada VAPID (cal generar-la i posar-la com a secret)
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY')!;
const VAPID_PUBLIC_KEY = Deno.env.get('VAPID_PUBLIC_KEY')!;

serve(async (req) => {
  // Manejar CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verificar autenticació
    const authHeader = req.headers.get('Authorization')!
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // Obtenir payload de la petició
    const payload: NotificationPayload = await req.json()
    
    console.log('Enviant notificació:', payload)

    // Obtenir subscripcions actives de l'usuari
    const { data: subscriptions, error: subscriptionsError } = await supabase
      .from('push_subscriptions')
      .select('*')
      .eq('user_id', payload.userId)
      .eq('activa', true)

    if (subscriptionsError) {
      throw subscriptionsError
    }

    if (!subscriptions || subscriptions.length === 0) {
      console.log('No hi ha subscripcions actives per l\'usuari:', payload.userId)
      return new Response(
        JSON.stringify({ success: false, message: 'No subscriptions found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Comprovar preferències de l'usuari
    const { data: preferences } = await supabase
      .from('notification_preferences')
      .select('*')
      .eq('user_id', payload.userId)
      .single()

    // Verificar si l'usuari vol rebre aquest tipus de notificació
    if (preferences) {
      const shouldSkip = (
        (payload.tipus === 'repte_nou' && !preferences.reptes_nous) ||
        (payload.tipus === 'caducitat_proxima' && !preferences.caducitat_terminis) ||
        (payload.tipus === 'partida_recordatori' && !preferences.recordatoris_partides)
      )

      if (shouldSkip) {
        console.log('Usuari ha desactivat aquest tipus de notificació:', payload.tipus)
        return new Response(
          JSON.stringify({ success: false, message: 'User disabled this notification type' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Comprovar mode silenciós
      if (preferences.silenci_nocturn && isQuietHours(preferences.hora_inici_silenci, preferences.hora_fi_silenci)) {
        console.log('Hora de silenci activa, posposant notificació')
        // TODO: Programar per enviar després del silenci
        return new Response(
          JSON.stringify({ success: false, message: 'Quiet hours active' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Preparar missatge push
    const pushMessage: PushMessage = {
      notification: {
        title: payload.titol,
        body: payload.missatge,
        icon: '/favicon.svg',
        badge: '/favicon.svg',
        tag: `${payload.tipus}_${payload.challengeId || payload.eventId || Date.now()}`,
        data: {
          type: payload.tipus,
          challengeId: payload.challengeId,
          eventId: payload.eventId,
          url: payload.url,
          actions: payload.actions
        }
      }
    }

    const results = []
    let successCount = 0
    let errorCount = 0

    // Enviar notificació a totes les subscripcions
    for (const subscription of subscriptions) {
      try {
        const response = await sendWebPush({
          endpoint: subscription.endpoint,
          p256dhKey: subscription.p256dh_key,
          authKey: subscription.auth_key,
          payload: JSON.stringify(pushMessage)
        })

        if (response.ok) {
          successCount++
          results.push({ subscriptionId: subscription.id, success: true })
        } else {
          errorCount++
          results.push({ 
            subscriptionId: subscription.id, 
            success: false, 
            error: await response.text() 
          })

          // Si la subscripció no és vàlida, marcar-la com inactiva
          if (response.status === 410 || response.status === 404) {
            await supabase
              .from('push_subscriptions')
              .update({ activa: false })
              .eq('id', subscription.id)
          }
        }
      } catch (error) {
        errorCount++
        results.push({ 
          subscriptionId: subscription.id, 
          success: false, 
          error: error.message 
        })
      }
    }

    // Guardar historial de notificació
    const { error: historyError } = await supabase
      .from('notification_history')
      .insert({
        user_id: payload.userId,
        tipus: payload.tipus,
        titol: payload.titol,
        missatge: payload.missatge,
        challenge_id: payload.challengeId,
        event_id: payload.eventId,
        payload: pushMessage,
        success: successCount > 0,
        error_message: errorCount > 0 ? `${errorCount} errors occurred` : null
      })

    if (historyError) {
      console.error('Error guardant historial:', historyError)
    }

    console.log(`Notificació enviada: ${successCount} èxits, ${errorCount} errors`)

    return new Response(
      JSON.stringify({
        success: successCount > 0,
        successCount,
        errorCount,
        results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error en send-push-notification:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Función para enviar Web Push
async function sendWebPush({ endpoint, p256dhKey, authKey, payload }: {
  endpoint: string;
  p256dhKey: string;
  authKey: string;
  payload: string;
}): Promise<Response> {
  // Implementar lògica de Web Push amb VAPID
  // Això requereix implementar la signatura VAPID i l'encriptació del payload
  
  const vapidHeaders = generateVAPIDHeaders(endpoint)
  
  return fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Encoding': 'aes128gcm',
      ...vapidHeaders
    },
    body: await encryptPayload(payload, p256dhKey, authKey)
  })
}

// Generar headers VAPID
function generateVAPIDHeaders(endpoint: string): Record<string, string> {
  const url = new URL(endpoint)
  const audience = `${url.protocol}//${url.host}`
  
  // TODO: Implementar signatura JWT VAPID
  // Això requereix una biblioteca de JWT i crypto
  
  return {
    'Authorization': `vapid t=${generateJWT(audience)}, k=${VAPID_PUBLIC_KEY}`,
  }
}

// Generar JWT per VAPID (simplificat)
function generateJWT(audience: string): string {
  // TODO: Implementar generació JWT real amb VAPID_PRIVATE_KEY
  // Per ara retornem un placeholder
  return 'JWT_PLACEHOLDER'
}

// Encriptar payload
async function encryptPayload(payload: string, p256dhKey: string, authKey: string): Promise<ArrayBuffer> {
  // TODO: Implementar encriptació AES128GCM per Web Push
  // Això és complex i requereix bibliotecques crypto específiques
  
  // Per ara retornem el payload sense encriptar (no recomanat per producció)
  return new TextEncoder().encode(payload)
}

// Comprovar si estem en hores de silenci
function isQuietHours(startTime: string, endTime: string): boolean {
  const now = new Date()
  const currentTime = now.toTimeString().slice(0, 5) // HH:MM format
  
  // Si l'hora d'inici és posterior a la de fi, vol dir que creua mitjanit
  if (startTime > endTime) {
    return currentTime >= startTime || currentTime <= endTime
  } else {
    return currentTime >= startTime && currentTime <= endTime
  }
}