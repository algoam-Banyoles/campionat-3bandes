// Edge Function per gestionar notificacions de reptes
// supabase/functions/challenge-notifications/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ChallengeNotificationPayload {
  type: 'challenge_created' | 'challenge_accepted' | 'challenge_completed' | 'challenge_expired';
  challengeId: string;
  userId?: string; // Opcional, si no es proporciona s'enviarà als participants del repte
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Usar service role key per accedir a totes les dades
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const payload: ChallengeNotificationPayload = await req.json()
    
    console.log('Processant notificació de repte:', payload)

    // Obtenir dades del repte
    const { data: challenge, error: challengeError } = await supabase
      .from('challenges')
      .select(`
        *,
        challenger:profiles!challenges_challenger_id_fkey(name, user_id),
        challenged:profiles!challenges_challenged_id_fkey(name, user_id)
      `)
      .eq('id', payload.challengeId)
      .single()

    if (challengeError || !challenge) {
      throw new Error(`Repte no trobat: ${challengeError?.message}`)
    }

    let results = []

    switch (payload.type) {
      case 'challenge_created':
        results.push(await handleChallengeCreated(supabase, challenge))
        break

      case 'challenge_accepted':
        results.push(await handleChallengeAccepted(supabase, challenge))
        break

      case 'challenge_completed':
        results = await handleChallengeCompleted(supabase, challenge)
        break

      case 'challenge_expired':
        results = await handleChallengeExpired(supabase, challenge)
        break

      default:
        throw new Error(`Tipus de notificació desconegut: ${payload.type}`)
    }

    const successCount = results.filter(r => r.success).length
    const errorCount = results.filter(r => !r.success).length

    return new Response(
      JSON.stringify({
        success: successCount > 0,
        processed: results.length,
        successCount,
        errorCount,
        results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error en challenge-notifications:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Repte creat - notificar al reptat
async function handleChallengeCreated(supabase: any, challenge: any) {
  const challengerName = challenge.challenger?.name || 'Algú'
  
  const notificationData = {
    userId: challenge.challenged_id,
    tipus: 'repte_nou',
    titol: 'Nou repte rebut!',
    missatge: `${challengerName} t'ha proposat un repte`,
    challengeId: challenge.id,
    url: `/reptes/${challenge.id}`,
    actions: [
      { action: 'accept', title: 'Acceptar', icon: '/icons/check-circle.svg' },
      { action: 'reject', title: 'Rebutjar', icon: '/icons/x-circle.svg' },
      { action: 'view', title: 'Veure detalls', icon: '/icons/eye.svg' }
    ]
  }

  try {
    const response = await sendNotification(notificationData)
    return { userId: challenge.challenged_id, success: response.ok, type: 'challenge_created' }
  } catch (error) {
    console.error('Error enviant notificació de repte creat:', error)
    return { userId: challenge.challenged_id, success: false, error: error.message, type: 'challenge_created' }
  }
}

// Repte acceptat - notificar al reptador
async function handleChallengeAccepted(supabase: any, challenge: any) {
  const challengedName = challenge.challenged?.name || 'Algú'
  
  const notificationData = {
    userId: challenge.challenger_id,
    tipus: 'repte_acceptat',
    titol: 'Repte acceptat!',
    missatge: `${challengedName} ha acceptat el teu repte`,
    challengeId: challenge.id,
    url: `/reptes/${challenge.id}`,
    actions: [
      { action: 'view', title: 'Veure detalls', icon: '/icons/eye.svg' }
    ]
  }

  try {
    const response = await sendNotification(notificationData)
    return { userId: challenge.challenger_id, success: response.ok, type: 'challenge_accepted' }
  } catch (error) {
    console.error('Error enviant notificació de repte acceptat:', error)
    return { userId: challenge.challenger_id, success: false, error: error.message, type: 'challenge_accepted' }
  }
}

// Repte completat - notificar a ambdós participants
async function handleChallengeCompleted(supabase: any, challenge: any) {
  const challengerName = challenge.challenger?.name || 'Algú'
  const challengedName = challenge.challenged?.name || 'Algú'
  
  const results = []

  // Notificació al reptador
  const challengerNotification = {
    userId: challenge.challenger_id,
    tipus: 'repte_completat',
    titol: 'Repte finalitzat',
    missatge: `El repte amb ${challengedName} ha estat completat`,
    challengeId: challenge.id,
    url: `/reptes/${challenge.id}`,
    actions: [
      { action: 'view', title: 'Veure resultats', icon: '/icons/eye.svg' }
    ]
  }

  // Notificació al reptat
  const challengedNotification = {
    userId: challenge.challenged_id,
    tipus: 'repte_completat',
    titol: 'Repte finalitzat',
    missatge: `El repte amb ${challengerName} ha estat completat`,
    challengeId: challenge.id,
    url: `/reptes/${challenge.id}`,
    actions: [
      { action: 'view', title: 'Veure resultats', icon: '/icons/eye.svg' }
    ]
  }

  // Enviar notificacions
  try {
    const challengerResponse = await sendNotification(challengerNotification)
    results.push({ 
      userId: challenge.challenger_id, 
      success: challengerResponse.ok, 
      type: 'challenge_completed_challenger' 
    })
  } catch (error) {
    results.push({ 
      userId: challenge.challenger_id, 
      success: false, 
      error: error.message, 
      type: 'challenge_completed_challenger' 
    })
  }

  try {
    const challengedResponse = await sendNotification(challengedNotification)
    results.push({ 
      userId: challenge.challenged_id, 
      success: challengedResponse.ok, 
      type: 'challenge_completed_challenged' 
    })
  } catch (error) {
    results.push({ 
      userId: challenge.challenged_id, 
      success: false, 
      error: error.message, 
      type: 'challenge_completed_challenged' 
    })
  }

  return results
}

// Repte caducat - notificar a ambdós participants
async function handleChallengeExpired(supabase: any, challenge: any) {
  const challengerName = challenge.challenger?.name || 'Algú'
  const challengedName = challenge.challenged?.name || 'Algú'
  
  const results = []

  // Programar notificacions de caducitat (en lloc d'enviar-les immediatament)
  const now = new Date()
  
  // Notificació al reptador
  const challengerScheduled = {
    user_id: challenge.challenger_id,
    tipus: 'repte_caducat',
    scheduled_for: now.toISOString(),
    challenge_id: challenge.id,
    payload: {
      titol: 'Repte caducat',
      missatge: `El teu repte a ${challengedName} ha caducat sense resposta`,
      url: '/reptes',
      type: 'repte_caducat'
    }
  }

  // Notificació al reptat
  const challengedScheduled = {
    user_id: challenge.challenged_id,
    tipus: 'repte_caducat',
    scheduled_for: now.toISOString(),
    challenge_id: challenge.id,
    payload: {
      titol: 'Has perdut un repte',
      missatge: `No has respost al repte de ${challengerName} a temps`,
      url: '/reptes',
      type: 'repte_caducat'
    }
  }

  // Programar les notificacions
  try {
    const { error: scheduleError } = await supabase
      .from('scheduled_notifications')
      .insert([challengerScheduled, challengedScheduled])

    if (scheduleError) {
      throw scheduleError
    }

    results.push({ 
      userId: challenge.challenger_id, 
      success: true, 
      type: 'challenge_expired_scheduled' 
    })
    results.push({ 
      userId: challenge.challenged_id, 
      success: true, 
      type: 'challenge_expired_scheduled' 
    })
  } catch (error) {
    console.error('Error programant notificacions de caducitat:', error)
    results.push({ 
      userId: challenge.challenger_id, 
      success: false, 
      error: error.message, 
      type: 'challenge_expired_scheduled' 
    })
    results.push({ 
      userId: challenge.challenged_id, 
      success: false, 
      error: error.message, 
      type: 'challenge_expired_scheduled' 
    })
  }

  return results
}

// Enviar notificació mitjançant la Edge Function send-push-notification
async function sendNotification(notificationData: any): Promise<Response> {
  return fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-push-notification`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
    },
    body: JSON.stringify(notificationData)
  })
}