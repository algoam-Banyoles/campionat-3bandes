// Edge Function Supabase: aplica penalitzacions automàtiques als reptes caducats
// Crida periòdicament l'endpoint del PWA

import { serve } from 'std/server';

const ENDPOINT = 'https://campionat-3bandes.vercel.app/campionat-continu/reptes/check-expired';

serve(async (_req) => {
  const cronSecret = Deno.env.get('CRON_SECRET');
  if (!cronSecret) {
    console.error('[aplica-penalitzacions] CRON_SECRET no està configurat. Abortant.');
    return new Response('Error: CRON_SECRET no configurat', { status: 500 });
  }

  try {
    const res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-cron-secret': cronSecret
      }
    });
    if (!res.ok) {
      return new Response(`Error en la crida: ${res.status} ${await res.text()}`, { status: 500 });
    }
    const data = await res.json();
    return new Response(`Penalitzacions aplicades: ${JSON.stringify(data)}`, { status: 200 });
  } catch (e: any) {
    return new Response(`Error intern: ${e?.message ?? e}`, { status: 500 });
  }
});

// Instruccions:
// 1. Desa aquest fitxer a supabase/functions/aplica-penalitzacions.ts
// 2. Desplega la funció amb supabase CLI: supabase functions deploy aplica-penalitzacions
// 3. Afegeix CRON_SECRET a les variables d'entorn de la funció al panell de Supabase
//    (i la mateixa variable al projecte Vercel com a variable d'entorn de servidor)
// 4. Programa la funció des del panell de Supabase (Scheduled Functions) perquè
//    s'executi cada dia o cada hora
