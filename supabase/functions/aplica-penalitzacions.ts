// Edge Function Supabase: aplica penalitzacions automàtiques als reptes caducats
// Crida periòdicament l'endpoint del PWA

import { serve } from 'std/server';

// Substitueix per la teva API key si l'endpoint la requereix
const API_KEY = process.env.API_KEY || '<API_KEY>'; // Posa la clau aquí si cal
const ENDPOINT = 'https://campionat-3bandes.vercel.app/reptes/check-expired';

serve(async (req) => {
  try {
    const res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(API_KEY ? { 'Authorization': `Bearer ${API_KEY}` } : {})
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
// 3. Programa la funció des del panell de Supabase (Scheduled Functions) perquè s'executi cada dia o cada hora
// 4. Si cal API key, afegeix-la a les variables d'entorn del projecte
