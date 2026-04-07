import { test, expect } from '@playwright/test';

/**
 * Verifica que la pàgina de login renderitza el formulari bàsic. NO fa login
 * real (caldria seed/credencials de test). Cobreix la regressió de "la pàgina
 * de login es queda en blanc" o "el formulari no apareix".
 */
test('login page renderitza formulari', async ({ page }) => {
  const response = await page.goto('/general/login', { waitUntil: 'domcontentloaded' });
  expect(response?.ok()).toBeTruthy();

  // Hauria d'haver-hi un input d'email i un de password
  const emailInput = page.locator('input[type="email"], input[name="email"]').first();
  const passwordInput = page.locator('input[type="password"]').first();

  // Els inputs existeixen al DOM (no comprovem visibilitat per les mateixes
  // raons que als altres specs E2E: layout portrait/landscape inestable).
  await expect(emailInput).toHaveCount(1, { timeout: 5000 });
  await expect(passwordInput).toHaveCount(1, { timeout: 5000 });
});
