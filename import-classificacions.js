const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Configuració Supabase
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL || 'https://qbldqtaqawnahuzlzsjs.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI';

const supabase = createClient(supabaseUrl, supabaseKey);

// Mappings
const modalityMapping = {
  '3 BANDES': 'tres_bandes',
  'LLIURE': 'lliure',
  'BANDA': 'banda'
};

const temporadaMapping = {
  '2022': '2021-2022',
  '2023': '2022-2023',
  '2024': '2023-2024',
  '2025': '2024-2025'
};

const categoriaMapping = {
  '1a': '1a',
  '2a': '2a',
  '3a': '3a',
  '4a': '4a'
};

async function llegirCSV() {
  const csvContent = fs.readFileSync('mitjanes.csv', 'utf8');
  const lines = csvContent.split('\n');
  const header = lines[0].split(';');

  const data = [];
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim()) {
      const values = lines[i].split(';');
      if (values.length >= 11) {
        data.push({
          any: values[0],
          modalitat: values[1],
          categoria: values[2],
          posicio: parseInt(values[3]),
          jugador: values[4],
          punts: parseInt(values[5]),
          caramboles: parseInt(values[6]),
          entrades: parseInt(values[7]),
          mitjana_general: parseFloat(values[8].replace(',', '.')),
          mitjana_particular: parseFloat(values[9].replace(',', '.')),
          numero_soci: parseInt(values[10])
        });
      }
    }
  }
  return data;
}

async function obtenirPlayers() {
  const { data, error } = await supabase
    .from('players')
    .select('id, numero_soci');

  if (error) throw error;

  const mapping = {};
  data.forEach(player => {
    mapping[player.numero_soci] = player.id;
  });

  return mapping;
}

async function obtenirCategories() {
  const { data, error } = await supabase
    .from('categories')
    .select('id, nom');

  if (error) throw error;

  const mapping = {};
  data.forEach(cat => {
    mapping[cat.nom] = cat.id;
  });

  return mapping;
}

async function obtenirEvents() {
  const { data, error } = await supabase
    .from('events')
    .select('id, temporada, modalitat, tipus_competicio');

  if (error) throw error;

  const mapping = {};
  data.forEach(event => {
    const key = `${event.temporada}_${event.modalitat}`;
    mapping[key] = event.id;
  });

  return mapping;
}

async function crearEvent(temporada, modalitat) {
  console.log(`Creant event: ${temporada} - ${modalitat}`);

  const eventData = {
    nom: `Campionat Social ${modalitat === 'tres_bandes' ? '3 Bandes' : modalitat.charAt(0).toUpperCase() + modalitat.slice(1)}`,
    temporada,
    modalitat,
    tipus_competicio: 'lliga_social',
    data_inici: temporada.includes('2021') ? '2021-09-01' :
                temporada.includes('2022') ? '2022-09-01' :
                temporada.includes('2023') ? '2023-09-01' : '2024-09-01',
    data_fi: temporada.includes('2021') ? '2022-07-31' :
             temporada.includes('2022') ? '2023-07-31' :
             temporada.includes('2023') ? '2024-07-31' : '2025-07-31',
    estat_competicio: 'finalitzat',
    actiu: false,
    calendari_publicat: false
  };

  const { data, error } = await supabase
    .from('events')
    .insert(eventData)
    .select()
    .single();

  if (error) {
    console.error(`Error creant event:`, error);
    throw error;
  }

  console.log(`Event creat amb ID: ${data.id}`);
  return data.id;
}

async function eliminarClassificacionsExistents(eventIds) {
  console.log('Eliminant classificacions existents...');

  const { error } = await supabase
    .from('classificacions')
    .delete()
    .in('event_id', eventIds);

  if (error) {
    console.error('Error eliminant classificacions:', error);
    throw error;
  }

  console.log('Classificacions eliminades correctament');
}

