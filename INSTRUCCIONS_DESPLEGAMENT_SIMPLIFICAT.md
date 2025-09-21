# INSTRUCCIONS DE DESPLEGAMENT - INTEGRACIÓ EXSOCIS
## Gestió de Baixes amb l'Estructura Real de la Taula Socis

**Data:** 2025-09-21  
**Objectiu:** Integrar exsocis utilitzant l'estructura real de la taula socis

---

## 📋 ESTRUCTURA REAL DE LA TAULA SOCIS

```sql
-- Taula socis actual:
-- numero_soci (integer) - Clau primària
-- cognoms (text)
-- nom (text) 
-- email (text)
```

## 🔧 CAMPS QUE S'AFEGIRAN

```sql
-- Camps nous que s'afegiran:
-- de_baixa (boolean) - FALSE = actiu, TRUE = de baixa
-- data_baixa (date) - Data quan es va donar de baixa (NULL si actiu)
```

---

## 🚀 ORDRE D'EXECUCIÓ

### STEP 1: Integrar exsocis i afegir camps de gestió de baixes
```bash
# Executar a Supabase Cloud
script_cloud_integracio_exsocis.sql
```

**Què fa aquest script:**
- ✅ Afegeix camp `de_baixa` (boolean, default FALSE)
- ✅ Afegeix camp `data_baixa` (date, NULL per defecte)
- ✅ Insereix 34 exsocis amb numero_soci 1-34
- ✅ Marca tots els exsocis amb `de_baixa = TRUE`
- ✅ Crea índex per optimitzar consultes

### STEP 2: Carregar mitjanes històriques
```bash
# Executar a Supabase Cloud
script_cloud_final_complet.sql
```

**Què fa aquest script:**
- ✅ Carrega 1.998 registres històrics
- ✅ Utilitza numero_soci 1-34 per exsocis
- ✅ Valida integritat referencial amb socis.numero_soci

---

## 💡 GESTIÓ FUTURA DE SOCIS

### Donar de baixa un soci actiu:
```sql
UPDATE socis 
SET de_baixa = TRUE, 
    data_baixa = CURRENT_DATE 
WHERE numero_soci = [NUMERO_SOCI];
```

### Reactivar un exsoci:
```sql
UPDATE socis 
SET de_baixa = FALSE, 
    data_baixa = NULL 
WHERE numero_soci = [NUMERO_SOCI];
```

### Consultar socis actius:
```sql
SELECT * FROM socis 
WHERE de_baixa = FALSE OR de_baixa IS NULL;
```

### Consultar exsocis:
```sql
SELECT * FROM socis 
WHERE de_baixa = TRUE;
```

### Consultar historial complet d'un soci:
```sql
SELECT 
    s.numero_soci,
    s.nom,
    s.cognoms,
    s.email,
    s.de_baixa,
    s.data_baixa,
    COUNT(mh.id) as mitjanes_historiques
FROM socis s
LEFT JOIN mitjanes_historiques mh ON s.numero_soci = mh.soci_id
WHERE s.numero_soci = [NUMERO_SOCI]
GROUP BY s.numero_soci, s.nom, s.cognoms, s.email, s.de_baixa, s.data_baixa;
```

---

## ✅ VERIFICACIONS POST-DESPLEGAMENT

### Després del STEP 1:
```sql
-- Verificar exsocis inserits
SELECT COUNT(*) FROM socis WHERE de_baixa = TRUE AND numero_soci BETWEEN 1 AND 34;
-- Resultat esperat: 34

-- Veure resum per estat
SELECT de_baixa, COUNT(*) FROM socis GROUP BY de_baixa;
```

### Després del STEP 2:
```sql
-- Verificar mitjanes carregades
SELECT COUNT(*) FROM mitjanes_historiques;
-- Resultat esperat: 1998

-- Verificar integritat referencial
SELECT COUNT(*) FROM mitjanes_historiques mh 
LEFT JOIN socis s ON mh.soci_id = s.numero_soci 
WHERE s.numero_soci IS NULL;
-- Resultat esperat: 0
```

---

## 📊 AVANTATGES DE AQUESTA SOLUCIÓ

1. **Respecta l'estructura existent**: No modifica camps existents
2. **Simplicitat**: Només 2 camps nous (`de_baixa`, `data_baixa`)
3. **Integritat**: Tots els soci_id de mitjanes històriques tenen referència vàlida
4. **Escalabilitat**: Fàcil gestió de baixes i reactivacions
5. **Historial complet**: Es conserva tota la informació dels exsocis

---

## 🎯 NUMERACIÓ UTILITZADA

- **IDs 1-34**: Exsocis identificats (de_baixa = TRUE)
- **IDs 8748+**: Socis actuals i futurs (de_baixa = FALSE)

**🎉 SOLUCIÓ COMPLETA I LLESTA PER EXECUTAR!**