import type { SupabaseClient } from '@supabase/supabase-js';

export type SociWithAverage = {
  numero_soci: number;
  nom: string;
  cognoms: string;
  email: string;
  historicalAverage: number | null;
  historicalAverageYear: number | null;
  oldestAverage: number | null;
  oldestAverageYear: number | null;
};

export type CategoryAssignment = {
  inscriptionId: string;
  categoryId: string;
  categoryName: string;
  playerName: string;
};

const MODALITY_MAPPING: Record<string, string> = {
  'tres_bandes': '3 BANDES',
  'lliure': 'LLIURE',
  'banda': 'BANDA'
};

/**
 * Load active socis with their historical averages for a given event modality.
 */
export async function loadSocisWithAverages(
  supabase: SupabaseClient,
  eventModality: string | null
): Promise<SociWithAverage[]> {
  const { data: socisData, error: socisError } = await supabase
    .from('socis')
    .select('numero_soci, nom, cognoms, email')
    .eq('de_baixa', false)
    .order('nom');

  if (socisError) throw socisError;

  if (!socisData || socisData.length === 0) {
    return [];
  }

  const currentYear = new Date().getFullYear();
  const lastTwoYears = [currentYear, currentYear - 1];

  let queryRecent = supabase
    .from('mitjanes_historiques')
    .select('soci_id, mitjana, year, modalitat')
    .in('year', lastTwoYears);

  let queryAll = supabase
    .from('mitjanes_historiques')
    .select('soci_id, mitjana, year, modalitat');

  if (eventModality) {
    const historialModality = MODALITY_MAPPING[eventModality] || eventModality.toUpperCase();
    queryRecent = queryRecent.eq('modalitat', historialModality);
    queryAll = queryAll.eq('modalitat', historialModality);
  }

  const [{ data: recentMitjanes, error: recentErr }, { data: allMitjanes, error: allErr }] =
    await Promise.all([queryRecent, queryAll]);

  if (recentErr) console.error('Error loading recent mitjanes_historiques:', recentErr);
  if (allErr) console.error('Error loading all mitjanes_historiques:', allErr);

  return socisData.map((soci) => {
    let bestMitjana: number | null = null;
    let bestMitjanaYear: number | null = null;
    let oldestMitjana: number | null = null;
    let oldestMitjanaYear: number | null = null;

    if (recentMitjanes) {
      const playerRecentMitjanes = recentMitjanes.filter((m) => m.soci_id === soci.numero_soci);

      if (playerRecentMitjanes.length > 0) {
        const bestRecent = playerRecentMitjanes.reduce((best, current) => {
          const currentAvg = parseFloat(current.mitjana);
          const bestAvg = parseFloat(best.mitjana);
          return currentAvg > bestAvg ? current : best;
        });
        bestMitjana = parseFloat(bestRecent.mitjana);
        bestMitjanaYear = bestRecent.year;
      }
    }

    if (bestMitjana === null && allMitjanes) {
      const playerAllMitjanes = allMitjanes
        .filter((m) => m.soci_id === soci.numero_soci)
        .filter((m) => !lastTwoYears.includes(m.year));

      if (playerAllMitjanes.length > 0) {
        const mostRecentOld = playerAllMitjanes.reduce((mostRecent, current) => {
          return current.year > mostRecent.year ? current : mostRecent;
        });
        oldestMitjana = parseFloat(mostRecentOld.mitjana);
        oldestMitjanaYear = mostRecentOld.year;
      }
    }

    return {
      numero_soci: soci.numero_soci,
      nom: soci.nom,
      cognoms: soci.cognoms || '',
      email: soci.email,
      historicalAverage: bestMitjana,
      historicalAverageYear: bestMitjanaYear,
      oldestAverage: oldestMitjana,
      oldestAverageYear: oldestMitjanaYear
    };
  });
}

/**
 * Distribute players evenly across categories (shuffled to avoid bias).
 * Clears existing assignments first, then assigns in batches.
 */
export async function assignPlayersToCategories(
  supabase: SupabaseClient,
  inscriptions: any[],
  categories: any[]
): Promise<{ assignments: CategoryAssignment[]; error: string | null }> {
  if (!inscriptions.length || !categories.length) {
    return { assignments: [], error: 'Necessites inscripcions i categories per arreglar les assignacions' };
  }

  // Clear all existing assignments
  const clearPromises = inscriptions.map((inscription) =>
    supabase
      .from('inscripcions')
      .update({ categoria_assignada_id: null })
      .eq('id', inscription.id)
  );
  await Promise.all(clearPromises);

  // Distribute players evenly
  const playersPerCategory = Math.floor(inscriptions.length / categories.length);
  const remainingPlayers = inscriptions.length % categories.length;

  const assignments: CategoryAssignment[] = [];
  let playerIndex = 0;

  const sortedCategories = [...categories].sort(
    (a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0)
  );

  // Shuffle to avoid bias (early sign-ups going to top categories)
  const shuffledInscriptions = [...inscriptions].sort(() => Math.random() - 0.5);

  for (let i = 0; i < sortedCategories.length; i++) {
    const category = sortedCategories[i];
    const playersInThisCategory = playersPerCategory + (i < remainingPlayers ? 1 : 0);

    for (let j = 0; j < playersInThisCategory && playerIndex < shuffledInscriptions.length; j++) {
      assignments.push({
        inscriptionId: shuffledInscriptions[playerIndex].id,
        categoryId: category.id,
        categoryName: category.nom,
        playerName: `${shuffledInscriptions[playerIndex].socis?.nom} ${shuffledInscriptions[playerIndex].socis?.cognoms}`
      });
      playerIndex++;
    }
  }

  // Apply assignments in batches
  const batchSize = 10;
  for (let i = 0; i < assignments.length; i += batchSize) {
    const batch = assignments.slice(i, i + batchSize);

    const updatePromises = batch.map(({ inscriptionId, categoryId }) =>
      supabase
        .from('inscripcions')
        .update({ categoria_assignada_id: categoryId })
        .eq('id', inscriptionId)
    );

    const results = await Promise.all(updatePromises);

    const errors = results.filter((r) => r.error);
    if (errors.length > 0) {
      throw new Error(
        `Errors en ${errors.length} assignacions del lot: ${errors[0].error!.message}`
      );
    }
  }

  return { assignments, error: null };
}

/**
 * Build a human-readable distribution summary from assignments.
 */
export function formatAssignmentSummary(assignments: CategoryAssignment[]): string {
  const distribution = assignments.reduce<Record<string, number>>((acc, a) => {
    acc[a.categoryName] = (acc[a.categoryName] || 0) + 1;
    return acc;
  }, {});

  const distributionText = Object.entries(distribution)
    .map(([category, count]) => `${category}: ${count}`)
    .join('\n');

  return `${assignments.length} jugadors assignats:\n${distributionText}`;
}
