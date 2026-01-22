// src/lib/stores/calendar.ts
import { writable, derived, get } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { user } from '$lib/stores/auth';

export type CalendarView = 'month' | 'week';

export type EsdevenimentClub = {
  id: string;
  titol: string;
  descripcio: string | null;
  data_inici: string;
  data_fi: string | null;
  tipus: 'general' | 'torneig' | 'social' | 'manteniment';
  visible_per_tots: boolean;
  creat_per: string | null;
  event_id: string | null;
};

export type RepteCalendari = {
  id: string;
  reptador_nom: string;
  reptat_nom: string;
  data_programada: string;
  estat: string;
  pos_reptador: number | null;
  pos_reptat: number | null;
  observacions: string | null;
};

export type PartidaCalendari = {
  id: string;
  jugador1_nom: string;
  jugador2_nom: string;
  jugador1?: any; // Dades originals del jugador 1
  jugador2?: any; // Dades originals del jugador 2
  data_programada: string;
  hora_inici: string;
  taula_assignada: number;
  estat: string;
  event_nom: string;
  categoria_nom: string;
  observacions_junta: string | null;
};

export type CalendarEvent = {
  id: string;
  title: string;
  tableInfo?: string; // Informació de taula (B1, B2, B3, etc.)
  description?: string;
  start: Date;
  end?: Date;
  type: 'challenge' | 'event';
  subtype?: string;
  data?: EsdevenimentClub | RepteCalendari | PartidaCalendari;
};

// Store per la data actual del calendari
export const currentDate = writable(new Date());

// Store per la vista actual (mensual/setmanal)
export const calendarView = writable<CalendarView>('week');

// Store per esdeveniments del club
export const esdeveniments = writable<EsdevenimentClub[]>([]);

// Store per reptes programats
export const reptesProgramats = writable<RepteCalendari[]>([]);

// Store per partides dels campionats socials
export const partidesCalendari = writable<PartidaCalendari[]>([]);

// Store loading
export const calendarLoading = writable(false);

// Store per errors
export const calendarError = writable<string | null>(null);

