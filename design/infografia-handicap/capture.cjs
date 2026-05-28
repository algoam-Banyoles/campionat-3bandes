/**
 * capture.js — Genera captures de les dues versions de la infografia.
 *
 * Sortides:
 *   - infografia_A4.png        (captura pantalla del DIV .page.a4)
 *   - infografia_WhatsApp.png  (captura 1080 x 1920 del DIV .page.wa)
 *   - infografia_A4.pdf        (PDF d'una sola pàgina A4 vertical)
 *
 * Requisits:
 *   npm install -D playwright
 *   npx playwright install chromium
 *
 * Execució (des d'aquesta carpeta):
 *   node capture.js
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const HERE = __dirname;
const FILE_URL = 'file:///' + path.resolve(HERE, 'index.html').replace(/\\/g, '/');

async function withPage(browser, url, viewport) {
  const ctx = await browser.newContext({
    viewport,
    deviceScaleFactor: 2,
  });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'networkidle' });
  // Esperar que el logo i les fonts estiguin carregats
  await page.evaluate(async () => {
    if (document.fonts && document.fonts.ready) {
      await document.fonts.ready;
    }
    const imgs = Array.from(document.images);
    await Promise.all(imgs.map(img =>
      img.complete ? Promise.resolve() : new Promise(res => {
        img.onload = img.onerror = res;
      })
    ));
  });
  await page.waitForTimeout(250);
  return { ctx, page };
}

async function captureA4PNG(browser) {
  const out = path.join(HERE, 'infografia_A4.png');
  // 210mm x 297mm a 96dpi ≈ 794 x 1123 px
  const { ctx, page } = await withPage(browser, FILE_URL + '?format=a4', { width: 900, height: 1300 });
  // Amagar els botons abans de capturar
  await page.addStyleTag({ content: '.switcher { display: none !important; } body { background: #fff !important; padding: 0 !important; }' });
  const el = await page.locator('#page');
  await el.screenshot({ path: out });
  await ctx.close();
  console.log(' OK  ', path.basename(out));
}

async function captureWhatsApp(browser) {
  const out = path.join(HERE, 'infografia_WhatsApp.png');
  const { ctx, page } = await withPage(browser, FILE_URL + '?format=whatsapp', { width: 1200, height: 2000 });
  await page.addStyleTag({ content: '.switcher { display: none !important; } body { background: #fff !important; padding: 0 !important; }' });
  const el = await page.locator('#page');
  await el.screenshot({ path: out, omitBackground: false });
  // Forçar a exactes 1080 x 1920? La captura del locator ja té la mida del DIV
  // (1080 x 1920) escalada per deviceScaleFactor=2 → 2160 x 3840. Si vols
  // exactament 1080 x 1920 px, comenta deviceScaleFactor a withPage.
  await ctx.close();
  console.log(' OK  ', path.basename(out));
}

async function captureWhatsAppExact1080(browser) {
  // Variant: PNG exacte de 1080 x 1920 px (sense retina scale)
  const out = path.join(HERE, 'infografia_WhatsApp.png');
  const ctx = await browser.newContext({
    viewport: { width: 1080, height: 1920 },
    deviceScaleFactor: 1,
  });
  const page = await ctx.newPage();
  await page.goto(FILE_URL + '?format=whatsapp', { waitUntil: 'networkidle' });
  await page.evaluate(async () => {
    if (document.fonts && document.fonts.ready) await document.fonts.ready;
    const imgs = Array.from(document.images);
    await Promise.all(imgs.map(img =>
      img.complete ? Promise.resolve() : new Promise(res => { img.onload = img.onerror = res; })
    ));
  });
  await page.addStyleTag({ content: '.switcher { display: none !important; } body { background: #fff !important; padding: 0 !important; margin: 0 !important; } .page.wa { box-shadow: none !important; }' });
  await page.waitForTimeout(250);
  // Captura tot el viewport (1080 x 1920)
  await page.screenshot({ path: out, fullPage: false, clip: { x: 0, y: 0, width: 1080, height: 1920 } });
  await ctx.close();
  console.log(' OK  ', path.basename(out), '(1080x1920)');
}

async function captureA4PDF(browser) {
  const out = path.join(HERE, 'infografia_A4.pdf');
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await page.goto(FILE_URL + '?format=a4', { waitUntil: 'networkidle' });
  await page.emulateMedia({ media: 'print' });
  await page.evaluate(async () => {
    if (document.fonts && document.fonts.ready) await document.fonts.ready;
    const imgs = Array.from(document.images);
    await Promise.all(imgs.map(img =>
      img.complete ? Promise.resolve() : new Promise(res => { img.onload = img.onerror = res; })
    ));
  });
  await page.pdf({
    path: out,
    format: 'A4',
    printBackground: true,
    margin: { top: '0', right: '0', bottom: '0', left: '0' },
    preferCSSPageSize: true,
  });
  await ctx.close();
  console.log(' OK  ', path.basename(out));
}

(async () => {
  if (!fs.existsSync(path.join(HERE, 'index.html'))) {
    console.error('No es troba index.html a', HERE);
    process.exit(1);
  }
  if (!fs.existsSync(path.join(HERE, 'logo.png'))) {
    console.warn('  AVÍS: logo.png no trobat — la captura sortirà sense logo.');
  }

  const browser = await chromium.launch();
  try {
    await captureA4PNG(browser);
    await captureWhatsAppExact1080(browser);
    await captureA4PDF(browser);
  } finally {
    await browser.close();
  }
  console.log('\nFet.');
})().catch(err => {
  console.error(err);
  process.exit(1);
});
