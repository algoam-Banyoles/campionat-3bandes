# Campionat 3 Bandes

Sistema de gestió per al campionat continu de ranking de tres bandes, desenvolupat amb SvelteKit i Supabase.

## 🏗️ Arquitectura

- **Frontend**: SvelteKit + TypeScript + TailwindCSS
- **Backend**: Supabase (PostgreSQL + Auth + RLS)
- **Testing**: Vitest
- **Deployment**: Adapter estàtic per a GitHub Pages

## 🚀 Configuració inicial

### 1. Prerequisites
- Node.js 18+
- PostgreSQL client (psql)
- Supabase CLI

```bash
# Instal·la dependencies
npm install

# Instal·la Supabase CLI (si no la tens)
npm install -g supabase
```

### 2. Configuració de Supabase Cloud

**Opció A: Mode interactiu (recomanat)**
```powershell
.\Configure-Supabase.ps1 -Interactive -TestConnection -Persist
```

**Opció B: Mode directe**
```powershell
.\Configure-Supabase.ps1 -Password (ConvertTo-SecureString "LA_TEVA_CONTRASENYA" -AsPlainText -Force) -Persist -TestConnection
```

### 3. Sincronització de la base de dades

```powershell
# Sincronització completa (Cloud → Local)
.\Sync-Database.ps1 -Action sync -Backup

# Només descarregar esquema
.\Sync-Database.ps1 -Action pull

# Resetear base de dades local
.\Sync-Database.ps1 -Action reset
```

### 4. Inicia el desenvolupament

```bash
# Inicia Supabase local
supabase start

# Inicia servidor de desenvolupament
npm run dev
```

## 🛠️ Scripts útils

### Exploració de base de dades
```powershell
# Veure ambdues bases de dades
.\Explore-Database.ps1

# Només Cloud
.\Explore-Database.ps1 -Target cloud

# Només Local
.\Explore-Database.ps1 -Target local

# Incloure esquemes del sistema
.\Explore-Database.ps1 -IncludeSystem
```

### Gestió de dades
```powershell
# Llistar taules disponibles
.\List-SupabaseTables.ps1

# Fer backup de l'esquema
.\Dump-SupabaseSchema.ps1 -OutputPath "backup.sql"
```

## 🧪 Testing

```bash
# Executar tots els tests
npm test

# Tests en mode watch
npm run test:watch

# Verificar TypeScript
npm run check
```

## 🏗️ Build i Deploy

```bash
# Build de producció
npm run build

# Preview local
npm run preview
```

## 📁 Estructura del projecte

```
├── src/
│   ├── lib/
│   │   ├── components/     # Components Svelte reutilitzables
│   │   ├── server/         # Codi server-side
│   │   ├── stores/         # Stores de Svelte
│   │   └── utils/          # Utilitats compartides
│   ├── routes/             # Rutes de l'aplicació
│   └── app.html            # Template HTML principal
├── supabase/
│   ├── migrations/         # Migracions de BD
│   ├── sql/                # Scripts SQL personalitzats
│   └── config.toml         # Configuració Supabase
├── tests/                  # Tests unitaris
└── static/                 # Recursos estàtics
```

## 🔧 Variables d'entorn

El projecte utilitza aquestes variables:

- `PUBLIC_SUPABASE_URL`: URL de Supabase
- `PUBLIC_SUPABASE_ANON_KEY`: Clau anònima de Supabase
- `SUPABASE_DB_URL`: URL de connexió directa a PostgreSQL

## 🔒 Seguretat

- Row Level Security (RLS) activat a totes les taules
- Autenticació basada en JWT
- Permisos granulars per rol (administrador/jugador)

## 📝 Scripts de desenvolupament

| Script | Descripció |
|--------|------------|
| `npm run dev` | Servidor de desenvolupament |
| `npm run build` | Build de producció |
| `npm test` | Executar tests |
| `npm run check` | Verificar TypeScript |
| `supabase start` | Iniciar Supabase local |
| `supabase stop` | Aturar Supabase local |

## 🤝 Workflow de desenvolupament

1. **Configura** la connexió amb `.\Configure-Supabase.ps1`
2. **Sincronitza** amb `.\Sync-Database.ps1 -Action sync`
3. **Desenvolupa** amb `npm run dev`
4. **Testa** amb `npm test`
5. **Publica** canvis a Cloud si cal

## 🆘 Resolució de problemes

### Error de connexió a Supabase
```powershell
# Verifica la configuració
.\Configure-Supabase.ps1 -Interactive -TestConnection

# Explora l'estat de les bases de dades
.\Explore-Database.ps1 -Verbose
```

### Problemes de migració
```powershell
# Reset complet
.\Sync-Database.ps1 -Action reset -Force

# Backup abans de canvis importants
.\Sync-Database.ps1 -Action sync -Backup
```

### Build errors
```bash
# Neteja i reinstal·la dependencies
rm -rf node_modules package-lock.json
npm install

# Verifica TypeScript
npm run check
```