// Store derivat que combina tots els esdeveniments per al calendari
export const calendarEvents = derived(
  [esdeveniments, reptesProgramats, partidesCalendari],
  ([$esdeveniments, $reptesProgramats, $partidesCalendari]) => {
    const events: CalendarEvent[] = [];
    
    // Afegir esdeveniments del club
    $esdeveniments.forEach(event => {
      events.push({
        id: `event-${event.id}`,
        title: event.titol,
        description: event.descripcio || undefined,
        start: new Date(event.data_inici),
        end: event.data_fi ? new Date(event.data_fi) : undefined,
        type: 'event',
        subtype: event.tipus,
        data: event
      });
    });
    
    // Afegir reptes programats
    $reptesProgramats.forEach(repte => {
      events.push({
        id: `challenge-${repte.id}`,
        title: `🎯 ${repte.reptador_nom} vs ${repte.reptat_nom}`,
        description: repte.observacions || undefined,
        start: new Date(repte.data_programada),
        type: 'challenge',
        subtype: repte.estat,
        data: repte
      });
    });
    
    // Afegir partides dels campionats socials
    $partidesCalendari.forEach(partida => {
      // Crear la data correctament
      const dataStr = partida.data_programada.split('T')[0]; // '2025-10-01'
      const horaStr = partida.hora_inici; // '19:00:00'

      // Extreure components i crear Date
      const [any, mes, dia] = dataStr.split('-').map(Number);
      const [hora, minut] = horaStr.split(':').map(Number);
      const dataHora = new Date(any, mes - 1, dia, hora, minut); // mes - 1 perquè Date usa 0-11
      
      if (!isNaN(dataHora.getTime())) {
        // Formatar noms utilitzant les dades originals dels jugadors (com SocialLeagueCalendarViewer)
        const formatPlayerName = (jugador: any) => {
          if (!jugador) return 'Jugador desconegut';
          
          // Si tenim nom i cognoms dels socis
          if (jugador.socis?.nom && jugador.socis?.cognoms) {
            const nom = jugador.socis.nom.trim();
            const cognoms = jugador.socis.cognoms.trim();
            
            // Obtenir primera inicial del nom
            const inicialNom = nom.charAt(0).toUpperCase();
            
            // Obtenir primer cognom (dividir per espais i agafar el primer)
            const primerCognom = cognoms.split(' ')[0];
            
            return `${inicialNom}. ${primerCognom}`;
          }
          
          // Fallback al nom del jugador si no hi ha socis
          if (jugador.nom) {
            return jugador.nom;
          }
          
          return 'Jugador desconegut';
        };
        
        const jugador1Format = formatPlayerName(partida.jugador1);
        const jugador2Format = formatPlayerName(partida.jugador2);
        
        events.push({
          id: `match-${partida.id}`,
          title: `${jugador1Format} vs ${jugador2Format}`,
          tableInfo: `B${partida.taula_assignada}`, // Informació de taula separada
          description: `${partida.event_nom} - ${partida.categoria_nom}\nTaula: ${partida.taula_assignada}${partida.observacions_junta ? `\n${partida.observacions_junta}` : ''}`,
          start: dataHora,
          type: 'challenge',
          subtype: `campionat-social-${partida.estat}`,
          data: partida
        });
        

      }
    });

    // Funció per obtenir la prioritat d'ordenació per tipus
    const getEventTypePriority = (event: CalendarEvent): number => {
      // Prioritat més baixa = apareix abans
      if (event.type === 'event') {
        // Esdeveniments del club van primer
        switch (event.subtype) {
          case 'general': return 1;     // Esdeveniments generals PRIMER
          case 'torneig': return 2;
          case 'social': return 3;
          case 'manteniment': return 4;
          default: return 5;
        }
      }
      if (event.type === 'challenge') {
        if (event.subtype?.startsWith('campionat-social')) {
          return 6; // Partides de campionats socials
        }
        return 7; // Reptes del ranking continu
      }
      return 10; // Altres esdeveniments
    };

    // Funció per extreure el número de billar (B1 -> 1, B2 -> 2, etc.)
    const getBillarNumber = (event: CalendarEvent): number => {
      if (!event.tableInfo) return 999; // Si no té taula, va al final
      const match = event.tableInfo.match(/B(\d+)/);
      return match ? parseInt(match[1]) : 999;
    };

    // Ordenar per: 1) tipus, 2) hora, 3) número de billar
    return events.sort((a, b) => {
      // 1. Primer per tipus d'esdeveniment
      const typeDiff = getEventTypePriority(a) - getEventTypePriority(b);
      if (typeDiff !== 0) {
        return typeDiff;
      }

      // 2. Després per hora
      const timeDiff = a.start.getTime() - b.start.getTime();
      if (timeDiff !== 0) {
        return timeDiff;
      }

      // 3. Finalment per número de billar
      return getBillarNumber(a) - getBillarNumber(b);
    });
  }
);

// Store derivat per obtenir esdeveniments d'un dia específic
export function getEventsForDate(date: Date): CalendarEvent[] {
  if (!date) return [];

  const allEvents = get(calendarEvents) as CalendarEvent[];
  const events = allEvents.filter(event => {
    if (!event.start) return false;

    const eventDate = new Date(event.start);
    return eventDate.toDateString() === date.toDateString();
  });

  return events;
}

// Funcions per carregar dades
export async function loadEsdeveniments(setLoading: boolean = true): Promise<void> {
  try {
    if (setLoading) {
      calendarLoading.set(true);
      calendarError.set(null);
    }

    const { data, error } = await supabase
      .from('esdeveniments_club')
      .select('*')
      .order('data_inici', { ascending: true });

    if (error) {
      throw new Error(error.message);
    }

    esdeveniments.set(data || []);
  } catch (error: any) {
    if (setLoading) {
      calendarError.set(error.message);
    }
    esdeveniments.set([]);
    throw error; // Re-throw for Promise.allSettled
  } finally {
    if (setLoading) {
      calendarLoading.set(false);
    }
  }
}

