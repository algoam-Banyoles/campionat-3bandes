# Graella de Resultats Creuats (Head-to-Head Grid)

## Descripció

La graella de resultats creuats és una funcionalitat administrativa que permet visualitzar els resultats de tots els enfrontaments entre jugadors d'una categoria en format de matriu.

## Característiques

### Visualització en Format Matriu
- **Files i columnes**: Cada jugador apareix tant a les files com a les columnes
- **Cel·la d'enfrontament**: A la intersecció (i,j) es mostren les dades del jugador i contra el jugador j
- **Format de graella 3x3 per cel·la**:
  - Posició (1,1): Caramboles
  - Posició (1,3): Entrades
  - Posició (2,2): Punts (2=victòria, 1=empat, 0=derrota)
  - Posició (3,1): Mitjana (caramboles/entrades)

### Restriccions d'Accés
- **Només administradors**: Accessible únicament des del panell d'administració
- **Només campionats en curs**: Mostra només dades de campionats socials actius i en estat "en_curs"

### Selecció de Categoria
- Selecció visual de categoria amb informació de distància i entrades màximes
- Càrrega automàtica de dades en seleccionar una categoria
- Gestió d'errors amb possibilitat de reintent

## Arquitectura Tècnica

### Components
1. **HeadToHeadGrid.svelte** (`src/lib/components/campionats-socials/`)
   - Component reutilitzable per mostrar la graella
   - Gestió d'estats de càrrega i errors
   - Responsive design amb scroll horizontal

2. **Pàgina d'administració** (`src/routes/admin/graella-resultats/+page.svelte`)
   - Selecció de campionat i categoria
   - Integració amb el component de visualització
   - Protegida per auth admin

### Capa de Dades

#### API Service (`src/lib/api/socialLeagues.ts`)
```typescript
getHeadToHeadResults(eventId: string, categoriaId: string): Promise<{
  players: Array<HeadToHeadPlayer>;
  matches: Map<string, HeadToHeadMatchData>;
}>
```

#### Funció RPC de Supabase
```sql
get_head_to_head_results(
  p_event_id UUID,
  p_categoria_id UUID
)
```

Retorna:
- Informació dels jugadors (nom, cognoms, número de soci)
- Dades de cada enfrontament (caramboles, entrades, punts, mitjana)
- Només partides validades amb resultats complets

### Tipus TypeScript (`src/lib/types/index.ts`)

```typescript
interface HeadToHeadMatchData {
  caramboles: number;
  entrades: number;
  punts: number;
  mitjana: number;
}

interface HeadToHeadPlayer {
  id: UUID;
  nom: string;
  cognoms: string | null;
  numero_soci: number;
}

interface HeadToHeadGrid {
  players: HeadToHeadPlayer[];
  cells: Map<string, HeadToHeadCell>;
}
```

## Ús

### Accés
1. Navegar a `/admin/graella-resultats`
2. Alternatívament, des del dashboard d'admin, clicar a "🎯 Graella de Resultats Creuats"

### Visualització
1. Seleccionar una categoria de la llista
2. La graella es carregarà automàticament
3. Desplaçar-se horitzontalment si hi ha molts jugadors
4. Les cel·les diagonals (jugador vs jugador mateix) mostren "-"
5. Les cel·les sense enfrontament mostren "Pendent"

### Llegenda
- **C**: Caramboles
- **E**: Entrades
- **P**: Punts (2=victòria, 1=empat, 0=derrota)
- **M**: Mitjana (caramboles/entrades amb 3 decimals)

## Migració de Base de Dades

La funció SQL es troba a:
- `supabase/migrations/20251022_add_head_to_head_function.sql`
- `supabase/sql/rpc_get_head_to_head_results.sql` (còpia de referència)

Per aplicar-la:
```bash
npx supabase db push
```

## Estil Visual

- **Capçaleres**: Fons fosc (#34495e) amb text blanc
- **Noms de jugadors**: Rotats 45° per estalviar espai
- **Cel·les d'enfrontament**: Graella 3x3 amb dades estructurades
- **Punts destacats**: Color verd per emfatitzar els punts
- **Responsive**: Adaptació automàtica a mòbils i tablets

## Futures Millores Possibles

1. Filtrar per estat de partida (només validades, també pendents, etc.)
2. Export a PDF o imatge
3. Vista compacta/expandida
4. Ordenació de jugadors per posició en classificació
5. Destacar victòries/derrotes amb colors
6. Comparació entre categories diferents
7. Històric de confrontacions entre dos jugadors específics

## Notes Tècniques

- La funció RPC utilitza `SECURITY DEFINER` per accedir a les taules necessàries
- Els permisos d'execució estan donats a usuaris autenticats, però l'accés està restringit a nivell d'aplicació
- La graella utilitza `position: sticky` per mantenir capçaleres visibles durant el scroll
- Els noms llargs s'ajusten amb `text-overflow: ellipsis` i tooltips amb el nom complet

## Manteniment

### Depuració
- Revisar console.error per errors en càrrega de dades
- Verificar que la funció RPC estigui desplegada correctament
- Comprovar que hi hagi partides validades a la categoria seleccionada

### Performance
- La consulta està optimitzada amb joins i filtres a nivell de BD
- El component només renderitza quan hi ha canvis de categoria
- Utilitza Map per accés O(1) a les dades d'enfrontaments
