# Migració al Sistema de View Mode

## Què és View Mode?

El sistema de View Mode permet als administradors canviar entre la vista d'administrador i la vista de jugador regular, útil per a testing i desenvolupament.

## Com migrar components

### Abans:
```typescript
import { isAdmin } from '$lib/stores/adminAuth';

// Usar directament isAdmin
{#if $isAdmin}
  <!-- Contingut només per admins -->
{/if}
```

### Després:
```typescript
import { effectiveIsAdmin } from '$lib/stores/viewMode';

// Usar effectiveIsAdmin en lloc d'isAdmin
{#if $effectiveIsAdmin}
  <!-- Contingut només per admins (respecta el view mode) -->
{/if}
```

## Components que necessiten migració

Cerca tots els components que utilitzin `isAdmin` i substitueix-lo per `effectiveIsAdmin`:

1. Components de pàgines (`+page.svelte`)
2. Components de campionats socials
3. Components d'administració
4. Qualsevol component que mostri funcionalitats diferents per admins

## Nota important

- `isAdmin` segueix existint i retorna el rol REAL de l'usuari
- `effectiveIsAdmin` considera tant el rol com el view mode actual
- Usa `effectiveIsAdmin` per mostrar/ocultar funcionalitats UI
- Mantén `isAdmin` per verificacions de seguretat al backend

## Buscar i reemplaçar

```bash
# Cerca tots els usos d'isAdmin en components Svelte
rg "import.*isAdmin.*from.*adminAuth" -t svelte

# Substitueix les importacions
# De: import { isAdmin } from '$lib/stores/adminAuth';
# A:   import { effectiveIsAdmin } from '$lib/stores/viewMode';

# I substitueix els usos
# De: $isAdmin
# A:   $effectiveIsAdmin
```