export async function loadReptesProgramats(setLoading: boolean = true): Promise<void> {
  try {
    if (setLoading) {
      calendarLoading.set(true);
      calendarError.set(null);
    }

    const { data, error } = await supabase
      .from('challenges')
      .select(`
        id,
        data_programada,
        estat,
        pos_reptador,
        pos_reptat,
        observacions,
        reptador:reptador_id(nom),
        reptat:reptat_id(nom)
      `)
      .not('data_programada', 'is', null)
      .order('data_programada', { ascending: true });

    if (error) {
      throw new Error(error.message);
    }

    const reptes: RepteCalendari[] = (data || []).map(item => ({
      id: item.id,
      reptador_nom: (item.reptador as any)?.nom || 'Desconegut',
      reptat_nom: (item.reptat as any)?.nom || 'Desconegut',
      data_programada: item.data_programada,
      estat: item.estat,
      pos_reptador: item.pos_reptador,
      pos_reptat: item.pos_reptat,
      observacions: item.observacions
    }));

    reptesProgramats.set(reptes);
  } catch (error: any) {
    if (setLoading) {
      calendarError.set(error.message);
    }
    reptesProgramats.set([]);
    throw error; // Re-throw for Promise.allSettled
  } finally {
    if (setLoading) {
      calendarLoading.set(false);
    }
  }
}

export async function loadPartidesCalendari(setLoading: boolean = true): Promise<void> {
  try {
    if (setLoading) {
      calendarLoading.set(true);
      calendarError.set(null);
    }

    // Check if user is authenticated
    const currentUser = get(user);
    const isAuthenticated = !!currentUser;
    
    console.log('👤 Loading calendar data - User authenticated:', isAuthenticated);

    // Get published events first
    const { data: publishedEvents, error: eventsError } = await supabase
      .from('events')
      .select('id')
      .eq('calendari_publicat', true);

    if (eventsError) {
      console.error('❌ Error getting published events:', eventsError);
      throw new Error(`Error getting published events: ${eventsError.message}`);
    }

    console.log('📋 Published events found:', publishedEvents?.length || 0);

    if (!publishedEvents || publishedEvents.length === 0) {
      console.log('⚠️ No published events found, calendar will be empty');
      partidesCalendari.set([]);
      return;
    }

    const eventIds = publishedEvents.map(e => e.id);
    console.log('🎯 Looking for matches in events:', eventIds);

    // Query matches with proper relations
    // Only show matches that haven't been played yet (caramboles_jugador1 is null)
    const { data, error } = await supabase
      .from('calendari_partides')
      .select(`
        id,
        data_programada,
        hora_inici,
        taula_assignada,
        estat,
        observacions_junta,
        event_id,
        categoria_id,
        jugador1_id,
        jugador2_id,
        jugador1:jugador1_id(
          id,
          nom,
          socis(nom, cognoms)
        ),
        jugador2:jugador2_id(
          id,
          nom,
          socis(nom, cognoms)
        ),
        events(id, nom),
        categories(id, nom)
      `)
      .eq('estat', 'validat')
      .in('event_id', eventIds)
      .not('data_programada', 'is', null)
      .not('hora_inici', 'is', null)
      .is('caramboles_jugador1', null)  // Només partides sense resultats
      .order('data_programada', { ascending: true });

    if (error) {
      console.error('❌ Supabase query error:', error);
      
      // Check if error is related to RLS permissions
      if (error.code === '42501' || error.message.includes('insufficient_privilege') || error.message.includes('permission denied')) {
        console.warn('⚠️ No access to calendar matches (user not authenticated). This is expected for public users.');
        console.log('💡 Calendar will show only events, not specific matches until user logs in.');
        
        // Set a user-friendly error message for non-authenticated users
        if (!isAuthenticated) {
          calendarError.set('Per veure les partides programades, cal iniciar sessió.');
        }
        
        partidesCalendari.set([]);
        return;
      }
      
      throw new Error(`Error getting partides: ${error.message} (Code: ${error.code})`);
    }

    console.log('🏆 Raw matches data received:', data?.length || 0);

    if (!data || data.length === 0) {
      if (!isAuthenticated) {
        console.log('ℹ️ No matches visible to anonymous users due to RLS policies');
        calendarError.set('No hi ha partides públiques disponibles. Inicia sessió per veure el calendari complet.');
      } else {
        console.log('⚠️ No validated matches found for published events');
      }
      partidesCalendari.set([]);
      return;
    }

    // Create partides with proper player data
    const partides: PartidaCalendari[] = data.map(item => {
      return {
        id: item.id,
        jugador1_nom: (item.jugador1 as any)?.socis ?
          `${(item.jugador1 as any).socis.nom} ${(item.jugador1 as any).socis.cognoms}` :
          ((item.jugador1 as any)?.nom || 'Desconegut'),
        jugador2_nom: (item.jugador2 as any)?.socis ?
          `${(item.jugador2 as any).socis.nom} ${(item.jugador2 as any).socis.cognoms}` :
          ((item.jugador2 as any)?.nom || 'Desconegut'),
        // Add original player data for proper formatting
        jugador1: item.jugador1,
        jugador2: item.jugador2,
        data_programada: item.data_programada,
        hora_inici: item.hora_inici,
        taula_assignada: item.taula_assignada,
        estat: item.estat,
        event_nom: (item.events as any)?.nom || 'Campionat',
        categoria_nom: (item.categories as any)?.nom || 'Categoria',
        observacions_junta: item.observacions_junta
      };
    });

    console.log('✅ Successfully processed matches:', partides.length);
    partidesCalendari.set(partides);
  } catch (error: any) {
    console.error('❌ Error in loadPartidesCalendari:', error);
    if (setLoading) {
      calendarError.set(error.message);
    }
    partidesCalendari.set([]);
    throw error; // Re-throw for Promise.allSettled
  } finally {
    if (setLoading) {
      calendarLoading.set(false);
    }
  }
}

