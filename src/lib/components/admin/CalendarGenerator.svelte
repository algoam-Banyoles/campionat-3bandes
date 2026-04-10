<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError } from '$lib/ui/alerts';

  const dispatch = createEventDispatcher();

  export let eventId: string = '';
  export let categories: any[] = [];
  export let inscriptions: any[] = [];
  export let processing = false;

  // Configuració del calendari
  let calendarConfig = {
    dies_setmana: ['dl', 'dt', 'dc', 'dj', 'dv'], // dilluns a divendres
    hores_disponibles: ['18:00', '19:00'], // horaris del club
    taules_per_slot: 3,
    max_partides_per_setmana: 2,
    max_partides_per_dia: 1,
    dies_festius: []
  };

  let dataInici: string = '';
  let dataFi: string = '';
  let showPreview = false;
  let proposedCalendar = [];
  let generatingCalendar = false;
  let showRestrictions = false;
  let showPlayers = true;
  let showDeleteConfirmation = false;
  let calendariPublicat = false;

  // Preview controls
  let previewSearch = '';
  let previewViewMode: 'cronologia' | 'categoria' = 'cronologia';
  let previewSelectedCategory = '';

  $: previewSearchLower = previewSearch.toLowerCase();
  $: filteredPreview = proposedCalendar.filter(m => {
    if (previewSearchLower && !(
      m.jugador1?.soci?.nom?.toLowerCase().includes(previewSearchLower) ||
      m.jugador1?.soci?.cognoms?.toLowerCase().includes(previewSearchLower) ||
      m.jugador2?.soci?.nom?.toLowerCase().includes(previewSearchLower) ||
      m.jugador2?.soci?.cognoms?.toLowerCase().includes(previewSearchLower)
    )) return false;
    if (previewSelectedCategory && m.categoria_id !== previewSelectedCategory) return false;
    return true;
  });
  $: previewProgrammed = filteredPreview.filter(m => m.estat === 'generat');
  $: previewPending = filteredPreview.filter(m => m.estat === 'pendent_programar');
  
  // Gestió de períodes de bloqueig
  let showBlockedPeriods = false;
  let blockedPeriods: Array<{ start: string; end: string; description: string }> = [];
  let newBlockedStart = '';
  let newBlockedEnd = '';
  let newBlockedDescription = '';
  
  // Gestió de vista d'estadístiques de taules
  let showTableStats = false;
  let calendarKPIs: any = null;

  // Mapes per optimitzar cerques
  let playerRestrictions = new Map();
  let playersByCategory = new Map();

  // Cache per restriccions especials parsejades (evita re-parsejar a cada slot check)
  let parsedRestrictionsCache = new Map<string, Array<{ start: Date; end: Date }>>();
  let calendarError = '';

  // Clau localStorage per persistir configuració entre generacions
  $: storageKey = `calendarConfig_${eventId}`;

  // Carregar configuració guardada al muntar o canviar event
  $: if (eventId) {
    loadSavedConfig();
  }

  function loadSavedConfig() {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved) {
        const config = JSON.parse(saved);
        if (config.dataInici) dataInici = config.dataInici;
        if (config.dataFi) dataFi = config.dataFi;
        if (config.blockedPeriods) blockedPeriods = config.blockedPeriods;
        if (config.calendarConfig) {
          calendarConfig = { ...calendarConfig, ...config.calendarConfig };
        }
      }
    } catch (e) {
      console.warn('Error carregant configuració guardada:', e);
    }
  }

  function saveConfig() {
    try {
      localStorage.setItem(storageKey, JSON.stringify({
        dataInici,
        dataFi,
        blockedPeriods,
        calendarConfig
      }));
    } catch (e) {
      console.warn('Error guardant configuració:', e);
    }
  }

  // Auto-guardar quan canvien les dates, bloqueigs o configuració
  $: if (eventId) {
    // Referenciar totes les variables per activar reactivitat
    const _trigger = JSON.stringify({ dataInici, dataFi, blockedPeriods, calendarConfig });
    saveConfig();
  }

  // Carregar restriccions dels jugadors i estat del calendari
  $: if (inscriptions.length > 0) {
    loadPlayerRestrictions();
    checkCalendariPublicat();
  }

  async function checkCalendariPublicat() {
    try {
      const { data, error } = await supabase
        .from('events')
        .select('calendari_publicat')
        .eq('id', eventId)
        .single();

      if (error) throw error;
      calendariPublicat = data?.calendari_publicat || false;
    } catch (error) {
      console.error('Error comprovant estat calendari:', error);
    }
  }

  async function loadPlayerRestrictions() {
    playerRestrictions.clear();
    playersByCategory.clear();
    parsedRestrictionsCache.clear();

    console.log('Carregant restriccions de', inscriptions.length, 'inscripcions');

    // Fase 5c-S3: ja no cal la taula `players`. Usem `soci_numero` directament
    // com a clau per a tots els mapes interns.
    const sociNumbers = inscriptions.map(i => i.soci_numero).filter(Boolean);
    console.log('Números de soci:', sociNumbers.slice(0, 5));

    if (sociNumbers.length === 0) {
      console.log('No hi ha números de soci vàlids');
      return;
    }

    try {
      let validPlayers = 0;

      inscriptions.forEach((inscription, index) => {
        const sociNumero = inscription.soci_numero;

        if (!sociNumero) {
          console.warn(`Skip inscripció ${index}: soci_numero buit`);
          return;
        }

        if (!inscription.categoria_assignada_id) {
          console.log(`Skip inscripció ${index}: no té categoria assignada`);
          return;
        }

        validPlayers++;

        // Calcular edat del jugador
        let edat: number | null = null;
        if (inscription.socis?.data_naixement) {
          const birth = new Date(inscription.socis.data_naixement);
          const today = new Date();
          edat = today.getFullYear() - birth.getFullYear();
          const m = today.getMonth() - birth.getMonth();
          if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) edat--;
        }

        playerRestrictions.set(sociNumero, {
          preferencies_dies: inscription.preferencies_dies || [],
          preferencies_hores: inscription.preferencies_hores || [],
          restriccions_especials: inscription.restriccions_especials || null,
          edat,
          soci: inscription.socis || {
            nom: `Soci ${inscription.soci_numero}`,
            cognoms: '',
            numero_soci: inscription.soci_numero
          }
        });

        if (!playersByCategory.has(inscription.categoria_assignada_id)) {
          playersByCategory.set(inscription.categoria_assignada_id, []);
        }
        playersByCategory.get(inscription.categoria_assignada_id).push({
          soci_numero: sociNumero,
          inscription_id: inscription.id,
          soci: inscription.socis || {
            nom: `Soci ${inscription.soci_numero}`,
            cognoms: '',
            numero_soci: inscription.soci_numero
          }
        });
      });

      console.log(`Processat: ${validPlayers} jugadors vàlids de ${inscriptions.length} inscripcions`);

    } catch (error) {
      console.error('Error processant inscripcions:', error);
    }

    console.log('Restriccions carregades:', playerRestrictions.size, 'jugadors');
    console.log('Jugadors per categoria:', Object.fromEntries(playersByCategory));

  }

  async function changePlayerCategory(player, fromCategoryId, toCategoryId) {
    if (fromCategoryId === toCategoryId) return;

    try {
      // Persistir a la BD
      const { error } = await supabase
        .from('inscripcions')
        .update({ categoria_assignada_id: toCategoryId })
        .eq('id', player.inscription_id);

      if (error) {
        console.error('Error canviant categoria:', error);
        dispatch('error', { message: `Error movent jugador: ${error.message}` });
        return;
      }

      // Actualitzar mapa local
      const fromPlayers = playersByCategory.get(fromCategoryId);
      if (fromPlayers) {
        playersByCategory.set(fromCategoryId, fromPlayers.filter(p => p.soci_numero !== player.soci_numero));
      }

      if (!playersByCategory.has(toCategoryId)) {
        playersByCategory.set(toCategoryId, []);
      }
      playersByCategory.get(toCategoryId).push(player);

      // Forçar reactivitat
      playersByCategory = new Map(playersByCategory);

      console.log(`✅ ${player.soci.nom} mogut de ${categories.find(c => c.id === fromCategoryId)?.nom} a ${categories.find(c => c.id === toCategoryId)?.nom}`);
    } catch (e) {
      console.error('Error canviant categoria:', e);
      dispatch('error', { message: 'Error movent jugador de categoria' });
    }
  }

  async function calculateProposal() {
    if (!dataInici) {
      dispatch('error', { message: 'Selecciona la data d\'inici del calendari' });
      return;
    }

    generatingCalendar = true;

    try {
      console.log('Calculant proposta de data de fi...');

      // Generar enfrontaments per saber quants partits hi ha
      const matchups = generateAllMatchups();

      // Calcular proposta automàtica
      const proposedEndDate = calculateProposedEndDate(matchups.length);
      dataFi = proposedEndDate.toISOString().split('T')[0];

      console.log(`💡 Proposta calculada: ${dataFi} per ${matchups.length} partits`);
      console.log('📝 Ara pots editar la data de fi abans de generar el calendari');

    } catch (error) {
      console.error('Error calculant proposta:', error);
      dispatch('error', { message: formatSupabaseError(error) });
    } finally {
      generatingCalendar = false;
    }
  }

  // Funció per obtenir el nom d'un jugador a partir d'un match i sociNumero
  function getPlayerName(match: any, sociNumero: number): string {
    if (match.jugador1?.soci_numero === sociNumero) {
      return `${match.jugador1.soci?.nom || ''} ${match.jugador1.soci?.cognoms || ''}`.trim();
    }
    return `${match.jugador2.soci?.nom || ''} ${match.jugador2.soci?.cognoms || ''}`.trim();
  }

  // Funció per validar el calendari generat i calcular KPIs
  function validateGeneratedCalendar(matches: any[]) {
    const scheduled = matches.filter(m => m.data_programada);
    const pending = matches.filter(m => !m.data_programada);

    // Construir mapa de partides per jugador (clau = soci_numero)
    const playerMatches = new Map<number, any[]>();
    const playerNames = new Map<number, string>();

    scheduled.forEach(match => {
      [match.jugador1, match.jugador2].forEach(j => {
        const sn = j.soci_numero;
        if (!playerMatches.has(sn)) playerMatches.set(sn, []);
        playerMatches.get(sn).push(match);
        if (!playerNames.has(sn)) {
          playerNames.set(sn, `${j.soci?.nom || ''} ${j.soci?.cognoms || ''}`.trim());
        }
      });
    });

    // KPI 1: Dues partides el mateix dia
    const sameDayViolations: any[] = [];
    playerMatches.forEach((pMatches, sociNumero) => {
      const byDate = new Map<string, any[]>();
      pMatches.forEach(m => {
        const d = new Date(m.data_programada);
        const ds = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
        if (!byDate.has(ds)) byDate.set(ds, []);
        byDate.get(ds).push(m);
      });
      byDate.forEach((ms, dateStr) => {
        if (ms.length > 1) {
          sameDayViolations.push({
            player: playerNames.get(sociNumero),
            date: dateStr,
            count: ms.length,
            matches: ms.map(m => `${getPlayerName(m, m.jugador1.soci_numero)} vs ${getPlayerName(m, m.jugador2.soci_numero)} ${m.hora_inici}`)
          });
        }
      });
    });

    // KPI 2: Superen max partides per setmana
    const weeklyViolations: any[] = [];
    const maxWeekly = calendarConfig.max_partides_per_setmana;
    playerMatches.forEach((pMatches, sociNumero) => {
      const byWeek = new Map<string, any[]>();
      pMatches.forEach(m => {
        const wk = getISOWeekKey(new Date(m.data_programada));
        if (!byWeek.has(wk)) byWeek.set(wk, []);
        byWeek.get(wk).push(m);
      });
      byWeek.forEach((ms, weekKey) => {
        if (ms.length > maxWeekly) {
          weeklyViolations.push({
            player: playerNames.get(sociNumero),
            week: weekKey,
            count: ms.length,
            max: maxWeekly
          });
        }
      });
    });

    // KPI 2b: Jugadors +75 amb dies consecutius
    const seniorConsecutiveViolations: any[] = [];
    playerMatches.forEach((pMatches, sociNumero) => {
      if (!isPlayerOver75(sociNumero)) return;
      if (hasOnly2ConsecutiveDayPrefs(sociNumero)) return;
      const dates = pMatches.map(m => {
        const d = new Date(m.data_programada);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
      });
      const uniqueDates = [...new Set(dates)].sort((a, b) => a - b);
      for (let i = 0; i < uniqueDates.length - 1; i++) {
        if ((uniqueDates[i + 1] - uniqueDates[i]) / 86400000 === 1) {
          const fmt = (t: number) => { const d = new Date(t); return `${d.getDate()}/${d.getMonth()+1}`; };
          const r = playerRestrictions.get(sociNumero);
          seniorConsecutiveViolations.push({
            player: playerNames.get(sociNumero),
            edat: r?.edat,
            dates: `${fmt(uniqueDates[i])} i ${fmt(uniqueDates[i+1])}`
          });
        }
      }
    });

    // KPI 3: Dies consecutius
    const consecutiveViolations: any[] = [];
    playerMatches.forEach((pMatches, sociNumero) => {
      const dates = pMatches.map(m => {
        const d = new Date(m.data_programada);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
      });
      const uniqueDates = [...new Set(dates)].sort((a, b) => a - b);
      for (let i = 0; i < uniqueDates.length - 1; i++) {
        const diff = (uniqueDates[i + 1] - uniqueDates[i]) / 86400000;
        if (diff === 1) {
          const d1 = new Date(uniqueDates[i]);
          const d2 = new Date(uniqueDates[i + 1]);
          const fmt = (d: Date) => `${d.getDate()}/${d.getMonth()+1}`;
          consecutiveViolations.push({
            player: playerNames.get(sociNumero),
            dates: `${fmt(d1)} i ${fmt(d2)}`
          });
        }
      }
    });

    // KPI 3b: 3 partides en dies consecutius
    const threeConsecutiveViolations: any[] = [];
    playerMatches.forEach((pMatches, sociNumero) => {
      const dates = pMatches.map(m => {
        const d = new Date(m.data_programada);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
      });
      const uniqueDates = [...new Set(dates)].sort((a, b) => a - b);
      for (let i = 0; i < uniqueDates.length - 2; i++) {
        const diff1 = (uniqueDates[i + 1] - uniqueDates[i]) / 86400000;
        const diff2 = (uniqueDates[i + 2] - uniqueDates[i + 1]) / 86400000;
        if (diff1 === 1 && diff2 === 1) {
          const fmt = (t: number) => { const d = new Date(t); return `${d.getDate()}/${d.getMonth()+1}`; };
          threeConsecutiveViolations.push({
            player: playerNames.get(sociNumero),
            dates: `${fmt(uniqueDates[i])}, ${fmt(uniqueDates[i+1])} i ${fmt(uniqueDates[i+2])}`
          });
        }
      }
    });

    // KPI 3c: Més de 2 parells de dies consecutius
    const excessConsecutivePairs: any[] = [];
    playerMatches.forEach((pMatches, sociNumero) => {
      if (hasOnly2ConsecutiveDayPrefs(sociNumero)) return; // Exceptuats
      const dates = pMatches.map(m => {
        const d = new Date(m.data_programada);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
      });
      const uniqueDates = [...new Set(dates)].sort((a, b) => a - b);
      let pairs = 0;
      for (let i = 0; i < uniqueDates.length - 1; i++) {
        if ((uniqueDates[i + 1] - uniqueDates[i]) / 86400000 === 1) pairs++;
      }
      if (pairs > 2) {
        excessConsecutivePairs.push({
          player: playerNames.get(sociNumero),
          pairs
        });
      }
    });

    // KPI 4: Partides fora de preferències de dies
    const dayPrefViolations: any[] = [];
    const dayNames = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];
    const dayLabels = { 'dg': 'Diumenge', 'dl': 'Dilluns', 'dt': 'Dimarts', 'dc': 'Dimecres', 'dj': 'Dijous', 'dv': 'Divendres', 'ds': 'Dissabte' };
    scheduled.forEach(match => {
      const matchDate = new Date(match.data_programada);
      const dayCode = dayNames[matchDate.getDay()];
      [match.jugador1, match.jugador2].forEach(j => {
        const r = playerRestrictions.get(j.soci_numero);
        if (r?.preferencies_dies?.length > 0 && !r.preferencies_dies.includes(dayCode)) {
          dayPrefViolations.push({
            player: playerNames.get(j.soci_numero),
            date: `${matchDate.getDate()}/${matchDate.getMonth()+1}`,
            day: dayLabels[dayCode] || dayCode,
            prefereix: r.preferencies_dies.map(d => dayLabels[d] || d).join(', ')
          });
        }
      });
    });

    // KPI 5: Partides fora de preferències d'hores
    const hourPrefViolations: any[] = [];
    scheduled.forEach(match => {
      const matchHour = match.hora_inici;
      [match.jugador1, match.jugador2].forEach(j => {
        const r = playerRestrictions.get(j.soci_numero);
        if (r?.preferencies_hores?.length > 0 && !r.preferencies_hores.includes(matchHour)) {
          hourPrefViolations.push({
            player: playerNames.get(j.soci_numero),
            date: (() => { const d = new Date(match.data_programada); return `${d.getDate()}/${d.getMonth()+1}`; })(),
            hora: matchHour,
            prefereix: r.preferencies_hores.join(', ')
          });
        }
      });
    });

    // KPI 6: Partides dins períodes de restricció especial
    const specialRestrViolations: any[] = [];
    scheduled.forEach(match => {
      const matchDate = new Date(match.data_programada);
      [match.jugador1, match.jugador2].forEach(j => {
        const r = playerRestrictions.get(j.soci_numero);
        if (r?.restriccions_especials && isDateRestricted(matchDate, r.restriccions_especials)) {
          specialRestrViolations.push({
            player: playerNames.get(j.soci_numero),
            date: `${matchDate.getDate()}/${matchDate.getMonth()+1}`,
            restriccio: r.restriccions_especials.substring(0, 60)
          });
        }
      });
    });

    // KPI 7: Resum general
    const totalPlayers = playerMatches.size;
    const matchCounts = Array.from(playerMatches.values()).map(m => m.length);
    const minMatches = Math.min(...matchCounts);
    const maxMatchCount = Math.max(...matchCounts);

    // Dates rang
    const allDates = scheduled.map(m => new Date(m.data_programada).getTime());
    const firstDate = allDates.length > 0 ? new Date(Math.min(...allDates)) : null;
    const lastDate = allDates.length > 0 ? new Date(Math.max(...allDates)) : null;
    const totalWeeks = firstDate && lastDate
      ? Math.ceil((lastDate.getTime() - firstDate.getTime()) / (7 * 86400000)) + 1
      : 0;

    // Slots usats vs disponibles
    const totalSlots = (() => {
      if (!firstDate || !lastDate) return 0;
      let count = 0;
      for (let d = new Date(firstDate); d <= lastDate; d.setDate(d.getDate() + 1)) {
        const dc = dayNames[d.getDay()];
        if (calendarConfig.dies_setmana.includes(dc)) {
          count += calendarConfig.hores_disponibles.length * calendarConfig.taules_per_slot;
        }
      }
      return count;
    })();
    const slotsUsats = scheduled.length;

    const kpis = {
      resum: {
        programats: scheduled.length,
        pendents: pending.length,
        total: matches.length,
        jugadors: totalPlayers,
        partidesPerJugador: `${minMatches}-${maxMatchCount}`,
        setmanes: totalWeeks,
        slotsUsats,
        slotsDisponibles: totalSlots,
        ocupacio: totalSlots > 0 ? `${(slotsUsats / totalSlots * 100).toFixed(1)}%` : '-',
        primerDia: firstDate ? `${firstDate.getDate()}/${firstDate.getMonth()+1}/${firstDate.getFullYear()}` : '-',
        ultimDia: lastDate ? `${lastDate.getDate()}/${lastDate.getMonth()+1}/${lastDate.getFullYear()}` : '-',
      },
      sameDayViolations,
      weeklyViolations,
      seniorConsecutiveViolations,
      consecutiveViolations,
      threeConsecutiveViolations,
      excessConsecutivePairs,
      dayPrefViolations,
      hourPrefViolations,
      specialRestrViolations,
      isValid: sameDayViolations.length === 0 && dayPrefViolations.length === 0 &&
               hourPrefViolations.length === 0 && specialRestrViolations.length === 0 &&
               threeConsecutiveViolations.length === 0 && excessConsecutivePairs.length === 0 &&
               seniorConsecutiveViolations.length === 0
    };

    return kpis;
  }

  async function generateCalendar() {
    if (!dataInici || !dataFi) {
      dispatch('error', { message: 'Selecciona la data d\'inici i fi del calendari' });
      return;
    }

    generatingCalendar = true;
    calendarError = '';

    try {
      console.log('=== GENERANT CALENDARI ===');
      console.log('📅 Data inici:', dataInici);
      console.log('📅 Data fi:', dataFi);
      console.log('🚫 Períodes de bloqueig:', blockedPeriods);
      console.log('🚫 Dies festius configurats:', calendarConfig.dies_festius);
      console.log('Generant calendari amb dates fixades...');

      let consecutiveDaysAvoided = { count: 0 };

      // 1. Generar tots els enfrontaments possibles per categoria
      const matchups = generateAllMatchups();

      console.log(`📅 Període establert: ${dataInici} a ${dataFi}`);
      console.log(`⚽ Partits a programar: ${matchups.length}`);

      // Calcular capacitat màxima del període
      const availableSlots = calculateAvailableCapacity();
      console.log(`📊 Capacitat màxima: ${availableSlots} slots disponibles`);

      if (matchups.length > availableSlots) {
        console.log(`⚠️ ATENCIÓ: ${matchups.length - availableSlots} partits NO càpiguen i aniran a pendents`);
      }

      // 1. Crear configuració del calendari
      const { error: configError } = await supabase
        .from('configuracio_calendari')
        .upsert({
          event_id: eventId,
          ...calendarConfig
        }, { onConflict: 'event_id' });

      if (configError) throw configError;

      // 3. Distribuir enfrontaments al calendari respectant restriccions
      const scheduledMatches = scheduleMatches(matchups, consecutiveDaysAvoided);

      // 4. Validar el calendari generat i calcular KPIs
      calendarKPIs = validateGeneratedCalendar(scheduledMatches);

      proposedCalendar = scheduledMatches;
      showPreview = true;

      console.log('Calendari generat:', scheduledMatches.length, 'partits');
      console.log(`🚫 Dies consecutius evitats: ${consecutiveDaysAvoided.count} cops`);

    } catch (error) {
      console.error('Error generant calendari:', error);
      calendarError = error instanceof Error ? error.message : formatSupabaseError(error);
      dispatch('error', { message: calendarError });
    } finally {
      generatingCalendar = false;
    }
  }

  function generateAllMatchups() {
    const matchups = [];

    console.log('Generant enfrontaments per categories:', Object.fromEntries(playersByCategory));
    console.log('Categories disponibles (prop):', categories.map(c => ({ id: c.id, nom: c.nom })));
    console.log('Categories al playersByCategory:', Array.from(playersByCategory.keys()));

    playersByCategory.forEach((players, categoryId) => {
      const category = categories.find(c => c.id === categoryId);
      console.log(`Categoria ${categoryId}:`, category?.nom || '⚠️ NO TROBADA', `${players.length} jugadors`);

      if (!category) {
        console.error(`❌ Categoria ${categoryId} no trobada a les categories del prop! Jugadors: ${players.length}`);
        // Usar la categoria directament per no perdre partides
        const fallbackCategory = { id: categoryId, nom: `Cat-${categoryId.substring(0, 8)}` };
        if (players.length >= 2) {
          for (let i = 0; i < players.length; i++) {
            for (let j = i + 1; j < players.length; j++) {
              matchups.push({
                categoria_id: categoryId,
                categoria_nom: fallbackCategory.nom,
                jugador1: players[i],
                jugador2: players[j],
                prioritat: Math.random()
              });
            }
          }
          console.log(`  ✅ Generades ${players.length * (players.length - 1) / 2} partides amb fallback`);
        }
        return;
      }

      if (players.length < 2) {
        console.log(`Saltant categoria ${category.nom}: menys de 2 jugadors`);
        return;
      }

      // Generar tots els enfrontaments possibles dins la categoria
      for (let i = 0; i < players.length; i++) {
        for (let j = i + 1; j < players.length; j++) {
          matchups.push({
            categoria_id: categoryId,
            categoria_nom: category.nom,
            jugador1: players[i],
            jugador2: players[j],
            prioritat: Math.random() // Aleatori per ara
          });
        }
      }
    });

    console.log('Enfrontaments generats:', matchups.length);
    return matchups;
  }

  function scheduleMatches(matchups, consecutiveDaysCounter) {
    const scheduled = [];
    const unscheduled = [];

    // Pre-cachejar totes les restriccions especials
    let playersWithRestrictions = 0;
    playerRestrictions.forEach((restrictions, _sociNumero) => {
      if (restrictions.restriccions_especials) {
        playersWithRestrictions++;
        const cached = parseSpecialRestrictions(restrictions.restriccions_especials);
        parsedRestrictionsCache.set(restrictions.restriccions_especials, cached);
      }
    });
    console.log(`Restriccions especials: ${playersWithRestrictions} jugadors amb períodes restringits`);

    // Tracking per jugador
    const playerStats = new Map();
    const playerAvailability = new Map();
    const playerWeeklyMatches = new Map(); // playerId -> Map<weekKey, count>

    // Inicialitzar stats dels jugadors (clau = soci_numero)
    playersByCategory.forEach(players => {
      players.forEach(player => {
        playerStats.set(player.soci_numero, {
          matchesScheduled: 0,
          lastMatchDate: null,
          tableUsage: new Map()
        });
        playerAvailability.set(player.soci_numero, []);
        playerWeeklyMatches.set(player.soci_numero, new Map());
      });
    });

    // Generar dates disponibles
    const availableDates = generateAvailableDates();

    const startTime = Date.now();
    const maxExecutionTime = 30000;

    // Fase 0: Detectar partides impossibles per incompatibilitat de preferències
    const incompatibleMatchups = [];
    const schedulableMatchups = [];

    matchups.forEach(matchup => {
      const reason = checkScheduleIncompatibility(matchup);
      if (reason) {
        incompatibleMatchups.push({ matchup, reason });
      } else {
        schedulableMatchups.push(matchup);
      }
    });

    if (incompatibleMatchups.length > 0) {
      console.warn(`\n⛔ ${incompatibleMatchups.length} partides impossibles per incompatibilitat:`);
      incompatibleMatchups.forEach(({ matchup, reason }) => {
        console.warn(`   ${matchup.jugador1.soci.nom} vs ${matchup.jugador2.soci.nom}: ${reason}`);
        unscheduled.push({
          ...matchup,
          data_programada: null,
          hora_inici: null,
          taula_assignada: null,
          estat: 'pendent_programar',
          motiu: reason
        });
      });
    }

    let remainingMatchups = [...schedulableMatchups];
    let attempts = 0;
    const maxAttempts = 50;

    while (remainingMatchups.length > 0 && attempts < maxAttempts) {
      if (Date.now() - startTime > maxExecutionTime) {
        console.warn(`⏱️ TIMEOUT: Generació interrompuda després de 30 segons`);
        break;
      }

      attempts++;
      console.log(`📅 Ronda ${attempts}: ${remainingMatchups.length} partits per programar`);

      remainingMatchups = sortMatchupsByBalance(remainingMatchups, playerStats);

      const scheduledThisRound = [];
      const unscheduledThisRound = [];

      for (const matchup of remainingMatchups) {
        const bestSlot = findBestBalancedSlot(
          matchup, availableDates, playerAvailability, playerStats,
          consecutiveDaysCounter, playerWeeklyMatches
        );

        if (bestSlot) {
          const scheduledMatch = {
            ...matchup,
            data_programada: bestSlot.date,
            hora_inici: bestSlot.time,
            taula_assignada: bestSlot.table,
            estat: 'generat'
          };

          scheduled.push(scheduledMatch);
          scheduledThisRound.push(scheduledMatch);

          const matchDate = new Date(bestSlot.date);
          const weekKey = getISOWeekKey(matchDate);

          [matchup.jugador1.soci_numero, matchup.jugador2.soci_numero].forEach(sociNumero => {
            const stats = playerStats.get(sociNumero);
            stats.matchesScheduled++;
            stats.lastMatchDate = matchDate;
            playerAvailability.get(sociNumero).push({ date: matchDate, time: bestSlot.time });

            const currentTableUsage = stats.tableUsage.get(bestSlot.table) || 0;
            stats.tableUsage.set(bestSlot.table, currentTableUsage + 1);

            const weekMap = playerWeeklyMatches.get(sociNumero);
            weekMap.set(weekKey, (weekMap.get(weekKey) || 0) + 1);
          });

          bestSlot.isUsed = true;
        } else {
          unscheduledThisRound.push(matchup);
        }
      }

      remainingMatchups = unscheduledThisRound;

      if (scheduledThisRound.length === 0) {
        console.warn(`⚠️ No s'han pogut programar més partits`);
        console.warn(`   Slots lliures: ${availableDates.filter(s => !s.isUsed).length}`);
        break;
      }

      console.log(`✅ Ronda ${attempts}: ${scheduledThisRound.length} partits programats`);
    }

    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`⏱️ Temps d'execució: ${executionTime}s`);

    // Afegir partits no programats com a pendents (amb motiu si és possible)
    remainingMatchups.forEach(matchup => {
      const reason = checkScheduleIncompatibility(matchup);
      unscheduled.push({
        ...matchup,
        data_programada: null,
        hora_inici: null,
        taula_assignada: null,
        estat: 'pendent_programar',
        motiu: reason || 'Sense slots disponibles dins el període'
      });
    });

    // Fase d'intercanvi: partides flexibles cedeixen lloc a partides no programades
    if (unscheduled.length > 0 && scheduled.length > 0) {
      const swapResult = trySwapFlexibleMatches(
        scheduled, unscheduled, availableDates,
        playerAvailability, playerStats, playerWeeklyMatches, consecutiveDaysCounter, startTime, maxExecutionTime
      );
      // Només actualitzar si el resultat és una referència diferent (hi ha hagut intercanvis)
      if (swapResult.scheduled !== scheduled) {
        scheduled.length = 0;
        scheduled.push(...swapResult.scheduled);
      }
      if (swapResult.unscheduled !== unscheduled) {
        unscheduled.length = 0;
        unscheduled.push(...swapResult.unscheduled);
      }
    }

    console.log(`📊 Resum final:`);
    console.log(`✅ Partits programats: ${scheduled.length}`);
    console.log(`⏳ Partits pendents: ${unscheduled.length}`);
    logPlayerBalance(playerStats);

    // Validació final: verificar que cap jugador té dues partides el mateix dia
    const dayConflicts = validateNoDuplicateDays(scheduled);
    if (dayConflicts.length > 0) {
      console.error(`❌ ALERTA: ${dayConflicts.length} conflictes detectats (jugadors amb 2 partides el mateix dia):`);
      dayConflicts.forEach(c => console.error(`   ${c}`));
    } else {
      console.log(`✅ Validació: cap jugador té dues partides el mateix dia`);
    }

    // Validació: max_partides_per_setmana
    const weekConflicts = validateWeeklyLimits(scheduled);
    if (weekConflicts.length > 0) {
      console.error(`❌ ALERTA: ${weekConflicts.length} conflictes setmanals detectats:`);
      weekConflicts.forEach(c => console.error(`   ${c}`));
    } else {
      console.log(`✅ Validació: cap jugador supera ${calendarConfig.max_partides_per_setmana} partides/setmana`);
    }

    if (scheduled.length > 0) {
      console.log(`\n🔄 Iniciant rebalanceig de taules...`);
      const rebalancedScheduled = rebalanceTableDistribution(scheduled);
      return [...rebalancedScheduled, ...unscheduled];
    }

    return [...scheduled, ...unscheduled];
  }

  // Helper: comprovar si un jugador té +75 anys
  function isPlayerOver75(sociNumero: number): boolean {
    const r = playerRestrictions.get(sociNumero);
    return r?.edat != null && r.edat > 75;
  }

  // Helper: comprovar si un jugador té dies preferits que són exactament 2 i consecutius
  function hasOnly2ConsecutiveDayPrefs(sociNumero: number): boolean {
    const r = playerRestrictions.get(sociNumero);
    const prefs = r?.preferencies_dies;
    if (!prefs || prefs.length !== 2) return false;
    const dayOrder = ['dl', 'dt', 'dc', 'dj', 'dv', 'ds', 'dg'];
    const i0 = dayOrder.indexOf(prefs[0]);
    const i1 = dayOrder.indexOf(prefs[1]);
    return Math.abs(i0 - i1) === 1;
  }

  // Helper: comptar parells de dies consecutius existents per un jugador
  // i comprovar si afegir slotDate en crearia un de nou (max 2 parells permesos)
  function wouldExceedConsecutivePairs(busy: any[], slotDate: Date): boolean {
    const DAY = 86400000;
    const busyDays = new Set(busy.map(b => {
      const d = new Date(b.date);
      return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    }));
    const slotTime = new Date(slotDate.getFullYear(), slotDate.getMonth(), slotDate.getDate()).getTime();

    // Comprovar si el slot crea un nou parell consecutiu
    const createsNewPair = busyDays.has(slotTime - DAY) || busyDays.has(slotTime + DAY);
    if (!createsNewPair) return false;

    // Comptar parells consecutius existents (sense el slot)
    const sortedDays = [...busyDays].sort((a, b) => a - b);
    let existingPairs = 0;
    for (let i = 0; i < sortedDays.length - 1; i++) {
      if (sortedDays[i + 1] - sortedDays[i] === DAY) existingPairs++;
    }

    return existingPairs >= 2;
  }

  // Helper: comprovar si afegir slotDate crearia 3 dies consecutius amb partides
  function wouldCreate3ConsecutiveDays(busy: any[], slotDate: Date): boolean {
    const slotTime = new Date(slotDate.getFullYear(), slotDate.getMonth(), slotDate.getDate()).getTime();
    const DAY = 86400000;
    const busyDays = new Set(busy.map(b => {
      const d = new Date(b.date);
      return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    }));

    const hasD_2 = busyDays.has(slotTime - 2 * DAY);
    const hasD_1 = busyDays.has(slotTime - DAY);
    const hasD1 = busyDays.has(slotTime + DAY);
    const hasD2 = busyDays.has(slotTime + 2 * DAY);

    if (hasD_2 && hasD_1) return true;
    if (hasD_1 && hasD1) return true;
    if (hasD1 && hasD2) return true;

    return false;
  }

  // Comprovar si un jugador té restriccions de dies o hores
  function isFlexiblePlayer(sociNumero) {
    const r = playerRestrictions.get(sociNumero);
    if (!r) return true;
    const hasDayPrefs = r.preferencies_dies?.length > 0;
    const hasTimePrefs = r.preferencies_hores?.length > 0;
    return !hasDayPrefs && !hasTimePrefs;
  }

  // Comprovar si un slot compleix TOTES les restriccions dures per un matchup
  // (excloent slot.isUsed, que es gestiona externament)
  function slotPassesHardConstraints(slot, matchup, playerAvailability, playerWeeklyMatches, excludeMatchId = null) {
    const p1Id = matchup.jugador1.soci_numero;
    const p2Id = matchup.jugador2.soci_numero;
    const p1Restrictions = playerRestrictions.get(p1Id);
    const p2Restrictions = playerRestrictions.get(p2Id);
    const dateStr = slot.date.toISOString().split('T')[0];
    const dayOfWeek = getDayOfWeekCode(slot.date.getDay());

    // Mateix dia (excloent la partida que s'està movent)
    const p1Busy = (playerAvailability.get(p1Id) || []).filter(b =>
      !excludeMatchId || b.matchId !== excludeMatchId
    );
    const p2Busy = (playerAvailability.get(p2Id) || []).filter(b =>
      !excludeMatchId || b.matchId !== excludeMatchId
    );

    if (p1Busy.some(b => b.date.toISOString().split('T')[0] === dateStr)) return false;
    if (p2Busy.some(b => b.date.toISOString().split('T')[0] === dateStr)) return false;

    // Jugadors +75 anys: no dies consecutius (excepte si dies preferits són 2 consecutius)
    const slotTime75h = new Date(slot.date.getFullYear(), slot.date.getMonth(), slot.date.getDate()).getTime();
    const DAY75h = 86400000;
    for (const [pid, busy] of [[p1Id, p1Busy], [p2Id, p2Busy]] as [number, any[]][]) {
      if (isPlayerOver75(pid) && !hasOnly2ConsecutiveDayPrefs(pid)) {
        const hasAdjacent = busy.some(b => {
          const bTime = new Date(b.date.getFullYear(), b.date.getMonth(), b.date.getDate()).getTime();
          return Math.abs(bTime - slotTime75h) === DAY75h;
        });
        if (hasAdjacent) return false;
      }
    }

    // 3 dies consecutius (si max_partides_per_setmana < 5)
    if (calendarConfig.max_partides_per_setmana < 5) {
      const slotTime = new Date(slot.date.getFullYear(), slot.date.getMonth(), slot.date.getDate()).getTime();
      const DAY = 86400000;
      for (const busy of [p1Busy, p2Busy]) {
        const busyDays = new Set(busy.map(b => {
          const d = new Date(b.date);
          return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        }));
        if ((busyDays.has(slotTime - 2*DAY) && busyDays.has(slotTime - DAY)) ||
            (busyDays.has(slotTime - DAY) && busyDays.has(slotTime + DAY)) ||
            (busyDays.has(slotTime + DAY) && busyDays.has(slotTime + 2*DAY))) {
          return false;
        }
      }
    }

    // Max 2 parells de dies consecutius per jugador
    for (const [pid, busy] of [[p1Id, p1Busy], [p2Id, p2Busy]] as [number, any[]][]) {
      if (!hasOnly2ConsecutiveDayPrefs(pid) && wouldExceedConsecutivePairs(busy, slot.date)) {
        return false;
      }
    }

    // DUR: Setmanal
    const weekKey = getISOWeekKey(slot.date);
    const maxWeekly = calendarConfig.max_partides_per_setmana;
    let p1Week = playerWeeklyMatches.get(p1Id)?.get(weekKey) || 0;
    let p2Week = playerWeeklyMatches.get(p2Id)?.get(weekKey) || 0;
    if (p1Week >= maxWeekly || p2Week >= maxWeekly) return false;

    // Dies
    if (p1Restrictions?.preferencies_dies?.length > 0 &&
        !p1Restrictions.preferencies_dies.includes(dayOfWeek)) return false;
    if (p2Restrictions?.preferencies_dies?.length > 0 &&
        !p2Restrictions.preferencies_dies.includes(dayOfWeek)) return false;

    // Hores
    if (p1Restrictions?.preferencies_hores?.length > 0 &&
        !p1Restrictions.preferencies_hores.includes(slot.time)) return false;
    if (p2Restrictions?.preferencies_hores?.length > 0 &&
        !p2Restrictions.preferencies_hores.includes(slot.time)) return false;

    // Restriccions especials
    if (p1Restrictions?.restriccions_especials &&
        isDateRestricted(slot.date, p1Restrictions.restriccions_especials)) return false;
    if (p2Restrictions?.restriccions_especials &&
        isDateRestricted(slot.date, p2Restrictions.restriccions_especials)) return false;

    return true;
  }

  // Fase d'intercanvi: partides flexibles (sense restriccions de dies/hores) cedeixen el seu slot
  // a partides no programades, i busquen un nou slot per elles mateixes
  function trySwapFlexibleMatches(scheduled, unscheduled, availableDates, playerAvailability, playerStats, playerWeeklyMatches, consecutiveDaysCounter, startTime, maxExecutionTime) {
    // Filtrar partides no programades que NO són incompatibles (tenen motiu d'incompatibilitat)
    const swappableUnscheduled = unscheduled.filter(m => !checkScheduleIncompatibility(m));
    if (swappableUnscheduled.length === 0) {
      console.log(`🔄 Intercanvi: cap partida pendent és compatible, no es fan intercanvis`);
      return { scheduled, unscheduled };
    }

    // Identificar partides flexibles (ambdós jugadors sense restriccions de dies/hores)
    const flexibleScheduled = scheduled.filter(m =>
      isFlexiblePlayer(m.jugador1.soci_numero) && isFlexiblePlayer(m.jugador2.soci_numero)
    );

    console.log(`\n🔄 Fase d'intercanvi:`);
    console.log(`   Partides pendents compatibles: ${swappableUnscheduled.length}`);
    console.log(`   Partides flexibles programades: ${flexibleScheduled.length}`);

    if (flexibleScheduled.length === 0) {
      console.log(`   Cap partida flexible disponible per intercanvi`);
      return { scheduled, unscheduled };
    }

    let swapCount = 0;
    const newScheduled = [...scheduled];
    const newUnscheduled = [...unscheduled];

    for (let ui = newUnscheduled.length - 1; ui >= 0; ui--) {
      if (Date.now() - startTime > maxExecutionTime) break;

      const pendingMatch = newUnscheduled[ui];
      // Saltar partides incompatibles
      if (checkScheduleIncompatibility(pendingMatch)) continue;

      const p1Id = pendingMatch.jugador1.soci_numero;
      const p2Id = pendingMatch.jugador2.soci_numero;

      // Buscar una partida flexible el slot de la qual serveixi per la partida pendent
      for (let si = 0; si < newScheduled.length; si++) {
        const flexMatch = newScheduled[si];
        // Només considerar partides flexibles
        if (!isFlexiblePlayer(flexMatch.jugador1.soci_numero) ||
            !isFlexiblePlayer(flexMatch.jugador2.soci_numero)) continue;

        const candidateSlot = {
          date: flexMatch.data_programada,
          time: flexMatch.hora_inici,
          table: flexMatch.taula_assignada
        };

        // 1. El slot de la partida flexible serveix per la partida pendent?
        // Primer: treure temporalment la partida flexible de les estructures
        const flexP1Id = flexMatch.jugador1.soci_numero;
        const flexP2Id = flexMatch.jugador2.soci_numero;
        const flexDateStr = candidateSlot.date.toISOString().split('T')[0];
        const flexWeekKey = getISOWeekKey(candidateSlot.date);

        // Simular que la partida flexible no existeix
        const removeFromAvailability = (playerId, dateStr) => {
          const busy = playerAvailability.get(playerId);
          if (!busy) return -1;
          const idx = busy.findIndex(b => b.date.toISOString().split('T')[0] === dateStr);
          if (idx >= 0) busy.splice(idx, 1);
          return idx;
        };
        const removeFromWeekly = (playerId, weekKey) => {
          const weekMap = playerWeeklyMatches.get(playerId);
          if (!weekMap) return;
          const count = weekMap.get(weekKey) || 0;
          if (count > 1) weekMap.set(weekKey, count - 1);
          else weekMap.delete(weekKey);
        };

        // Treure la partida flexible temporalment
        removeFromAvailability(flexP1Id, flexDateStr);
        removeFromAvailability(flexP2Id, flexDateStr);
        removeFromWeekly(flexP1Id, flexWeekKey);
        removeFromWeekly(flexP2Id, flexWeekKey);

        // Comprovar si el slot serveix per la partida pendent
        const pendingFits = slotPassesHardConstraints(
          candidateSlot, pendingMatch, playerAvailability, playerWeeklyMatches
        );

        if (pendingFits) {
          // 2. Buscar un nou slot per la partida flexible
          const flexMatchup = {
            jugador1: flexMatch.jugador1,
            jugador2: flexMatch.jugador2,
            categoria_id: flexMatch.categoria_id,
            categoria_nom: flexMatch.categoria_nom
          };

          // Alliberar el slot original
          const originalSlot = availableDates.find(s =>
            s.date.toISOString().split('T')[0] === flexDateStr &&
            s.time === candidateSlot.time &&
            s.table === candidateSlot.table
          );
          if (originalSlot) originalSlot.isUsed = false;

          const newSlotForFlex = findBestBalancedSlot(
            flexMatchup, availableDates, playerAvailability, playerStats,
            consecutiveDaysCounter, playerWeeklyMatches
          );

          if (newSlotForFlex) {
            // Intercanvi reeixit!
            // Marcar el nou slot de la flexible com a usat
            newSlotForFlex.isUsed = true;

            // Actualitzar la partida flexible amb el nou slot
            newScheduled[si] = {
              ...flexMatch,
              data_programada: newSlotForFlex.date,
              hora_inici: newSlotForFlex.time,
              taula_assignada: newSlotForFlex.table
            };

            // Registrar la flexible al nou lloc
            const newFlexDate = new Date(newSlotForFlex.date);
            const newFlexWeekKey = getISOWeekKey(newFlexDate);
            [flexP1Id, flexP2Id].forEach(pid => {
              playerAvailability.get(pid).push({ date: newFlexDate, time: newSlotForFlex.time });
              const wm = playerWeeklyMatches.get(pid);
              wm.set(newFlexWeekKey, (wm.get(newFlexWeekKey) || 0) + 1);
            });

            // Marcar el slot original com a usat per la partida pendent
            if (originalSlot) originalSlot.isUsed = true;

            // Programar la partida pendent al slot alliberat
            const scheduledPending = {
              ...pendingMatch,
              data_programada: candidateSlot.date,
              hora_inici: candidateSlot.time,
              taula_assignada: candidateSlot.table,
              estat: 'generat',
              motiu: undefined
            };
            newScheduled.push(scheduledPending);

            // Registrar la pendent
            const pendDate = new Date(candidateSlot.date);
            const pendWeekKey = getISOWeekKey(pendDate);
            [p1Id, p2Id].forEach(pid => {
              playerAvailability.get(pid).push({ date: pendDate, time: candidateSlot.time });
              const wm = playerWeeklyMatches.get(pid);
              wm.set(pendWeekKey, (wm.get(pendWeekKey) || 0) + 1);
              const stats = playerStats.get(pid);
              if (stats) stats.matchesScheduled++;
            });

            // Treure de la llista de pendents
            newUnscheduled.splice(ui, 1);
            swapCount++;

            console.log(`   ✅ Intercanvi #${swapCount}: ${pendingMatch.jugador1.soci.nom} vs ${pendingMatch.jugador2.soci.nom} ← slot de ${flexMatch.jugador1.soci.nom} vs ${flexMatch.jugador2.soci.nom}`);
            break; // Següent partida pendent
          } else {
            // No s'ha trobat nou slot per la flexible, desfer
            if (originalSlot) originalSlot.isUsed = true;
            // Restaurar la flexible a les estructures
            [flexP1Id, flexP2Id].forEach(pid => {
              playerAvailability.get(pid).push({ date: candidateSlot.date, time: candidateSlot.time });
              const wm = playerWeeklyMatches.get(pid);
              wm.set(flexWeekKey, (wm.get(flexWeekKey) || 0) + 1);
            });
          }
        } else {
          // El slot no serveix per la pendent, restaurar la flexible
          [flexP1Id, flexP2Id].forEach(pid => {
            playerAvailability.get(pid).push({ date: candidateSlot.date, time: candidateSlot.time });
            const wm = playerWeeklyMatches.get(pid);
            wm.set(flexWeekKey, (wm.get(flexWeekKey) || 0) + 1);
          });
        }
      }
    }

    console.log(`   🔄 Total intercanvis realitzats: ${swapCount}`);
    return { scheduled: newScheduled, unscheduled: newUnscheduled };
  }

  // Validar que cap jugador juga 2 partides el mateix dia
  function validateNoDuplicateDays(matches) {
    const playerDays = new Map(); // playerId -> Set<dateStr>
    const conflicts = [];

    matches.forEach(match => {
      if (!match.data_programada) return;
      const dateStr = new Date(match.data_programada).toISOString().split('T')[0];

      [match.jugador1, match.jugador2].forEach(jugador => {
        const sn = jugador.soci_numero;
        if (!playerDays.has(sn)) playerDays.set(sn, new Set());
        const days = playerDays.get(sn);
        if (days.has(dateStr)) {
          conflicts.push(`${jugador.soci.nom} ${jugador.soci.cognoms} té 2 partides el ${dateStr}`);
        }
        days.add(dateStr);
      });
    });

    return conflicts;
  }

  // Validar que cap jugador supera max_partides_per_setmana (amb marge +1 si max < 5)
  function validateWeeklyLimits(matches) {
    const playerWeeks = new Map();
    const conflicts = [];
    const maxPerWeek = calendarConfig.max_partides_per_setmana;
    const hardLimit = maxPerWeek >= 5 ? maxPerWeek : maxPerWeek + 1;

    matches.forEach(match => {
      if (!match.data_programada) return;
      const weekKey = getISOWeekKey(new Date(match.data_programada));

      [match.jugador1, match.jugador2].forEach(jugador => {
        const sn = jugador.soci_numero;
        if (!playerWeeks.has(sn)) playerWeeks.set(sn, new Map());
        const weeks = playerWeeks.get(sn);
        const count = (weeks.get(weekKey) || 0) + 1;
        weeks.set(weekKey, count);
        if (count > hardLimit) {
          conflicts.push(`❌ ${jugador.soci.nom} ${jugador.soci.cognoms} té ${count} partides a la setmana ${weekKey} (supera límit dur ${hardLimit})`);
        } else if (count > maxPerWeek) {
          conflicts.push(`⚠️ ${jugador.soci.nom} ${jugador.soci.cognoms} té ${count} partides a la setmana ${weekKey} (supera nominal ${maxPerWeek}, dins marge)`);
        }
      });
    });

    return conflicts;
  }

  // Funció per rebalancejar la distribució de taules després de la generació
  function rebalanceTableDistribution(matches: any[], maxPercentage: number = 0.60) {
    console.log(`🎱 Analitzant distribució de taules per ${matches.length} partits...`);
    
    // Calcular estadístiques actuals de taules per jugador
    const playerTableStats = new Map();
    
    matches.forEach(match => {
      // Jugador 1
      if (!playerTableStats.has(match.jugador1.soci_numero)) {
        playerTableStats.set(match.jugador1.soci_numero, {
          total: 0,
          tables: new Map(),
          matches: []
        });
      }
      const stats1 = playerTableStats.get(match.jugador1.soci_numero);
      stats1.total++;
      stats1.tables.set(match.taula_assignada, (stats1.tables.get(match.taula_assignada) || 0) + 1);
      stats1.matches.push({ match, playerRole: 1 });

      // Jugador 2
      if (!playerTableStats.has(match.jugador2.soci_numero)) {
        playerTableStats.set(match.jugador2.soci_numero, {
          total: 0,
          tables: new Map(),
          matches: []
        });
      }
      const stats2 = playerTableStats.get(match.jugador2.soci_numero);
      stats2.total++;
      stats2.tables.set(match.taula_assignada, (stats2.tables.get(match.taula_assignada) || 0) + 1);
      stats2.matches.push({ match, playerRole: 2 });
    });
    
    // Identificar jugadors que violen les restriccions
    const playersExceedingLimit = [];
    const playersNeedingMinimum = [];
    
    playerTableStats.forEach((stats, playerId) => {
      // Restricció 1: Percentatge màxim del 60%
      stats.tables.forEach((count, table) => {
        const percentage = count / stats.total;
        if (percentage > maxPercentage && stats.total >= 3) {
          playersExceedingLimit.push({ playerId, table, count, percentage, total: stats.total, type: 'max' });
        }
      });
      
      // Restricció 2: Mínim de partits per taula segons total
      const totalMatches = stats.total;
      let minPerTable = 0;
      
      if (totalMatches >= 12) {
        minPerTable = 3;
      } else if (totalMatches >= 8) {
        minPerTable = 2;
      }
      
      if (minPerTable > 0) {
        // Obtenir totes les taules disponibles (1, 2, 3)
        const availableTables = [1, 2, 3];
        availableTables.forEach(table => {
          const count = stats.tables.get(table) || 0;
          if (count < minPerTable) {
            playersNeedingMinimum.push({ 
              playerId, 
              table, 
              count, 
              needed: minPerTable, 
              total: totalMatches,
              type: 'min'
            });
          }
        });
      }
    });
    
    const totalIssues = playersExceedingLimit.length + playersNeedingMinimum.length;
    
    if (totalIssues === 0) {
      console.log(`✅ Cap jugador viola les restriccions de taules. No cal rebalanceig.`);
      return matches;
    }
    
    console.log(`⚠️ ${totalIssues} problemes detectats:`);
    console.log(`   - ${playersExceedingLimit.length} casos superen el ${(maxPercentage * 100).toFixed(0)}%`);
    console.log(`   - ${playersNeedingMinimum.length} casos necessiten mínim de partits`);
    
    let swapsPerformed = 0;
    const maxSwaps = 200; // Límit de seguretat augmentat
    
    // Prioritzar solucionar mínims abans que màxims
    const allIssues = [...playersNeedingMinimum, ...playersExceedingLimit];
    
    // Intentar intercanviar partides per cada problema detectat
    for (const issue of allIssues) {
      if (swapsPerformed >= maxSwaps) break;
      
      const playerStats = playerTableStats.get(issue.playerId);
      
      if (issue.type === 'min') {
        // Jugador necessita MÉS partits a aquesta taula
        console.log(`  Jugador té ${issue.count} partits a taula ${issue.table}, necessita mínim ${issue.needed} (total: ${issue.total})`);
        
        // Buscar partits d'aquest jugador a altres taules per moure'ls aquí
        const otherTableMatches = playerStats.matches
          .filter(m => m.match.taula_assignada !== issue.table)
          .map(m => m.match);
        
        for (const sourceMatch of otherTableMatches) {
          if (swapsPerformed >= maxSwaps) break;
          
          const matchDate = sourceMatch.data_programada.toISOString().split('T')[0];
          const matchTime = sourceMatch.hora_inici;
          
          // Buscar un partit del mateix dia/hora a la taula desitjada
          for (const targetMatch of matches) {
            if (targetMatch === sourceMatch) continue;
            if (targetMatch.taula_assignada !== issue.table) continue;
            
            const targetDate = targetMatch.data_programada.toISOString().split('T')[0];
            if (targetDate !== matchDate || targetMatch.hora_inici !== matchTime) continue;
            
            // Verificar que l'intercanvi millori el mínim sense crear problemes
            const wouldImproveMinimum = wouldSwapImproveMinimum(
              sourceMatch, targetMatch, issue.playerId, playerTableStats
            );
            
            if (wouldImproveMinimum) {
              // Intercanviar taules
              const tempTable = sourceMatch.taula_assignada;
              sourceMatch.taula_assignada = targetMatch.taula_assignada;
              targetMatch.taula_assignada = tempTable;
              
              // Actualitzar estadístiques
              updateStatsAfterSwap(sourceMatch, targetMatch, tempTable, playerTableStats);
              
              swapsPerformed++;
              console.log(`    ✓ Intercanvi ${swapsPerformed} (mínim): Taules ${tempTable} ↔ ${targetMatch.taula_assignada} (${matchDate} ${matchTime})`);
              
              // Recomprovar si ja tenim el mínim
              const currentCount = playerTableStats.get(issue.playerId).tables.get(issue.table) || 0;
              if (currentCount >= issue.needed) {
                console.log(`    ✅ Jugador ja té el mínim a taula ${issue.table}`);
                break;
              }
            }
          }
        }
        
      } else {
        // Jugador té MASSA partits a aquesta taula (restricció màxim 60%)
        const problematicMatches = playerStats.matches
          .filter(m => m.match.taula_assignada === issue.table)
          .map(m => m.match);
        
        console.log(`  Jugador té ${issue.count} partits a taula ${issue.table} (${(issue.percentage * 100).toFixed(1)}%)`);
        
        // Buscar candidats per intercanviar (mateix dia i hora, taula diferent)
        for (const problematicMatch of problematicMatches) {
          if (swapsPerformed >= maxSwaps) break;
          
          const matchDate = problematicMatch.data_programada.toISOString().split('T')[0];
          const matchTime = problematicMatch.hora_inici;
          
          // Buscar un partit del mateix dia/hora/taula diferent
          for (const candidateMatch of matches) {
            if (candidateMatch === problematicMatch) continue;
            if (candidateMatch.taula_assignada === issue.table) continue;
            
            const candidateDate = candidateMatch.data_programada.toISOString().split('T')[0];
            if (candidateDate !== matchDate || candidateMatch.hora_inici !== matchTime) continue;
            
            // Verificar que l'intercanvi millori la situació
            const wouldImprove = wouldSwapImprove(
              problematicMatch, candidateMatch, issue.playerId, playerTableStats, maxPercentage
            );
            
            if (wouldImprove) {
              // Intercanviar taules
              const tempTable = problematicMatch.taula_assignada;
              problematicMatch.taula_assignada = candidateMatch.taula_assignada;
              candidateMatch.taula_assignada = tempTable;
              
              // Actualitzar estadístiques
              updateStatsAfterSwap(problematicMatch, candidateMatch, tempTable, playerTableStats);
              
              swapsPerformed++;
              console.log(`    ✓ Intercanvi ${swapsPerformed} (màxim): Taules ${tempTable} ↔ ${candidateMatch.taula_assignada} (${matchDate} ${matchTime})`);
              break;
            }
          }
          
          // Recomprovar si el jugador encara supera el límit
          const currentCount = playerTableStats.get(issue.playerId).tables.get(issue.table) || 0;
          const currentPercentage = currentCount / playerStats.total;
          if (currentPercentage <= maxPercentage) {
            console.log(`    ✅ Jugador ja no supera el límit a taula ${issue.table}`);
            break;
          }
        }
      }
    }
    
    console.log(`🔄 Rebalanceig completat: ${swapsPerformed} intercanvis realitzats\n`);
    
    return matches;
  }
  
  // Verificar si un intercanvi milloraria per aconseguir el mínim
  function wouldSwapImproveMinimum(sourceMatch: any, targetMatch: any, playerId: number, stats: Map<any, any>) {
    const playerStats = stats.get(playerId);
    if (!playerStats) return false;
    
    const sourceTable = sourceMatch.taula_assignada;
    const targetTable = targetMatch.taula_assignada;
    
    const sourceCount = playerStats.tables.get(sourceTable) || 0;
    const targetCount = playerStats.tables.get(targetTable) || 0;
    
    // L'intercanvi és bo si:
    // 1. Augmenta el comptador a la taula objectiu (on necessitem més partits)
    // 2. No deixa la taula origen per sota d'un mínim segur
    const totalMatches = playerStats.total;
    let minPerTable = 0;
    
    if (totalMatches >= 12) minPerTable = 3;
    else if (totalMatches >= 8) minPerTable = 2;
    
    const sourceAfterSwap = sourceCount - 1;
    const targetAfterSwap = targetCount + 1;
    
    // Només fer l'intercanvi si no deixem l'origen per sota del mínim
    return sourceAfterSwap >= minPerTable || sourceCount > targetCount;
  }
  
  // Verificar si un intercanvi milloraria la distribució (per màxims)
  function wouldSwapImprove(match1: any, match2: any, playerId: number, stats: Map<any, any>, maxPercentage: number) {
    // Comprovar si l'intercanvi millora la distribució per al jugador problemàtic
    const playerStats = stats.get(playerId);
    if (!playerStats) return false;
    
    const currentTable = match1.taula_assignada;
    const newTable = match2.taula_assignada;
    
    const currentCount = playerStats.tables.get(currentTable) || 0;
    const newCount = playerStats.tables.get(newTable) || 0;
    
    // Verificar mínims també
    const totalMatches = playerStats.total;
    let minPerTable = 0;
    if (totalMatches >= 12) minPerTable = 3;
    else if (totalMatches >= 8) minPerTable = 2;
    
    // L'intercanvi millora si redueix l'ús de la taula problemàtica
    // i no crea un nou problema a l'altra taula ni viola els mínims
    const newPercentageAtCurrent = (currentCount - 1) / totalMatches;
    const newPercentageAtNew = (newCount + 1) / totalMatches;
    const currentCountAfterSwap = currentCount - 1;
    
    return newPercentageAtNew <= maxPercentage && 
           newPercentageAtCurrent < (currentCount / totalMatches) &&
           (currentCountAfterSwap >= minPerTable || minPerTable === 0);
  }
  
  // Actualitzar estadístiques després d'un intercanvi
  function updateStatsAfterSwap(match1: any, match2: any, originalTable1: number, stats: Map<any, any>) {
    // Actualitzar per tots els jugadors involucrats
    const players = [
      match1.jugador1.soci_numero,
      match1.jugador2.soci_numero,
      match2.jugador1.soci_numero,
      match2.jugador2.soci_numero
    ];

    players.forEach(sociNumero => {
      const playerStats = stats.get(sociNumero);
      if (!playerStats) return;
      
      // Recalcular comptadors de taules
      playerStats.tables.clear();
      playerStats.matches.forEach(({ match }) => {
        const table = match.taula_assignada;
        playerStats.tables.set(table, (playerStats.tables.get(table) || 0) + 1);
      });
    });
  }

  // Ordenar enfrontaments per equilibri: prioritzar jugadors amb menys partits programats
  // Calcular la dificultat de programació d'un enfrontament
  // Més restriccions = menys slots possibles = més difícil = prioritat més alta
  function getMatchupDifficulty(matchup) {
    let difficulty = 0;
    const p1 = playerRestrictions.get(matchup.jugador1.soci_numero);
    const p2 = playerRestrictions.get(matchup.jugador2.soci_numero);

    const totalConfigDays = calendarConfig.dies_setmana.length;
    const totalConfigHours = calendarConfig.hores_disponibles.length;

    // Restriccions de dies: menys dies disponibles = més difícil
    const p1Days = p1?.preferencies_dies?.length > 0 ? p1.preferencies_dies : null;
    const p2Days = p2?.preferencies_dies?.length > 0 ? p2.preferencies_dies : null;
    if (p1Days && p2Days) {
      const commonDays = p1Days.filter(d => p2Days.includes(d) && calendarConfig.dies_setmana.includes(d));
      difficulty += (totalConfigDays - commonDays.length) * 10;
    } else if (p1Days) {
      const validDays = p1Days.filter(d => calendarConfig.dies_setmana.includes(d));
      difficulty += (totalConfigDays - validDays.length) * 5;
    } else if (p2Days) {
      const validDays = p2Days.filter(d => calendarConfig.dies_setmana.includes(d));
      difficulty += (totalConfigDays - validDays.length) * 5;
    }

    // Restriccions d'hores: menys hores disponibles = més difícil
    const p1Hours = p1?.preferencies_hores?.length > 0 ? p1.preferencies_hores : null;
    const p2Hours = p2?.preferencies_hores?.length > 0 ? p2.preferencies_hores : null;
    if (p1Hours && p2Hours) {
      const commonHours = p1Hours.filter(h => p2Hours.includes(h) && calendarConfig.hores_disponibles.includes(h));
      difficulty += (totalConfigHours - commonHours.length) * 15;
    } else if (p1Hours) {
      const validHours = p1Hours.filter(h => calendarConfig.hores_disponibles.includes(h));
      difficulty += (totalConfigHours - validHours.length) * 8;
    } else if (p2Hours) {
      const validHours = p2Hours.filter(h => calendarConfig.hores_disponibles.includes(h));
      difficulty += (totalConfigHours - validHours.length) * 8;
    }

    // Restriccions especials: si tenen períodes bloquejats, més difícil
    if (p1?.restriccions_especials) difficulty += 5;
    if (p2?.restriccions_especials) difficulty += 5;

    return difficulty;
  }

  function sortMatchupsByBalance(matchups, playerStats) {
    return [...matchups].sort((a, b) => {
      // Primer criteri: dificultat (partides difícils primer)
      const aDifficulty = getMatchupDifficulty(a);
      const bDifficulty = getMatchupDifficulty(b);
      if (aDifficulty !== bDifficulty) {
        return bDifficulty - aDifficulty; // Més difícils primer
      }

      // Segon criteri: equilibri (jugadors amb menys partits primer)
      const aPlayer1Stats = playerStats.get(a.jugador1.soci_numero);
      const aPlayer2Stats = playerStats.get(a.jugador2.soci_numero);
      const bPlayer1Stats = playerStats.get(b.jugador1.soci_numero);
      const bPlayer2Stats = playerStats.get(b.jugador2.soci_numero);

      const aTotalMatches = aPlayer1Stats.matchesScheduled + aPlayer2Stats.matchesScheduled;
      const bTotalMatches = bPlayer1Stats.matchesScheduled + bPlayer2Stats.matchesScheduled;

      if (aTotalMatches !== bTotalMatches) {
        return aTotalMatches - bTotalMatches;
      }

      return b.prioritat - a.prioritat;
    });
  }

  // Detectar si dos jugadors tenen preferències completament incompatibles
  function checkScheduleIncompatibility(matchup) {
    const p1 = playerRestrictions.get(matchup.jugador1.soci_numero);
    const p2 = playerRestrictions.get(matchup.jugador2.soci_numero);
    const p1Name = `${matchup.jugador1.soci.nom} ${matchup.jugador1.soci.cognoms}`.trim();
    const p2Name = `${matchup.jugador2.soci.nom} ${matchup.jugador2.soci.cognoms}`.trim();

    const p1Days = p1?.preferencies_dies?.length > 0 ? p1.preferencies_dies : null;
    const p2Days = p2?.preferencies_dies?.length > 0 ? p2.preferencies_dies : null;
    const p1Hours = p1?.preferencies_hores?.length > 0 ? p1.preferencies_hores : null;
    const p2Hours = p2?.preferencies_hores?.length > 0 ? p2.preferencies_hores : null;
    const configDays = calendarConfig.dies_setmana;
    const configHours = calendarConfig.hores_disponibles;

    // Comprovar que cada jugador té almenys un dia vàlid al calendari
    if (p1Days) {
      const validDays = p1Days.filter(d => configDays.includes(d));
      if (validDays.length === 0) {
        return `${p1Name} no té cap dia disponible al calendari: prefereix [${p1Days.join(',')}], calendari: [${configDays.join(',')}]`;
      }
    }
    if (p2Days) {
      const validDays = p2Days.filter(d => configDays.includes(d));
      if (validDays.length === 0) {
        return `${p2Name} no té cap dia disponible al calendari: prefereix [${p2Days.join(',')}], calendari: [${configDays.join(',')}]`;
      }
    }

    // Comprovar que cada jugador té almenys una hora vàlida al calendari
    if (p1Hours) {
      const validHours = p1Hours.filter(h => configHours.includes(h));
      if (validHours.length === 0) {
        return `${p1Name} no té cap hora disponible al calendari: prefereix [${p1Hours.join(',')}], calendari: [${configHours.join(',')}]`;
      }
    }
    if (p2Hours) {
      const validHours = p2Hours.filter(h => configHours.includes(h));
      if (validHours.length === 0) {
        return `${p2Name} no té cap hora disponible al calendari: prefereix [${p2Hours.join(',')}], calendari: [${configHours.join(',')}]`;
      }
    }

    // Si ambdós tenen preferències de dies, comprovar intersecció dins el calendari
    if (p1Days && p2Days) {
      const commonDays = p1Days.filter(d => p2Days.includes(d) && configDays.includes(d));
      if (commonDays.length === 0) {
        return `Incompatibilitat de dies: ${p1Name} [${p1Days.join(',')}] vs ${p2Name} [${p2Days.join(',')}]`;
      }
    }

    // Si ambdós tenen preferències d'hores, comprovar intersecció dins el calendari
    if (p1Hours && p2Hours) {
      const commonHours = p1Hours.filter(h => p2Hours.includes(h) && configHours.includes(h));
      if (commonHours.length === 0) {
        return `Incompatibilitat d'horaris: ${p1Name} [${p1Hours.join(',')}] vs ${p2Name} [${p2Hours.join(',')}]`;
      }
    }

    return null; // Compatible
  }

  // Trobar el millor slot per un enfrontament, amb restriccions dures i toves
  function findBestBalancedSlot(matchup, availableDates, playerAvailability, playerStats, consecutiveDaysCounter, playerWeeklyMatches) {
    const player1Id = matchup.jugador1.soci_numero;
    const player2Id = matchup.jugador2.soci_numero;

    const player1Restrictions = playerRestrictions.get(player1Id);
    const player2Restrictions = playerRestrictions.get(player2Id);
    const player1Busy = playerAvailability.get(player1Id) || [];
    const player2Busy = playerAvailability.get(player2Id) || [];

    const player1Stats = playerStats.get(player1Id);
    const player2Stats = playerStats.get(player2Id);

    const filterReasons = {
      used: 0,
      sameDay: 0,
      consecutiveStreak: 0,
      weeklyLimit: 0,
      dayPreference: 0,
      timePreference: 0,
      specialRestrictions: 0,
      total: availableDates.length
    };

    // FILTRES DURS: restriccions que MAI es poden violar
    const validSlots = availableDates.filter(slot => {
      if (slot.isUsed) {
        filterReasons.used++;
        return false;
      }

      const dateStr = slot.date.toISOString().split('T')[0];
      const dayOfWeek = getDayOfWeekCode(slot.date.getDay());

      // DUR: Cap jugador pot jugar 2 partides el mateix dia
      const player1HasMatchThisDay = player1Busy.some(busy =>
        busy.date.toISOString().split('T')[0] === dateStr
      );
      const player2HasMatchThisDay = player2Busy.some(busy =>
        busy.date.toISOString().split('T')[0] === dateStr
      );
      if (player1HasMatchThisDay || player2HasMatchThisDay) {
        filterReasons.sameDay++;
        return false;
      }

      // DUR: Jugadors +75 anys no poden jugar en dies consecutius
      // (excepte si els seus dies preferits són exactament 2 i consecutius)
      const slotTime75 = new Date(slot.date.getFullYear(), slot.date.getMonth(), slot.date.getDate()).getTime();
      const DAY75 = 86400000;
      for (const [pid, busy] of [[player1Id, player1Busy], [player2Id, player2Busy]] as [number, any[]][]) {
        if (isPlayerOver75(pid) && !hasOnly2ConsecutiveDayPrefs(pid)) {
          const hasAdjacent = busy.some(b => {
            const bTime = new Date(b.date.getFullYear(), b.date.getMonth(), b.date.getDate()).getTime();
            return Math.abs(bTime - slotTime75) === DAY75;
          });
          if (hasAdjacent) {
            filterReasons.consecutiveStreak++;
            return false;
          }
        }
      }

      // DUR (si max_partides_per_setmana < 5): No permetre 3 partides en dies consecutius
      if (calendarConfig.max_partides_per_setmana < 5) {
        if (wouldCreate3ConsecutiveDays(player1Busy, slot.date) ||
            wouldCreate3ConsecutiveDays(player2Busy, slot.date)) {
          filterReasons.consecutiveStreak++;
          return false;
        }
      }

      // DUR: Max 2 parells de dies consecutius per jugador
      // (excepte si els seus dies preferits són exactament 2 i consecutius)
      if (!hasOnly2ConsecutiveDayPrefs(player1Id) && wouldExceedConsecutivePairs(player1Busy, slot.date)) {
        filterReasons.consecutiveStreak++;
        return false;
      }
      if (!hasOnly2ConsecutiveDayPrefs(player2Id) && wouldExceedConsecutivePairs(player2Busy, slot.date)) {
        filterReasons.consecutiveStreak++;
        return false;
      }

      // DUR: Màxim de partides per setmana per jugador
      const weekKey = getISOWeekKey(slot.date);
      const p1WeekCount = playerWeeklyMatches.get(player1Id)?.get(weekKey) || 0;
      const p2WeekCount = playerWeeklyMatches.get(player2Id)?.get(weekKey) || 0;
      const maxWeekly = calendarConfig.max_partides_per_setmana;
      if (p1WeekCount >= maxWeekly || p2WeekCount >= maxWeekly) {
        filterReasons.weeklyLimit++;
        return false;
      }

      // DUR: Preferències de dies (si el jugador ha indicat dies, respectar-los)
      if (player1Restrictions?.preferencies_dies?.length > 0 &&
          !player1Restrictions.preferencies_dies.includes(dayOfWeek)) {
        filterReasons.dayPreference++;
        return false;
      }
      if (player2Restrictions?.preferencies_dies?.length > 0 &&
          !player2Restrictions.preferencies_dies.includes(dayOfWeek)) {
        filterReasons.dayPreference++;
        return false;
      }

      // DUR: Preferències d'hores (si el jugador ha indicat hores, respectar-les)
      if (player1Restrictions?.preferencies_hores?.length > 0 &&
          !player1Restrictions.preferencies_hores.includes(slot.time)) {
        filterReasons.timePreference++;
        return false;
      }
      if (player2Restrictions?.preferencies_hores?.length > 0 &&
          !player2Restrictions.preferencies_hores.includes(slot.time)) {
        filterReasons.timePreference++;
        return false;
      }

      // DUR: Restriccions especials (períodes de bloqueig)
      if (player1Restrictions?.restriccions_especials) {
        if (isDateRestricted(slot.date, player1Restrictions.restriccions_especials)) {
          filterReasons.specialRestrictions++;
          return false;
        }
      }
      if (player2Restrictions?.restriccions_especials) {
        if (isDateRestricted(slot.date, player2Restrictions.restriccions_especials)) {
          filterReasons.specialRestrictions++;
          return false;
        }
      }

      return true;
    });

    if (validSlots.length === 0) {
      const freeSlots = availableDates.filter(s => !s.isUsed).length;
      if (freeSlots < 100) {
        console.log(`⚠️ Sense slots per ${matchup.jugador1.soci.nom} vs ${matchup.jugador2.soci.nom}`);
        console.log(`   Lliures: ${freeSlots}, Mateix dia: ${filterReasons.sameDay}, Setmana plena: ${filterReasons.weeklyLimit}, Dies: ${filterReasons.dayPreference}, Hores: ${filterReasons.timePreference}, Restriccions: ${filterReasons.specialRestrictions}`);
      }
      return null;
    }

    // PUNTUACIÓ: Restriccions toves (preferències, no obligatòries)
    // Prioritat principal: omplir els primers dies disponibles (partides ASAP)
    const scoredSlots = validSlots.map(slot => {
      let score = 0;
      const slotDate = new Date(slot.date);

      // --- PROXIMITAT: prioritzar dates més properes (pes dominant) ---
      // Les partides s'han de jugar al més aviat possible
      const daysFromStart = Math.abs((slotDate.getTime() - new Date(dataInici).getTime()) / 86400000);
      score -= daysFromStart * 10; // Penalització forta per cada dia lluny de l'inici

      // --- DIES CONSECUTIUS: penalització (evitar 2 partides en dies seguits) ---
      const hasConsecutive = [player1Busy, player2Busy].some(busy =>
        busy.some(b => {
          const daysDiff = Math.abs(Math.round(
            (new Date(slotDate.getFullYear(), slotDate.getMonth(), slotDate.getDate()).getTime() -
             new Date(b.date.getFullYear(), b.date.getMonth(), b.date.getDate()).getTime()) / 86400000
          ));
          return daysDiff === 1;
        })
      );
      if (hasConsecutive) {
        score -= 80;
        consecutiveDaysCounter.count++;
      }

      // --- ESPAIAT ENTRE PARTIDES: bonificació moderada ---
      // Preferir espaiat però sense que anul·li la proximitat
      const daysBetween1 = player1Stats.lastMatchDate
        ? Math.abs((slotDate.getTime() - player1Stats.lastMatchDate.getTime()) / 86400000)
        : 999;
      const daysBetween2 = player2Stats.lastMatchDate
        ? Math.abs((slotDate.getTime() - player2Stats.lastMatchDate.getTime()) / 86400000)
        : 999;
      const minDaysBetween = Math.min(daysBetween1, daysBetween2);

      if (minDaysBetween >= 3) score += 30;
      else if (minDaysBetween >= 2) score += 20;

      // --- DIVERSIFICACIÓ DE TAULES ---
      const player1TableUsage = player1Stats.tableUsage.get(slot.table) || 0;
      const player2TableUsage = player2Stats.tableUsage.get(slot.table) || 0;
      const totalTableUsage = player1TableUsage + player2TableUsage;

      if (totalTableUsage === 0) score += 15;
      else if (totalTableUsage <= 2) score += 5;

      // --- EQUILIBRI SETMANAL: penalitzar setmanes massa carregades ---
      const weekKey = getISOWeekKey(slotDate);
      const p1WeekCount = playerWeeklyMatches.get(player1Id)?.get(weekKey) || 0;
      const p2WeekCount = playerWeeklyMatches.get(player2Id)?.get(weekKey) || 0;
      score -= (p1WeekCount + p2WeekCount) * 15;

      return { slot, score };
    });

    scoredSlots.sort((a, b) => b.score - a.score);
    return scoredSlots[0].slot;
  }

  // Funció per mostrar l'equilibri dels jugadors
  function logPlayerBalance(playerStats) {
    const stats = Array.from(playerStats.entries()).map(([playerId, stats]) => ({
      playerId,
      matches: stats.matchesScheduled,
      lastMatch: stats.lastMatchDate ? stats.lastMatchDate.toLocaleDateString('ca-ES') : 'Mai'
    }));

    // Agrupar per nombre de partits
    const matchCounts = stats.reduce((acc, player) => {
      acc[player.matches] = (acc[player.matches] || 0) + 1;
      return acc;
    }, {});

    console.log('📊 Distribució de partits per jugador:', matchCounts);

    const minMatches = Math.min(...stats.map(s => s.matches));
    const maxMatches = Math.max(...stats.map(s => s.matches));
    console.log(`📈 Rang: ${minMatches} - ${maxMatches} partits per jugador`);
    
    // Mostrar estadístiques d'ús de taules
    console.log('🎱 Distribució de taules per jugador:');
    let playersExceedingLimit = 0;
    playerStats.forEach((stats, playerId) => {
      if (stats.matchesScheduled > 0) {
        const tableDistribution = {};
        stats.tableUsage.forEach((count, table) => {
          const percentage = (count / stats.matchesScheduled * 100).toFixed(1);
          tableDistribution[`Taula ${table}`] = `${count} (${percentage}%)`;
          if (count / stats.matchesScheduled > 0.60) {
            playersExceedingLimit++;
          }
        });
        console.log(`  Jugador ${playerId.substring(0, 8)}:`, tableDistribution);
      }
    });
    
    if (playersExceedingLimit > 0) {
      console.warn(`⚠️ ${playersExceedingLimit} jugadors superen el 60% en alguna taula`);
    } else {
      console.log(`✅ Cap jugador supera el 60% de partits a la mateixa taula`);
    }
  }

  // Funcions per gestionar períodes de bloqueig
  function addBlockedPeriod() {
    if (!newBlockedStart || !newBlockedEnd) {
      alert('Cal especificar data d\'inici i fi del període de bloqueig');
      return;
    }

    const start = new Date(newBlockedStart);
    const end = new Date(newBlockedEnd);

    if (start > end) {
      alert('La data d\'inici ha de ser anterior a la data de fi');
      return;
    }

    blockedPeriods = [...blockedPeriods, {
      start: newBlockedStart,
      end: newBlockedEnd,
      description: newBlockedDescription || 'Període bloquejat'
    }];

    // Actualitzar dies_festius amb les noves dates
    updateBlockedDatesInConfig();

    // Netejar formulari
    newBlockedStart = '';
    newBlockedEnd = '';
    newBlockedDescription = '';
  }

  function removeBlockedPeriod(index: number) {
    blockedPeriods = blockedPeriods.filter((_, i) => i !== index);
    updateBlockedDatesInConfig();
  }

  function updateBlockedDatesInConfig() {
    // Generar totes les dates dels períodes bloquejats
    const allBlockedDates = new Set<string>();
    
    blockedPeriods.forEach(period => {
      // Utilitzar dates locals sense conversió de timezone
      const [startYear, startMonth, startDay] = period.start.split('-').map(Number);
      const [endYear, endMonth, endDay] = period.end.split('-').map(Number);
      
      const start = new Date(startYear, startMonth - 1, startDay); // Month is 0-indexed
      const end = new Date(endYear, endMonth - 1, endDay);
      
      console.log(`🔍 Processing blocked period: ${period.start} to ${period.end}`);
      
      for (let date = new Date(start); date <= end; date.setDate(date.getDate() + 1)) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const dateStr = `${year}-${month}-${day}`;
        allBlockedDates.add(dateStr);
      }
    });

    console.log(`🚫 Total blocked dates generated (${allBlockedDates.size}):`, Array.from(allBlockedDates));
    
    // Actualitzar dies_festius amb NOMÉS les dates bloquejades
    // (assumint que no hi ha altres festius predefinits per simplicitat)
    calendarConfig.dies_festius = Array.from(allBlockedDates);
    
    console.log(`✅ dies_festius updated with ${calendarConfig.dies_festius.length} blocked dates`);
  }
  
  // Funció per calcular estadístiques d'ús de taules per jugador
  function calculateTableStats() {
    const stats = [];
    const playerMap = new Map();
    
    // Recopilar tots els jugadors únics del calendari proposat
    proposedCalendar.forEach(match => {
      if (match.estat === 'generat') {
        // Jugador 1
        if (!playerMap.has(match.jugador1.soci_numero)) {
          playerMap.set(match.jugador1.soci_numero, {
            soci_numero: match.jugador1.soci_numero,
            nom: match.jugador1.soci.nom,
            cognoms: match.jugador1.soci.cognoms || '',
            taula1: 0,
            taula2: 0,
            taula3: 0,
            total: 0
          });
        }
        const player1Stats = playerMap.get(match.jugador1.soci_numero);
        player1Stats[`taula${match.taula_assignada}`]++;
        player1Stats.total++;

        // Jugador 2
        if (!playerMap.has(match.jugador2.soci_numero)) {
          playerMap.set(match.jugador2.soci_numero, {
            soci_numero: match.jugador2.soci_numero,
            nom: match.jugador2.soci.nom,
            cognoms: match.jugador2.soci.cognoms || '',
            taula1: 0,
            taula2: 0,
            taula3: 0,
            total: 0
          });
        }
        const player2Stats = playerMap.get(match.jugador2.soci_numero);
        player2Stats[`taula${match.taula_assignada}`]++;
        player2Stats.total++;
      }
    });
    
    // Convertir a array, afegir informació de mínims i ordenar per nom
    const result = Array.from(playerMap.values()).map(player => {
      let minRequired = 0;
      if (player.total >= 12) minRequired = 3;
      else if (player.total >= 8) minRequired = 2;
      
      return {
        ...player,
        minRequired
      };
    });
    
    return result.sort((a, b) => {
      const nomA = `${a.nom} ${a.cognoms}`.toLowerCase();
      const nomB = `${b.nom} ${b.cognoms}`.toLowerCase();
      return nomA.localeCompare(nomB, 'ca');
    });
  }

  function generateAvailableDates() {
    const dates = [];
    const [startYear, startMonth, startDay] = dataInici.split('-').map(Number);
    const [endYear, endMonth, endDay] = dataFi.split('-').map(Number);
    
    // Crear dates a migdia per evitar problemes de timezone
    const start = new Date(startYear, startMonth - 1, startDay, 12, 0, 0);
    const end = new Date(endYear, endMonth - 1, endDay, 12, 0, 0);

    console.log(`📅 Generating available dates from ${dataInici} to ${dataFi}`);
    console.log(`📋 Dies de la setmana configurats: ${calendarConfig.dies_setmana.join(', ')}`);
    console.log(`🚫 Blocked dates (dies_festius):`, calendarConfig.dies_festius);

    let totalDays = 0;
    let validDays = 0;
    let blockedDays = 0;
    let daysByWeekday = { dl: 0, dt: 0, dc: 0, dj: 0, dv: 0, ds: 0, dg: 0 };

    // Iterar amb una còpia de la data per evitar modificar la referència
    const currentDate = new Date(start);
    while (currentDate <= end) {
      totalDays++;
      const dayOfWeek = getDayOfWeekCode(currentDate.getDay());

      // Comprovar si el dia està disponible
      if (calendarConfig.dies_setmana.includes(dayOfWeek)) {
        daysByWeekday[dayOfWeek]++;
        
        // Crear dateStr amb format local consistent
        const year = currentDate.getFullYear();
        const month = String(currentDate.getMonth() + 1).padStart(2, '0');
        const day = String(currentDate.getDate()).padStart(2, '0');
        const dateStr = `${year}-${month}-${day}`;
        
        if (!calendarConfig.dies_festius.includes(dateStr)) {
          validDays++;

          // Afegir slots per cada hora i taula
          calendarConfig.hores_disponibles.forEach(hora => {
            for (let taula = 1; taula <= calendarConfig.taules_per_slot; taula++) {
              dates.push({
                date: new Date(currentDate),
                time: hora,
                table: taula,
                isUsed: false
              });
            }
          });
        } else {
          blockedDays++;
          console.log(`🚫 Skipping blocked date: ${dateStr}`);
        }
      }
      
      // Incrementar dia
      currentDate.setDate(currentDate.getDate() + 1);
    }

    console.log(`📊 Date generation summary:`);
    console.log(`   Total days in range: ${totalDays}`);
    console.log(`   Valid days (matching dies_setmana): ${validDays + blockedDays}`);
    console.log(`   Blocked days (in dies_festius): ${blockedDays}`);
    console.log(`   Available days for scheduling: ${validDays}`);
    console.log(`   Total slots generated: ${dates.length}`);
    console.log(`   📅 Dies per dia de la setmana:`, daysByWeekday);

    return dates;
  }


  function getDayOfWeekCode(dayIndex) {
    const days = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds']; // 0=diumenge, 1=dilluns...
    return days[dayIndex];
  }

  function getISOWeekKey(date: Date): string {
    const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    d.setDate(d.getDate() + 4 - (d.getDay() || 7));
    const yearStart = new Date(d.getFullYear(), 0, 1);
    const weekNo = Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
    return `${d.getFullYear()}-W${String(weekNo).padStart(2, '0')}`;
  }

  // Processar restriccions especials de text lliure
  function parseSpecialRestrictions(restrictions) {
    if (!restrictions || restrictions.trim() === '') return [];
    
    const periods = [];
    const currentYear = new Date().getFullYear();
    
    // Mapes dels mesos en català
    const monthMap = {
      'gener': 0, 'febrer': 1, 'març': 2, 'abril': 3, 'maig': 4, 'juny': 5,
      'juliol': 6, 'agost': 7, 'setembre': 8, 'octubre': 9, 'novembre': 10, 'desembre': 11
    };
    
    // Dividir per línies i processar cada línia
    const lines = restrictions.split('\n').map(line => line.trim()).filter(line => line.length > 0);

    for (const line of lines) {
      let found = false;
      
      // Test 0: Períodes "del X de [mes1] al Y de [mes2]" (creua mesos/anys)
      let match = line.match(/del\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)\s+al\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, startDay, startMonth, endDay, endMonth] = match;
        const startMonthNumber = monthMap[startMonth.toLowerCase()];
        const endMonthNumber = monthMap[endMonth.toLowerCase()];
        
        if (startMonthNumber !== undefined && endMonthNumber !== undefined) {
          let startDate = new Date(currentYear, startMonthNumber, parseInt(startDay));
          let endDate = new Date(currentYear, endMonthNumber, parseInt(endDay));
          
          // Si la data final és abans que la inicial, assumir que creua anys
          if (endDate < startDate) {
            endDate = new Date(currentYear + 1, endMonthNumber, parseInt(endDay));
          }
          
          periods.push({ start: startDate, end: endDate });
          found = true;
        }
      }
      
      // Test 1: Períodes "del X al Y de [mes]"
      if (!found) {
        match = line.match(/del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
        if (match) {
          const [, startDay, endDay, monthName] = match;
          const monthNumber = monthMap[monthName.toLowerCase()];
          if (monthNumber !== undefined) {
            const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
            const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
            periods.push({ start: startDate, end: endDate });
            found = true;
          }
        }
      }
      
      // Test 2: Períodes "del X al Y d'[mes]"
      if (!found) {
        match = line.match(/del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+d'([a-zA-Zàèéíòóúç]+)/i);
        if (match) {
          const [, startDay, endDay, monthName] = match;
          const monthNumber = monthMap[monthName.toLowerCase()];
          if (monthNumber !== undefined) {
            const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
            const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
            periods.push({ start: startDate, end: endDate });
            found = true;
          }
        }
      }
      
      // Test 3: DD/MM al DD/MM
      if (!found) {
        match = line.match(/(\d{1,2})\/(\d{1,2})\s+al\s+(\d{1,2})\/(\d{1,2})/i);
        if (match) {
          const [, startDay, startMonth, endDay, endMonth] = match;
          let startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
          let endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
          
          // Si la data final és abans que la inicial, assumir que creua anys (ex: 15/12 al 6/1)
          if (endDate < startDate) {
            endDate = new Date(currentYear + 1, parseInt(endMonth) - 1, parseInt(endDay));
          }
          
          periods.push({ start: startDate, end: endDate });
          found = true;
        }
      }
      
      // Test 4: DD-MM al DD-MM
      if (!found) {
        match = line.match(/(\d{1,2})-(\d{1,2})\s+al\s+(\d{1,2})-(\d{1,2})/i);
        if (match) {
          const [, startDay, startMonth, endDay, endMonth] = match;
          let startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
          let endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
          
          // Si la data final és abans que la inicial, assumir que creua anys
          if (endDate < startDate) {
            endDate = new Date(currentYear + 1, parseInt(endMonth) - 1, parseInt(endDay));
          }
          
          periods.push({ start: startDate, end: endDate });
          found = true;
        }
      }
      
      // Test 5: Dates específiques "X de [mes]"
      if (!found) {
        match = line.match(/(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
        if (match) {
          const [, day, monthName] = match;
          const monthNumber = monthMap[monthName.toLowerCase()];
          if (monthNumber !== undefined) {
            const date = new Date(currentYear, monthNumber, parseInt(day));
            periods.push({ start: date, end: date });
            found = true;
          }
        }
      }
      
      // Test 6: "X [mes]" sense "de"
      if (!found) {
        match = line.match(/(\d{1,2})\s+([a-zA-Zàèéíòóúç]+)/i);
        if (match) {
          const [, day, monthName] = match;
          const monthNumber = monthMap[monthName.toLowerCase()];
          if (monthNumber !== undefined) {
            const date = new Date(currentYear, monthNumber, parseInt(day));
            periods.push({ start: date, end: date });
            found = true;
          }
        }
      }
      
      // Test 7: Multiple dates "X i Y [mes]"
      if (!found) {
        match = line.match(/(\d{1,2})\s+i\s+(\d{1,2})\s+([a-zA-Zàèéíòóúç]+)/i);
        if (match) {
          const [, day1, day2, monthName] = match;
          const monthNumber = monthMap[monthName.toLowerCase()];
          if (monthNumber !== undefined) {
            const date1 = new Date(currentYear, monthNumber, parseInt(day1));
            const date2 = new Date(currentYear, monthNumber, parseInt(day2));
            periods.push({ start: date1, end: date1 });
            periods.push({ start: date2, end: date2 });
            found = true;
          }
        }
      }
      
      if (!found) {
        console.warn('Restricció no reconeguda:', line);
      }
    }

    return periods;
  }
  
  // Parser flexible per dates en diferents formats
  function parseFlexibleDate(dateStr) {
    const currentYear = new Date().getFullYear();
    
    // Provar DD/MM/YYYY, DD-MM-YYYY, DD/MM, DD-MM
    const formats = [
      /^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/,  // DD/MM/YYYY
      /^(\d{1,2})[\/\-](\d{1,2})$/                 // DD/MM (assumir any actual)
    ];
    
    for (const format of formats) {
      const match = dateStr.match(format);
      if (match) {
        const day = parseInt(match[1]);
        const month = parseInt(match[2]) - 1; // JavaScript months are 0-indexed
        const year = match[3] ? parseInt(match[3]) : currentYear;
        
        // Validacions bàsiques
        if (day < 1 || day > 31 || month < 0 || month > 11) {
          continue;
        }
        
        const date = new Date(year, month, day);
        
        // Verificar que la data creada coincideix amb els valors introduïts
        // (JavaScript "arregla" dates invàlides com 32/13/2024)
        if (date.getFullYear() !== year || 
            date.getMonth() !== month || 
            date.getDate() !== day) {
          continue;
        }
        
        return date;
      }
    }
    
    return null;
  }
  
  // Comprovar si una data està dins les restriccions especials (amb cache)
  function isDateRestricted(date, restrictionsText) {
    if (!restrictionsText || restrictionsText.trim() === '') return false;

    // Usar cache per evitar re-parsejar el mateix text milers de vegades
    let restrictions = parsedRestrictionsCache.get(restrictionsText);
    if (!restrictions) {
      restrictions = parseSpecialRestrictions(restrictionsText);
      parsedRestrictionsCache.set(restrictionsText, restrictions);
    }

    const checkDate = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0);

    return restrictions.some(restriction => {
      const startDate = new Date(restriction.start.getFullYear(), restriction.start.getMonth(), restriction.start.getDate(), 0, 0, 0, 0);
      const endDate = new Date(restriction.end.getFullYear(), restriction.end.getMonth(), restriction.end.getDate(), 0, 0, 0, 0);
      return checkDate >= startDate && checkDate <= endDate;
    });
  }

  function calculateProposedEndDate(totalMatches) {
    // Càlcul precís basant-se en la configuració real del club
    const diesPerSetmana = calendarConfig.dies_setmana.length; // dies establerts (normalment 5: dl-dv)
    const horesPerDia = calendarConfig.hores_disponibles.length; // torns (normalment 2: 18:00, 19:00)
    const taulesPerHora = calendarConfig.taules_per_slot; // billars (normalment 3)

    const slotsPerSetmana = diesPerSetmana * horesPerDia * taulesPerHora;
    const slotsPerDia = horesPerDia * taulesPerHora;

    console.log(`📊 Configuració del club:`);
    console.log(`   Dies per setmana: ${diesPerSetmana}`);
    console.log(`   Hores/torns per dia: ${horesPerDia}`);
    console.log(`   Taules/billars per hora: ${taulesPerHora}`);
    console.log(`   Slots per dia: ${slotsPerDia}`);
    console.log(`   Slots per setmana: ${slotsPerSetmana}`);

    // Calcular setmanes necessàries (sense marge)
    const setmanesNecessaries = Math.ceil(totalMatches / slotsPerSetmana);

    const startDate = new Date(dataInici);
    const proposedEndDate = new Date(startDate);

    // Afegir setmanes completes
    proposedEndDate.setDate(proposedEndDate.getDate() + (setmanesNecessaries * 7));

    console.log(`📅 Càlcul de proposta:`);
    console.log(`   Partits totals: ${totalMatches}`);
    console.log(`   Setmanes necessàries: ${setmanesNecessaries}`);
    console.log(`   Data inici: ${startDate.toISOString().split('T')[0]}`);
    console.log(`   Data fi proposada: ${proposedEndDate.toISOString().split('T')[0]}`);
    console.log(`   Capacitat total: ${setmanesNecessaries * slotsPerSetmana} slots`);

    return proposedEndDate;
  }

  function calculateAvailableCapacity() {
    // Calcular slots reals disponibles dins el període establert
    const [startYear, startMonth, startDay] = dataInici.split('-').map(Number);
    const [endYear, endMonth, endDay] = dataFi.split('-').map(Number);
    
    const startDate = new Date(startYear, startMonth - 1, startDay);
    const endDate = new Date(endYear, endMonth - 1, endDay);
    let totalSlots = 0;

    // Iterar per cada dia del període
    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      const dayOfWeek = getDayOfWeekCode(date.getDay());

      // Comprovar si el dia està disponible
      if (calendarConfig.dies_setmana.includes(dayOfWeek)) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const dateStr = `${year}-${month}-${day}`;

        // Comprovar si no és festiu
        if (!calendarConfig.dies_festius.includes(dateStr)) {
          // Afegir slots d'aquest dia
          const slotsPerDia = calendarConfig.hores_disponibles.length * calendarConfig.taules_per_slot;
          totalSlots += slotsPerDia;
        }
      }
    }

    console.log(`🔢 Càlcul de capacitat real:`);
    console.log(`   Dies del període: ${Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24))} dies`);
    console.log(`   Dies vàlids: ${calendarConfig.dies_setmana.join(', ')}`);
    console.log(`   Hores per dia: ${calendarConfig.hores_disponibles.join(', ')}`);
    console.log(`   Taules per hora: ${calendarConfig.taules_per_slot}`);
    console.log(`   Total slots: ${totalSlots}`);

    return totalSlots;
  }

  function calculateEndDate(totalMatches) {
    // Calcular capacitat setmanal
    const diesPerSetmana = calendarConfig.dies_setmana.length;
    const horesPerDia = calendarConfig.hores_disponibles.length;
    const taulesPerHora = calendarConfig.taules_per_slot;

    const slotsPerSetmana = diesPerSetmana * horesPerDia * taulesPerHora;

    // Calcular dies mínims necessaris per programar tots els partits (sense marge)
    const diesMinims = Math.ceil(totalMatches / (slotsPerSetmana / 7)); // dies reals necessaris

    // Afegir 10 dies laborables (excloent caps de setmana)
    const startDate = new Date(dataInici);
    const endDate = new Date(startDate);

    // Afegir dies mínims
    endDate.setDate(endDate.getDate() + diesMinims);

    // Afegir 10 dies laborables addicionals
    let diesLaborablesAfegits = 0;
    while (diesLaborablesAfegits < 10) {
      endDate.setDate(endDate.getDate() + 1);
      const dayOfWeek = endDate.getDay();
      // Comptar només dies laborables (dilluns=1 a divendres=5)
      if (dayOfWeek >= 1 && dayOfWeek <= 5) {
        diesLaborablesAfegits++;
      }
    }

    console.log(`Capacitat setmanal: ${slotsPerSetmana} slots`);
    console.log(`Partits totals: ${totalMatches}`);
    console.log(`Dies mínims necessaris: ${diesMinims}`);
    console.log(`Data inici: ${startDate.toISOString().split('T')[0]}`);
    console.log(`Data fi (amb 10 dies laborables extra): ${endDate.toISOString().split('T')[0]}`);

    return endDate;
  }

  async function saveCalendar() {
    processing = true;

    try {
      // Comprovar conflictes de billar amb partides d'ALTRES events
      const slotsToCheck = proposedCalendar
        .filter(m => m.data_programada && m.hora_inici && m.taula_assignada)
        .map(m => ({
          dia: m.data_programada!.toISOString().split('T')[0],
          hora: m.hora_inici!,
          billar: m.taula_assignada!
        }));

      if (slotsToCheck.length > 0) {
        const dates = [...new Set(slotsToCheck.map(s => s.dia))];
        const { data: existing } = await supabase
          .from('calendari_partides')
          .select('data_programada, hora_inici, taula_assignada')
          .neq('event_id', eventId)
          .in('data_programada::date', dates)
          .not('data_programada', 'is', null)
          .not('hora_inici', 'is', null)
          .not('taula_assignada', 'is', null)
          .or('partida_anullada.is.null,partida_anullada.eq.false')
          .not('estat', 'in', '("jugada","cancel·lada_per_retirada","pendent_programar","postposada","reprogramada")');

        if (existing && existing.length > 0) {
          const occupiedSet = new Set(
            existing.map((e: any) => `${String(e.data_programada).split('T')[0]}|${e.hora_inici}|${e.taula_assignada}`)
          );
          const conflicts = slotsToCheck.filter(s => occupiedSet.has(`${s.dia}|${s.hora}|${s.billar}`));
          if (conflicts.length > 0) {
            const msg = conflicts.slice(0, 5).map(c =>
              `  - ${c.dia} a les ${c.hora}, billar ${c.billar}`
            ).join('\n');
            throw new Error(
              `Hi ha ${conflicts.length} partides que coincideixen amb partides d'altres campionats al mateix billar:\n${msg}` +
              (conflicts.length > 5 ? `\n  ... i ${conflicts.length - 5} més` : '')
            );
          }
        }
      }

      // Eliminar calendari existent
      await supabase
        .from('calendari_partides')
        .delete()
        .eq('event_id', eventId);

      // Inserir nous partits
      const partidesToInsert = proposedCalendar.map(match => ({
        event_id: eventId,
        categoria_id: match.categoria_id,
        jugador1_soci_numero: match.jugador1.soci_numero,
        jugador2_soci_numero: match.jugador2.soci_numero,
        data_programada: match.data_programada?.toISOString() || null,
        hora_inici: match.hora_inici,
        taula_assignada: match.taula_assignada,
        estat: match.estat
      }));

      const { error } = await supabase
        .from('calendari_partides')
        .insert(partidesToInsert);

      if (error) {
        if (error.message?.includes('idx_unique_billar_slot')) {
          throw new Error('No es pot desar: hi ha partides duplicades al mateix billar/hora/dia. Revisa el calendari generat.');
        }
        throw error;
      }

      dispatch('calendarCreated', { matches: partidesToInsert.length });
      showPreview = false;
      proposedCalendar = [];

    } catch (error) {
      console.error('Error desant calendari:', error);
      dispatch('error', { message: formatSupabaseError(error) });
    } finally {
      processing = false;
    }
  }

  async function regenerateCalendar() {
    if (!confirm('Això eliminarà el calendari actual i generarà un de nou. Continuar?')) {
      return;
    }

    try {
      generatingCalendar = true;

      // Eliminar calendari existent
      await supabase
        .from('calendari_partides')
        .delete()
        .eq('event_id', eventId);

      // Generar nou calendari
      await generateCalendar();

    } catch (error) {
      console.error('Error regenerant calendari:', error);
      dispatch('error', { message: formatSupabaseError(error) });
    } finally {
      generatingCalendar = false;
    }
  }

  async function deletePublishedCalendar() {
    try {
      generatingCalendar = true;
      showDeleteConfirmation = false;

      // 1. Despublicar l'esdeveniment
      const { error: updateError } = await supabase
        .from('esdeveniments_club')
        .update({ calendari_publicat: false })
        .eq('id', eventId);

      if (updateError) throw updateError;

      // 2. Eliminar totes les partides del calendari
      const { error: deleteError } = await supabase
        .from('calendari_partides')
        .delete()
        .eq('event_id', eventId);

      if (deleteError) throw deleteError;

      // 3. Resetear l'estat del component
      proposedCalendar = [];
      showPreview = false;
      
      console.log('✅ Calendari publicat esborrat amb èxit');
      dispatch('success', { message: 'Calendari esborrat correctament' });

    } catch (error) {
      console.error('Error esborrant calendari publicat:', error);
      dispatch('error', { message: formatSupabaseError(error) });
    } finally {
      generatingCalendar = false;
    }
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
      <span class="mr-2">📅</span> Generador de Calendaris
    </h3>

    <!-- Configuració del calendari -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label for="data-inici" class="block text-sm font-medium text-gray-700 mb-2">
          Data d'inici
        </label>
        <input
          id="data-inici"
          type="date"
          bind:value={dataInici}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
        />
      </div>

      <div>
        <label for="data-fi" class="block text-sm font-medium text-gray-700 mb-2">
          Data de fi del campionat
        </label>
        <input
          id="data-fi"
          type="date"
          bind:value={dataFi}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Es proposarà automàticament"
        />
        {#if dataFi}
          <p class="mt-1 text-xs text-green-600">
            ✅ Data de fi establerta. Les partides que no càpiguen aniran a la llista de pendents.
          </p>
        {:else}
          <p class="mt-1 text-xs text-gray-500">
            💡 Clica "Generar Calendari" per obtenir una proposta de data de fi segons els partits a disputar
          </p>
        {/if}
      </div>
    </div>

    <!-- Dies de la setmana -->
    <fieldset class="mt-4">
      <legend class="block text-sm font-medium text-gray-700 mb-2">
        Dies disponibles
      </legend>
      <div class="flex flex-wrap gap-2">
        {#each [
          { code: 'dl', name: 'Dilluns' },
          { code: 'dt', name: 'Dimarts' },
          { code: 'dc', name: 'Dimecres' },
          { code: 'dj', name: 'Dijous' },
          { code: 'dv', name: 'Divendres' },
          { code: 'ds', name: 'Dissabte' },
          { code: 'dg', name: 'Diumenge' }
        ] as day}
          <label class="flex items-center">
            <input
              type="checkbox"
              bind:group={calendarConfig.dies_setmana}
              value={day.code}
              class="mr-2 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <span class="text-sm text-gray-700">{day.name}</span>
          </label>
        {/each}
      </div>
    </fieldset>

    <!-- Hores disponibles -->
    <fieldset class="mt-4">
      <legend class="block text-sm font-medium text-gray-700 mb-2">
        Hores disponibles
      </legend>
      <div class="flex flex-wrap gap-2">
        {#each ['17:30', '18:00', '18:30', '19:00', '19:30', '20:00'] as hora}
          <label class="flex items-center">
            <input
              type="checkbox"
              bind:group={calendarConfig.hores_disponibles}
              value={hora}
              class="mr-2 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <span class="text-sm text-gray-700">{hora}</span>
          </label>
        {/each}
      </div>
      <p class="mt-1 text-xs text-gray-500">
        Per defecte: 18:00 i 19:00 (horaris habituals del club)
      </p>
    </fieldset>

    <!-- Configuració avançada -->
    <div class="mt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
      <div>
        <label for="taules-per-hora" class="block text-sm font-medium text-gray-700 mb-2">
          Taules per hora
        </label>
        <input
          id="taules-per-hora"
          type="number"
          min="1"
          max="10"
          bind:value={calendarConfig.taules_per_slot}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div>
        <label for="max-partits-setmana" class="block text-sm font-medium text-gray-700 mb-2">
          Màx partits per setmana
        </label>
        <input
          id="max-partits-setmana"
          type="number"
          min="1"
          max="7"
          bind:value={calendarConfig.max_partides_per_setmana}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div>
        <label for="max-partits-dia" class="block text-sm font-medium text-gray-700 mb-2">
          Màx partits per dia
        </label>
        <input
          id="max-partits-dia"
          type="number"
          min="1"
          max="3"
          bind:value={calendarConfig.max_partides_per_dia}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
    </div>

    <!-- Períodes de bloqueig -->
    <div class="mt-6 border-t border-gray-200 pt-6">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h4 class="text-sm font-medium text-gray-900">Períodes de Bloqueig</h4>
          <p class="text-xs text-gray-500 mt-1">
            Especifica períodes en els quals no es poden programar partides (vacances, Pasqua, etc.)
          </p>
        </div>
        <button
          on:click={() => showBlockedPeriods = !showBlockedPeriods}
          class="px-3 py-1.5 text-sm bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
        >
          {showBlockedPeriods ? 'Amagar' : 'Gestionar Bloquejos'}
        </button>
      </div>

      {#if showBlockedPeriods}
        <!-- Formulari per afegir nou període -->
        <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
          <h5 class="text-sm font-medium text-gray-900 mb-3">Afegir Nou Període de Bloqueig</h5>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div>
              <label for="blocked-start" class="block text-xs font-medium text-gray-700 mb-1">
                Data d'inici
              </label>
              <input
                id="blocked-start"
                type="date"
                bind:value={newBlockedStart}
                class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label for="blocked-end" class="block text-xs font-medium text-gray-700 mb-1">
                Data de fi
              </label>
              <input
                id="blocked-end"
                type="date"
                bind:value={newBlockedEnd}
                class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label for="blocked-description" class="block text-xs font-medium text-gray-700 mb-1">
                Descripció (opcional)
              </label>
              <input
                id="blocked-description"
                type="text"
                bind:value={newBlockedDescription}
                placeholder="Ex: Setmana Santa"
                class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="mt-3">
            <button
              on:click={addBlockedPeriod}
              class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700"
            >
              ➕ Afegir Període
            </button>
          </div>
        </div>

        <!-- Llista de períodes bloquejats -->
        {#if blockedPeriods.length > 0}
          <div class="space-y-2">
            <h5 class="text-sm font-medium text-gray-900">Períodes Bloquejats ({blockedPeriods.length})</h5>
            {#each blockedPeriods as period, index}
              <div class="flex items-center justify-between bg-red-50 border border-red-200 rounded-lg p-3">
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-medium text-gray-900">
                      {new Date(period.start).toLocaleDateString('ca-ES')} - {new Date(period.end).toLocaleDateString('ca-ES')}
                    </span>
                    {#if period.description}
                      <span class="text-xs text-gray-600 italic">({period.description})</span>
                    {/if}
                  </div>
                  <div class="text-xs text-gray-500 mt-1">
                    {Math.ceil((new Date(period.end).getTime() - new Date(period.start).getTime()) / (1000 * 60 * 60 * 24)) + 1} dies bloquejats
                  </div>
                </div>
                <button
                  on:click={() => removeBlockedPeriod(index)}
                  class="ml-3 px-3 py-1 text-sm bg-red-600 text-white rounded hover:bg-red-700"
                >
                  Eliminar
                </button>
              </div>
            {/each}
          </div>
        {:else}
          <div class="text-center py-4 text-sm text-gray-500 bg-gray-50 border border-gray-200 rounded-lg">
            No hi ha períodes de bloqueig definits
          </div>
        {/if}

        <div class="mt-3 p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <div class="flex items-start gap-2">
            <svg class="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <div class="text-xs text-blue-800">
              <strong>Important:</strong> Els períodes bloquejats NO tindran partides programades, però 
              <strong>apareixeran al calendari imprès</strong> com a dates buides, mantenint la continuïtat visual del calendari.
            </div>
          </div>
        </div>
      {/if}
    </div>

    <!-- Jugadors per categoria -->
    {#if playersByCategory.size > 0}
      <div class="mt-6">
        <button
          on:click={() => showPlayers = !showPlayers}
          class="flex items-center gap-2 text-sm font-medium text-gray-700 hover:text-gray-900 mb-3"
        >
          <span class="transform transition-transform {showPlayers ? 'rotate-90' : ''}">&gt;</span>
          Jugadors per Categoria ({Array.from(playersByCategory.values()).reduce((sum, p) => sum + p.length, 0)} jugadors en {playersByCategory.size} categories)
        </button>

        {#if showPlayers}
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {#each Array.from(playersByCategory.entries()) as [categoryId, players]}
              {@const category = categories.find(c => c.id === categoryId)}
              <div class="border border-gray-200 rounded-lg p-3 bg-gray-50">
                <h5 class="font-medium text-gray-900 mb-2 flex items-center justify-between">
                  <span>{category?.nom || 'Desconeguda'}</span>
                  <span class="text-xs bg-blue-100 text-blue-800 px-2 py-0.5 rounded-full">{players.length} jug.</span>
                </h5>
                <div class="space-y-1">
                  {#each players as player}
                    {@const restrictions = playerRestrictions.get(player.soci_numero)}
                    <div class="flex items-center justify-between bg-white rounded px-2 py-1.5 text-sm border border-gray-100">
                      <div class="flex-1 min-w-0">
                        <span class="font-medium text-gray-800 truncate block">{player.soci.nom} {player.soci.cognoms || ''}</span>
                        <div class="flex flex-wrap gap-1 mt-0.5">
                          {#if restrictions?.preferencies_dies?.length > 0}
                            <span class="text-xs text-blue-600">{restrictions.preferencies_dies.join(',')}</span>
                          {/if}
                          {#if restrictions?.preferencies_hores?.length > 0}
                            <span class="text-xs text-green-600">{restrictions.preferencies_hores.join(',')}</span>
                          {/if}
                          {#if restrictions?.restriccions_especials}
                            <span class="text-xs text-red-500" title={restrictions.restriccions_especials}>bloqueig</span>
                          {/if}
                        </div>
                      </div>
                      <select
                        value={categoryId}
                        on:change={(e) => changePlayerCategory(player, categoryId, e.target.value)}
                        class="ml-2 text-xs border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500 py-1"
                      >
                        {#each categories as cat}
                          <option value={cat.id}>{cat.nom}</option>
                        {/each}
                      </select>
                    </div>
                  {/each}
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    {/if}

    <!-- Botons d'acció -->
    <div class="mt-6 flex flex-wrap gap-3">
      {#if !dataFi}
        <button
          on:click={calculateProposal}
          disabled={generatingCalendar || !dataInici}
          class="px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 disabled:bg-gray-400"
        >
          {generatingCalendar ? 'Calculant...' : '💡 Calcular Proposta de Data'}
        </button>
      {:else}
        <button
          on:click={generateCalendar}
          disabled={generatingCalendar || !dataInici}
          class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 disabled:bg-gray-400"
        >
          {generatingCalendar ? 'Generant Calendari...' : 'Generar Calendari'}
        </button>
      {/if}

      <button
        on:click={regenerateCalendar}
        disabled={generatingCalendar}
        class="px-4 py-2 bg-orange-600 text-white text-sm rounded hover:bg-orange-700 disabled:bg-gray-400"
      >
        Regenerar Calendari
      </button>

      <!-- Botó per esborrar calendari publicat -->
      {#if calendariPublicat}
        <button
          on:click={() => showDeleteConfirmation = true}
          disabled={generatingCalendar}
          class="px-4 py-2 bg-red-600 text-white text-sm rounded hover:bg-red-700 disabled:bg-gray-400 flex items-center gap-2"
        >
          🗑️ Esborrar Calendari Publicat
        </button>
      {/if}

      <button
        on:click={() => showRestrictions = !showRestrictions}
        class="px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700"
      >
        {showRestrictions ? 'Amagar' : 'Mostrar'} Restriccions
      </button>

      {#if dataFi}
        <button
          on:click={() => { dataFi = ''; proposedCalendar = []; showPreview = false; }}
          class="px-4 py-2 bg-gray-500 text-white text-sm rounded hover:bg-gray-600"
        >
          🔄 Nova Proposta
        </button>
      {/if}
    </div>

    {#if calendarError}
      <div class="mt-3 p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
        <strong>Error:</strong> {calendarError}
      </div>
    {/if}
  </div>

  <!-- Restriccions dels jugadors -->
  {#if showRestrictions && playerRestrictions.size > 0}
    <div class="bg-white border border-gray-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
        <span class="mr-2">🔍</span> Restriccions dels Jugadors
      </h3>

      <div class="space-y-4">
        {#each Array.from(playersByCategory.entries()) as [categoryId, players]}
          {@const category = categories.find(c => c.id === categoryId)}
          <div class="border border-gray-200 rounded-lg p-4">
            <h4 class="font-medium text-gray-900 mb-3">{category?.nom || 'Categoria desconeguda'}</h4>

            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Jugador</th>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dies Disponibles</th>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Hores Disponibles</th>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Restriccions Especials</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  {#each players as player}
                    {@const restrictions = playerRestrictions.get(player.soci_numero)}
                    <tr>
                      <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                        {restrictions?.soci?.nom || 'Nom no disponible'} {restrictions?.soci?.cognoms || ''}
                        <div class="text-xs text-gray-500">#{player.soci_numero}</div>
                      </td>
                      <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                        {#if restrictions?.preferencies_dies?.length > 0}
                          <div class="flex flex-wrap gap-1">
                            {#each restrictions.preferencies_dies as dia}
                              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                {dia}
                              </span>
                            {/each}
                          </div>
                        {:else}
                          <span class="text-gray-400">Qualsevol dia</span>
                        {/if}
                      </td>
                      <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                        {#if restrictions?.preferencies_hores?.length > 0}
                          <div class="flex flex-wrap gap-1">
                            {#each restrictions.preferencies_hores as hora}
                              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                                {hora}
                              </span>
                            {/each}
                          </div>
                        {:else}
                          <span class="text-gray-400">Qualsevol hora</span>
                        {/if}
                      </td>
                      <td class="px-4 py-2 text-sm text-gray-900">
                        {#if restrictions?.restriccions_especials}
                          {@const periods = parseSpecialRestrictions(restrictions.restriccions_especials)}
                          {#if periods.length > 0}
                            <div class="space-y-1">
                              {#each periods as period}
                                <div class="inline-flex items-center px-2 py-1 rounded text-xs bg-red-100 text-red-800 mr-1 mb-1">
                                  🚫 {period.start.toLocaleDateString('ca-ES', { day: 'numeric', month: 'short' })}
                                  {#if period.start.getTime() !== period.end.getTime()}
                                    - {period.end.toLocaleDateString('ca-ES', { day: 'numeric', month: 'short' })}
                                  {/if}
                                </div>
                              {/each}
                            </div>
                            <div class="text-xs text-gray-500 mt-1">
                              Text original: {restrictions.restriccions_especials}
                            </div>
                          {:else}
                            <span class="text-orange-600 text-xs">⚠️ No s'han pogut interpretar les restriccions</span>
                            <div class="text-xs text-gray-500">{restrictions.restriccions_especials}</div>
                          {/if}
                        {:else}
                          <span class="text-gray-400">-</span>
                        {/if}
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        {/each}
      </div>

      <div class="mt-4 text-sm text-gray-600">
        <strong>Total:</strong> {playerRestrictions.size} jugadors amb restriccions carregades
      </div>
    </div>
  {/if}

  <!-- Preview del calendari -->
  {#if showPreview && proposedCalendar.length > 0}
    <div class="bg-white border border-gray-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
        <span class="mr-2">👀</span> Vista Prèvia del Calendari
      </h3>

      <!-- KPIs del calendari generat -->
      {#if calendarKPIs}
        <div class="mb-6 space-y-4">
          <!-- Resum general -->
          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-3">
            <div class="bg-green-50 border border-green-200 rounded-lg p-3 text-center">
              <div class="text-2xl font-bold text-green-700">{calendarKPIs.resum.programats}</div>
              <div class="text-xs text-green-600">Programats</div>
            </div>
            {#if calendarKPIs.resum.pendents > 0}
              <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-3 text-center">
                <div class="text-2xl font-bold text-yellow-700">{calendarKPIs.resum.pendents}</div>
                <div class="text-xs text-yellow-600">Pendents</div>
              </div>
            {/if}
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-3 text-center">
              <div class="text-2xl font-bold text-blue-700">{calendarKPIs.resum.jugadors}</div>
              <div class="text-xs text-blue-600">Jugadors</div>
            </div>
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-3 text-center">
              <div class="text-2xl font-bold text-gray-700">{calendarKPIs.resum.partidesPerJugador}</div>
              <div class="text-xs text-gray-500">Partides/jugador</div>
            </div>
            <div class="bg-purple-50 border border-purple-200 rounded-lg p-3 text-center">
              <div class="text-2xl font-bold text-purple-700">{calendarKPIs.resum.ocupacio}</div>
              <div class="text-xs text-purple-600">Ocupació slots</div>
            </div>
          </div>

          <div class="text-xs text-gray-500">
            {calendarKPIs.resum.primerDia} - {calendarKPIs.resum.ultimDia} ({calendarKPIs.resum.setmanes} setmanes) | {calendarKPIs.resum.slotsUsats}/{calendarKPIs.resum.slotsDisponibles} slots
          </div>

          <!-- Validacions de restriccions dures -->
          <div class="border border-gray-200 rounded-lg overflow-hidden">
            <div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
              <h4 class="text-sm font-semibold text-gray-800">Validació de Restriccions</h4>
            </div>
            <div class="divide-y divide-gray-100">
              <!-- Mateix dia -->
              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">Dues partides el mateix dia</span>
                {#if calendarKPIs.sameDayViolations.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 violacions</span>
                {:else}
                  <span class="text-xs font-medium text-red-700 bg-red-100 px-2 py-0.5 rounded-full">{calendarKPIs.sameDayViolations.length} violacions</span>
                {/if}
              </div>
              {#if calendarKPIs.sameDayViolations.length > 0}
                <div class="px-4 py-1 bg-red-50">
                  {#each calendarKPIs.sameDayViolations as v}
                    <div class="text-xs text-red-700">{v.player}: {v.count} partides el {v.date}</div>
                  {/each}
                </div>
              {/if}

              <!-- Max setmanal -->
              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">Superen {calendarConfig.max_partides_per_setmana} partides/setmana</span>
                {#if calendarKPIs.weeklyViolations.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 violacions</span>
                {:else}
                  <span class="text-xs font-medium text-orange-700 bg-orange-100 px-2 py-0.5 rounded-full">{calendarKPIs.weeklyViolations.length} violacions</span>
                {/if}
              </div>
              {#if calendarKPIs.weeklyViolations.length > 0}
                <div class="px-4 py-1 bg-orange-50">
                  {#each calendarKPIs.weeklyViolations as v}
                    <div class="text-xs text-orange-700">{v.player}: {v.count} partides setmana {v.week} (max {v.max})</div>
                  {/each}
                </div>
              {/if}

              <!-- Dies consecutius -->
              <!-- Jugadors +75 amb dies consecutius -->
              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">Jugadors +75 anys amb dies consecutius</span>
                {#if calendarKPIs.seniorConsecutiveViolations.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 violacions</span>
                {:else}
                  <span class="text-xs font-medium text-red-700 bg-red-100 px-2 py-0.5 rounded-full">{calendarKPIs.seniorConsecutiveViolations.length} violacions</span>
                {/if}
              </div>
              {#if calendarKPIs.seniorConsecutiveViolations.length > 0}
                <div class="px-4 py-1 bg-red-50 max-h-32 overflow-y-auto">
                  {#each calendarKPIs.seniorConsecutiveViolations as v}
                    <div class="text-xs text-red-700">{v.player} ({v.edat} anys): {v.dates}</div>
                  {/each}
                </div>
              {/if}

              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">Partides en dies consecutius</span>
                {#if calendarKPIs.consecutiveViolations.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 casos</span>
                {:else}
                  <span class="text-xs font-medium text-yellow-700 bg-yellow-100 px-2 py-0.5 rounded-full">{calendarKPIs.consecutiveViolations.length} casos</span>
                {/if}
              </div>
              {#if calendarKPIs.consecutiveViolations.length > 0}
                <div class="px-4 py-1 bg-yellow-50 max-h-32 overflow-y-auto">
                  {#each calendarKPIs.consecutiveViolations as v}
                    <div class="text-xs text-yellow-700">{v.player}: {v.dates}</div>
                  {/each}
                </div>
              {/if}

              <!-- 3 dies consecutius -->
              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">3 partides en dies consecutius</span>
                {#if calendarKPIs.threeConsecutiveViolations.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 casos</span>
                {:else}
                  <span class="text-xs font-medium text-red-700 bg-red-100 px-2 py-0.5 rounded-full">{calendarKPIs.threeConsecutiveViolations.length} casos</span>
                {/if}
              </div>
              {#if calendarKPIs.threeConsecutiveViolations.length > 0}
                <div class="px-4 py-1 bg-red-50 max-h-32 overflow-y-auto">
                  {#each calendarKPIs.threeConsecutiveViolations as v}
                    <div class="text-xs text-red-700">{v.player}: {v.dates}</div>
                  {/each}
                </div>
              {/if}

              <!-- Més de 2 parells consecutius -->
              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">Més de 2 parells dies consecutius</span>
                {#if calendarKPIs.excessConsecutivePairs.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 casos</span>
                {:else}
                  <span class="text-xs font-medium text-red-700 bg-red-100 px-2 py-0.5 rounded-full">{calendarKPIs.excessConsecutivePairs.length} casos</span>
                {/if}
              </div>
              {#if calendarKPIs.excessConsecutivePairs.length > 0}
                <div class="px-4 py-1 bg-red-50 max-h-32 overflow-y-auto">
                  {#each calendarKPIs.excessConsecutivePairs as v}
                    <div class="text-xs text-red-700">{v.player}: {v.pairs} parells</div>
                  {/each}
                </div>
              {/if}

              <!-- Fora preferències dies -->
              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">Fora de preferencia de dies</span>
                {#if calendarKPIs.dayPrefViolations.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 violacions</span>
                {:else}
                  <span class="text-xs font-medium text-red-700 bg-red-100 px-2 py-0.5 rounded-full">{calendarKPIs.dayPrefViolations.length} violacions</span>
                {/if}
              </div>
              {#if calendarKPIs.dayPrefViolations.length > 0}
                <div class="px-4 py-1 bg-red-50 max-h-32 overflow-y-auto">
                  {#each calendarKPIs.dayPrefViolations as v}
                    <div class="text-xs text-red-700">{v.player}: {v.date} ({v.day}) - prefereix {v.prefereix}</div>
                  {/each}
                </div>
              {/if}

              <!-- Fora preferències hores -->
              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">Fora de preferencia d'hores</span>
                {#if calendarKPIs.hourPrefViolations.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 violacions</span>
                {:else}
                  <span class="text-xs font-medium text-red-700 bg-red-100 px-2 py-0.5 rounded-full">{calendarKPIs.hourPrefViolations.length} violacions</span>
                {/if}
              </div>
              {#if calendarKPIs.hourPrefViolations.length > 0}
                <div class="px-4 py-1 bg-red-50 max-h-32 overflow-y-auto">
                  {#each calendarKPIs.hourPrefViolations as v}
                    <div class="text-xs text-red-700">{v.player}: {v.date} a les {v.hora} - prefereix {v.prefereix}</div>
                  {/each}
                </div>
              {/if}

              <!-- Fora restriccions especials (períodes bloqueig) -->
              <div class="px-4 py-2 flex items-center justify-between">
                <span class="text-sm text-gray-700">Dins periode de bloqueig personal</span>
                {#if calendarKPIs.specialRestrViolations.length === 0}
                  <span class="text-xs font-medium text-green-700 bg-green-100 px-2 py-0.5 rounded-full">0 violacions</span>
                {:else}
                  <span class="text-xs font-medium text-red-700 bg-red-100 px-2 py-0.5 rounded-full">{calendarKPIs.specialRestrViolations.length} violacions</span>
                {/if}
              </div>
              {#if calendarKPIs.specialRestrViolations.length > 0}
                <div class="px-4 py-1 bg-red-50 max-h-32 overflow-y-auto">
                  {#each calendarKPIs.specialRestrViolations as v}
                    <div class="text-xs text-red-700">{v.player}: {v.date} - {v.restriccio}</div>
                  {/each}
                </div>
              {/if}
            </div>

            <!-- Resum validació -->
            <div class="px-4 py-2 border-t border-gray-200 bg-gray-50">
              {#if calendarKPIs.isValid && calendarKPIs.consecutiveViolations.length === 0 && calendarKPIs.weeklyViolations.length === 0}
                <span class="text-sm font-medium text-green-700">Totes les restriccions dures respectades</span>
              {:else if calendarKPIs.isValid}
                <span class="text-sm font-medium text-yellow-700">Restriccions dures OK - {calendarKPIs.consecutiveViolations.length + calendarKPIs.weeklyViolations.length} advertiments</span>
              {:else}
                <span class="text-sm font-medium text-red-700">Hi ha violacions de restriccions dures</span>
              {/if}
            </div>
          </div>
        </div>
      {:else}
        <div class="mb-4 text-sm text-gray-600">
          <div><strong>📊 Total:</strong> {proposedCalendar.length} partits</div>
        </div>
      {/if}

      <!-- Estadístiques d'ús de taules per jugador -->
      {#if proposedCalendar.filter(p => p.estat === 'generat').length > 0}
        <div class="mb-6 border-t border-gray-200 pt-4">
          <button
            on:click={() => showTableStats = !showTableStats}
            class="flex items-center gap-2 text-sm font-medium text-gray-700 hover:text-gray-900"
          >
            <svg 
              class="w-4 h-4 transform transition-transform {showTableStats ? 'rotate-90' : ''}" 
              fill="none" 
              stroke="currentColor" 
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
            </svg>
            <span>🎱 Distribució de Taules per Jugador ({calculateTableStats().length} jugadors)</span>
          </button>

          {#if showTableStats}
            {@const tableStats = calculateTableStats()}
            <div class="mt-4 overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Jugador</th>
                    <th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase">Taula 1</th>
                    <th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase">Taula 2</th>
                    <th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase">Taula 3</th>
                    <th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase">Total</th>
                    <th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase">Mínim req.</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  {#each tableStats as player}
                    {@const maxUsage = Math.max(player.taula1, player.taula2, player.taula3)}
                    {@const percentage1 = player.total > 0 ? (player.taula1 / player.total * 100).toFixed(0) : 0}
                    {@const percentage2 = player.total > 0 ? (player.taula2 / player.total * 100).toFixed(0) : 0}
                    {@const percentage3 = player.total > 0 ? (player.taula3 / player.total * 100).toFixed(0) : 0}
                    {@const hasMaxViolation = (player.taula1 / player.total > 0.60) || (player.taula2 / player.total > 0.60) || (player.taula3 / player.total > 0.60)}
                    {@const hasMinViolation = player.minRequired > 0 && (player.taula1 < player.minRequired || player.taula2 < player.minRequired || player.taula3 < player.minRequired)}
                    <tr class="{hasMaxViolation || hasMinViolation ? 'bg-red-50' : ''}">
                      <td class="px-4 py-2 whitespace-nowrap text-sm font-medium text-gray-900">
                        {player.nom} {player.cognoms}
                      </td>
                      <td class="px-4 py-2 text-center text-sm">
                        <span class="{
                          player.taula1 > 0 && player.taula1 / player.total > 0.60 ? 'text-red-600 font-bold' : 
                          player.minRequired > 0 && player.taula1 < player.minRequired ? 'text-orange-600 font-semibold' : 
                          'text-gray-900'
                        }">
                          {player.taula1}
                        </span>
                        <span class="text-xs text-gray-500 ml-1">({percentage1}%)</span>
                      </td>
                      <td class="px-4 py-2 text-center text-sm">
                        <span class="{
                          player.taula2 > 0 && player.taula2 / player.total > 0.60 ? 'text-red-600 font-bold' : 
                          player.minRequired > 0 && player.taula2 < player.minRequired ? 'text-orange-600 font-semibold' : 
                          'text-gray-900'
                        }">
                          {player.taula2}
                        </span>
                        <span class="text-xs text-gray-500 ml-1">({percentage2}%)</span>
                      </td>
                      <td class="px-4 py-2 text-center text-sm">
                        <span class="{
                          player.taula3 > 0 && player.taula3 / player.total > 0.60 ? 'text-red-600 font-bold' : 
                          player.minRequired > 0 && player.taula3 < player.minRequired ? 'text-orange-600 font-semibold' : 
                          'text-gray-900'
                        }">
                          {player.taula3}
                        </span>
                        <span class="text-xs text-gray-500 ml-1">({percentage3}%)</span>
                      </td>
                      <td class="px-4 py-2 text-center text-sm font-medium text-gray-900">
                        {player.total}
                      </td>
                      <td class="px-4 py-2 text-center text-sm text-gray-500">
                        {player.minRequired > 0 ? player.minRequired : '-'}
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
              
              <div class="mt-3 p-3 bg-blue-50 border border-blue-200 rounded text-xs text-blue-800">
                <div><strong>ℹ️ Llegenda de colors:</strong></div>
                <ul class="mt-1 ml-4 list-disc">
                  <li><span class="text-red-600 font-bold">Vermell:</span> Supera el 60% a una taula (màxim)</li>
                  <li><span class="text-orange-600 font-semibold">Taronja:</span> Per sota del mínim requerit</li>
                </ul>
                <div class="mt-2"><strong>📋 Mínims requerits:</strong></div>
                <ul class="mt-1 ml-4 list-disc">
                  <li>8-11 partits: mínim 2 per taula</li>
                  <li>12+ partits: mínim 3 per taula</li>
                </ul>
              </div>
            </div>
          {/if}
        </div>
      {/if}

      <!-- Controls de filtre i vista -->
      <div class="flex flex-wrap items-center gap-3 mb-4">
        <input
          type="text"
          bind:value={previewSearch}
          placeholder="Cercar jugador..."
          class="px-3 py-1.5 border border-gray-300 rounded text-sm w-48 focus:ring-blue-500 focus:border-blue-500"
        />

        <div class="flex rounded-lg border border-gray-300 overflow-hidden">
          <button
            on:click={() => previewViewMode = 'cronologia'}
            class="px-3 py-1.5 text-sm {previewViewMode === 'cronologia' ? 'bg-blue-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}"
          >
            Cronologia
          </button>
          <button
            on:click={() => previewViewMode = 'categoria'}
            class="px-3 py-1.5 text-sm {previewViewMode === 'categoria' ? 'bg-blue-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}"
          >
            Per Categoria
          </button>
        </div>

        {#if previewViewMode === 'categoria'}
          <select
            bind:value={previewSelectedCategory}
            class="px-3 py-1.5 border border-gray-300 rounded text-sm focus:ring-blue-500 focus:border-blue-500"
          >
            <option value="">Totes les categories</option>
            {#each categories as cat}
              <option value={cat.id}>{cat.nom}</option>
            {/each}
          </select>
        {/if}

        {#if previewSearch}
          <span class="text-sm text-gray-600">
            {previewProgrammed.length} programats + {previewPending.length} pendents = <strong>{filteredPreview.length}</strong> partits
          </span>
        {/if}
      </div>

      <!-- Taula de partits -->
      {#if previewViewMode === 'cronologia'}
        <!-- Vista cronològica -->
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Data</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Hora</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Taula</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Categoria</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Enfrontament</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              {#each filteredPreview as match}
                <tr class="{match.estat === 'pendent_programar' ? 'bg-yellow-50' : ''}">
                  <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                    {match.estat === 'pendent_programar' ? '⏳ Pendent' : match.data_programada.toLocaleDateString('ca-ES')}
                  </td>
                  <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                    {match.estat === 'pendent_programar' ? '-' : match.hora_inici}
                  </td>
                  <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                    {match.estat === 'pendent_programar' ? '-' : `Taula ${match.taula_assignada}`}
                  </td>
                  <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-500">
                    {match.categoria_nom}
                  </td>
                  <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                    {match.jugador1.soci.nom} vs {match.jugador2.soci.nom}
                    {#if match.motiu}
                      <div class="text-xs text-red-500 mt-1">{match.motiu}</div>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {:else}
        <!-- Vista per categoria -->
        {#each [...new Set(filteredPreview.map(m => m.categoria_id))] as catId}
          {@const catName = categories.find(c => c.id === catId)?.nom || catId}
          {@const catMatches = filteredPreview.filter(m => m.categoria_id === catId)}
          {@const catProgrammed = catMatches.filter(m => m.estat === 'generat')}
          {@const catPending = catMatches.filter(m => m.estat === 'pendent_programar')}

          <div class="mb-4 border border-gray-200 rounded-lg overflow-hidden">
            <div class="bg-gray-50 px-4 py-2 font-medium text-sm text-gray-900">
              {catName} — {catProgrammed.length} programats
              {#if catPending.length > 0}
                <span class="text-yellow-600">+ {catPending.length} pendents</span>
              {/if}
            </div>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Data</th>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Hora</th>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Taula</th>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Enfrontament</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  {#each catMatches as match}
                    <tr class="{match.estat === 'pendent_programar' ? 'bg-yellow-50' : ''}">
                      <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                        {match.estat === 'pendent_programar' ? '⏳ Pendent' : match.data_programada.toLocaleDateString('ca-ES')}
                      </td>
                      <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                        {match.estat === 'pendent_programar' ? '-' : match.hora_inici}
                      </td>
                      <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                        {match.estat === 'pendent_programar' ? '-' : `Taula ${match.taula_assignada}`}
                      </td>
                      <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                        {match.jugador1.soci.nom} vs {match.jugador2.soci.nom}
                        {#if match.motiu}
                          <div class="text-xs text-red-500 mt-1">{match.motiu}</div>
                        {/if}
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        {/each}
      {/if}

      <!-- Botons d'acció -->
      <div class="flex items-center space-x-3 mt-6">
        <button
          on:click={saveCalendar}
          disabled={processing}
          class="px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 disabled:bg-gray-400"
        >
          {processing ? 'Desant Calendari...' : 'Desar Calendari'}
        </button>
        <button
          on:click={() => { showPreview = false; proposedCalendar = []; }}
          class="px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700"
        >
          Cancel·lar
        </button>
      </div>
    </div>
  {/if}

  {#if showPreview && proposedCalendar.length === 0}
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
      <div class="text-yellow-800">
        <strong>Atenció:</strong> No s'han pogut generar partits.
        <ul class="mt-2 text-sm list-disc list-inside">
          <li>Categories amb jugadors: {Array.from(playersByCategory.entries()).map(([id, p]) => `${categories.find(c => c.id === id)?.nom || id}: ${p.length} jugadors`).join(', ') || 'cap'}</li>
          <li>Inscripcions totals: {inscriptions.length}</li>
          <li>Inscripcions amb categoria: {inscriptions.filter(i => i.categoria_assignada_id).length}</li>
          <li>Dies configurats: {calendarConfig.dies_setmana.join(', ')}</li>
          <li>Hores configurades: {calendarConfig.hores_disponibles.join(', ')}</li>
        </ul>
        <p class="mt-2 text-sm">Comprova que els jugadors tenen categories assignades i que les dates/restriccions permeten alguna programació.</p>
      </div>
    </div>
  {/if}
</div>

<!-- Modal de doble confirmació per esborrar calendari publicat -->
{#if showDeleteConfirmation}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
      <div class="text-center">
        <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100 mb-4">
          <svg class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.732 15.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>
        
        <h3 class="text-lg font-medium text-gray-900 mb-2">
          Esborrar Calendari Publicat
        </h3>
        
        <p class="text-sm text-gray-500 mb-6">
          <strong>Atenció!</strong> Aquesta acció eliminarà permanentment:
        </p>
        
        <div class="text-left bg-red-50 border border-red-200 rounded-md p-3 mb-6">
          <ul class="text-sm text-red-700 space-y-1">
            <li>• Tot el calendari publicat</li>
            <li>• Totes les partides programades</li>
            <li>• La visibilitat a l'aplicació PWA</li>
          </ul>
        </div>
        
        <p class="text-sm text-gray-600 mb-6">
          Aquesta acció <strong>NO es pot desfer</strong>. Estàs segur?
        </p>
      </div>
      
      <div class="flex flex-col sm:flex-row gap-3 sm:gap-2">
        <button
          on:click={deletePublishedCalendar}
          disabled={generatingCalendar}
          class="flex-1 px-4 py-2 bg-red-600 text-white text-sm rounded hover:bg-red-700 disabled:bg-gray-400"
        >
          {generatingCalendar ? 'Esborrant...' : 'Sí, Esborrar Definitivament'}
        </button>
        <button
          on:click={() => showDeleteConfirmation = false}
          disabled={generatingCalendar}
          class="flex-1 px-4 py-2 bg-gray-300 text-gray-700 text-sm rounded hover:bg-gray-400 disabled:bg-gray-200"
        >
          Cancel·lar
        </button>
      </div>
    </div>
  </div>
{/if}