/**
 * Adaptador social per a la gestió unificada de partides.
 *
 * Llegeix calendari_partides dels events lliga_social actius i despatxa les
 * escriptures a calendarMutationsService (saveMatchResult, registerNoShow,
 * saveMatchEdit, markAsUnprogrammed).
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import { formatarNomJugadorParts } from '$lib/utils/playerUtils';
import {
  saveMatchResult,
  registerNoShow,
  saveMatchEdit,
  markAsUnprogrammed
} from '$lib/services/calendarMutationsService';
import type {
  MatchAdapter,
  UnifiedMatch,
  UnifiedPlayer,
  UnifiedStatus,
  SocialMeta,
  ResultInput,
  EnterResultResponse
} from './types';

// ── Helpers ────────────────────────────────────────────────────────────────

function mapEstat(estat: string): UnifiedStatus {
  if (estat === 'jugada') return 'jugada';
  if (estat === 'pendent_programar') return 'pendent';
  if (estat === 'generat' || estat === 'publicat' || estat === 'validat') return 'programada';
  return 'altres';
}

function buildPlayer(
  sociNumero: number | null,
  nom: string | null,
  cognoms: string | null
): UnifiedPlayer {
  const raw = `${nom ?? ''} ${cognoms ?? ''}`.trim();
  return {
    displayName: raw ? formatarNomJugadorParts(nom, cognoms) : '?',
    rawName: raw || '?',
    sociNumero
  };
}

// ── Adaptador ──────────────────────────────────────────────────────────────

export const socialAdapter: MatchAdapter = {
  async listMatches(supabase: SupabaseClient, includeJugades = false): Promise<UnifiedMatch[]> {
    // 1. Obtenir events lliga_social actius
    const { data: events, error: evErr } = await supabase
      .from('events')
      .select('id, nom')
      .eq('tipus_competicio', 'lliga_social')
      .eq('actiu', true);

    if (evErr) throw new Error(`Error carregant events socials: ${evErr.message}`);
    if (!events || events.length === 0) return [];

    const eventsArr = events as Array<{ id: string; nom: string }>;
    const evMap = new Map(eventsArr.map((e) => [e.id, e.nom]));
    const eventIds = eventsArr.map((e) => e.id);

    // 2. Carregar categories
    const { data: cats, error: catErr } = await supabase
      .from('categories')
      .select('id, event_id, nom, distancia_caramboles')
      .in('event_id', eventIds);

    if (catErr) throw new Error(`Error carregant categories: ${catErr.message}`);
    const catMap = new Map(
      (cats ?? []).map((c: any) => [
        c.id as string,
        { nom: c.nom as string, distancia_caramboles: c.distancia_caramboles as number | null, event_id: c.event_id as string }
      ])
    );

    // 3. Carregar partides (filtrades per estat si no es volen les jugades)
    let query = supabase
      .from('calendari_partides')
      .select(
        'id, event_id, categoria_id, estat, data_programada, hora_inici, taula_assignada, jugador1_soci_numero, jugador2_soci_numero, observacions_junta, partida_anullada'
      )
      .in('event_id', eventIds)
      .or('partida_anullada.is.null,partida_anullada.eq.false');

    if (!includeJugades) {
      query = (supabase
        .from('calendari_partides')
        .select(
          'id, event_id, categoria_id, estat, data_programada, hora_inici, taula_assignada, jugador1_soci_numero, jugador2_soci_numero, observacions_junta, partida_anullada'
        )
        .in('event_id', eventIds)
        .or('partida_anullada.is.null,partida_anullada.eq.false')
        .not('estat', 'in', '("jugada","cancel·lada_per_retirada")')) as typeof query;
    }

    const { data: partides, error: pErr } = await query;
    if (pErr) throw new Error(`Error carregant partides socials: ${pErr.message}`);
    if (!partides || partides.length === 0) return [];

    // 4. Obtenir noms de socis (per jugador1 i jugador2)
    const sociNumeros = Array.from(
      new Set(
        (partides as any[]).flatMap((p) => [p.jugador1_soci_numero, p.jugador2_soci_numero]).filter(Boolean)
      )
    ) as number[];

    let sociMap = new Map<number, { nom: string | null; cognoms: string | null }>();
    if (sociNumeros.length > 0) {
      const { data: socis } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .in('numero_soci', sociNumeros);
      for (const s of (socis ?? []) as any[]) {
        sociMap.set(s.numero_soci as number, { nom: s.nom, cognoms: s.cognoms });
      }
    }

    // 5. Construir UnifiedMatch[]
    const matches: UnifiedMatch[] = (partides as any[]).map((p) => {
      const soci1 = sociMap.get(p.jugador1_soci_numero) ?? { nom: null, cognoms: null };
      const soci2 = sociMap.get(p.jugador2_soci_numero) ?? { nom: null, cognoms: null };
      const cat = catMap.get(p.categoria_id as string);
      const eventNom = evMap.get(p.event_id as string) ?? '';
      const status = mapEstat(p.estat as string);

      // Data i hora de programació
      let slot = null;
      if (p.data_programada && p.hora_inici) {
        slot = {
          dataIso: (p.data_programada as string).substring(0, 10),
          hora: (p.hora_inici as string).substring(0, 5),
          billar: p.taula_assignada as number | null
        };
      }

      const meta: SocialMeta = {
        source: 'social',
        eventId: p.event_id as string,
        eventNom,
        categoriaId: p.categoria_id as string,
        categoriaNom: cat?.nom ?? '',
        distanciaCaramboles: cat?.distancia_caramboles ?? null
      };

      const canEnterResult = status === 'programada';
      const canSchedule = status === 'pendent' || status === 'programada';
      const canUnschedule = status === 'programada';

      return {
        source: 'social' as const,
        id: p.id as string,
        player1: buildPlayer(p.jugador1_soci_numero, soci1.nom, soci1.cognoms),
        player2: buildPlayer(p.jugador2_soci_numero, soci2.nom, soci2.cognoms),
        slot,
        status,
        rawEstat: p.estat as string,
        capabilities: { canEnterResult, canSchedule, canUnschedule },
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
    if (input.kind === 'social') {
      await saveMatchResult(supabase, match.id, {
        caramboles_jugador1: input.caramboles_jugador1,
        caramboles_jugador2: input.caramboles_jugador2,
        entrades: input.entrades,
        observacions: input.observacions
      });
      return {
        message: `Resultat registrat: ${input.caramboles_jugador1}–${input.caramboles_jugador2} en ${input.entrades} entrades.`
      };
    }

    if (input.kind === 'social-noshow') {
      const res = await registerNoShow(supabase, match.id, input.absentPlayer);
      const player = input.absentPlayer === 1 ? match.player1.displayName : match.player2.displayName;
      const elim = res.jugador_eliminat ? ' El jugador ha quedat eliminat.' : '';
      return {
        message: `Incompareixença registrada per ${player} (${res.incompareixences} total).${elim}`
      };
    }

    throw new Error(`Tipus de resultat no vàlid per a partides socials: ${(input as any).kind}`);
  },

  async schedule(
    supabase: SupabaseClient,
    match: UnifiedMatch,
    slot: import('./types').UnifiedSlot
  ): Promise<void> {
    if (!slot.billar) {
      throw new Error('Cal especificar el billar per a les partides socials.');
    }
    // Si la partida era pendent_programar → canviar a 'validat'; altrament mantenim l'estat actual
    const nouEstat = match.rawEstat === 'pendent_programar' ? 'validat' : match.rawEstat;
    await saveMatchEdit(supabase, match.id, {
      data_programada: slot.dataIso,
      hora_inici: slot.hora,
      taula_assignada: slot.billar,
      estat: nouEstat,
      observacions_junta: ''
    });
  },

  async unschedule(supabase: SupabaseClient, match: UnifiedMatch): Promise<void> {
    await markAsUnprogrammed(supabase, { id: match.id, observacions_junta: null });
  }
};
