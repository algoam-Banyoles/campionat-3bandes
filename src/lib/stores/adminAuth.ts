import { writable, derived } from 'svelte/store';
import { user } from './auth';
import { supabase } from '$lib/supabaseClient';

export const isAdmin = writable(false);
export const adminChecked = writable(false);

// Lista d'emails d'administradors (pots afegir més aquí)
const ADMIN_EMAILS = [
  'admin@campionat3bandes.com',
  'junta@campionat3bandes.com',
  'algoam@gmail.com',  // Email real d'administrador
  // Afegeix aquí els emails dels administradors
];

// Funció per verificar si un usuari és admin
export async function checkAdminStatus(userEmail: string): Promise<boolean> {
  try {
    console.log('🔍 checkAdminStatus called with email:', userEmail);
    console.log('🔍 ADMIN_EMAILS:', ADMIN_EMAILS);
    console.log('🔍 Email lowercased:', userEmail.toLowerCase());

    // Primer, comprova per email (mètode ràpid)
    if (ADMIN_EMAILS.includes(userEmail.toLowerCase())) {
      console.log('✅ User is admin (found in ADMIN_EMAILS)');
      return true;
    }

    // Comprova la taula d'admins
    const { data: adminData, error: adminError } = await supabase
      .from('admins')
      .select('email')
      .eq('email', userEmail.toLowerCase())
      .single();

    if (adminData) {
      return true;
    }

    // Si no està a la taula d'admins, comprova si és membre de la junta directiva via socis
    // (assumint que tens un camp per això a la taula socis)
    const { data: sociData, error: sociError } = await supabase
      .from('socis')
      .select('numero_soci')
      .eq('email', userEmail.toLowerCase())
      .single();

    if (sociError && sociError.code !== 'PGRST116') {
      console.error('Error checking socis status:', sociError);
    }

    // Per ara, retorna false si no està a la taula d'admins
    // Pots afegir lògica addicional aquí si tens camps específics per la junta
    return false;

  } catch (error) {
    console.error('Error in checkAdminStatus:', error);
    return false;
  }
}

// Subscripció automàtica per actualitzar l'estat d'admin quan canvia l'usuari
user.subscribe(async (currentUser) => {
  adminChecked.set(false);

  if (currentUser?.email) {
    const adminStatus = await checkAdminStatus(currentUser.email);
    isAdmin.set(adminStatus);
    adminChecked.set(true);

    console.log('Admin status checked:', {
      email: currentUser.email,
      isAdmin: adminStatus
    });
  } else {
    isAdmin.set(false);
    adminChecked.set(true);
  }
});

// Store derivat que combina usuari i estat d'admin
export const adminUser = derived(
  [user, isAdmin, adminChecked],
  ([$user, $isAdmin, $adminChecked]) => ({
    user: $user,
    isAdmin: $isAdmin,
    adminChecked: $adminChecked
  })
);