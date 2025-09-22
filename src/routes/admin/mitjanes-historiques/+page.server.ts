import type { PageServerLoad } from './$types';
import { serverSupabase } from '$lib/server/supabaseAdmin';
import { requireAdmin } from '$lib/server/adminGuard';

export const load: PageServerLoad = async (event) => {
  await requireAdmin(event);
  
  const supabase = serverSupabase(event.request, true); // Use service role for admin operations

  try {
    // Carregar mitjanes històriques en batches per evitar el límit per defecte de 1000 files
    const fetchAllMitjanes = async () => {
      const CHUNK = 1000;
      let from = 0;
      const all: any[] = [];

      while (true) {
        const { data, error } = await supabase
          .from('mitjanes_historiques')
          .select('*')
          .order('year', { ascending: false })
          .order('mitjana', { ascending: false })
          .range(from, from + CHUNK - 1);

        if (error) throw error;
        if (!data || data.length === 0) break;

        all.push(...data);
        if (data.length < CHUNK) break; // last chunk
        from += CHUNK;
      }

      return all;
    };

    // Si s'envia `page` als query params, fem paginació servidora
    const pageParam = event.url.searchParams.get('page');
    const limitParam = event.url.searchParams.get('limit');

    let mitjanesList: any[] = [];
    let totalCount: number | null = null;

    // Forcem paginació per defecte: si no es passa `page`, assumim page=1 i limit=200
    const DEFAULT_PAGE = 1;
    const DEFAULT_LIMIT = 200;

    const page = Math.max(1, parseInt(pageParam || String(DEFAULT_PAGE), 10) || DEFAULT_PAGE);
    const limit = Math.max(1, parseInt(limitParam || String(DEFAULT_LIMIT), 10) || DEFAULT_LIMIT);
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    const { data, error, count } = await supabase
      .from('mitjanes_historiques')
      .select('*', { count: 'exact' })
      .order('year', { ascending: false })
      .order('mitjana', { ascending: false })
      .range(from, to);

    if (error) throw error;
    mitjanesList = data || [];
    totalCount = typeof count === 'number' ? count : null;
    

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
      socis: socisList || [],
      page: page,
      limit: limit,
      total: totalCount
    };
  } catch (error) {
    console.error('Error carregant dades:', error);
    return {
      mitjanes: [],
      socis: []
    };
  }
};