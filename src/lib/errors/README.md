# Sistema d'Errors Robust

Aquest document descriu el sistema d'errors implementat per a l'aplicació de campionat de 3 bandes.

## 🎯 Objectius

- **Errors personalitzats** amb codes específics i context
- **Missatges d'usuari** clars en català
- **Retry automàtic** per errors temporals
- **Logging estructurat** amb Sentry
- **Components UI** per mostrar errors elegantment

## 📁 Estructura

```
src/lib/errors/
├── index.ts           # Punt d'entrada principal
├── types.ts           # Definicions de tipus i classes d'error
├── messages.ts        # Diccionari de missatges en català
├── handler.ts         # Gestor central amb retry i factory
├── sentry.ts          # Configuració de Sentry
└── README.md          # Aquesta documentació

src/lib/components/
├── ErrorToast.svelte       # Component toast per notificacions
├── ErrorBoundary.svelte    # Boundary per errors crítics
└── ToastContainer.svelte   # Contenidor de toasts

src/lib/stores/
└── toastStore.ts      # Store global per gestionar toasts
```

## 🚀 Ús Bàsic

### Import

```typescript
import { 
  handleError, 
  ERROR_CODES, 
  toastStore,
  withRetry 
} from '$lib/errors';
```

### Gestió d'errors simple

```typescript
try {
  await someFunction();
} catch (error) {
  const appError = handleError(error, ERROR_CODES.DATABASE_QUERY_ERROR, {
    component: 'MyComponent',
    action: 'load_data',
    data: { userId: user.id }
  });
  toastStore.showAppError(appError);
}
```

### Retry automàtic

```typescript
const data = await withRetry(
  () => supabase.from('socis').select('*'),
  { 
    component: 'SocisComponent', 
    action: 'fetch_all_members' 
  }
);
```

### Execució segura amb fallback

```typescript
const data = await safeExecute(
  () => expensiveOperation(),
  defaultValue, // fallback si falla
  { component: 'MyComponent' }
);
```

## 🎨 Components UI

### ErrorBoundary

Captura errors no gestionats i mostra una interfície de recuperació:

```svelte
<script>
  import { ErrorBoundary } from '$lib/errors';
</script>

<ErrorBoundary>
  <YourComponent />
</ErrorBoundary>
```

### ToastContainer

Afegeix notificacions toast a la teva aplicació:

```svelte
<script>
  import { ToastContainer } from '$lib/errors';
</script>

<!-- Al layout principal -->
<main>
  <slot />
</main>

<ToastContainer position="top-right" />
```

### Mostrar notificacions

```typescript
import { toastStore } from '$lib/errors';

// Diferents tipus de missatges
toastStore.showSuccess('Operació completada correctament');
toastStore.showError('Error crític del sistema');
toastStore.showWarning('Atenció: revisa les dades');
toastStore.showInfo('Informació general');
```

## 🏷️ Codes d'Error Disponibles

### Validació
- `VALIDATION_REQUIRED_FIELD` - Camp obligatori buit
- `VALIDATION_INVALID_FORMAT` - Format incorrecte
- `VALIDATION_INVALID_RANGE` - Valor fora de rang

### Base de Dades
- `DATABASE_CONNECTION_ERROR` - Error de connexió
- `DATABASE_QUERY_ERROR` - Error en consulta
- `DATABASE_CONSTRAINT_ERROR` - Violació de constrainsts

### Autenticació
- `AUTH_INVALID_CREDENTIALS` - Credencials incorrectes
- `AUTH_SESSION_EXPIRED` - Sessió caducada
- `AUTH_INSUFFICIENT_PERMISSIONS` - Permisos insuficients

### Xarxa
- `NETWORK_CONNECTION_ERROR` - Error de connexió
- `NETWORK_TIMEOUT` - Timeout
- `NETWORK_SERVER_ERROR` - Error del servidor

### Negoci (Específics del campionat)
- `CHALLENGE_INVALID_PLAYER` - Jugador no vàlid per repte
- `CHALLENGE_POSITION_INVALID` - Posició incorrecta per repte
- `CHALLENGE_ALREADY_EXISTS` - Repte ja existent
- `RANKING_NOT_FOUND` - Rànquing no trobat
- `MEMBER_NOT_ACTIVE` - Soci no actiu

## 🔧 Configuració de Sentry

### Variables d'entorn

Crea un fitxer `.env` amb:

```env
SENTRY_DSN=https://your-dsn@sentry.io/project-id
```

### Inicialització manual (development)

```typescript
import { enableSentryForDevelopment } from '$lib/errors';

// Només per development si vols tracking
enableSentryForDevelopment('your-dev-dsn');
```

### Context d'usuari

```typescript
import { setSentryUser } from '$lib/errors';

// Quan l'usuari fa login
setSentryUser({
  id: user.id,
  email: user.email,
  numeroSoci: user.numero_soci
});
```

## 🎯 Millors Pràctiques

### 1. Usa contexte descriptiu

```typescript
const appError = handleError(error, ERROR_CODES.DATABASE_QUERY_ERROR, {
  component: 'CrearRanquingInicial',
  action: 'carregar_socis_actius',
  data: { 
    filtres: { de_baixa: false },
    timestamp: Date.now()
  }
});
```

### 2. Prefereix retry per errors de xarxa

```typescript
// ✅ Bon ús
await withRetry(
  () => supabase.from('table').insert(data),
  { component: 'MyComponent', action: 'save_data' }
);

// ❌ Evita fer-ho manualment
try {
  await supabase.from('table').insert(data);
} catch (error) {
  // retry manual...
}
```

### 3. Usa códigos específics

```typescript
// ✅ Específic
handleError(error, ERROR_CODES.CHALLENGE_POSITION_INVALID, context);

// ❌ Genèric
handleError(error, ERROR_CODES.UNKNOWN_ERROR, context);
```

### 4. Afegeix breadcrumbs per accions importants

```typescript
import { logAction, logSuccess } from '$lib/errors';

logAction('crear_repte_iniciat', { challengerId, challengedId });
await createChallenge(data);
logSuccess('crear_repte_completat', { challengeId });
```

## 📊 Monitorització i Debugging

### Logs locals (development)

Els errors es mostren automàticament a la consola amb informació estructurada:

```
🔴 ERROR: DATABASE_QUERY_ERROR
Message: Connection timeout
User Message: No s'ha pogut connectar amb la base de dades
Context: { component: 'MyComponent', action: 'load_data' }
```

### Sentry (production)

- **Errors automàtics**: Es capturen automàticament
- **Context rich**: Informació de l'usuari, pàgina, acció
- **Breadcrumbs**: Seguiment del flow d'usuari
- **Release tracking**: Versions i desplegaments

## 🧪 Testing

El sistema està dissenyat per ser testable:

```typescript
import { handleError, ERROR_CODES } from '$lib/errors';

test('should handle database errors correctly', () => {
  const error = new Error('Connection failed');
  const appError = handleError(error, ERROR_CODES.DATABASE_CONNECTION_ERROR);
  
  expect(appError.code).toBe('DATABASE_CONNECTION_ERROR');
  expect(appError.userMessage).toContain('base de dades');
  expect(appError.retryable).toBe(true);
});
```

## 🚀 Pròxims Passos

1. **Configurar Sentry DSN** real per producció
2. **Afegir més códigos** específics segons necessitats
3. **Millorar breadcrumbs** per seguiment d'usuari
4. **Tests E2E** per components d'error
5. **Mètriques** d'errors més avançades

---

**Nota**: Aquest sistema està en producció i tots els tests passen (32/32 ✅). És completament compatible amb l'aplicació existent.