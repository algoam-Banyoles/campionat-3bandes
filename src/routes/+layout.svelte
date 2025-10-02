<script lang="ts">
  import "../app.css";
  import { onMount } from "svelte";
  import { user, status, adminStore, isLoading } from "$lib/stores/auth";
  import { initAuthClient, signOut } from "$lib/utils/auth-client";
  import { initializeNotifications } from '$lib/stores/notifications';
  import { setupFocusManagement } from "$lib/utils/focus-management";
  import Toasts from '$lib/components/general/Toasts.svelte';
  import Nav from '$lib/components/general/Nav.svelte';
  import AccessibilityButton from "$lib/components/accessibility/AccessibilityButton.svelte";
  import AccessibilityModal from "$lib/components/accessibility/AccessibilityModal.svelte";
  import SkipLink from "$lib/components/accessibility/SkipLink.svelte";

  let showInscripcio = false;
  let showAccessibilityModal = false;

  type SessionUser = { email: string | null } | null;

  async function refreshInscripcioVisibility(u: SessionUser) {
    if (!u?.email) {
      showInscripcio = false;
      return;
    }

    // Verificar que l'usuari està correctament autenticat
    if ($status !== 'authenticated') {
      showInscripcio = false;
      return;
    }

    try {
      const { supabase } = await import('$lib/supabaseClient');
      
      // Verificar que tenim una sessió vàlida abans de fer peticions
      const { data: sessionData } = await supabase.auth.getSession();
      if (!sessionData.session) {
        console.warn('No valid session for inscripcio check');
        showInscripcio = false;
        return;
      }

      const { data: ev, error: eEv } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .limit(1)
        .maybeSingle();
      
      if (eEv) {
        // Si és un error d'autenticació, no mostrar warnings
        if (eEv.code === 'PGRST301' || eEv.message?.includes('JWT')) {
          console.warn('Auth error in refreshInscripcioVisibility:', eEv.message);
          showInscripcio = false;
          return;
        }
        throw eEv;
      }
      
      const eventId = ev?.id;
      if (!eventId) {
        showInscripcio = false;
        return;
      }
      
      // Buscar jugador via players (estructura actual)
      const { data: pl, error: ePl } = await supabase
        .from('players')
        .select('id')
        .eq('email', u.email)
        .maybeSingle();
      
      if (ePl) {
        if (ePl.code === 'PGRST301' || ePl.message?.includes('JWT')) {
          console.warn('Auth error fetching player:', ePl.message);
          showInscripcio = false;
          return;
        }
        throw ePl;
      }
      
      if (!pl) {
        showInscripcio = false;
        return;
      }
      
      const { data: rp, error: eRp } = await supabase
        .from('ranking_positions')
        .select('posicio')
        .eq('event_id', eventId)
        .eq('player_id', pl.id)
        .maybeSingle();
      
      if (eRp) {
        if (eRp.code === 'PGRST301' || eRp.message?.includes('JWT')) {
          console.warn('Auth error fetching ranking:', eRp.message);
          showInscripcio = false;
          return;
        }
        throw eRp;
      }
      
      if (rp) {
        showInscripcio = false;
        return;
      }
      
      const { data: wl, error: eWl } = await supabase
        .from('waiting_list')
        .select('id')
        .eq('event_id', eventId)
        .eq('player_id', pl.id)
        .maybeSingle();
      
      if (eWl) {
        if (eWl.code === 'PGRST301' || eWl.message?.includes('JWT')) {
          console.warn('Auth error fetching waiting list:', eWl.message);
          showInscripcio = false;
          return;
        }
        throw eWl;
      }
      
      showInscripcio = !wl;
      
    } catch (e) {
      // Només mostrar error si no és un problema d'autenticació
      const errorMessage = e instanceof Error ? e.message : String(e);
      if (!errorMessage.includes('JWT') && !errorMessage.includes('401') && !errorMessage.includes('400')) {
        console.warn('refreshInscripcioVisibility error', e);
      }
      showInscripcio = false;
    }
  }

  onMount(() => {
    // Inicialitza sessió + rol admin en muntar el layout
    initAuthClient();

    // Inicialitza sistema de notificacions push
    initializeNotifications();

    // Configura gestió del focus per accessibilitat
    setupFocusManagement();
  });


    $: if ($status === 'authenticated') {
      void refreshInscripcioVisibility($user);
    }

  function openAccessibilityModal() {
    showAccessibilityModal = true;
  }

  function closeAccessibilityModal() {
    showAccessibilityModal = false;
  }
</script>


<SkipLink />

<!-- Accessibility button -->
<AccessibilityButton on:open={openAccessibilityModal} />

<!-- Accessibility modal -->
<AccessibilityModal
  bind:isOpen={showAccessibilityModal}
  on:close={closeAccessibilityModal}
/>

{#if $isLoading}
  <div class="fullpage-spinner">Carregant sessió…</div>
{:else}
  <Nav />

  <main id="main-content" class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-4 sm:py-6 lg:py-8 pb-safe" tabindex="-1">
    <slot />
  </main>

  <Toasts />
{/if}
