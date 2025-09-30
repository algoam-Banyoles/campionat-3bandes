const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Configuració de Supabase
const supabaseUrl = 'https://qbldqtaqawnahuzlzsjs.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

// Mapatge d'anys a temporades
const temporadaMapping = {
  '2022': '2021-2022',
  '2023': '2022-2023',
  '2024': '2023-2024',
  '2025': '2024-2025'
};

// Mapatge de modalitats
const modalitatMapping = {
  'LLIURE': 'lliure',
  'BANDA': 'banda',
  '3 BANDES': 'tres_bandes'
};

async function main() {
  console.log('🚀 Iniciant importació de classificacions històriques...');

  try {
    // 1. Verificar estat actual
    console.log('\n📊 Verificant estat actual...');
    const { data: currentClassifications, error: countError } = await supabase
      .from('classificacions')
      .select('id')
      .limit(1000);

    if (countError) {
      console.error('❌ Error verificant classificacions:', countError);
      return;
    }

    console.log(`📋 Classificacions actuals: ${currentClassifications?.length || 0}`);

    // 1.5. Netejar TOTES les classificacions històriques existents
    console.log('\n🧹 Netejant totes les classificacions existents per reimportar...');
    const { error: deleteError } = await supabase
      .from('classificacions')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000'); // Condició que borra tots

    if (deleteError) {
      console.warn('⚠️ Error netejant classificacions existents:', deleteError.message);
    } else {
      console.log('✅ Totes les classificacions netejades');
    }

    // 2. Llegir i processar CSV
    console.log('\n📖 Llegint fitxer CSV...');
    const csvPath = path.join(__dirname, 'mitjanes.csv');
    const csvContent = fs.readFileSync(csvPath, 'utf-8');
    const lines = csvContent.split('\n').filter(line => line.trim());

    console.log(`📄 Total línies al CSV: ${lines.length} (incloent capçalera)`);

    // Saltar capçalera
    const dataLines = lines.slice(1);
    console.log(`📊 Registres de dades: ${dataLines.length}`);

    // 3. Processar cada línia
    const errors = [];
    const successes = [];
    const missingPlayers = new Set();
    const createdPlayers = [];

    console.log('\n🔄 Processant registres...');

    for (let i = 0; i < dataLines.length; i++) {
      const line = dataLines[i];
      if (!line.trim()) continue;

      try {
        // Parsejar CSV (separador ;)
        const parts = line.split(';');
        if (parts.length < 11) {
          errors.push(`Línia ${i + 2}: Format incorrecte (${parts.length} camps)`);
          continue;
        }

        // Estructura: Any;Modalitat;Categoria;Posició;Jugador;Punts;Caramboles;Entrades;Mitjana General;Mitjana Particular;Numero Soci
        const [any, modalitat, categoria, posicio, jugador, punts, caramboles, entrades, mitjanaGeneral, mitjanaParticular, numeroSoci] = parts;

        // Debug per verificar dades
        if (i === 0) {
          console.log(`📝 Exemple primera línia:`);
          console.log(`  Any: ${any}, Modalitat: ${modalitat}, Categoria: ${categoria}`);
          console.log(`  Jugador: ${jugador}, Mitjana Particular: ${mitjanaParticular}, Numero Soci: ${numeroSoci}`);
        }

        // Validacions bàsiques
        if (!numeroSoci || !any || !modalitat || !categoria || !jugador) {
          errors.push(`Línia ${i + 2}: Camps obligatoris buits`);
          continue;
        }

        const numeroSociInt = parseInt(numeroSoci);
        if (isNaN(numeroSociInt)) {
          errors.push(`Línia ${i + 2}: Número de soci no vàlid: ${numeroSoci}`);
          continue;
        }

        // Verificar si el jugador existeix
        let playerId = null;
        const { data: existingPlayer } = await supabase
          .from('players')
          .select('id, numero_soci')
          .eq('numero_soci', numeroSociInt)
          .single();

        if (existingPlayer) {
          playerId = existingPlayer.id;
        } else {
          // Crear jugador si no existeix
          missingPlayers.add(numeroSociInt);

          const { data: newPlayer, error: createPlayerError } = await supabase
            .from('players')
            .insert([{
              numero_soci: numeroSociInt,
              nom: jugador.trim(),
              email: null
            }])
            .select('id')
            .single();

          if (createPlayerError) {
            errors.push(`Línia ${i + 2}: Error creant jugador ${jugador} (${numeroSoci}): ${createPlayerError.message}`);
            continue;
          }

          playerId = newPlayer.id;
          createdPlayers.push({ numero_soci: numeroSociInt, nom: jugador });
          console.log(`👤 Creat jugador: ${jugador} (${numeroSoci})`);
        }

        // Buscar o crear event
        const temporada = temporadaMapping[any];
        const modalitatMapped = modalitatMapping[modalitat];

        if (!temporada || !modalitatMapped) {
          errors.push(`Línia ${i + 2}: Any/modalitat no mapejat: ${any}/${modalitat}`);
          continue;
        }

        // Buscar event existent
        let eventId = null;
        const { data: existingEvent } = await supabase
          .from('events')
          .select('id')
          .eq('temporada', temporada)
          .eq('modalitat', modalitatMapped)
          .eq('tipus_competicio', 'lliga_social')
          .single();

        if (existingEvent) {
          eventId = existingEvent.id;
        } else {
          // Crear event
          const { data: newEvent, error: createEventError } = await supabase
            .from('events')
            .insert([{
              nom: `Lliga Social ${modalitat} ${temporada}`,
              temporada: temporada,
              modalitat: modalitatMapped,
              tipus_competicio: 'lliga_social',
              estat_competicio: 'finalitzat',
              actiu: false,
              calendari_publicat: true
            }])
            .select('id')
            .single();

          if (createEventError) {
            errors.push(`Línia ${i + 2}: Error creant event: ${createEventError.message}`);
            continue;
          }

          eventId = newEvent.id;
          console.log(`🏆 Creat event: ${modalitat} ${temporada}`);
        }

        // Buscar categoria
        let categoriaId = null;
        const { data: existingCategory } = await supabase
          .from('categories')
          .select('id')
          .eq('event_id', eventId)
          .eq('nom', categoria + ' Categoria')
          .single();

        if (existingCategory) {
          categoriaId = existingCategory.id;
        } else {
          // Crear categoria
          const distanciaCaramboles = modalitat === '3 BANDES' ? 40 :
                                     modalitat === 'BANDA' ? 80 : 120;

          const { data: newCategory, error: createCategoryError } = await supabase
            .from('categories')
            .insert([{
              event_id: eventId,
              nom: categoria + ' Categoria',
              distancia_caramboles: distanciaCaramboles,
              min_jugadors: 4,
              max_jugadors: 20,
              ordre_categoria: categoria === '1a' ? 1 : categoria === '2a' ? 2 : 3
            }])
            .select('id')
            .single();

          if (createCategoryError) {
            errors.push(`Línia ${i + 2}: Error creant categoria: ${createCategoryError.message}`);
            continue;
          }

          categoriaId = newCategory.id;
          console.log(`📂 Creada categoria: ${categoria} per ${modalitat} ${temporada}`);
        }

        // Processar mitjana particular (convertir coma decimal a punt si cal)
        const mitjanaParticularValue = mitjanaParticular
          ? parseFloat(mitjanaParticular.replace(',', '.'))
          : 0;

        // Crear classificació
        const { error: classificationError } = await supabase
          .from('classificacions')
          .insert([{
            event_id: eventId,
            categoria_id: categoriaId,
            player_id: playerId,
            posicio: parseInt(posicio) || 0,
            punts: parseInt(punts) || 0,
            caramboles_favor: parseInt(caramboles) || 0,
            caramboles_contra: parseInt(entrades) || 0,
            mitjana_particular: mitjanaParticularValue,
            partides_jugades: 0, // Les calcularem posteriorment si cal
            partides_guanyades: 0,
            partides_perdudes: 0,
            partides_empat: 0
          }]);

        if (classificationError) {
          errors.push(`Línia ${i + 2}: Error creant classificació: ${classificationError.message}`);
          continue;
        }

        successes.push(i + 2);

        // Mostrar progrés cada 50 registres
        if (successes.length % 50 === 0) {
          console.log(`✅ Processats ${successes.length} registres...`);
        }

      } catch (error) {
        errors.push(`Línia ${i + 2}: Error inesperat: ${error.message}`);
      }
    }

    // 4. Mostrar resum final
    console.log('\n📈 RESUM FINAL:');
    console.log(`✅ Registres carregats amb èxit: ${successes.length}`);
    console.log(`❌ Errors: ${errors.length}`);
    console.log(`👤 Jugadors creats: ${createdPlayers.length}`);
    console.log(`📊 Total registres processats: ${dataLines.length}`);

    if (createdPlayers.length > 0) {
      console.log('\n👥 Jugadors creats:');
      createdPlayers.forEach(player => {
        console.log(`  - ${player.nom} (${player.numero_soci})`);
      });
    }

    if (errors.length > 0) {
      console.log('\n❌ Errors trobats:');
      errors.slice(0, 10).forEach(error => console.log(`  - ${error}`));
      if (errors.length > 10) {
        console.log(`  ... i ${errors.length - 10} errors més`);
      }
    }

    // 5. Verificació final
    console.log('\n🔍 Verificació final...');
    const { data: finalCount, error: finalCountError } = await supabase
      .from('classificacions')
      .select('id', { count: 'exact' });

    if (!finalCountError) {
      console.log(`📊 Total classificacions a la BD: ${finalCount?.length || 0}`);
    }

    console.log('\n🎉 Importació completada!');

  } catch (error) {
    console.error('💥 Error fatal:', error);
  }
}

// Executar script
if (require.main === module) {
  main();
}

module.exports = { main };