// Edge Function per processar notificacions programades
// supabase/functions/process-notification-queue/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    console.log('Processant cua de notificacions programades...')

    // Obtenir notificacions pendents que ja haurien de ser enviades
    const { data: pendingNotifications, error: fetchError } = await supabase
      .from('scheduled_notifications')
      .select(`
        *,
        profiles!scheduled_notifications_user_id_fkey(name),
        challenges(
          id,
          challenger_id,
          challenged_id,
          deadline,
          status,
          challenger:profiles!challenges_challenger_id_fkey(name),
          challenged:profiles!challenges_challenged_id_fkey(name)
        )
      `)
      .eq('processed', false)
      .lte('scheduled_for', new Date().toISOString())
      .order('scheduled_for', { ascending: true })
      .limit(50) // Processar en lots de 50

    if (fetchError) {
      throw fetchError
    }

    if (!pendingNotifications || pendingNotifications.length === 0) {
      console.log('No hi ha notificacions pendents per processar')
      return new Response(
        JSON.stringify({ processed: 0, message: 'No pending notifications' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Trobades ${pendingNotifications.length} notificacions pendents`)

    let processedCount = 0
    let errorCount = 0

    // Processar cada notificació
    for (const notification of pendingNotifications) {
      try {
        await processNotification(supabase, notification)
        processedCount++
      } catch (error) {
        console.error(`Error processant notificació ${notification.id}:`, error)
        errorCount++
      }
    }

    console.log(`Processat: ${processedCount} èxits, ${errorCount} errors`)

    return new Response(
      JSON.stringify({
        processed: processedCount,
        errors: errorCount,
        total: pendingNotifications.length
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error en process-notification-queue:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function processNotification(supabase: any, notification: any) {
  const { user_id, tipus, payload, challenge_id, id } = notification

  let notificationData = {
    userId: user_id,
    tipus,
    titol: '',
    missatge: '',
    challengeId: challenge_id,
    url: '',
    actions: []
  }

  // Generar contingut segons el tipus de notificació
  switch (tipus) {
    case 'caducitat_proxima':
      await handleExpiryWarning(supabase, notification, notificationData)
      break
    
    case 'repte_caducat':
      await handleChallengeExpired(supabase, notification, notificationData)
      break
    
    case 'partida_recordatori':
      await handleMatchReminder(supabase, notification, notificationData)
      break
    
    default:
      console.warn(`Tipus de notificació desconegut: ${tipus}`)
      return
  }

  // Enviar notificació
  const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-push-notification`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
    },
    body: JSON.stringify(notificationData)
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Error enviant notificació: ${error}`)
  }

  // Marcar com processada
  const { error: updateError } = await supabase
    .from('scheduled_notifications')
    .update({
      processed: true,
      processed_at: new Date().toISOString()
    })
    .eq('id', id)

  if (updateError) {
    throw updateError
  }

  console.log(`Notificació ${id} processada correctament`)
}

async function handleExpiryWarning(supabase: any, notification: any, notificationData: any) {
  const challenge = notification.challenges

  if (!challenge) {
    throw new Error('Challenge no trobat per notificació de caducitat')
  }

  // Comprovar que el repte encara estigui actiu
  if (challenge.status !== 'proposed') {
    console.log(`Repte ${challenge.id} ja no està en estat 'proposed', saltant notificació`)
    return
  }

  const challengerName = challenge.challenger?.name || 'Algú'
  const hoursLeft = Math.ceil((new Date(challenge.deadline).getTime() - Date.now()) / (1000 * 60 * 60))

  notificationData.titol = 'Repte a punt de caducar!'
  notificationData.missatge = `El repte de ${challengerName} caduca en ${hoursLeft} hores`
  notificationData.url = `/reptes/${challenge.id}`
  notificationData.actions = [
    { action: 'accept', title: 'Acceptar', icon: '/icons/check-circle.svg' },
    { action: 'reject', title: 'Rebutjar', icon: '/icons/x-circle.svg' },
    { action: 'view', title: 'Veure detalls', icon: '/icons/eye.svg' }
  ]
}

async function handleChallengeExpired(supabase: any, notification: any, notificationData: any) {
  const challenge = notification.challenges

  if (!challenge) {
    throw new Error('Challenge no trobat per notificació de caducitat')
  }

  const challengerName = challenge.challenger?.name || 'Algú'
  const challengedName = challenge.challenged?.name || 'Algú'

  // Enviar notificació al reptador
  if (notification.user_id === challenge.challenger_id) {
    notificationData.titol = 'Repte caducat'
    notificationData.missatge = `El teu repte a ${challengedName} ha caducat sense resposta`
  } else {
    // Enviar notificació al reptat
    notificationData.titol = 'Has perdut un repte'
    notificationData.missatge = `No has respost al repte de ${challengerName} a temps`
  }

  notificationData.url = '/reptes'
  notificationData.actions = [
    { action: 'view', title: 'Veure reptes', icon: '/icons/eye.svg' }
  ]
}

async function handleMatchReminder(supabase: any, notification: any, notificationData: any) {
  const challenge = notification.challenges

  if (!challenge) {
    throw new Error('Challenge no trobat per recordatori de partida')
  }

  const opponentName = notification.user_id === challenge.challenger_id 
    ? challenge.challenged?.name 
    : challenge.challenger?.name

  notificationData.titol = 'Partida programada avui'
  notificationData.missatge = `Tens una partida amb ${opponentName || 'algú'} programada avui`
  notificationData.url = `/reptes/${challenge.id}`
  notificationData.actions = [
    { action: 'confirm', title: 'Confirmar assistència', icon: '/icons/check.svg' },
    { action: 'reschedule', title: 'Reagendar', icon: '/icons/calendar.svg' },
    { action: 'view', title: 'Veure detalls', icon: '/icons/eye.svg' }
  ]
}