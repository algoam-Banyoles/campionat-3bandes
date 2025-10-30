# 🔌 Connexió a Supabase Cloud - Guia Única

Aquesta guia explica com configurar i utilitzar la connexió a la base de dades de Supabase Cloud.

## 📋 Prerequisits

### 1. Instal·lar PostgreSQL Client Tools

**Windows:**
```powershell
# Opció 1: Amb Chocolatey
choco install postgresql --params '/Password:postgres'

# Opció 2: Descarregar de postgresql.org
# https://www.postgresql.org/download/windows/
# Assegura't d'afegir PostgreSQL\bin al PATH
```

**Verificar instal·lació:**
```powershell
psql --version
# Hauria de mostrar: psql (PostgreSQL) 15.x o superior
```

---

## 🔑 Configuració de Variables d'Entorn

### 1. Obtenir les credencials de Supabase

Ves al Dashboard de Supabase:
1. https://supabase.com/dashboard
2. Selecciona el teu projecte: **campionat-3bandes**
3. Ves a **Settings** → **Database**

### 2. Copiar les credencials necessàries

**A. Connection String (Direct connection - Session mode):**
```
postgresql://postgres.xxxxx:[YOUR-PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
```

**B. Connection Pooling String (Transaction mode - RECOMANAT per scripts):**
```
postgresql://postgres.xxxxx:[YOUR-PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres
```

**C. API Keys:**
- **URL:** `https://xxxxx.supabase.co`
- **anon/public key:** (comença per `eyJ...`)
- **service_role key:** (comença per `eyJ...`, només per backend)

### 3. Crear fitxer `.env`

Crea o edita el fitxer `.env` a l'arrel del projecte:

```bash
# ============================================
# SUPABASE CLOUD CONNECTION
# ============================================

# 1. API Configuration (per l'aplicació web)
PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Duplicats per compatibilitat amb versions anteriors
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# 2. Service Role Key (per operacions d'administració)
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# 3. Database Direct Connection (per psql, migracions, scripts)
# IMPORTANT: Utilitza el pooler amb port 6543 per scripts
SUPABASE_DB_URL=postgresql://postgres.xxxxx:[YOUR-PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres

# ============================================
# VAPID KEYS (per notificacions push)
# ============================================
# Genera amb: npx web-push generate-vapid-keys
VITE_PUBLIC_VAPID_KEY=your-public-vapid-key
VAPID_PRIVATE_KEY=your-private-vapid-key
```

**⚠️ IMPORTANT:**
- ❌ **NO** pujar el fitxer `.env` a Git (ja està al `.gitignore`)
- ✅ Utilitzar el **port 6543** (Transaction pooler) per scripts i migracions
- ✅ Utilitzar el **port 5432** només per connexions interactives llargues

---

## 🚀 Utilitzar la Connexió

### 1. Connectar amb psql (Terminal interactiu)

```powershell
# Carregar variables d'entorn
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim().Trim('"').Trim("'")
        Set-Item -Path "env:$name" -Value $value
    }
}

# Connectar a la base de dades
psql $env:SUPABASE_DB_URL
```

### 2. Executar un fitxer SQL

```powershell
# Opció A: Amb pipe
Get-Content "supabase/sql/fix_security_warnings.sql" -Raw | psql $env:SUPABASE_DB_URL

# Opció B: Amb -f
psql $env:SUPABASE_DB_URL -f "supabase/sql/fix_security_warnings.sql"

# Opció C: Amb redireccions (bash/unix style)
psql $env:SUPABASE_DB_URL < supabase/sql/fix_security_warnings.sql
```

### 3. Executar una query directa

```powershell
psql $env:SUPABASE_DB_URL -c "SELECT * FROM socis LIMIT 5;"
```

### 4. Utilitzar scripts PowerShell existents

Tots els scripts ja estan preparats per utilitzar `$env:SUPABASE_DB_URL`:

