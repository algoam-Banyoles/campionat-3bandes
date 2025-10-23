<script lang="ts">
  import { slide } from 'svelte/transition';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';

  // Estats
  let multimediaData: any[] = [];
  let loading = true;
  let error: string | null = null;
  let showAddForm = false;
  let editingLink: any | null = null;

  // Form fields
  let formTipus = '';
  let formClub = '';
  let formBillar = '';
  let formEnllac = '';

  // Fallback data si no es pot carregar de la BD
  const fallbackData = [
    { tipus: 'Web del Foment', club: 'Foment Martinenc', billar: '', enllaç: 'https://www.fomentmartinenc.org/' },
    { tipus: 'Billar en directe (Cat)', club: 'Billar Club Granollers', billar: '1', enllaç: 'https://youtube.com/@granollersbillar1?si=FDt5FSZHq9ojgr-y' },
    { tipus: 'Billar en directe (Cat)', club: 'Billar Club Granollers', billar: '2', enllaç: 'https://youtube.com/@granollersbillar2?si=bTm9h_9pGfDc4EQH' },
    { tipus: 'Billar en directe (Cat)', club: 'Billar Club Granollers', billar: '3', enllaç: 'https://youtube.com/@granollersbillar3?si=TbSqiYOjnVHuv-dC' },
    { tipus: 'Billar en directe (Cat)', club: 'Billar Club Granollers', billar: '4', enllaç: 'https://youtube.com/@granollersbillar4?si=0bQch6qE46kyZdMW' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Banyoles', billar: '1', enllaç: 'https://youtube.com/channel/UCIozKc9Toz66y2am4-nWxAA' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Banyoles', billar: '2', enllaç: 'https://youtube.com/channel/UCsbBBXU9y7vyZeZboSGuKvQ' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Banyoles', billar: '3', enllaç: 'https://youtube.com/channel/UC3UaoySxRFDKQPVjOiCTGpg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Banyoles', billar: '4', enllaç: 'https://youtube.com/channel/UCrJ-OEolzEnigssxldd4l1g' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Borges', billar: '1', enllaç: 'http://www.youtube.com/@BorgesBillar1' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Borges', billar: '2', enllaç: 'http://www.youtube.com/@BorgesBillar2' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Borges', billar: '3', enllaç: 'http://www.youtube.com/@BorgesBillar3' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Canet de Mar', billar: '1', enllaç: 'https://www.youtube.com/watch?v=Qa2YArp4e-c' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Canet de Mar', billar: '2', enllaç: 'https://www.youtube.com/watch?v=npIi55F8EBE' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Canet de Mar', billar: '3', enllaç: 'https://www.youtube.com/watch?v=cQitJsP-s4c' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cerdanyola', billar: '1', enllaç: 'https://www.youtube.com/@ClubBillarCerdanyolaBill-wr6so/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cerdanyola', billar: '2', enllaç: 'https://www.youtube.com/@ClubBillarCerdanyolaBill-oq6ri/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cerdanyola', billar: '3', enllaç: 'https://www.youtube.com/@ClubBillarCerdanyolaBillar/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cervera', billar: '1', enllaç: 'https://youtube.com/@cerverabillar1' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cervera', billar: '2', enllaç: 'https://youtube.com/@cerverabillar2' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cervera', billar: '3', enllaç: 'https://youtube.com/@cerverabillar3' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Cervera', billar: '4', enllaç: 'https://youtube.com/@cerverabillar4' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lleida', billar: '1', enllaç: 'https://youtube.com/channel/UC33EaGjvEA92-jcWpL06_XQ' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lleida', billar: '2', enllaç: 'https://youtube.com/channel/UC6glMfOX3W3GzVDGenn-cfQ' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lleida', billar: '3', enllaç: 'https://youtube.com/channel/UCNn1Tmh53ejJUXhfSDv3Hfg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lleida', billar: '4', enllaç: 'https://youtube.com/channel/UCOWby67o_7DONPFu1h9VgVg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lliçà d\'Amunt', billar: '1', enllaç: 'https://www.youtube.com/@llicabillar1' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Lliçà d\'Amunt', billar: '2', enllaç: 'https://www.youtube.com/@llicabillar2' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Llinars', billar: '1', enllaç: 'https://www.youtube.com/@ClubBillarllinars/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Manresa', billar: '1', enllaç: 'https://www.youtube.com/channel/UCk9YLBgxJVhWrsjLcrn7qwA' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Manresa', billar: '2', enllaç: 'https://www.youtube.com/channel/UCx17qHHbTj0yXWKqBqN6B2A' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Manresa', billar: '3', enllaç: 'https://www.youtube.com/channel/UCoy0jInzaCfMTirQJTWRtlA' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Manresa', billar: '4', enllaç: 'https://www.youtube.com/channel/UCV4n0mgnRWigOksGnxnHtPw' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Mataró', billar: '1', enllaç: 'https://youtu.be/L2K1JVss4cg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Mataró', billar: '2', enllaç: 'https://youtu.be/tPZWMOzSqlM' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Mataró', billar: '3', enllaç: 'https://youtu.be/Ow_FQFa-h6Q' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Mataró', billar: '4', enllaç: 'https://youtu.be/-ko-yUFy7cs' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Molins', billar: '1', enllaç: 'https://gaming.youtube.com/watch?v=O8jdvml7FM0' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Molins', billar: '2', enllaç: 'https://gaming.youtube.com/watch?v=05SxVkabkBg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Molins', billar: '3', enllaç: 'https://gaming.youtube.com/watch?v=caWJQbfOaiE' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Molins', billar: '4', enllaç: 'https://gaming.youtube.com/watch?v=X-Sqkj-_9CU' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Monforte', billar: '1', enllaç: 'https://youtube.com/channel/UCFfLvkS2hTIXop-r-wTlXcQ' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Monforte', billar: '2', enllaç: 'https://youtube.com/channel/UCTZhhkh0po7TgRmJ6qy7UUw' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Monforte', billar: '3', enllaç: 'https://youtube.com/channel/UCw4lTndxGlhu74xVbw8bkzg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Monforte', billar: '4', enllaç: 'https://youtube.com/channel/UCSCI6PC7st_sIILtW3bdCvg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Montroig', billar: '1', enllaç: 'https://youtube.com/@billar1mont-roig610?si=olgJnR83IyGn-S2R' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Montroig', billar: '2', enllaç: 'https://youtube.com/@billar2mont-roig289?si=sPikKvqnBSwR1P4w' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Montroig', billar: '3', enllaç: 'https://youtube.com/@billar3mont-roig36?si=Ysi25_SOWTAieTCR' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Adrià', billar: '1', enllaç: 'https://www.youtube.com/channel/UC8TiwIIzS1vNHd1W0Z1lpuQ' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Adrià', billar: '2', enllaç: 'https://www.youtube.com/channel/UC9xHdBNYXuj5CtbpXz28EiQ' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Adrià', billar: '3', enllaç: 'https://www.youtube.com/channel/UCnxFpglOqmIXLKPv6tf_q-g' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Adrià', billar: '4', enllaç: 'https://www.youtube.com/channel/UC4QKXDKnDqnQ31_YG5yvdDg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Feliu', billar: '1', enllaç: 'https://www.youtube.com/@cbsantfeliu1/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Feliu', billar: '2', enllaç: 'https://www.youtube.com/@cbsantfeliu2/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sant Feliu', billar: '3', enllaç: 'https://www.youtube.com/@cbsantfeliu3/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '1', enllaç: 'https://www.youtube.com/channel/UCt1s0StHWo6oyawmmxmZASw' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '2', enllaç: 'https://www.youtube.com/channel/UCwLYL5CIFXXOqaS7kJly3gQ' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '3', enllaç: 'https://www.youtube.com/channel/UC5EMAWwvg_1gsVrqEWlpixw' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '4', enllaç: 'https://www.youtube.com/channel/UCOkHTGoB6MGivKS2DBcuTTQ' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '5', enllaç: 'https://www.youtube.com/channel/UCEy8Kt3skfnGx3rv6TU1iHg' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '6', enllaç: 'https://www.youtube.com/channel/UCIy2d7-zhSNrQiJISbzKfLw' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '7', enllaç: 'https://www.youtube.com/@clubbillarsants-billar7' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Sants', billar: '8', enllaç: 'https://www.youtube.com/@clubbillarsants-billar8' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Tarragona', billar: '1', enllaç: 'https://youtube.com/channel/UCPqOow5DLA1eFcj2ji8nmyw' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Tarragona', billar: '2', enllaç: 'https://youtube.com/channel/UCUe403LWY9NGRUAglIM2Lug' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Tarragona', billar: '3', enllaç: 'https://youtube.com/channel/UCJk0IyN2gNficW43ZFFajxw' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Vic', billar: '1', enllaç: 'https://youtu.be/ytD9_b2GVsc' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Vic', billar: '2', enllaç: 'https://youtu.be/QcQqQYQZa_M' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Vic', billar: '3', enllaç: 'https://youtu.be/xRkfCNZnYAk' },
    { tipus: 'Billar en directe (Cat)', club: 'Club Billar Vic', billar: '4', enllaç: 'https://youtu.be/Z5dADQCFczY' },
    { tipus: 'Billar en directe (Cat)', club: 'Coral Colon', billar: '1', enllaç: 'https://www.youtube.com/@CoralColonBillar1/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Coral Colon', billar: '2', enllaç: 'https://www.youtube.com/@CoralColonBillar2/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Coral Colon', billar: '3', enllaç: 'https://www.youtube.com/@CoralColonBillar3/streams' },
    { tipus: 'Billar en directe (Cat)', club: 'Coral Colon', billar: '4', enllaç: 'https://www.youtube.com/@CoralColonBillar4/streams' },
    { tipus: 'Billar en directe (Esp)', club: 'Billar Sueca', billar: '', enllaç: 'https://www.youtube.com/@billarsueca8304' },
    { tipus: 'Billar en directe (Esp)', club: 'Club Billar Ayamonte', billar: '', enllaç: 'https://www.youtube.com/@clubbillarayamonte7763' },
    { tipus: 'Billar en directe (Esp)', club: 'Club Billar Baeza', billar: '', enllaç: 'https://youtube.com/@baezabillar6310?feature=shared' },
    { tipus: 'Billar en directe (Esp)', club: 'Club Billar Valladolid', billar: '', enllaç: 'https://www.youtube.com/@clubbillarvalladolid' },
    { tipus: 'Billar en directe (Esp)', club: 'Federación Billar Comunidad Valenciana', billar: '', enllaç: 'https://www.youtube.com/@federaciondebillarcomunida5284' },
    { tipus: 'Billar en directe (Esp)', club: 'Federación Española de Billar', billar: '', enllaç: 'https://www.youtube.com/@realfederacionespanoladebi1020' },
    { tipus: 'Billar en directe (Esp)', club: 'Federación Madrileña de Billar', billar: '', enllaç: 'https://www.youtube.com/@fmbvallecasmadrid6669' },
    { tipus: 'Billar en directe (Int)', club: 'Billar en casa HD', billar: '', enllaç: 'https://youtube.com/@billarencasahd123?feature=shared' },
    { tipus: 'Billar en directe (Int)', club: 'Club Billar Pézenas', billar: '', enllaç: 'https://www.youtube.com/@BillardPezenas' },
    { tipus: 'Billar en directe (Int)', club: 'Kozoom', billar: '', enllaç: 'https://www.youtube.com/@KozoomTV' },
    { tipus: 'Billar en directe (Int)', club: 'PBA', billar: '', enllaç: 'https://www.youtube.com/@pbatv' },
    { tipus: 'Billar en directe (Int)', club: 'PBA', billar: '', enllaç: 'https://www.youtube.com/@billiards-pbatv' },
    { tipus: 'Documents', club: 'Esteve Mata (joc curt)', billar: '', enllaç: 'http://www.estevemata.com/images/aprenjugar/dosierlibreycuadro47.pdf' },
    { tipus: 'Tutorials billar', club: '3 cushion billiards', billar: '', enllaç: 'https://www.youtube.com/@3cushionbilliards769' },
    { tipus: 'Tutorials billar', club: 'Alexandre Salazar', billar: '', enllaç: 'https://www.youtube.com/@billarvirtualsalazar2889' },
    { tipus: 'Tutorials billar', club: 'AM Billiard academy', billar: '', enllaç: 'https://www.youtube.com/@ambilliardacademy' },
    { tipus: 'Tutorials billar', club: 'Billiard Hakase (coreà)', billar: '', enllaç: 'https://www.youtube.com/@billiard.hakase' },
    { tipus: 'Tutorials billar', club: 'El flaco billarista', billar: '', enllaç: 'https://www.youtube.com/@elflacobillarista' },
    { tipus: 'Tutorials billar', club: 'El profe de billar', billar: '', enllaç: 'https://www.youtube.com/@elprofedebillar' },
    { tipus: 'Tutorials billar', club: 'Escuela de 3 bandas', billar: '', enllaç: 'https://www.youtube.com/@escuelade3bandasparatodos' },
    { tipus: 'Tutorials billar', club: 'Fone Jr', billar: '', enllaç: 'https://www.youtube.com/@fone_jr' },
    { tipus: 'Tutorials billar', club: 'Fred Caudron', billar: '', enllaç: 'https://www.youtube.com/@FredCaudron' },
    { tipus: 'Tutorials billar', club: 'GJ Billiard (Holandès)', billar: '', enllaç: 'https://www.youtube.com/@GJBilliards' },
    { tipus: 'Tutorials billar', club: 'HT Billiards (Pool)', billar: '', enllaç: 'https://www.youtube.com/@htbilliards' },
    { tipus: 'Tutorials billar', club: 'hwanjuTV (coreà)', billar: '', enllaç: 'https://www.youtube.com/@hwanjuTV' },
    { tipus: 'Tutorials billar', club: 'Jaume Carreras', billar: '', enllaç: 'https://youtube.com/@jaumecarreras222?feature=shared' },
    { tipus: 'Tutorials billar', club: 'Les billes en paquet (francès)', billar: '', enllaç: 'https://www.youtube.com/@lesbillesenpaquet' },
    { tipus: 'Tutorials billar', club: 'Mike\'s life Biljardstudio (holandès)', billar: '', enllaç: 'https://www.youtube.com/@LiveBiljartstudioMikeHofland' },
    { tipus: 'Tutorials billar', club: 'Monpetitbillard (francès)', billar: '', enllaç: 'https://www.youtube.com/@monpetitbillard' },
    { tipus: 'Tutorials billar', club: 'Night Cafe (anglès/turc)', billar: '', enllaç: 'https://www.youtube.com/c/NightCaf%C3%A9Billiard' },
    { tipus: 'Tutorials billar', club: 'sybazzar (coreà)', billar: '', enllaç: 'https://www.youtube.com/@%EC%97%90%EC%8A%A4%EC%99%80%EC%9D%B4%EC%8A%A4%ED%8F%AC%EC%B8%A0' },
    { tipus: 'Tutorials billar', club: 'Timo Peters Billiards (holandès)', billar: '', enllaç: 'https://www.youtube.com/@TimoPetersBilliards' },
    { tipus: 'Tutorials billar', club: 'Tres Bandas (Esp)', billar: '', enllaç: 'https://www.youtube.com/@TresBandas_2024' },
    { tipus: 'Tutorials billar', club: 'Yeu Bida 3C (vietnamita)', billar: '', enllaç: 'https://www.youtube.com/@YeuBida3C' }
  ];

  // Carregar enllaços multimedia des de la BD
  async function loadMultimediaLinks() {
    loading = true;
    error = null;

    try {
      const { data, error: fetchError } = await supabase
        .from('multimedia_links')
        .select('*')
        .order('tipus', { ascending: true })
        .order('club', { ascending: true })
        .order('billar', { ascending: true });

      if (fetchError) {
        console.error('Error loading multimedia links:', fetchError);
        // Utilitzar dades fallback si hi ha error
        multimediaData = fallbackData;
        error = 'Error carregant enllaços. Mostrant dades predeterminades.';
      } else {
        // Convertir 'enllac' de la BD a 'enllaç' per compatibilitat
        multimediaData = data.map((item: any) => ({
          ...item,
          enllaç: item.enllac
        }));
        console.log(`✅ Loaded ${multimediaData.length} multimedia links`);
      }
    } catch (err) {
      console.error('Exception loading multimedia links:', err);
      multimediaData = fallbackData;
      error = 'Error carregant enllaços. Mostrant dades predeterminades.';
    } finally {
      loading = false;
    }
  }

  // Obrir formulari per afegir nou enllaç
  function openAddForm() {
    editingLink = null;
    formTipus = '';
    formClub = '';
    formBillar = '';
    formEnllac = '';
    showAddForm = true;
  }

  // Obrir formulari per editar enllaç
  function openEditForm(link: any) {
    editingLink = link;
    formTipus = link.tipus;
    formClub = link.club;
    formBillar = link.billar || '';
    formEnllac = link.enllac || link.enllaç;
    showAddForm = true;
  }

  // Tancar formulari
  function closeForm() {
    showAddForm = false;
    editingLink = null;
    formTipus = '';
    formClub = '';
    formBillar = '';
    formEnllac = '';
  }

  // Guardar enllaç (crear o actualitzar)
  async function saveLink() {
    if (!formTipus || !formClub || !formEnllac) {
      alert('Si us plau, omple tots els camps obligatoris');
      return;
    }

    loading = true;

    try {
      if (editingLink) {
        // Actualitzar enllaç existent
        const { error: updateError } = await supabase
          .from('multimedia_links')
          .update({
            tipus: formTipus,
            club: formClub,
            billar: formBillar,
            enllac: formEnllac
          })
          .eq('id', editingLink.id);

        if (updateError) throw updateError;
        console.log('✅ Link updated successfully');
      } else {
        // Crear nou enllaç
        const { error: insertError } = await supabase
          .from('multimedia_links')
          .insert({
            tipus: formTipus,
            club: formClub,
            billar: formBillar,
            enllac: formEnllac
          });

        if (insertError) throw insertError;
        console.log('✅ Link created successfully');
      }

      closeForm();
      await loadMultimediaLinks();
    } catch (err: any) {
      console.error('Error saving link:', err);
      alert(`Error guardant enllaç: ${err.message}`);
    } finally {
      loading = false;
    }
  }

  // Eliminar enllaç
  async function deleteLink(link: any) {
    if (!confirm(`Estàs segur que vols eliminar l'enllaç "${link.club} - ${link.billar || 'General'}"?`)) {
      return;
    }

    loading = true;

    try {
      const { error: deleteError } = await supabase
        .from('multimedia_links')
        .delete()
        .eq('id', link.id);

      if (deleteError) throw deleteError;

      console.log('✅ Link deleted successfully');
      await loadMultimediaLinks();
    } catch (err: any) {
      console.error('Error deleting link:', err);
      alert(`Error eliminant enllaç: ${err.message}`);
    } finally {
      loading = false;
    }
  }

  onMount(async () => {
    await loadMultimediaLinks();
  });

  // Estats de col·lapse
  let collapsedTypes: Record<string, boolean> = {};
  let collapsedClubs: Record<string, Record<string, boolean>> = {};

  // Funció per agrupar per tipus
  $: groupedData = multimediaData.reduce((acc, item) => {
    if (!acc[item.tipus]) {
      acc[item.tipus] = [];
    }
    acc[item.tipus].push(item);
    return acc;
  }, {} as Record<string, typeof multimediaData>);

  // Agrupar per tipus i després per club dins de cada tipus
  $: sortedGroups = Object.keys(groupedData).sort().reduce((acc, tipus) => {
    const typeItems = groupedData[tipus];
    
    // Agrupar per club dins del tipus
    const clubGroups = typeItems.reduce((clubAcc, item) => {
      const clubName = item.club || 'Sense club';
      if (!clubAcc[clubName]) {
        clubAcc[clubName] = [];
      }
      clubAcc[clubName].push(item);
      return clubAcc;
    }, {} as Record<string, typeof multimediaData>);

    // Ordenar clubs i elements dins de cada club
    const sortedClubGroups = Object.keys(clubGroups).sort().reduce((clubAcc, club) => {
      clubAcc[club] = clubGroups[club].sort((a, b) => {
        if (a.billar < b.billar) return -1;
        if (a.billar > b.billar) return 1;
        return 0;
      });
      return clubAcc;
    }, {} as Record<string, typeof multimediaData>);

    acc[tipus] = sortedClubGroups;
    return acc;
  }, {} as Record<string, Record<string, typeof multimediaData>>);

  // Inicialitzar estats de col·lapse (tots col·lapsats per defecte)
  $: {
    Object.keys(sortedGroups).forEach(tipus => {
      if (!(tipus in collapsedTypes)) {
        collapsedTypes[tipus] = true;
      }
      if (!(tipus in collapsedClubs)) {
        collapsedClubs[tipus] = {};
      }
      Object.keys(sortedGroups[tipus]).forEach(club => {
        if (!(club in collapsedClubs[tipus])) {
          collapsedClubs[tipus][club] = true;
        }
      });
    });
  }

  function toggleType(tipus: string) {
    collapsedTypes[tipus] = !collapsedTypes[tipus];
  }

  function toggleClub(tipus: string, club: string) {
    collapsedClubs[tipus][club] = !collapsedClubs[tipus][club];
  }

  function expandAll() {
    Object.keys(sortedGroups).forEach(tipus => {
      collapsedTypes[tipus] = false;
      Object.keys(sortedGroups[tipus]).forEach(club => {
        collapsedClubs[tipus][club] = false;
      });
    });
  }

  function collapseAll() {
    Object.keys(sortedGroups).forEach(tipus => {
      collapsedTypes[tipus] = true;
      Object.keys(sortedGroups[tipus]).forEach(club => {
        collapsedClubs[tipus][club] = true;
      });
    });
  }

  function getTypeIcon(tipus: string) {
    if (tipus.includes('Web')) return '🌐';
    if (tipus.includes('directe')) return '📺';
    if (tipus.includes('Documents')) return '📄';
    if (tipus.includes('Tutorials')) return '🎓';
    return '📎';
  }

  function getTypeColor(tipus: string) {
    if (tipus.includes('Web')) return 'blue';
    if (tipus.includes('directe (Cat)')) return 'green';
    if (tipus.includes('directe (Esp)')) return 'yellow';
    if (tipus.includes('directe (Int)')) return 'purple';
    if (tipus.includes('Documents')) return 'red';
    if (tipus.includes('Tutorials')) return 'indigo';
    return 'gray';
  }
</script>

<svelte:head>
  <title>Multimedia - Foment Martinenc</title>
</svelte:head>

<div class="max-w-7xl mx-auto p-4">
  <div class="mb-8">
    <div class="flex items-center justify-between mb-4">
      <div>
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Multimedia</h1>
        <p class="text-lg text-gray-600">
          Enllaços útils per al món del billar: canals en directe, tutorials, documents i més.
        </p>
      </div>
      <div class="flex gap-2">
        {#if $user}
          <button
            on:click={openAddForm}
            class="px-4 py-2 text-sm bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors font-medium"
          >
            ➕ Afegir enllaç
          </button>
        {/if}
        <button
          on:click={expandAll}
          class="px-4 py-2 text-sm bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-colors"
        >
          Expandir tot
        </button>
        <button
          on:click={collapseAll}
          class="px-4 py-2 text-sm bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
        >
          Col·lapsar tot
        </button>
      </div>
    </div>

    {#if error}
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
        <p class="text-sm text-yellow-800">{error}</p>
      </div>
    {/if}

    {#if loading}
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
        <div class="flex items-center gap-2">
          <svg class="w-5 h-5 animate-spin text-blue-600" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-sm text-blue-800">Carregant enllaços...</span>
        </div>
      </div>
    {/if}
  </div>

  <div class="space-y-6">
    {#each Object.entries(sortedGroups) as [tipus, clubGroups]}
      {@const typeColor = getTypeColor(tipus)}
      {@const typeIcon = getTypeIcon(tipus)}
      {@const totalItems = Object.values(clubGroups).flat().length}
      
      <div class="bg-white shadow-sm rounded-lg border border-gray-200">
        <!-- Header del tipus (col·lapsable) -->
        <button
          on:click={() => toggleType(tipus)}
          class="w-full px-6 py-4 border-b rounded-t-lg text-left hover:bg-opacity-80 transition-colors" 
          class:bg-blue-50={typeColor === 'blue'} 
          class:border-blue-200={typeColor === 'blue'}
          class:bg-green-50={typeColor === 'green'} 
          class:border-green-200={typeColor === 'green'}
          class:bg-yellow-50={typeColor === 'yellow'} 
          class:border-yellow-200={typeColor === 'yellow'}
          class:bg-purple-50={typeColor === 'purple'} 
          class:border-purple-200={typeColor === 'purple'}
          class:bg-red-50={typeColor === 'red'} 
          class:border-red-200={typeColor === 'red'}
          class:bg-indigo-50={typeColor === 'indigo'} 
          class:border-indigo-200={typeColor === 'indigo'}
          class:bg-gray-50={typeColor === 'gray'} 
          class:border-gray-200={typeColor === 'gray'}
        >
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-semibold flex items-center gap-2"
                class:text-blue-800={typeColor === 'blue'}
                class:text-green-800={typeColor === 'green'}
                class:text-yellow-800={typeColor === 'yellow'}
                class:text-purple-800={typeColor === 'purple'}
                class:text-red-800={typeColor === 'red'}
                class:text-indigo-800={typeColor === 'indigo'}
                class:text-gray-800={typeColor === 'gray'}>
              <span class="text-2xl">{typeIcon}</span>
              {tipus}
              <span class="text-sm font-normal ml-2"
                    class:text-blue-600={typeColor === 'blue'}
                    class:text-green-600={typeColor === 'green'}
                    class:text-yellow-600={typeColor === 'yellow'}
                    class:text-purple-600={typeColor === 'purple'}
                    class:text-red-600={typeColor === 'red'}
                    class:text-indigo-600={typeColor === 'indigo'}
                    class:text-gray-600={typeColor === 'gray'}>
                ({totalItems} {totalItems === 1 ? 'enllaç' : 'enllaços'})
              </span>
            </h2>
            <svg 
              class="w-5 h-5 transition-transform duration-200"
              class:rotate-180={!collapsedTypes[tipus]}
              class:text-blue-600={typeColor === 'blue'}
              class:text-green-600={typeColor === 'green'}
              class:text-yellow-600={typeColor === 'yellow'}
              class:text-purple-600={typeColor === 'purple'}
              class:text-red-600={typeColor === 'red'}
              class:text-indigo-600={typeColor === 'indigo'}
              class:text-gray-600={typeColor === 'gray'}
              fill="none" stroke="currentColor" viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
            </svg>
          </div>
        </button>
        
        <!-- Contingut del tipus -->
        {#if !collapsedTypes[tipus]}
          <div transition:slide={{ duration: 300 }} class="border-t border-gray-100">
            <div class="space-y-2 p-4">
              {#each Object.entries(clubGroups) as [club, items]}
                <!-- Header del club (col·lapsable) -->
                <div class="bg-gray-50 rounded-lg border border-gray-200">
                  <button
                    on:click={() => toggleClub(tipus, club)}
                    class="w-full px-4 py-3 text-left hover:bg-gray-100 transition-colors rounded-lg"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="font-medium text-gray-900 flex items-center gap-2">
                        <span class="text-lg">🏛️</span>
                        {club}
                        <span class="text-sm font-normal text-gray-600">
                          ({items.length} {items.length === 1 ? 'enllaç' : 'enllaços'})
                        </span>
                      </h3>
                      <svg 
                        class="w-4 h-4 text-gray-500 transition-transform duration-200"
                        class:rotate-180={!collapsedClubs[tipus][club]}
                        fill="none" stroke="currentColor" viewBox="0 0 24 24"
                      >
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                      </svg>
                    </div>
                  </button>
                  
                  <!-- Contingut del club -->
                  {#if !collapsedClubs[tipus][club]}
                    <div transition:slide={{ duration: 200 }} class="px-4 pb-3">
                      <div class="overflow-x-auto">
                        <table class="min-w-full">
                          <thead>
                            <tr class="border-b border-gray-200">
                              {#if items.some(item => item.billar)}
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                                  Billar
                                </th>
                              {/if}
                              <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                                Enllaç
                              </th>
                              {#if $user}
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                                  Accions
                                </th>
                              {/if}
                            </tr>
                          </thead>
                          <tbody class="divide-y divide-gray-100">
                            {#each items as item}
                              <tr class="hover:bg-gray-50">
                                {#if items.some(i => i.billar)}
                                  <td class="px-3 py-2 text-sm text-gray-900 font-medium">
                                    {item.billar || '—'}
                                  </td>
                                {/if}
                                <td class="px-3 py-2 text-sm">
                                  <a
                                    href={item.enllaç}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    class="hover:underline flex items-center gap-2"
                                    class:text-blue-600={typeColor === 'blue'}
                                    class:hover:text-blue-800={typeColor === 'blue'}
                                    class:text-green-600={typeColor === 'green'}
                                    class:hover:text-green-800={typeColor === 'green'}
                                    class:text-yellow-600={typeColor === 'yellow'}
                                    class:hover:text-yellow-800={typeColor === 'yellow'}
                                    class:text-purple-600={typeColor === 'purple'}
                                    class:hover:text-purple-800={typeColor === 'purple'}
                                    class:text-red-600={typeColor === 'red'}
                                    class:hover:text-red-800={typeColor === 'red'}
                                    class:text-indigo-600={typeColor === 'indigo'}
                                    class:hover:text-indigo-800={typeColor === 'indigo'}
                                    class:text-gray-600={typeColor === 'gray'}
                                    class:hover:text-gray-800={typeColor === 'gray'}
                                  >
                                    <span class="break-all">{item.enllaç}</span>
                                    <svg class="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                                    </svg>
                                  </a>
                                </td>
                                {#if $user}
                                  <td class="px-3 py-2 text-sm">
                                    <div class="flex gap-2">
                                      <button
                                        on:click={() => openEditForm(item)}
                                        class="text-blue-600 hover:text-blue-800 text-xs font-medium"
                                      >
                                        Editar
                                      </button>
                                      <button
                                        on:click={() => deleteLink(item)}
                                        class="text-red-600 hover:text-red-800 text-xs font-medium"
                                      >
                                        Eliminar
                                      </button>
                                    </div>
                                  </td>
                                {/if}
                              </tr>
                            {/each}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    {/each}
  </div>

  <!-- Estadístiques -->
  <div class="mt-8 bg-gray-50 rounded-lg p-6">
    <h3 class="text-lg font-semibold text-gray-900 mb-4">Resum</h3>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="text-center">
        <div class="text-2xl font-bold text-blue-600">{multimediaData.length}</div>
        <div class="text-sm text-gray-600">Total d'enllaços</div>
      </div>
      <div class="text-center">
        <div class="text-2xl font-bold text-green-600">{Object.keys(sortedGroups).length}</div>
        <div class="text-sm text-gray-600">Categories</div>
      </div>
      <div class="text-center">
        <div class="text-2xl font-bold text-purple-600">
          {new Set(multimediaData.map(item => item.club).filter(club => club)).size}
        </div>
        <div class="text-sm text-gray-600">Clubs diferents</div>
      </div>
    </div>
  </div>
</div>

<!-- Modal per afegir/editar enllaç -->
{#if showAddForm}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
    <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <div class="p-6">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-2xl font-bold text-gray-900">
            {editingLink ? 'Editar enllaç' : 'Afegir nou enllaç'}
          </h2>
          <button
            on:click={closeForm}
            class="text-gray-400 hover:text-gray-600 text-2xl"
          >
            ×
          </button>
        </div>

        <form on:submit|preventDefault={saveLink} class="space-y-4">
          <!-- Tipus -->
          <div>
            <label for="tipus" class="block text-sm font-medium text-gray-700 mb-2">
              Tipus *
            </label>
            <select
              id="tipus"
              bind:value={formTipus}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">Selecciona un tipus</option>
              <option value="Web del Foment">Web del Foment</option>
              <option value="Billar en directe (Cat)">Billar en directe (Cat)</option>
              <option value="Billar en directe (Esp)">Billar en directe (Esp)</option>
              <option value="Billar en directe (Int)">Billar en directe (Int)</option>
              <option value="Documents">Documents</option>
              <option value="Tutorials billar">Tutorials billar</option>
            </select>
          </div>

          <!-- Club -->
          <div>
            <label for="club" class="block text-sm font-medium text-gray-700 mb-2">
              Club / Nom *
            </label>
            <input
              id="club"
              type="text"
              bind:value={formClub}
              required
              placeholder="Ex: Club Billar Barcelona"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <!-- Billar -->
          <div>
            <label for="billar" class="block text-sm font-medium text-gray-700 mb-2">
              Número de billar (opcional)
            </label>
            <input
              id="billar"
              type="text"
              bind:value={formBillar}
              placeholder="Ex: 1, 2, 3..."
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">Deixa en blanc si no és aplicable</p>
          </div>

          <!-- Enllaç -->
          <div>
            <label for="enllac" class="block text-sm font-medium text-gray-700 mb-2">
              Enllaç *
            </label>
            <input
              id="enllac"
              type="url"
              bind:value={formEnllac}
              required
              placeholder="https://example.com"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">URL completa incloent https://</p>
          </div>

          <!-- Botons -->
          <div class="flex gap-3 pt-4">
            <button
              type="submit"
              disabled={loading}
              class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"
            >
              {loading ? 'Guardant...' : (editingLink ? 'Actualitzar' : 'Afegir')}
            </button>
            <button
              type="button"
              on:click={closeForm}
              disabled={loading}
              class="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-300 transition-colors disabled:bg-gray-100 disabled:cursor-not-allowed"
            >
              Cancel·lar
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
{/if}