# Períodes de Bloqueig del Calendari de Campionats Socials

## 📋 Descripció

S'ha afegit la funcionalitat per especificar **períodes de bloqueig** en la generació automàtica del calendari de campionats socials. Això permet definir dates en les quals **no es programaran partides**, però que **apareixeran al calendari imprès** com a dies buits.

## 🎯 Casos d'Ús

- **Vacances de Pasqua**: Bloquejar la setmana santa
- **Vacances d'estiu**: Bloquejar el mes d'agost
- **Festius especials**: Bloquejar ponts o festivitats locals
- **Tancament del club**: Bloquejar períodes de manteniment o tancament temporal

## 🔧 Com Utilitzar-ho

### 1. Accedeix a la pàgina d'inscripcions socials
Vés a: **Admin → Inscripcions Socials** (`/admin/inscripcions-socials`)

### 2. Selecciona l'esdeveniment
Tria el campionat social per al qual vols generar el calendari.

### 3. Configura els períodes de bloqueig
Al component "Generador de Calendari":

1. Clica el botó **"Gestionar Bloquejos"** dins la secció "Períodes de Bloqueig"
2. Omple el formulari:
   - **Data d'inici**: Primera data a bloquejar (inclosa)
   - **Data de fi**: Última data a bloquejar (inclosa)
   - **Descripció**: Text opcional (ex: "Setmana Santa", "Vacances d'agost")
3. Clica **"➕ Afegir Període"**

Pots afegir múltiples períodes de bloqueig segons necessitis.

### 4. Genera el calendari
Un cop definits els períodes:

1. Estableix la data d'inici i de fi del campionat
2. Configura dies de la setmana, hores i altres paràmetres
3. Clica **"Generar Calendari"**

L'algoritme **saltarà automàticament** les dates bloquejades en programar les partides.

## 📊 Comportament

### Durant la generació
- Les dates dins dels períodes bloquejats **NO tindran partides programades**
- L'algoritme les tractarà com a dies festius
- Es salten completament en l'assignació de partides

### Al calendari imprès
- **Les dates bloquejades SÍ apareixen** al calendari cronològic
- Es mostren com a **slots buits** (sense partits)
- Mantenen la **continuïtat visual** del calendari
- Facilita veure tot el període de competició d'un cop d'ull

## 💡 Exemple Pràctic

**Escenari**: Campionat del 15 de gener al 30 de juny, amb vacances de Setmana Santa

1. Afegir període de bloqueig:
   - Inici: 10 d'abril
   - Fi: 17 d'abril
   - Descripció: "Setmana Santa"

2. Generar calendari amb:
   - Data inici: 15 de gener
   - Data fi: 30 de juny
   - Dies: Dilluns a Divendres
   - Hores: 18:00 i 19:00

**Resultat**:
- ✅ Partides programades del 15 gener al 9 abril
- 🚫 **Cap partit** del 10 al 17 abril (Setmana Santa)
- ✅ Partides programades del 18 abril al 30 juny
- 📅 Al calendari imprès, la setmana del 10-17 abril apareix però amb tots els slots buits

## 🔄 Gestió de Períodes

### Modificar un període
Per modificar un període existent:
1. Elimina'l amb el botó **"Eliminar"**
2. Torna a crear-lo amb les dades correctes

### Eliminar un període
Clica el botó **"Eliminar"** al costat del període que vols esborrar.

**Important**: Després d'eliminar un període, cal regenerar el calendari perquè els canvis tinguin efecte.

## ⚙️ Implementació Tècnica

### Component modificat
- **`src/lib/components/admin/CalendarGenerator.svelte`**

### Noves variables
```typescript
let blockedPeriods: Array<{ 
  start: string; 
  end: string; 
  description: string 
}> = [];
```

### Noves funcions
- `addBlockedPeriod()`: Afegeix un nou període de bloqueig
- `removeBlockedPeriod(index)`: Elimina un període
- `updateBlockedDatesInConfig()`: Converteix els períodes a dates individuals i els afegeix a `dies_festius`

### Integració amb sistema existent
Els períodes de bloqueig s'afegeixen automàticament al camp `dies_festius` de la configuració del calendari, reutilitzant la lògica existent que ja saltava els dies festius en la generació.

## 📝 Notes

- Els períodes de bloqueig són **temporals** (només per a la sessió actual)
- Cal definir-los cada vegada que es generi un calendari nou
- Si es regenera el calendari, cal tornar a especificar els períodes
- Les dates bloquejades es calculen **incloses** (inici i fi inclosos)
- El sistema calcula automàticament el nombre de dies bloquejats

## 🎨 Millores Futures (Opcionals)

- [ ] Desar els períodes de bloqueig a la base de dades
- [ ] Carregar períodes de bloqueig predefinits per temporada
- [ ] Importar dies festius oficials de Catalunya
- [ ] Visualització gràfica dels períodes al calendari

---

**Data d'implementació**: 11 de desembre de 2025  
**Versió**: 1.0
