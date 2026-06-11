# CLAUDE.md — Projecte Campionat 3 Bandes

PWA de gestió de la secció de billar 3 bandes del Foment Martinenc.

## Stack

- **Frontend**: SvelteKit + TypeScript + TailwindCSS
- **Backend**: Supabase (PostgreSQL + Auth + RLS)
- **Gràfics**: ECharts
- **Error tracking**: Sentry
- **Deploy**: Vercel (`campionat-3bandes.vercel.app`) — `svelte.config.js` usa `adapter-vercel` quan `VERCEL=1` i adaptador estàtic altrament. Els `+server.ts` NOMÉS funcionen al deploy de Vercel.
- **PWA**: Service Worker propi a `static/sw.js`, registrat des d'`app.html` (NO vite-pwa, NO `src/service-worker.js`)
- **Secrets de servidor**: `CRON_SECRET` (capçalera `x-cron-secret` del endpoint `check-expired`; l'envia l'edge function `aplica-penalitzacions`). Cal definir-lo a Vercel i als secrets de Supabase Functions.

## Estructura de mòduls (`src/routes/`)

```
/                          → Pàgina principal
/general/
  calendari                → Calendari general d'activitats
  multimedia               → Galeria de vídeos/fotos
  login                    → Autenticació Supabase
  reset-password           → Recuperació contrasenya
  logout

/campionats-socials/       → Lligues per categories
  +page.svelte             → Vista única amb views (active/history/preparation/...)
  [eventId]/               → Detall d'un campionat
    classificacio/         → Classificació + modal "veure resultats per jugador"
  inscripcions/            → Inscripció de socis
  cerca-jugadors/
  comparador/              → Comparador de jugadors
  mitjanes-historiques/    → Mitjanes per temporada (admin pot editar inline)
  mitjanes-comparatives/   → Comparativa entre dues últimes temporades disponibles
  resultats-pendents/      → (admin) Pujar resultats pendents + incompareixences
  gestio-inscripcions/     → (admin) Gestió completa d'inscripcions socials

/campionat-continu/        → Rànquing permanent (reptes directes)
  ranking/                 → Classificació (20 posicions)
  reptes/                  → Tots els reptes
    nou/                   → Crear repte
    me/                    → Els meus reptes actius
    [id]/resultat/
  historial/               → Partides jugades
  llista-espera/           → Jugadors en llista d'espera (públic)
  inscripcio/              → Alta al campionat continu
  classificacio/[id]/      → Classificació d'una temporada
  configuracio/notificacions/
  ranking-inicial/         → (admin) Wizard de rànquing inicial
  historial-canvis-ranking/→ (admin) Historial de canvis de posició
  gestio-inscripcions/     → (admin) Gestió d'inscripcions
  gestio-llista-espera/    → (admin) Gestió de la llista d'espera
  gestio-reptes/           → (admin) Gestió de reptes
    nou/                   → (admin) Crear repte per a tercers
    access/                → (admin) Reptes d'accés
    [id]/programar/        → (admin) Programar repte
    [id]/resultat/         → (admin) Posar resultat (incl. +server.ts)

/handicap/                 → Torneig eliminació doble (1 per temporada)
  +layout.svelte           → Guard de 3 nivells (dev/admin/public)
  +page.svelte             → Dashboard
  configuracio/            → (admin) Configuració del torneig
  inscripcions/            → (admin) Gestió de participants
  sorteig/                 → (admin) Seeds i generació de bracket
  quadre/                  → Visualització del bracket (mobile: rondes acabades col·lapsades)
  partides/                → Llistat i programació de partides
  historial/               → Resultats passats
  estadistiques/           → Classificació i trajectòries
  resum/                   → Resum d'un torneig (per event_id)

/admin/                    → Operacions cross-cutting (admin only)
  +layout.svelte           → Guard: $adminChecked && $isAdmin
  +page.svelte             → Dashboard amb 2 seccions: "Gestió del club" i "Operacions del rànquing continu"
  socis/                   → CRUD de socis (cens del club)
  events/                  → CRUD d'events
    [id]/                  → Edició d'un event
    nou/                   → Crear event
  categories/              → Gestió de categories
  configuracio/            → Paràmetres del rànquing continu
  config/                  → Redirect a configuracio
  content-editor/          → Editor de contingut estàtic (home, normativa, horaris)
  audit-log/               → Registre d'auditoria
  reset-campionat/         → Reset complet del campionat (destructiu)
  ping/                    → Health check
  check/                   → Comprovació sessió/admin
  -- Endpoints servidor (sense pàgina) --
  debug/+server.ts
  penalitzacions/+server.ts
  reset/+server.ts
  waiting-list/+server.ts (+ [id]/, reorder/)
  whoami/+server.ts

/api/                      → Endpoints servidor
/dev/test-notifications/   → Pàgina de test (dev)
/offline/                  → Pàgina sense connexió
```

