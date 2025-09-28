# 🎯 PROMPT PER A AI - CONNEXIÓ BD CLUB DE BILLAR

## ⚡ CONNEXIÓ DIRECTA DISPONIBLE

**Database**: Supabase Cloud PostgreSQL  
**Club**: Secció de Billar del Foment Martinenc  
**Status**: ✅ OPERATIVA I ACCESSIBLE

---

## 🚀 EINA UNIVERSAL D'ACCÉS

```bash
# CONNEXIÓ DIRECTA - USA AQUESTA COMANDA:
node cloud-db-connector.cjs --list-tables

# EXEMPLES PRÀCTICS:
node cloud-db-connector.cjs --table socis              # Socis del club
node cloud-db-connector.cjs --table ranking_positions  # Classificació actual  
node cloud-db-connector.cjs --table events             # Competicions
node cloud-db-connector.cjs --table matches            # Partides jugades
```

---

## 📊 DADES DISPONIBLES

### **27 TAULES PRINCIPALS**
- **socis** - Membres del club (6855, 7528, 8561...)
- **ranking_positions** - Classificació actual de jugadors
- **events** - Campionats i tornejos actius
- **matches** - Historial de partides
- **challenges** - Reptes entre jugadors
- **calendari_partides** - Partides programades
- **players** - Jugadors actius en competició
- **inscripcions** - Inscripcions a events

### **7 VIEWS ESPECIALITZADES**
- **v_challenges_pending** - Reptes pendents
- **v_player_badges** - Badges dels jugadors
- **v_promocions_candidates** - Candidats promoció

---

## 💡 PROMPT READY-TO-USE

```
CONNEXIÓ BD ACTIVA: Tens accés directe a la base de dades del club de billar via cloud-db-connector.cjs

DADES: 27 taules + 7 views amb informació completa del club
- Socis, jugadors, rankings, partides, esdeveniments
- Històric complet, estadístiques, calendaris

ÚS: node cloud-db-connector.cjs --table [nom_taula]
EXEMPLE: node cloud-db-connector.cjs --table socis --limit 10

La connexió està testejada i funciona perfectament. Pots consultar qualsevol dada en temps real.
```

---

## ⚡ QUICK START

1. **Llistar taules**: `node cloud-db-connector.cjs --list-tables`
2. **Testar connexió**: `node cloud-db-connector.cjs --test-connection` 
3. **Veure socis**: `node cloud-db-connector.cjs --table socis --limit 5`
4. **Ajuda completa**: `node cloud-db-connector.cjs --help`

**Variables d'entorn**: ✅ Ja configurades automàticament  
**Permisos**: ✅ Lectura completa (segur)  
**Status**: ✅ Operativa 24/7

🚀 **LLEST PER USAR - EXECUTA I CONNECTA!**