<script lang="ts">
    import { page } from '$app/stores';
    import { user } from '$lib/stores/auth';
    import { isAdmin } from '$lib/stores/adminAuth';
    import { signOut } from '$lib/utils/auth-client';
    import { isDevUser } from '$lib/guards/devOnly';

  // Tipus per als enllaços
  type NavLink = {
    href: string;
    label: string;
    disabled?: boolean;
  };

  // Tipus per a les seccions de navegació
  type NavSection = {
    label: string;
    icon: string;
    color: string;
    links: NavLink[];
    userLinks?: NavLink[];
    adminOnly?: boolean;
  };

  // Estructura principal de navegació
  const navegacio: Record<string, NavSection> = {
    general: {
      label: 'General',
      icon: '🏠',
      color: 'gray',
      links: [
        { href: '/', label: 'Inici' },
        { href: '/general/calendari', label: 'Calendari General' },
        { href: '/general/multimedia', label: 'Multimedia' }
      ]
    },
    socials: {
      label: 'Campionats Socials',
      icon: '🏆',
      color: 'green',
      links: [
        { href: '/campionats-socials?view=active', label: 'Lligues en Curs' },
        { href: '/campionats-socials?view=history', label: 'Historial' },
        { href: '/campionats-socials?view=players', label: 'Cerca Jugadors' }
      ],
      userLinks: [
        { href: '/campionats-socials/inscripcions', label: 'Inscripcions Obertes' }
      ]
    },
    ranking: {
      label: 'Campionat Ranking',
      icon: '📊',
      color: 'blue',
      links: [
        { href: '/campionat-continu/ranking', label: 'Classificació' },
        { href: '/campionat-continu/reptes', label: 'Reptes' },
        { href: '/campionat-continu/llista-espera', label: "Llista d'espera" },
        { href: '/campionat-continu/historial', label: 'Historial' }
      ],
      userLinks: [
        { href: '/campionat-continu/reptes/me', label: 'Els meus reptes' },
        { href: '/campionat-continu/reptes/nou', label: 'Nou repte' }
      ]
    },
    handicap: {
      label: 'Campionat Hàndicap',
      icon: '⚖️',
      color: 'purple',
      links: [
        { href: '/handicap', label: 'Proximament', disabled: true }
      ]
    },
    admin: {
      label: 'Administració',
      icon: '⚙️',
      color: 'red',
      links: [
        { href: '/admin', label: 'Dashboard' },
        { href: '/admin/events', label: 'Events' },
        { href: '/admin/categories', label: 'Categories' },
        { href: '/admin/inscripcions', label: 'Inscripcions' },
        { href: '/admin/inscripcions-socials', label: 'Inscripcions Socials' },
        { href: '/admin/mitjanes-historiques', label: 'Mitjanes Històriques' }
      ],
      adminOnly: true
    }
  };

  // Detectar secció actual basada en la ruta
  function getCurrentSection() {
    const path = $page.url.pathname;
    if (path.includes('/admin')) {
      return 'admin';
    }
    if (path.includes('/campionats-socials')) {
      return 'socials';
    }
    if (path.includes('/campionat-continu')) {
      return 'ranking';
    }
    if (path.includes('/handicap')) {
      return 'handicap';
    }
    return 'general'; // Default
  }

  let selectedSection = getCurrentSection();
  let open = false;
  let dropdownOpen = false;
  let mobileMenuOpen = false;
  let activeDropdown: string | null = null;

  // Reactivitat per actualitzar la secció seleccionada
  $: selectedSection = getCurrentSection();

  function isActive(href: string) {
    const p = $page.url.pathname;
    return p === href || (href !== '/' && p.startsWith(href));
  }

  // Tancar dropdown quan es clica fora
  function handleClickOutside(event) {
    if (activeDropdown && !event.target.closest('[data-dropdown]')) {
      activeDropdown = null;
    }
  }

  // Funció per gestionar el toggle del dropdown
  function toggleDropdown(sectionKey: string) {
    if (activeDropdown === sectionKey) {
      activeDropdown = null;
    } else {
      activeDropdown = sectionKey;
    }
  }

  // Tancar dropdown quan es navega
  function closeDropdownOnNavigate() {
    activeDropdown = null;
  }
</script>

<svelte:window on:click={handleClickOutside} />

