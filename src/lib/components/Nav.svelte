<script lang="ts">
  import { page } from '$app/stores';
  import { user, isAdmin, logout } from '$lib/authStore';

  // enllaços sempre visibles
  const baseLinks = [
    { href: '/', label: 'Inici' },
    { href: '/calendari', label: 'Calendari' },
    { href: '/classificacio', label: 'Classificació' },
    { href: '/reptes', label: 'Reptes' },
    { href: '/socis', label: 'Socis' }
  ];

  let open = false;

  function isActive(href: string) {
    const p = $page.url.pathname;
    return p === href || (href !== '/' && p.startsWith(href));
  }
</script>

<nav class="sticky top-0 z-50 border-b bg-white/80 backdrop-blur">
  <div class="mx-auto max-w-6xl px-4">
    <div class="flex h-14 items-center justify-between gap-3">
      <a href="/" class="font-semibold tracking-tight">Campionat 3B</a>

      <!-- Desktop -->
      <ul class="hidden sm:flex gap-2">
        {#each baseLinks as l}
          <li>
            <a
              href={l.href}
              class="px-2 py-1 rounded hover:bg-slate-100"
              class:bg-slate-900={isActive(l.href)}
              class:text-white={isActive(l.href)}
            >
              {l.label}
            </a>
          </li>
        {/each}

        {#if $user}
          <li>
            <a
              href="/reptes/me"
              class="px-2 py-1 rounded hover:bg-slate-100"
              class:bg-slate-900={isActive('/reptes/me')}
              class:text-white={isActive('/reptes/me')}
            >
              Els meus reptes
            </a>
          </li>
          <li>
            <a
              href="/reptes/nou"
              class="px-2 py-1 rounded hover:bg-slate-100"
              class:bg-slate-900={isActive('/reptes/nou')}
              class:text-white={isActive('/reptes/nou')}
            >
              Nou repte
            </a>
          </li>
        {/if}

        {#if $user && $isAdmin}
          <li>
            <a
              href="/admin"
              class="px-2 py-1 rounded hover:bg-slate-100 hover:underline"
              class:bg-slate-900={
                isActive('/admin') &&
                !$page.url.pathname.startsWith('/admin/config') &&
                !$page.url.pathname.startsWith('/admin/penalitzacions')
              }
              class:text-white={
                isActive('/admin') &&
                !$page.url.pathname.startsWith('/admin/config') &&
                !$page.url.pathname.startsWith('/admin/penalitzacions')
              }
            >
              Admin
            </a>
          </li>
          <li>
            <a
              href="/admin/config"
              class="px-2 py-1 rounded hover:bg-slate-100 hover:underline"
              class:bg-slate-900={isActive('/admin/config')}
              class:text-white={isActive('/admin/config')}
            >
              Configuració
            </a>
          </li>
          <li>
            <a
              href="/admin/penalitzacions"
              class="px-2 py-1 rounded hover:bg-slate-100 hover:underline"
              class:bg-slate-900={isActive('/admin/penalitzacions')}
              class:text-white={isActive('/admin/penalitzacions')}
            >
              Penalitzacions
            </a>
          </li>
        {/if}
      </ul>

      <!-- Dreta -->
      <div class="ml-auto flex items-center gap-2">
        {#if $user}
          <span class="text-sm text-slate-600 hidden sm:inline">{$user.email}</span>
          <button class="rounded bg-slate-900 text-white px-3 py-1" on:click={logout}>
            Surt
          </button>
        {:else}
          <a href="/login" class="rounded bg-slate-900 text-white px-3 py-1">Entra</a>
        {/if}

        <button
          class="sm:hidden rounded p-2 hover:bg-slate-100"
          on:click={() => (open = !open)}
          aria-label="Obre/ tanca menú">☰</button>
      </div>
    </div>

    <!-- Mòbil -->
    {#if open}
      <ul class="sm:hidden pb-3 space-y-1">
        {#each baseLinks as l}
          <li>
            <a
              href={l.href}
              class="block px-2 py-2 rounded hover:bg-slate-100"
              class:bg-slate-900={isActive(l.href)}
              class:text-white={isActive(l.href)}
              on:click={() => (open = false)}
            >
              {l.label}
            </a>
          </li>
        {/each}

        {#if $user}
          <li>
            <a
              href="/reptes/me"
              class="block px-2 py-2 rounded hover:bg-slate-100"
              class:bg-slate-900={isActive('/reptes/me')}
              class:text-white={isActive('/reptes/me')}
              on:click={() => (open = false)}
            >
              Els meus reptes
            </a>
          </li>
          <li>
            <a
              href="/reptes/nou"
              class="block px-2 py-2 rounded hover:bg-slate-100"
              class:bg-slate-900={isActive('/reptes/nou')}
              class:text-white={isActive('/reptes/nou')}
              on:click={() => (open = false)}
            >
              Nou repte
            </a>
          </li>
        {/if}

        {#if $user && $isAdmin}
          <li>
            <a
              href="/admin"
              class="block px-2 py-2 rounded hover:bg-slate-100 hover:underline"
              class:bg-slate-900={
                isActive('/admin') &&
                !$page.url.pathname.startsWith('/admin/config') &&
                !$page.url.pathname.startsWith('/admin/penalitzacions')
              }
              class:text-white={
                isActive('/admin') &&
                !$page.url.pathname.startsWith('/admin/config') &&
                !$page.url.pathname.startsWith('/admin/penalitzacions')
              }
              on:click={() => (open = false)}
            >
              Admin
            </a>
          </li>
          <li>
            <a
              href="/admin/config"
              class="block px-2 py-2 rounded hover:bg-slate-100 hover:underline"
              class:bg-slate-900={isActive('/admin/config')}
              class:text-white={isActive('/admin/config')}
              on:click={() => (open = false)}
            >
              Configuració
            </a>
          </li>
          <li>
            <a
              href="/admin/penalitzacions"
              class="block px-2 py-2 rounded hover:bg-slate-100 hover:underline"
              class:bg-slate-900={isActive('/admin/penalitzacions')}
              class:text-white={isActive('/admin/penalitzacions')}
              on:click={() => (open = false)}
            >
              Penalitzacions
            </a>
          </li>
        {/if}

        <li class="pt-2 border-t">
          {#if $user}
            <button class="w-full text-left px-2 py-2 rounded hover:bg-slate-100" on:click={logout}>
              Surt ({$user.email})
            </button>
          {:else}
            <a href="/login" class="block px-2 py-2 rounded hover:bg-slate-100">Entra</a>
          {/if}
        </li>
      </ul>
    {/if}
  </div>
</nav>
