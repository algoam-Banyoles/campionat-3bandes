// Smoke test read-only de /admin/partides (sense credencials: verifica
// que la ruta compila/carrega i que el guard redirigeix els anònims).
import { chromium } from '@playwright/test';

const BASE = process.env.BASE_URL ?? 'http://localhost:5173';

const browser = await chromium.launch();
const page = await browser.newPage();

const pageErrors = [];
page.on('pageerror', (err) => pageErrors.push(String(err)));

await page.goto(`${BASE}/admin/partides`, { waitUntil: 'networkidle', timeout: 60000 });
await page.waitForTimeout(3000);

console.log('FINAL URL:', page.url());
const title = await page.locator('h1').first().textContent().catch(() => null);
console.log('H1:', JSON.stringify(title));
console.log('PAGE ERRORS:', JSON.stringify(pageErrors, null, 2));

await browser.close();
