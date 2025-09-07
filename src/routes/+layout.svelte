<script lang="ts">
  import "../app.css";
  import { user, loadingAuth } from '$lib/authStore';
  import { isAdmin } from '$lib/isAdmin';

  let admin = false;

  // Recalcula cada cop que canvia l'usuari i quan deixa de carregar l'autenticació
  $: if (!$loadingAuth) {
    (async () => {
      admin = await isAdmin();
      console.debug('[navbar] user=', $user?.email, 'admin=', admin);
    })();
  }
</script>

<nav class="bg-slate-900 text-white">
  <div class="mx-auto max-w-5xl px-4 py-3 flex items-center gap-6">
    <a href="/" class="font-semibold">Campionat 3 Bandes</a>
    <a href="/calendari" class="hover:underline">Calendari</a>
    <a href="/classificacio" class="hover:underline">Classificació</a>
    <a href="/socis" class="hover:underline">Socis</a>

    {#if !$loadingAuth && $user && admin}
      <a href="/admin" class="hover:underline">Admin</a>
    {/if}

    <div class="ml-auto flex items-center gap-3">
      {#if $loadingAuth}
        <span class="text-sm opacity-80">…</span>
      {:else if $user}
        <span class="text-sm opacity-80">{$user.email}</span>
        <a class="hover:underline" href="/logout">Surt</a>
      {:else}
        <a class="hover:underline" href="/login">Entra</a>
      {/if}
    </div>
  </div>
</nav>

<main class="mx-auto max-w-5xl p-4">
  <slot />
</main>

<!-- DEBUG opcional: elimina-ho quan vulguis -->
{#if !$loadingAuth}
  <div class="fixed bottom-2 right-2 text-xs bg-slate-800 text-white px-2 py-1 rounded">
    {$user?.email ?? 'anònim'} | admin: {admin ? 'sí' : 'no'}
  </div>
{/if}
