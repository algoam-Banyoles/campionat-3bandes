import { test, expect } from '@playwright/test';

test('home loads in under 5s', async ({ page }) => {
  const start = Date.now();
  const response = await page.goto('/', { waitUntil: 'domcontentloaded' });
  const elapsed = Date.now() - start;

  expect(response?.ok()).toBeTruthy();
  expect(elapsed).toBeLessThan(5000);
  // El document ha de tenir contingut: el <h1> de Nav existeix al DOM
  // (encara que l'orientació o el tema CSS el deixi visualment ocult al
  // viewport de test). No comprovem visibilitat perquè el layout té
  // diverses branques portrait/landscape que en headless tornen estats
  // no estables.
  await expect(page.locator('h1, h2').first()).toHaveCount(1, { timeout: 5000 });
});
