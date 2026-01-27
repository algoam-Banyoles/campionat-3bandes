# RESUM: Correcció Incompareixences i Classificacions

## 🎯 Objectiu

Corregir la gestió d'incompareixences en els campionats socials perquè les classificacions es calculin correctament segons les regles establertes.

## 📋 Regles Correctes

### Quan un jugador NO es presenta:
- ❌ Punts: **0**
- ❌ Caramboles: **0**
- ⚠️ Entrades: **màxim de categoria** (50 general, 40 lliure 1a)
  - Penalització: mitjana = 0/50 = 0.000

### Quan un jugador SÍ es presenta:
- ✅ Punts: **2** (victòria)
- ✅ Caramboles: **0**
- ✅ Entrades: **0**
  - No afecta la mitjana

## 🔧 Què s'ha corregit

### Abans (INCORRECTE)
```
Jugador PRESENT: 2 punts, distància_categoria caramboles, 0 entrades
Jugador ABSENT: 0 punts, 0 caramboles, 50 entrades
```

**Problema**: El jugador present sumava caramboles artificials que afectaven les classificacions.

### Després (CORRECTE)
```
Jugador PRESENT: 2 punts, 0 caramboles, 0 entrades
Jugador ABSENT: 0 punts, 0 caramboles, max_entrades categoria
```

**Solució**: El jugador present no suma ni caramboles ni entrades, per tant la seva mitjana no canvia.

## 📊 Exemple Pràctic

### Situació Inicial
- **Jugador A**: 100 caramboles / 20 entrades = mitjana **5.000**
- **Jugador B**: 50 caramboles / 10 entrades = mitjana **5.000**

### Jugador B NO es presenta

#### Amb les regles CORRECTES:
- **Jugador A** (present): 100 caramboles / 20 entrades = mitjana **5.000** ✅ (no canvia)
- **Jugador B** (absent): 50 caramboles / 60 entrades = mitjana **0.833** ✅ (baixa molt)

#### Amb les regles INCORRECTES (abans):
- **Jugador A** (present): 125 caramboles / 20 entrades = mitjana **6.250** ❌ (puja artificialment)
- **Jugador B** (absent): 50 caramboles / 60 entrades = mitjana **0.833** ✅

## 🚀 Com Aplicar el Fix

### Pas 1: Aplicar la Migració

Ves a [Supabase Dashboard](https://supabase.com/dashboard) → **SQL Editor**

```sql
-- Copia i executa el contingut de:
supabase/migrations/20250130000007_fix_incompareixences_classificacions.sql
```

### Pas 2: Verificar

1. Registra una incompareixença de prova
2. Comprova les classificacions
3. Verifica que:
   - El jugador present manté la seva mitjana
   - El jugador absent té mitjana molt baixa
   - Els punts són correctes (2 vs 0)

## 📁 Fitxers Creats/Modificats

### Nous Fitxers
- ✅ `supabase/migrations/20250130000007_fix_incompareixences_classificacions.sql` - Migració correctora
- ✅ `FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md` - Documentació detallada
- ✅ `RESUM_FIX_INCOMPAREIXENCES.md` - Aquest fitxer

### Fitxers Actualitzats
- ✅ `INCOMPAREIXENCES_MIGRATION.md` - Afegit pas 9 amb la nova migració
- ✅ `FIX_GRAELLA_BLANK_ENTRIES.md` - Actualitzades regles d'incompareixença

## ⚠️ Notes Importants

1. **Dades existents**: Les incompareixences ja registrades NO es modifiquen automàticament
2. **Max_entrades**: Cada categoria pot tenir el seu propi valor (50 o 40)
3. **Compatibilitat**: La funció és compatible amb versions anteriors
4. **Classificacions**: La funció `get_social_league_classifications` ja gestiona correctament els casos amb 0 entrades

## 📚 Documentació Relacionada

- [FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md](FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md) - Explicació detallada
- [INCOMPAREIXENCES_MIGRATION.md](INCOMPAREIXENCES_MIGRATION.md) - Guia completa de migracions
- [FIX_GRAELLA_BLANK_ENTRIES.md](FIX_GRAELLA_BLANK_ENTRIES.md) - Context sobre entrades individuals

## ✅ Checklist d'Aplicació

- [ ] Llegir aquest resum
- [ ] Revisar [FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md](FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md)
- [ ] Aplicar migració `20250130000007_fix_incompareixences_classificacions.sql`
- [ ] Verificar amb incompareixença de prova
- [ ] Comprovar classificacions
- [ ] Confirmar que les mitjanes són correctes

## 🆘 Si hi ha Problemes

1. Revisa els logs de Supabase
2. Comprova que totes les migracions anteriors s'han aplicat
3. Verifica que la funció `get_social_league_classifications` està actualitzada
4. Consulta la documentació detallada

---

**Data**: 27 Gener 2026  
**Autor**: Sistema de migracions  
**Versió**: 1.0
