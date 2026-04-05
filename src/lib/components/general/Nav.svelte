<script lang="ts">
    import { page } from '$app/stores';
    import { user } from '$lib/stores/auth';
    import { isAdmin } from '$lib/stores/adminAuth';
    import { signOut } from '$lib/utils/auth-client';
    import { isDevUser } from '$lib/guards/devOnly';
    import { viewMode, effectiveIsAdmin } from '$lib/stores/viewMode';

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
    adminLinks?: NavLink[];
    adminOnly?: boolean;
  };

  // Estructura principal de navegació
  const navegacio: Record<string, NavSection> = {
    general: {
      label: 'Inici',
      icon: '🏠',
      color: 'gray',
      links: [
        { href: '/', label: 'Pàgina Principal' },
        { href: '/general/calendari', label: 'Calendari General' },
        { href: '/general/multimedia', label: 'Multimèdia' }
      ]
    },
    socials: {
      label: 'Socials',
      icon: '🏆',
      color: 'green',
      links: [
        { href: '/campionats-socials?view=active', label: 'Veure Campionats Actius' },
        { href: '/campionats-socials?view=history', label: 'Historial de Campionats' },
        { href: '/campionats-socials/cerca-jugadors', label: 'Buscar Jugadors' }
      ],
      userLinks: [
        { href: '/campionats-socials/inscripcions', label: 'Inscriure\'s a Campionats' }
      ],
      adminLinks: [
        { href: '/campionats-socials?view=active&admin=true', label: 'Preparació Campionats' }
      ]
    },
    ranking: {
      label: 'Continu',
      icon: '📊',
      color: 'blue',
      links: [
        { href: '/campionat-continu/ranking', label: 'Veure Classificació' },
        { href: '/campionat-continu/reptes', label: 'Tots els Reptes' },
        { href: '/campionat-continu/historial', label: 'Historial de Partides' },
        { href: '/campionat-continu/llista-espera', label: "Llista d'Espera" }
      ],
      userLinks: [
        { href: '/campionat-continu/reptes/nou', label: 'Crear Nou Repte' },
        { href: '/campionat-continu/reptes/me', label: 'Els Meus Reptes Actius' }
      ]
    },
    handicap: {
      label: 'Hàndicap',
      icon: '⚖️',
      color: 'purple',
      links: [
        { href: '/handicap', label: 'Dashboard' },
        { href: '/handicap/quadre', label: 'Quadre' },
        { href: '/handicap/partides', label: 'Partides' },
        { href: '/handicap/historial', label: 'Historial' },
        { href: '/handicap/estadistiques', label: 'Estadístiques' }
      ],
      adminLinks: [
        { href: '/handicap/configuracio', label: 'Configuració' },
        { href: '/handicap/inscripcions', label: 'Inscripcions' },
        { href: '/handicap/sorteig', label: 'Sorteig' }
      ]
    },
    admin: {
      label: 'Administració',
      icon: '⚙️',
      color: 'red',
      links: [
        { href: '/admin', label: 'Dashboard' },
        { href: '/admin/socis', label: 'Gestió de Socis' },
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
  let mobileMenuOpen = false;
  let activeDropdown: string | null = null;
  let mobileExpandedSection: string | null = null;

  // Reactivitat per actualitzar la secció seleccionada
  $: selectedSection = getCurrentSection();

  function isActive(href: string) {
    const p = $page.url.pathname;
    return p === href || (href !== '/' && p.startsWith(href));
  }

  // Tancar dropdown quan es clica fora
  function handleClickOutside(event: MouseEvent) {
    if (activeDropdown && !(event.target as Element)?.closest('[data-dropdown]')) {
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

  // Tancar menú mòbil quan es navega
  function closeMobileMenuOnNavigate() {
    mobileMenuOpen = false;
    activeDropdown = null;
    mobileExpandedSection = null;
  }

  // Toggle secció mòbil
  function toggleMobileSection(sectionKey: string) {
    if (mobileExpandedSection === sectionKey) {
      mobileExpandedSection = null;
    } else {
      mobileExpandedSection = sectionKey;
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

<!-- Sidebar fixa per desktop/tablet/landscape (oculta NOMÉS en portrait mobile) -->
<aside class="hidden portrait:md:block landscape:block fixed left-0 top-0 h-screen portrait:md:w-56 landscape:w-20 landscape:lg:w-56 bg-gradient-to-b from-gray-50 to-gray-100 border-r-2 border-gray-300 shadow-lg z-[9999]">
  <!-- Logo header -->
  <div class="p-3 border-b-2 border-gray-300 bg-white flex-shrink-0">
    <a href="/" class="flex items-center justify-center portrait:md:justify-start landscape:lg:justify-start gap-3">
      <img src="/logo.png" alt="Foment Martinenc" class="h-10 w-10 object-contain" />
      <span class="hidden portrait:md:flex landscape:lg:flex flex-col justify-center text-sm font-bold text-gray-900 leading-tight">
        <span>Foment</span>
        <span>Martinenc</span>
      </span>
    </a>
  </div>

  <!-- Navigation sections -->
  <div class="flex flex-col h-[calc(100vh-4.5rem)]">
    <div class="flex-1 overflow-y-auto py-2">
      {#each Object.entries(navegacio) as [key, section]}
        {#if !section.adminOnly || $isAdmin}
          <div class="mb-1">
            <!-- Section button -->
            <button
              on:click={() => toggleMobileSection(key)}
              class="w-full flex items-center justify-center portrait:md:justify-start landscape:lg:justify-start gap-2 px-3 py-2 hover:bg-white/60 transition-all duration-200 {
                selectedSection === key ? 'bg-white border-l-4 border-' + section.color + '-500 text-' + section.color + '-700' : 'text-gray-700'
              }"
              title={section.label}
            >
              <span class="text-xl flex-shrink-0">{section.icon}</span>
              <span class="hidden portrait:md:block landscape:lg:block text-sm font-semibold">{section.label}</span>
              <svg class="hidden portrait:md:block landscape:lg:block ml-auto h-3 w-3 transition-transform duration-200 {
                mobileExpandedSection === key ? 'rotate-180' : ''
              }" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
            </button>

            <!-- Expanded section links -->
            {#if mobileExpandedSection === key}
              <div class="bg-white/40 border-l-2 border-{section.color}-200 ml-2 portrait:md:ml-3 landscape:lg:ml-3">
                {#each section.links as link}
                  <a
                    href={link.href}
                    class="flex items-center px-3 portrait:md:px-4 landscape:lg:px-4 py-1.5 text-xs portrait:md:text-sm landscape:lg:text-sm font-medium hover:bg-white/80 transition-colors {
                      link.disabled ? 'opacity-50 cursor-not-allowed' : ''
                    } {
                      isActive(link.href) ? 'bg-' + section.color + '-50 text-' + section.color + '-800 border-l-2 border-' + section.color + '-500' : 'text-gray-700'
                    }"
                    class:pointer-events-none={link.disabled}
                  >
                    <span class="hidden portrait:md:block landscape:lg:block">{link.label}</span>
                    <span class="portrait:md:hidden landscape:lg:hidden text-[10px] text-center w-full leading-tight">{link.label.substring(0, 15)}{link.label.length > 15 ? '..' : ''}</span>
                  </a>
                {/each}

                {#if $user && section.userLinks && section.userLinks.length > 0}
                  <div class="border-t border-gray-200 mt-1 pt-1">
                    <div class="px-3 portrait:md:px-4 landscape:lg:px-4 py-0.5">
                      <span class="hidden portrait:md:block landscape:lg:block text-[10px] font-semibold text-gray-500 uppercase">Meves</span>
                    </div>
                    {#each section.userLinks as link}
                      <a
                        href={link.href}
                        class="flex items-center px-3 portrait:md:px-4 landscape:lg:px-4 py-1.5 text-xs portrait:md:text-sm landscape:lg:text-sm font-medium hover:bg-white/80 transition-colors {
                          isActive(link.href) ? 'bg-' + section.color + '-50 text-' + section.color + '-800 border-l-2 border-' + section.color + '-500' : 'text-gray-700'
                        }"
                      >
                        <span class="hidden portrait:md:block landscape:lg:block">{link.label}</span>
                        <span class="portrait:md:hidden landscape:lg:hidden text-[10px] text-center w-full leading-tight">{link.label.substring(0, 15)}{link.label.length > 15 ? '..' : ''}</span>
                      </a>
                    {/each}
                  </div>
                {/if}

                {#if $isAdmin && section.adminLinks && section.adminLinks.length > 0}
                  <div class="border-t border-gray-200 mt-1 pt-1">
                    {#if !$user || !section.userLinks || section.userLinks.length === 0}
                      <div class="px-3 portrait:md:px-4 landscape:lg:px-4 py-0.5">
                        <span class="hidden portrait:md:block landscape:lg:block text-[10px] font-semibold text-gray-500 uppercase">Meves</span>
                      </div>
                    {/if}
                    {#each section.adminLinks as link}
                      <a
                        href={link.href}
                        class="flex items-center px-3 portrait:md:px-4 landscape:lg:px-4 py-1.5 text-xs portrait:md:text-sm landscape:lg:text-sm font-medium hover:bg-white/80 transition-colors {
                          isActive(link.href) ? 'bg-' + section.color + '-50 text-' + section.color + '-800 border-l-2 border-' + section.color + '-500' : 'text-gray-700'
                        }"
                      >
                        <span class="hidden portrait:md:block landscape:lg:block">{link.label}</span>
                        <span class="portrait:md:hidden landscape:lg:hidden text-[10px] text-center w-full leading-tight">{link.label.substring(0, 15)}{link.label.length > 15 ? '..' : ''}</span>
                      </a>
                    {/each}
                  </div>
                {/if}
              </div>
            {/if}
          </div>
        {/if}
      {/each}
    </div>

    <!-- User section at bottom -->
    <div class="flex-shrink-0 border-t-2 border-gray-300 bg-white p-2">
      {#if $user}
        <div class="space-y-1.5">
          <div class="hidden portrait:md:block landscape:lg:block">
            <div class="text-[10px] text-gray-600">Sessió:</div>
            <div class="text-xs font-semibold text-gray-900 truncate">{$user.email}</div>
          </div>

          {#if $isAdmin}
            <div class="flex items-center justify-between gap-1">
              <span class="hidden portrait:md:block landscape:lg:block text-[10px] text-gray-700">Vista {$viewMode === 'admin' ? 'Admin' : 'Jug.'}</span>
              <button
                on:click={() => viewMode.toggleMode()}
                class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors {
                  $viewMode === 'admin' ? 'bg-blue-600' : 'bg-green-600'
                }"
                title="Canviar vista"
              >
                <span class="sr-only">Toggle view mode</span>
                <span class="inline-block h-3 w-3 transform rounded-full bg-white transition-transform {
                  $viewMode === 'admin' ? 'translate-x-5' : 'translate-x-1'
                }"></span>
              </button>
            </div>
          {/if}

          <button
            on:click={signOut}
            class="w-full flex items-center justify-center gap-1 px-2 py-1.5 text-xs font-medium text-white bg-red-600 hover:bg-red-700 rounded transition-colors"
          >
            <span class="portrait:md:hidden landscape:lg:hidden text-sm">🚪</span>
            <span class="hidden portrait:md:block landscape:lg:block">Sortir</span>
          </button>
        </div>
      {:else}
        <a
          href="/general/login"
          class="w-full flex items-center justify-center gap-1 px-2 py-1.5 text-xs font-medium text-white bg-blue-600 hover:bg-blue-700 rounded transition-colors"
        >
          <span class="portrait:md:hidden landscape:lg:hidden text-sm">🔐</span>
          <span class="hidden portrait:md:block landscape:lg:block">Iniciar Sessió</span>
        </a>
      {/if}
    </div>
  </div>
</aside>

<!-- Navbar superior NOMÉS per portrait mobile (quan no hi ha sidebar) -->
<nav class="portrait:md:hidden landscape:hidden sticky top-0 z-[9998] bg-white border-b border-gray-200 shadow-sm" aria-label="Navegació principal">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <!-- Navegació principal -->
    <div class="flex h-20 landscape:h-14 justify-between">
      <!-- Logo (simplified) - Only show on portrait mobile when sidebar is hidden -->
      <div class="flex flex-shrink-0 items-center landscape:hidden portrait:lg:hidden">
        <a href="/" class="flex items-center" title="Secció de Billar del Foment Martinenc">
          <img src="/logo.png" alt="Foment Martinenc" class="h-12 w-12 object-contain" />
        </a>
      </div>

      <!-- Seccions principals centrades (Desktop) - Hidden when sidebar is visible -->
      <!-- Only show on very large screens where there's space for both -->
      <div class="hidden portrait:xl:hidden landscape:2xl:hidden 2xl:flex 2xl:items-center 2xl:justify-center flex-1 h-20">
        <div class="flex items-center space-x-4 2xl:space-x-8">
          {#each Object.entries(navegacio) as [key, section]}
            {#if !section.adminOnly || $isAdmin}
              <div class="relative" data-dropdown>
                <button
                  on:click={() => toggleDropdown(key)}
                  class="inline-flex items-center px-3 2xl:px-4 py-3 border-b-3 text-lg font-semibold min-h-[56px] rounded-t-lg transition-all duration-200 {
                    selectedSection === key
                      ? 'border-' + section.color + '-500 text-' + section.color + '-700 bg-' + section.color + '-50'
                      : 'border-transparent text-gray-900 hover:text-gray-700 hover:border-gray-400 hover:bg-gray-50'
                  }"
                  title={section.adminOnly ? section.label : ''}
                >
                  <span class="{section.adminOnly ? '' : 'mr-2'} text-xl">{section.icon}</span>
                  {#if !section.adminOnly}
                    {section.label}
                  {/if}
                  <svg class="ml-1 h-4 w-4 transition-transform duration-200 {
                    activeDropdown === key ? 'rotate-180' : ''
                  }" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>

                <!-- Dropdown -->
                {#if activeDropdown === key}
                  <div class="absolute top-full left-0 mt-1 w-72 bg-white rounded-lg shadow-xl border-2 border-gray-200 z-50">
                    <div class="py-3">
                      {#each section.links as link}
                        <a
                          href={link.href}
                          on:click={closeDropdownOnNavigate}
                          class="flex items-center px-5 py-4 text-lg font-medium text-gray-800 hover:bg-gray-100 min-h-[56px] transition-colors duration-200 {
                            link.disabled ? 'opacity-50 cursor-not-allowed' : ''
                          } {
                            isActive(link.href) ? 'bg-' + section.color + '-100 text-' + section.color + '-800 border-l-4 border-' + section.color + '-500' : ''
                          }"
                          class:pointer-events-none={link.disabled}
                        >
                          {link.label}
                        </a>
                      {/each}

                      <!-- User links si n'hi ha -->
                      {#if $user && section.userLinks && section.userLinks.length > 0}
                        <hr class="my-3 border-gray-300">
                        <div class="px-3 py-2">
                          <span class="text-sm font-semibold text-gray-500 uppercase tracking-wider">Les Meves Accions</span>
                        </div>
                        {#each section.userLinks as link}
                          <a
                            href={link.href}
                            on:click={closeDropdownOnNavigate}
                            class="flex items-center px-5 py-4 text-lg font-medium text-gray-800 hover:bg-gray-100 min-h-[56px] transition-colors duration-200 {
                              isActive(link.href) ? 'bg-' + section.color + '-100 text-' + section.color + '-800 border-l-4 border-' + section.color + '-500' : ''
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

      <!-- Menú d'usuari (Dreta) - Only show on very large screens -->
      <div class="hidden portrait:xl:hidden landscape:2xl:hidden 2xl:flex 2xl:ml-6 2xl:items-center 2xl:gap-4">
        {#if $user}
          <!-- View Mode Switch (only for admins - simplified) -->
          {#if $isAdmin}
            <button
              on:click={() => viewMode.toggleMode()}
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 {
                $viewMode === 'admin' ? 'bg-blue-600' : 'bg-green-600'
              }"
              title={$viewMode === 'admin' ? 'Vista Admin - Clic per canviar a vista Jugador' : 'Vista Jugador - Clic per canviar a vista Admin'}
            >
              <span class="sr-only">Toggle view mode</span>
              <span
                class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform {
                  $viewMode === 'admin' ? 'translate-x-6' : 'translate-x-1'
                }"
              ></span>
            </button>
          {/if}

          <span class="text-lg text-gray-700">{$user.email}</span>
          <button
            on:click={signOut}
            class="bg-gray-800 text-white px-5 py-4 rounded-md text-lg font-medium hover:bg-gray-700 min-h-[56px] flex items-center"
          >
            Sortir
          </button>
        {:else}
          <a
            href="/general/login"
            class="bg-blue-600 text-white px-5 py-4 rounded-md text-lg font-medium hover:bg-blue-700 min-h-[56px] flex items-center"
          >
            Iniciar Sessió
          </a>
        {/if}
      </div>

      <!-- Page title or breadcrumb when sidebar is visible -->
      <div class="hidden landscape:flex portrait:lg:flex landscape:2xl:hidden portrait:xl:hidden flex-1 items-center justify-center">
        <h1 class="text-lg font-semibold text-gray-900">Secció de Billar - Foment Martinenc</h1>
      </div>

      <!-- Menú mòbil button - Only show on portrait mobile (when sidebar is hidden) -->
      <div class="flex items-center landscape:hidden portrait:lg:hidden ml-2">
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
      <!-- Layout vertical (portrait) - Accordion tradicional -->
      <div class="portrait:xl:hidden landscape:2xl:hidden portrait:block landscape:hidden max-h-[calc(100vh-5.5rem)] overflow-y-auto">
        <div class="pt-2 pb-3">
          {#each Object.entries(navegacio) as [key, section]}
            {#if !section.adminOnly || $isAdmin}
              <div class="border-b border-gray-200">
                <button
                  on:click={() => toggleMobileSection(key)}
                  class="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-gray-50 transition-colors"
                >
                  <div class="flex items-center space-x-2">
                    <span class="text-xl">{section.icon}</span>
                    <span class="font-semibold text-gray-900">{section.label}</span>
                  </div>
                  <svg
                    class="h-5 w-5 text-gray-500 transition-transform duration-200 {
                      mobileExpandedSection === key ? 'rotate-180' : ''
                    }"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>

                {#if mobileExpandedSection === key}
                  <div class="bg-gray-50">
                    {#each section.links as link}
                      <a
                        href={link.href}
                        on:click={closeMobileMenuOnNavigate}
                        class="mobile-nav-item block pl-8 pr-4 py-3 text-base font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-100 transition-colors {
                          link.disabled ? 'opacity-50 cursor-not-allowed' : ''
                        } {
                          isActive(link.href) ? 'bg-' + section.color + '-100 text-' + section.color + '-800 border-l-4 border-' + section.color + '-500' : ''
                        }"
                        class:pointer-events-none={link.disabled}
                      >
                        {link.label}
                      </a>
                    {/each}

                    {#if $user && section.userLinks && section.userLinks.length > 0}
                      <div class="border-t border-gray-200 mt-2 pt-2">
                        <div class="px-8 py-2">
                          <span class="text-xs font-semibold text-gray-500 uppercase">Les Meves Accions</span>
                        </div>
                        {#each section.userLinks as link}
                          <a
                            href={link.href}
                            on:click={closeMobileMenuOnNavigate}
                            class="mobile-nav-item block pl-8 pr-4 py-3 text-base font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-100 transition-colors {
                              isActive(link.href) ? 'bg-' + section.color + '-100 text-' + section.color + '-800 border-l-4 border-' + section.color + '-500' : ''
                            }"
                          >
                            {link.label}
                          </a>
                        {/each}
                      </div>
                    {/if}
                  </div>
                {/if}
              </div>
            {/if}
          {/each}
        </div>
      </div>

      <!-- Layout horitzontal (landscape) - Dues columnes -->
      <div class="portrait:xl:hidden landscape:2xl:hidden portrait:hidden landscape:block">
        <div class="flex h-[calc(100vh-3.5rem)] relative">
          <!-- Columna esquerra: Icones de seccions -->
          <div class="w-20 bg-gray-100 border-r border-gray-300 overflow-y-auto flex flex-col">
            <!-- Seccions de navegació -->
            <div class="flex-1 overflow-y-auto">
              {#each Object.entries(navegacio) as [key, section]}
                {#if !section.adminOnly || $isAdmin}
                  <button
                    on:click={() => toggleMobileSection(key)}
                    class="w-full flex flex-col items-center justify-center py-3 px-2 hover:bg-gray-200 transition-colors border-b border-gray-300 {
                      mobileExpandedSection === key ? 'bg-' + section.color + '-100 border-l-4 border-' + section.color + '-500' : ''
                    }"
                    title={section.label}
                  >
                    <span class="text-2xl mb-1">{section.icon}</span>
                    <span class="text-[10px] font-medium text-gray-700 text-center leading-tight">{section.label}</span>
                  </button>
                {/if}
              {/each}
            </div>
            
            <!-- User menu (fixat a baix) -->
            <div class="flex-shrink-0 border-t-2 border-gray-400 bg-gray-100">
              {#if $user}
                <button
                  on:click={() => toggleMobileSection('user')}
                  class="w-full flex flex-col items-center justify-center py-3 px-2 hover:bg-gray-200 transition-colors {
                    mobileExpandedSection === 'user' ? 'bg-blue-100 border-l-4 border-blue-500' : ''
                  }"
                  title="Compte d'usuari"
                >
                  <span class="text-2xl mb-1">👤</span>
                  <span class="text-[10px] font-medium text-gray-700 text-center leading-tight truncate w-full px-1">
                    {$user.email?.split('@')[0] || 'Usuari'}
                  </span>
                </button>
              {:else}
                <a
                  href="/general/login"
                  on:click={closeMobileMenuOnNavigate}
                  class="w-full flex flex-col items-center justify-center py-3 px-2 hover:bg-blue-100 transition-colors"
                  title="Iniciar sessió"
                >
                  <span class="text-2xl mb-1">🔐</span>
                  <span class="text-[10px] font-medium text-blue-600 text-center leading-tight">Login</span>
                </a>
              {/if}
            </div>
          </div>

          <!-- Columna dreta: Contingut de la secció seleccionada -->
          <div class="flex-1 bg-white overflow-y-auto">
            {#if mobileExpandedSection}
              {@const section = navegacio[mobileExpandedSection]}
              <div class="p-3">
                <h3 class="text-sm font-bold text-gray-900 mb-2 pb-2 border-b border-gray-200">
                  {section.icon} {section.label}
                </h3>
                <div class="space-y-1">
                  {#each section.links as link}
                    <a
                      href={link.href}
                      on:click={closeMobileMenuOnNavigate}
                      class="block px-3 py-2 rounded text-sm font-medium text-gray-700 hover:bg-gray-100 transition-colors {
                        link.disabled ? 'opacity-50 cursor-not-allowed' : ''
                      } {
                        isActive(link.href) ? 'bg-' + section.color + '-100 text-' + section.color + '-800' : ''
                      }"
                      class:pointer-events-none={link.disabled}
                    >
                      {link.label}
                    </a>
                  {/each}

                  {#if $user && section.userLinks && section.userLinks.length > 0}
                    <div class="border-t border-gray-200 mt-2 pt-2">
                      <div class="px-3 py-1">
                        <span class="text-[10px] font-semibold text-gray-500 uppercase">Les Meves Accions</span>
                      </div>
                      {#each section.userLinks as link}
                        <a
                          href={link.href}
                          on:click={closeMobileMenuOnNavigate}
                          class="block px-3 py-2 rounded text-sm font-medium text-gray-700 hover:bg-gray-100 transition-colors {
                            isActive(link.href) ? 'bg-' + section.color + '-100 text-' + section.color + '-800' : ''
                          }"
                        >
                          {link.label}
                        </a>
                      {/each}
                    </div>
                  {/if}
                </div>
              </div>
            {:else}
              <div class="flex items-center justify-center h-full text-gray-400 text-sm">
                Selecciona una secció
              </div>
            {/if}
          </div>
        </div>
          <!-- Popup del menú d'usuari (només si està obert) -->
          {#if mobileExpandedSection === 'user' && $user}
            <div class="absolute bottom-0 left-20 w-64 bg-white border border-gray-300 shadow-lg z-50">
              <div class="p-3">
                <div class="text-xs font-medium text-gray-600 mb-1">Sessió iniciada com:</div>
                <div class="text-sm font-semibold text-gray-900 truncate mb-3">{$user.email}</div>

                {#if $isAdmin}
                  <div class="flex items-center justify-between mb-3 pb-3 border-b border-gray-200">
                    <span class="text-xs font-medium text-gray-700">Vista {$viewMode === 'admin' ? 'Admin' : 'Jugador'}</span>
                    <button
                      on:click={() => viewMode.toggleMode()}
                      class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors {
                        $viewMode === 'admin' ? 'bg-blue-600' : 'bg-green-600'
                      }"
                    >
                      <span class="sr-only">Toggle view mode</span>
                      <span
                        class="inline-block h-3 w-3 transform rounded-full bg-white transition-transform {
                          $viewMode === 'admin' ? 'translate-x-5' : 'translate-x-1'
                        }"
                      ></span>
                    </button>
                  </div>
                {/if}

                <button
                  on:click={() => { signOut(); closeMobileMenuOnNavigate(); }}
                  class="w-full px-3 py-2 text-sm font-medium text-red-600 hover:text-red-800 hover:bg-red-50 rounded transition-colors"
                >
                  Sortir
                </button>
              </div>
            </div>
          {/if}
      </div>
    {/if}

    <!-- User menu mòbil (portrait - a baix del tot) -->
    {#if mobileMenuOpen}
      <div class="portrait:block landscape:hidden pt-3 pb-3 border-t-2 border-gray-300 bg-gray-50">
        {#if $user}
          <div class="px-4 py-2">
            <div class="text-sm font-medium text-gray-600">Sessió iniciada com:</div>
            <div class="text-base font-semibold text-gray-900 truncate">{$user.email}</div>
          </div>
          {#if $isAdmin}
            <div class="px-4 py-2 flex items-center justify-between">
              <span class="text-sm font-medium text-gray-700">Vista {$viewMode === 'admin' ? 'Admin' : 'Jugador'}</span>
              <button
                on:click={() => viewMode.toggleMode()}
                class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors {
                  $viewMode === 'admin' ? 'bg-blue-600' : 'bg-green-600'
                }"
              >
                <span class="sr-only">Toggle view mode</span>
                <span
                  class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform {
                    $viewMode === 'admin' ? 'translate-x-6' : 'translate-x-1'
                  }"
                ></span>
              </button>
            </div>
          {/if}
          <div class="px-2 mt-2">
            <button
              on:click={() => { signOut(); closeMobileMenuOnNavigate(); }}
              class="mobile-nav-item block w-full text-left px-4 py-3 text-base font-medium text-red-600 hover:text-red-800 hover:bg-red-50 rounded transition-colors"
            >
              Sortir
            </button>
          </div>
        {:else}
          <div class="px-2">
            <a
              href="/general/login"
              on:click={closeMobileMenuOnNavigate}
              class="mobile-nav-item block px-4 py-3 text-base font-medium text-white bg-blue-600 hover:bg-blue-700 rounded text-center transition-colors"
            >
              Iniciar Sessió
            </a>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</nav>