export async function deleteEsdeveniment(id: string): Promise<void> {
  try {
    calendarLoading.set(true);
    calendarError.set(null);
    
    const { error } = await supabase
      .from('esdeveniments_club')
      .delete()
      .eq('id', id);
    
    if (error) {
      throw new Error(error.message);
    }
    
    // Actualitzar els stores eliminant l'esdeveniment
    esdeveniments.update((events: EsdevenimentClub[]) => events.filter((event: EsdevenimentClub) => event.id !== id));
    
  } catch (error: any) {
    calendarError.set(error.message);
    throw error;
  } finally {
    calendarLoading.set(false);
  }
}

export async function refreshCalendarData(): Promise<void> {
  try {
    calendarLoading.set(true);
    calendarError.set(null);

    console.log('🔄 Refreshing calendar data...');

    // Load all data in parallel, passing false to prevent individual loading states
    const results = await Promise.allSettled([
      loadEsdeveniments(false),
      loadReptesProgramats(false),
      loadPartidesCalendari(false)
    ]);

    // Check for errors
    const errors = results
      .filter(r => r.status === 'rejected')
      .map(r => (r as PromiseRejectedResult).reason);

    if (errors.length > 0) {
      console.error('❌ Errors refreshing calendar data:', errors);
      // Set error but don't throw - partial data is better than nothing
      calendarError.set(`Error carregant algunes dades: ${errors.map(e => e.message).join(', ')}`);
    } else {
      console.log('✅ All calendar data refreshed successfully');
    }
  } catch (error: any) {
    console.error('❌ Unexpected error in refreshCalendarData:', error);
    calendarError.set(error.message);
  } finally {
    calendarLoading.set(false);
  }
}

// Funcions d'utilitat per dates
export function navigateToDate(date: Date): void {
  currentDate.set(new Date(date));
}

export function navigateToToday(): void {
  currentDate.set(new Date());
}

export function navigateMonth(direction: 1 | -1): void {
  currentDate.update((date: Date) => {
    const newDate = new Date(date);
    newDate.setMonth(newDate.getMonth() + direction);
    return newDate;
  });
}

export function navigateWeek(direction: 1 | -1): void {
  currentDate.update((date: Date) => {
    const newDate = new Date(date);
    newDate.setDate(newDate.getDate() + (direction * 7));
    return newDate;
  });
}

export function setCalendarView(view: CalendarView): void {
  calendarView.set(view);
}