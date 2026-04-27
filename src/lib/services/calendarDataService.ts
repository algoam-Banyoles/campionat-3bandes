/**
 * Servei de càrrega de dades del calendari de campionats socials.
 *
 * Encapsula la lògica complexa que abans vivia a `loadCalendarData()`
 * dins el component `SocialLeagueCalendarViewer.svelte`. Carrega:
 *  - configuració del calendari (només admin)
 *  - partides programades via RPC pública
 *  - partides no programades (només per usuaris autenticats; respecta RLS)
 *  - exclusió de jugadors retirats/desqualificats a les partides pendents
 *  - lookup de noms reals i categories per a les partides no programades
 *  - merge amb la llista de categories
 *
 * Retorna un objecte amb tota la informació necessària. Els errors fatals
 * es propaguen com a excepció; els errors no fatals es loguen i es
 * continua amb dades parcials.
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import type { CalendarConfig } from './calendarTimelineService';

export interface CalendarDataResult {
  config: CalendarConfig | null;
  matches: any[];
  finalCategories: any[];
}

export interface MyPlayerData {
  id: number;
  numero_soci: number;
  nom: string;
  email: string | null;
}

/**
 * Carrega les dades del soci a partir del seu email. S'usa per a saber
 * quin jugador és l'usuari actual i activar filtres "les meves partides".
 * Retorna `null` si no es troba cap soci amb aquest email.
 */
export async function loadSociByEmail(
  supabase: SupabaseClient,
  email: string
): Promise<MyPlayerData | null> {
  const { data, error } = await supabase
    .from('socis')
    .select('numero_soci, nom, cognoms, email')
    .eq('email', email)
    .maybeSingle();

  if (error || !data) return null;

  return {
    id: data.numero_soci,
    numero_soci: data.numero_soci,
    nom: `${data.nom ?? ''} ${data.cognoms ?? ''}`.trim(),
    email: data.email
  };
}

