# Script per generar INSERT statements dels exsocis a la taula socis
# Integra els jugadors no identificats com a socis amb estat "baixa"

Write-Host "Generant INSERT statements per a la taula socis..."

# Definir els exsocis amb la seva informació
$exsocis = @(
    @{id="0001"; nom="A. ALUJA"; primera_aparicio="2011-01-01"; ultima_aparicio="2011-12-31"},
    @{id="0002"; nom="A. FERNÁNDEZ"; primera_aparicio="2024-01-01"; ultima_aparicio="2024-12-31"},
    @{id="0003"; nom="A. MARTÍ"; primera_aparicio="2005-01-01"; ultima_aparicio="2009-12-31"},
    @{id="0004"; nom="ALBARRACIN"; primera_aparicio="2007-01-01"; ultima_aparicio="2009-12-31"},
    @{id="0005"; nom="ALCARAZ"; primera_aparicio="2005-01-01"; ultima_aparicio="2008-12-31"},
    @{id="0006"; nom="BARRIENTOS"; primera_aparicio="2007-01-01"; ultima_aparicio="2009-12-31"},
    @{id="0007"; nom="BARRIERE"; primera_aparicio="2003-01-01"; ultima_aparicio="2004-12-31"},
    @{id="0008"; nom="C. GIRÓ"; primera_aparicio="2012-01-01"; ultima_aparicio="2012-12-31"},
    @{id="0009"; nom="CASBAS"; primera_aparicio="2003-01-01"; ultima_aparicio="2004-12-31"},
    @{id="0010"; nom="DOMÉNECH"; primera_aparicio="2017-01-01"; ultima_aparicio="2017-12-31"},
    @{id="0011"; nom="DONADEU"; primera_aparicio="2003-01-01"; ultima_aparicio="2003-12-31"},
    @{id="0012"; nom="DURAN"; primera_aparicio="2008-01-01"; ultima_aparicio="2009-12-31"},
    @{id="0013"; nom="E. GIRÓ"; primera_aparicio="2012-01-01"; ultima_aparicio="2012-12-31"},
    @{id="0014"; nom="E. LLORENTE"; primera_aparicio="2021-01-01"; ultima_aparicio="2021-12-31"},
    @{id="0015"; nom="ERRA"; primera_aparicio="2008-01-01"; ultima_aparicio="2008-12-31"},
    @{id="0016"; nom="J. LAHOZ"; primera_aparicio="2017-01-01"; ultima_aparicio="2017-12-31"},
    @{id="0017"; nom="J. ROVIROSA"; primera_aparicio="2009-01-01"; ultima_aparicio="2011-12-31"},
    @{id="0018"; nom="JUAN GÓMEZ"; primera_aparicio="2018-01-01"; ultima_aparicio="2018-12-31"},
    @{id="0019"; nom="M. ALMIRALL"; primera_aparicio="2009-01-01"; ultima_aparicio="2011-12-31"},
    @{id="0020"; nom="M. PALAU"; primera_aparicio="2007-01-01"; ultima_aparicio="2011-12-31"},
    @{id="0021"; nom="M. PRAT"; primera_aparicio="2009-01-01"; ultima_aparicio="2012-12-31"},
    @{id="0022"; nom="MAGRIÑA"; primera_aparicio="2003-01-01"; ultima_aparicio="2003-12-31"},
    @{id="0023"; nom="P. RUIZ"; primera_aparicio="2005-01-01"; ultima_aparicio="2023-12-31"},
    @{id="0024"; nom="PEÑA"; primera_aparicio="2005-01-01"; ultima_aparicio="2006-12-31"},
    @{id="0025"; nom="PUIG"; primera_aparicio="2003-01-01"; ultima_aparicio="2007-12-31"},
    @{id="0026"; nom="REAL"; primera_aparicio="2006-01-01"; ultima_aparicio="2007-12-31"},
    @{id="0027"; nom="RODRÍGUEZ"; primera_aparicio="2007-01-01"; ultima_aparicio="2009-12-31"},
    @{id="0028"; nom="S. BASCÓN"; primera_aparicio="2019-01-01"; ultima_aparicio="2020-12-31"},
    @{id="0029"; nom="SOLANES"; primera_aparicio="2009-01-01"; ultima_aparicio="2009-12-31"},
    @{id="0030"; nom="SOLANS"; primera_aparicio="2008-01-01"; ultima_aparicio="2008-12-31"},
    @{id="0031"; nom="SUÑE"; primera_aparicio="2007-01-01"; ultima_aparicio="2008-12-31"},
    @{id="0032"; nom="TABERNER"; primera_aparicio="2004-01-01"; ultima_aparicio="2005-12-31"},
    @{id="0033"; nom="TALAVERA"; primera_aparicio="2004-01-01"; ultima_aparicio="2004-12-31"},
    @{id="0034"; nom="VIVAS"; primera_aparicio="2003-01-01"; ultima_aparicio="2009-12-31"}
)

