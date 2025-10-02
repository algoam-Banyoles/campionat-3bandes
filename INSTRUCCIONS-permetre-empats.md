# Instruccions per Permetre Empats en Campionats Socials

## Fitxer a modificar
`src/routes/admin/resultats-socials/+page.svelte`

---

## Canvi 1: Validació (línies 117-120)

### ABANS:
```javascript
if (caramboles_jugador1 === caramboles_jugador2) {
  error = 'No es poden empatar en una partida de campionat social';
  return;
}
```

### DESPRÉS:
```javascript
// Empats permesos: 1 punt per cada jugador
if (caramboles_jugador1 === 0 && caramboles_jugador2 === 0) {
  error = 'Introdueix les caramboles per ambdós jugadors';
  return;
}
```

---

## Canvi 2: Botó Submit (línia 442)

### ABANS:
```svelte
disabled={loading || !selectedMatch || caramboles_jugador1 === caramboles_jugador2}
```

### DESPRÉS:
```svelte
disabled={loading || !selectedMatch || (caramboles_jugador1 === 0 && caramboles_jugador2 === 0)}
```

---

## Canvi 3: Preview del Resultat (línies 403-415)

### ABANS:
```svelte
<!-- Winner Preview -->
{#if caramboles_jugador1 !== caramboles_jugador2 && (caramboles_jugador1 > 0 || caramboles_jugador2 > 0)}
  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
    <h4 class="font-medium text-blue-900 mb-2">Guanyador:</h4>
    <p class="text-blue-800">
      {caramboles_jugador1 > caramboles_jugador2
        ? `${selectedMatch.soci1?.nom} ${selectedMatch.soci1?.cognoms}`
        : `${selectedMatch.soci2?.nom} ${selectedMatch.soci2?.cognoms}`}
    </p>
    <p class="text-sm text-blue-700">
      Resultat: {caramboles_jugador1} - {caramboles_jugador2}
    </p>
  </div>
{/if}
```

### DESPRÉS:
```svelte
<!-- Result Preview -->
{#if caramboles_jugador1 > 0 || caramboles_jugador2 > 0}
  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
    {#if caramboles_jugador1 === caramboles_jugador2}
      <h4 class="font-medium text-yellow-900 mb-2">⚖️ Empat!</h4>
      <p class="text-yellow-800">
        Ambdós jugadors obtenen 1 punt
      </p>
    {:else}
      <h4 class="font-medium text-blue-900 mb-2">🏆 Guanyador:</h4>
      <p class="text-blue-800">
        {caramboles_jugador1 > caramboles_jugador2
          ? `${selectedMatch.soci1?.nom} ${selectedMatch.soci1?.cognoms}`
          : `${selectedMatch.soci2?.nom} ${selectedMatch.soci2?.cognoms}`}
      </p>
      <p class="text-sm text-blue-700">
        Guanyador: 2 punts • Perdedor: 0 punts
      </p>
    {/if}
    <p class="text-sm text-blue-700 mt-2">
      Resultat: {caramboles_jugador1} - {caramboles_jugador2}
    </p>
  </div>
{/if}
```

---

## Resum dels Canvis

✅ **Empats ara permesos** - Validen que almenys un jugador tingui caramboles
✅ **Botó habilitat** - Només deshabilitat si ambdós tenen 0 caramboles
✅ **Preview millorat** - Mostra missatge específic per empats amb icona ⚖️
✅ **Sistema de punts** - Empat = 1 punt per cada jugador
