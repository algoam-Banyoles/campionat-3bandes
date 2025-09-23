# 🚧 Lligues Socials - Documentació de Desenvolupament

## 📋 Estat Actual

### ✅ COMPLETAT
- **Migració 007**: Extensions de base de dades per lligues socials
- **Estructura de rutes**: `/campionats-socials/` amb layout específic
- **Restricció d'accés**: Només `algoam@gmail.com` pot accedir
- **UI base**: Dashboard inicial amb indicadors de progrés

### 🔄 EN CURS
- Importació dades històriques Excel
- API endpoints per gestió lligues

### ⏳ PENDENT
- Algoritme generació calendari automàtic
- Interfícies inscripcions i categories
- Sistema validació junta
- Classificacions dinàmiques

## 🗂️ Estructura Fitxers Nous

```
├── supabase/migrations/
│   └── 007_lligues_socials.sql          # Migració BD principal
├── src/lib/guards/
│   └── devOnly.ts                       # Restricció accés desenvolupament
├── src/routes/campionats-socials/
│   ├── +layout.server.ts                # Guard servidor
│   ├── +layout.svelte                   # Layout amb warning dev
│   └── +page.svelte                     # Dashboard lligues socials
├── apply-migration-007.ps1              # Script aplicació migració
└── LLIGUES_SOCIALS_DEV.md              # Aquest document
```

## 🔧 Taules BD Noves

### `categories`
Categories per cada event/lliga (1a, 2a, 3a categoria)
- `event_id`, `nom`, `distancia_caramboles`, `ordre_categoria`
- 8-12 jugadors per categoria

### `inscripcions`
Inscripcions jugadors amb preferències horàries
- `player_id`, `event_id`, `preferencies_dies`, `preferencies_hores`
- Estat: pagat, confirmat

### `calendari_partides`
Calendari generat automàticament
- Partides programades amb data/hora/taula
- Estats: generat → validat → jugada
- Sistema reprogramacions

### `classificacions`
Classificació dinàmica per categoria
- Punts, partides jugades, caramboles favor/contra
- Actualització automàtica

### `configuracio_calendari`
Paràmetres generació calendari per event
- Dies setmana, hores, taules disponibles
- Límits partides per jugador

## 🚀 Com Provar

### 1. Aplicar Migració
```powershell
.\apply-migration-007.ps1
```

### 2. Iniciar Desenvolupament
```bash
npm run dev
```

### 3. Accedir com Developer
- Login amb `algoam@gmail.com`
- Veure enllaç "Lligues Socials [DEV]" al menú
- Accedir a `/campionats-socials`

### 4. Verificar Restricció
- Qualsevol altre usuari no veurà l'enllaç
- Accés directe URL donarà error 403

## 🔒 Seguretat Temporal

**IMPORTANT**: Les lligues socials estan **completament restringides** durant desenvolupament:

- **Frontend**: Només `algoam@gmail.com` veu l'enllaç
- **Backend**: Guard `ensureDevAccess()` bloqueja altres usuaris
- **BD**: Polítiques RLS només permeten lectura

## 🗄️ Schema BD Actual vs Nou

### ABANS (Ranking Continu)
```
events (nom, temporada, actiu)
  ↓
challenges → matches
  ↓
ranking_positions
```

### DESPRÉS (Multi-Competició)
```
events (+ modalitat, tipus_competicio, estats)
  ↓
├── challenges → matches (ranking continu)
├── inscripcions → categories → calendari_partides → classificacions (lligues)
└── [handicap tables] (futur)
```

## 🔄 Pròxims Passos

1. **Importació Excel** històrics
2. **API Service** `lliguesSocials.ts`
3. **Algoritme calendari** amb constraints
4. **UI inscripcions** amb preferències
5. **Dashboard admin** gestió competicions

## ⚠️ RECORDATORI

**Abans de producció:**
1. Eliminar `devOnly.ts` guard
2. Actualitzar polítiques RLS
3. Eliminar avisos de desenvolupament
4. Testing complet multi-usuari