import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/supabaseClient';

export const POST: RequestHandler = async () => {
  try {
    const matchId = '892f8de0-7f93-40c9-9da7-fa9fda092586';

    console.log(`Updating match ${matchId} using exact same method as OldMatchesModal`);

    // Usa exactament el mateix format que OldMatchesModal.svelte
    const { error: updateError } = await supabase
      .from('calendari_partides')
      .update({
        estat: 'pendent_programar',
        data_programada: null,
        hora_inici: null,
        taula_assignada: null
      })
      .eq('id', matchId);

    console.log('Update result:', { error: updateError });

    if (updateError) {
      return json({ 
        error: `Update failed: ${updateError.message}`,
        code: updateError.code
      }, { status: 500 });
    }

    // Verifica que s'actualitzà
    const { data: updated, error: selectError } = await supabase
      .from('calendari_partides')
      .select('id, estat, data_programada, hora_inici, taula_assignada')
      .eq('id', matchId)
      .single();

    if (selectError) {
      return json({ 
        error: `Verification failed: ${selectError.message}` 
      }, { status: 500 });
    }

    if (updated?.estat === 'pendent_programar') {
      return json({
        success: true,
        message: 'Match updated successfully',
        match: updated
      });
    } else {
      return json({ 
        error: 'Update verification failed - status not changed',
        match: updated 
      }, { status: 500 });
    }
  } catch (error) {
    console.error('Exception:', error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      { status: 500 }
    );
  }
};