### Refactor d'agost-octubre 2026: arquitectura modular

S'han mogut **12 rutes** de `/admin/` als seus mòduls naturals (cada acció admin viu dins del mòdul que gestiona). Tota la nova UI segueix el patró editorial (paper, ink, accent, sense bg-blue-50, etc.) — vegeu "Direcció de disseny" més avall.

| Ruta antiga | Ruta nova | Notes |
| --- | --- | --- |
| `/admin/inscripcions-socials` | `/campionats-socials/gestio-inscripcions` | wrapper `gis-root` |
| `/admin/resultats-socials` | `/campionats-socials/resultats-pendents` | wrapper `rp-root` |
| `/admin/graella-resultats` | (fusionat) | botó "Imprimir A3" inline al sub-view head-to-head; modal extret a `HeadToHeadPrintModal` |
| `/admin/mitjanes-historiques` | `/campionats-socials/mitjanes-historiques` | edició només admin (gated `$effectiveIsAdmin`) |
| `/admin/mitjanes-comparatives` | `/campionats-socials/mitjanes-comparatives` | detecció dinàmica d'anys per modalitat |
| `/admin/inscripcions` (continu) | `/campionat-continu/gestio-inscripcions` | |
| `/admin/historial` (continu) | `/campionat-continu/historial-canvis-ranking` | el `/historial` públic ja existia, calia diferenciar |
| `/admin/ranking-inicial` | `/campionat-continu/ranking-inicial` | |
| `/admin/reptes` + `[id]/programar` + `[id]/resultat` + `nou` + `access` | `/campionat-continu/gestio-reptes/...` (mateixa estructura) | inclou `+server.ts` per a `requireAdmin` |
| `/admin/llistes-espera` | `/campionat-continu/gestio-llista-espera` | només continu té llista d'espera |

## Layouts i guards

| Layout | Guard | Accés |
|--------|-------|-------|
| `src/routes/+layout.svelte` | Cap | Tothom |
| `src/routes/admin/+layout.svelte` | `$adminChecked && $isAdmin` | Admins |
| `src/routes/handicap/+layout.svelte` | 3 nivells (dev/admin/public) | Veure CLAUDE_HANDICAP.md |
| `src/routes/campionat-continu/+layout.svelte` | Cap (només `<slot />`) | Tothom |
| `src/routes/general/+layout.svelte` | Cap | Tothom |

## Stores (`src/lib/stores/`)

### `auth.ts`
```typescript
// Discriminated union
type AuthState =
  | { status: 'loading' | 'anonymous'; session: null; user: null }
  | { status: 'authenticated'; session: { access_token: string }; user: UserProfile };

export const authState: Writable<AuthState>;
// Derived: user, roles, isAdmin (legacy), userId, isLoading, isAnon, status, token
```

### `adminAuth.ts`
```typescript
export const isAdmin: Writable<boolean>;       // true si l'usuari és admin
export const adminChecked: Writable<boolean>;  // true quan la comprovació ha finalitzat (PER A TOTS els usuaris)
export const adminUser: Derived;               // { user, isAdmin }
export function checkAdminStatus(email: string): Promise<void>;
// Comprova: ADMIN_EMAILS array → taula admins → taula socis
```
**Important**: `adminChecked` es posa `true` per a TOTS els usuaris (admin o no) un cop finalitza la comprovació. Usar `$adminChecked && $isAdmin` per guards complets.

### `viewMode.ts`
```typescript
export type ViewMode = 'admin' | 'player';
export const viewMode: ViewModeStore;   // toggle(), persistit a localStorage
export const effectiveIsAdmin: Derived; // true si isAdmin && viewMode === 'admin'
```
Els admins poden canviar a vista "Jugador" per veure l'app com un soci normal.

### `toastStore.ts`
```typescript
// Funcions d'ús comú:
showSuccess(message: string): void;
showError(message: string, error?: unknown): void;
showWarning(message: string): void;
showInfo(message: string): void;
```

