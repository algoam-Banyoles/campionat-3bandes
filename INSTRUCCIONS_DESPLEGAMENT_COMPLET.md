# INSTRUCCIONS DE DESPLEGAMENT COMPLET
## Integració d'Exsocis i Mitjanes Històriques

**Data:** 2025-09-21  
**Objectiu:** Integrar exsocis a la base de dades amb gestió d'estat i carregar mitjanes històriques

---

## 📋 RESUM DE L'ESTRATÈGIA

### ✅ Avantatges de la nova aproximació:
- **Integritat referencial completa**: tots els soci_id de mitjanes històriques existeixen a la taula socis
- **Gestió d'estat**: diferenciació clara entre socis 'actiu' i 'baixa'  
- **Historial complet**: es conserva tota la informació dels exsocis
- **Escalabilitat**: permet donar de baixa socis actuals sense perdre l'historial
- **Numeració clara**: IDs 1-34 per exsocis, IDs 8748+ per futurs socis reals

### 🎯 Estructura implementada:
```
Taula SOCIS:
├── IDs 1-34: Exsocis (estat='baixa')
├── IDs 8748+: Socis actuals (estat='actiu')  
└── Camps nous: estat, data_baixa, observacions

Taula MITJANES_HISTORIQUES:
├── soci_id: referències vàlides a socis (1-34 per exsocis, 8748+ per actius)
├── Integritat referencial: 100% garantida
└── 1.998 registres històrics (2003-2025)
```

---

## 🚀 ORDRE D'EXECUCIÓ

### STEP 1: Preparar i integrar exsocis
```bash
# Executar a Supabase Cloud (SQL Editor o CLI)
script_cloud_integracio_exsocis.sql
```

**Què fa aquest script:**
- ✅ Crea camps `estat`, `data_baixa`, `observacions` a la taula socis
- ✅ Actualitza socis existents amb estat 'actiu'
- ✅ Insereix 34 exsocis amb IDs 1-34 i estat 'baixa'
- ✅ Crea índex per optimitzar consultes per estat
- ✅ Inclou verificacions i consultes de control

### STEP 2: Carregar mitjanes històriques actualitzades
```bash
# Executar a Supabase Cloud (SQL Editor o CLI)
script_cloud_final_complet.sql
```

**Què fa aquest script:**
- ✅ Esborra mitjanes històriques existents
- ✅ Insereix 1.998 registres amb IDs reals (1-34 per exsocis)
- ✅ Valida integritat referencial
- ✅ Proporciona consultes de verificació

---

## 📄 FITXERS GENERATS

### Scripts SQL principals:
- `script_cloud_integracio_exsocis.sql` - Integració d'exsocis a la taula socis
- `script_cloud_final_complet.sql` - Càrrega de mitjanes històriques actualitzades

### Scripts de suport:
- `esquema_socis_exsocis.sql` - Només actualització d'esquema  
- `insert_exsocis_socis_table.sql` - Només inserció d'exsocis

### Fitxers de dades:
- `mitjanes_historiques_ids_reals.txt` - Dades processades amb IDs 1-34
- `mitjanes_historiques_final.txt` - Dades originals amb IDs 00XX

---

## 🛠️ MÈTODES DE DESPLEGAMENT

### Opció 1: Supabase Dashboard (Recomanat)
1. Anar a [Supabase Dashboard](https://supabase.com/dashboard)
2. Seleccionar projecte
3. SQL Editor → New Query
4. Copiar contingut del script
5. Executar (Run)

### Opció 2: Supabase CLI
```bash
# Executar cada script
supabase db push --db-url "$env:SUPABASE_DB_URL" --file script_cloud_integracio_exsocis.sql
supabase db push --db-url "$env:SUPABASE_DB_URL" --file script_cloud_final_complet.sql
```

### Opció 3: psql directe
```bash
# Connectar i executar
psql "$env:SUPABASE_DB_URL" -f script_cloud_integracio_exsocis.sql
psql "$env:SUPABASE_DB_URL" -f script_cloud_final_complet.sql
```

---

## ✅ VERIFICACIONS POST-DESPLEGAMENT

### Després del STEP 1 (Exsocis):
```sql
-- Verificar exsocis inserits
SELECT COUNT(*) FROM socis WHERE estat = 'baixa' AND id BETWEEN 1 AND 34;
-- Resultat esperat: 34

-- Verificar socis actius
SELECT COUNT(*) FROM socis WHERE estat = 'actiu';

-- Veure resum per estat  
SELECT estat, COUNT(*) FROM socis GROUP BY estat;
```

### Després del STEP 2 (Mitjanes):
```sql
-- Verificar mitjanes carregades
SELECT COUNT(*) FROM mitjanes_historiques;
-- Resultat esperat: 1998

-- Verificar integritat referencial
SELECT COUNT(*) FROM mitjanes_historiques mh 
LEFT JOIN socis s ON mh.soci_id = s.id 
WHERE s.id IS NULL;
-- Resultat esperat: 0 (cap referència òrfena)

-- Resum per modalitat
SELECT modalitat, COUNT(*) FROM mitjanes_historiques GROUP BY modalitat;
```

---

## 🎯 GESTIÓ FUTURA DE SOCIS

### Per donar de baixa un soci actiu:
```sql
UPDATE socis 
SET estat = 'baixa', 
    data_baixa = CURRENT_DATE,
    observacions = 'Baixa voluntària' 
WHERE id = [ID_SOCI];
```

### Per reactivar un exsoci:
```sql
UPDATE socis 
SET estat = 'actiu', 
    data_baixa = NULL,
    observacions = 'Reactivat' 
WHERE id = [ID_EXSOCI];
```

### Consultar historial complet d'un soci:
```sql
SELECT 
    s.nom,
    s.estat,
    s.data_alta,
    s.data_baixa,
    COUNT(mh.id) as mitjanes_historiques
FROM socis s
LEFT JOIN mitjanes_historiques mh ON s.id = mh.soci_id
WHERE s.id = [ID_SOCI]
GROUP BY s.id, s.nom, s.estat, s.data_alta, s.data_baixa;
```

---

## 📊 ESTADÍSTIQUES FINALS

- **Exsocis integrats:** 34 (IDs 1-34)
- **Mitjanes històriques:** 1.998 registres
- **Període cobert:** 2003-2025  
- **Modalitats:** 3 BANDES, BANDA, LLIURE
- **Integritat referencial:** 100% garantida
- **IDs disponibles per nous socis:** 8748+

---

## 🆘 SOLUCIÓ DE PROBLEMES

### Error: "duplicate key value violates unique constraint"
- **Causa:** Ja existeixen dades a les taules
- **Solució:** Els scripts inclouen DELETE statements per netejar dades existents

### Error: "column does not exist"  
- **Causa:** Els camps nous no s'han creat correctament
- **Solució:** Executar primer `esquema_socis_exsocis.sql`

### Error: "foreign key constraint violation"
- **Causa:** Intent d'inserir mitjanes amb soci_id inexistent
- **Solució:** Assegurar-se que el STEP 1 s'ha executat correctament

---

**🎉 DESPLEGAMENT COMPLET LLEST PER EXECUTAR!** 

Tots els scripts estan preparats per a un desplegament segur i complet de la funcionalitat d'exsocis integrats.