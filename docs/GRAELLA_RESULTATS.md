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

### Impressió (A3 Apaïsat)
- **Botó d'impressió**: Accessible des de la interfície principal
- **Selector de categories**: Modal interactiu per triar quines categories imprimir
- **Format A3 apaïsat**: Disseny optimitzat per a paper A3 en orientació horitzontal
- **Multi-pàgina**: Cada categoria s'imprimeix en una pàgina independent
- **Capçalera**: Inclou nom de l'event, categoria, distància i data d'impressió
- **Llegenda**: Explicació clara de les abreviatures (C, E, P, M)
- **Optimització**: Font compacta (7pt), noms rotats 45°, marges d'1cm

## Arquitectura Tècnica

### Components
1. **HeadToHeadGrid.svelte** (`src/lib/components/campionats-socials/`)
   - Component reutilitzable per mostrar la graella
   - Gestió d'estats de càrrega i errors
   - Responsive design amb scroll horizontal
   - Format de noms: Inicial + primer cognom

2. **HeadToHeadPrintable.svelte** (`src/lib/components/campionats-socials/`)
   - Component específic per a impressió
   - Layout optimitzat per A3 apaïsat
   - Càrrega dinàmica de categories seleccionades
   - Page breaks automàtics entre categories
   - Estils @media print per a configuració d'impressió

3. **Pàgina d'administració** (`src/routes/admin/graella-resultats/+page.svelte`)
   - Selecció de campionat i categoria
   - Integració amb el component de visualització
   - Modal de selecció de categories per imprimir
   - Botó d'impressió amb preparació de dades
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

### Impressió (Pas a Pas)

1. **Obrir el modal d'impressió**
   - Clicar el botó morat "Imprimir (A3)" a la part superior dreta

2. **Seleccionar categories**
   - Marcar les caselles de les categories que vols imprimir
   - Opcions: "Seleccionar Totes" o "Deseleccionar Totes"
   - Veure recompte de categories seleccionades a la part inferior

3. **Preparar i imprimir**
   - Clicar "Imprimir" (el sistema carregarà les dades)
   - S'obrirà automàticament el diàleg d'impressió del navegador

4. **Configurar impressió**
   - Format: **A3**
   - Orientació: **Apaïsat** (Landscape)
   - Marges: Mínims (1cm recomanat)
   - Verificar previsualització

5. **Imprimir**
   - Confirmar i enviar a impressora
   - Cada categoria sortirà en una pàgina independent

### Llegenda
- **C**: Caramboles
- **E**: Entrades
- **P**: Punts (2=victòria, 1=empat, 0=derrota)
- **M**: Mitjana (caramboles/entrades amb 3 decimals)
- **Format noms**: J. Pérez (inicial + primer cognom)

## Migració de Base de Dades

La funció SQL es troba a:
- `supabase/migrations/20251022_add_head_to_head_function.sql`
- `supabase/sql/rpc_get_head_to_head_results.sql` (còpia de referència)

Per aplicar-la:
```bash
npx supabase db push
```

## Estil Visual

### Pantalla
- **Capçaleres**: Fons fosc (#34495e) amb text blanc
- **Noms de jugadors**: Rotats 45° per estalviar espai, format curt (J. Pérez)
- **Cel·les d'enfrontament**: Graella 3x3 amb dades estructurades
- **Punts destacats**: Color verd per emfatitzar els punts
- **Responsive**: Adaptació automàtica a mòbils i tablets
- **Tooltips**: Nom complet al passar el ratolí

### Impressió
- **Font**: 7pt per a dades, 9pt per a capçaleres
- **Borders**: Negre sòlid (#333) per a bona impressió
- **Capçalera**: Inclou nom de l'event, categoria i data
- **Llegenda**: Al peu de cada pàgina
- **Marges**: 1cm en tots els costats
- **Orientació**: A3 Apaïsat automàtic
- **Page breaks**: Salts de pàgina entre categories

## Futures Millores Possibles

1. Filtrar per estat de partida (només validades, també pendents, etc.)
2. ~~Export a PDF o imatge~~ ✅ **IMPLEMENTAT: Impressió A3**
3. Vista compacta/expandida
4. Ordenació de jugadors per posició en classificació
5. Destacar victòries/derrotes amb colors
6. Comparació entre categories diferents
7. Històric de confrontacions entre dos jugadors específics
8. Export directe a PDF (sense diàleg d'impressió)
9. Opció d'incloure gràfics o estadístiques addicionals
10. Personalització de l'ordre de les categories a imprimir

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
