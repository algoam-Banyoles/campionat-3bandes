# SOLUCIÓ DEFINITIVA AL PROBLEMA DE FOREIGN KEYS
## Integració Completa d'Exsocis i Mitjanes Històriques

**Data:** 2025-09-21  
**Problema:** Error de foreign key - alguns soci_id de mitjanes històriques no existeixen a la taula socis

---

## 🎯 **PROBLEMA SOLUCIONAT**

### ❌ **Error original:**
```
ERROR: 23503: insert or update on table "mitjanes_historiques" violates foreign key constraint "fk_mitjanes_historiques_soci_id"
DETAIL: Key (soci_id)=(8186) is not present in table "socis".
```

### ✅ **Solució implementada:**
Afegir **TOTS** els socis necessaris a la taula `socis` abans de carregar les mitjanes històriques.

---

## 📊 **ANÀLISI COMPLETA REALITZADA**

- **153 IDs únics** trobats a mitjanes històriques
- **34 exsocis històrics** (IDs 1-34) - amb dades aproximades
- **48 exsocis coneguts** (IDs 263-8582) - amb noms i cognoms reals  
- **71 socis desconeguts** - amb placeholders temporals

---

## 🚀 **ORDRE D'EXECUCIÓ DEFINITIU**

### **SCRIPT 1: script_solucio_completa.sql**
```bash
# Executar PRIMER a Supabase Cloud
script_solucio_completa.sql
```

**Què fa:**
- ✅ Afegeix camps `de_baixa` i `data_baixa` a la taula socis
- ✅ Insereix 34 exsocis històrics (IDs 1-34) amb `de_baixa = TRUE`
- ✅ Insereix 48 exsocis coneguts amb noms/cognoms reals i `de_baixa = TRUE`
- ✅ Insereix 71 placeholders temporals amb `de_baixa = FALSE`
- ✅ **Total: 153 socis afegits**

### **SCRIPT 2: script_cloud_final_complet.sql**
```bash
# Executar SEGON a Supabase Cloud
script_cloud_final_complet.sql
```

**Què fa:**
- ✅ Carrega 1.998 mitjanes històriques
- ✅ Utilitza separadors decimals correctes (punt en lloc de coma)
- ✅ **Tots els soci_id tenen referència vàlida a la taula socis**

---

## ✅ **VERIFICACIONS POST-EXECUCIÓ**

### Després del Script 1:
```sql
-- Verificar socis afegits
SELECT 
    CASE 
        WHEN numero_soci BETWEEN 1 AND 34 THEN 'Exsocis històrics'
        WHEN nom NOT LIKE 'SOCI_%' AND de_baixa = TRUE THEN 'Exsocis coneguts'
        WHEN nom LIKE 'SOCI_%' THEN 'Placeholders'
        ELSE 'Socis actius'
    END as categoria,
    COUNT(*) as total
FROM socis 
GROUP BY categoria;
-- Resultat esperat: 34 + 48 + 71 = 153 socis nous
```

### Després del Script 2:
```sql
-- Verificar que no hi ha IDs orfes
SELECT COUNT(*) as ids_orfes 
FROM mitjanes_historiques mh 
LEFT JOIN socis s ON mh.soci_id = s.numero_soci 
WHERE s.numero_soci IS NULL;
-- Resultat esperat: 0 (cap ID orfe)

-- Verificar mitjanes carregades
SELECT COUNT(*) FROM mitjanes_historiques;
-- Resultat esperat: 1998
```

---

## 🎯 **AVANTATGES DE LA SOLUCIÓ**

1. **Integritat referencial completa**: Tots els soci_id tenen referència vàlida
2. **Dades reals on és possible**: 48 exsocis amb noms/cognoms reals
3. **Flexibilitat futura**: Els placeholders es poden actualitzar posteriorment
4. **Gestió de baixes**: Camp `de_baixa` per distingir socis actius/inactius
5. **Escalabilitat**: Fàcil afegir nous socis o actualitzar existents

---

## 🔄 **GESTIÓ FUTURA**

### Actualitzar un placeholder amb dades reals:
```sql
UPDATE socis 
SET nom = 'NOM_REAL', 
    cognoms = 'COGNOMS_REALS',
    de_baixa = TRUE,
    data_baixa = '2024-12-31'
WHERE numero_soci = [ID_PLACEHOLDER];
```

### Donar de baixa un soci actiu:
```sql
UPDATE socis 
SET de_baixa = TRUE, 
    data_baixa = CURRENT_DATE 
WHERE numero_soci = [ID_SOCI];
```

---

## 🎉 **SOLUCIÓ COMPLETA I LLESTA**

Els dos scripts estan preparats per solucionar definitivament el problema de foreign keys. L'execució d'aquests dos scripts en ordre garanteix:

- ✅ Cap error de foreign key constraint
- ✅ Totes les mitjanes històriques carregades correctament
- ✅ Integritat referencial completa
- ✅ Gestió adequada d'exsocis i socis actius

**Ja pots executar els scripts!** 🚀