export async function loadCalendarData(
  supabase: SupabaseClient,
  options: {
    eventId: string;
    isAdmin: boolean;
    /** Categories ja conegudes pel pare. Si està buit, es carreguen via RPC. */
    categories: any[];
  }
): Promise<CalendarDataResult> {
  const { eventId, isAdmin, categories } = options;

  if (!eventId) {
    return { config: null, matches: [], finalCategories: categories };
  }

  let config: CalendarConfig | null = null;
  const categoriesMap = new Map<string, string>();
  const playersMap = new Map<number, { nom: string; cognoms: string }>();

  // 1. Configuració del calendari (admin)
  if (isAdmin) {
    try {
      const { data, error } = await supabase
        .from('configuracio_calendari')
        .select('*')
        .eq('event_id', eventId)
        .single();

      if (data) {
        config = data as CalendarConfig;
      }
      if (error && error.code !== 'PGRST116') {
        console.warn('Error loading calendar config:', error);
      }
    } catch (e) {
      console.warn('Could not load calendar config - insufficient permissions:', e);
    }
  }

  // 2. Partides programades (RPC pública)
  const { data: matchDataRaw, error: matchError } = await supabase.rpc(
    'get_calendar_matches_public',
    { p_event_id: eventId }
  );
  if (matchError) {
    console.error('Error loading calendar with RPC:', matchError);
    throw matchError;
  }

  // 3. Partides no programades (només autenticats)
  let unprogrammedRaw: any[] = [];
  const withdrawnSocis = new Set<number>();

  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (user) {
    try {
      // Jugadors retirats per a excloure
      const { data: inscriptionsData, error: inscriptionsError } = await supabase.rpc(
        'get_inscripcions_with_socis',
        { p_event_id: eventId }
      );
      if (!inscriptionsError && Array.isArray(inscriptionsData)) {
        for (const item of inscriptionsData as any[]) {
          if (
            (item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences) &&
            typeof item.soci_numero === 'number'
          ) {
            withdrawnSocis.add(item.soci_numero);
          }
        }
      }

      // Partides pendents
      const { data, error } = await supabase
        .from('calendari_partides')
        .select('*')
        .eq('event_id', eventId)
        .eq('estat', 'pendent_programar')
        .is('caramboles_jugador1', null)
        .is('caramboles_jugador2', null)
        .is('data_programada', null);

      if (error) {
        console.warn('Could not load unprogrammed matches:', error);
      } else if (data) {
        unprogrammedRaw = data;
      }

      // Lookup noms i categories per a partides no programades
      if (unprogrammedRaw.length > 0) {
        // Filtrar retirats
        if (withdrawnSocis.size > 0) {
          unprogrammedRaw = unprogrammedRaw.filter(
            (m: any) =>
              !withdrawnSocis.has(m.jugador1_soci_numero ?? -1) &&
              !withdrawnSocis.has(m.jugador2_soci_numero ?? -1)
          );
        }

        const sociNumbers = Array.from(
          new Set(
            [
              ...unprogrammedRaw.map((m: any) => m.jugador1_soci_numero),
              ...unprogrammedRaw.map((m: any) => m.jugador2_soci_numero)
            ].filter((n: any) => typeof n === 'number')
          )
        ) as number[];

        if (sociNumbers.length > 0) {
          const { data: socisData } = await supabase
            .from('socis')
            .select('numero_soci, nom, cognoms')
            .in('numero_soci', sociNumbers);
          if (socisData) {
            for (const soci of socisData as any[]) {
              const inicialNom = soci.nom ? soci.nom.trim().charAt(0).toUpperCase() : '';
              const primerCognom = soci.cognoms ? soci.cognoms.trim().split(' ')[0] : '';
              playersMap.set(soci.numero_soci, { nom: inicialNom, cognoms: primerCognom });
            }
          }
        }

        const categoriaIds = Array.from(
          new Set(unprogrammedRaw.map((m: any) => m.categoria_id).filter(Boolean))
        ) as string[];
        if (categoriaIds.length > 0) {
          const { data: categoriesData } = await supabase
            .from('categories')
            .select('id, nom')
            .in('id', categoriaIds);
          if (categoriesData) {
            for (const c of categoriesData as any[]) {
              categoriesMap.set(c.id, c.nom);
            }
          }
        }
      }
    } catch (err) {
      console.warn('Error loading unprogrammed matches for authenticated user:', err);
    }
  }

  // 4. Transformar partides RPC a format esperat
  const matchData = (matchDataRaw || []).map((match: any) => ({
    id: match.id,
    categoria_id: match.categoria_id,
    data_programada: match.data_programada,
    hora_inici: match.hora_inici,
    jugador1_soci_numero: match.jugador1_numero_soci,
    jugador2_soci_numero: match.jugador2_numero_soci,
    estat: match.estat,
    taula_assignada: match.taula_assignada,
    observacions_junta: match.observacions_junta,
    jugador1: {
      numero_soci: match.jugador1_numero_soci,
      socis: { nom: match.jugador1_nom, cognoms: match.jugador1_cognoms }
    },
    jugador2: {
      numero_soci: match.jugador2_numero_soci,
      socis: { nom: match.jugador2_nom, cognoms: match.jugador2_cognoms }
    }
  }));

  // 5. Transformar partides no programades
  const unprogrammedData = unprogrammedRaw.map((match: any) => ({
    id: match.id,
    categoria_id: match.categoria_id,
    categoria_nom: categoriesMap.get(match.categoria_id) || '',
    data_programada: match.data_programada,
    hora_inici: match.hora_inici,
    jugador1_soci_numero: match.jugador1_soci_numero,
    jugador2_soci_numero: match.jugador2_soci_numero,
    estat: match.estat,
    taula_assignada: match.taula_assignada,
    observacions_junta: match.observacions_junta,
    jugador1: playersMap.get(match.jugador1_soci_numero) || {
      nom: 'J.',
      cognoms: '(No programat)'
    },
    jugador2: playersMap.get(match.jugador2_soci_numero) || {
      nom: 'J.',
      cognoms: '(No programat)'
    }
  }));

  const allMatchData = [...matchData, ...unprogrammedData];

  // 6. Carregar categories si no en venen del pare
  let finalCategories = categories;
  if (finalCategories.length === 0) {
    const { data, error } = await supabase.rpc('get_categories_for_event', {
      p_event_id: eventId
    });
    if (!error && data) {
      finalCategories = data;
    } else if (error) {
      console.error('Error loading categories for calendar:', error);
    }
  }

  // 7. Merge matches + categories
  const matches = allMatchData.map((m: any) => {
    const category = finalCategories.find((c: any) => c.id === m.categoria_id);
    return { ...m, categoria: category || null };
  });

  return { config, matches, finalCategories };
}
