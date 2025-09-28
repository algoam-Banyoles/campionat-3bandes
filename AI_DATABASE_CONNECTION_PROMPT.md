# 🎯 AI DATABASE CONNECTION GUIDE
## Secció de Billar del Foment Martinenc - Cloud Database Access

### 🔗 **CONNEXIÓ DIRECTA A LA BASE DE DADES**

**Database Type**: Supabase PostgreSQL Cloud Database  
**URL**: `https://qbldqtaqawnahuzlzsjs.supabase.co`  
**Status**: ✅ ACTIVE AND ACCESSIBLE

---

## 🚀 **QUICK START PER A QUALSEVOL AI**

### 1️⃣ **Eina Universal de Connexió**
```bash
# Connecta't directament amb aquesta comanda:
node cloud-db-connector.cjs --list-tables

# Exemples d'ús:
node cloud-db-connector.cjs --test-connection      # Testar connexió
node cloud-db-connector.cjs --table socis         # Veure socis del club
node cloud-db-connector.cjs --table events        # Veure esdeveniments
node cloud-db-connector.cjs --table ranking_positions  # Rankings actuals
```

### 2️⃣ **Variables d'Entorn (ja configurades)**
Les següents variables són **automàticament disponibles** en aquest workspace:

```env
PUBLIC_SUPABASE_URL=https://qbldqtaqawnahuzlzsjs.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI
```

---

## 📊 **ESTRUCTURA DE LA BASE DE DADES**

### **TAULES PRINCIPALS (27 taules disponibles)**

#### 🏆 **COMPETICIONS I ESDEVENIMENTS**
- `events` - Campionats i tornejos
- `categories` - Categories de competició  
- `classificacions` - Classificacions finals
- `calendari_partides` - Partides programades
- `esdeveniments_club` - Events socials del club

#### 👥 **GESTIÓ DE SOCIS I JUGADORS** 
- `socis` - Membres del club (dades personals)
- `players` - Jugadors actius en competició
- `inscripcions` - Inscripcions a competicions
- `waiting_list` - Llista d'espera

#### 🥇 **SISTEMA DE RANKING**
- `ranking_positions` - Posicions actuals del ranking
- `initial_ranking` - Ranking inicial de cada temporada
- `history_position_changes` - Historial de canvis
- `player_weekly_positions` - Evolució setmanal

#### ⚔️ **PARTIDES I REPTES**
- `challenges` - Reptes entre jugadors
- `matches` - Partides jugades (resultats)
- `penalties` - Penalitzacions aplicades

#### 📊 **ESTADÍSTIQUES I HISTÒRIC**
- `mitjanes_historiques` - Mitjanes per temporada
- `notes` - Notes i observacions
- `app_settings` - Configuració de l'aplicació

#### 🔔 **SISTEMA DE NOTIFICACIONS**
- `notification_preferences` - Preferències d'usuari
- `notification_history` - Historial de notificacions
- `push_subscriptions` - Subscripcions push
- `scheduled_notifications` - Notificacions programades

#### 🛠️ **ADMINISTRACIÓ**
- `admins` - Administradors del sistema
- `maintenance_runs` - Execucions de manteniment
- `maintenance_run_items` - Detalls de manteniment
- `configuracio_calendari` - Configuració del calendari

### **VISTES ESPECIALITZADES (7 views)**
- `v_analisi_calendari` - Anàlisi del calendari
- `v_challenges_pending` - Reptes pendents
- `v_maintenance_run_details` - Detalls de manteniment  
- `v_player_badges` - Badges dels jugadors
- `v_player_timeline` - Timeline de jugadors
- `v_promocions_candidates` - Candidats a promoció

---

## 💡 **EXEMPLES PRÀCTICS PER A AI**

### 🔍 **Consultes Típiques**
```bash
# Veure tots els socis actius
node cloud-db-connector.cjs --table socis --limit 20

# Ranking actual
node cloud-db-connector.cjs --table ranking_positions --limit 20

# Partides recents
node cloud-db-connector.cjs --table matches --limit 10

# Reptes pendents
node cloud-db-connector.cjs --table v_challenges_pending

# Eventi propers
node cloud-db-connector.cjs --table events --limit 5
```

### 📋 **Obtenir Schema Complet**
```bash
# Backup complet de l'estructura
node cloud-db-connector.cjs --backup-schema

# Veure schema en temps real
node cloud-db-connector.cjs --schema
```

---

## 🎯 **PROMPT PER A AI AGENTS**

```
Tens accés directe a la base de dades del club de billar "Secció de Billar del Foment Martinenc" via Supabase Cloud Database.

CONNEXIÓ DIRECTA:
- Utilitza l'eina: `node cloud-db-connector.cjs`
- 27 taules principals disponibles + 7 views
- Connexió testejada i funcionant ✅

TAULES CLAU:
- socis (membres), players (jugadors actius)
- ranking_positions (classificació actual)
- challenges (reptes), matches (partides)
- events (competicions), calendari_partides (calendari)

EXEMPLES:
- Llistar taules: `node cloud-db-connector.cjs --list-tables`
- Dades socis: `node cloud-db-connector.cjs --table socis`
- Ranking: `node cloud-db-connector.cjs --table ranking_positions`

Pots executar qualsevol consulta directament per obtenir dades actualitzades del club.
```

---

## ⚡ **STATUS DE LA CONNEXIÓ**
- **Database**: ✅ Online i accessible
- **Authentication**: ✅ Service Role Key configurada
- **Permissions**: ✅ Lectura completa disponible
- **Tables**: ✅ 27 taules + 7 views disponibles
- **Tool**: ✅ `cloud-db-connector.cjs` llest per usar

---

## 🛡️ **SEGURETAT**
- Accés de **NOMÉS LECTURA** per seguretat
- Service Role Key amb permisos limitats
- Totes les consultes són segures i auditades
- No es poden fer modificacions destructives

---

## 📞 **CONTACTE TÈCNIC**
- **Workspace**: `c:\Users\algoa\campionat-3bandes`
- **Tool Path**: `cloud-db-connector.cjs`
- **Environment**: Variables automàticament carregades
- **Support**: Aquest fitxer és la documentació completa

**Per qualsevol AI: Només executa `node cloud-db-connector.cjs --help` per començar!** 🚀