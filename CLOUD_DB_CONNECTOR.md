# 🎯 Cloud Database Connector

**Una eina universal per connectar-se fàcilment a la base de dades cloud de Supabase**

## 🚀 Ús Ràpid

```bash
# Provar connexió
node cloud-db-connector.cjs --test-connection

# Llistar totes les taules
node cloud-db-connector.cjs --list-tables

# Veure dades d'una taula específica
node cloud-db-connector.cjs --table socis

# Executar una consulta personalitzada
node cloud-db-connector.cjs --query "SELECT nom, email FROM socis LIMIT 5"
```

## 📋 Comandes Disponibles

| Comanda | Descripció | Exemple |
|---------|------------|---------|
| `--test-connection` | Prova la connexió a la base de dades | `node cloud-db-connector.cjs --test-connection` |
| `--list-tables` | Mostra totes les taules i vistes disponibles | `node cloud-db-connector.cjs --list-tables` |
| `--table <nom>` | Obté dades d'una taula específica | `node cloud-db-connector.cjs --table players` |
| `--query "<sql>"` | Executa una consulta SELECT | `node cloud-db-connector.cjs --query "SELECT * FROM events"` |
| `--schema` | Mostra l'esquema complet de la base de dades | `node cloud-db-connector.cjs --schema` |
| `--backup-schema` | Crea una còpia de seguretat de l'esquema | `node cloud-db-connector.cjs --backup-schema` |
| `--limit <número>` | Limita el nombre de files retornades | `node cloud-db-connector.cjs --table socis --limit 20` |
| `--help` | Mostra l'ajuda | `node cloud-db-connector.cjs --help` |

## 📊 Taules Principals

| Taula | Descripció | Exemple d'ús |
|-------|------------|--------------|
| `socis` | Membres del club | `--table socis` |
| `events` | Campionats/tornejos | `--table events` |
| `players` | Jugadors actius | `--table players` |
| `challenges` | Reptes de partides | `--table challenges` |
| `matches` | Partides jugades | `--table matches` |
| `ranking_positions` | Rankings actuals | `--table ranking_positions` |
| `categories` | Categories de competició | `--table categories` |

## 🎯 Exemples Pràctics

### Veure tots els socis actius
```bash
node cloud-db-connector.cjs --table socis --limit 50
```

### Comprovar els reptes pendents
```bash
node cloud-db-connector.cjs --table challenges
```

### Veure el rànquing actual
```bash
node cloud-db-connector.cjs --table ranking_positions
```

### Crear còpia de seguretat de l'esquema
```bash
node cloud-db-connector.cjs --backup-schema
```

### Consulta personalitzada per veure jugadors amb mitjana alta
```bash
node cloud-db-connector.cjs --query "SELECT nom, mitjana FROM players WHERE mitjana > 1.0 LIMIT 10"
```

## ⚙️ Configuració

Les variables d'entorn necessàries ja estan configurades en aquest workspace:

- `PUBLIC_SUPABASE_URL` - URL del projecte Supabase
- `SUPABASE_SERVICE_ROLE_KEY` - Clau de servei per accés complet

## 🛡️ Seguretat

- **Només lectura**: Totes les operacions són de només lectura per seguretat
- **Límits de files**: Límit per defecte de 10 files (personalitzable amb --limit)
- **Validació automàtica**: Validació de connexió abans de cada operació

## 🤖 Per a IAs

Aquesta eina està dissenyada perquè qualsevol IA pugui utilitzar-la fàcilment:

1. **Sintaxi simple**: Comandes clares i consistents
2. **Sortida estructurada**: JSON formatat per fàcil parsing
3. **Gestió d'errors**: Missatges clars d'error i còdis d'exit
4. **Documentació inclosa**: --help sempre disponible
5. **Límits de seguretat**: Prevents accidental data exposure

### Exemples per a IAs:

```bash
# Comprovar si la base de dades està accessible
node cloud-db-connector.cjs --test-connection

# Explorar l'estructura disponible
node cloud-db-connector.cjs --list-tables

# Investigar dades específiques
node cloud-db-connector.cjs --table socis --limit 5

# Crear backup per anàlisi offline
node cloud-db-connector.cjs --backup-schema
```

## 📝 Notes

- Ideal per debugging, anàlisi de dades i verificació d'esquema
- Compatible amb qualsevol eina que pugui executar Node.js
- Output en format JSON per fàcil integració
- Suport per pipes i redireccions del shell

## 🔗 Fitxers Relacionats

- `cloud-db-connector.cjs` - L'eina principal
- `validate_cloud_schema.cjs` - Validador d'esquema
- `generate_migration.cjs` - Generador de migracions
- `supabase/migrations/20250928102000_clean_cloud_sync.sql` - Última migració completa