<nav class="sticky top-0 z-50 bg-white border-b border-gray-200 shadow-sm">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <!-- Navegació principal -->
    <div class="flex h-16 justify-between">
      <!-- Logo -->
      <div class="flex flex-shrink-0 items-center">
        <a href="/" class="flex items-center space-x-3">
          <img src="/logo.png" alt="Foment Martinenc" class="h-10 w-10 object-contain" />
          <div class="hidden sm:flex sm:flex-col">
            <span class="text-sm font-bold text-gray-900 leading-tight">Secció de Billar del</span>
            <span class="text-sm font-bold text-gray-900 leading-tight">Foment Martinenc</span>
          </div>
          <span class="text-sm font-bold text-gray-900 sm:hidden">Foment Martinenc</span>
        </a>
      </div>

      <!-- Seccions principals centrades (Desktop) -->
      <div class="hidden sm:flex sm:items-center sm:justify-center flex-1 h-16">
        <div class="flex items-center space-x-8">
          {#each Object.entries(navegacio) as [key, section]}
            {#if !section.adminOnly || $isAdmin}
              <div class="relative" data-dropdown>
                <button
                  on:click={() => toggleDropdown(key)}
                  class="inline-flex items-center px-3 py-2 border-b-2 text-sm font-medium {
                    selectedSection === key
                      ? 'border-' + section.color + '-500 text-' + section.color + '-600'
                      : 'border-transparent text-gray-900 hover:text-gray-700 hover:border-gray-300'
                  }"
                >
                  <span class="mr-1">{section.icon}</span>
                  {section.label}
                  <svg class="ml-1 h-4 w-4 transition-transform duration-200 {
                    activeDropdown === key ? 'rotate-180' : ''
                  }" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>

                <!-- Dropdown -->
                {#if activeDropdown === key}
                  <div class="absolute top-full left-0 mt-1 w-64 bg-white rounded-md shadow-lg border border-gray-200 z-50">
                    <div class="py-2">
                      {#each section.links as link}
                        <a
                          href={link.href}
                          on:click={closeDropdownOnNavigate}
                          class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 {
                            link.disabled ? 'opacity-50 cursor-not-allowed' : ''
                          } {
                            isActive(link.href) ? 'bg-' + section.color + '-50 text-' + section.color + '-700' : ''
                          }"
                          class:pointer-events-none={link.disabled}
                        >
                          {link.label}
                        </a>
                      {/each}

                      <!-- User links si n'hi ha -->
                      {#if $user && section.userLinks && section.userLinks.length > 0}
                        <hr class="my-2">
                        {#each section.userLinks as link}
                          <a
                            href={link.href}
                            on:click={closeDropdownOnNavigate}
                            class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 {
                              isActive(link.href) ? 'bg-' + section.color + '-50 text-' + section.color + '-700' : ''
                            }"
                          >
                            {link.label}
                          </a>
                        {/each}
                      {/if}
                    </div>
                  </div>
                {/if}
              </div>
            {/if}
          {/each}
        </div>
      </div>

      <!-- Menú d'usuari (Dreta) -->
      <div class="hidden sm:ml-6 sm:flex sm:items-center">
        {#if $user}
          <span class="text-sm text-gray-700 mr-4">{$user.email}</span>
          <button
            on:click={signOut}
            class="bg-gray-800 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-700"
          >
            Sortir
          </button>
        {:else}
          <a
            href="/general/login"
            class="bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700"
          >
            Iniciar Sessió
          </a>
        {/if}
      </div>

      <!-- Menú mòbil button -->
      <div class="flex items-center sm:hidden">
        <button
          on:click={() => mobileMenuOpen = !mobileMenuOpen}
          class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100"
          aria-expanded="false"
          aria-label="Obrir menú de navegació"
        >
          <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
      </div>
    </div>

    <!-- Menú mòbil -->
    {#if mobileMenuOpen}
      <div class="sm:hidden">
        <div class="pt-2 pb-3 space-y-1">
          {#each Object.entries(navegacio) as [, section]}
            {#if !section.adminOnly || $isAdmin}
              <div class="px-2">
                <div class="text-gray-500 font-medium text-xs uppercase tracking-wider py-2">
                  {section.icon} {section.label}
                </div>
                {#each section.links as link}
                  <a
                    href={link.href}
                    class="block pl-4 pr-4 py-2 text-base font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-50 {
                      link.disabled ? 'opacity-50 cursor-not-allowed' : ''
                    } {
                      isActive(link.href) ? 'bg-' + section.color + '-50 text-' + section.color + '-700' : ''
                    }"
                    class:pointer-events-none={link.disabled}
                  >
                    {link.label}
                  </a>
                {/each}
              </div>
            {/if}
          {/each}
        </div>

        <!-- User menu mòbil -->
        <div class="pt-4 pb-3 border-t border-gray-200">
          {#if $user}
            <div class="px-4">
              <div class="text-base font-medium text-gray-800">{$user.email}</div>
            </div>
            <div class="mt-3 px-2">
              <button
                on:click={signOut}
                class="block w-full text-left px-4 py-2 text-base font-medium text-gray-500 hover:text-gray-800 hover:bg-gray-100"
              >
                Sortir
              </button>
            </div>
          {:else}
            <div class="px-2">
              <a
                href="/general/login"
                class="block px-4 py-2 text-base font-medium text-blue-600 hover:text-blue-800 hover:bg-blue-50"
              >
                Iniciar Sessió
              </a>
            </div>
          {/if}
        </div>
      </div>
    {/if}
  </div>
</nav>