import { redirect } from '@sveltejs/kit';
import type { PageServerLoad, Actions } from './$types';
import { serverSupabase } from '$lib/server/adminGuard';

// Comprovació via `is_admin_by_email()` que usa el JWT del client (no
// un paràmetre arbitrari de la URL). Aquesta era la causa d'un bypass
// d'autorització: abans qualsevol podia passar `?email=algoam@gmail.com`
// i el servidor confiava en aquest valor.
export const load: PageServerLoad = async (event) => {
	const supabase = serverSupabase(event);
	const { data: isAdmin, error } = await supabase.rpc('is_admin_by_email');

	if (error || isAdmin !== true) {
		throw redirect(302, '/');
	}

	return { isAdmin: true };
};

export const actions: Actions = {
	reset: async (event) => {
		const data = await event.request.formData();
		const confirmationText = data.get('confirmation') as string;

		const supabase = serverSupabase(event);
		const { data: isAdmin } = await supabase.rpc('is_admin_by_email');

		if (isAdmin !== true) {
			return {
				success: false,
				error: 'No tens permisos d\'administrador'
			};
		}

		if (confirmationText !== 'RESET CAMPIONAT') {
			return {
				success: false,
				error: 'Cal escriure exactament "RESET CAMPIONAT" per confirmar'
			};
		}

		try {
			const { data: result, error } = await supabase.rpc('admin_reset_championship');

			if (error) {
				console.error('Error en reset:', error);
				return {
					success: false,
					error: `Error executant el reset: ${error.message}`
				};
			}

			return {
				success: true,
				message: 'Reset del campionat executat correctament',
				result
			};

		} catch (err) {
			console.error('Error inesperat:', err);
			return {
				success: false,
				error: 'Error inesperat durant el reset'
			};
		}
	}
};