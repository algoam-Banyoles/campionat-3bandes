# Generació de Classificacions Finals

## Problema
El campionat "Campionat Social 3 Bandes 2025-2026" està marcat com finalitzat però només mostra la llista d'inscrits en lloc de les classificacions reals amb punts, caramboles, etc.

## Solució Implementada

S'ha creat una funció `generate_final_classifications` que:
1. Calcula les classificacions utilitzant la funció `get_social_league_classifications`
2. Guarda les classificacions a la taula `classificacions`
3. Les classificacions queden permanents i es mostren correctament

## Com Aplicar la Solució

### Opció 1: Consola SQL de Supabase (RECOMANAT)

1. Obre la consola SQL de Supabase: https://supabase.com/dashboard/project/qbldqtaqawnahuzlzsjs/sql
2. Copia tot el contingut del fitxer `generate_classifications_manual.sql`
3. Enganxa'l a la consola SQL
4. Executa'l (botó Run o Ctrl+Enter)

Això farà:
- Crear la funció `generate_final_classifications`
- Generar les classificacions per al campionat 2025-2026
- Mostrar les primeres 20 classificacions com a verificació

### Opció 2: PowerShell (després d'aplicar la migració)

```powershell
# Primer, aplica la migració manualment a Supabase
# Després executa:
.\Generate-Classifications.ps1
```

## Verificació

Després d'executar la funció, comprova:

1. **A la consola SQL:**
```sql
SELECT COUNT(*) FROM classificacions 
WHERE event_id = '8a81a82e-96c9-4c49-9fbe-b492394462ac';
```

Hauria de retornar aproximadament 45 classificacions (el nombre de jugadors inscrits).

2. **A la PWA:**
Ves a: http://localhost:5173/campionats-socials?view=history
Clica sobre "📊 Classificació" del Campionat Social 3 Bandes 2025-2026
Ara hauria de mostrar el banner verd "Classificació Actualitzada" amb totes les dades.

## Fitxers Creats/Modificats

- `supabase/migrations/20250211000001_generate_final_classifications.sql` - Migració amb la funció
- `generate_classifications_manual.sql` - Script SQL per executar manualment
- `Generate-Classifications.ps1` - Script PowerShell per generar classificacions
- `src/lib/api/classifications.ts` - Funcions TypeScript per la interfície
- `src/routes\campionats-socials\[eventId]\classificacio\+page.svelte` - Millorat amb banners informatius

## Ús Futur

Quan finalitzis un altre campionat:

1. **Via PowerShell:**
```powershell
.\Generate-Classifications.ps1 -EventId "id-del-campionat"
```

2. **Via SQL:**
```sql
SELECT * FROM generate_final_classifications('id-del-campionat');
```

3. **Via codi (a implementar a la interfície d'admin):**
```typescript
import { generateFinalClassifications } from '$lib/api/classifications';

const result = await generateFinalClassifications(eventId);
console.log(result.message);
```

## Notes Importants

- La funció esborra classificacions existents abans de generar-ne de noves
- Només es poden generar classificacions si hi ha partides validades
- Les classificacions es basen en `get_social_league_classifications` que:
  - Calcula punts (2 per victòria, 1 per empat, 0 per derrota)
  - Calcula mitjanes generals i millors mitjanes
  - Respecta l'estat dels jugadors (retirats, etc.)
  - Ordena per: punts DESC, mitjana general DESC, caramboles DESC

## Propera Millora Recomanada

Afegir un botó a la interfície d'administració per generar classificacions finals quan es finalitza un campionat, així no cal fer-ho manualment.
