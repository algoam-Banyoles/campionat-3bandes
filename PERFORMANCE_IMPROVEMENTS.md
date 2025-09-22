# 🚀 Guia d'Aplicació de Millores de Rendiment

Aquest document conté les instruccions per aplicar les optimitzacions de rendiment recomanades per l'auditoria de seguretat i rendiment.

## 📋 Resum de Millores Aplicades

### ✅ Ja Implementades (Automàticament)
- **Consultes SELECT optimitzades:** Especificació de columnes concretes en lloc de `SELECT *`
  - `src/lib/playerBadges.ts` - Optimitzat
  - `src/lib/server/daoAdmin.ts` - Optimitzat  
  - `src/lib/settings.ts` - Optimitzat
- **Paginació server-side:** Implementada a mitjanes històriques per evitar càrregues de >1000 registres

### ⚠️ Pendents d'Aplicar (Requereix acció manual)

## 🔧 Pas 1: Aplicar Índexs a la Base de Dades

### Opció A: Script Automàtic (Recomanat)
```bash
# Des de l'arrel del projecte
./scripts/apply-performance-optimizations.sh
```

### Opció B: Manual via Supabase Dashboard (Recomanat)
1. Ves a [Supabase Dashboard](https://app.supabase.com) > El teu projecte > SQL Editor
2. Copia i executa el contingut de `scripts/apply-indexes-corrected.sql`
3. Verifica que s'executin sense errors
4. Aquest script utilitza els noms correctes de columnes i evita índexs duplicats

### Opció C: Via Supabase CLI
```bash
# Aplicar migration amb els índexs
supabase db push
supabase db sql < scripts/apply-indexes-manual.sql
```

## 📊 Pas 2: Configurar Automatitzacions

### Edge Function per Penalitzacions Automàtiques
Ja implementada a `supabase/functions/aplica-penalitzacions.ts`

**Configurar execució programada:**
1. Supabase Dashboard > Functions > aplica-penalitzacions  
2. Afegir trigger tipus "Scheduled" 
3. Configurar cron: `0 2 * * *` (cada dia a les 2:00)
4. Variables d'entorn: `API_KEY` (opcional)

### Edge Functions per Inactivitat (Opcional)
Crear functions similars per:
- `apply_pre_inactivity` (setmanalment)  
- `apply_inactivity` (setmanalment)

## 🔍 Pas 3: Verificar Millores

### Verificar Índexs Aplicats
```sql
-- Executar a Supabase SQL Editor
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes 
WHERE tablename IN ('challenges', 'ranking_positions', 'mitjanes_historiques')
    AND indexname LIKE 'idx_%'
ORDER BY tablename;
```

### Monitoritzar Rendiment
1. Supabase Dashboard > Reports > Performance
2. Revisar temps de resposta de queries
3. Identificar queries lentes (>100ms)

## 📈 Beneficis Esperats

### Millores de Rendiment
- **Consultes de reptes:** 60-80% més ràpides
- **Càrrega de ranking:** 50-70% més ràpida  
- **Mitjanes històriques:** Paginació evita timeouts
- **Cerques per jugador:** 70-90% més ràpides

### Optimització de Recursos
- Menor ús de CPU a Supabase
- Reducció de transferència de dades
- Millor experiència d'usuari (UI més responsiva)

## 🚨 Troubleshooting

### Error: "permission denied for relation"
**Solució:** Assegurar-se que l'usuari té permisos d'administrador a Supabase.

### Error: "index already exists"
**Solució:** Normal, els índexs usen `IF NOT EXISTS`. Ignorar aquest error.

### Error: "relation does not exist"
**Solució:** Verificar que les migracions estan aplicades correctament.

### Script no executa
```bash
# Fer executable
chmod +x scripts/apply-performance-optimizations.sh

# Verificar permisos
ls -la scripts/
```

## 📞 Suport

Si tens problemes aplicant les millores:
1. Verifica que Supabase CLI està instal·lat: `supabase --version`
2. Comprova connexió: `supabase status`  
3. Executa manualment via Dashboard com a fallback
4. Consulta logs de Supabase per errors específics

## 🎯 Pròxims Passos Recomanats

1. **Aplicar índexs** (prioritat alta)
2. **Configurar automatitzacions** (prioritat mitjana)
3. **Monitoritzar rendiment** contínuament
4. **Optimitzar més consultes** segons necessitat
5. **Configurar alertes** per queries lentes