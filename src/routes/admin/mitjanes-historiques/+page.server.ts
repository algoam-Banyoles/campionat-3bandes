import type { PageServerLoad } from './$types';
import { serverSupabase } from '$lib/server/supabaseAdmin';
import { requireAdmin } from '$lib/server/adminGuard';

export const load: PageServerLoad = async (event) => {
  await requireAdmin(event);
  
  const supabase = serverSupabase(event.request);

  try {
    // Carregar mitjanes amb informació del soci (si existeix)
    const { data: mitjanesList, error: mitjError } = await supabase
      .from('mitjanes_historiques')
      .select(`
        id,
        soci_id,
        year,
        modalitat,
        mitjana,
        socis (
          numero_soci,
          nom,
          cognoms
        )
      `)
      .order('year', { ascending: false })
      .order('mitjana', { ascending: false });

    if (mitjError) throw mitjError;

    // Processar les dades per incloure informació del soci
    const mitjanes = (mitjanesList || []).map(m => ({
      ...m,
      nom_soci: m.socis?.[0]?.nom || null,
      cognoms_soci: m.socis?.[0]?.cognoms || null
    }));

    // Carregar tots els socis per al dropdown
    const { data: socisList, error: socisError } = await supabase
      .from('socis')
      .select('numero_soci, nom, cognoms, email')
      .order('cognoms');

    if (socisError) throw socisError;

    return {
      mitjanes,
      socis: socisList || []
    };
  } catch (error) {
    console.error('Error carregant dades:', error);
    return {
      mitjanes: [],
      socis: []
    };
  }
};