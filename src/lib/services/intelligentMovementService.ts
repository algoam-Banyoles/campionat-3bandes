/**
 * Servei de moviments intel·ligents entre categories de Campionats Socials.
 *
 * Conté la lògica pura de càlcul de cascades (sense dependència de Supabase),
 * més funcions auxiliars per carregar campions previs i aplicar moviments
 * en lot. La separació permet provar la lògica en isolació.
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import type {
  Category,
  CategoryMovement,
  InscripcioWithSoci,
  PreviousChampion,
  SociMin,
  UUID
} from '$lib/types';
import { fkOne } from '$lib/utils/supabaseJoins';

export interface IntelligentContext {
  inscriptions: InscripcioWithSoci[];
  categories: Category[];
  socis: SociMin[];
  previousChampions: Map<number, PreviousChampion>;
}

/**
 * Carrega els campions/subcampions de la temporada anterior per a una
 * combinació modalitat/temporada del mateix tipus de competició.
 *
 * Retorna un mapa `numero_soci → PreviousChampion`.
 */
export async function loadPreviousChampions(
  supabase: SupabaseClient,
  modalitat: string,
  currentTemporada: string | number
): Promise<Map<number, PreviousChampion>> {
  const result = new Map<number, PreviousChampion>();

  // Calcular temporada anterior. Suportem tant '2025-2026' com '2025'.
  const previousSeason = computePreviousSeason(currentTemporada);
  if (!previousSeason) return result;

  const { data, error } = await supabase
    .from('classificacions')
    .select(`
      soci_numero,
      posicio,
      categories (
        nom,
        ordre_categoria,
        events (
          modalitat,
          temporada
        )
      ),
      socis:socis!classificacions_soci_numero_fkey (
        numero_soci,
        nom,
        cognoms
      )
    `)
    .eq('categories.events.modalitat', modalitat)
    .eq('categories.events.temporada', previousSeason)
    .in('posicio', [1, 2])
    .order('posicio');

  if (error) {
    console.error('Error loading previous champions:', error);
    return result;
  }

  for (const row of (data || []) as any[]) {
    const soci: any = fkOne(row.socis);
    const cat: any = fkOne(row.categories);
    const evt: any = fkOne(cat?.events);
    const numeroSoci = soci?.numero_soci ?? row.soci_numero;
    if (!numeroSoci) continue;

    result.set(numeroSoci, {
      numero_soci: numeroSoci,
      posicio: row.posicio,
      categoria_nom: cat?.nom ?? null,
      ordre_categoria: cat?.ordre_categoria ?? null,
      modalitat: evt?.modalitat ?? null,
      temporada: evt?.temporada ?? null,
      nom: soci ? `${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim() : ''
    });
  }

  return result;
}

/**
 * Calcula la temporada anterior a la donada, suportant els formats
 * `'2025-2026'` i `'2025'`. Retorna null si no es pot parsejar.
 */
export function computePreviousSeason(temporada: string | number): string | null {
  if (typeof temporada === 'number') return String(temporada - 1);
  const dashMatch = temporada.match(/^(\d{4})\s*[-/]\s*(\d{4})$/);
  if (dashMatch) {
    const start = parseInt(dashMatch[1], 10);
    const end = parseInt(dashMatch[2], 10);
    return `${start - 1}-${end - 1}`;
  }
  const single = parseInt(temporada, 10);
  if (!isNaN(single)) return String(single - 1);
  return null;
}

/** Obté la mitjana d'un jugador a partir del soci enriquit (o 0). */
export function getPlayerAverage(
  inscription: InscripcioWithSoci,
  socis: SociMin[]
): number {
  const soci = socis.find(s => s.numero_soci === inscription.soci_numero);
  if (!soci) return 0;
  return soci.historicalAverage ?? (soci as any).mitjana ?? (soci as any).average ?? 0;
}

/**
 * Obté les inscripcions d'una categoria ordenades segons el criteri de
 * cascada: campions/subcampions primer, després mitjana descendent.
 */
export function getInscriptionsByCategory(
  ctx: IntelligentContext,
  categoryId: UUID,
  excludeInscriptionId: UUID | null = null
): Array<InscripcioWithSoci & { average: number; isChampion: boolean }> {
  return ctx.inscriptions
    .filter(ins => ins.categoria_assignada_id === categoryId && ins.id !== excludeInscriptionId)
    .map(ins => ({
      ...ins,
      average: getPlayerAverage(ins, ctx.socis),
      isChampion: ctx.previousChampions.has(ins.soci_numero)
    }))
    .sort((a, b) => {
      if (a.isChampion && !b.isChampion) return -1;
      if (b.isChampion && !a.isChampion) return 1;
      return (b.average || 0) - (a.average || 0);
    });
}

/**
 * Calcula la llista completa de moviments en cascada que han de produir-se
 * quan un jugador es mou d'una categoria a una altra.
 *
 * Funció pura: rep tot el context i retorna la llista de moviments.
 * No fa cap update a la base de dades. Cada moviment porta la categoria
 * d'origen (`previousCategoryId`) per facilitar el "desfer".
 */
export function calculateCascadeMovements(
  ctx: IntelligentContext,
  inscriptionId: UUID,
  targetCategoryId: UUID
): CategoryMovement[] {
  const movements: CategoryMovement[] = [];

  const inscription = ctx.inscriptions.find(i => i.id === inscriptionId);
  if (!inscription) return movements;

  const originalCategoryId = inscription.categoria_assignada_id;
  const targetCategory = ctx.categories.find(c => c.id === targetCategoryId);
  const originalCategory = originalCategoryId
    ? ctx.categories.find(c => c.id === originalCategoryId)
    : null;

  if (!targetCategory) return movements;

  // 1. Moviment principal
  movements.push({
    inscriptionId,
    categoryId: targetCategoryId,
    previousCategoryId: originalCategoryId ?? null,
    reason: 'Moviment manual',
    playerName: getPlayerName(inscription, ctx.socis)
  });

  // 2. Cascada (només si canvia de categoria)
  if (originalCategoryId && originalCategory && originalCategoryId !== targetCategoryId) {
    const isMovingUp = targetCategory.ordre_categoria < originalCategory.ordre_categoria;
    const isMovingDown = targetCategory.ordre_categoria > originalCategory.ordre_categoria;

    if (isMovingUp) {
      handleMoveUp(ctx, inscription, originalCategory, targetCategory, movements);
    } else if (isMovingDown) {
      handleMoveDown(ctx, inscription, originalCategory, targetCategory, movements);
    }
  }

  // 3. Cas especial: jugador sense mitjana cap a 1a categoria
  const movedAverage = getPlayerAverage(inscription, ctx.socis);
  if (movedAverage === 0 && targetCategory.ordre_categoria === 1) {
    handleNoAveragePlayerToTop(ctx, inscription, movements);
  }

  return movements;
}

/**
 * Construeix la llista inversa de moviments per a desfer un lot anterior.
 * Es processa en ordre invers per garantir consistència si hi ha cadenes.
 */
export function buildUndoMovements(applied: CategoryMovement[]): CategoryMovement[] {
  return applied
    .slice()
    .reverse()
    .map(m => ({
      inscriptionId: m.inscriptionId,
      // Per a desfer cal restaurar la categoria d'origen (que pot ser null).
      // L'`applyMovements` actual no permet null, ho tractarem allà.
      categoryId: (m.previousCategoryId as UUID) ?? '',
      previousCategoryId: m.categoryId,
      reason: `Desfer: ${m.reason}`,
      playerName: m.playerName
    }));
}

function getPlayerName(inscription: InscripcioWithSoci, socis: SociMin[]): string {
  if (inscription.socis) {
    return `${inscription.socis.nom ?? ''} ${inscription.socis.cognoms ?? ''}`.trim();
  }
  const soci = socis.find(s => s.numero_soci === inscription.soci_numero);
  if (!soci) return `Soci #${inscription.soci_numero}`;
  return `${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim() || `Soci #${inscription.soci_numero}`;
}

function handleMoveUp(
  ctx: IntelligentContext,
  movedInscription: InscripcioWithSoci,
  fromCategory: Category,
  toCategory: Category,
  movements: CategoryMovement[]
) {
  const targetCategoryPlayers = getInscriptionsByCategory(ctx, toCategory.id, movedInscription.id);

  let playerToDemote: typeof targetCategoryPlayers[number] | null = null;
  for (let i = targetCategoryPlayers.length - 1; i >= 0; i--) {
    if (!targetCategoryPlayers[i].isChampion) {
      playerToDemote = targetCategoryPlayers[i];
      break;
    }
  }

  if (playerToDemote) {
    movements.push({
      inscriptionId: playerToDemote.id,
      categoryId: fromCategory.id,
      previousCategoryId: playerToDemote.categoria_assignada_id ?? null,
      reason: `Baixa per fer lloc a jugador de ${fromCategory.nom}`,
      playerName: getPlayerName(playerToDemote, ctx.socis)
    });
  }
}

function handleMoveDown(
  ctx: IntelligentContext,
  movedInscription: InscripcioWithSoci,
  fromCategory: Category,
  toCategory: Category,
  movements: CategoryMovement[]
) {
  const targetCategoryPlayers = getInscriptionsByCategory(ctx, toCategory.id, movedInscription.id);
  if (targetCategoryPlayers.length === 0) return;

  const bestPlayer = targetCategoryPlayers[0];
  movements.push({
    inscriptionId: bestPlayer.id,
    categoryId: fromCategory.id,
    previousCategoryId: bestPlayer.categoria_assignada_id ?? null,
    reason: `Puja per ocupar lloc lliure a ${fromCategory.nom}`,
    playerName: getPlayerName(bestPlayer, ctx.socis)
  });
}

function handleNoAveragePlayerToTop(
  ctx: IntelligentContext,
  _movedInscription: InscripcioWithSoci,
  movements: CategoryMovement[]
) {
  const sortedCategories = ctx.categories
    .filter(c => c.ordre_categoria > 1)
    .sort((a, b) => a.ordre_categoria - b.ordre_categoria);

  for (const category of sortedCategories) {
    const players = getInscriptionsByCategory(ctx, category.id);

    let playerToDemote: typeof players[number] | null = null;
    for (let i = players.length - 1; i >= 0; i--) {
      if (!players[i].isChampion) {
        playerToDemote = players[i];
        break;
      }
    }

    if (!playerToDemote) continue;

    const lowerCategory = ctx.categories.find(
      c => c.ordre_categoria === category.ordre_categoria + 1
    );

    if (lowerCategory) {
      movements.push({
        inscriptionId: playerToDemote.id,
        categoryId: lowerCategory.id,
        previousCategoryId: playerToDemote.categoria_assignada_id ?? null,
        reason: `Baixa per efecte cascada (jugador sense mitjana a 1a)`,
        playerName: getPlayerName(playerToDemote, ctx.socis)
      });
    }
  }
}

/**
 * Aplica una llista de moviments com a UPDATEs successius a la taula
 * `inscripcions`. Si `categoryId` és cadena buida, s'interpreta com a
 * "deixar sense categoria" (null) — útil per desfer moviments d'un soci
 * que originalment no tenia categoria assignada.
 *
 * Retorna `null` si tot va bé, o el primer error trobat.
 */
export async function applyMovements(
  supabase: SupabaseClient,
  movements: CategoryMovement[]
): Promise<Error | null> {
  for (const m of movements) {
    const value = m.categoryId === '' ? null : m.categoryId;
    const { error } = await supabase
      .from('inscripcions')
      .update({ categoria_assignada_id: value })
      .eq('id', m.inscriptionId);

    if (error) {
      return new Error(error.message);
    }
  }
  return null;
}
