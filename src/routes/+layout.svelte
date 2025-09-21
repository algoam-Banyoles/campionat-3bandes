<script lang="ts">
  import "../app.css";
  import { onMount } from "svelte";
  import { user, status, adminStore, isLoading } from "$lib/stores/auth";
  import { initAuthClient, signOut } from "$lib/utils/auth-client";
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
  });

  // helper d’estils opcionals per remarcar link actiu
  import { page } from "$app/stores";
  const isActive = (href: string, current: string) =>
    current.startsWith(href) ? "underline font-semibold" : "hover:underline";

  let menuOpen = false;
  const toggleMenu = () => (menuOpen = !menuOpen);

    $: if ($status === 'authenticated') {
      void refreshInscripcioVisibility($user);
    }
</script>

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
      class="ml-auto md:hidden"
      on:click={toggleMenu}
      aria-label="Obrir menú"
    >
      <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
      </svg>
    </button>
  </div>

  {#if menuOpen}
    <div class="md:hidden px-4 pb-4 flex flex-col gap-2">
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

        <div class="pt-2 flex flex-col gap-2">
          {#if $status === 'loading'}
            <span class="text-sm opacity-80">…</span>
          {:else if $user}
          <span class="text-sm opacity-80">{$user.email}</span>
          <button
            class="w-fit rounded border px-3 py-1 text-sm hover:bg-slate-800"
            on:click={() => { signOut(); menuOpen = false; }}
          >
            Sortir
          </button>
        {:else}
          <a class="w-fit rounded border px-3 py-1 text-sm hover:bg-slate-800" href="/login">Entra</a>
        {/if}
      </div>
    </div>
  {/if}
</nav>

<main class="mx-auto max-w-5xl p-2 sm:p-4">
  <slot />
</main>

<Toasts />
<MobileNavigation />

<!-- DEBUG opcional: treu-ho quan vulguis -->
  {#if $status !== 'loading'}
  <div class="fixed bottom-2 right-2 text-xs bg-slate-800 text-white px-2 py-1 rounded">
    {$user?.email ?? "anònim"} | admin: {$adminStore ? "sí" : "no"}
  </div>
{/if}
{/if}
