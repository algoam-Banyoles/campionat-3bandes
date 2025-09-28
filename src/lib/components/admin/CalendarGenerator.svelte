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
  let showDeleteConfirmation = false; // Modal per doble confirmació
  let calendariPublicat = false; // Estat del calendari publicat

  // Mapes per optimitzar cerques
  let playerRestrictions = new Map();
  let playersByCategory = new Map();

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

    console.log('Carregant restriccions de', inscriptions.length, 'inscripcions');

    // Obtenir player_ids per als socis de les inscripcions
    const sociNumbers = inscriptions.map(i => i.soci_numero).filter(Boolean);
    console.log('Números de soci:', sociNumbers.slice(0, 5));

    if (sociNumbers.length === 0) {
      console.log('No hi ha números de soci vàlids');
      return;
    }

    try {
      const { data: playersData, error } = await supabase
        .from('players')
        .select('id, numero_soci')
        .in('numero_soci', sociNumbers);

      if (error) {
        console.error('Error carregant players:', error);
        return;
      }

      console.log('Players trobats:', playersData?.length || 0);

      // Crear mapa soci_numero -> player_id
      const sociToPlayerMap = new Map();
      (playersData || []).forEach(player => {
        sociToPlayerMap.set(player.numero_soci, player.id);
      });

      let validPlayers = 0;

      inscriptions.forEach((inscription, index) => {
        const playerId = sociToPlayerMap.get(inscription.soci_numero);

        if (!playerId) {
          console.log(`Skip inscripció ${index}: soci ${inscription.soci_numero} no té player_id`);
          return;
        }

        if (!inscription.categoria_assignada_id) {
          console.log(`Skip inscripció ${index}: no té categoria assignada`);
          return;
        }

        console.log(`Processing inscription ${index}:`, {
          soci_numero: inscription.soci_numero,
          player_id: playerId,
          categoria: inscription.categoria_assignada_id,
          has_socis_data: !!inscription.socis,
          socis_data: inscription.socis
        });

        validPlayers++;

        playerRestrictions.set(playerId, {
          preferencies_dies: inscription.preferencies_dies || [],
          preferencies_hores: inscription.preferencies_hores || [],
          restriccions_especials: inscription.restriccions_especials || null,
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
          player_id: playerId,
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

    // Debug detallat de restriccions
    console.log('🔍 DETALL DE RESTRICCIONS:');
    playerRestrictions.forEach((restrictions, playerId) => {
      console.log(`Jugador ${playerId}:`, {
        nom: restrictions.soci.nom,
        cognoms: restrictions.soci.cognoms,
        dies_disponibles: restrictions.preferencies_dies,
        hores_disponibles: restrictions.preferencies_hores,
        restriccions_especials: restrictions.restriccions_especials
      });
    });
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

  async function generateCalendar() {
    if (!dataInici || !dataFi) {
      dispatch('error', { message: 'Selecciona la data d\'inici i fi del calendari' });
      return;
    }

    generatingCalendar = true;

    try {
      console.log('Generant calendari amb dates fixades...');

      // 0. Processar restriccions especials dels jugadors
      let totalSpecialRestrictions = 0;
      let consecutiveDaysAvoided = { count: 0 }; // 🔄 Contador per dies consecutius evitats
      
      playerRestrictions.forEach((restrictions, playerId) => {
        if (restrictions.restriccions_especials) {
          const parsedRestrictions = parseSpecialRestrictions(restrictions.restriccions_especials);
          if (parsedRestrictions.length > 0) {
            totalSpecialRestrictions += parsedRestrictions.length;
            console.log(`🚫 Jugador ${playerId}: ${parsedRestrictions.length} restriccions especials detectades`);
          }
        }
      });
      console.log(`📋 Total restriccions especials processades: ${totalSpecialRestrictions}`);

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

      proposedCalendar = scheduledMatches;
      showPreview = true;

      console.log('Calendari generat:', scheduledMatches.length, 'partits');
      console.log(`🚫 Dies consecutius evitats: ${consecutiveDaysAvoided.count} cops`);

    } catch (error) {
      console.error('Error generant calendari:', error);
      dispatch('error', { message: formatSupabaseError(error) });
    } finally {
      generatingCalendar = false;
    }
  }

  function generateAllMatchups() {
    const matchups = [];

    console.log('Generant enfrontaments per categories:', Object.fromEntries(playersByCategory));

    playersByCategory.forEach((players, categoryId) => {
      const category = categories.find(c => c.id === categoryId);
      console.log(`Categoria ${categoryId}:`, category?.nom, `${players.length} jugadors`);

      if (!category || players.length < 2) {
        console.log(`Saltant categoria ${category?.nom || categoryId}: ${players.length < 2 ? 'menys de 2 jugadors' : 'categoria no trobada'}`);
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

    // Tracking per jugador
    const playerStats = new Map(); // jugador -> { matchesScheduled: number, lastMatchDate: Date|null }
    const playerAvailability = new Map(); // jugador -> [dates ocupades]

    // Inicialitzar stats dels jugadors
    playersByCategory.forEach(players => {
      players.forEach(player => {
        playerStats.set(player.player_id, {
          matchesScheduled: 0,
          lastMatchDate: null
        });
        playerAvailability.set(player.player_id, []);
      });
    });

    // Generar dates disponibles
    const availableDates = generateAvailableDates();

    // Algoritme equilibrat: processar per rondes
    let remainingMatchups = [...matchups];
    let attempts = 0;
    const maxAttempts = 10;

    while (remainingMatchups.length > 0 && attempts < maxAttempts) {
      attempts++;
      console.log(`📅 Ronda ${attempts}: ${remainingMatchups.length} partits per programar`);

      // Ordenar enfrontaments per prioritat equilibrada
      remainingMatchups = sortMatchupsByBalance(remainingMatchups, playerStats);

      const scheduledThisRound = [];
      const unscheduledThisRound = [];

      for (const matchup of remainingMatchups) {
        const bestSlot = findBestBalancedSlot(matchup, availableDates, playerAvailability, playerStats, consecutiveDaysCounter);

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

          // Actualitzar stats dels jugadors
          const matchDate = new Date(bestSlot.date);

          [matchup.jugador1.player_id, matchup.jugador2.player_id].forEach(playerId => {
            playerStats.get(playerId).matchesScheduled++;
            playerStats.get(playerId).lastMatchDate = matchDate;
            playerAvailability.get(playerId).push(matchDate);
          });

          // Marcar slot com utilitzat
          bestSlot.isUsed = true;
        } else {
          unscheduledThisRound.push(matchup);
        }
      }

      remainingMatchups = unscheduledThisRound;

      // Si no s'ha programat cap partit en aquesta ronda, sortir
      if (scheduledThisRound.length === 0) {
        console.log('⚠️ No s\'han pogut programar més partits en aquesta ronda');
        break;
      }

      console.log(`✅ Ronda ${attempts}: ${scheduledThisRound.length} partits programats`);

      // Mostrar estadístiques d'equilibri
      logPlayerBalance(playerStats);
    }

    // Afegir partits no programats com a pendents
    remainingMatchups.forEach(matchup => {
      unscheduled.push({
        ...matchup,
        data_programada: null,
        hora_inici: null,
        taula_assignada: null,
        estat: 'pendent_programar'
      });
    });

    console.log(`📊 Resum final:`);
    console.log(`✅ Partits programats: ${scheduled.length}`);
    console.log(`⏳ Partits pendents: ${unscheduled.length}`);
    logPlayerBalance(playerStats);

    return [...scheduled, ...unscheduled];
  }

  // Ordenar enfrontaments per equilibri: prioritzar jugadors amb menys partits programats
  function sortMatchupsByBalance(matchups, playerStats) {
    return [...matchups].sort((a, b) => {
      const aPlayer1Stats = playerStats.get(a.jugador1.player_id);
      const aPlayer2Stats = playerStats.get(a.jugador2.player_id);
      const bPlayer1Stats = playerStats.get(b.jugador1.player_id);
      const bPlayer2Stats = playerStats.get(b.jugador2.player_id);

      // Calcular el total de partits programats per cada enfrontament
      const aTotalMatches = aPlayer1Stats.matchesScheduled + aPlayer2Stats.matchesScheduled;
      const bTotalMatches = bPlayer1Stats.matchesScheduled + bPlayer2Stats.matchesScheduled;

      // Prioritzar enfrontaments amb jugadors que tenen menys partits
      if (aTotalMatches !== bTotalMatches) {
        return aTotalMatches - bTotalMatches;
      }

      // Si iguals, prioritzar per prioritat original (aleatòria)
      return b.prioritat - a.prioritat;
    });
  }

  // Funció millorada per trobar el millor slot considerant equilibri
  function findBestBalancedSlot(matchup, availableDates, playerAvailability, playerStats, consecutiveDaysCounter) {
    const player1Id = matchup.jugador1.player_id;
    const player2Id = matchup.jugador2.player_id;

    const player1Restrictions = playerRestrictions.get(player1Id);
    const player2Restrictions = playerRestrictions.get(player2Id);
    const player1Busy = playerAvailability.get(player1Id) || [];
    const player2Busy = playerAvailability.get(player2Id) || [];

    const player1Stats = playerStats.get(player1Id);
    const player2Stats = playerStats.get(player2Id);

    // Filtrar slots disponibles amb restriccions bàsiques
    const validSlots = availableDates.filter(slot => {
      if (slot.isUsed) return false;

      const dayOfWeek = getDayOfWeekCode(slot.date.getDay());
      const dateStr = slot.date.toISOString().split('T')[0];
      const slotDate = new Date(slot.date);

      // Comprovar si els jugadors ja juguen aquest dia
      if (player1Busy.some(busyDate =>
          busyDate.toISOString().split('T')[0] === dateStr) ||
          player2Busy.some(busyDate =>
          busyDate.toISOString().split('T')[0] === dateStr)) {
        return false;
      }

      // ✨ EVITAR DIES CONSECUTIUS: Excloure completament slots en dies consecutius
      const hasConsecutiveDayConflict = player1Busy.some(busyDate => {
        const daysDiff = Math.abs((slotDate.getTime() - busyDate.getTime()) / (1000 * 60 * 60 * 24));
        return daysDiff < 1; // Menys d'1 dia = consecutiu
      }) || player2Busy.some(busyDate => {
        const daysDiff = Math.abs((slotDate.getTime() - busyDate.getTime()) / (1000 * 60 * 60 * 24));
        return daysDiff < 1; // Menys d'1 dia = consecutiu
      });

      if (hasConsecutiveDayConflict) {
        consecutiveDaysCounter.count++; // Incrementar contador
        return false;
      }

      // Comprovar preferències de dies
      const player1HasDayPrefs = player1Restrictions?.preferencies_dies?.length > 0;
      const player2HasDayPrefs = player2Restrictions?.preferencies_dies?.length > 0;

      if (player1HasDayPrefs && !player1Restrictions.preferencies_dies.includes(dayOfWeek)) return false;
      if (player2HasDayPrefs && !player2Restrictions.preferencies_dies.includes(dayOfWeek)) return false;

      // Comprovar preferències d'hores
      const player1HasTimePrefs = player1Restrictions?.preferencies_hores?.length > 0;
      const player2HasTimePrefs = player2Restrictions?.preferencies_hores?.length > 0;

      if (player1HasTimePrefs && !player1Restrictions.preferencies_hores.includes(slot.time)) return false;
      if (player2HasTimePrefs && !player2Restrictions.preferencies_hores.includes(slot.time)) return false;

      // ✨ NOVA FUNCIONALITAT: Comprovar restriccions especials (dates específiques d'indisponibilitat)
      if (player1Restrictions?.restriccions_especials) {
        if (isDateRestricted(slot.date, player1Restrictions.restriccions_especials)) {
          return false;
        }
      }
      
      if (player2Restrictions?.restriccions_especials) {
        if (isDateRestricted(slot.date, player2Restrictions.restriccions_especials)) {
          return false;
        }
      }

      return true;
    });

    if (validSlots.length === 0) return null;

    // Ordenar slots per preferència d'equilibri
    const scoredSlots = validSlots.map(slot => {
      let score = 0;

      // Evitar dies consecutius (puntuació alta = millor)
      const slotDate = new Date(slot.date);
      const daysBetween1 = player1Stats.lastMatchDate ?
        Math.abs((slotDate.getTime() - player1Stats.lastMatchDate.getTime()) / (1000 * 60 * 60 * 24)) : 999;
      const daysBetween2 = player2Stats.lastMatchDate ?
        Math.abs((slotDate.getTime() - player2Stats.lastMatchDate.getTime()) / (1000 * 60 * 60 * 24)) : 999;

      // Prioritzar dies amb més separació (els consecutius ja estan exclosos)
      const minDaysBetween = Math.min(daysBetween1, daysBetween2);
      if (minDaysBetween >= 3) {
        score += 150; // Excel·lent: 3+ dies d'espaiat
      } else if (minDaysBetween >= 2) {
        score += 100; // Perfecte: 2+ dies d'espaiat
      } else if (minDaysBetween >= 1) {
        score += 50; // Acceptable: 1 dia d'espaiat
      }
      // Nota: Els dies consecutius ja no poden arribar aquí

      // Prioritzar dates més properes (per omplir el calendari de manera més uniforme)
      const daysFromStart = Math.abs((slotDate.getTime() - new Date(dataInici).getTime()) / (1000 * 60 * 60 * 24));
      score += Math.max(0, 30 - daysFromStart * 0.1);

      return { slot, score };
    });

    // Retornar el slot amb millor puntuació
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
  }

  function generateAvailableDates() {
    const dates = [];
    const start = new Date(dataInici);
    const end = new Date(dataFi);

    for (let date = new Date(start); date <= end; date.setDate(date.getDate() + 1)) {
      const dayOfWeek = getDayOfWeekCode(date.getDay());

      // Comprovar si el dia està disponible
      if (calendarConfig.dies_setmana.includes(dayOfWeek)) {
        // Comprovar si no és festiu
        const dateStr = date.toISOString().split('T')[0];
        if (!calendarConfig.dies_festius.includes(dateStr)) {

          // Afegir slots per cada hora i taula
          calendarConfig.hores_disponibles.forEach(hora => {
            for (let taula = 1; taula <= calendarConfig.taules_per_slot; taula++) {
              dates.push({
                date: new Date(date),
                time: hora,
                table: taula,
                isUsed: false
              });
            }
          });
        }
      }
    }

    return dates;
  }


  function getDayOfWeekCode(dayIndex) {
    const days = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds']; // 0=diumenge, 1=dilluns...
    return days[dayIndex];
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
    
    console.log('🔍 Parsing restrictions:', restrictions);
    
    // Dividir per línies i processar cada línia
    const lines = restrictions.split('\n').map(line => line.trim()).filter(line => line.length > 0);
    
    for (const line of lines) {
      console.log('📝 Processing line:', line);
      let found = false;
      
      // Test 1: Períodes "del X al Y de [mes]"
      let match = line.match(/del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, startDay, endDay, monthName] = match;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
          const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
          periods.push({ start: startDate, end: endDate });
          console.log('✅ Found month period (de):', { start: startDate, end: endDate });
          found = true;
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
            console.log("✅ Found month period (d'):", { start: startDate, end: endDate });
            found = true;
          }
        }
      }
      
      // Test 3: DD/MM al DD/MM
      if (!found) {
        match = line.match(/(\d{1,2})\/(\d{1,2})\s+al\s+(\d{1,2})\/(\d{1,2})/i);
        if (match) {
          const [, startDay, startMonth, endDay, endMonth] = match;
          const startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
          const endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
          periods.push({ start: startDate, end: endDate });
          console.log('✅ Found date period (/):', { start: startDate, end: endDate });
          found = true;
        }
      }
      
      // Test 4: DD-MM al DD-MM
      if (!found) {
        match = line.match(/(\d{1,2})-(\d{1,2})\s+al\s+(\d{1,2})-(\d{1,2})/i);
        if (match) {
          const [, startDay, startMonth, endDay, endMonth] = match;
          const startDate = new Date(currentYear, parseInt(startMonth) - 1, parseInt(startDay));
          const endDate = new Date(currentYear, parseInt(endMonth) - 1, parseInt(endDay));
          periods.push({ start: startDate, end: endDate });
          console.log('✅ Found dash period (-):', { start: startDate, end: endDate });
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
            console.log('✅ Found specific date:', { start: date, end: date });
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
            console.log('✅ Found specific date (no "de"):', { start: date, end: date });
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
            console.log('✅ Found multiple specific dates:', { date1, date2 });
            found = true;
          }
        }
      }
      
      if (!found) {
        console.log('❌ No pattern matched for line:', line);
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
  
  // Comprovar si una data està dins les restriccions especials
  function isDateRestricted(date, restrictionsText) {
    if (!restrictionsText || restrictionsText.trim() === '') return false;
    
    const restrictions = parseSpecialRestrictions(restrictionsText);
    
    return restrictions.some(restriction => {
      // Comparar només les dates (sense hora)
      const checkDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
      const startDate = new Date(restriction.start.getFullYear(), restriction.start.getMonth(), restriction.start.getDate());
      const endDate = new Date(restriction.end.getFullYear(), restriction.end.getMonth(), restriction.end.getDate());
      
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
    const startDate = new Date(dataInici);
    const endDate = new Date(dataFi);
    let totalSlots = 0;

    // Iterar per cada dia del període
    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      const dayOfWeek = getDayOfWeekCode(date.getDay());

      // Comprovar si el dia està disponible
      if (calendarConfig.dies_setmana.includes(dayOfWeek)) {
        const dateStr = date.toISOString().split('T')[0];

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
      // Eliminar calendari existent
      await supabase
        .from('calendari_partides')
        .delete()
        .eq('event_id', eventId);

      // Inserir nous partits
      const partidesToInsert = proposedCalendar.map(match => ({
        event_id: eventId,
        categoria_id: match.categoria_id,
        jugador1_id: match.jugador1.player_id, // Usar player_id (UUID)
        jugador2_id: match.jugador2.player_id,
        data_programada: match.data_programada?.toISOString() || null,
        hora_inici: match.hora_inici,
        taula_assignada: match.taula_assignada,
        estat: match.estat
      }));

      const { error } = await supabase
        .from('calendari_partides')
        .insert(partidesToInsert);

      if (error) throw error;

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
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Data d'inici
        </label>
        <input
          type="date"
          bind:value={dataInici}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
        />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Data de fi del campionat
        </label>
        <input
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
    <div class="mt-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        Dies disponibles
      </label>
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
    </div>

    <!-- Hores disponibles -->
    <div class="mt-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        Hores disponibles
      </label>
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
    </div>

    <!-- Configuració avançada -->
    <div class="mt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Taules per hora
        </label>
        <input
          type="number"
          min="1"
          max="10"
          bind:value={calendarConfig.taules_per_slot}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Màx partits per setmana
        </label>
        <input
          type="number"
          min="1"
          max="7"
          bind:value={calendarConfig.max_partides_per_setmana}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Màx partits per dia
        </label>
        <input
          type="number"
          min="1"
          max="3"
          bind:value={calendarConfig.max_partides_per_dia}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
    </div>

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
                    {@const restrictions = playerRestrictions.get(player.player_id)}
                    <tr>
                      <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                        {restrictions?.soci?.nom || 'Nom no disponible'} {restrictions?.soci?.cognoms || ''}
                        <div class="text-xs text-gray-500">ID: {player.player_id.substring(0, 8)}...</div>
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
                        {restrictions?.restriccions_especials || '-'}
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

      <div class="mb-4 text-sm text-gray-600">
        {#if proposedCalendar.filter(p => p.estat === 'generat').length > 0}
          <div class="space-y-1">
            <div><strong>✅ Partits programats:</strong> {proposedCalendar.filter(p => p.estat === 'generat').length}</div>
            {#if proposedCalendar.filter(p => p.estat === 'pendent_programar').length > 0}
              <div><strong>⏳ Partits pendents:</strong> {proposedCalendar.filter(p => p.estat === 'pendent_programar').length}</div>
            {/if}
            <div><strong>📊 Total:</strong> {proposedCalendar.length} partits</div>
          </div>
        {:else}
          <div class="text-yellow-600">
            <strong>⚠️ Cap partit programat automàticament</strong> - tots requereixen programació manual
          </div>
        {/if}
      </div>

      <!-- Taula de partits -->
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Data</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Hora</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Taula</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Categoria</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Enfrontament</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each proposedCalendar.slice(0, 20) as match}
              <tr class="{match.estat === 'pendent_programar' ? 'bg-yellow-50' : ''}">
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {match.estat === 'pendent_programar' ? '⏳ Pendent' : match.data_programada.toLocaleDateString('ca-ES')}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {match.estat === 'pendent_programar' ? '-' : match.hora_inici}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {match.estat === 'pendent_programar' ? '-' : `Taula ${match.taula_assignada}`}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {match.categoria_nom}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {match.jugador1.soci.nom} vs {match.jugador2.soci.nom}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>

        {#if proposedCalendar.length > 20}
          <div class="text-center py-4 text-sm text-gray-500">
            ... i {proposedCalendar.length - 20} partits més
          </div>
        {/if}
      </div>

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
        <strong>Atenció:</strong> No s'han pogut generar partits amb les restriccions actuals.
        Prova d'ampliar les dates o reduir les restriccions.
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