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
  
  // Gestió de períodes de bloqueig
  let showBlockedPeriods = false;
  let blockedPeriods: Array<{ start: string; end: string; description: string }> = [];
  let newBlockedStart = '';
  let newBlockedEnd = '';
  let newBlockedDescription = '';
  
  // Gestió de vista d'estadístiques de taules
  let showTableStats = false;

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

  // Funció per validar el calendari generat
  function validateGeneratedCalendar(matches: any[]) {
    console.log('\n🔍 Validant calendari generat...');
    
    const errors = [];
    const warnings = [];
    const playerMatchesByDate = new Map(); // playerId -> Map<dateStr, Match[]>

    // Construir mapa de partides per jugador i data
    matches.forEach(match => {
      if (!match.data_programada) return; // Ignorar partides no programades

      const dateStr = new Date(match.data_programada).toISOString().split('T')[0];
      
      // Jugador 1
      if (!playerMatchesByDate.has(match.jugador1.player_id)) {
        playerMatchesByDate.set(match.jugador1.player_id, new Map());
      }
      const player1Dates = playerMatchesByDate.get(match.jugador1.player_id);
      if (!player1Dates.has(dateStr)) {
        player1Dates.set(dateStr, []);
      }
      player1Dates.get(dateStr).push(match);

      // Jugador 2
      if (!playerMatchesByDate.has(match.jugador2.player_id)) {
        playerMatchesByDate.set(match.jugador2.player_id, new Map());
      }
      const player2Dates = playerMatchesByDate.get(match.jugador2.player_id);
      if (!player2Dates.has(dateStr)) {
        player2Dates.set(dateStr, []);
      }
      player2Dates.get(dateStr).push(match);
    });

    // Validació 1: Cap jugador pot tenir més d'una partida el mateix dia
    playerMatchesByDate.forEach((dateMap, playerId) => {
      dateMap.forEach((matchesOnDate, dateStr) => {
        if (matchesOnDate.length > 1) {
          const playerName = matchesOnDate[0].jugador1.player_id === playerId 
            ? `${matchesOnDate[0].jugador1.soci.nom} ${matchesOnDate[0].jugador1.soci.cognoms}`
            : `${matchesOnDate[0].jugador2.soci.nom} ${matchesOnDate[0].jugador2.soci.cognoms}`;
          
          errors.push({
            type: 'MATEIX_DIA',
            playerId,
            playerName,
            date: dateStr,
            count: matchesOnDate.length,
            matches: matchesOnDate.map(m => `${m.jugador1.soci.nom} vs ${m.jugador2.soci.nom} a les ${m.hora_inici}`)
          });
        }
      });
    });

    // Validació 2: Cap jugador pot tenir partides en dies consecutius
    playerMatchesByDate.forEach((dateMap, playerId) => {
      const dates = Array.from(dateMap.keys()).sort();
      
      for (let i = 0; i < dates.length - 1; i++) {
        const date1 = new Date(dates[i] as string);
        const date2 = new Date(dates[i + 1] as string);
        const daysDiff = Math.abs((date2.getTime() - date1.getTime()) / (1000 * 60 * 60 * 24));
        
        if (daysDiff === 1) {
          const matches1 = dateMap.get(dates[i]);
          const playerName = matches1[0].jugador1.player_id === playerId 
            ? `${matches1[0].jugador1.soci.nom} ${matches1[0].jugador1.soci.cognoms}`
            : `${matches1[0].jugador2.soci.nom} ${matches1[0].jugador2.soci.cognoms}`;
          
          warnings.push({
            type: 'DIES_CONSECUTIUS',
            playerId,
            playerName,
            date1: dates[i],
            date2: dates[i + 1]
          });
        }
      }
    });

    // Validació 3: Comprovar distribució de taules per jugador
    const playerTableStats = new Map();
    matches.forEach(match => {
      if (!match.data_programada || !match.taula_assignada) return;

      [match.jugador1.player_id, match.jugador2.player_id].forEach(playerId => {
        if (!playerTableStats.has(playerId)) {
          playerTableStats.set(playerId, { total: 0, tables: new Map() });
        }
        const stats = playerTableStats.get(playerId);
        stats.total++;
        stats.tables.set(match.taula_assignada, (stats.tables.get(match.taula_assignada) || 0) + 1);
      });
    });

    playerTableStats.forEach((stats, playerId) => {
      if (stats.total < 3) return; // Ignorar jugadors amb poques partides
      
      stats.tables.forEach((count, table) => {
        const percentage = count / stats.total;
        if (percentage > 0.60) {
          // Trobar nom del jugador
          const match = matches.find(m => 
            m.jugador1.player_id === playerId || m.jugador2.player_id === playerId
          );
          if (match) {
            const playerName = match.jugador1.player_id === playerId 
              ? `${match.jugador1.soci.nom} ${match.jugador1.soci.cognoms}`
              : `${match.jugador2.soci.nom} ${match.jugador2.soci.cognoms}`;
            
            warnings.push({
              type: 'TAULA_EXCESSIVA',
              playerId,
              playerName,
              table,
              count,
              total: stats.total,
              percentage: (percentage * 100).toFixed(1)
            });
          }
        }
      });
    });

    // Mostrar resultats
    console.log('\n📊 Resultats de la validació:');
    console.log(`   Errors crítics: ${errors.length}`);
    console.log(`   Advertiments: ${warnings.length}`);

    if (errors.length > 0) {
      console.error('\n❌ ERRORS CRÍTICS DETECTATS:');
      errors.forEach(err => {
        if (err.type === 'MATEIX_DIA') {
          console.error(`   ⚠️ ${err.playerName} té ${err.count} partides el ${err.date}:`);
          err.matches.forEach(m => console.error(`      - ${m}`));
        }
      });
    }

    if (warnings.length > 0) {
      console.warn('\n⚠️ ADVERTIMENTS:');
      warnings.forEach(warn => {
        if (warn.type === 'DIES_CONSECUTIUS') {
          console.warn(`   📅 ${warn.playerName}: partides en dies consecutius (${warn.date1} i ${warn.date2})`);
        } else if (warn.type === 'TAULA_EXCESSIVA') {
          console.warn(`   🎱 ${warn.playerName}: ${warn.percentage}% de partides a la taula ${warn.table} (${warn.count}/${warn.total})`);
        }
      });
    }

    if (errors.length === 0 && warnings.length === 0) {
      console.log('   ✅ Cap problema detectat!');
    }

    return { errors, warnings, isValid: errors.length === 0 };
  }

  async function generateCalendar() {
    if (!dataInici || !dataFi) {
      dispatch('error', { message: 'Selecciona la data d\'inici i fi del calendari' });
      return;
    }

    generatingCalendar = true;

    try {
      console.log('=== GENERANT CALENDARI ===');
      console.log('📅 Data inici:', dataInici);
      console.log('📅 Data fi:', dataFi);
      console.log('🚫 Períodes de bloqueig:', blockedPeriods);
      console.log('🚫 Dies festius configurats:', calendarConfig.dies_festius);
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

      // 4. Validar el calendari generat
      const validation = validateGeneratedCalendar(scheduledMatches);
      
      if (!validation.isValid) {
        console.error('❌ El calendari generat conté errors crítics. Revisa els logs.');
        // Encara mostrem el calendari perquè l'administrador pugui veure els errors
      }

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

    // Log de restriccions especials carregades
    console.log(`\n🔐 Restriccions especials de jugadors carregades: ${playerRestrictions.size}`);
    let playersWithRestrictions = 0;
    playerRestrictions.forEach((restrictions, playerId) => {
      if (restrictions.restriccions_especials) {
        playersWithRestrictions++;
        const periods = parseSpecialRestrictions(restrictions.restriccions_especials);
        console.log(`   📅 ${restrictions.soci.nom}: ${periods.length} períodes restringits`);
        periods.forEach(p => {
          console.log(`      - ${p.start.toISOString().split('T')[0]} a ${p.end.toISOString().split('T')[0]}`);
        });
      }
    });
    console.log(`   Total jugadors amb restriccions: ${playersWithRestrictions}\n`);

    // Tracking per jugador
    const playerStats = new Map(); // jugador -> { matchesScheduled: number, lastMatchDate: Date|null, tableUsage: Map<number, number> }
    const playerAvailability = new Map(); // jugador -> [{date: Date, time: string}] quan ja juga

    // Inicialitzar stats dels jugadors
    playersByCategory.forEach(players => {
      players.forEach(player => {
        playerStats.set(player.player_id, {
          matchesScheduled: 0,
          lastMatchDate: null,
          tableUsage: new Map() // taula -> nombre de partits
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
    
    const startTime = Date.now();
    const maxExecutionTime = 30000; // 30 segons màxim

    while (remainingMatchups.length > 0 && attempts < maxAttempts) {
      // Comprovar timeout
      if (Date.now() - startTime > maxExecutionTime) {
        console.warn(`⏱️ TIMEOUT: Generació interrompuda després de 30 segons`);
        console.warn(`   Partits programats: ${scheduled.length}`);
        console.warn(`   Partits pendents: ${remainingMatchups.length}`);
        break;
      }
      
      attempts++;
      console.log(`📅 Ronda ${attempts}/${maxAttempts}: ${remainingMatchups.length} partits per programar`);

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
            const stats = playerStats.get(playerId);
            stats.matchesScheduled++;
            stats.lastMatchDate = matchDate;
            // Guardar data+hora per evitar duplicats a la mateixa hora
            playerAvailability.get(playerId).push({ date: matchDate, time: bestSlot.time });
            
            // Actualitzar ús de taula
            const currentTableUsage = stats.tableUsage.get(bestSlot.table) || 0;
            stats.tableUsage.set(bestSlot.table, currentTableUsage + 1);
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
        console.warn('⚠️ No s\'han pogut programar més partits en aquesta ronda');
        console.warn(`   Slots totals disponibles: ${availableDates.length}`);
        console.warn(`   Slots usats: ${availableDates.filter(s => s.isUsed).length}`);
        console.warn(`   Slots lliures: ${availableDates.filter(s => !s.isUsed).length}`);
        break;
      }

      console.log(`✅ Ronda ${attempts}: ${scheduledThisRound.length} partits programats`);

      // Mostrar estadístiques d'equilibri cada 2 rondes
      if (attempts % 2 === 0) {
        logPlayerBalance(playerStats);
      }
    }
    
    // Log final detallat
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`⏱️ Temps d'execució: ${executionTime}s`);

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

    // ✨ PAS DE REBALANCEIG: Optimitzar la distribució de taules
    if (scheduled.length > 0) {
      console.log(`\n🔄 Iniciant rebalanceig de taules...`);
      const rebalancedScheduled = rebalanceTableDistribution(scheduled);
      return [...rebalancedScheduled, ...unscheduled];
    }

    return [...scheduled, ...unscheduled];
  }

  // Funció per rebalancejar la distribució de taules després de la generació
  function rebalanceTableDistribution(matches: any[], maxPercentage: number = 0.60) {
    console.log(`🎱 Analitzant distribució de taules per ${matches.length} partits...`);
    
    // Calcular estadístiques actuals de taules per jugador
    const playerTableStats = new Map();
    
    matches.forEach(match => {
      // Jugador 1
      if (!playerTableStats.has(match.jugador1.player_id)) {
        playerTableStats.set(match.jugador1.player_id, {
          total: 0,
          tables: new Map(),
          matches: []
        });
      }
      const stats1 = playerTableStats.get(match.jugador1.player_id);
      stats1.total++;
      stats1.tables.set(match.taula_assignada, (stats1.tables.get(match.taula_assignada) || 0) + 1);
      stats1.matches.push({ match, playerRole: 1 });
      
      // Jugador 2
      if (!playerTableStats.has(match.jugador2.player_id)) {
        playerTableStats.set(match.jugador2.player_id, {
          total: 0,
          tables: new Map(),
          matches: []
        });
      }
      const stats2 = playerTableStats.get(match.jugador2.player_id);
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
  function wouldSwapImproveMinimum(sourceMatch: any, targetMatch: any, playerId: string, stats: Map<any, any>) {
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
  function wouldSwapImprove(match1: any, match2: any, playerId: string, stats: Map<any, any>, maxPercentage: number) {
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
      match1.jugador1.player_id,
      match1.jugador2.player_id,
      match2.jugador1.player_id,
      match2.jugador2.player_id
    ];
    
    players.forEach(playerId => {
      const playerStats = stats.get(playerId);
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

    // Contador de slots filtrats per cada raó
    const filterReasons = {
      used: 0,
      tableLimit: 0,
      sameDay: 0,
      consecutive: 0,
      dayPreference: 0,
      timePreference: 0,
      specialRestrictions: 0,
      total: availableDates.length
    };

    // Filtrar slots disponibles amb restriccions bàsiques
    const validSlots = availableDates.filter(slot => {
      if (slot.isUsed) {
        filterReasons.used++;
        return false;
      }

      const dayOfWeek = getDayOfWeekCode(slot.date.getDay());
      const dateStr = slot.date.toISOString().split('T')[0];
      const slotDate = new Date(slot.date);

      // Comprovar si els jugadors ja juguen aquest dia (bloquejar tot el dia)
      const player1HasMatchThisDay = player1Busy.some(busy => {
        const busyDateStr = busy.date.toISOString().split('T')[0];
        return busyDateStr === dateStr; // Bloquejar tot el dia
      });

      const player2HasMatchThisDay = player2Busy.some(busy => {
        const busyDateStr = busy.date.toISOString().split('T')[0];
        return busyDateStr === dateStr; // Bloquejar tot el dia
      });

      if (player1HasMatchThisDay || player2HasMatchThisDay) {
        filterReasons.sameDay++;
        return false;
      }

      // ✨ EVITAR DIES CONSECUTIUS: Excloure completament slots en dies consecutius
      const hasConsecutiveDayConflict = player1Busy.some(busy => {
        // Normalitzar dates per comparar només el dia (sense hores)
        const slotDay = new Date(slotDate.getFullYear(), slotDate.getMonth(), slotDate.getDate());
        const busyDay = new Date(busy.date.getFullYear(), busy.date.getMonth(), busy.date.getDate());
        const daysDiff = Math.abs((slotDay.getTime() - busyDay.getTime()) / (1000 * 60 * 60 * 24));
        return daysDiff === 1; // Exactament 1 dia = consecutiu
      }) || player2Busy.some(busy => {
        const slotDay = new Date(slotDate.getFullYear(), slotDate.getMonth(), slotDate.getDate());
        const busyDay = new Date(busy.date.getFullYear(), busy.date.getMonth(), busy.date.getDate());
        const daysDiff = Math.abs((slotDay.getTime() - busyDay.getTime()) / (1000 * 60 * 60 * 24));
        return daysDiff === 1; // Exactament 1 dia = consecutiu
      });

      if (hasConsecutiveDayConflict) {
        consecutiveDaysCounter.count++; // Incrementar contador
        filterReasons.consecutive++;
        return false;
      }

      // Comprovar preferències de dies
      const player1HasDayPrefs = player1Restrictions?.preferencies_dies?.length > 0;
      const player2HasDayPrefs = player2Restrictions?.preferencies_dies?.length > 0;

      if (player1HasDayPrefs && !player1Restrictions.preferencies_dies.includes(dayOfWeek)) {
        filterReasons.dayPreference++;
        return false;
      }
      if (player2HasDayPrefs && !player2Restrictions.preferencies_dies.includes(dayOfWeek)) {
        filterReasons.dayPreference++;
        return false;
      }

      // Comprovar preferències d'hores
      const player1HasTimePrefs = player1Restrictions?.preferencies_hores?.length > 0;
      const player2HasTimePrefs = player2Restrictions?.preferencies_hores?.length > 0;

      if (player1HasTimePrefs && !player1Restrictions.preferencies_hores.includes(slot.time)) {
        filterReasons.timePreference++;
        return false;
      }
      if (player2HasTimePrefs && !player2Restrictions.preferencies_hores.includes(slot.time)) {
        filterReasons.timePreference++;
        return false;
      }

      // ✨ NOVA FUNCIONALITAT: Comprovar restriccions especials (dates específiques d'indisponibilitat)
      if (player1Restrictions?.restriccions_especials) {
        const dateStr = slot.date.toISOString().split('T')[0];
        if (dateStr === '2026-01-06') {
          console.log(`🔍 DEBUG: Comprovant 6/1/2026 per ${matchup.jugador1.soci.nom}`, {
            slotDate: slot.date,
            year: slot.date.getFullYear(),
            month: slot.date.getMonth(),
            day: slot.date.getDate(),
            restriccions: player1Restrictions.restriccions_especials
          });
        }
        if (isDateRestricted(slot.date, player1Restrictions.restriccions_especials)) {
          filterReasons.specialRestrictions++;
          console.log(`   ⛔ ${matchup.jugador1.soci.nom} no disponible el ${dateStr}`);
          return false;
        }
      }
      
      if (player2Restrictions?.restriccions_especials) {
        const dateStr = slot.date.toISOString().split('T')[0];
        if (dateStr === '2026-01-06') {
          console.log(`🔍 DEBUG: Comprovant 6/1/2026 per ${matchup.jugador2.soci.nom}`, {
            slotDate: slot.date,
            year: slot.date.getFullYear(),
            month: slot.date.getMonth(),
            day: slot.date.getDate(),
            restriccions: player2Restrictions.restriccions_especials
          });
        }
        if (isDateRestricted(slot.date, player2Restrictions.restriccions_especials)) {
          filterReasons.specialRestrictions++;
          console.log(`   ⛔ ${matchup.jugador2.soci.nom} no disponible el ${dateStr}`);
          return false;
        }
      }

      return true;
    });

    if (validSlots.length === 0) {
      // Log detallat quan no es troben slots
      if (filterReasons.total < 50) { // Només mostrar si hi ha pocs slots disponibles en general
        console.log(`⚠️ No s'han trobat slots vàlids per ${matchup.jugador1.soci.nom} vs ${matchup.jugador2.soci.nom}`);
        console.log(`   Slots totals: ${filterReasons.total}`);
        console.log(`   Filtrats per ús: ${filterReasons.used}`);
        console.log(`   Filtrats per límit de taula: ${filterReasons.tableLimit}`);
        console.log(`   Filtrats per mateix dia: ${filterReasons.sameDay}`);
        console.log(`   Filtrats per dies consecutius: ${filterReasons.consecutive}`);
        console.log(`   Filtrats per preferències dia: ${filterReasons.dayPreference}`);
        console.log(`   Filtrats per preferències hora: ${filterReasons.timePreference}`);
        console.log(`   Filtrats per restriccions especials: ${filterReasons.specialRestrictions}`);
      }
      return null;
    }

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

      // ✨ DIVERSIFICACIÓ DE TAULES: Bonificar taules que els jugadors han usat menys
      const player1TableUsage = player1Stats.tableUsage.get(slot.table) || 0;
      const player2TableUsage = player2Stats.tableUsage.get(slot.table) || 0;
      const totalTableUsage = player1TableUsage + player2TableUsage;
      
      // Bonificar taules poc utilitzades
      if (totalTableUsage === 0) {
        score += 80; // Taula nova per ambdós jugadors
      } else if (totalTableUsage === 1) {
        score += 60; // Taula poc utilitzada
      } else if (totalTableUsage === 2) {
        score += 40; // Taula moderadament utilitzada
      } else if (totalTableUsage >= 3) {
        score += 20; // Taula molt utilitzada (menys preferent)
      }

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
        if (!playerMap.has(match.jugador1.player_id)) {
          playerMap.set(match.jugador1.player_id, {
            player_id: match.jugador1.player_id,
            nom: match.jugador1.soci.nom,
            cognoms: match.jugador1.soci.cognoms || '',
            taula1: 0,
            taula2: 0,
            taula3: 0,
            total: 0
          });
        }
        const player1Stats = playerMap.get(match.jugador1.player_id);
        player1Stats[`taula${match.taula_assignada}`]++;
        player1Stats.total++;
        
        // Jugador 2
        if (!playerMap.has(match.jugador2.player_id)) {
          playerMap.set(match.jugador2.player_id, {
            player_id: match.jugador2.player_id,
            nom: match.jugador2.soci.nom,
            cognoms: match.jugador2.soci.cognoms || '',
            taula1: 0,
            taula2: 0,
            taula3: 0,
            total: 0
          });
        }
        const player2Stats = playerMap.get(match.jugador2.player_id);
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
          console.log(`✅ Període detectat: del ${startDay} de ${startMonth} al ${endDay} de ${endMonth} (ambdós inclosos)`, { 
            dataInici: startDate.toISOString().split('T')[0], 
            dataFinal: endDate.toISOString().split('T')[0] 
          });
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
            console.log('✅ Found month period (de) - ambdós dies inclosos:', { 
              start: startDate.toISOString().split('T')[0], 
              end: endDate.toISOString().split('T')[0] 
            });
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
            console.log("✅ Found month period (d') - ambdós dies inclosos:", { 
              start: startDate.toISOString().split('T')[0], 
              end: endDate.toISOString().split('T')[0] 
            });
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
          console.log('✅ Found date period (/) - ambdós dies inclosos:', { 
            start: startDate.toISOString().split('T')[0], 
            end: endDate.toISOString().split('T')[0] 
          });
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
          console.log('✅ Found dash period (-) - ambdós dies inclosos:', { 
            start: startDate.toISOString().split('T')[0], 
            end: endDate.toISOString().split('T')[0] 
          });
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
      // Normalitzar totes les dates a mitjanit hora local per comparar només el dia
      const checkDate = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0);
      const startDate = new Date(restriction.start.getFullYear(), restriction.start.getMonth(), restriction.start.getDate(), 0, 0, 0, 0);
      const endDate = new Date(restriction.end.getFullYear(), restriction.end.getMonth(), restriction.end.getDate(), 0, 0, 0, 0);
      
      const isRestricted = checkDate >= startDate && checkDate <= endDate;
      
      if (isRestricted) {
        console.log(`   🔒 Data restringida: ${checkDate.toISOString().split('T')[0]} està dins del període ${startDate.toISOString().split('T')[0]} - ${endDate.toISOString().split('T')[0]} (ambdós inclosos)`);
      }
      
      return isRestricted;
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