<script lang="ts">
  import "../app.css";
  import { onMount } from "svelte";
  import { user, authReady, initAuth, logout } from "$lib/authStore";
  import { adminStore } from '$lib/roles';

  onMount(() => {
    // Inicialitza sessió + rol admin en muntar el layout
    initAuth();
  });

  // helper d’estils opcionals per remarcar link actiu
  import { page } from "$app/stores";
  const isActive = (href: string, current: string) =>
    current.startsWith(href) ? "underline font-semibold" : "hover:underline";

  let menuOpen = false;
  const toggleMenu = () => (menuOpen = !menuOpen);
</script>

<nav class="bg-slate-900 text-white">
  <div class="mx-auto max-w-5xl px-4 py-3 flex items-center gap-6">
    <a href="/" class="font-semibold">Campionat 3 Bandes</a>

    <div class="hidden md:flex items-center gap-6 flex-1">
      <a href="/calendari" class={isActive("/calendari", $page.url.pathname)}>Calendari</a>
      <a href="/classificacio" class={isActive("/classificacio", $page.url.pathname)}>Classificació</a>
      <a href="/reptes" class={isActive("/reptes", $page.url.pathname)}>Reptes</a>

      {#if $authReady && $user}
        <a href="/inscripcio" class={isActive("/inscripcio", $page.url.pathname)}>Inscripció</a>
        <a href="/reptes/me" class={isActive("/reptes/me", $page.url.pathname)}>Els meus reptes</a>
        <a href="/reptes/nou" class={isActive("/reptes/nou", $page.url.pathname)}>Crear repte</a>
      {/if}

      {#if $authReady && $adminStore}
        <a href="/admin" class={isActive("/admin", $page.url.pathname)}>Admin</a>
      {/if}

      <div class="ml-auto flex items-center gap-3">
        {#if !$authReady}
          <span class="text-sm opacity-80">…</span>
        {:else if $user}
          <span class="text-sm opacity-80">{$user.email}</span>
          <button
            class="rounded border px-3 py-1 text-sm hover:bg-slate-800"
            on:click={logout}
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
      <a href="/classificacio" class={isActive("/classificacio", $page.url.pathname)}>Classificació</a>
      <a href="/reptes" class={isActive("/reptes", $page.url.pathname)}>Reptes</a>

      {#if $authReady && $user}
        <a href="/inscripcio" class={isActive("/inscripcio", $page.url.pathname)}>Inscripció</a>
        <a href="/reptes/me" class={isActive("/reptes/me", $page.url.pathname)}>Els meus reptes</a>
        <a href="/reptes/nou" class={isActive("/reptes/nou", $page.url.pathname)}>Crear repte</a>
      {/if}

      {#if $authReady && $adminStore}
        <a href="/admin" class={isActive("/admin", $page.url.pathname)}>Admin</a>
      {/if}

      <div class="pt-2 flex flex-col gap-2">
        {#if !$authReady}
          <span class="text-sm opacity-80">…</span>
        {:else if $user}
          <span class="text-sm opacity-80">{$user.email}</span>
          <button
            class="w-fit rounded border px-3 py-1 text-sm hover:bg-slate-800"
            on:click={() => { logout(); menuOpen = false; }}
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

<!-- DEBUG opcional: treu-ho quan vulguis -->
{#if $authReady}
  <div class="fixed bottom-2 right-2 text-xs bg-slate-800 text-white px-2 py-1 rounded">
    {$user?.email ?? "anònim"} | admin: {$adminStore ? "sí" : "no"}
  </div>
{/if}
