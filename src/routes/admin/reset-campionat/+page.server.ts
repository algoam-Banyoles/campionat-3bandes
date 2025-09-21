import { redirect } from '@sveltejs/kit';
import type { PageServerLoad, Actions } from './$types';
import { supabase } from '$lib/supabaseClient';

export const load: PageServerLoad = async ({ url }) => {
	// Verificar si l'usuari és admin
	const email = url.searchParams.get('email') || '';
	
	if (!email) {
		throw redirect(302, '/');
	}

	const { data: isAdmin } = await supabase
		.rpc('is_admin', { p_email: email });

	if (!isAdmin) {
		throw redirect(302, '/');
	}

	return {
		isAdmin: true,
		email
	};
};

export const actions: Actions = {
	reset: async ({ request }) => {
		const data = await request.formData();
		const email = data.get('email') as string;
		const confirmationText = data.get('confirmation') as string;

		// Verificar admin
		const { data: isAdmin } = await supabase
			.rpc('is_admin', { p_email: email });

		if (!isAdmin) {
			return {
				success: false,
				error: 'No tens permisos d\'administrador'
			};
		}

		// Verificar text de confirmació
		if (confirmationText !== 'RESET CAMPIONAT') {
			return {
				success: false,
				error: 'Cal escriure exactament "RESET CAMPIONAT" per confirmar'
			};
		}

		try {
			// Executar el reset
			const { data: result, error } = await supabase
				.rpc('admin_reset_championship');

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