$sqlInserts = @()
$sqlInserts += "-- INSERT statements per afegir exsocis a la taula socis"
$sqlInserts += "-- Estat: 'baixa' indica que han estat socis però ja no ho són"
$sqlInserts += "-- Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$sqlInserts += ""

foreach ($exsoci in $exsocis) {
    $nomEscaped = $exsoci.nom.Replace("'", "''")
    
    # Generar INSERT amb tots els camps necessaris
    $sql = @"
INSERT INTO socis (
    id, 
    nom, 
    cognoms, 
    email, 
    telefon, 
    data_alta, 
    data_baixa, 
    estat, 
    observacions
) VALUES (
    $($exsoci.id), 
    '$nomEscaped', 
    NULL, 
    NULL, 
    NULL, 
    '$($exsoci.primera_aparicio)', 
    '$($exsoci.ultima_aparicio)', 
    'baixa', 
    'Exsoci identificat de mitjanes històriques. ID assignat automàticament.'
);
"@
    
    $sqlInserts += $sql
}

# Afegir comentaris finals
$sqlInserts += ""
$sqlInserts += "-- Verificar la inserció"
$sqlInserts += "SELECT COUNT(*) as exsocis_afegits FROM socis WHERE id BETWEEN 1 AND 99 AND estat = 'baixa';"
$sqlInserts += ""
$sqlInserts += "-- Consulta per veure tots els exsocis"
$sqlInserts += "SELECT id, nom, data_alta, data_baixa, estat FROM socis WHERE estat = 'baixa' ORDER BY id;"

# Guardar script
$sqlInserts | Out-File -FilePath "insert_exsocis_socis_table.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT EXSOCIS GENERAT ======"
Write-Host "Fitxer: insert_exsocis_socis_table.sql"
Write-Host "Exsocis a inserir: $($exsocis.Count)"
Write-Host "Rang IDs: 0001-0034"
Write-Host "Estat: 'baixa'"
Write-Host "=================================="

# També generar un script per modificar l'esquema si cal
$esquema = @"
-- Script per assegurar que la taula socis té els camps necessaris
-- Executar abans de inserir els exsocis

-- Verificar/crear camp 'estat' si no existeix
DO `$`$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'estat'
    ) THEN
        ALTER TABLE socis ADD COLUMN estat VARCHAR(20) DEFAULT 'actiu';
    END IF;
END `$`$;

-- Verificar/crear camp 'data_baixa' si no existeix  
DO `$`$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'data_baixa'
    ) THEN
        ALTER TABLE socis ADD COLUMN data_baixa DATE NULL;
    END IF;
END `$`$;

-- Verificar/crear camp 'observacions' si no existeix
DO `$`$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'observacions'
    ) THEN
        ALTER TABLE socis ADD COLUMN observacions TEXT NULL;
    END IF;
END `$`$;

-- Crear índex per millorar consultes per estat
CREATE INDEX IF NOT EXISTS idx_socis_estat ON socis(estat);

-- Mostrar esquema actual de la taula socis
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'socis' 
ORDER BY ordinal_position;
"@

$esquema | Out-File -FilePath "esquema_socis_exsocis.sql" -Encoding UTF8

Write-Host "Script esquema: esquema_socis_exsocis.sql"
Write-Host "=================================="