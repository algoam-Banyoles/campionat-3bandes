# INSTRUCCIONS PER LA CÀRREGA COMPLETA DE MITJANES HISTÒRIQUES

## ⚠️ Còpia de Seguretat OBLIGATÒRIA
Abans de començar, fes una còpia de seguretat de la taula `mitjanes_historiques`:

```sql
-- Crear taula de backup
CREATE TABLE mitjanes_historiques_backup AS 
SELECT * FROM mitjanes_historiques;
```

## PASSOS PER LA CÀRREGA

### 1. Executar la migració base
```powershell
# Al terminal PowerShell del projecte:
cd C:\Users\algoa\campionat-3bandes
psql "$env:SUPABASE_DB_URL" -f "supabase/migrations/016_overwrite_mitjanes_with_mapping.sql"
```

**Important:** Això crearà les taules temporals i farà les previsualitzacions, però NO truncarà les dades encara.

### 2. Carregar el CSV
```powershell
# Carregar dades del CSV a la taula temporal:
psql "$env:SUPABASE_DB_URL" -c "\copy temp_new_mitjanes(year, modalitat, posicio, nom_jugador, mitjana) FROM 'dades/Ranquing (1) (1).csv' WITH (FORMAT csv, DELIMITER ';', HEADER true)"
```

### 3. Revisar previsualitzacions
Després d'executar els passos anteriors, revisa les consultes de previsualització que et mostren:

- **Files coincidents per jugador:** Quantes mitjanes s'assignaran a cada soci
- **Jugadors sense assignar:** Noms que no tenen match amb cap soci del mapping
- **Mostra de dades finals:** Com quedaran les dades a inserir

### 4. Executar la càrrega destructiva (OPCIONAL)
Només quan estiguis segur i tinguis la còpia de seguretat:

```sql
-- Descomenta i executa aquest bloc a la migració:
BEGIN;
TRUNCATE TABLE mitjanes_historiques;
INSERT INTO mitjanes_historiques (soci_id, year, modalitat, mitjana, created_at)
SELECT COALESCE(t.numero_soci, NULL) AS soci_id,
       m.year,
       m.modalitat,
       m.mitjana,
       NOW()
FROM temp_new_mitjanes m
LEFT JOIN temp_nom_to_soci t ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%';
COMMIT;
```

## VERIFICACIONS FINALS

### Comptar registres
```sql
SELECT COUNT(*) as total_mitjanes FROM mitjanes_historiques;
SELECT COUNT(*) as mitjanes_assignades FROM mitjanes_historiques WHERE soci_id IS NOT NULL;
SELECT COUNT(*) as mitjanes_sense_assignar FROM mitjanes_historiques WHERE soci_id IS NULL;
```

### Mostra per anys i modalitats
```sql
SELECT year, modalitat, COUNT(*) as total
FROM mitjanes_historiques 
GROUP BY year, modalitat 
ORDER BY year DESC, modalitat;
```

### Top jugadors amb més mitjanes
```sql
SELECT s.nom, s.cognoms, COUNT(*) as mitjanes_totals
FROM mitjanes_historiques mh
JOIN socis s ON mh.soci_id = s.numero_soci
GROUP BY s.numero_soci, s.nom, s.cognoms
ORDER BY mitjanes_totals DESC
LIMIT 20;
```

## ROLLBACK (si cal)
Si alguna cosa va malament:

```sql
-- Recuperar des del backup
TRUNCATE TABLE mitjanes_historiques;
INSERT INTO mitjanes_historiques SELECT * FROM mitjanes_historiques_backup;

-- Eliminar backup
DROP TABLE mitjanes_historiques_backup;
```

## MAPPING INCLÒS
El mapping inclou aquests jugadors:
- J.F. SANTOS → 7602
- J.M. CAMPOS → 8707  
- A. BERMEJO → 8542
- A. BOIX → 8077
- ... (i 37 jugadors més)

Si trobes jugadors sense assignar a les previsualitzacions, pots afegir noves entrades al `temp_nom_to_soci` abans d'executar la càrrega final.