# INSTRUCCIONS PER CARREGAR MITJANES HISTÒRIQUES AL CLOUD

## Resum de la migració
- **Total registres:** 728 mitjanes històriques
- **Socis involucrats:** 41 socis diferents
- **Període temporal:** 2003-2025 (22 anys)
- **Modalitats:** BANDA, 3 BANDES, LLIURE

## Fitxers generats

### 1. `carrega_completa_mitjanes_cloud.sql`
Fitxer SQL complet amb transacció segura que inclou:
- Eliminació de dades existents per evitar duplicats
- Inserció de totes les 728 mitjanes històriques
- Verificacions de la càrrega
- Gestió de transaccions (BEGIN/COMMIT)

### 2. `inserts_mitjanes_historiques_cloud.sql`
Fitxer amb només els INSERTs purs (sense transacció)

## Com executar al cloud

### Opció 1: Utilitzant psql (recomanada)
```bash
# Amb la variable d'entorn configurada
psql "$env:SUPABASE_DB_URL" -f "carrega_completa_mitjanes_cloud.sql"

# O directament amb la URL
psql "postgresql://postgres.qbldqtaqawnahuzlzsjs:Banyoles2026%21@aws-0-eu-central-1.pooler.supabase.com:6543/Continu3B?sslmode=require" -f "carrega_completa_mitjanes_cloud.sql"
```

### Opció 2: Copiar i enganxar al SQL Editor de Supabase
1. Obre el dashboard de Supabase
2. Ves a "SQL Editor"
3. Copia tot el contingut de `carrega_completa_mitjanes_cloud.sql`
4. Enganxa-ho i executa

### Opció 3: Per parts (si hi ha problemes de timeout)
Pots dividir el fitxer en parts més petites si hi ha problemes de timeout.

## Verificació post-càrrega
El script inclou verificacions automàtiques, però pots executar manualment:

```sql
SELECT 
    COUNT(*) as total_mitjanes,
    COUNT(DISTINCT soci_id) as socis_diferents,
    MIN(year) as any_mes_antic,
    MAX(year) as any_mes_recent
FROM mitjanes_historiques;
```

## Troubleshooting

### Si hi ha errors de connexió:
- Verifica que la contrasenya sigui correcta (Banyoles2026!)
- Comprova que la URL de connexió sigui correcta
- Assegura't que el firewall permeti la connexió

### Si hi ha errors de duplicats:
El script elimina automàticament les dades existents per aquests socis abans d'inserir les noves.

### Si hi ha timeout:
Divideix el fitxer en parts més petites o executa per lotes.

## Estadístiques esperades
Després de la càrrega hauríeu de veure:
- 728 registres totals
- 41 socis diferents
- Període: 2003-2025
- 3 modalitats diferents