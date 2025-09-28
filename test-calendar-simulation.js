// Test simulació generació calendari amb restriccions reals
console.log("🏆 Testing calendar generation with real player restrictions:\n");

// Simulació de jugadors amb restriccions reals
const playersWithRestrictions = [
  { id: 8715, name: "Jugador A", restrictions: "del 1 al 15 de octubre NO" },
  { id: 7196, name: "Jugador B", restrictions: "Del 1 al 15 de octubre NO" },
  { id: 8648, name: "Jugador C", restrictions: "6 octubre NO" },
  { id: 8747, name: "Jugador D", restrictions: "1 i 2 octubre NO" },
  { id: 9999, name: "Jugador E", restrictions: "" } // Sense restriccions
];

// Funcions de parsing (copiades del CalendarGenerator)
function parseSpecialRestrictions(restrictions) {
  if (!restrictions || restrictions.trim() === '') return [];
  
  const periods = [];
  const currentYear = new Date().getFullYear();
  
  // Mapes dels mesos en català
  const monthMap = {
    'gener': 0, 'febrer': 1, 'març': 2, 'abril': 3, 'maig': 4, 'juny': 5,
    'juliol': 6, 'agost': 7, 'setembre': 8, 'octubre': 9, 'novembre': 10, 'desembre': 11
  };
  
  // Dividir per línies i processar cada línia
  const lines = restrictions.split('\n').map(line => line.trim()).filter(line => line.length > 0);
  
  for (const line of lines) {
    let found = false;
    
    // Test 1: Períodes "del X al Y de [mes]"
    let match = line.match(/del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+de\s+([a-zA-Zàèéíòóúç]+)/i);
    if (match) {
      const [, startDay, endDay, monthName] = match;
      const monthNumber = monthMap[monthName.toLowerCase()];
      if (monthNumber !== undefined) {
        const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
        const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
        periods.push({ start: startDate, end: endDate });
        found = true;
      }
    }
    
    // Test 2: Períodes "del X al Y d'[mes]"
    if (!found) {
      match = line.match(/del\s+(\d{1,2})\s+al\s+(\d{1,2})\s+d'([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, startDay, endDay, monthName] = match;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const startDate = new Date(currentYear, monthNumber, parseInt(startDay));
          const endDate = new Date(currentYear, monthNumber, parseInt(endDay));
          periods.push({ start: startDate, end: endDate });
          found = true;
        }
      }
    }
    
    // Test 6: "X [mes]" sense "de"
    if (!found) {
      match = line.match(/(\d{1,2})\s+([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, day, monthName] = match;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const date = new Date(currentYear, monthNumber, parseInt(day));
          periods.push({ start: date, end: date });
          found = true;
        }
      }
    }
    
    // Test 7: Multiple dates "X i Y [mes]"
    if (!found) {
      match = line.match(/(\d{1,2})\s+i\s+(\d{1,2})\s+([a-zA-Zàèéíòóúç]+)/i);
      if (match) {
        const [, day1, day2, monthName] = match;
        const monthNumber = monthMap[monthName.toLowerCase()];
        if (monthNumber !== undefined) {
          const date1 = new Date(currentYear, monthNumber, parseInt(day1));
          const date2 = new Date(currentYear, monthNumber, parseInt(day2));
          periods.push({ start: date1, end: date1 });
          periods.push({ start: date2, end: date2 });
          found = true;
        }
      }
    }
  }
  
  return periods;
}

function isDateRestricted(date, restrictionsText) {
  if (!restrictionsText || restrictionsText.trim() === '') return false;
  
  const restrictions = parseSpecialRestrictions(restrictionsText);
  
  return restrictions.some(restriction => {
    // Comparar només les dates (sense hora)
    const checkDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    const startDate = new Date(restriction.start.getFullYear(), restriction.start.getMonth(), restriction.start.getDate());
    const endDate = new Date(restriction.end.getFullYear(), restriction.end.getMonth(), restriction.end.getDate());
    
    return checkDate >= startDate && checkDate <= endDate;
  });
}

// Simular programació de partits
function canScheduleMatch(player1, player2, date) {
  const player1Restricted = isDateRestricted(date, player1.restrictions);
  const player2Restricted = isDateRestricted(date, player2.restrictions);
  
  return !player1Restricted && !player2Restricted;
}

// Generar enfrontaments
const matchups = [];
for (let i = 0; i < playersWithRestrictions.length; i++) {
  for (let j = i + 1; j < playersWithRestrictions.length; j++) {
    matchups.push({
      player1: playersWithRestrictions[i],
      player2: playersWithRestrictions[j]
    });
  }
}

console.log(`Generated ${matchups.length} matchups to schedule:\n`);

// Dates de test per octubre 2025
const testDates = [
  new Date(2025, 9, 1),   // 1 d'octubre
  new Date(2025, 9, 2),   // 2 d'octubre  
  new Date(2025, 9, 6),   // 6 d'octubre
  new Date(2025, 9, 10),  // 10 d'octubre
  new Date(2025, 9, 15),  // 15 d'octubre
  new Date(2025, 9, 16),  // 16 d'octubre
  new Date(2025, 9, 25),  // 25 d'octubre
];

// Provar programar cada enfrontament en cada data
testDates.forEach(date => {
  const dateStr = date.toLocaleDateString('ca-ES');
  console.log(`📅 ${dateStr}:`);
  
  let scheduledCount = 0;
  let blockedCount = 0;
  
  matchups.forEach(matchup => {
    const canSchedule = canScheduleMatch(matchup.player1, matchup.player2, date);
    const status = canSchedule ? '✅' : '🚫';
    const reason = canSchedule ? '' : getBlockedReason(matchup.player1, matchup.player2, date);
    
    console.log(`   ${status} ${matchup.player1.name} vs ${matchup.player2.name}${reason ? ` (${reason})` : ''}`);
    
    if (canSchedule) {
      scheduledCount++;
    } else {
      blockedCount++;
    }
  });
  
  console.log(`   📊 ${scheduledCount} programats, ${blockedCount} bloquejats\n`);
});

function getBlockedReason(player1, player2, date) {
  const p1Restricted = isDateRestricted(date, player1.restrictions);
  const p2Restricted = isDateRestricted(date, player2.restrictions);
  
  if (p1Restricted && p2Restricted) {
    return `Ambdós restringits`;
  } else if (p1Restricted) {
    return `${player1.name} restringit`;
  } else if (p2Restricted) {
    return `${player2.name} restringit`;
  }
  
  return '';
}

console.log("🎯 Calendar simulation completed!");