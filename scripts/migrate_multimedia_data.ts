import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const multimediaData = [
  { tipus: 'Web del Foment', club: 'Foment Martinenc', billar: '', enllac: 'https://www.fomentmartinenc.org/' },
  { tipus: 'Billar en directe (Cat)', club: 'Billar Club Granollers', billar: '1', enllac: 'https://youtube.com/@granollersbillar1?si=FDt5FSZHq9ojgr-y' },
  { tipus: 'Billar en directe (Cat)', club: 'Billar Club Granollers', billar: '2', enllac: 'https://youtube.com/@granollersbillar2?si=bTm9h_9pGfDc4EQH' },
  { tipus: 'Billar en directe (Cat)', club: 'Billar Club Granollers', billar: '3', enllac: 'https://youtube.com/@granollersbillar3?si=TbSqiYOjnVHuv-dC' },
  { tipus: 'Billar en directe (Cat)', club: 'Billar Club Granollers', billar: '4', enllac: 'https://youtube.com/@granollersbillar4?si=0bQch6qE46kyZdMW' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Banyoles', billar: '1', enllac: 'https://youtube.com/channel/UCIozKc9Toz66y2am4-nWxAA' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Banyoles', billar: '2', enllac: 'https://youtube.com/channel/UCsbBBXU9y7vyZeZboSGuKvQ' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Banyoles', billar: '3', enllac: 'https://youtube.com/channel/UC3UaoySxRFDKQPVjOiCTGpg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Banyoles', billar: '4', enllac: 'https://youtube.com/channel/UCrJ-OEolzEnigssxldd4l1g' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Borges', billar: '1', enllac: 'http://www.youtube.com/@BorgesBillar1' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Borges', billar: '2', enllac: 'http://www.youtube.com/@BorgesBillar2' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Borges', billar: '3', enllac: 'http://www.youtube.com/@BorgesBillar3' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Canet de Mar', billar: '1', enllac: 'https://www.youtube.com/watch?v=Qa2YArp4e-c' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Canet de Mar', billar: '2', enllac: 'https://www.youtube.com/watch?v=npIi55F8EBE' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Canet de Mar', billar: '3', enllac: 'https://www.youtube.com/watch?v=cQitJsP-s4c' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cerdanyola', billar: '1', enllac: 'https://www.youtube.com/@ClubBillarCerdanyolaBill-wr6so/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cerdanyola', billar: '2', enllac: 'https://www.youtube.com/@ClubBillarCerdanyolaBill-oq6ri/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cerdanyola', billar: '3', enllac: 'https://www.youtube.com/@ClubBillarCerdanyolaBillar/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cervera', billar: '1', enllac: 'https://youtube.com/@cerverabillar1' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cervera', billar: '2', enllac: 'https://youtube.com/@cerverabillar2' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cervera', billar: '3', enllac: 'https://youtube.com/@cerverabillar3' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cervera', billar: '4', enllac: 'https://youtube.com/@cerverabillar4' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lleida', billar: '1', enllac: 'https://youtube.com/channel/UC33EaGjvEA92-jcWpL06_XQ' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lleida', billar: '2', enllac: 'https://youtube.com/channel/UC6glMfOX3W3GzVDGenn-cfQ' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lleida', billar: '3', enllac: 'https://youtube.com/channel/UCNn1Tmh53ejJUXhfSDv3Hfg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lleida', billar: '4', enllac: 'https://youtube.com/channel/UCOWby67o_7DONPFu1h9VgVg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lliçà d\'Amunt', billar: '1', enllac: 'https://www.youtube.com/@llicabillar1' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lliçà d\'Amunt', billar: '2', enllac: 'https://www.youtube.com/@llicabillar2' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Llinars', billar: '1', enllac: 'https://www.youtube.com/@ClubBillarllinars/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Manresa', billar: '1', enllac: 'https://www.youtube.com/channel/UCk9YLBgxJVhWrsjLcrn7qwA' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Manresa', billar: '2', enllac: 'https://www.youtube.com/channel/UCx17qHHbTj0yXWKqBqN6B2A' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Manresa', billar: '3', enllac: 'https://www.youtube.com/channel/UCoy0jInzaCfMTirQJTWRtlA' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Manresa', billar: '4', enllac: 'https://www.youtube.com/channel/UCV4n0mgnRWigOksGnxnHtPw' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Mataró', billar: '1', enllac: 'https://youtu.be/L2K1JVss4cg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Mataró', billar: '2', enllac: 'https://youtu.be/tPZWMOzSqlM' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Mataró', billar: '3', enllac: 'https://youtu.be/Ow_FQFa-h6Q' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Mataró', billar: '4', enllac: 'https://youtu.be/-ko-yUFy7cs' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Molins', billar: '1', enllac: 'https://gaming.youtube.com/watch?v=O8jdvml7FM0' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Molins', billar: '2', enllac: 'https://gaming.youtube.com/watch?v=05SxVkabkBg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Molins', billar: '3', enllac: 'https://gaming.youtube.com/watch?v=caWJQbfOaiE' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Molins', billar: '4', enllac: 'https://gaming.youtube.com/watch?v=X-Sqkj-_9CU' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Monforte', billar: '1', enllac: 'https://youtube.com/channel/UCFfLvkS2hTIXop-r-wTlXcQ' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Monforte', billar: '2', enllac: 'https://youtube.com/channel/UCTZhhkh0po7TgRmJ6qy7UUw' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Monforte', billar: '3', enllac: 'https://youtube.com/channel/UCw4lTndxGlhu74xVbw8bkzg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Monforte', billar: '4', enllac: 'https://youtube.com/channel/UCSCI6PC7st_sIILtW3bdCvg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Montroig', billar: '1', enllac: 'https://youtube.com/@billar1mont-roig610?si=olgJnR83IyGn-S2R' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Montroig', billar: '2', enllac: 'https://youtube.com/@billar2mont-roig289?si=sPikKvqnBSwR1P4w' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Montroig', billar: '3', enllac: 'https://youtube.com/@billar3mont-roig36?si=Ysi25_SOWTAieTCR' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Adrià', billar: '1', enllac: 'https://www.youtube.com/channel/UC8TiwIIzS1vNHd1W0Z1lpuQ' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Adrià', billar: '2', enllac: 'https://www.youtube.com/channel/UC9xHdBNYXuj5CtbpXz28EiQ' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Adrià', billar: '3', enllac: 'https://www.youtube.com/channel/UCnxFpglOqmIXLKPv6tf_q-g' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Adrià', billar: '4', enllac: 'https://www.youtube.com/channel/UC4QKXDKnDqnQ31_YG5yvdDg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Feliu', billar: '1', enllac: 'https://www.youtube.com/@cbsantfeliu1/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Feliu', billar: '2', enllac: 'https://www.youtube.com/@cbsantfeliu2/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Feliu', billar: '3', enllac: 'https://www.youtube.com/@cbsantfeliu3/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '1', enllac: 'https://www.youtube.com/channel/UCt1s0StHWo6oyawmmxmZASw' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '2', enllac: 'https://www.youtube.com/channel/UCwLYL5CIFXXOqaS7kJly3gQ' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '3', enllac: 'https://www.youtube.com/channel/UC5EMAWwvg_1gsVrqEWlpixw' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '4', enllac: 'https://www.youtube.com/channel/UCOkHTGoB6MGivKS2DBcuTTQ' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '5', enllac: 'https://www.youtube.com/channel/UCEy8Kt3skfnGx3rv6TU1iHg' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '6', enllac: 'https://www.youtube.com/channel/UCIy2d7-zhSNrQiJISbzKfLw' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '7', enllac: 'https://www.youtube.com/@clubbillarsants-billar7' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '8', enllac: 'https://www.youtube.com/@clubbillarsants-billar8' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Tarragona', billar: '1', enllac: 'https://youtube.com/channel/UCPqOow5DLA1eFcj2ji8nmyw' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Tarragona', billar: '2', enllac: 'https://youtube.com/channel/UCUe403LWY9NGRUAglIM2Lug' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Tarragona', billar: '3', enllac: 'https://youtube.com/channel/UCJk0IyN2gNficW43ZFFajxw' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Vic', billar: '1', enllac: 'https://youtu.be/ytD9_b2GVsc' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Vic', billar: '2', enllac: 'https://youtu.be/QcQqQYQZa_M' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Vic', billar: '3', enllac: 'https://youtu.be/xRkfCNZnYAk' },
  { tipus: 'Billar en directe (Cat)', club: 'Club Billar Vic', billar: '4', enllac: 'https://youtu.be/Z5dADQCFczY' },
  { tipus: 'Billar en directe (Cat)', club: 'Coral Colon', billar: '1', enllac: 'https://www.youtube.com/@CoralColonBillar1/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Coral Colon', billar: '2', enllac: 'https://www.youtube.com/@CoralColonBillar2/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Coral Colon', billar: '3', enllac: 'https://www.youtube.com/@CoralColonBillar3/streams' },
  { tipus: 'Billar en directe (Cat)', club: 'Coral Colon', billar: '4', enllac: 'https://www.youtube.com/@CoralColonBillar4/streams' },
  { tipus: 'Billar en directe (Esp)', club: 'Billar Sueca', billar: '', enllac: 'https://www.youtube.com/@billarsueca8304' },
  { tipus: 'Billar en directe (Esp)', club: 'Club Billar Ayamonte', billar: '', enllac: 'https://www.youtube.com/@clubbillarayamonte7763' },
  { tipus: 'Billar en directe (Esp)', club: 'Club Billar Baeza', billar: '', enllac: 'https://youtube.com/@baezabillar6310?feature=shared' },
  { tipus: 'Billar en directe (Esp)', club: 'Club Billar Valladolid', billar: '', enllac: 'https://www.youtube.com/@clubbillarvalladolid' },
  { tipus: 'Billar en directe (Esp)', club: 'Federación Billar Comunidad Valenciana', billar: '', enllac: 'https://www.youtube.com/@federaciondebillarcomunida5284' },
  { tipus: 'Billar en directe (Esp)', club: 'Federación Española de Billar', billar: '', enllac: 'https://www.youtube.com/@realfederacionespanoladebi1020' },
  { tipus: 'Billar en directe (Esp)', club: 'Federación Madrileña de Billar', billar: '', enllac: 'https://www.youtube.com/@fmbvallecasmadrid6669' },
  { tipus: 'Billar en directe (Int)', club: 'Billar en casa HD', billar: '', enllac: 'https://youtube.com/@billarencasahd123?feature=shared' },
  { tipus: 'Billar en directe (Int)', club: 'Club Billar Pézenas', billar: '', enllac: 'https://www.youtube.com/@BillardPezenas' },
  { tipus: 'Billar en directe (Int)', club: 'Kozoom', billar: '', enllac: 'https://www.youtube.com/@KozoomTV' },
  { tipus: 'Billar en directe (Int)', club: 'PBA', billar: '', enllac: 'https://www.youtube.com/@pbatv' },
  { tipus: 'Billar en directe (Int)', club: 'PBA', billar: '', enllac: 'https://www.youtube.com/@billiards-pbatv' },
  { tipus: 'Documents', club: 'Esteve Mata (joc curt)', billar: '', enllac: 'http://www.estevemata.com/images/aprenjugar/dosierlibreycuadro47.pdf' },
  { tipus: 'Tutorials billar', club: '3 cushion billiards', billar: '', enllac: 'https://www.youtube.com/@3cushionbilliards769' },
  { tipus: 'Tutorials billar', club: 'Alexandre Salazar', billar: '', enllac: 'https://www.youtube.com/@billarvirtualsalazar2889' },
  { tipus: 'Tutorials billar', club: 'AM Billiard academy', billar: '', enllac: 'https://www.youtube.com/@ambilliardacademy' },
  { tipus: 'Tutorials billar', club: 'Billiard Hakase (coreà)', billar: '', enllac: 'https://www.youtube.com/@billiard.hakase' },
  { tipus: 'Tutorials billar', club: 'El flaco billarista', billar: '', enllac: 'https://www.youtube.com/@elflacobillarista' },
  { tipus: 'Tutorials billar', club: 'El profe de billar', billar: '', enllac: 'https://www.youtube.com/@elprofedebillar' },
  { tipus: 'Tutorials billar', club: 'Escuela de 3 bandas', billar: '', enllac: 'https://www.youtube.com/@escuelade3bandasparatodos' },
  { tipus: 'Tutorials billar', club: 'Fone Jr', billar: '', enllac: 'https://www.youtube.com/@fone_jr' },
  { tipus: 'Tutorials billar', club: 'Fred Caudron', billar: '', enllac: 'https://www.youtube.com/@FredCaudron' },
  { tipus: 'Tutorials billar', club: 'GJ Billiard (Holandès)', billar: '', enllac: 'https://www.youtube.com/@GJBilliards' },
  { tipus: 'Tutorials billar', club: 'HT Billiards (Pool)', billar: '', enllac: 'https://www.youtube.com/@htbilliards' },
  { tipus: 'Tutorials billar', club: 'hwanjuTV (coreà)', billar: '', enllac: 'https://www.youtube.com/@hwanjuTV' },
  { tipus: 'Tutorials billar', club: 'Jaume Carreras', billar: '', enllac: 'https://youtube.com/@jaumecarreras222?feature=shared' },
  { tipus: 'Tutorials billar', club: 'Les billes en paquet (francès)', billar: '', enllac: 'https://www.youtube.com/@lesbillesenpaquet' },
  { tipus: 'Tutorials billar', club: 'Mike\'s life Biljardstudio (holandès)', billar: '', enllac: 'https://www.youtube.com/@LiveBiljartstudioMikeHofland' },
  { tipus: 'Tutorials billar', club: 'Monpetitbillard (francès)', billar: '', enllac: 'https://www.youtube.com/@monpetitbillard' },
  { tipus: 'Tutorials billar', club: 'Night Cafe (anglès/turc)', billar: '', enllac: 'https://www.youtube.com/c/NightCaf%C3%A9Billiard' },
  { tipus: 'Tutorials billar', club: 'sybazzar (coreà)', billar: '', enllac: 'https://www.youtube.com/@%EC%97%90%EC%8A%A4%EC%99%80%EC%9D%B4%EC%8A%A4%ED%8F%AC%EC%B8%A0' },
  { tipus: 'Tutorials billar', club: 'Timo Peters Billiards (holandès)', billar: '', enllac: 'https://www.youtube.com/@TimoPetersBilliards' },
  { tipus: 'Tutorials billar', club: 'Tres Bandas (Esp)', billar: '', enllac: 'https://www.youtube.com/@TresBandas_2024' },
  { tipus: 'Tutorials billar', club: 'Yeu Bida 3C (vietnamita)', billar: '', enllac: 'https://www.youtube.com/@YeuBida3C' }
];

async function migrateData() {
  console.log('🚀 Starting multimedia data migration...');

  // First, check if data already exists
  const { data: existingData, error: checkError } = await supabase
    .from('multimedia_links')
    .select('id')
    .limit(1);

  if (checkError) {
    console.error('❌ Error checking existing data:', checkError);
    return;
  }

  if (existingData && existingData.length > 0) {
    console.log('⚠️  Data already exists in the database. Skipping migration.');
    console.log('   If you want to re-migrate, delete all rows first.');
    return;
  }

  // Insert all data
  const { data, error } = await supabase
    .from('multimedia_links')
    .insert(multimediaData);

  if (error) {
    console.error('❌ Error inserting data:', error);
    return;
  }

  console.log(`✅ Successfully migrated ${multimediaData.length} multimedia links!`);
}

migrateData();
