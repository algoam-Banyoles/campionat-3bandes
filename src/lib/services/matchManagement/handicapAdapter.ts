/**
 * Adaptador hàndicap per a la gestió unificada de partides.
 *
 * Llegeix handicap_matches de l'event hàndicap actiu i despatxa:
 * - enterResult → saveMatchResult de handicap-propagation
 * - schedule    → scheduleHandicapMatch de handicap-manual-schedule
 * - unschedule  → unscheduleHandicapMatch de handicap-manual-schedule
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import { formatarNomJugadorParts } from '$lib/utils/playerUtils';
import { saveMatchResult } from '$lib/utils/handicap-propagation';
import {
  scheduleHandicapMatch,
  unscheduleHandicapMatch
} from '$lib/utils/handicap-manual-schedule';
import { buildMatchCodeMap, buildSlotSourceMap } from '$lib/utils/handicap-types';
import type {
  MatchAdapter,
  UnifiedMatch,
  UnifiedPlayer,
  UnifiedStatus,
  HandicapMeta,
  ResultInput,
  EnterResultResponse
} from './types';

// ── Helpers ────────────────────────────────────────────────────────────────

function mapEstat(estat: string): UnifiedStatus {
  if (estat === 'jugada' || estat === 'walkover') return 'jugada';
  if (estat === 'pendent') return 'pendent';
  if (estat === 'programada') return 'programada';
  return 'altres';
}

function buildPlayer(
  sociNumero: number | null,
  nom: string | null,
  cognoms: string | null,
  fallback: string
): UnifiedPlayer {
  const raw = `${nom ?? ''} ${cognoms ?? ''}`.trim();
  return {
    displayName: raw ? formatarNomJugadorParts(nom, cognoms) : fallback,
    rawName: raw || fallback,
    sociNumero
  };
}

// ── Adaptador ──────────────────────────────────────────────────────────────

export const handicapAdapter: MatchAdapter = {
  async listMatches(supabase: SupabaseClient, includeJugades = false): Promise<UnifiedMatch[]> {
    // 1. Trobar l'event hàndicap actiu
    const { data: ev, error: evErr } = await supabase
      .from('events')
      .select('id, nom')
      .eq('tipus_competicio', 'handicap')
      .eq('actiu', true)
      .limit(1)
      .maybeSingle();

    if (evErr) throw new Error(`Error carregant event hàndicap: ${evErr.message}`);
    if (!ev) return [];

    const eventId = (ev as any).id as string;
    const eventNom = (ev as any).nom as string ?? '';

    // 2. Configuració del torneig (sistema_puntuacio, limit_entrades)
    const { data: cfg } = await supabase
      .from('handicap_config')
      .select('sistema_puntuacio, limit_entrades')
      .eq('event_id', eventId)
      .maybeSingle();

    const sistemaPuntuacio = (cfg as any)?.sistema_puntuacio as string ?? 'distancia';
    const limitEntrades = (cfg as any)?.limit_entrades as number | null ?? null;

    // 3. Partides (estat pendent/programada; opcionalment jugada/walkover)
    const estats = ['pendent', 'programada'];
    if (includeJugades) {
      estats.push('jugada', 'walkover');
    }

    const { data: rawMatches, error: mErr } = await supabase
      .from('handicap_matches')
      .select(
        'id, estat, distancia_jugador1, distancia_jugador2, calendari_partida_id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id'
      )
      .eq('event_id', eventId)
      .in('estat', estats);

    if (mErr) throw new Error(`Error carregant partides hàndicap: ${mErr.message}`);
    if (!rawMatches || rawMatches.length === 0) return [];

    // 4. Slots de bracket
    const slotIds = (rawMatches as any[]).flatMap((m) => [m.slot1_id, m.slot2_id]);
    const { data: slots } = await supabase
      .from('handicap_bracket_slots')
      .select('id, bracket_type, ronda, posicio, is_bye, participant_id')
      .in('id', slotIds);

    const slotMap = new Map(((slots ?? []) as any[]).map((s) => [s.id as string, s]));

    // 5. Participants
    const participantIds = Array.from(
      new Set(
        ((slots ?? []) as any[])
          .filter((s) => s.participant_id)
          .map((s) => s.participant_id as string)
      )
    );

    let partMap = new Map<string, any>();
    if (participantIds.length > 0) {
      const { data: parts } = await supabase
        .from('handicap_participants')
        .select(
          'id, distancia, seed, soci_numero, socis!handicap_participants_soci_numero_fkey(nom, cognoms)'
        )
        .in('id', participantIds);

      partMap = new Map(((parts ?? []) as any[]).map((p) => [p.id as string, p]));
    }

    // 6. Slots de calendari_partides (per date/hora/taula de les partides programades)
    const scheduledIds = (rawMatches as any[])
      .filter((m) => m.calendari_partida_id)
      .map((m) => m.calendari_partida_id as string);

    let partidaMap = new Map<string, any>();
    if (scheduledIds.length > 0) {
      const { data: partides } = await supabase
        .from('calendari_partides')
        .select('id, data_programada, hora_inici, taula_assignada, jugador1_soci_numero, jugador2_soci_numero')
        .in('id', scheduledIds);
      partidaMap = new Map(((partides ?? []) as any[]).map((p) => [p.id as string, p]));
    }

    // 7. Construir codeMap per als matchCodes (mateix patró que la pàgina de partides)
    const codeInputs = (rawMatches as any[]).map((m) => {
      const s1 = slotMap.get(m.slot1_id);
      return {
        id: m.id as string,
        bracket_type: (s1?.bracket_type ?? 'winners') as string,
        ronda: (s1?.ronda ?? 1) as number,
        matchPos: s1 ? Math.ceil((s1.posicio as number) / 2) : 0
      };
    });
    const codeMap = buildMatchCodeMap(codeInputs);
    const slotSourceMap = buildSlotSourceMap(rawMatches as any[], codeMap);

    // 8. Construir UnifiedMatch[]
    const matches: UnifiedMatch[] = (rawMatches as any[])
      .filter((m) => {
        // Excloure byes — la pàgina de partides fa el mateix
        const s1 = slotMap.get(m.slot1_id);
        return s1?.is_bye !== true;
      })
      .map((m) => {
        const slot1 = slotMap.get(m.slot1_id) as any | undefined;
        const slot2 = slotMap.get(m.slot2_id) as any | undefined;
        const p1 = slot1?.participant_id ? partMap.get(slot1.participant_id as string) : null;
        const p2 = slot2?.participant_id ? partMap.get(slot2.participant_id as string) : null;
        const partida = m.calendari_partida_id ? partidaMap.get(m.calendari_partida_id as string) : null;
        const matchPos = slot1 ? Math.ceil((slot1.posicio as number) / 2) : 0;
        const matchCode = codeMap.get(m.id as string) ?? '';

        // Noms dels jugadors (mirall exacte de la pàgina de partides)
        const getName = (p: any | null, slotId: string) => {
          if (p) {
            const r = p.socis;
            const s = Array.isArray(r) ? r[0] : r;
            if (s) return formatarNomJugadorParts(s.nom, s.cognoms) || '?';
          }
          const src = slotSourceMap.get(slotId);
          return src ? `${src.role} ${src.code}` : 'Per determinar';
        };

        const p1Name = getName(p1, m.slot1_id as string);
        const p2Name = getName(p2, m.slot2_id as string);

        const getSociNom = (p: any | null): { nom: string | null; cognoms: string | null } => {
          if (!p) return { nom: null, cognoms: null };
          const r = p.socis;
          const s = Array.isArray(r) ? r[0] : r;
          return { nom: s?.nom ?? null, cognoms: s?.cognoms ?? null };
        };

        const s1Data = getSociNom(p1);
        const s2Data = getSociNom(p2);

        const player1: UnifiedPlayer = {
          displayName: p1Name,
          rawName: `${s1Data.nom ?? ''} ${s1Data.cognoms ?? ''}`.trim() || p1Name,
          sociNumero: p1?.soci_numero ?? null
        };
        const player2: UnifiedPlayer = {
          displayName: p2Name,
          rawName: `${s2Data.nom ?? ''} ${s2Data.cognoms ?? ''}`.trim() || p2Name,
          sociNumero: p2?.soci_numero ?? null
        };

        let slot = null;
        if (partida?.data_programada && partida?.hora_inici) {
          slot = {
            dataIso: (partida.data_programada as string).substring(0, 10),
            hora: (partida.hora_inici as string).substring(0, 5),
            billar: partida.taula_assignada as number | null
          };
        }

        const status = mapEstat(m.estat as string);
        const bothResolved = !!(slot1?.participant_id && slot2?.participant_id);

        const meta: HandicapMeta = {
          source: 'handicap',
          eventId,
          eventNom,
          bracketType: (slot1?.bracket_type ?? 'winners') as HandicapMeta['bracketType'],
          ronda: (slot1?.ronda ?? 1) as number,
          matchPos,
          matchCode,
          calendariPartidaId: m.calendari_partida_id ?? null,
          player1ParticipantId: slot1?.participant_id ?? null,
          player2ParticipantId: slot2?.participant_id ?? null,
          player1Distancia: p1?.distancia ?? (m.distancia_jugador1 as number | null) ?? null,
          player2Distancia: p2?.distancia ?? (m.distancia_jugador2 as number | null) ?? null,
          sistemaPuntuacio,
          limitEntrades
        };

        // Capabilities: no podem entrar resultat si un jugador no és determinat
        const canEnterResult = status === 'programada' && bothResolved;
        const canSchedule = status === 'pendent' || status === 'programada';
        const canUnschedule = !!(m.calendari_partida_id);

        return {
          source: 'handicap' as const,
          id: m.id as string,
          player1,
          player2,
          slot,
          status,
          rawEstat: m.estat as string,
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
    if (input.kind !== 'handicap') {
      throw new Error(`Tipus de resultat no vàlid per al hàndicap: ${(input as any).kind}`);
    }

    const meta = match.meta as HandicapMeta;
    if (!meta.player1ParticipantId || !meta.player2ParticipantId) {
      throw new Error('Ambdós jugadors han d\'estar determinats per enregistrar el resultat.');
    }

    const result = await saveMatchResult(supabase, {
      matchId: match.id,
      isWalkover: input.isWalkover,
      caramboles1: input.caramboles1,
      caramboles2: input.caramboles2,
      entrades: input.entrades,
      winnerParticipantId: input.winnerParticipantId,
      loserParticipantId: input.loserParticipantId,
      calendariPartidaId: meta.calendariPartidaId
    });

    if (!result.ok) {
      throw new Error((result as import('$lib/utils/handicap-propagation').SaveResultError).error);
    }

    const ok = result as import('$lib/utils/handicap-propagation').SaveResultResponse;

    // Construir missatge descriptiu en català
    const winnerName =
      input.winnerParticipantId === meta.player1ParticipantId
        ? match.player1.displayName
        : match.player2.displayName;

    let message: string;
    if (ok.isChampion) {
      message = `${winnerName} és el CAMPIÓ del torneig! El torneig s'ha tancat.`;
    } else if (ok.needsResetMatch) {
      message = `${winnerName} guanya la Gran Final! Cal jugar el Reset Match (GF-R2) — ambdós jugadors estan assignats a la nova partida.`;
    } else {
      message = `Resultat registrat. ${winnerName} guanya i avança a ${ok.winnerDestDesc}.`;
      if (ok.newSchedulableCount > 0) {
        message += ` ${ok.newSchedulableCount} nova${ok.newSchedulableCount !== 1 ? 'es' : ''} partida${ok.newSchedulableCount !== 1 ? 'des' : ''} llesta${ok.newSchedulableCount !== 1 ? 'es' : ''} per programar.`;
      }
    }

    return { message };
  },

  async schedule(
    supabase: SupabaseClient,
    match: UnifiedMatch,
    slot: import('./types').UnifiedSlot
  ): Promise<void> {
    if (!slot.billar) {
      throw new Error('Cal especificar el billar per a les partides hàndicap.');
    }

    const meta = match.meta as HandicapMeta;
    const bothResolved = !!(meta.player1ParticipantId && meta.player2ParticipantId);

    await scheduleHandicapMatch(supabase, {
      eventId: meta.eventId,
      matchId: match.id,
      calendariPartidaId: meta.calendariPartidaId,
      player1SociNumero: match.player1.sociNumero,
      player2SociNumero: match.player2.sociNumero,
      bothResolved,
      slot: { data: slot.dataIso, hora: slot.hora, taula: slot.billar }
    });
  },

  async unschedule(supabase: SupabaseClient, match: UnifiedMatch): Promise<void> {
    const meta = match.meta as HandicapMeta;
    if (!meta.calendariPartidaId) {
      throw new Error('La partida no té cap slot assignat per desassignar.');
    }

    await unscheduleHandicapMatch(supabase, {
      matchId: match.id,
      calendariPartidaId: meta.calendariPartidaId
    });
  }
};