async function insertarClassificacions(classificacions) {
  console.log(`Inserint ${classificacions.length} classificacions...`);

  // Inserir per lots de 100
  const batchSize = 100;
  for (let i = 0; i < classificacions.length; i += batchSize) {
    const batch = classificacions.slice(i, i + batchSize);

    const { error } = await supabase
      .from('classificacions')
      .insert(batch);

    if (error) {
      console.error(`Error inserint lot ${i/batchSize + 1}:`, error);
      console.log('Dades problemàtiques:', batch[0]); // Mostrar primera fila problemàtica
      throw error;
    }

    console.log(`Lot ${i/batchSize + 1} inserit correctament`);
  }
}

async function main() {
  try {
    console.log('🔄 Iniciant importació de classificacions...');

    // 1. Llegir CSV
    console.log('📖 Llegint CSV...');
    const csvData = await llegirCSV();
    console.log(`CSV llegit: ${csvData.length} registres`);

    // 2. Obtenir mappings
    console.log('🔍 Obtenint mappings de BBDD...');
    const [playersMap, categoriesMap, eventsMap] = await Promise.all([
      obtenirPlayers(),
      obtenirCategories(),
      obtenirEvents()
    ]);

    console.log(`Players: ${Object.keys(playersMap).length}`);
    console.log(`Categories: ${Object.keys(categoriesMap).length}`);
    console.log(`Events existents: ${Object.keys(eventsMap).length}`);

    // 3. Crear events faltants i preparar classificacions
    const classificacions = [];
    const eventsCreats = new Set();

    for (const row of csvData) {
      const temporada = temporadaMapping[row.any];
      const modalitat = modalityMapping[row.modalitat];
      const eventKey = `${temporada}_${modalitat}`;

      // Crear event si no existeix
      if (!eventsMap[eventKey] && !eventsCreats.has(eventKey)) {
        const newEventId = await crearEvent(temporada, modalitat);
        eventsMap[eventKey] = newEventId;
        eventsCreats.add(eventKey);
      }

      const eventId = eventsMap[eventKey];
      const playerId = playersMap[row.numero_soci];
      const categoriaId = categoriesMap[row.categoria];

      if (!eventId) {
        console.warn(`⚠️ No s'ha trobat event per: ${row.any} ${row.modalitat}`);
        continue;
      }

      if (!playerId) {
        console.warn(`⚠️ No s'ha trobat jugador amb número de soci: ${row.numero_soci}`);
        continue;
      }

      if (!categoriaId) {
        console.warn(`⚠️ No s'ha trobat categoria: ${row.categoria}`);
        continue;
      }

      // Calcular camps derivats
      const partides_perdudes = Math.max(0, row.punts - row.punts); // CSV no té perdudes directament
      const partides_jugades = row.punts + partides_perdudes; // Estimació

      classificacions.push({
        event_id: eventId,
        categoria_id: categoriaId,
        player_id: playerId,
        posicio: row.posicio,
        partides_jugades: Math.max(row.punts, 10), // Mínim 10 partides
        partides_guanyades: row.punts,
        partides_perdudes: Math.max(0, Math.max(row.punts, 10) - row.punts),
        partides_empat: 0,
        punts: row.punts,
        caramboles_favor: row.caramboles,
        caramboles_contra: Math.round(row.caramboles / Math.max(row.mitjana_particular, 0.1)), // Estimació
        mitjana_particular: row.mitjana_particular,
        updated_at: new Date().toISOString()
      });
    }

    console.log(`✅ Classificacions preparades: ${classificacions.length}`);

    // 4. Eliminar classificacions existents dels events que actualitzarem
    const eventIdsToUpdate = [...new Set(classificacions.map(c => c.event_id))];
    if (eventIdsToUpdate.length > 0) {
      await eliminarClassificacionsExistents(eventIdsToUpdate);
    }

    // 5. Inserir noves classificacions
    if (classificacions.length > 0) {
      await insertarClassificacions(classificacions);
    }

    console.log('🎉 Importació completada correctament!');
    console.log(`📊 Resum:`);
    console.log(`   - Events creats: ${eventsCreats.size}`);
    console.log(`   - Classificacions importades: ${classificacions.length}`);

  } catch (error) {
    console.error('❌ Error durant la importació:', error);
    process.exit(1);
  }
}

// Executar només si és cridat directament
if (require.main === module) {
  main();
}

module.exports = { main };