import { supabase } from '$lib/supabaseClient';

export interface NotificationData {
  playerEmail: string;
  playerName: string;
  eventName: string;
  eventType: string;
  modality: string;
  season: string;
  status: 'confirmed' | 'payment_required' | 'category_assigned' | 'inscription_received';
  categoryName?: string;
  quota?: number;
}

export async function sendInscriptionNotification(data: NotificationData): Promise<void> {
  const templates = {
    inscription_received: {
      subject: `📝 Inscripció rebuda - ${data.eventName}`,
      body: `
        <h2>Inscripció rebuda</h2>
        <p>Hola ${data.playerName},</p>
        <p>Hem rebut la teva inscripció per a <strong>${data.eventName}</strong> (${data.modality} - ${data.season}).</p>
        <p>La junta revisarà la teva inscripció i t'assignarà una categoria segons la teva mitjana històrica.</p>
        <p>Rebràs una nova notificació quan l'estat de la teva inscripció canviï.</p>
        <hr>
        <p><em>Foment Martinenc - Secció Billar</em></p>
      `
    },
    category_assigned: {
      subject: `🎯 Categoria assignada - ${data.eventName}`,
      body: `
        <h2>Categoria assignada</h2>
        <p>Hola ${data.playerName},</p>
        <p>T'hem assignat la categoria <strong>${data.categoryName}</strong> per a ${data.eventName}.</p>
        ${data.quota && data.quota > 0 ? `
        <p><strong>Quota d'inscripció:</strong> ${data.quota}€</p>
        <p>Per confirmar la teva inscripció, hauràs de pagar la quota indicada.</p>
        ` : ''}
        <p>Pots consultar l'estat de la teva inscripció a la plataforma.</p>
        <hr>
        <p><em>Foment Martinenc - Secció Billar</em></p>
      `
    },
    payment_required: {
      subject: `💳 Pagament pendent - ${data.eventName}`,
      body: `
        <h2>Pagament pendent</h2>
        <p>Hola ${data.playerName},</p>
        <p>Per completar la teva inscripció a <strong>${data.eventName}</strong>, cal que paguis la quota de <strong>${data.quota}€</strong>.</p>
        <p>Pots efectuar el pagament a la secretaria del club o contactar amb la junta per més informació.</p>
        <p>Un cop rebut el pagament, la teva inscripció quedarà confirmada.</p>
        <hr>
        <p><em>Foment Martinenc - Secció Billar</em></p>
      `
    },
    confirmed: {
      subject: `✅ Inscripció confirmada - ${data.eventName}`,
      body: `
        <h2>Inscripció confirmada</h2>
        <p>Hola ${data.playerName},</p>
        <p>La teva inscripció a <strong>${data.eventName}</strong> ha estat confirmada!</p>
        ${data.categoryName ? `<p><strong>Categoria:</strong> ${data.categoryName}</p>` : ''}
        <p>Rebràs el calendari de partides un cop es generi automàticament.</p>
        <p>Bon campionat!</p>
        <hr>
        <p><em>Foment Martinenc - Secció Billar</em></p>
      `
    }
  };

  const template = templates[data.status];
  if (!template) {
    console.error('Template not found for status:', data.status);
    return;
  }

  try {
    // Utilitzem la funció edge de Supabase per enviar emails
    const { error } = await supabase.functions.invoke('send-email', {
      body: {
        to: data.playerEmail,
        subject: template.subject,
        html: template.body
      }
    });

    if (error) {
      console.error('Error sending notification:', error);
      // Si falla l'email, registrem la notificació a la base de dades per un seguiment posterior
      await logNotificationAttempt(data, 'failed', error.message);
    } else {
      await logNotificationAttempt(data, 'sent');
    }
  } catch (error) {
    console.error('Error in notification service:', error);
    await logNotificationAttempt(data, 'failed', error instanceof Error ? error.message : 'Unknown error');
  }
}

async function logNotificationAttempt(data: NotificationData, status: 'sent' | 'failed', errorMessage?: string) {
  try {
    await supabase.from('notification_log').insert({
      recipient_email: data.playerEmail,
      event_name: data.eventName,
      notification_type: data.status,
      status,
      error_message: errorMessage,
      sent_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Failed to log notification attempt:', error);
  }
}

// Funció per enviar recordatoris de pagament
export async function sendPaymentReminders(): Promise<void> {
  try {
    const { data: pendingPayments, error } = await supabase
      .from('inscripcions')
      .select(`
        *,
        socis (nom, cognoms, email),
        events (nom, modalitat, temporada, quota_inscripcio),
        categoria_assignada:categories (nom)
      `)
      .eq('confirmat', false)
      .eq('pagat', false)
      .gt('events.quota_inscripcio', 0);

    if (error) throw error;

    for (const inscription of pendingPayments || []) {
      if (!inscription.socis?.email) continue;

      await sendInscriptionNotification({
        playerEmail: inscription.socis.email,
        playerName: `${inscription.socis.nom} ${inscription.socis.cognoms}`,
        eventName: inscription.events.nom,
        eventType: inscription.events.tipus_competicio,
        modality: inscription.events.modalitat,
        season: inscription.events.temporada,
        status: 'payment_required',
        categoryName: inscription.categoria_assignada?.nom,
        quota: inscription.events.quota_inscripcio
      });

      // Espera 1 segon entre emails per no saturar el servei
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  } catch (error) {
    console.error('Error sending payment reminders:', error);
  }
}