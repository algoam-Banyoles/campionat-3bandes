/**
 * Adaptador del campionat continu per a la gestió unificada de partides.
 *
 * Llegeix challenges actius (proposat/acceptat/programat) i despatxa:
 * - enterResult → authFetch POST /campionat-continu/gestio-reptes/[id]/resultat
 *   (NOTA: aquest endpoint només existeix al deploy de Vercel/dev, no al build estàtic).
 * - schedule    → supabase.rpc('programar_repte', {...})
 * - Sense unschedule (no suportat pel continu).
 *
 * Billar sempre null (el continu no usa billar).
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import { formatarNomJugadorParts } from '$lib/utils/playerUtils';
import { authFetch } from '$lib/utils/http';
import type {
  MatchAdapter,
  UnifiedMatch,
  UnifiedPlayer,
  UnifiedStatus,
  ContinuMeta,
  ResultInput,
  EnterResultResponse
} from './types';

// ── Helpers ────────────────────────────────────────────────────────────────

function mapEstat(estat: string): UnifiedStatus {
  if (estat === 'jugat') return 'jugada';
  if (estat === 'proposat' || estat === 'acceptat') return 'pendent';
  if (estat === 'programat') return 'programada';
  return 'altres';
}

function buildPlayer(
  sociNumero: number | null,
  nom: string | null
): UnifiedPlayer {
  const raw = nom ?? '?';
  // El continu emmagatzema nom complet a socis.nom (sense cognoms per separat en la cerca ràpida)
  // Usem formatarNomJugadorParts sense cognoms → retornarà el primer token com a inicial + primer cognom
  return {
    displayName: raw !== '?' ? formatarNomJugadorParts(nom, null) || raw : '?',
    rawName: raw,
    sociNumero
  };
}

// ── Adaptador ──────────────────────────────────────────────────────────────

export const continuAdapter: MatchAdapter = {
  async listMatches(supabase: SupabaseClient, includeJugades = false): Promise<UnifiedMatch[]> {
    // 1. Trobar l'event ranking_continu actiu
    const { data: ev, error: evErr } = await supabase
      .from('events')
      .select('id')
      .eq('tipus_competicio', 'ranking_continu')
      .eq('actiu', true)
      .limit(1)
      .maybeSingle();

    if (evErr) throw new Error(`Error carregant event continu: ${evErr.message}`);
    if (!ev) return [];

    const eventId = (ev as any).id as string;

    // 2. Carregar reptes actius (+ jugats si cal)
    const estats = ['proposat', 'acceptat', 'programat'];
    if (includeJugades) estats.push('jugat');

    const { data: challenges, error: cErr } = await supabase
      .from('challenges')
      .select(
        'id, event_id, reptador_soci_numero, reptat_soci_numero, pos_reptador, pos_reptat, estat, data_programada, reprogram_count'
      )
      .eq('event_id', eventId)
      .in('estat', estats);

    if (cErr) throw new Error(`Error carregant reptes: ${cErr.message}`);
    if (!challenges || challenges.length === 0) return [];

    // 3. Noms via socis
    const sociNumeros = Array.from(
      new Set(
        (challenges as any[]).flatMap((c) => [c.reptador_soci_numero, c.reptat_soci_numero]).filter(Boolean)
      )
    ) as number[];

    let sociMap = new Map<number, string | null>();
    if (sociNumeros.length > 0) {
      const { data: socis } = await supabase
        .from('socis')
        .select('numero_soci, nom')
        .in('numero_soci', sociNumeros);
      for (const s of (socis ?? []) as any[]) {
        sociMap.set(s.numero_soci as number, s.nom as string | null);
      }
    }

    // 4. Una consulta única d'app_settings per caramboles_objectiu/max_entrades/allow_tiebreak
    const { data: cfg } = await supabase
      .from('app_settings')
      .select('caramboles_objectiu, max_entrades, allow_tiebreak')
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    const settings = (cfg as any) ?? { caramboles_objectiu: 20, max_entrades: 50, allow_tiebreak: true };

    // 5. Construir UnifiedMatch[]
    const matches: UnifiedMatch[] = (challenges as any[]).map((c) => {
      const status = mapEstat(c.estat as string);

      let slot = null;
      if (c.data_programada) {
        // data_programada és timestamptz: convertir a data/hora LOCAL per a la UI
        const d = new Date(c.data_programada as string);
        const pad = (n: number) => String(n).padStart(2, '0');
        const dataIso = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
        const hora = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
        slot = { dataIso, hora, billar: null };
      }

      const meta: ContinuMeta = {
        source: 'continu',
        eventId,
        reprogramCount: (c.reprogram_count as number) ?? 0,
        posReptador: c.pos_reptador as number | null,
        posReptat: c.pos_reptat as number | null,
        carambolesObjectiu: (settings.caramboles_objectiu as number) ?? 20,
        maxEntrades: (settings.max_entrades as number) ?? 50,
        allowTiebreak: (settings.allow_tiebreak as boolean) ?? true
      };

      return {
        source: 'continu' as const,
        id: c.id as string,
        player1: buildPlayer(c.reptador_soci_numero, sociMap.get(c.reptador_soci_numero) ?? null),
        player2: buildPlayer(c.reptat_soci_numero, sociMap.get(c.reptat_soci_numero) ?? null),
        slot,
        status,
        rawEstat: c.estat as string,
        capabilities: {
          // Mirall del guard del servidor: només acceptat/programat admeten resultat
          canEnterResult: c.estat === 'acceptat' || c.estat === 'programat',
          canSchedule: status === 'pendent' || status === 'programada',
          canUnschedule: false
        },
        meta
      } satisfies UnifiedMatch;
    });

    return matches;
  },

  async enterResult(
    supabase: SupabaseClient,
    match: UnifiedMatch,
    input: ResultInput
  ): Promise<EnterResultResponse> {
    // Silence unused parameter warning — supabase no s'usa perquè l'escriptura
    // passa per l'endpoint HTTP (que usa serverSupabase internament).
    void supabase;

    if (input.kind !== 'continu') {
      throw new Error(`Tipus de resultat no vàlid per al continu: ${(input as any).kind}`);
    }

    // NOTA: l'endpoint /campionat-continu/gestio-reptes/[id]/resultat
    // només existeix al deploy de Vercel o en mode dev (`+server.ts`).
    const payload = {
      data_iso: input.data_iso,
      tipusResultat: input.tipusResultat,
      carR: input.carR,
      carT: input.carT,
      entrades: input.entrades,
      serieR: input.serieR,
      serieT: input.serieT,
      tbR: input.tbR,
      tbT: input.tbT
    };

    const res = await authFetch(
      `/campionat-continu/gestio-reptes/${match.id}/resultat`,
      { method: 'POST', body: JSON.stringify(payload) }
    );

    let body: any = null;
    try {
      body = await res.json();
    } catch {
      throw new Error(`Error de servidor (${res.status})`);
    }

    if (!res.ok || !body?.ok) {
      throw new Error(body?.error ?? `Error del servidor (${res.status})`);
    }

    return { message: body.rpcMsg ?? 'Resultat registrat.' };
  },

  async schedule(
    supabase: SupabaseClient,
    match: UnifiedMatch,
    slot: import('./types').UnifiedSlot
  ): Promise<void> {
    // Construir ISO complet a partir de data + hora
    const isoStr = slot.hora
      ? `${slot.dataIso}T${slot.hora}:00`
      : `${slot.dataIso}T00:00:00`;
    const d = new Date(isoStr);
    if (isNaN(d.getTime())) {
      throw new Error('Data o hora invàlida per programar el repte.');
    }
    const data_iso = d.toISOString();

    // Necessitem l'email de l'usuari autenticat per a p_actor_email
    const { data: authData } = await supabase.auth.getUser();
    const email = authData?.user?.email;
    if (!email) throw new Error('Cal iniciar sessió per programar un repte.');

    const { data: out, error: rpcErr } = await supabase.rpc('programar_repte', {
      p_challenge: match.id,
      p_data: data_iso,
      p_actor_email: email
    });

    if (rpcErr) throw new Error(rpcErr.message);
    const result = out as any;
    if (result && !result.ok) {
      throw new Error(result.error || 'Error programant el repte.');
    }
  }

  // Sense unschedule: el continu no suporta desprogramació directa.
};
