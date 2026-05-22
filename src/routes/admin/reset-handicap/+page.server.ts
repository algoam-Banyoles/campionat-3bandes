import { redirect } from '@sveltejs/kit';
import type { PageServerLoad, Actions } from './$types';
import { serverSupabase } from '$lib/server/adminGuard';

interface HandicapEventRow {
	id: string;
	nom: string;
	temporada: string | null;
	estat_competicio: string | null;
	creat_el: string | null;
	participants: number;
	matches: number;
	matches_jugats: number;
}

export const load: PageServerLoad = async (event) => {
	const supabase = serverSupabase(event);
	const { data: isAdmin, error } = await supabase.rpc('is_admin_by_email');

	if (error || isAdmin !== true) {
		throw redirect(302, '/');
	}

	// Llistar tots els events hàndicap (inclou finalitzats per mostrar protecció d'històric)
	const { data: events } = await supabase
		.from('events')
		.select('id, nom, temporada, estat_competicio, creat_el')
		.eq('tipus_competicio', 'handicap')
		.order('creat_el', { ascending: false });

	const rows: HandicapEventRow[] = [];
	for (const e of events ?? []) {
		const [{ count: nPart }, { count: nMatch }, { count: nPlayed }] = await Promise.all([
			supabase
				.from('handicap_participants')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', e.id as string),
			supabase
				.from('handicap_matches')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', e.id as string),
			supabase
				.from('handicap_matches')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', e.id as string)
				.in('estat', ['jugada', 'walkover'])
		]);
		rows.push({
			id: e.id as string,
			nom: (e.nom as string) ?? '(sense nom)',
			temporada: (e.temporada as string) ?? null,
			estat_competicio: (e.estat_competicio as string) ?? null,
			creat_el: (e.creat_el as string) ?? null,
			participants: nPart ?? 0,
			matches: nMatch ?? 0,
			matches_jugats: nPlayed ?? 0
		});
	}

	return { isAdmin: true, events: rows };
};

export const actions: Actions = {
	deleteEvent: async (event) => {
		const data = await event.request.formData();
		const eventId = data.get('event_id') as string;
		const confirmationText = data.get('confirmation') as string;

		const supabase = serverSupabase(event);
		const { data: isAdmin } = await supabase.rpc('is_admin_by_email');
		if (isAdmin !== true) {
			return { success: false, error: 'No tens permisos d\'administrador' };
		}

		if (!eventId) {
			return { success: false, error: 'Falta l\'identificador de l\'event' };
		}

		if (confirmationText !== 'ESBORRAR') {
			return {
				success: false,
				error: 'Cal escriure exactament "ESBORRAR" per confirmar'
			};
		}

		try {
			const { data: result, error } = await supabase.rpc('admin_delete_handicap_event', {
				p_event_id: eventId
			});

			if (error) {
				console.error('Error esborrant event hàndicap:', error);
				return { success: false, error: error.message };
			}

			return {
				success: true,
				message: 'Event hàndicap esborrat correctament',
				result
			};
		} catch (err) {
			console.error('Error inesperat:', err);
			return { success: false, error: 'Error inesperat durant l\'esborrat' };
		}
	}
};
