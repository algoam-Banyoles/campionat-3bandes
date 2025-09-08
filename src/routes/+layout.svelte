<script lang="ts">
  import "../app.css";
  import { onMount } from "svelte";
  import { user, isAdmin, authReady, initAuth, logout } from "$lib/authStore";

  onMount(() => {
    // Inicialitza sessió + rol admin en muntar el layout
    initAuth();
  });

  // helper d’estils opcionals per remarcar link actiu
  import { page } from "$app/stores";
  const isActive = (href: string, current: string) =>
    current.startsWith(href) ? "underline font-semibold" : "hover:underline";
</script>

<nav class="bg-slate-900 text-white">
  <div class="mx-auto max-w-5xl px-4 py-3 flex items-center gap-6">
    <a href="/" class="font-semibold">Campionat 3 Bandes</a>
    <a href="/calendari" class={isActive("/calendari", $page.url.pathname)}>Calendari</a>
    <a href="/classificacio" class={isActive("/classificacio", $page.url.pathname)}>Classificació</a>
    <a href="/reptes" class={isActive("/reptes", $page.url.pathname)}>Reptes</a>

    {#if $authReady && $user}
      <a href="/reptes/me" class={isActive("/reptes/me", $page.url.pathname)}>Els meus reptes</a>
      <a href="/reptes/nou" class={isActive("/reptes/nou", $page.url.pathname)}>Crear repte</a>
    {/if}

    {#if $authReady && $isAdmin}
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
</nav>

<main class="mx-auto max-w-5xl p-4">
  <slot />
</main>

<!-- DEBUG opcional: treu-ho quan vulguis -->
{#if $authReady}
  <div class="fixed bottom-2 right-2 text-xs bg-slate-800 text-white px-2 py-1 rounded">
    {$user?.email ?? "anònim"} | admin: {$isAdmin ? "sí" : "no"}
  </div>
{/if}
