# CLAUDE.md — Projecte Campionat 3 Bandes

PWA de gestió de la secció de billar 3 bandes del Foment Martinenc.

## Stack

- **Frontend**: SvelteKit + TypeScript + TailwindCSS
- **Backend**: Supabase (PostgreSQL + Auth + RLS)
- **Gràfics**: ECharts
- **Error tracking**: Sentry
- **Deploy**: Adaptador estàtic (GitHub Pages)
- **PWA**: Service Worker propi (NO vite-pwa)

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
    classificacio/
  inscripcions/            → Inscripció de socis
  cerca-jugadors/

/campionat-continu/        → Rànquing permanent (reptes directes)
  ranking/                 → Classificació (20 posicions)
  reptes/                  → Tots els reptes
    nou/                   → Crear repte
    me/                    → Els meus reptes actius
    [id]/resultat/
  historial/               → Partides jugades
  llista-espera/           → Jugadors en llista d'espera
  inscripcio/              → Alta al campionat continu
  classificacio/[id]/      → Classificació d'una temporada
  configuracio/notificacions/

/handicap/                 → Torneig eliminació doble (1 per temporada)
  +layout.svelte           → Guard de 3 nivells (dev/admin/public)
  +page.svelte             → Dashboard
  configuracio/            → (admin) Configuració del torneig
  inscripcions/            → (admin) Gestió de participants
  sorteig/                 → (admin) Seeds i generació de bracket
  quadre/                  → Visualització del bracket
  partides/                → Llistat i programació de partides
  historial/               → Resultats passats
  estadistiques/           → Classificació i trajectòries
  resum/                   → Resum d'un torneig (per event_id)

/admin/                    → Gestió global (admin only)
  +layout.svelte           → Guard: $adminChecked && $isAdmin
  socis/                   → CRUD de socis
  events/                  → CRUD d'events
    [id]/                  → Edició d'un event
    nou/                   → Crear event
  categories/              → Gestió de categories
  inscripcions/            → Inscripcions campionat continu
  inscripcions-socials/    → Inscripcions campionats socials
  reptes/                  → Gestió de reptes
    [id]/programar/
    [id]/resultat/
    nou/
    access/
  resultats-socials/       → Introducció de resultats socials
  graella-resultats/       → Graella de resultats
  historial/               → Historial de partides admin
  mitjanes-historiques/    → Mitjanes per temporada
  mitjanes-comparatives/   → Comparativa de mitjanes
  configuracio/            → Configuració general
  config/                  → Configuració avançada
  content-editor/          → Editor de contingut
  llistes-espera/          → Gestió llistes d'espera
  ranking-inicial/         → Configuració del rànquing inicial
  reset-campionat/         → Eina de reset
  ping/                    → Health check
  check/                   → Comprovació de BD

/api/                      → Endpoints servidor
/dev/test-notifications/   → Pàgina de test (dev)
/offline/                  → Pàgina sense connexió
```

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
- **`Nav.svelte`**: Navegació principal. Sidebar fixa (tablet/desktop/landscape). Navbar superior mòbil (portrait). Estructura de seccions: `navegacio` (Record<string, NavSection>). Cada secció té `links` (tots), `userLinks` (autenticats), `adminLinks` (admins), `adminOnly` (amaga als no-admins).
- `Banner.svelte`, `Loader.svelte`, `ErrorBoundary.svelte`, `ErrorToast.svelte`
- `ConnectionStatus.svelte`, `OfflineIndicator.svelte`
- `OrientationBanner.svelte` — Detecta portrait/landscape
- `MobileNavigation.svelte`, `BottomTabBar.svelte`, `HamburgerMenu.svelte`
- `SwipeHandler.svelte`, `PullToRefresh.svelte`
- `NotificationSettings.svelte`, `NotificationPermissions.svelte`

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
  tipus_competicio TEXT,  -- 'social' | 'continu' | 'handicap'
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

## Errors coneguts (ignorar)

- **`connectionManager.ts`**: `handleOfflineEvent` hauria de ser `handleOnlineEvent`. Error pre-existent, no tocar.
- `npm run check` reporta 1 error (aquest) i ~99 warnings CSS → tots pre-existents.

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
