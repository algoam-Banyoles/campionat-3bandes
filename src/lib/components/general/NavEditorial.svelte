<script lang="ts">
  import { page } from '$app/stores';
  import { user } from '$lib/stores/auth';
  import { isAdmin } from '$lib/stores/adminAuth';
  import { signOut } from '$lib/utils/auth-client';
  import { viewMode } from '$lib/stores/viewMode';

  type NavLink = { href: string; label: string; disabled?: boolean };
  type NavSection = {
    label: string;
    num: string;
    sectionToken: string; // mapeja a --sec-{X} a design-tokens.css
    links: NavLink[];
    userLinks?: NavLink[];
    adminLinks?: NavLink[];
    adminOnly?: boolean;
  };

  // Mateixa estructura que Nav.svelte (no es perd cap link).
  const navegacio: Record<string, NavSection> = {
    general: {
      label: 'Inici',
      num: '01',
      sectionToken: 'general',
      links: [
        { href: '/', label: 'Pàgina principal' },
        { href: '/general/calendari', label: 'Calendari general' },
        { href: '/general/multimedia', label: 'Multimèdia' }
      ]
    },
    socials: {
      label: 'Socials',
      num: '02',
      sectionToken: 'social',
      links: [
        { href: '/campionats-socials?view=active', label: 'Campionats actius' },
        { href: '/campionats-socials?view=history', label: 'Historial de campionats' },
        { href: '/campionats-socials/mitjanes-historiques', label: 'Mitjanes per temporada' },
        { href: '/campionats-socials/mitjanes-comparatives', label: 'Comparativa de mitjanes' },
        { href: '/campionats-socials/cerca-jugadors', label: 'Buscar jugadors' },
        { href: '/campionats-socials/comparador', label: 'Comparador de jugadors' }
      ],
      userLinks: [
        { href: '/campionats-socials/inscripcions', label: "Inscriure's a campionats" }
      ],
      adminLinks: [
        { href: '/campionats-socials?view=active&admin=true', label: 'Preparació de campionats' },
        { href: '/campionats-socials/gestio-inscripcions', label: 'Gestió d\'inscripcions' },
        { href: '/campionats-socials/resultats-pendents', label: 'Pujar resultats pendents' }
      ]
    },
    ranking: {
      label: 'Continu',
      num: '03',
      sectionToken: 'continu',
      links: [
        { href: '/campionat-continu/ranking', label: 'Veure classificació' },
        { href: '/campionat-continu/reptes', label: 'Tots els reptes' },
        { href: '/campionat-continu/historial', label: 'Historial de partides' },
        { href: '/campionat-continu/llista-espera', label: "Llista d'espera" }
      ],
      userLinks: [
        { href: '/campionat-continu/reptes/nou', label: 'Crear nou repte' },
        { href: '/campionat-continu/reptes/me', label: 'Els meus reptes actius' }
      ],
      adminLinks: [
        { href: '/campionat-continu/gestio-inscripcions', label: 'Gestió d\'inscripcions' },
        { href: '/campionat-continu/ranking-inicial', label: 'Crear rànquing inicial' },
        { href: '/campionat-continu/historial-canvis-ranking', label: 'Canvis de posició' }
      ]
    },
    handicap: {
      label: 'Hàndicap',
      num: '04',
      sectionToken: 'handicap',
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
      num: '05',
      sectionToken: 'admin',
      links: [
        { href: '/admin', label: 'Dashboard' },
        { href: '/admin/socis', label: 'Gestió de socis' },
        { href: '/admin/events', label: 'Events' },
        { href: '/admin/categories', label: 'Categories' },
        { href: '/admin/audit-log', label: "Registre d'auditoria" }
      ],
      adminOnly: true
    }
  };

  let activeDropdown: string | null = null;
  let mobileMenuOpen = false;

  function getCurrentSection(path: string) {
    if (path.startsWith('/admin')) return 'admin';
    if (path.startsWith('/campionats-socials')) return 'socials';
    if (path.startsWith('/campionat-continu')) return 'ranking';
    if (path.startsWith('/handicap')) return 'handicap';
    return 'general';
  }

  function isActive(href: string, currentPath: string) {
    const cleanHref = href.split('?')[0];
    if (cleanHref === '/') return currentPath === '/';
    return currentPath === cleanHref || currentPath.startsWith(cleanHref + '/');
  }

  $: currentPath = $page.url.pathname;
  $: selectedSection = getCurrentSection(currentPath);
  // Quan canvia la ruta, tanca dropdowns i menú mòbil
  $: if (currentPath) {
    activeDropdown = null;
    mobileMenuOpen = false;
  }

  // Bloqueja l'scroll del body quan el menú mòbil està obert.
  // Així el panell es manté fix sobre la pàgina i no es perd l'usuari
  // si havia fet scroll abans d'obrir el menú.
  $: if (typeof document !== 'undefined') {
    document.body.classList.toggle('nav-mobile-open', mobileMenuOpen);
  }

  function handleClickOutside(e: MouseEvent) {
    if (activeDropdown && !(e.target as Element)?.closest('[data-dropdown]')) {
      activeDropdown = null;
    }
  }

  function toggleDropdown(key: string) {
    activeDropdown = activeDropdown === key ? null : key;
  }

  function closeMobileMenu() {
    mobileMenuOpen = false;
  }