```powershell
# Aplicar correccions de seguretat
.\Apply-SecurityFixes.ps1

# Explorar la base de dades
.\Explore-Database.ps1

# Llistar taules
.\List-SupabaseTables.ps1
```

---

## 🔍 Verificar la Connexió

Crea i executa aquest script per verificar:

```powershell
# Test-SupabaseConnection.ps1

# Carregar .env
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim().Trim('"').Trim("'")
        Set-Item -Path "env:$name" -Value $value
    }
}

Write-Host "`n🔍 VERIFICANT CONNEXIÓ A SUPABASE" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# 1. Verificar que la variable està definida
if (-not $env:SUPABASE_DB_URL) {
    Write-Host "❌ SUPABASE_DB_URL no està definida" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Variable SUPABASE_DB_URL trobada" -ForegroundColor Green

# 2. Test de connexió
Write-Host "`n🔌 Provant connexió..." -ForegroundColor Yellow

$result = psql $env:SUPABASE_DB_URL -c "SELECT version();" -t 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Connexió exitosa!" -ForegroundColor Green
    Write-Host "`n📊 Versió de PostgreSQL:" -ForegroundColor Cyan
    Write-Host $result -ForegroundColor White
    
    # 3. Comptar taules
    $tableCount = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" -t 2>$null
    Write-Host "`n📋 Taules a l'schema public: $($tableCount.Trim())" -ForegroundColor Cyan
    
    Write-Host "`n✅ CONNEXIÓ VERIFICADA CORRECTAMENT`n" -ForegroundColor Green
} else {
    Write-Host "❌ Error de connexió" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    exit 1
}
```

Executa-ho:
```powershell
.\Test-SupabaseConnection.ps1
```

---

## 🛠️ Troubleshooting

### Error: "psql: command not found"

**Solució:**
```powershell
# Afegir PostgreSQL al PATH
$pgPath = "C:\Program Files\PostgreSQL\15\bin"
$env:PATH = "$pgPath;$env:PATH"

# Per fer-ho permanent (com a administrador):
[Environment]::SetEnvironmentVariable("PATH", "$pgPath;$env:PATH", "Machine")
```

### Error: "connection refused" o "timeout"

**Causes possibles:**
1. ❌ Password incorrecte al connection string
2. ❌ Firewall bloquejant els ports 5432 o 6543
3. ❌ IP no autoritzada (comprova Supabase Dashboard → Settings → Database → Connection Pooling)

**Solució:**
- Verifica que la teva IP està a la whitelist
- Ves a: Dashboard → Settings → Database → Add your IP

### Error: "SSL connection required"

**Solució:** Afegeix `?sslmode=require` al final de la connexió:
```bash
SUPABASE_DB_URL=postgresql://postgres.xxxxx:[PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?sslmode=require
```

### Error: "too many connections"

**Solució:** Estàs utilitzant el port incorrecte.
- ✅ **Utilitza port 6543** (Transaction pooler)
- ❌ No utilitzis port 5432 per scripts (Direct connection, límit de connexions)

---

## 📚 Referències

- **Supabase Database Docs:** https://supabase.com/docs/guides/database
- **psql Documentation:** https://www.postgresql.org/docs/current/app-psql.html
- **Connection Pooling:** https://supabase.com/docs/guides/database/connecting-to-postgres#connection-pooler

---

## 🔐 Seguretat

### ✅ Bones Pràctiques

1. **Mai compartir el fitxer `.env`**
2. **Utilitzar variables d'entorn** en producció (Vercel, GitHub Actions)
3. **Rotar les claus** periòdicament
4. **Utilitzar IP whitelisting** quan sigui possible
5. **Service Role Key** només al backend, mai al frontend

### 🔄 Rotar Password de la Base de Dades

Si necessites canviar el password:

1. Ves a Dashboard → Settings → Database
2. Clica "Reset database password"
3. Copia el nou password
4. Actualitza el `.env` amb el nou connection string

---

**Data de creació:** 30 d'octubre de 2025  
**Última actualització:** 30 d'octubre de 2025