### `calendar.ts`
Gestiona events del calendari general: `currentDate`, `calendarView` ('week'|'month'), `esdeveniments`, `reptesProgramats`, `partidesCalendari`. Funcions: `loadEsdeveniments()`, `loadReptesProgramats()`, `loadPartidesCalendari()`.

### `mySoci.ts`

```typescript
export const mySociNumero: Writable<number | null>;
export function getMySociNumero(): number | null;
```

Resol el `numero_soci` de l'usuari loggat a partir de `socis.email`. Es subscriu automàticament a `$user` i s'omple/buida amb la sessió. Útil per a:

- Construir enllaços al perfil propi (`/jugador/{numero_soci}`)
- Marcar files "is-mine" a classificacions, calendari, etc.
- Filtrar reptes/partides per "només meves" (vegeu `/campionat-continu/historial`)
- Renderitzar widgets personalitzats com `MyUpcomingMatchesWidget`

## Utils (`src/lib/utils/`)

| Fitxer | Funció principal |
|--------|-----------------|
| `auth-client.ts` | `hydrateSession()`, `initAuthClient()`, `signOut()`, `ensureFreshToken()` |
| `playerUtils.ts` | `formatarNomJugador()` → "A. Gómez", `obtenirInicials()`, `esNomValid()` |
| `playerName.ts` | Utilitats addicionals de format de noms |
| `adminPage.ts` | Helpers per a pàgines d'administració |
| `loadingStates.ts` | Gestió d'estats de càrrega |
| `skeletonUtils.ts` | Skeleton loaders |
| `focus-management.ts` | Accessibilitat: gestió de focus |
| `http.ts` | Utilitats HTTP |
| `supabase.ts` | `getSupabaseClient()`, `withSupabase<T>()` |
| `handicap-*.ts` | Veure CLAUDE_HANDICAP.md |

## API (`src/lib/api/`)

| Fitxer | Funcions |
|--------|---------|
| `socialLeagues.ts` | `getSocialLeagueEvents()`, `exportCalendariToCSV()` |
| `classifications.ts` | `generateFinalClassifications()` |

## Components (`src/lib/components/`)

### Components generals (`general/`)

- **`Nav.svelte`** (legacy): Navegació antiga, encara referenciada per algunes rutes.
- **`NavEditorial.svelte`**: Navegació editorial actual. Topbar + section nav per modalitat (general/socials/continu/handicap/admin) amb dropdowns admin contextuals i panell mòbil amb hamburger. Bloqueja el scroll del body via classe `nav-mobile-open`.
- `Banner.svelte`, `Loader.svelte`, `ErrorBoundary.svelte`, `ErrorToast.svelte`
- `SwipeHandler.svelte`, `PullToRefresh.svelte`
- `NotificationSettings.svelte`, `NotificationPermissions.svelte`
- **`MyUpcomingMatchesWidget.svelte`**: Llista properes partides programades d'un soci. Sense props mostra les de l'usuari loggat (via `mySociNumero`). Amb `sociNumero={X}` mostra les d'aquell soci (s'usa al perfil). Si no hi ha partides futures, no es renderitza. Usat a `/+page.svelte` (home) i `/jugador/[numero_soci]/+page.svelte`.

### Components campionats-socials (`campionats-socials/`)
- `SocialLeagueCalendarViewer.svelte`, `SocialLeagueMatchResults.svelte`
- `SocialLeaguePlayersGrid.svelte`, `SocialLeagueClassifications.svelte`
- `DragDropInscriptions.svelte`, `CategorySetup.svelte`, `CategoryManagement.svelte`
- `PlayerRestrictionsTable.svelte`, `HeadToHeadGrid.svelte`, `HallOfFame.svelte`

### Components handicap (`handicap/`)
- `HandicapBracketView.svelte` — Render visual del bracket (SVG connectors)
- `HandicapMatchResult.svelte` — Formulari d'introducció de resultats
- `HandicapAvailabilityGrid.svelte` — Matriu de disponibilitat (editable/aggregate)
- `HandicapSlotPicker.svelte` — Selector de data/hora/taula inline
- `HandicapWeeklyCalendar.svelte` — Calendari setmanal de partides
- `HandicapBranchBalance.svelte` — Equilibri de branques
- `HandicapScheduleConfig.svelte` — Configuració de dates i períodes bloquejats

## Convencions de codi

