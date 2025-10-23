# Desplegament: Actualització Estats Calendari

## Descripció
Actualitza el constraint d'estats de la taula `calendari_partides` per incloure tots els estats utilitzats a l'aplicació.

## Estats afegits
- `pendent_programar` - Partides generades però pendents de programar
- `reprogramada` - Partides que s'han reprogramat
- `jugada` - Partides ja jugades
- `cancel·lada` - Partides cancel·lades

## Estats existents mantinguts
- `generat` - Partida creada
- `validat` - Partida validada per admin
- `publicat` - Partida publicada al calendari

## Instruccions de Desplegament

### Opció 1: Via Dashboard de Supabase
1. Obre el teu projecte a https://supabase.com/dashboard
2. Ves a **SQL Editor**
3. Crea una nova query
4. Copia i enganxa el contingut de `supabase/migrations/20250124_update_calendari_estats.sql`
5. Executa la query
6. Verifica que no hi ha errors

### Opció 2: Via Supabase CLI (LOCAL)
```bash
# Des del directori arrel del projecte
supabase db push
```

### Opció 3: Via Supabase CLI (REMOT)
```bash
# Assegura't que tens enllaçat el projecte remot
supabase link --project-ref <project-ref>

# Aplica les migracions
supabase db push
```

## Verificació
Després de desplegar, verifica que:
1. El constraint `calendari_partides_estat_check` accepta els nous estats
2. Les partides amb estat `pendent_programar` es carreguen correctament al modal
3. Es pot programar una partida i canviar-li l'estat a `validat`

## Rollback
Si cal revertir els canvis:
```sql
ALTER TABLE calendari_partides DROP CONSTRAINT IF EXISTS calendari_partides_estat_check;

ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_estat_check
    CHECK (estat IN ('generat', 'validat', 'publicat'));
```

**IMPORTANT:** Això només funcionarà si no hi ha partides amb els nous estats a la base de dades.
