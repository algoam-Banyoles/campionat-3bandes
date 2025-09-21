# INSTRUCCIONS FINALS PER A LA CÀRREGA AL CLOUD

## RESUM DEL PROCESSAMENT
✅ **COMPLETAT**: Assignació de números de soci per jugadors no identificats

### FITXERS GENERATS:

1. **mitjanes_historiques_final.txt**
   - Fitxer processat amb tots els "Nosoci" substituïts
   - 1,998 registres de mitjanes històriques (2003-2025)
   - Tots els exsocis tenen assignats números 00XX

2. **script_cloud_mitjanes_historiques.sql**
   - Script SQL complet per carregar al cloud
   - 1,998 INSERT statements
   - Transacció segura amb BEGIN/COMMIT
   - Eliminació prèvia de dades per evitar duplicats

3. **llista_exsocis_actualitzada.txt**
   - Documentació completa dels 34 exsocis identificats
   - Números assignats: 0001-0034
   - Períodes d'activitat de cada exsoci

4. **assignacio_nous_socis.txt**
   - Mapping detallat de les assignacions
   - Format: NomJugador -> NumeroSoci

### ASSIGNACIONS D'EXSOCIS (00XX):
- **0001**: A. ALUJA
- **0002**: A. FERNÁNDEZ  
- **0003**: A. MARTÍ
- **0004**: ALBARRACIN
- **0005**: ALCARAZ
- **0006**: BARRIENTOS
- **0007**: BARRIERE
- **0008**: C. GIRÓ
- **0009**: CASBAS
- **0010**: DOMÉNECH
- **0011**: DONADEU
- **0012**: DURAN
- **0013**: E. GIRÓ
- **0014**: E. LLORENTE
- **0015**: ERRA
- **0016**: J. LAHOZ
- **0017**: J. ROVIROSA
- **0018**: JUAN  GÓMEZ
- **0019**: M. ALMIRALL
- **0020**: M. PALAU
- **0021**: M. PRAT
- **0022**: MAGRIÑA
- **0023**: P. RUIZ
- **0024**: PEÑA
- **0025**: PUIG
- **0026**: REAL
- **0027**: RODRÍGUEZ
- **0028**: S. BASCÓN
- **0029**: SOLANES
- **0030**: SOLANS
- **0031**: SUÑE
- **0032**: TABERNER
- **0033**: TALAVERA
- **0034**: VIVAS

## INSTRUCCIONS PER CARREGAR AL CLOUD:

### OPCIÓ 1: SQL Editor de Supabase Dashboard
1. Anar a https://supabase.com/dashboard
2. Seleccionar el vostre projecte
3. Anar a "SQL Editor"
4. Copiar i enganxar el contingut de `script_cloud_mitjanes_historiques.sql`
5. Executar l'script

### OPCIÓ 2: CLI de Supabase
```bash
supabase db push --db-url "YOUR_SUPABASE_DB_URL"
```

### OPCIÓ 3: psql directe
```bash
psql "YOUR_SUPABASE_DB_URL" -f script_cloud_mitjanes_historiques.sql
```

## VERIFICACIONS POST-CÀRREGA:

L'script inclou una query de verificació que mostrarà:
- Total de registres carregats
- Rang d'anys (2003-2025)
- Número de modalitats (3: "3 BANDES", "BANDA", "LLIURE")
- Número de socis diferents (inclou 00XX per exsocis)

## NOTES IMPORTANTS:

🔴 **NÚMEROS RESERVATS**: 
- Els números 0001-0099 estan reservats per exsocis
- Els nous socis reals començaran des del següent número lliure (8748+)

🟢 **BENEFICIS DEL SISTEMA 00XX**:
- Evita conflictes amb nous socis futurs
- Facilita la identificació d'exsocis en consultes
- Manté la coherència històrica de les dades

🔵 **ESTADÍSTIQUES**:
- Total registres processats: 1,998
- Exsocis identificats: 34 jugadors únics
- Aparicions d'exsocis: 143 registres
- Període cobert: 2003-2025 (23 anys)

## CONTACTE:
Si hi ha algun problema amb la càrrega, contacteu amb l'administrador del sistema.