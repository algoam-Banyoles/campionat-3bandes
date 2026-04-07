import { test, expect, type Page, type ConsoleMessage } from '@playwright/test';

/**
 * Smoke E2E sobre les rutes públiques (sense auth). Per cada ruta:
 *   1. Resposta HTTP OK i càrrega < 5s.
 *   2. No errors de consola severs (filtrats: warnings, info, recursos 401/403
 *      esperats per usuaris anònims).
 *   3. El `<body>` renderitza i no es mostra cap missatge global d'error.
 */

const PUBLIC_ROUTES: { path: string; label: string }[] = [
  { path: '/', label: 'Home' },
  { path: '/general/calendari', label: 'Calendari general' },
  { path: '/campionats-socials', label: 'Campionats socials' },
  { path: '/campionat-continu/ranking', label: 'Rànquing continu' },
  { path: '/handicap', label: 'Hàndicap dashboard' }
];

/**
 * Errors esperats per a usuaris anònims (RLS bloqueja certes lectures). No
 * els considerem fallades.
 */
const IGNORED_ERROR_PATTERNS = [
  /401/,
  /403/,
  /permission denied/i,
  /insufficient_privilege/i,
  /Per veure les partides/i,
  // Service worker / manifest sovint xerren a localhost preview
  /service[- ]?worker/i,
  /manifest/i
];

function attachConsoleCollector(page: Page): { errors: string[] } {
  const errors: string[] = [];
  page.on('console', (msg: ConsoleMessage) => {
    if (msg.type() !== 'error') return;
    const text = msg.text();
    if (IGNORED_ERROR_PATTERNS.some((re) => re.test(text))) return;
    errors.push(text);
  });
  page.on('pageerror', (err) => {
    const text = err.message;
    if (IGNORED_ERROR_PATTERNS.some((re) => re.test(text))) return;
    errors.push(`pageerror: ${text}`);
  });
  return { errors };
}

for (const route of PUBLIC_ROUTES) {
  test(`${route.label} (${route.path}) carrega sense errors`, async ({ page }) => {
    const collector = attachConsoleCollector(page);

    const start = Date.now();
    const response = await page.goto(route.path, { waitUntil: 'domcontentloaded' });
    const elapsed = Date.now() - start;

    expect(response, `cap resposta de ${route.path}`).not.toBeNull();
    expect(response!.ok(), `${route.path} → ${response!.status()}`).toBeTruthy();
    expect(elapsed, `${route.path} ha trigat ${elapsed} ms`).toBeLessThan(5000);

    // Esperem que el client hidrati: <main id="main-content"> sempre present
    // al layout principal. No comprovem visibilitat perquè els media queries
    // portrait/landscape generen estats no estables en headless.
    await page.waitForSelector('h1, h2, main, [role="main"]', {
      state: 'attached',
      timeout: 8000
    });

    // Donem 800ms perquè el client acabi d'hidratar i emeti errors si n'hi ha
    await page.waitForTimeout(800);

    expect(
      collector.errors,
      `errors de consola a ${route.path}:\n${collector.errors.join('\n')}`
    ).toEqual([]);
  });
}
