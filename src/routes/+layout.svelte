<script lang="ts">
  import "../app.css";
  import { onMount } from "svelte";
  import { user, status, adminStore, isLoading } from "$lib/stores/auth";
  import { initAuthClient, signOut } from "$lib/utils/auth-client";
  import { initializeNotifications } from '$lib/stores/notifications';
  import Toasts from '$lib/components/Toasts.svelte';
  import MobileNavigation from '$lib/components/navigation/MobileNavigation.svelte';

  let showInscripcio = false;

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
      
      const { data: pl, error: ePl } = await supabase
        .from('socis')
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
  });

  // helper d’estils opcionals per remarcar link actiu
  import { page } from "$app/stores";
  const isActive = (href: string, current: string) =>
    current.startsWith(href) ? "underline font-semibold" : "hover:underline";

  let menuOpen = false;
  const toggleMenu = () => (menuOpen = !menuOpen);

  // Tancar menú quan es fa clic fora
  function handleClickOutside(event: MouseEvent) {
    if (menuOpen && event.target instanceof Element) {
      const nav = event.target.closest('nav');
      if (!nav) {
        menuOpen = false;
      }
    }
  }

    $: if ($status === 'authenticated') {
      void refreshInscripcioVisibility($user);
    }
</script>

<!-- Detectar clics fora del menú per tancar-lo -->
<svelte:window on:click={handleClickOutside} />

{#if $isLoading}
  <div class="fullpage-spinner">Carregant sessió…</div>
{:else}
<nav class="bg-slate-900 text-white">
  <div class="mx-auto max-w-5xl px-4 py-3 flex items-center gap-6">
    <a href="/" class="font-semibold">Campionat 3 Bandes</a>

    <div class="hidden md:flex items-center gap-6 flex-1">
      <a href="/calendari" class={isActive("/calendari", $page.url.pathname)}>Calendari</a>
      <a href="/ranking" class={isActive("/ranking", $page.url.pathname)}>Classificació</a>
      <a href="/reptes" class={isActive("/reptes", $page.url.pathname)}>Reptes</a>
      <a href="/llista-espera" class={isActive("/llista-espera", $page.url.pathname)}>Llista d'espera</a>
      <a href="/historial" class={isActive("/historial", $page.url.pathname)}>Historial</a>

        {#if $status === 'authenticated' && $user}
        {#if showInscripcio}
          <a href="/inscripcio" class={isActive("/inscripcio", $page.url.pathname)}>Inscripció</a>
        {/if}
        <a href="/reptes/me" class={isActive("/reptes/me", $page.url.pathname)}>Els meus reptes</a>
        <a href="/reptes/nou" class={isActive("/reptes/nou", $page.url.pathname)}>Crear repte</a>
        <a href="/configuracio/notificacions" class={isActive("/configuracio/notificacions", $page.url.pathname)}>
          Notificacions
        </a>
      {/if}

        {#if $status === 'authenticated' && $adminStore}
        <a href="/admin" class={isActive("/admin", $page.url.pathname)}>Admin</a>
      {/if}

      <div class="ml-auto flex items-center gap-3">
          {#if $status === 'loading'}
            <span class="text-sm opacity-80">…</span>
          {:else if $user}
          <span class="text-sm opacity-80">{$user.email}</span>
          <button
            class="rounded border px-3 py-1 text-sm hover:bg-slate-800"
            on:click={signOut}
          >
            Sortir
          </button>
        {:else}
          <a class="rounded border px-3 py-1 text-sm hover:bg-slate-800" href="/login">Entra</a>
        {/if}
      </div>
    </div>

    <button
      class="ml-auto md:hidden p-3 rounded-lg hover:bg-slate-700 transition-all duration-200 relative"
      class:bg-slate-700={menuOpen}
      on:click={toggleMenu}
      aria-label={menuOpen ? "Tancar menú" : "Obrir menú"}
      aria-expanded={menuOpen}
    >
      <svg class="h-6 w-6 transition-transform duration-200" class:rotate-90={menuOpen} fill="none" stroke="currentColor" viewBox="0 0 24 24">
        {#if menuOpen}
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        {:else}
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
        {/if}
      </svg>
    </button>
  </div>

  {#if menuOpen}
    <div
      class="md:hidden px-4 pb-4 bg-slate-800 border-t border-slate-700 animate-slideDown"
    >
      <!-- Navegació principal -->
      <div class="flex flex-col gap-2 py-3">
        <a href="/calendari" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/calendari', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
          📅 Calendari
        </a>
        <a href="/ranking" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/ranking', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
          🏆 Classificació
        </a>
        <a href="/reptes" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/reptes', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
          ⚔️ Reptes
        </a>
        <a href="/llista-espera" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/llista-espera', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
          ⏳ Llista d'espera
        </a>
        <a href="/historial" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/historial', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
          📜 Historial
        </a>
      </div>

      <!-- Secció d'usuari autenticat -->
      {#if $status === 'authenticated' && $user}
        <div class="border-t border-slate-700 pt-3 flex flex-col gap-2">
          {#if showInscripcio}
            <a href="/inscripcio" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/inscripcio', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
              ✍️ Inscripció
            </a>
          {/if}
          <a href="/reptes/me" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/reptes/me', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
            👤 Els meus reptes
          </a>
          <a href="/reptes/nou" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/reptes/nou', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
            ➕ Crear repte
          </a>
          <a href="/configuracio/notificacions" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/configuracio/notificacions', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
            🔔 Notificacions
          </a>
        </div>
      {/if}

      <!-- Secció admin -->
      {#if $status === 'authenticated' && $adminStore}
        <div class="border-t border-slate-700 pt-3">
          <a href="/admin" class="block py-3 px-4 rounded-lg text-white hover:bg-slate-700 transition-colors {isActive('/admin', $page.url.pathname) ? 'bg-slate-600' : ''}" on:click={() => menuOpen = false}>
            ⚙️ Admin
          </a>
        </div>
      {/if}

      <!-- Secció d'autenticació -->
      <div class="border-t border-slate-700 pt-3 flex flex-col gap-3">
        {#if $status === 'loading'}
          <span class="text-sm opacity-80 px-3">Carregant…</span>
        {:else if $user}
          <div class="px-3">
            <span class="text-sm opacity-80 block mb-2">{$user.email}</span>
            <button
              class="w-full bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded transition-colors"
              on:click={() => { signOut(); menuOpen = false; }}
            >
              Sortir
            </button>
          </div>
        {:else}
          <div class="px-3">
            <a
              class="block w-full bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded text-center transition-colors"
              href="/login"
              on:click={() => menuOpen = false}
            >
              Entra
            </a>
          </div>
        {/if}
      </div>
    </div>
  {/if}
</nav>

<main class="mx-auto max-w-5xl p-2 sm:p-4">
  <slot />
</main>

<Toasts />
<!-- <MobileNavigation /> -->

{/if}
