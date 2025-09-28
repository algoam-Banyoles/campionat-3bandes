# 🎯 DATABASE TOOLS INDEX

## 📁 Fitxers Principals de Base de Dades

### 🔗 Connector Principal
- **`cloud-db-connector.cjs`** - Eina universal per connectar-se al cloud database
- **`CLOUD_DB_CONNECTOR.md`** - Documentació completa de l'eina
- **`examples-cloud-db.cjs`** - Exemples d'ús programàtic

### 📊 Migració i Esquema
- **`supabase/migrations/20250928102000_clean_cloud_sync.sql`** - Última migració completa sincronitzada amb el cloud

## 🚀 Ús Ràpid per a IAs

```bash
# Test de connexió ràpid
node cloud-db-connector.cjs --test-connection

# Veure totes les taules disponibles
node cloud-db-connector.cjs --list-tables

# Accedir a dades específiques
node cloud-db-connector.cjs --table socis --limit 10
node cloud-db-connector.cjs --table players --limit 5
node cloud-db-connector.cjs --table challenges --limit 5

# Crear backup de l'esquema
node cloud-db-connector.cjs --backup-schema

# Executar exemples complets
node examples-cloud-db.cjs
```

## 📋 Taules Més Importants

| Taula | Descripció | Comanda |
|-------|------------|---------|
| `socis` | Membres del club | `node cloud-db-connector.cjs --table socis` |
| `players` | Jugadors actius | `node cloud-db-connector.cjs --table players` |
| `events` | Campionats | `node cloud-db-connector.cjs --table events` |
| `challenges` | Reptes de partides | `node cloud-db-connector.cjs --table challenges` |
| `matches` | Partides jugades | `node cloud-db-connector.cjs --table matches` |
| `ranking_positions` | Posicions del rànquing | `node cloud-db-connector.cjs --table ranking_positions` |
| `categories` | Categories de competició | `node cloud-db-connector.cjs --table categories` |

## 🎯 Per a Qualsevol IA

Aquesta eina està dissenyada per ser **extremadament fàcil d'usar** per qualsevol IA:

1. **Una sola eina**: `cloud-db-connector.cjs` fa tot el necessari
2. **Sintaxi simple**: Comandes clares amb `--` flags
3. **Sortida JSON**: Format estructurat fàcil de parsejar
4. **Seguretat**: Només operacions de lectura
5. **Documentació inclosa**: `--help` sempre disponible
6. **Variables automàtiques**: Environment ja configurat

### Fluxe Típic per a IAs:

1. **Connectar**: `node cloud-db-connector.cjs --test-connection`
2. **Explorar**: `node cloud-db-connector.cjs --list-tables`
3. **Investigar**: `node cloud-db-connector.cjs --table <nom>`
4. **Analitzar**: Usar la sortida JSON per a decisions

## 💡 Tips per a IAs

- Usar `--limit` per controlar la quantitat de dades
- Començar sempre amb `--test-connection`
- `--list-tables` mostra l'estructura disponible
- `--backup-schema` crea snapshot per anàlisi offline
- Totes les operacions són **read-only** per seguretat

## 🔧 Manteniment

- **Actualització automàtica**: L'esquema es sincronitza amb el cloud
- **Backup automàtic**: Crear backups regulars amb `--backup-schema`
- **Validació**: Test de connexió abans de cada operació important

## 📞 Suport

Per a qualsevol dubte sobre l'ús d'aquestes eines:
```bash
node cloud-db-connector.cjs --help
```