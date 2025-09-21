import type { PageServerLoad } from './$types';
import { serverSupabase } from '$lib/server/supabaseAdmin';
import { requireAdmin } from '$lib/server/adminGuard';

export const load: PageServerLoad = async (event) => {
  await requireAdmin(event);
  
  const supabase = serverSupabase(event.request, true); // Use service role for admin operations

  try {
    // Carregar mitjanes històriques
    const { data: mitjanesList, error: mitjError } = await supabase
      .from('mitjanes_historiques')
      .select('*')
      .order('year', { ascending: false })
      .order('mitjana', { ascending: false });

    if (mitjError) throw mitjError;

    // Carregar tots els socis
    const { data: socisList, error: socisError } = await supabase
      .from('socis')
      .select('numero_soci, nom, cognoms, email')
      .order('cognoms');

    if (socisError) throw socisError;

    // Crear un mapa de socis per optimitzar les cerques
    const socisMap = new Map();
    (socisList || []).forEach(soci => {
      socisMap.set(soci.numero_soci, soci);
    });

    // Processar les mitjanes per incloure informació del soci
    const mitjanes = (mitjanesList || []).map(m => {
      const soci = socisMap.get(m.soci_id);
      return {
        ...m,
        nom_soci: soci?.nom || null,
        cognoms_soci: soci?.cognoms || null
      };
    });

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