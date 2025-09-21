# INSTRUCCIONS PER EXECUTAR LA CÀRREGA MANUAL

## ORDRE D'EXECUCIÓ:

### 1. **01_crear_taules_temporals.sql**
   - Executa amb pgAdmin o client SQL
   - Crea les taules temporals i omple el mapping

### 2. **Carregar CSV (PowerShell)**
   ```powershell
   cd C:\Users\algoa\campionat-3bandes
   psql "postgresql://postgres.qbldqtaqawnahuzlzjs:Banyoles2025%21@aws-0-eu-central-1.pooler.supabase.com:6543/Continu3B?sslmode=require" -c "\copy temp_new_mitjanes(year, modalitat, posicio, nom_jugador, mitjana) FROM 'dades/Ranquing (1) (1).csv' WITH (FORMAT csv, DELIMITER ';', HEADER true)"
   ```

### 3. **03_previsualitzacions.sql**
   - Revisa TOTS els resultats abans de continuar
   - Comprova que els matchings són correctes
   - Veu quins jugadors queden sense assignar

### 4. **04_crear_backup.sql**
   - IMPRESCINDIBLE fer abans de la càrrega
   - Això et permetrà recuperar si alguna cosa va malament

### 5. **05_carrega_destructiva.sql**
   - NOMÉS quan estiguis segur
   - Revisa bé abans de fer COMMIT
   - Pots fer ROLLBACK si veus que alguna cosa no està bé

### 6. **06_verificacions_finals.sql**
   - Comprova que tot ha anat bé
   - Estadístiques i top jugadors

### 7. **07_rollback_emergencia.sql** (només si cal)
   - Usa'l si necessites desfer els canvis

## NOTES IMPORTANTS:
- Executa els scripts EN ORDRE
- No saltis el backup (pas 4)
- Revisa sempre les previsualitzacions (pas 3)
- Si tens dubtes, para i consulta abans de continuar