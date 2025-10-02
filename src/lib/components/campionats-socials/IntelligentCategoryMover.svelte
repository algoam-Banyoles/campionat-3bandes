<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  const dispatch = createEventDispatcher();

  export let inscriptions: any[] = [];
  export let categories: any[] = [];
  export let socis: any[] = [];
  export let eventId: string = '';
  export let currentEvent: any = null;

  let previousChampions = new Map(); // numero_soci -> {posicio, categoria_nom, modalitat, temporada}
  let processing = false;

  // Carregar campions de temporada anterior
  async function loadPreviousChampions() {
    if (!currentEvent) return;

    try {
      // Calcular temporada anterior
      const currentYear = parseInt(currentEvent.temporada);
      const previousYear = currentYear - 1;
      const previousSeason = previousYear.toString();

      console.log('Loading champions from previous season:', previousSeason);

      const { data: champions, error } = await supabase
        .from('classificacions')
        .select(`
          player_id,
          posicio,
          categories (
            nom,
            ordre_categoria,
            events (
              modalitat,
              temporada
            )
          ),
          players (
            numero_soci,
            nom
          )
        `)
        .eq('categories.events.modalitat', currentEvent.modalitat)
        .eq('categories.events.temporada', previousSeason)
        .in('posicio', [1, 2]) // només campió i subcampió
        .order('posicio');

      if (error) {
        console.error('Error loading champions:', error);
        return;
      }

      previousChampions.clear();

      champions?.forEach(champion => {
        if (champion.players?.[0]?.numero_soci) {
          const numeroSoci = champion.players[0].numero_soci;
          const championInfo = {
            posicio: champion.posicio,
            categoria_nom: champion.categories?.[0]?.nom,
            ordre_categoria: champion.categories?.[0]?.ordre_categoria,
            modalitat: champion.categories?.[0]?.events?.[0]?.modalitat,
            temporada: champion.categories?.[0]?.events?.[0]?.temporada,
            nom: champion.players?.[0]?.nom
          };

          previousChampions.set(numeroSoci, championInfo);
        }
      });

      console.log(`Loaded ${previousChampions.size} previous champions from season ${previousSeason}`);

    } catch (error) {
      console.error('Error loading previous champions:', error);
    }
  }

  // Carregar campions quan canvia l'event
  $: if (eventId && currentEvent) {
    loadPreviousChampions();
  }

  // Obtenir mitjana d'un jugador
  function getPlayerAverage(inscription) {
    const soci = socis.find(s => s.numero_soci === inscription.soci_numero);

    // Intentar different formes d'obtenir la mitjana
    if (soci) {
      return soci.historicalAverage || soci.mitjana || soci.average || 0;
    }

    return 0;
  }

  // Comprovar si un jugador és campió/subcampió
  function isChampionOrRunnerUp(numeroSoci) {
    return previousChampions.has(numeroSoci);
  }

  // Obtenir categoria objetivo per un campió/subcampió
  function getTargetCategoryForChampion(numeroSoci) {
    const championInfo = previousChampions.get(numeroSoci);
    if (!championInfo) return null;

    // Si era de 3a categoria, va a 2a
    // Si era de 2a categoria, va a 1a
    // Si era de 1a categoria, queda a 1a
    const targetOrder = Math.max(1, championInfo.ordre_categoria - 1);

    return categories.find(cat => cat.ordre_categoria === targetOrder);
  }

  // Trobar inscripcions d'una categoria ordenades per mitjana (descendant)
  function getInscriptionsByCategory(categoryId, excludeInscriptionId = null) {
    return inscriptions
      .filter(ins => ins.categoria_assignada_id === categoryId && ins.id !== excludeInscriptionId)
      .map(ins => ({
        ...ins,
        average: getPlayerAverage(ins),
        isChampion: isChampionOrRunnerUp(ins.soci_numero)
      }))
      .sort((a, b) => {
        // Campions/subcampions van primer
        if (a.isChampion && !b.isChampion) return -1;
        if (b.isChampion && !a.isChampion) return 1;

        // Després per mitjana descendant
        return (b.average || 0) - (a.average || 0);
      });
  }

  // Moure jugador amb efecte cascada
  export async function movePlayerIntelligently(inscriptionId, targetCategoryId) {
    if (processing) return;
    processing = true;

    try {
      const inscription = inscriptions.find(ins => ins.id === inscriptionId);
      if (!inscription) {
        throw new Error('Inscripció no trobada');
      }

      const originalCategoryId = inscription.categoria_assignada_id;
      const targetCategory = categories.find(cat => cat.id === targetCategoryId);
      const originalCategory = categories.find(cat => cat.id === originalCategoryId);

      if (!targetCategory) {
        throw new Error('Categoria destí no vàlida');
      }

      console.log('Moving player intelligently:', {
        player: inscription.soci_numero,
        from: originalCategory?.nom,
        to: targetCategory.nom,
        isChampion: isChampionOrRunnerUp(inscription.soci_numero)
      });

      // Preparar moviments en cascada
      const movements = [];

      // 1. Moure el jugador principal
      movements.push({
        inscriptionId: inscriptionId,
        categoryId: targetCategoryId,
        reason: 'Moviment manual'
      });

      // 2. Calcular moviments en cascada
      if (originalCategoryId && originalCategoryId !== targetCategoryId) {
        await calculateCascadeMovements(
          inscription,
          originalCategory,
          targetCategory,
          movements
        );
      }

      // 3. Executar tots els moviments
      console.log('Executing movements:', movements);

      for (const movement of movements) {
        const { error } = await supabase
          .from('inscripcions')
          .update({ categoria_assignada_id: movement.categoryId })
          .eq('id', movement.inscriptionId);

        if (error) throw error;
      }

      // 4. Notificar canvis
      dispatch('movementsCompleted', {
        movements: movements,
        totalMoved: movements.length
      });

    } catch (error) {
      console.error('Error in intelligent movement:', error);
      dispatch('error', { message: error.message });
    } finally {
      processing = false;
    }
  }

  // Calcular moviments en cascada
  async function calculateCascadeMovements(movedInscription, fromCategory, toCategory, movements) {
    const movedAverage = getPlayerAverage(movedInscription);
    const isMovedPlayerChampion = isChampionOrRunnerUp(movedInscription.soci_numero);

    // Determinar direcció del moviment
    const isMovingUp = toCategory.ordre_categoria < fromCategory.ordre_categoria;
    const isMovingDown = toCategory.ordre_categoria > fromCategory.ordre_categoria;

    if (isMovingUp) {
      // Moviment cap amunt: l'últim de la categoria superior baixa
      await handleMoveUp(movedInscription, fromCategory, toCategory, movements);
    } else if (isMovingDown) {
      // Moviment cap avall: el millor de la categoria inferior puja
      await handleMoveDown(movedInscription, fromCategory, toCategory, movements);
    }

    // Cas especial: afegir jugador sense mitjana a categoria alta
    if (movedAverage === 0 && toCategory.ordre_categoria === 1) {
      await handleNoAveragePlayerToTop(movedInscription, movements);
    }
  }

  async function handleMoveUp(movedInscription, fromCategory, toCategory, movements) {
    // Trobar l'últim jugador de la categoria superior (menys campió/subcampió)
    const targetCategoryPlayers = getInscriptionsByCategory(toCategory.id, movedInscription.id);

    // Buscar el darrer jugador que NO sigui campió/subcampió
    let playerToDemote = null;
    for (let i = targetCategoryPlayers.length - 1; i >= 0; i--) {
      const player = targetCategoryPlayers[i];
      if (!player.isChampion) {
        playerToDemote = player;
        break;
      }
    }

    if (playerToDemote) {
      movements.push({
        inscriptionId: playerToDemote.id,
        categoryId: fromCategory.id,
        reason: `Baixa per fer lloc a jugador de ${fromCategory.nom}`
      });
    }
  }

  async function handleMoveDown(movedInscription, fromCategory, toCategory, movements) {
    // Trobar el millor jugador de la categoria inferior
    const targetCategoryPlayers = getInscriptionsByCategory(toCategory.id, movedInscription.id);

    if (targetCategoryPlayers.length > 0) {
      const bestPlayer = targetCategoryPlayers[0]; // ja està ordenat

      movements.push({
        inscriptionId: bestPlayer.id,
        categoryId: fromCategory.id,
        reason: `Puja per ocupar lloc lliure a ${fromCategory.nom}`
      });
    }
  }

  async function handleNoAveragePlayerToTop(movedInscription, movements) {
    // Quan s'afegeix un jugador sense mitjana a 1a categoria,
    // han de baixar jugadors de totes les categories
    const sortedCategories = categories
      .filter(cat => cat.ordre_categoria > 1)
      .sort((a, b) => a.ordre_categoria - b.ordre_categoria);

    for (const category of sortedCategories) {
      const players = getInscriptionsByCategory(category.id);

      // Buscar el darrer jugador que NO sigui campió/subcampió
      let playerToDemote = null;
      for (let i = players.length - 1; i >= 0; i--) {
        const player = players[i];
        if (!player.isChampion) {
          playerToDemote = player;
          break;
        }
      }

      if (playerToDemote) {
        // Trobar categoria inferior
        const lowerCategory = categories.find(cat =>
          cat.ordre_categoria === category.ordre_categoria + 1
        );

        if (lowerCategory) {
          movements.push({
            inscriptionId: playerToDemote.id,
            categoryId: lowerCategory.id,
            reason: `Baixa per efecte cascada (jugador sense mitjana a 1a)`
          });
        }
      }
    }
  }
</script>

<!-- Aquest component no té UI, només funcionalitat -->