### Patró de pàgina estàndard
```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
  import { user } from '$lib/stores/auth';

  let loading = true;
  let error: string | null = null;
  let data: SomeType[] = [];

  onMount(async () => {
    const { data: result, error: err } = await supabase
      .from('taula')
      .select('camps')
      .eq('event_id', eventId);

    if (err) { error = err.message; loading = false; return; }
    data = result ?? [];
    loading = false;
  });
</script>

{#if loading}
  <div>Carregant...</div>
{:else if error}
  <div class="text-red-600">{error}</div>
{:else}
  <!-- contingut -->
{/if}
```

### Imports de Supabase
```typescript
import { supabase } from '$lib/supabaseClient';
// El client ja inclou wrapRpc (error mapping al català)
```

### Guards d'accés en pàgines admin
```svelte
import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
$: if ($adminChecked && !$isAdmin) goto('/');
// O usar $effectiveIsAdmin per respectar el toggle de vista
```

### Variables reactives
Usar `$:` per a valors derivats de stores:
```svelte
$: canAccess = $adminChecked && $isAdmin;
$: filteredItems = items.filter(i => i.estat === selectedEstat);
```

### Errors de Supabase
```typescript
const { data, error } = await supabase.from('...').select();
if (error) {
  errorMessage = error.message; // o usar showError() del toastStore
  return;
}
```

### Import de tipus
```typescript
import type { SomeType } from '$lib/utils/some-module'; // import type separat
import { someFunction } from '$lib/utils/some-module';   // import de valor
// NO: import { someFunction, type SomeType } from '...' (causa errors de parse)
```

## Nav.svelte — com afegir seccions

Estructura de la constant `navegacio`:
```typescript
const navegacio: Record<string, NavSection> = {
  handicap: {
    label: 'Hàndicap',
    icon: '⚖️',
    color: 'purple',
    links: [              // visibles a tothom
      { href: '/handicap', label: 'Dashboard' },
    ],
    userLinks: [          // visibles als autenticats
      { href: '/handicap/inscripcio', label: 'Inscriure\'s' }
    ],
    adminLinks: [         // visibles als admins
      { href: '/handicap/configuracio', label: 'Configuració' }
    ],
    adminOnly: false      // true → secció invisible als no-admins
  }
};
```

## Model de dades global

### Taules core
```
socis (numero_soci PK, nom, cognoms, email, data_naixement, ...)
players (id UUID PK, numero_soci FK→socis, ...)
admins (email PK)

events (
  id UUID PK,
  nom TEXT,
  tipus_competicio TEXT,  -- 'lliga_social' | 'ranking_continu' | 'handicap'
  temporada TEXT,          -- format 'YYYY-YYYY' (ex: '2025-2026')
  estat_competicio TEXT,   -- 'planificacio'|'inscripcions'|'en_curs'|'finalitzat'
  actiu BOOLEAN,
  data_inici DATE,
  data_fi DATE
)

categories (
  id UUID PK,
  event_id UUID FK,
  nom TEXT,
  ordre_categoria SMALLINT,  -- ordre dins l'event; >= 3 → últim grup de distància
  distancia_caramboles SMALLINT
)

inscripcions (
  id UUID PK,
  event_id UUID FK,
  soci_numero INTEGER FK→socis,  -- NO player_id!
  categoria_assignada_id UUID FK→categories,
  preferencies_dies TEXT[],
  preferencies_hores TEXT[],
  ...
)

calendari_partides (
  id UUID PK,
  event_id UUID FK,   -- SEMPRE filtrar per event_id
  categoria_id UUID FK→categories (NULLABLE per hàndicap),
  jugador1_id UUID FK→players,
  jugador2_id UUID FK→players,
  data_programada TIMESTAMPTZ,
  hora_inici TEXT,    -- 'HH:MM'
  taula_assignada SMALLINT,  -- 1, 2 o 3 (billar, no "taula")
  estat TEXT,         -- 'generat'|'publicat'|'jugada'|...
  caramboles_jugador1, caramboles_jugador2, entrades, ...
)

classificacions (event_id, categoria_id, player_id, punts, ...)
mitjanes_historiques (player_id, temporada, distancia_objectiu, ...)
```

### Relació socis ↔ players ↔ inscripcions
```
socis.numero_soci = players.numero_soci   (JOIN principal)
inscripcions.soci_numero = socis.numero_soci  (NO player_id!)
players.id = calendari_partides.jugador1_id / jugador2_id
```

### Events per temporada
```typescript
// Buscar events per temporada, NO per actiu=true (pot estar finalitzat)
.from('events').eq('temporada', '2025-2026').eq('tipus_competicio', 'social')
// actiu=true és útil per l'event "actual actiu", però per historial usar temporada
```

