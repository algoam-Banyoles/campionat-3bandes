<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { exportCalendariToCSV } from '$lib/api/socialLeagues';
  import PendingMatchesModal from './PendingMatchesModal.svelte';
  import OldMatchesModal from './OldMatchesModal.svelte';
  import CalendarMatchEditModal from './CalendarMatchEditModal.svelte';
  import CalendarMatchResultModal from './CalendarMatchResultModal.svelte';
  import CalendarIncompareixencaModal from './CalendarIncompareixencaModal.svelte';
  import CalendarTimelineView from './CalendarTimelineView.svelte';
  import CalendarCategoryView from './CalendarCategoryView.svelte';
  import CalendarUnprogrammedMatches from './CalendarUnprogrammedMatches.svelte';
  import {
    toLocalDateStr,
    getDayOfWeekCode,
    formatDate,
    generateAvailableDates as svcGenerateAvailableDates,
    generateTimelineData as svcGenerateTimelineData,
    groupByCategory as svcGroupByCategory,
    groupTimelineByDayAndHour as svcGroupTimelineByDayAndHour
  } from '$lib/services/calendarTimelineService';
  import {
    formatPlayerName,
    matchPlayerById,
    matchPlayerSearchText,
    generatePlayerSuggestions as svcGeneratePlayerSuggestions
  } from '$lib/services/calendarPlayerSearchService';
  import {
    generatePrintHTML as svcGeneratePrintHTML,
    type PrintContext
  } from '$lib/services/calendarPrintService';

  const dispatch = createEventDispatcher();

  export let eventId: string = '';
  export let categories: any[] = [];
  export let isAdmin: boolean = false;
  export let eventData: any = null;
  export let defaultMode: 'category' | 'timeline' = 'timeline';
  export const editMode: boolean = false;

  // Funció per imprimir només la taula cronològica
  function printCalendar() {
    // Verificar que hi hagi dades per imprimir
    if (!matches || matches.length === 0) {
      alert('No hi ha dades de calendari per imprimir. Assegura\'t que el calendari estigui generat.');
      return;
    }

    // Preguntar a l'usuari quin format d'impressió vol
    const useDoubleColumn = confirm(
      'Tria el format d\'impressió:\n\n' +
      'Acceptar: Dues columnes (més compacte, més partides per pàgina)\n' +
      'Cancel·lar: Una columna (text més gran, més fàcil de llegir)'
    );

    console.log('Imprimint calendari amb', matches.length, 'partides', useDoubleColumn ? '(dues columnes)' : '(una columna)');
    
    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      alert('No s\'ha pogut obrir la finestra d\'impressió. Comprova que no estiguin bloquejades les finestres emergents.');
      return;
    }
    
    try {
      // Construir context per al servei d'impressió a partir de l'estat actual.
      // Reutilitzem el timeline filtrat i agrupat (computat reactivament a la vista).
      const filteredForPrint = timelineData.filter(slot => {
        if (selectedDate && slot.dateStr !== selectedDate) return false;
        if (selectedCategory && slot.match && slot.match.categoria_id !== selectedCategory) return false;
        return true;
      });
      const timelineGroupedForPrint = svcGroupTimelineByDayAndHour(filteredForPrint);

      const pendingForPrint = matches.filter(match => {
        const hasResult = match.caramboles_jugador1 != null && match.caramboles_jugador2 != null;
        if (hasResult) return false;
        if (!match.data_programada || !match.hora_inici || !match.taula_assignada) {
          if (selectedCategory && match.categoria_id !== selectedCategory) return false;
          return true;
        }
        return false;
      });

      const printCtx: PrintContext = {
        eventData,
        isAdmin,
        pendingMatches: pendingForPrint,
        timelineGrouped: timelineGroupedForPrint,
        categories
      };

      const printHTML = svcGeneratePrintHTML(printCtx, useDoubleColumn);

      printWindow.document.open();
      printWindow.document.write(printHTML);
      printWindow.document.close();

      printWindow.onload = () => {
        printWindow.print();
        printWindow.close();
      };
    } catch (error: any) {
      console.error('Error generant la impressió:', error);
      alert('Error generant la impressió: ' + error.message);
      printWindow.close();
    }
  }



  let matches: any[] = [];
  let availableDates: Date[] = [];
  let timelineData: any[] = [];
  let unprogrammedMatches: any[] = [];
  let calendarConfig: any = {
    dies_setmana: ['dl', 'dt', 'dc', 'dj', 'dv'],
    hores_disponibles: ['18:00', '19:00'],
    taules_per_slot: 3
  };
  let loading = true;
  let error: string | null = null;
  let viewMode: 'category' | 'timeline' = defaultMode;
  let publishing = false;

  // Filtres
  let selectedCategory = '';
  let selectedDate = '';
  let selectedWeek = '';
  let playerSearch = '';
  let selectedPlayerId: string | null = null; // ID del jugador seleccionat (filtratge exacte)
  let playerSuggestions = [];
  let showOnlyMyMatches = false;
  let myPlayerData: any = null;

  // Edició (només per admins)
  let editingMatch: any = null;
  let editForm = {
    data_programada: '',
    hora_inici: '',
    taula_assignada: null,
    estat: 'generat',
    observacions_junta: ''
  };

  // Variables per l'intercanvi de partides
  let selectedMatches: Set<string> = new Set();
  let swapMode: boolean = false;

  // Variables per al modal de resultats
  let showResultModal = false;
  let resultMatch: any = null;
  let resultForm = {
    caramboles_jugador1: 0,
    caramboles_jugador2: 0,
    entrades: 0,
    observacions: ''
  };

  // Variables per al modal d'incompareixences
  let showIncompareixencaModal = false;
  let incompareixencaMatch: any = null;

  // Variables per al modal de partides pendents
  let showPendingMatchesModal = false;
  let selectedSlot: any = null;

  // Variable per al modal de partides antigues
  let showOldMatchesModal = false;

  const dayNames = {
    'dl': 'Dilluns',
    'dt': 'Dimarts',
    'dc': 'Dimecres',
    'dj': 'Dijous',
    'dv': 'Divendres',
    'ds': 'Dissabte',
    'dg': 'Diumenge'
  };

  const estatOptions = [
    { value: 'generat', label: 'Generat', color: 'bg-gray-100 text-gray-800' },
    { value: 'validat', label: 'Validat', color: 'bg-blue-100 text-blue-800' },
    { value: 'publicat', label: 'Publicat', color: 'bg-green-100 text-green-800' },
    { value: 'reprogramada', label: 'Reprogramada', color: 'bg-yellow-100 text-yellow-800' },
    { value: 'jugada', label: 'Jugada', color: 'bg-emerald-100 text-emerald-800' },
    { value: 'cancel·lada', label: 'Cancel·lada', color: 'bg-red-100 text-red-800' },
    { value: 'pendent_programar', label: 'Pendent programar', color: 'bg-orange-100 text-orange-800' }
  ];

  // Carregar dades quan canvia l'event
  $: if (eventId) {
    loadCalendarData();
  }

  // Generar dates disponibles per la vista timeline
  $: availableDates = generateAvailableDates(matches);
  $: timelineData = matches.length > 0 ? generateTimelineData(matches, calendarConfig, availableDates) : [];
  
  // Debug reactiu
  // $: {
  //   if (matches.length > 0) {
  //     console.log('🔍 Reactive update - matches:', matches.length);
  //     console.log('🔍 Reactive update - availableDates:', availableDates?.length || 0);
  //     console.log('🔍 Reactive update - timelineData:', timelineData?.length || 0);
  //   }
  // }

  // Estat combinat de loading.
  // IMPORTANT: no depenem de `matches.length > 0` perquè quan es fan múltiples uploads,
  // la llista pot quedar momentàniament buida i la UI pot quedar enganxada en l'estat "Carregant".
  $: isDataReady = !loading;
  
  // Debug per veure quan es considera que les dades estan llestes
  // $: {
  //   console.log('🔍 Data ready check:', {
  //     loading,
  //     matchesLength: matches.length,
  //     isDataReady,
  //     timelineDataLength: timelineData.length
  //   });
  // }

  // Load player data for logged-in user
  async function loadMyPlayerData() {
    if (!$user) {
      myPlayerData = null;
      return;
    }

    try {
      // Fase 5c-S2c-2: directe via socis.email
      const { data: sociData, error: sociError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms, email')
        .eq('email', $user.email)
        .maybeSingle();

      if (sociError || !sociData) {
        console.log('No soci data found for user email:', $user.email);
        myPlayerData = null;
      } else {
        myPlayerData = {
          id: sociData.numero_soci,
          numero_soci: sociData.numero_soci,
          nom: `${sociData.nom ?? ''} ${sociData.cognoms ?? ''}`.trim(),
          email: sociData.email
        };
      }
    } catch (e) {
      console.error('Error loading player data:', e);
      myPlayerData = null;
    }
  }

  // React to user changes
  $: if ($user) {
    console.log('🔍 User detected in calendar, loading player data:', $user.id);
    loadMyPlayerData();
  } else {
    console.log('🔍 No user in calendar');
    myPlayerData = null;
    showOnlyMyMatches = false;
  }

  // Debug myPlayerData changes
  $: console.log('🎯 Calendar - myPlayerData:', myPlayerData, 'showOnlyMyMatches:', showOnlyMyMatches);

  async function loadCalendarData() {
    if (!eventId) return;

    loading = true;
    error = null;

  let categoriesMap = new Map();
  let playersMap = new Map();
  try {
      // Carregar configuració del calendari (només per admins per evitar errors RLS)
      if (isAdmin) {
        try {
          const { data: config, error: configError } = await supabase
            .from('configuracio_calendari')
            .select('*')
            .eq('event_id', eventId)
            .single();

          if (config) {
            calendarConfig = config;
            console.log('📅 Configuració del calendari carregada:', {
              dies_setmana: config.dies_setmana,
              hores_disponibles: config.hores_disponibles,
              taules_per_slot: config.taules_per_slot
            });
          }
          
          if (configError && configError.code !== 'PGRST116') { // PGRST116 = no rows found
            console.warn('Error loading calendar config:', configError);
          }
        } catch (configErr) {
          console.warn('Could not load calendar config - insufficient permissions:', configErr);
          // Continuar sense configuració del calendari
        }
      }

      // Carregar partits amb funció RPC per accés públic
      console.log('🔍 Loading calendar matches with RPC for event:', eventId);
      const { data: matchDataRaw, error: matchError } = await supabase
        .rpc('get_calendar_matches_public', {
          p_event_id: eventId
        });

      if (matchError) {
        console.error('❌ Error loading calendar with RPC:', matchError);
        throw matchError;
      }

      console.log('✅ Loaded calendar matches:', matchDataRaw?.length || 0);

      // Carregar també partides no programades (només si l'usuari està autenticat)
      console.log('🔍 Loading unprogrammed matches (only for authenticated users)...');
      let unprogrammedRaw = [];
      let unprogrammedError = null;
      const withdrawnSocis = new Set<number>();
      
      // Verificar si l'usuari està autenticat
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      console.log('🔍 User authentication status:', user ? 'Authenticated' : 'Anonymous');
      
      if (user) {
        try {
          // Carregar jugadors retirats/desqualificats per excloure les seves partides pendents
          const { data: inscriptionsData, error: inscriptionsError } = await supabase
            .rpc('get_inscripcions_with_socis', {
              p_event_id: eventId
            });

          if (!inscriptionsError) {
            (inscriptionsData || [])
              .filter((item: any) => item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences)
              .forEach((item: any) => {
                if (typeof item.soci_numero === 'number') {
                  withdrawnSocis.add(item.soci_numero);
                }
              });
          }

          // Carregar partides no programades amb els filtres correctes
          console.log('🔍 User authenticated, loading unprogrammed matches (estat=pendent_programar, data_programada=null)...');
          const result = await supabase
            .from('calendari_partides')
            .select('*')
            .eq('event_id', eventId)
            .eq('estat', 'pendent_programar')
            .is('caramboles_jugador1', null)
            .is('caramboles_jugador2', null)
            .is('data_programada', null);

          unprogrammedRaw = result.data;
          unprogrammedError = result.error;

          // Si hi ha partides, buscar noms reals de jugadors i categories
          // Fase 5c-S2c-2: query directa a `socis` per `*_soci_numero`
          if (unprogrammedRaw && unprogrammedRaw.length > 0) {
            const sociNumbers = Array.from(new Set([
              ...unprogrammedRaw.map((m: any) => m.jugador1_soci_numero),
              ...unprogrammedRaw.map((m: any) => m.jugador2_soci_numero)
            ].filter((n: any) => typeof n === 'number'))) as number[];

            if (sociNumbers.length > 0) {
              // Excloure partides pendents amb jugadors retirats
              if (withdrawnSocis.size > 0) {
                unprogrammedRaw = unprogrammedRaw.filter((match: any) => {
                  return !withdrawnSocis.has(match.jugador1_soci_numero ?? -1)
                      && !withdrawnSocis.has(match.jugador2_soci_numero ?? -1);
                });
              }

              const { data: socisData } = await supabase
                .from('socis')
                .select('numero_soci, nom, cognoms')
                .in('numero_soci', sociNumbers);
              if (socisData) {
                socisData.forEach((soci: any) => {
                  const inicialNom = soci.nom ? soci.nom.trim().charAt(0).toUpperCase() : '';
                  const primerCognom = soci.cognoms ? soci.cognoms.trim().split(' ')[0] : '';
                  // playersMap aquí es composa per soci_numero (no UUID).
                  playersMap.set(soci.numero_soci, { nom: inicialNom, cognoms: primerCognom });
                });
              }
            }
            const categoriaIds = [...new Set(unprogrammedRaw.map((m: any) => m.categoria_id).filter(Boolean))];

            // Carregar categories
            if (categoriaIds.length > 0) {
              const { data: categoriesData } = await supabase
                .from('categories')
                .select('id, nom')
                .in('id', categoriaIds);
              if (categoriesData) {
                categoriesData.forEach(c => {
                  categoriesMap.set(c.id, c.nom);
                });
              }
            }

            // Afegir noms reals a les partides (lookup per soci_numero)
            unprogrammedRaw = unprogrammedRaw.map(match => ({
              ...match,
              categoria_nom: categoriesMap.get(match.categoria_id) || '',
              jugador1: playersMap.get(match.jugador1_soci_numero) || { nom: 'J.', cognoms: '(No programat)' },
              jugador2: playersMap.get(match.jugador2_soci_numero) || { nom: 'J.', cognoms: '(No programat)' }
            }));
          }
        } catch (err) {
          console.warn('⚠️ Error loading unprogrammed matches for authenticated user:', err);
          unprogrammedError = err;
        }
      } else {
        console.log('ℹ️ Anonymous user - unprogrammed matches not available due to RLS policies');
      }

      console.log('🔍 Unprogrammed query result:', { 
        data: unprogrammedRaw?.length || 0, 
        error: unprogrammedError 
      });

      if (unprogrammedError) {
        console.warn('⚠️ Could not load unprogrammed matches:', unprogrammedError);
        // Continuar sense partides no programades si hi ha error de permisos
      }

      console.log('✅ Loaded unprogrammed matches:', unprogrammedRaw?.length || 0);

      // Transformar les dades RPC al format esperat pel component
      const matchData = matchDataRaw?.map(match => ({
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
          socis: {
            nom: match.jugador1_nom,
            cognoms: match.jugador1_cognoms
          }
        },
        jugador2: {
          numero_soci: match.jugador2_numero_soci,
          socis: {
            nom: match.jugador2_nom,
            cognoms: match.jugador2_cognoms
          }
        }
      })) || [];

      // Transformar les partides no programades al mateix format
      // (Fase 5c-S2c-2: lookup per soci_numero)
      const unprogrammedData = unprogrammedRaw?.map((match: any) => ({
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
        jugador1: playersMap.get(match.jugador1_soci_numero) || { nom: 'J.', cognoms: '(No programat)' },
        jugador2: playersMap.get(match.jugador2_soci_numero) || { nom: 'J.', cognoms: '(No programat)' }
      })) || [];

      console.log('🔍 Unprogrammed data processed:', unprogrammedData.length);

      // Combinar les dades programades i no programades
      const allMatchData = [...matchData, ...unprogrammedData];
      console.log('📊 Total matches (programmed + unprogrammed):', allMatchData.length);

      // Debug: comprovar taules assignades
      // const withTables = matchData.filter(m => m.taula_assignada).length;
      // const withoutTables = matchData.filter(m => !m.taula_assignada).length;
      // console.log('🔍 Matches with taula_assignada:', withTables, 'without:', withoutTables);
      // if (matchData.length > 0) {
      //   console.log('🔍 Sample match taula_assignada:', matchData[0].taula_assignada, typeof matchData[0].taula_assignada);
      // }

      // Carregar categories si no es passen per prop
      let finalCategories = categories;
      if (categories.length === 0) {
        console.log('🔍 Loading categories for calendar with RPC:', eventId);
        const { data: categoriesData, error: categoriesError } = await supabase
          .rpc('get_categories_for_event', {
            p_event_id: eventId
          });
        
        if (!categoriesError && categoriesData) {
          finalCategories = categoriesData;
          console.log('✅ Loaded categories for calendar:', finalCategories.length);
        } else {
          console.error('❌ Error loading categories for calendar:', categoriesError);
        }
      }

      // Combinar dades de partits amb categories
      const matchesWithCategories = (allMatchData || []).map(match => {
        const category = finalCategories.find(c => c.id === match.categoria_id);
        return {
          ...match,
          categoria: category || null
        };
      });

      matches = matchesWithCategories;
      
      console.log('✅ Final matches processed:', matches.length);
      console.log('🔍 Sample match structure:', matches[0] ? {
        id: matches[0].id,
        data_programada: matches[0].data_programada,
        hora_inici: matches[0].hora_inici,
        jugador1: matches[0].jugador1?.socis?.nom,
        jugador2: matches[0].jugador2?.socis?.nom,
        categoria: matches[0].categoria?.nom,
        taula_assignada: matches[0].taula_assignada
      } : 'No matches');

    } catch (e) {
      console.error('❌ Error in loadCalendarData:', e);
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }


  // Wrappers fins que reactive blocks usin directament els serveis.
  function generateAvailableDates(matchesParam: any[] = []): Date[] {
    const currentMatches = matchesParam.length > 0 ? matchesParam : matches;
    return svcGenerateAvailableDates(currentMatches);
  }

  function generateTimelineData(
    matchesParam: any[] = [],
    configParam: any = null,
    datesParam: Date[] = []
  ): any[] {
    const currentMatches = matchesParam.length > 0 ? matchesParam : matches;
    const currentDates = datesParam.length > 0 ? datesParam : availableDates;
    const config = configParam || calendarConfig;
    return svcGenerateTimelineData(currentMatches, config, currentDates);
  }

  function getEstatStyle(estat: string) {
    const option = estatOptions.find(opt => opt.value === estat);
    return option?.color || 'bg-gray-100 text-gray-800';
  }

  // Filtrar dades
  $: filteredMatches = matches.filter(match => {
    // Filtrar partides passades - només mostrar partides futures o d'avui
    if (match.data_programada) {
      const matchDate = new Date(match.data_programada);
      const today = new Date();
      today.setHours(0, 0, 0, 0); // Resetear a inici del dia

      // Si la partida és anterior a avui, no la mostrem
      if (matchDate < today) return false;
    }

    // Filtrar per jugador: prioritzar ID si hi ha jugador seleccionat, sinó text
    if (showOnlyMyMatches && myPlayerData) {
      if (!matchPlayerById(match, myPlayerData.id)) return false;
    } else if (selectedPlayerId) {
      if (!matchPlayerById(match, selectedPlayerId)) return false;
    } else if (playerSearch.length >= 2) {
      const searchLower = playerSearch.toLowerCase().trim();
      const player1Match = matchPlayerSearchText(match.jugador1, searchLower);
      const player2Match = matchPlayerSearchText(match.jugador2, searchLower);
      if (!player1Match && !player2Match) return false;
    }

    if (selectedCategory && match.categoria_id !== selectedCategory) return false;
    if (selectedDate) {
      const matchDate = match.data_programada ?
        toLocalDateStr(new Date(match.data_programada)) : null;
      if (matchDate !== selectedDate) return false;
    }
    return true;
  });

  $: filteredTimeline = timelineData.filter(slot => {
    // Filtrar slots de dates passades - només mostrar dates futures o d'avui
    const slotDate = new Date(slot.dateStr);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (slotDate < today) return false;

    // Filtrar per jugador: prioritzar ID si hi ha jugador seleccionat, sinó text
    if (showOnlyMyMatches && myPlayerData) {
      if (!slot.match) return false;
      if (!matchPlayerById(slot.match, myPlayerData.id)) return false;
    } else if (selectedPlayerId) {
      if (!slot.match) return false;
      if (!matchPlayerById(slot.match, selectedPlayerId)) return false;
    } else if (playerSearch.length >= 2) {
      if (!slot.match) return false;
      const searchLower = playerSearch.toLowerCase().trim();
      const player1Match = matchPlayerSearchText(slot.match.jugador1, searchLower);
      const player2Match = matchPlayerSearchText(slot.match.jugador2, searchLower);
      if (!player1Match && !player2Match) return false;
    }

    if (selectedDate && slot.dateStr !== selectedDate) return false;
    if (selectedCategory && slot.match && slot.match.categoria_id !== selectedCategory) return false;

    return true;
  });


  // Separar partits programats i no programats
  $: programmedMatches = filteredMatches.filter(match => match.data_programada && !['pendent_programar'].includes(match.estat));
  $: {
    unprogrammedMatches = filteredMatches.filter(match =>
      (!match.data_programada || match.estat === 'pendent_programar') &&
      match.caramboles_jugador1 == null &&
      match.caramboles_jugador2 == null
    );

    // Ordenar per categoria
    unprogrammedMatches.sort((a, b) => {
      const catA = categories.find(c => c.id === a.categoria_id);
      const catB = categories.find(c => c.id === b.categoria_id);

      // Si ambdues categories tenen camp 'ordre', ordenar per ordre
      if (catA?.ordre !== undefined && catB?.ordre !== undefined) {
        return catA.ordre - catB.ordre;
      }

      // Si no, ordenar per nom de categoria
      const nomA = catA?.nom || a.categoria_nom || '';
      const nomB = catB?.nom || b.categoria_nom || '';
      return nomA.localeCompare(nomB);
    });
  }
  
  // Comptar slots amb partits del jugador cercat
  $: playerMatchSlots = filteredTimeline.filter(slot => slot.match).length;
    
  // Verificar si s'han generat slots
  $: hasValidSlots = filteredTimeline.length > 0;

  // Agrupar per categoria (vista categoria)
  $: matchesByCategory = groupByCategory(programmedMatches);

  // Agrupar timeline per dies i hores (vista cronològica)
  $: timelineGrouped = groupTimelineByDayAndHour(filteredTimeline);

  // Generar suggeriments de jugadors en temps real
  $: if (playerSearch.length >= 2) {
    generatePlayerSuggestions(playerSearch);
  } else {
    playerSuggestions = [];
  }

  // Wrappers fins que el codi consumidor passi a usar els serveis directament.
  function groupByCategory(arr: any[]) {
    return svcGroupByCategory(arr);
  }

  function groupTimelineByDayAndHour(timeline: any[]) {
    return svcGroupTimelineByDayAndHour(timeline);
  }

  function getCategoryName(categoryId: string) {
    const category = categories.find(c => c.id === categoryId);
    if (!category) return 'Desconeguda';
    return category.nom.replace(/\s*Categoria\s*/gi, '').trim();
  }

  // Mapa de noms de categories (id → nom curt) per a passar als subcomponents.
  $: categoryNames = categories.reduce<Record<string, string>>((acc, cat) => {
    acc[cat.id] = cat.nom?.replace(/\s*Categoria\s*/gi, '').trim() ?? 'Desconeguda';
    return acc;
  }, {});

  function generatePlayerSuggestions(searchText: string) {
    playerSuggestions = svcGeneratePlayerSuggestions(matches, searchText);
  }

  function selectPlayer(suggestion: any) {
    playerSearch = suggestion.displayName;
    selectedPlayerId = suggestion.id;
    playerSuggestions = [];
  }

  function clearPlayerSearch() {
    playerSearch = '';
    selectedPlayerId = null;
    playerSuggestions = [];
  }

  // Tancar suggeriments quan es fa clic fora
  function handleClickOutside(event: MouseEvent) {
    const target = event.target as Element;
    if (!target.closest('.player-search-container')) {
      playerSuggestions = [];
    }
  }

  // Funcions d'edició (només per admins)
  async function startEditing(match: any) {
    if (!isAdmin) return;

    editingMatch = match;
    editForm = {
      data_programada: match.data_programada ?
        toLocalDateStr(new Date(match.data_programada)) : '',
      hora_inici: match.hora_inici || '',
      taula_assignada: match.taula_assignada,
      estat: match.estat,
      observacions_junta: match.observacions_junta || ''
    };
  }

  function cancelEditing() {
    editingMatch = null;
  }

  // Funcions per gestionar resultats
  async function openResultModal(match: any) {
    if (!isAdmin) return;

    // Fetch full match data to get existing scores
    const { data: fullMatchData, error: fetchError } = await supabase
      .from('calendari_partides')
      .select('caramboles_jugador1, caramboles_jugador2, entrades, observacions_junta')
      .eq('id', match.id)
      .single();

    if (fetchError) {
        alert('Error carregant les dades de la partida: ' + formatSupabaseError(fetchError));
        return;
    }

    // Combine original match data (with player names) with fresh score data
    resultMatch = {
        ...match,
        ...fullMatchData
    };

    resultForm = {
      caramboles_jugador1: resultMatch.caramboles_jugador1 || 0,
      caramboles_jugador2: resultMatch.caramboles_jugador2 || 0,
      entrades: resultMatch.entrades || 0,
      observacions: resultMatch.observacions_junta || ''
    };
    showResultModal = true;
  }

  function closeResultModal() {
    showResultModal = false;
    resultMatch = null;
    resultForm = {
      caramboles_jugador1: 0,
      caramboles_jugador2: 0,
      entrades: 0,
      observacions: ''
    };
  }

  async function saveResult() {
    if (!resultMatch || !isAdmin) return;
    if (loading) return; // evita submissions concurrents (doble click)

    // Empats permesos: 1 punt per cada jugador
    if (resultForm.caramboles_jugador1 === 0 && resultForm.caramboles_jugador2 === 0) {
      alert('Introdueix les caramboles per ambdós jugadors');
      return;
    }

    loading = true;

    try {
      // Calcular punts segons el resultat
      let punts_j1 = 0;
      let punts_j2 = 0;

      if (resultForm.caramboles_jugador1 > resultForm.caramboles_jugador2) {
        punts_j1 = 2;  // Jugador 1 guanya
        punts_j2 = 0;
      } else if (resultForm.caramboles_jugador2 > resultForm.caramboles_jugador1) {
        punts_j1 = 0;
        punts_j2 = 2;  // Jugador 2 guanya
      } else {
        punts_j1 = 1;  // Empat
        punts_j2 = 1;
      }

      const { data: updateData, error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          caramboles_jugador1: resultForm.caramboles_jugador1,
          caramboles_jugador2: resultForm.caramboles_jugador2,
          entrades: resultForm.entrades,
          punts_jugador1: punts_j1,
          punts_jugador2: punts_j2,
          data_joc: new Date().toISOString(),
          estat: 'jugada',
          validat_per: (await supabase.auth.getUser()).data.user?.id,
          data_validacio: new Date().toISOString(),
          observacions_junta: resultForm.observacions
        })
        .eq('id', resultMatch.id);

      if (updateError) {
        throw updateError;
      }

      // Tancar modal i recarregar dades
      closeResultModal();
      await loadCalendarData();
      dispatch('matchUpdated');

      alert('✅ Resultat guardat correctament!');
    } catch (err) {
      console.error('Error guardant resultat:', err);
      alert('Error guardant el resultat: ' + formatSupabaseError(err));
    } finally {
      loading = false;
    }
  }

  // Funcions per gestionar incompareixences
  function openIncompareixencaModal(match: any) {
    if (!isAdmin) return;
    incompareixencaMatch = match;
    showIncompareixencaModal = true;
  }

  function closeIncompareixencaModal() {
    showIncompareixencaModal = false;
    incompareixencaMatch = null;
  }

  async function marcarIncompareixenca(jugadorQueFalta: 1 | 2) {
    if (!incompareixencaMatch || !isAdmin) return;
    if (loading) return; // evita RPC concurrents

    const jugadorNom = jugadorQueFalta === 1
      ? formatPlayerName(incompareixencaMatch.jugador1)
      : formatPlayerName(incompareixencaMatch.jugador2);

    const confirmation = confirm(
      `Estàs segur que vols marcar incompareixença de ${jugadorNom}?\n\n` +
      `Això assignarà:\n` +
      `- Jugador present: 2 punts, 0 entrades\n` +
      `- Jugador absent: 0 punts, 50 entrades\n\n` +
      `Si el jugador té 2 incompareixences, serà eliminat del campionat.`
    );

    if (!confirmation) return;

    try {
      loading = true;

      const { data, error: rpcError } = await supabase
        .rpc('registrar_incompareixenca', {
          p_partida_id: incompareixencaMatch.id,
          p_jugador_que_falta: jugadorQueFalta
        });

      if (rpcError) throw rpcError;

      closeIncompareixencaModal();

      // Recarregar dades
      await loadCalendarData();
      dispatch('matchUpdated');

      // Mostrar missatge segons el resultat
      if (data.jugador_eliminat) {
        alert(
          `⚠️ INCOMPAREIXENÇA REGISTRADA\n\n` +
          `El jugador ${jugadorNom} té ${data.incompareixences} incompareixences.\n` +
          `HA ESTAT ELIMINAT DEL CAMPIONAT.\n\n` +
          `Totes les seves partides pendents han estat anul·lades.`
        );
      } else {
        alert(
          `✅ INCOMPAREIXENÇA REGISTRADA\n\n` +
          `El jugador ${jugadorNom} té ${data.incompareixences} incompareixença(es).\n` +
          `Partida registrada amb els punts corresponents.`
        );
      }
    } catch (err) {
      console.error('Error registrant incompareixença:', err);
      alert('Error registrant la incompareixença: ' + formatSupabaseError(err));
    } finally {
      loading = false;
    }
  }

  async function convertToUnprogrammed(match: any) {
    if (!isAdmin) return;

    const confirmation = confirm(
      `Estàs segur que vols convertir aquesta partida en no programada?\n\n` +
      `${formatPlayerName(match.jugador1)} vs ${formatPlayerName(match.jugador2)}\n` +
      `Data: ${formatDate(new Date(match.data_programada))} a les ${match.hora_inici}\n\n` +
      `Aquesta acció eliminarà la data i hora programades.`
    );

    if (!confirmation) return;

    try {
      loading = true;

      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          data_programada: null,
          hora_inici: null,
          taula_assignada: null,
          estat: 'pendent_programar',
          observacions_junta: match.observacions_junta ?
            `${match.observacions_junta}\n[${new Date().toLocaleDateString('ca-ES')}] Convertida a no programada per indisponibilitat de jugador.` :
            `[${new Date().toLocaleDateString('ca-ES')}] Convertida a no programada per indisponibilitat de jugador.`
        })
        .eq('id', match.id);

      if (updateError) throw updateError;

      // Recarregar dades
      await loadCalendarData();
      dispatch('matchUpdated');

      alert('Partida convertida a no programada correctament.');

    } catch (e) {
      console.error('Error converting match to unprogrammed:', e);
      error = formatSupabaseError(e);
      alert('Error al convertir la partida: ' + error);
    } finally {
      loading = false;
    }
  }

  async function programEmptySlot(slot: any) {
    if (!isAdmin) return;

    selectedSlot = slot;
    showPendingMatchesModal = true;
  }

  function handleMatchProgrammed() {
    showPendingMatchesModal = false;
    selectedSlot = null;
    loadCalendarData();
    dispatch('matchUpdated');
  }

  function closePendingMatchesModal() {
    showPendingMatchesModal = false;
    selectedSlot = null;
  }

  function convertOldMatchesToPending() {
    if (!isAdmin) return;
    showOldMatchesModal = true;
  }

  function handleMatchesConverted(event: CustomEvent) {
    showOldMatchesModal = false;
    loadCalendarData();
    dispatch('matchUpdated');
    alert(`✅ S'han convertit ${event.detail.count} partides a "Pendent de programar"`);
  }

  function closeOldMatchesModal() {
    showOldMatchesModal = false;
  }

  async function saveMatch() {
    if (!editingMatch || !isAdmin) return;

    try {
      loading = true;

      const updates: any = {
        estat: editForm.estat,
        taula_assignada: editForm.taula_assignada,
        observacions_junta: editForm.observacions_junta || null
      };

      if (editForm.data_programada && editForm.hora_inici) {
        updates.data_programada = editForm.data_programada + 'T' + editForm.hora_inici + ':00';
        updates.hora_inici = editForm.hora_inici;
      }

      // Comprovar conflicte de billar abans de desar
      if (updates.data_programada && updates.hora_inici && updates.taula_assignada) {
        const dia = updates.data_programada.split('T')[0];
        const { data: conflict } = await supabase
          .from('calendari_partides')
          .select('id')
          .eq('hora_inici', updates.hora_inici)
          .eq('taula_assignada', updates.taula_assignada)
          .neq('id', editingMatch.id)
          .or('partida_anullada.is.null,partida_anullada.eq.false')
          .not('estat', 'in', '("jugada","cancel·lada_per_retirada","pendent_programar","postposada","reprogramada")')
          .filter('data_programada::date', 'eq', dia)
          .maybeSingle();
        if (conflict) {
          throw new Error(`El billar ${updates.taula_assignada} ja té una partida programada el ${dia} a les ${updates.hora_inici}. Tria un altre billar o una altra hora.`);
        }
      }

      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update(updates)
        .eq('id', editingMatch.id);

      if (updateError) {
        if (updateError.message?.includes('idx_unique_billar_slot')) {
          throw new Error(`El billar ${updates.taula_assignada} ja té una partida a aquesta hora. Tria un altre billar o una altra hora.`);
        }
        throw updateError;
      }

      // Tancar edició abans de recarregar
      cancelEditing();

      // Recarregar dades
      await loadCalendarData();
      dispatch('matchUpdated');

    } catch (e) {
      error = formatSupabaseError(e);
      alert('Error guardant els canvis: ' + error);
    } finally {
      loading = false;
    }
  }

  // Funció per publicar el calendari al calendari general
  async function publishCalendar() {
    if (!isAdmin || publishing) return;
    
    const validatedMatches = matches.filter(match => match.estat === 'validat');
    
    if (validatedMatches.length === 0) {
      error = 'No hi ha partits validats per publicar';
      return;
    }

    // Confirmar la publicació
    const confirmPublish = confirm(`Estàs segur que vols publicar ${validatedMatches.length} partits validats al calendari general?\n\nAixò farà que les partides apareguin al calendari de la PWA i seran visibles per tots els usuaris.`);
    
    if (!confirmPublish) return;

    publishing = true;
    error = null;

    try {
      // Actualitzar l'esdeveniment per marcar-lo com a publicat
      const { error: updateEventError } = await supabase
        .from('events')
        .update({ calendari_publicat: true })
        .eq('id', eventId);

      if (updateEventError) {
        console.error('Error actualitzant esdeveniment:', updateEventError);
        error = 'Error al marcar l\'esdeveniment com a publicat: ' + updateEventError.message;
        return;
      }

      // Recarregar les dades per actualitzar la vista
      await loadCalendarData();
      
      // Emetre esdeveniment per notificar que s'ha publicat
      dispatch('calendarPublished', { 
        eventId,
        publishedMatches: validatedMatches.length 
      });

      // Mostrar missatge d'èxit
      console.log(`✅ Calendari publicat! ${validatedMatches.length} partits ara són visibles al calendari general.`);
      
      // Opcional: mostrar una notificació toast
      if (typeof window !== 'undefined') {
        // Si tens un sistema de notificacions, pots usar-lo aquí
        alert(`✅ Calendari publicat correctament!\n\n${validatedMatches.length} partits ara són visibles al calendari general de la PWA.`);
      }

    } catch (e) {
      console.error('Error publicant calendari:', e);
      error = formatSupabaseError(e);
    } finally {
      publishing = false;
    }
  }

  // Funcions per l'intercanvi de partides
  function toggleSwapMode() {
    swapMode = !swapMode;
    if (!swapMode) {
      selectedMatches.clear();
      selectedMatches = selectedMatches; // trigger reactivity
    }
  }

  function toggleMatchSelection(matchId: string) {
    if (selectedMatches.has(matchId)) {
      selectedMatches.delete(matchId);
    } else {
      // Limit to 2 selections for swapping
      if (selectedMatches.size >= 2) {
        alert('Només pots seleccionar 2 partides per intercanviar.');
        return;
      }
      selectedMatches.add(matchId);
    }
    selectedMatches = selectedMatches; // trigger reactivity
  }

  async function swapMatches() {
    if (selectedMatches.size !== 2) {
      error = 'Has de seleccionar exactament 2 partides per intercanviar.';
      return;
    }

    const matchIds = Array.from(selectedMatches);
    const match1 = matches.find(m => m.id === matchIds[0]);
    const match2 = matches.find(m => m.id === matchIds[1]);

    if (!match1 || !match2) {
      error = 'No s\'han pogut trobar les partides seleccionades.';
      return;
    }

    // Validar que les partides tinguin dates i hores assignades
    if (!match1.data_programada || !match1.hora_inici || !match2.data_programada || !match2.hora_inici) {
      error = 'Les partides han de tenir data i hora assignades per poder-les intercanviar.';
      return;
    }

    // Confirmar l'intercanvi
    const confirmSwap = confirm(
      `Estàs segur que vols intercanviar aquestes partides?\n\n` +
      `Partida 1: ${formatPlayerName(match1.jugador1)} vs ${formatPlayerName(match1.jugador2)}\n` +
      `Data actual: ${formatDate(new Date(match1.data_programada))} a les ${match1.hora_inici}\n\n` +
      `Partida 2: ${formatPlayerName(match2.jugador1)} vs ${formatPlayerName(match2.jugador2)}\n` +
      `Data actual: ${formatDate(new Date(match2.data_programada))} a les ${match2.hora_inici}\n\n` +
      `Després de l'intercanvi, les dates i hores s'intercanviaran.`
    );

    if (!confirmSwap) return;

    try {
      // Intercanviar les dates i hores
      const { error: error1 } = await supabase
        .from('calendari_partides')
        .update({
          data_programada: match2.data_programada,
          hora_inici: match2.hora_inici,
          taula_assignada: match2.taula_assignada
        })
        .eq('id', match1.id);

      if (error1) throw error1;

      const { error: error2 } = await supabase
        .from('calendari_partides')
        .update({
          data_programada: match1.data_programada,
          hora_inici: match1.hora_inici,
          taula_assignada: match1.taula_assignada
        })
        .eq('id', match2.id);

      if (error2) throw error2;

      // Recarregar les dades
      await loadCalendarData();

      // Resetear la selecció
      selectedMatches.clear();
      selectedMatches = selectedMatches;
      swapMode = false;

      dispatch('matchesSwapped', { match1Id: match1.id, match2Id: match2.id });

      alert('✅ Partides intercanviades correctament!');

    } catch (e) {
      console.error('Error intercanviant partides:', e);
      error = formatSupabaseError(e);
    }
  }

  // Funció per exportar calendari a CSV
  async function downloadCalendariCSV() {
    if (!eventId || !eventData) return;

    try {
      const csvContent = await exportCalendariToCSV(eventId);

      // Crear i descarregar el fitxer
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');
      if (link.download !== undefined) {
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `calendari_${eventData.nom.replace(/[^a-zA-Z0-9]/g, '_')}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }
    } catch (error) {
      console.error('Error exporting calendar:', error);
      const errorMessage = error instanceof Error ? error.message : 'Error desconegut';
      alert(`Error exportant el calendari: ${errorMessage}`);
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

<style>
  @media print {
    /* Amagar TOT el contingut de la pàgina */
    :global(body *) {
      visibility: hidden !important;
    }

    /* Mostrar només l'encapçalament i la taula cronològica.
       `.calendar-main-container` viu al component fill CalendarTimelineView,
       per això usem `:global()`. */
    .print-title-show,
    .print-title-show *,
    :global(.calendar-main-container),
    :global(.calendar-main-container *) {
      visibility: visible !important;
    }

    /* Amagar elements específics dins els subcomponents (`:global` perquè
       `.print-hide` també l'usen els fills). */
    :global(.print-hide) {
      visibility: hidden !important;
      display: none !important;
    }

    :global(.no-print) {
      visibility: hidden !important;
      display: none !important;
    }

    /* Mostrar l'encapçalament en impressió */
    .print-title-show {
      display: block !important;
      page-break-after: avoid !important;
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      width: 100% !important;
      z-index: 1000 !important;
      background: white !important;
    }

    /* Configuració de pàgina optimitzada per calendari */
    @page {
      margin: 0.4in 0.3in 0.2in 0.3in; /* top right bottom left - peu més petit */
      size: A4 landscape;
    }

    /* Reset de la pàgina per impressió */
    :global(html), :global(body) {
      width: 100% !important;
      height: auto !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    /* Contenidor de la taula per impressió - mogut a CalendarTimelineView */

    /* Estils generals optimitzats per llegibilitat */
    :global(body) {
      font-family: Arial, sans-serif !important;
      font-size: 12px !important;
      line-height: 1.3 !important;
      color: #000 !important;
    }

    /* Taules optimitzades per calendari cronològic.
       Les taules ara viuen als subcomponents — apliquem `:global()`. */
    :global(table) {
      width: 100% !important;
      border-collapse: collapse !important;
      page-break-inside: auto !important;
      margin-bottom: 10px !important;
    }

    :global(th), :global(td) {
      padding: 4px 6px !important;
      font-size: 10px !important;
      font-weight: normal !important;
      border: 0.5px solid #666 !important;
      text-align: left !important;
      vertical-align: middle !important;
      white-space: nowrap !important;
      overflow: hidden !important;
      text-overflow: ellipsis !important;
      line-height: 1.2 !important;
      height: 18px !important;
      max-height: 18px !important;
    }

    :global(th) {
      background-color: #e8e8e8 !important;
      font-weight: bold !important;
      font-size: 9px !important;
      text-transform: uppercase !important;
      border: 1px solid #333 !important;
      height: 20px !important;
      max-height: 20px !important;
    }

    /* Amplades específiques per columnes — mogudes a CalendarTimelineView */

    :global(.calendar-table .category-column) {
      width: 50px !important;
      min-width: 50px !important;
      max-width: 50px !important;
    }

    :global(.calendar-table .player-column) {
      width: 120px !important;
      min-width: 120px !important;
      max-width: 120px !important;
    }

    /* Estil compacte per noms de jugadors */
    :global(.player-name-compact) {
      font-size: 10px !important;
      font-weight: normal !important;
      margin: 0 !important;
      line-height: 1.2 !important;
      white-space: nowrap !important;
      overflow: hidden !important;
      text-overflow: ellipsis !important;
    }

    :global(.player-name-compact .font-semibold) {
      font-weight: bold !important;
      font-size: 10px !important;
    }

    :global(.vs-separator) {
      font-size: 8px !important;
      color: #666 !important;
      margin: 0 4px !important;
      font-weight: normal !important;
    }

    /* Estils específics per categories compactes */
    :global(.category-compact) {
      font-size: 8px !important;
      padding: 1px 4px !important;
      border-radius: 2px !important;
      font-weight: bold !important;
      background-color: #e0e0e0 !important;
      color: #333 !important;
    }

    /* Estils de billar/dia/hora compactes — moguts a CalendarTimelineView */

    /* Capçaleres de seccions */
    :global(h3), :global(h4) {
      margin: 10px 0 5px 0 !important;
      font-size: 14px !important;
      font-weight: bold !important;
      page-break-after: avoid !important;
    }

    /* Estils per encapçalament professional */
    .print-header-container {
      display: flex !important;
      align-items: center !important;
      justify-content: space-between !important;
      margin-bottom: 20px !important;
      padding: 15px 20px !important;
    }

    .print-header-left {
      flex: 0 0 auto !important;
    }

    .print-logo {
      height: 60px !important;
      width: auto !important;
      object-fit: contain !important;
    }

    .print-header-center {
      flex: 1 !important;
      text-align: center !important;
      margin: 0 20px !important;
    }

    .print-main-title {
      font-size: 16px !important;
      font-weight: bold !important;
      margin: 0 0 8px 0 !important;
      color: #000 !important;
      text-transform: uppercase !important;
      letter-spacing: 0.5px !important;
    }

    .print-event-title {
      font-size: 14px !important;
      font-weight: bold !important;
      margin: 0 0 6px 0 !important;
      color: #333 !important;
    }

    .print-season {
      font-size: 12px !important;
      font-weight: normal !important;
      margin: 0 0 6px 0 !important;
      color: #666 !important;
    }

    :global(.print-date) {
      font-size: 10px !important;
      font-style: italic !important;
      margin: 0 !important;
      color: #888 !important;
    }

    .print-header-right {
      flex: 0 0 auto !important;
    }

    :global(.print-contact) {
      text-align: right !important;
      font-size: 10px !important;
      line-height: 1.4 !important;
    }

    :global(.print-contact-line) {
      margin-bottom: 2px !important;
      color: #666 !important;
    }

    .print-divider {
      border: none !important;
      border-top: 2px solid #333 !important;
      margin: 0 0 20px 0 !important;
    }

    /* Divisions de dies */
    :global(.calendar-day-section) {
      page-break-inside: avoid !important;
      margin-bottom: 15px !important;
    }

    /* Capçaleres de dia més prominents */
    :global(.day-header) {
      background-color: #e0e0e0 !important;
      font-size: 13px !important;
      font-weight: bold !important;
      padding: 8px !important;
    }

    /* Capçaleres d'hora */
    :global(.hour-header) {
      background-color: #f5f5f5 !important;
      font-size: 12px !important;
      font-weight: bold !important;
      padding: 6px !important;
    }

    /* Cel·les match/empty — mogudes a CalendarTimelineView */

    /* Separadors principals entre dies i hores */
    :global(.day-separator) {
      border-right: 4px solid #333 !important;
      background-color: #e8e8e8 !important;
      font-weight: bold !important;
      font-size: 14px !important;
    }

    :global(.hour-separator) {
      border-right: 4px solid #333 !important;
      background-color: #f0f0f0 !important;
      font-weight: bold !important;
      font-size: 13px !important;
    }

    /* Separadors verticals jeràrquics — moguts a CalendarTimelineView */

    /* Línies de separació horitzontals específiques per calendari */
    :global(.day-separator-row) {
      border-top: 4px solid #333 !important;
    }

    :global(.hour-separator-row) {
      border-top: 2px solid #666 !important;
    }

    /* Millores generals de les línies de divisió */
    :global(tbody tr) {
      border-bottom: 1px solid #ddd !important;
    }

    /* Files de canvi de dia més destacades */
    :global(tbody tr.new-day) {
      border-top: 4px solid #333 !important;
    }

    /* Files de canvi d'hora més destacades */
    :global(tbody tr.new-hour) {
      border-top: 2px solid #666 !important;
    }

    /* Eliminar colors de fons que no siguin necessaris */
    :global(.bg-gray-50), :global(.bg-orange-50), :global(.hover\:bg-gray-50) {
      background-color: transparent !important;
    }

    /* Força salts de pàgina entre dies si cal - compatibilitat multi-navegador */
    :global(.print-page-break) {
      page-break-before: always !important;
      break-before: page !important; /* CSS3 modern */
      display: block !important;
      height: 0 !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    /* Assegurar que no es trenquin files de taula */
    :global(tr) {
      page-break-inside: avoid !important;
    }
  }

  /* Estils responsius del calendari (mòbil/tauleta/pantalla) — moguts a CalendarTimelineView */
</style>

<div class="space-y-6 main-calendar-container">
  <!-- Encapçalament professional per a impressió -->
  <div class="print-title-show" style="display: none;">
    <div class="print-header-container">
      <div class="print-header-left">
        <img src="/logo.png" alt="Foment Martinenc" class="print-logo" />
      </div>
      <div class="print-header-center">
        <h1 class="print-main-title">
          FOMENT MARTINENC - SECCIÓ BILLAR
        </h1>
        <h2 class="print-event-title">
          {eventData?.nom || 'Campionat de Billar'}
        </h2>
        <h3 class="print-season">
          Temporada {eventData?.temporada || new Date().getFullYear()}
        </h3>
      </div>
      <div class="print-header-right">
      </div>
    </div>
    <hr class="print-divider" />
  </div>

  <!-- Header amb controls -->
  <div class="bg-white border border-gray-200 rounded-lg p-6 print-header-hide">
    <div class="flex items-center justify-between mb-4">
      <div>
        <h3 class="text-lg font-medium text-gray-900">Calendari de Partits</h3>
        {#if matches.length > 0}
          <div class="mt-1 text-sm text-gray-600">
            {#if programmedMatches.some(match => match.estat === 'publicat')}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-emerald-100 text-emerald-800 mr-2">
                📢 {programmedMatches.filter(match => match.estat === 'publicat').length} publicats
              </span>
            {/if}

            {#if selectedPlayerId || playerSearch.length >= 2}
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                🔍 Filtrant per: {playerSearch} | Partits trobats: {filteredMatches.length}/{matches.length} | Slots amb partits: {playerMatchSlots}
              </span>
            {/if}
          </div>
        {/if}
      </div>

      <!-- Controls de vista - Botons d'acció admin -->
      <div class="flex flex-wrap items-center gap-3">
        <!-- Botó de publicar calendari (només per admins i si hi ha partits validats) -->
        {#if isAdmin && programmedMatches.some(match => match.estat === 'validat')}
          <button
            on:click={publishCalendar}
            class="no-print px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 flex items-center gap-2 font-medium"
            title="Publicar calendari al calendari general de la PWA"
            disabled={loading}
          >
            {#if publishing}
              <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
              Publicant...
            {:else}
              📢 Publicar
            {/if}
          </button>
        {/if}

        <!-- Botó per convertir partides antigues (només per admins) -->
        {#if isAdmin}
          <button
            on:click={convertOldMatchesToPending}
            class="no-print px-4 py-2 bg-purple-600 text-white text-sm rounded hover:bg-purple-700 flex items-center gap-2 font-medium"
            title="Convertir partides antigues sense resultats a pendent de programar"
            disabled={loading}
          >
            🔄 Reciclar Antigues
          </button>
        {/if}

        <!-- Controls d'intercanvi de partides (només per admins) -->
        {#if isAdmin}
          <div class="flex items-center gap-2">
            <button
              on:click={toggleSwapMode}
              class="no-print px-4 py-2 text-sm rounded font-medium flex items-center justify-center gap-2"
              class:bg-orange-600={swapMode}
              class:text-white={swapMode}
              class:hover:bg-orange-700={swapMode}
              class:bg-orange-100={!swapMode}
              class:text-orange-800={!swapMode}
              class:hover:bg-orange-200={!swapMode}
              title="Activar/desactivar mode d'intercanvi de partides"
            >
              🔄 <span class="hidden sm:inline">{swapMode ? 'Cancel·lar' : 'Intercanviar'}</span>
            </button>

            {#if swapMode && selectedMatches.size === 2}
              <button
                on:click={swapMatches}
                class="no-print px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 font-medium flex items-center justify-center gap-1"
                title="Confirmar intercanvi de les partides seleccionades"
              >
                ✅ <span class="hidden sm:inline">Confirmar</span>
              </button>
            {/if}

            {#if swapMode}
              <span class="text-sm text-gray-600 font-medium">
                {selectedMatches.size}/2
              </span>
            {/if}
          </div>
        {/if}

        <!-- Botó d'exportar CSV (només per admins) -->
        {#if isAdmin}
          <button
            on:click={downloadCalendariCSV}
            class="no-print px-4 py-2 bg-purple-600 text-white text-sm rounded hover:bg-purple-700 items-center gap-2 font-medium flex"
            title="Exportar calendari a CSV"
          >
            📄 Exportar
          </button>
        {/if}

        <!-- Botó d'impressió -->
        <button
          on:click={printCalendar}
          class="no-print hidden md:flex px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 items-center gap-2 font-medium"
          title="Imprimir calendari cronològic"
        >
          🖨️ Imprimir
        </button>
      </div>
    </div>

    <!-- Filtres - Primera fila -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div>
        <label for="category-filter" class="block text-sm font-medium text-gray-700 mb-2">Categoria</label>
        <select
          id="category-filter"
          bind:value={selectedCategory}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">Totes les categories</option>
          {#each categories.sort((a, b) => a.ordre_categoria - b.ordre_categoria) as category}
            <option value={category.id}>{category.nom}</option>
          {/each}
        </select>
      </div>

      <div>
        <label for="date-filter" class="block text-sm font-medium text-gray-700 mb-2">Data</label>
        <input
          id="date-filter"
          type="date"
          bind:value={selectedDate}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div class="relative print-header-hide player-search-container">
        <label for="player-search" class="block text-sm font-medium text-gray-700 mb-2">Jugador</label>
        <div class="relative">
          <input
            id="player-search"
            type="text"
            bind:value={playerSearch}
            on:input={() => { selectedPlayerId = null; }}
            placeholder="Escriu nom o cognoms..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 pr-8"
            disabled={showOnlyMyMatches}
          />
          {#if playerSearch}
            <button
              on:click={clearPlayerSearch}
              class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
              title="Netejar cerca"
            >
              ✕
            </button>
          {/if}
        </div>

        <!-- Suggeriments de jugadors -->
        {#if playerSuggestions.length > 0}
          <div class="absolute top-full left-0 right-0 z-50 bg-white border border-gray-300 rounded-md shadow-lg max-h-64 overflow-y-auto mt-1">
            {#each playerSuggestions as suggestion}
              <button
                on:click={() => selectPlayer(suggestion)}
                class="w-full px-3 py-2 text-left hover:bg-gray-50 border-b border-gray-100 last:border-b-0 focus:outline-none focus:bg-gray-50"
              >
                <div class="text-sm font-medium text-gray-900">
                  {suggestion.displayName}
                </div>
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div>
        <div class="block text-sm font-medium text-gray-700 mb-2 invisible" aria-hidden="true">Accions</div>
        <button
          on:click={() => { selectedCategory = ''; selectedDate = ''; clearPlayerSearch(); }}
          class="w-full px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700 font-medium"
        >
          Netejar Filtres
        </button>
      </div>
    </div>

    <!-- Filtres - Segona fila: Selector de vista i checkbox -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-2">
      <div class="flex items-end">
        <div class="flex bg-gray-100 rounded-lg p-1">
          <button
            on:click={() => viewMode = 'category'}
            class="px-3 py-1.5 rounded text-sm transition-colors font-medium"
            class:bg-white={viewMode === 'category'}
            class:shadow-sm={viewMode === 'category'}
            class:text-gray-900={viewMode === 'category'}
            class:text-gray-600={viewMode !== 'category'}
          >
            📋 Per Categoria
          </button>
          <button
            on:click={() => viewMode = 'timeline'}
            class="px-3 py-1.5 rounded text-sm transition-colors font-medium"
            class:bg-white={viewMode === 'timeline'}
            class:shadow-sm={viewMode === 'timeline'}
            class:text-gray-900={viewMode === 'timeline'}
            class:text-gray-600={viewMode !== 'timeline'}
          >
            📅 Cronològica
          </button>
        </div>
      </div>

      <div>
        <!-- Columna buida per mantenir el grid -->
      </div>

      <div class="flex items-start">
        {#if myPlayerData}
          <label class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
            <input
              type="checkbox"
              bind:checked={showOnlyMyMatches}
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <span class="font-medium">🎯 Les meves partides</span>
          </label>
        {/if}
      </div>

      <div>
        <!-- Columna buida per mantenir el grid -->
      </div>
    </div>
  </div>

  <!-- Missatges d'error -->
  {#if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4 print-header-hide">
      <div class="text-red-800">{error}</div>
    </div>
  {/if}

  <!-- Loading -->
  {#if !isDataReady}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center print-header-hide">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">
        {loading ? 'Carregant calendari...' : 'Esperant dades del calendari...'}
      </p>
    </div>
  {:else if viewMode === 'category'}
    <!-- Vista per Categories -->
    <CalendarCategoryView
      {matchesByCategory}
      totalMatches={filteredMatches.length}
      {categoryNames}
      {isAdmin}
      {swapMode}
      {selectedMatches}
      on:toggleMatch={(e) => toggleMatchSelection(e.detail.matchId)}
      on:openResult={(e) => openResultModal(e.detail.match)}
      on:openIncompareixenca={(e) => openIncompareixencaModal(e.detail.match)}
      on:startEdit={(e) => startEditing(e.detail.match)}
      on:convertUnprogrammed={(e) => convertToUnprogrammed(e.detail.match)}
    />
  {:else}
    <!-- Vista Cronològica -->
    <CalendarTimelineView
      {timelineGrouped}
      {dayNames}
      {isAdmin}
      {swapMode}
      {selectedMatches}
      hasPlayerFilter={!!selectedPlayerId || playerSearch.length >= 2}
      hasOtherFilter={!!selectedDate || !!selectedCategory}
      {playerSearch}
      on:toggleMatch={(e) => toggleMatchSelection(e.detail.matchId)}
      on:openResult={(e) => openResultModal(e.detail.match)}
      on:openIncompareixenca={(e) => openIncompareixencaModal(e.detail.match)}
      on:startEdit={(e) => startEditing(e.detail.match)}
      on:convertUnprogrammed={(e) => convertToUnprogrammed(e.detail.match)}
      on:programSlot={(e) => programEmptySlot(e.detail.slot)}
    />
  {/if}

  <!-- Partides No Programades -->
  <CalendarUnprogrammedMatches
    matches={unprogrammedMatches}
    {isAdmin}
    {categoryNames}
    {estatOptions}
    on:program={(e) => startEditing(e.detail.match)}
  />
</div>

<!-- Modal d'edició (només per admins) -->
{#if isAdmin}
  <CalendarMatchEditModal
    match={editingMatch}
    {estatOptions}
    on:save={(e) => { editForm = { ...editForm, ...e.detail }; saveMatch(); }}
    on:cancel={cancelEditing}
  />
{/if}

<!-- Modal per introduir resultats -->
{#if showResultModal}
  <CalendarMatchResultModal
    match={resultMatch}
    categoryName={resultMatch ? getCategoryName(resultMatch.categoria_id) : ''}
    saving={loading}
    on:save={(e) => { resultForm = { ...resultForm, ...e.detail }; saveResult(); }}
    on:close={closeResultModal}
  />
{/if}

<!-- Modal d'Incompareixença -->
{#if showIncompareixencaModal}
  <CalendarIncompareixencaModal
    match={incompareixencaMatch}
    saving={loading}
    on:selectAbsent={(e) => marcarIncompareixenca(e.detail.player)}
    on:close={closeIncompareixencaModal}
  />
{/if}

<!-- Modal de Partides Pendents -->
{#if showPendingMatchesModal && selectedSlot}
  <PendingMatchesModal
    {eventId}
    {categories}
    slot={selectedSlot}
    on:matchProgrammed={handleMatchProgrammed}
    on:close={closePendingMatchesModal}
  />
{/if}

<!-- Modal de Partides Antigues -->
{#if showOldMatchesModal}
  <OldMatchesModal
    {eventId}
    {categories}
    on:matchesConverted={handleMatchesConverted}
    on:close={closeOldMatchesModal}
  />
{/if}