</script>

<svelte:window on:click={handleClickOutside} />

<!-- ────────── Topbar ────────── -->
<header class="topbar">
  <div class="topbar-inner">
    <a class="brand" href="/" aria-label="Inici">
      <img src="/logo.png" alt="Foment Martinenc" />
      <span class="brand-text">
        <span class="brand-name">Foment Martinenc</span>
        <span class="brand-sub">Secció Billar</span>
      </span>
    </a>

    <div class="topbar-spacer"></div>

    {#if $user}
      <div class="user-area" data-dropdown>
        <button
          class="user-pill"
          on:click|stopPropagation={() => toggleDropdown('user')}
          aria-haspopup="menu"
          aria-expanded={activeDropdown === 'user'}
        >
          <span class="user-name">{$user.email}</span>
          {#if $isAdmin}
            <span class="user-role">{$viewMode === 'admin' ? 'Admin' : 'Jugador'}</span>
          {/if}
          <svg class="caret" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M6 9l6 6 6-6" />
          </svg>
        </button>

        {#if activeDropdown === 'user'}
          <div class="dropdown user-dropdown" role="menu">
            <div class="user-dropdown-head">
              <div class="user-dropdown-email">{$user.email}</div>
            </div>
            {#if $isAdmin}
              <button class="dropdown-item" on:click={() => viewMode.toggleMode()}>
                Canviar a vista <strong>{$viewMode === 'admin' ? 'Jugador' : 'Admin'}</strong>
              </button>
            {/if}
            <button class="dropdown-item dropdown-item-danger" on:click={() => signOut()}>
              Sortir
            </button>
          </div>
        {/if}
      </div>
    {:else}
      <a href="/general/login" class="login-link">Iniciar sessió</a>
    {/if}

    <button
      class="hamburger"
      class:open={mobileMenuOpen}
      on:click|stopPropagation={() => (mobileMenuOpen = !mobileMenuOpen)}
      aria-label={mobileMenuOpen ? 'Tancar menú' : 'Obrir menú'}
      aria-expanded={mobileMenuOpen}
    >
      <span class="hamburger-bar"></span>
      <span class="hamburger-bar"></span>
      <span class="hamburger-bar"></span>
    </button>
  </div>
</header>

<!-- ────────── Section nav (desktop / tablet) ────────── -->
<nav class="sections" aria-label="Navegació de seccions">
  <div class="sections-inner">
    {#each Object.entries(navegacio) as [key, section]}
      {#if !section.adminOnly || $isAdmin}
        <div class="section-item" data-dropdown>
          <a
            href={section.links[0].href}
            class:active={selectedSection === key}
            style="--section-color: var(--sec-{section.sectionToken});"
            on:click={() => (activeDropdown = null)}
          >
            <span class="num">{section.num}</span>
            <span class="lbl">{section.label}</span>
          </a>
          {#if section.links.length > 1 || (section.userLinks && section.userLinks.length > 0 && $user) || (section.adminLinks && section.adminLinks.length > 0 && $isAdmin)}
            <button
              class="caret-btn"
              on:click|stopPropagation={() => toggleDropdown(key)}
              aria-haspopup="menu"
              aria-expanded={activeDropdown === key}
              aria-label="Subseccions de {section.label}"
            >
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>

            {#if activeDropdown === key}
              <div class="dropdown section-dropdown" role="menu">
                {#each section.links as link}
                  <a
                    href={link.href}
                    class="dropdown-item"
                    class:active={isActive(link.href, currentPath)}
                    class:disabled={link.disabled}
                    aria-disabled={link.disabled}
                    on:click={() => (activeDropdown = null)}
                  >
                    {link.label}
                  </a>
                {/each}

                {#if $user && section.userLinks && section.userLinks.length > 0}
                  <hr class="dropdown-rule" />
                  <div class="dropdown-eyebrow">Les meves accions</div>
                  {#each section.userLinks as link}
                    <a
                      href={link.href}
                      class="dropdown-item"
                      class:active={isActive(link.href, currentPath)}
                      on:click={() => (activeDropdown = null)}
                    >
                      {link.label}
                    </a>
                  {/each}
                {/if}

                {#if $isAdmin && section.adminLinks && section.adminLinks.length > 0}
                  <hr class="dropdown-rule" />
                  <div class="dropdown-eyebrow">Administració</div>
                  {#each section.adminLinks as link}
                    <a
                      href={link.href}
                      class="dropdown-item"
                      class:active={isActive(link.href, currentPath)}
                      on:click={() => (activeDropdown = null)}
                    >
                      {link.label}
                    </a>
                  {/each}
                {/if}
              </div>
            {/if}
          {/if}
        </div>
      {/if}
    {/each}
  </div>
</nav>

<!-- ────────── Panel mòbil (hamburger obert) ────────── -->
{#if mobileMenuOpen}
  <button
    type="button"
    class="mobile-backdrop"
    on:click={() => (mobileMenuOpen = false)}
    aria-label="Tancar menú"
  ></button>
  <div class="mobile-panel" role="menu">
    <!-- Sessió de l'usuari (al mòbil només es veu aquí, no al topbar) -->
    <div class="mobile-user">
      {#if $user}
        <div class="mobile-user-head">
          <div class="mobile-user-eyebrow">Sessió</div>
          <div class="mobile-user-email">{$user.email}</div>
          {#if $isAdmin}
            <div class="mobile-user-role">Vista: <strong>{$viewMode === 'admin' ? 'Admin' : 'Jugador'}</strong></div>
          {/if}
        </div>
        <div class="mobile-user-actions">
          {#if $isAdmin}
            <button class="mobile-user-btn" on:click={() => { viewMode.toggleMode(); closeMobileMenu(); }}>
              Canviar a {$viewMode === 'admin' ? 'Jugador' : 'Admin'}
            </button>
          {/if}
          <button class="mobile-user-btn mobile-user-btn-danger" on:click={() => { signOut(); closeMobileMenu(); }}>
            Sortir
          </button>
        </div>
      {:else}
        <a href="/general/login" class="mobile-user-btn mobile-user-btn-primary" on:click={closeMobileMenu}>
          Iniciar sessió
        </a>
      {/if}
    </div>

    {#each Object.entries(navegacio) as [key, section]}
      {#if !section.adminOnly || $isAdmin}
        <div class="mobile-section">
          <div class="mobile-section-head" style="--section-color: var(--sec-{section.sectionToken});">
            <span class="num">{section.num}</span>
            <span class="lbl">{section.label}</span>
          </div>
          <div class="mobile-section-links">
            {#each section.links as link}
              <a
                href={link.href}
                class="mobile-link"
                class:active={isActive(link.href, currentPath)}
                on:click={closeMobileMenu}
              >
                {link.label}
              </a>
            {/each}
            {#if $user && section.userLinks && section.userLinks.length > 0}
              <div class="mobile-eyebrow">Les meves accions</div>
              {#each section.userLinks as link}
                <a
                  href={link.href}
                  class="mobile-link"
                  class:active={isActive(link.href, currentPath)}
                  on:click={closeMobileMenu}
                >
                  {link.label}
                </a>
              {/each}
            {/if}
            {#if $isAdmin && section.adminLinks && section.adminLinks.length > 0}
              <div class="mobile-eyebrow">Administració</div>
              {#each section.adminLinks as link}
                <a
                  href={link.href}
                  class="mobile-link"
                  class:active={isActive(link.href, currentPath)}
                  on:click={closeMobileMenu}
                >
                  {link.label}
                </a>
              {/each}
            {/if}
          </div>
        </div>
      {/if}
    {/each}
  </div>
{/if}

<style>
  /* ── Topbar ──────────────────────────────────────────────── */
  .topbar {
    background: var(--paper-elevated);
    border-bottom: 1px solid var(--rule);
    position: sticky;
    top: 0;
    z-index: 50;
  }
  .topbar-inner {
    max-width: 1180px;
    margin: 0 auto;
    padding: 0.85rem 1.25rem;
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    text-decoration: none;
    color: var(--ink);
    min-height: 48px;
    min-width: 0;
    overflow: hidden;
  }
  .brand img {
    width: 40px;
    height: 40px;
    object-fit: contain;
    flex-shrink: 0;
  }
  .brand-text {
    display: flex;
    flex-direction: column;
    line-height: 1.05;
    min-width: 0;
    overflow: hidden;
  }
  .brand-name {
    font-family: var(--font-sans);
    font-weight: 800;
    font-size: 1rem;
    letter-spacing: -0.018em;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .brand-sub {
    font-family: var(--font-sans);
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin-top: 3px;
  }
  .topbar-spacer {
    flex: 1;
  }

  /* User pill / login */
  .user-area {
    position: relative;
  }
  .user-pill {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.45rem 0.85rem;
    border: 1px solid var(--rule);
    background: var(--paper-elevated);
    border-radius: 999px;
    font-family: var(--font-sans);
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--ink-2);
    cursor: pointer;
    min-height: 44px;
  }
  .user-pill:hover {
    border-color: var(--rule-strong);
    color: var(--ink);
  }
  .user-name {
    max-width: 14ch;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .user-role {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    padding: 0.15rem 0.4rem;
    background: rgba(0, 0, 0, 0.05);
    color: var(--ink);
  }

  .login-link {
    display: inline-flex;
    align-items: center;
    padding: 0.55rem 1rem;
    background: var(--ink);
    color: var(--paper);
    text-decoration: none;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    letter-spacing: -0.005em;
    min-height: 44px;
    border: 1px solid var(--ink);
  }
  .login-link:hover {
    opacity: 0.9;
  }

  /* Hamburger (visible només en mòbil) */
  .hamburger {
    display: none;
    flex-direction: column;
    justify-content: space-around;
    width: 44px;
    height: 44px;
    background: transparent;
    border: 1px solid var(--rule);
    cursor: pointer;
    padding: 0.65rem 0.5rem;
  }
  .hamburger-bar {
    display: block;
    height: 2px;
    background: var(--ink);
    transition: transform 0.18s ease, opacity 0.18s ease;
  }
  .hamburger.open .hamburger-bar:nth-child(1) {
    transform: translateY(7px) rotate(45deg);
  }
  .hamburger.open .hamburger-bar:nth-child(2) {
    opacity: 0;
  }
  .hamburger.open .hamburger-bar:nth-child(3) {
    transform: translateY(-7px) rotate(-45deg);
  }

  /* ── Section nav ──────────────────────────────────────── */
  .sections {
    background: var(--paper-elevated);
    border-bottom: 1px solid var(--rule);
    position: sticky;
    top: 4.25rem;
    z-index: 40;
  }
  .sections-inner {
    max-width: 1180px;
    margin: 0 auto;
    padding: 0 1.25rem;
    display: flex;
    gap: 0;
    /* No `overflow-x: auto` — això força `overflow-y: auto` i fa
       aparèixer scroll vertical quan s'obren els dropdowns. */
    overflow: visible;
  }
  .section-item {
    position: relative;
    display: inline-flex;
    align-items: stretch;
  }
  .section-item > a {
    position: relative;
    display: inline-flex;
    align-items: baseline;
    gap: 0.5rem;
    padding: 1rem 1.1rem;
    text-decoration: none;
    color: var(--ink-2);
    font-family: var(--font-sans);
    font-weight: 500;
    font-size: 0.95rem;
    letter-spacing: -0.005em;
    white-space: nowrap;
    min-height: 48px;
  }
  .section-item > a:hover {
    color: var(--ink);
  }
  .section-item > a.active {
    color: var(--ink);
    font-weight: 600;
  }
  .section-item > a.active::after {
    content: '';
    position: absolute;
    left: 1.1rem;
    right: 1.1rem;
    bottom: -1px;
    height: 3px;
    background: var(--section-color, var(--accent));
  }
  .section-item .num {
    font-size: 0.6875rem;
    font-weight: 500;
    color: var(--ink-3);
    font-feature-settings: 'tnum' 1;
    letter-spacing: 0.04em;
  }
  .caret-btn {
    background: transparent;
    border: none;
    padding: 0 0.6rem 0 0;
    margin-left: -0.4rem;
    color: var(--ink-3);
    cursor: pointer;
    display: inline-flex;
    align-items: center;
  }
  .caret-btn:hover {
    color: var(--ink);
  }

  /* ── Dropdowns (user i secció) ────────────────────────── */
  .dropdown {
    position: absolute;
    top: 100%;
    margin-top: 0.4rem;
    min-width: 16rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.06);
    z-index: 60;
    padding: 0.4rem 0;
  }
  .user-dropdown {
    right: 0;
  }
  .section-dropdown {
    left: 0;
  }
  .user-dropdown-head {
    padding: 0.5rem 1rem 0.65rem;
    border-bottom: 1px solid var(--rule);
    margin-bottom: 0.4rem;
  }
  .user-dropdown-email {
    font-size: 0.8125rem;
    color: var(--ink-2);
    word-break: break-all;
  }
  .dropdown-item {
    display: block;
    width: 100%;
    text-align: left;
    background: transparent;
    border: none;
    padding: 0.65rem 1rem;
    font-family: var(--font-sans);
    font-size: 0.9375rem;
    font-weight: 500;
    color: var(--ink);
    text-decoration: none;
    cursor: pointer;
    line-height: 1.3;
  }
  .dropdown-item:hover {
    background: var(--paper);
  }
  .dropdown-item.active {
    background: rgba(0, 0, 0, 0.03);
    border-left: 3px solid var(--ink);
    padding-left: calc(1rem - 3px);
    font-weight: 600;
  }
  .dropdown-item.disabled {
    opacity: 0.4;
    cursor: not-allowed;
    pointer-events: none;
  }
  .dropdown-item-danger {
    color: var(--accent);
    font-weight: 600;
  }
  .dropdown-rule {
    border: none;
    border-top: 1px solid var(--rule);
    margin: 0.4rem 0;
  }
  .dropdown-eyebrow {
    padding: 0.5rem 1rem 0.3rem;
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
  }

  /* ── Mobile panel (hamburger expandit) ────────────────── */
  /* Fixat sota el topbar perquè sigui visible independentment de
     l'scroll de la pàgina. El backdrop captura clics fora del panell.
     L'scroll del body es bloqueja via `body.nav-mobile-open`. */
  .mobile-panel {
    display: none;
    position: fixed;
    top: 4.25rem;
    left: 0;
    right: 0;
    background: var(--paper-elevated);
    border-top: 1px solid var(--rule);
    border-bottom: 1px solid var(--rule);
    padding: 0.5rem 0;
    max-height: calc(100vh - 4.25rem);
    /* Reserva fons per safe-area en iOS */
    padding-bottom: max(0.5rem, env(safe-area-inset-bottom));
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    overscroll-behavior: contain;
    z-index: 49;
    box-shadow: 0 12px 24px rgba(0, 0, 0, 0.08);
  }
  .mobile-backdrop {
    display: none;
    position: fixed;
    top: 4.25rem;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(26, 24, 20, 0.45);
    border: none;
    padding: 0;
    margin: 0;
    cursor: pointer;
    z-index: 48;
  }
  /* Modern viewport units si existeixen (millor en mòbil amb URL bar) */
  @supports (height: 100dvh) {
    .mobile-panel { max-height: calc(100dvh - 4.25rem); }
  }
  :global(body.nav-mobile-open) {
    overflow: hidden;
  }
  .mobile-section {
    border-top: 1px solid var(--rule);
    padding: 0.75rem 1.25rem 1rem;
  }
  .mobile-section:first-child {
    border-top: none;
  }
  .mobile-section-head {
    display: flex;
    align-items: baseline;
    gap: 0.6rem;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid var(--section-color, var(--ink));
    margin-bottom: 0.6rem;
  }
  .mobile-section-head .num {
    font-size: 0.6875rem;
    font-weight: 600;
    color: var(--ink-3);
    letter-spacing: 0.06em;
    font-feature-settings: 'tnum' 1;
  }
  .mobile-section-head .lbl {
    font-weight: 800;
    font-size: 1.125rem;
    letter-spacing: -0.018em;
    color: var(--ink);
  }
  .mobile-section-links {
    display: flex;
    flex-direction: column;
    gap: 0;
  }
  .mobile-link {
    padding: 0.7rem 0.4rem;
    text-decoration: none;
    color: var(--ink);
    font-family: var(--font-sans);
    font-weight: 500;
    font-size: 0.9375rem;
    border-bottom: 1px solid var(--rule);
    min-height: 48px;
    display: flex;
    align-items: center;
  }
  .mobile-link:last-child {
    border-bottom: none;
  }
  .mobile-link.active {
    font-weight: 700;
    color: var(--ink);
    background: rgba(0, 0, 0, 0.03);
    padding-left: 0.75rem;
    margin-left: -0.4rem;
    border-left: 3px solid var(--ink);
  }
  .mobile-eyebrow {
    padding: 0.65rem 0.4rem 0.3rem;
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin-top: 0.4rem;
    border-top: 1px solid var(--rule);
  }

  /* ── Mobile user block (dins el panel) ─────────────── */
  .mobile-user {
    padding: 1rem 1.25rem;
    background: var(--paper);
    border-bottom: 1px solid var(--rule);
  }
  .mobile-user-head { margin-bottom: 0.65rem; }
  .mobile-user-eyebrow {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin-bottom: 0.25rem;
  }
  .mobile-user-email {
    font-weight: 700;
    font-size: 0.9375rem;
    color: var(--ink);
    word-break: break-all;
  }
  .mobile-user-role {
    margin-top: 0.3rem;
    font-size: 0.75rem;
    color: var(--ink-2);
  }
  .mobile-user-role strong { color: var(--ink); font-weight: 700; }
  .mobile-user-actions {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }
  .mobile-user-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.55rem 0.85rem;
    background: var(--paper-elevated);
    color: var(--ink);
    border: 1px solid var(--rule-strong);
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    text-decoration: none;
    min-height: 44px;
  }
  .mobile-user-btn:hover { border-color: var(--ink); }
  .mobile-user-btn-danger {
    color: var(--accent);
    border-color: var(--accent);
  }
  .mobile-user-btn-primary {
    background: var(--ink);
    color: var(--paper);
    border-color: var(--ink);
  }

  /* ── Responsiu ─────────────────────────────────────────── */
  @media (max-width: 767px) {
    .brand-name {
      font-size: 0.9375rem;
    }
    .brand-sub {
      display: none;
    }
    /* Al mòbil, l'usuari/login es mou al panel del hamburger
       per evitar superposicions amb el brand i el botó */
    .user-area, .login-link {
      display: none;
    }
    .hamburger {
      display: flex;
    }
    .sections {
      display: none;
    }
    .mobile-panel {
      display: block;
    }
    .mobile-backdrop {
      display: block;
    }
    .topbar-inner {
      padding: 0.7rem 1rem;
    }
  }

  /* High-contrast mode compat */
  :global(.high-contrast) .topbar,
  :global(.high-contrast) .sections,
  :global(.high-contrast) .mobile-panel,
  :global(.high-contrast) .dropdown {
    background: #ffffff !important;
    border-color: #000000 !important;
  }
  :global(.high-contrast) .section-item > a.active::after {
    background: #000000 !important;
  }
</style>