## Terminologia del domini

| Terme correcte | Evitar |
|---------------|--------|
| billar (B1, B2, B3) | taula de joc |
| caramboles | punts |
| entrades | torns |
| distància | handicap (en context de puntuació) |
| guanyador / perdedor | winner / loser |
| reptador / reptat | challenger / challenged |
| jornada | round (social) |
| seed | cap de sèrie |
| bye | descans |
| quadre | bracket |

UI sempre en **català**. Comentaris de codi: mixt català/castellà.

## Direcció de disseny (per a skills/agents de frontend)

Context que les skills generatives de frontend (com `frontend-design`) NO poden inferir del codi i que cal saber abans de proposar cap direcció estètica.

### Audiència i to
- **Públic**: socis del Foment Martinenc, secció billar 3 bandes — adults i gent gran (50+).
- **Institucional**, NO startup. Evitar estètica "tech bro": gradients neon, glassmorphism, animacions ostentoses, copy de màrqueting.
- **Idioma UI sempre en català**.

### Restriccions tècniques
- Stack: SvelteKit 2 + **Svelte 5** (runes als components nous: `$state`, `$derived`, `$effect`) + Tailwind 3 + Supabase. Adaptador estàtic (GitHub Pages) — sense SSR runtime.
- PWA offline-first amb Service Worker propi (NO vite-pwa, tot i que és al package.json). Bundle reduït: evitar dependències pesades (Lottie, Framer Motion, biblioteques d'icones SVG, més biblioteques de gràfics — ja hi ha ECharts).
- Instal·lable a iOS/Android: respectar safe areas, no fixed positioning agressiu.

### Sistema visual existent (no reinventar)
- **Tipografia ja escalada per accessibilitat** (veure `tailwind.config.cjs`): `text-xs`=16px, `text-base`=20px. **Mai** baixar de `text-sm`. Hi ha un `--font-size-multiplier` CSS que els usuaris poden augmentar.
- **Colors funcionals**: blau primari (`bg-blue-600`), verd èxit, vermell error/perill, taronja warning. Paleta accessible WCAG a `colors.accessible` per a high-contrast.
- **Touch targets** mínim 48px (utility `touch-target`, spacing `touch`/`touch-lg`). Components interactius mai més petits.
- **Focus visible enhanced**: outline blau 4px (`.focus-visible-enhanced`). Mai desactivar.
- **High-contrast mode**: classe `.high-contrast` al body. Tot component nou ha de funcionar en ambdós modes — no separar seccions només per `bg-gray-50`, cal contorn.
- **Animacions**: només `slideDown` (0.2s). Respectar `prefers-reduced-motion` amb fallback.

### Decisions estètiques preses
- **Densitat baixa / espai generós** (taules denses només amb pattern `mobile-stack`).
- Cards = `bg-white` + `border`. NO glassmorphism, NO shadows fortes per defecte.
- Iconografia: **emojis Unicode** al Nav (⚖️ hàndicap, etc.). NO afegir biblioteques d'icones.

### Què NO fer
- Gradients morats/blaus genèrics estil landing de SaaS.
- `rounded-3xl` o `rounded-full` exagerats en botons grans.
- Animacions d'entrada a cada element.
- Dark mode toggle (no implementat, no és prioritari).
- Substituir el sistema de colors funcional per una paleta "de marca" inventada.

### Què SÍ buscar
- Jerarquia tipogràfica clara aprofitant l'escala ja gran (jugar amb pesos i mides relatives).
- Reaprofitament de la paleta funcional abans d'ampliar-la.
- Compatibilitat amb high-contrast mode i `--font-size-multiplier`.
- Layouts que funcionin tant en portrait com en landscape (la PWA es fa servir en tablet a peu de billar).

### Format dels noms de jugador (regla obligatòria)

**Sempre** usar `formatarNomJugador()` de `$lib/utils/playerUtils` per mostrar noms de jugadors a la UI. Format: **inicials del nom + primer cognom** (ex: "Joan Garcia Pujol" → "J. Garcia").

La funció gestiona el connector català "i" entre cognoms ("Joan Garcia i Pujol" → "J. Garcia").

**Mai mostrar** el `numero_soci` com a text inline (estil "Soci #1234") en pantalles d'usuari. Si cal mostrar-lo (rar, només zones d'admin de gestió de socis), fes-ho com a columna pròpia identificada, no concatenat amb el nom.

