import { afterNavigate } from '$app/navigation';

export function setupFocusManagement() {
  afterNavigate(({ to }) => {
    // Find the main heading or main content area
    const mainHeading = document.querySelector('h1');
    const mainContent = document.querySelector('#main-content') || document.querySelector('main');

    if (mainHeading) {
      // Make heading focusable temporarily
      mainHeading.setAttribute('tabindex', '-1');
      mainHeading.focus();

      // Remove tabindex after focus
      setTimeout(() => {
        mainHeading.removeAttribute('tabindex');
      }, 100);
    } else if (mainContent) {
      (mainContent as HTMLElement).setAttribute('tabindex', '-1');
      (mainContent as HTMLElement).focus();

      setTimeout(() => {
        (mainContent as HTMLElement).removeAttribute('tabindex');
      }, 100);
    }

    // Announce page change to screen readers
    announcePageChange(to?.url?.pathname);
  });
}

function announcePageChange(pathname: string | undefined) {
  if (!pathname) return;

  const announcement = document.createElement('div');
  announcement.setAttribute('aria-live', 'polite');
  announcement.setAttribute('aria-atomic', 'true');
  announcement.className = 'sr-only';
  announcement.textContent = `Navegat a ${getPageTitle(pathname)}`;

  document.body.appendChild(announcement);

  setTimeout(() => {
    document.body.removeChild(announcement);
  }, 1000);
}

function getPageTitle(pathname: string): string {
  const titles: Record<string, string> = {
    '/': 'Pàgina d\'inici',
    '/campionat-continu/ranking': 'Classificació del campionat continu',
    '/campionat-continu/reptes': 'Reptes del campionat continu',
    '/campionat-continu/llista-espera': 'Llista d\'espera',
    '/campionat-continu/historial': 'Historial de partides',
    '/campionat-continu/reptes/me': 'Els meus reptes',
    '/campionat-continu/reptes/nou': 'Crear nou repte',
    '/campionats-socials': 'Campionats socials',
    '/campionats-socials/inscripcions': 'Inscripcions als campionats socials',
    '/campionats-socials/cerca-jugadors': 'Cerca de jugadors',
    '/general/calendari': 'Calendari general',
    '/general/multimedia': 'Multimedia',
    '/general/login': 'Iniciar sessió',
    '/admin': 'Administració',
    '/admin/events': 'Gestió d\'events',
    '/admin/categories': 'Gestió de categories'
  };

  // Check exact match first
  if (titles[pathname]) {
    return titles[pathname];
  }

  // Check partial matches for dynamic routes
  for (const [route, title] of Object.entries(titles)) {
    if (pathname.startsWith(route) && route !== '/') {
      return title;
    }
  }

  return 'Pàgina';
}