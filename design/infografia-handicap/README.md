# Infografia — Campionats Socials Hàndicap

Infografia institucional per a la secció de billar 3 bandes del Foment Martinenc.
Un únic `index.html` amb dues versions:

- **A4 vertical** — per imprimir / PDF (`index.html?format=a4`)
- **WhatsApp 1080×1920** — per compartir com a imatge (`index.html?format=whatsapp`)

Els botons flotants superiors permeten canviar entre les dues versions.
No es veuen en impressió ni en les captures.

## Fitxers

| Fitxer | Què és |
| --- | --- |
| `index.html` | Infografia (HTML + CSS, sense dependències externes) |
| `logo.png` | Logo del Foment Martinenc, usat a la capçalera |
| `capture.cjs` | Script Playwright que genera els PNG i el PDF |
| `README.md` | Aquest fitxer |

## Veure-la al navegador

Obre directament `index.html` amb el navegador (doble clic).
O des d'un terminal:

```powershell
# Windows
start "" "index.html"
```

```bash
# macOS / Linux
open index.html        # macOS
xdg-open index.html    # Linux
```

Per veure cada versió:

- `index.html?format=a4`
- `index.html?format=whatsapp`

## Generar les captures (PNG + PDF)

Requereix Node.js i Playwright.

### Instal·lació (una sola vegada)

Des d'aquesta carpeta (`design/infografia-handicap/`):

```powershell
npm init -y
npm install -D playwright
npx playwright install chromium
```

### Generar les captures

```powershell
node capture.cjs
```

> Nota: el fitxer porta extensió `.cjs` perquè el `package.json` del projecte té
> `"type": "module"`. Així s'evita carregar-lo com a ESM.

Sortides (mateixa carpeta):

- `infografia_A4.png` — captura del DIV A4 (alta resolució, x2)
- `infografia_WhatsApp.png` — exactament 1080 × 1920 px
- `infografia_A4.pdf` — PDF d'una sola pàgina A4 vertical, sense marges

## Imprimir manualment des del navegador

1. Obre `index.html?format=a4`.
2. Fes servir la funció **Imprimir** del navegador (Ctrl+P).
3. Marges: **cap** o **per defecte**, segons el navegador.
4. Activa **gràfics de fons** (Chrome: "More settings → Background graphics").
5. Mida: **A4**, orientació **vertical**.

> Els botons "A4" i "WhatsApp" ja no apareixen en imprimir.

## Notes de disseny

- Paleta institucional: blau marí `#102C46`, blau viu `#0B97D1`, groc `#F7C948`, verd `#1F7A55`.
- Tipografia: Arial / Helvetica (alta llegibilitat per a públic adult i gent gran).
- Tot el contingut cap en **una sola pàgina A4**.
- La versió WhatsApp redistribueix els mateixos blocs amb textos més grans.
- No s'usa el terme "gol d'or" — sempre **"CARAMBOLA D'OR"**.

## Resolució de problemes

- **El logo no surt**: comprova que `logo.png` és a la mateixa carpeta que `index.html`.
- **Els colors no s'imprimeixen**: activa "Imprimir gràfics de fons" al diàleg d'impressió.
- **El PDF surt en blanc o tallat**: assegura't que `capture.js` ha usat `preferCSSPageSize: true` (ja és el cas).
- **Playwright no troba el navegador**: torna a executar `npx playwright install chromium`.
