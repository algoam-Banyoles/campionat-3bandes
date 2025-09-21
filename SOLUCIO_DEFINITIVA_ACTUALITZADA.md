# SOLUCIÓ DEFINITIVA ACTUALITZADA

## SITUACIÓ ACTUAL
- **Els socis actius ja existeixen** a la base de dades ✅
- Només necessitem afegir els **exsocis** per resoldre les claus foranes

## SCRIPTS GENERATS

### 1. script_final_simplificat.sql
**Objectiu**: Afegir només els exsocis necessaris
- ✅ 34 exsocis històrics (IDs 1-34)
- ✅ 48 exsocis coneguts (del fitxer exsocisconeguts.txt)
- ✅ Camps de_baixa i data_baixa afegits automàticament

### 2. script_cloud_final_complet.sql
**Objectiu**: Carregar les 1.998 mitjanes històriques
- ✅ Format decimal PostgreSQL (punts en lloc de comes)
- ✅ Totes les claus foranes seran vàlides després d'executar l'script 1

## ORDRE D'EXECUCIÓ

1. **Primer**: `script_final_simplificat.sql`
   - Afegeix els camps necessaris (de_baixa, data_baixa)
   - Insereix els 82 exsocis (34 històrics + 48 coneguts)

2. **Segon**: `script_cloud_final_complet.sql`
   - Carrega les 1.998 mitjanes històriques
   - Totes les referències soci_id seran vàlides

## VERIFICACIÓ
El primer script inclou consultes de verificació per confirmar:
- Nombre d'exsocis afegits correctament
- Distribució per categories (històrics, coneguts, actius)

## RESULTAT FINAL
- ✅ 0 violacions de claus foranes
- ✅ Totes les mitjanes històriques carregades
- ✅ Exsocis marcats com de_baixa = TRUE
- ✅ Socis actius preservats