**Patró d'aplicació:**
```svelte
import { formatarNomJugador } from '$lib/utils/playerUtils';
…
{formatarNomJugador(`${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim())}
```

### Congruència entre estat loggat / no loggat (regla obligatòria)

Tota pantalla ha de tenir **el mateix shell visual i layout** independentment de si l'usuari està loggat o no. La personalització és una **capa addicional** que es desactiva, no que reestructura la pantalla.

**Què canvia entre estats (capa de personalització):**
- Topbar: "Iniciar sessió" (anònim) ↔ pill amb nom + número de soci (loggat).
- Highlights de "tu" / "les meves" a taules (classificació, calendari, graella): només quan loggat.
- Vistes "Les meves partides" / "Els meus reptes": només existeixen quan loggat. En anònim, el toggle d'aquesta vista no apareix o redirigeix a login.
- Botons d'acció (Inscriure's, Crear repte, Programar partida): si està loggat, acció directa. Si no, mostren CTA "Iniciar sessió per a…" en el mateix lloc del botó.

**Què NO ha de canviar:**
- Layout principal (mast-head, secció nav, subtabs, columnes de taules, mides tipogràfiques).
- Quantitat de columnes a les taules de dades. Una taula de classificació ha de tenir les mateixes columnes en ambdós estats.
- Estructura de les pàgines: un usuari anònim ha de poder consultar tots els resultats, calendaris, classificacions i historial. Només es restringeix l'edició i la personalització.
- Patrons d'iconografia i color funcional.

**Implementació tipus:**
```svelte
{#if $isAuthenticated && row.soci_numero === $mySociNumero}
  <tr class="is-mine">
{:else}
  <tr>
{/if}
```
La classe `is-mine` aplica només els estils de personalització (background tint, badge "tu"), però la `<tr>` continua tenint la mateixa estructura.

**Validació**: abans de tancar qualsevol pantalla nova, comprovar amb `signOut()` que el layout es manté i la informació no personalitzada continua sent consultable.

## Errors coneguts (ignorar)

- **`connectionManager.ts`**: `handleOfflineEvent` hauria de ser `handleOnlineEvent`. Error pre-existent, no tocar.
- `npm run check` esperat: **0 errors i 0 warnings** (des de la revisió integral de juny 2026).

## Migració automàtica de mitjanes

A partir del 2026-05-06, quan un event social passa a `estat_competicio = 'finalitzat'`, un trigger PostgreSQL volca automàticament les mitjanes finals dels seus jugadors a `mitjanes_historiques`:

- Funció: `public.migrate_social_event_to_historiques(event_id UUID) RETURNS INTEGER` (idempotent via `UNIQUE (soci_id, year, modalitat)`)
- Trigger: `event_finalitzat_migrate_mitjanes AFTER INSERT OR UPDATE OF estat_competicio ON events`
- Mapatge modalitats: `tres_bandes → '3 BANDES'`, `lliure → 'LLIURE'`, `banda → 'BANDA'`
- Convenció `year`: end-year de la temporada (`2025-2026 → 2026`)

La migració `20260506000002_auto_migrate_social_averages_to_historiques.sql` inclou backfill per a tots els events ja finalitzats. Els permisos `EXECUTE` estan revocats per a `anon`/`authenticated`; només el trigger i `service_role` poden invocar la funció directament.

## Comandes

```bash
npm run dev        # Servidor de desenvolupament
npm run build      # Build de producció
npm run check      # TypeScript + svelte-check
npm test           # Vitest
```

## Agents

### reviewer
Revisa el codi generat per:
- Terminologia: "billar" (no "taula"), català a la UI
- Patró Supabase: filtrar per `event_id`, usar `soci_numero` a inscripcions (no `player_id`)
- No modificar taules existents sense migració explícita
- Imports de tipus separats (`import type { X }` apart de `import { fn }`)
- Coherència amb CLAUDE_HANDICAP.md i CLAUDE_SUPABASE.md

### tester
Després de cada canvi:
- Executa `npm run check`
- Reporta només errors nous (ignorar `connectionManager.ts` i warnings CSS)
- Verifica que les rutes dels altres mòduls (socials, continu, hàndicap) compilen

### integrity
Abans de donar una tasca per completada:
- Queries a `calendari_partides` sempre filtren per `event_id`
- Cap camp afegit a taules existents sense migració
- RLS policies segueixen el patró establert (veure CLAUDE_SUPABASE.md)
- Cap mòdul existent trencat
