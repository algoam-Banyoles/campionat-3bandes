<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/stores/auth';
  import { supabase } from '$lib/supabaseClient';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import DragDropInscriptions from '$lib/components/campionats-socials/DragDropInscriptions.svelte';
  import AutoCategoryAssignment from '$lib/components/campionats-socials/AutoCategoryAssignment.svelte';
  import CategorySetup from '$lib/components/campionats-socials/CategorySetup.svelte';
  import CalendarGenerator from '$lib/components/admin/CalendarGenerator.svelte';
  import CalendarEditor from '$lib/components/admin/CalendarEditor.svelte';
  import PlayerSelfRestrictionsEditor from '$lib/components/general/PlayerSelfRestrictionsEditor.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';

  let loading = true;
  let error: string | null = null;
  let successMessage: string | null = null;
  let events: any[] = [];
  let selectedEventId: string = '';
  let inscriptions: any[] = [];
  let categories: any[] = [];
  let showAddPlayer = false;
  let selectedSociId: string = '';
  let socis: any[] = [];
  let addingInscription = false;
  let processingAssignments = false;
  let selectedInscriptions: string[] = [];
  let bulkDeleteMode = false;
  let useIntelligentMovement = true;

  // Player restrictions editor variables
  let restrictionsEditorOpen = false;
  let selectedInscriptionForRestrictions = null;

  // Sorting and filtering variables
  let sortField = '';
  let sortDirection = 'asc';
  let filterName = '';
  let filterCategory = '';
  let filterStatus = '';

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const competitionTypes = {
    'lliga_social': 'Lliga Social',
    'eliminatories': 'Eliminatòries'
  };

  const statusNames = {
    'planificacio': 'Planificació',
    'inscripcions': 'Inscripcions Obertes',
    'pendent_validacio': 'Pendent Validació',
    'validat': 'Validat',
    'en_curs': 'En Curs',
    'finalitzat': 'Finalitzat'
  };

  // Sorting and filtering functions
  function handleSort(field: string) {
    if (sortField === field) {
      sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      sortField = field;
      sortDirection = 'asc';
    }
  }


  // Reactive statements for filtered and sorted inscriptions
  $: filteredAndSortedInscriptions = (() => {
    // Force reactivity by referencing all filter variables
    const nameFilter = filterName;
    const categoryFilter = filterCategory;
    const statusFilter = filterStatus;
    const sort = sortField;
    const direction = sortDirection;

    // Apply filters
    let result = inscriptions.filter(inscription => {
      // Name filter
      if (nameFilter && nameFilter.trim()) {
        const fullName = `${inscription.socis?.nom || ''} ${inscription.socis?.cognoms || ''}`.toLowerCase();
        if (!fullName.includes(nameFilter.toLowerCase())) {
          return false;
        }
      }

      // Category filter
      if (categoryFilter) {
        if (categoryFilter === 'unassigned') {
          if (inscription.categoria_assignada_id) return false;
        } else {
          if (inscription.categoria_assignada?.nom !== categoryFilter) return false;
        }
      }

      // Status filter
      if (statusFilter) {
        switch (statusFilter) {
          case 'confirmed':
            if (!inscription.confirmat) return false;
            break;
          case 'pending':
            if (inscription.confirmat) return false;
            break;
          case 'paid':
            if (!inscription.pagat) return false;
            break;
          case 'unpaid':
            if (inscription.pagat) return false;
            break;
        }
      }

      return true;
    });

    // Apply sorting
    if (sort) {
      result = result.sort((a, b) => {
        let aValue, bValue;

        switch (sort) {
          case 'name':
            aValue = `${a.socis?.nom || ''} ${a.socis?.cognoms || ''}`.toLowerCase();
            bValue = `${b.socis?.nom || ''} ${b.socis?.cognoms || ''}`.toLowerCase();
            break;
          case 'date':
            aValue = new Date(a.created_at);
            bValue = new Date(b.created_at);
            break;
          case 'category':
            aValue = a.categoria_assignada?.nom || 'zz';
            bValue = b.categoria_assignada?.nom || 'zz';
            break;
          case 'status':
            const statusOrder = { confirmat: a.confirmat ? 1 : 0, pagat: a.pagat ? 1 : 0 };
            const statusOrderB = { confirmat: b.confirmat ? 1 : 0, pagat: b.pagat ? 1 : 0 };
            aValue = statusOrder.confirmat + statusOrder.pagat;
            bValue = statusOrderB.confirmat + statusOrderB.pagat;
            break;
          default:
            return 0;
        }

        if (aValue < bValue) return direction === 'asc' ? -1 : 1;
        if (aValue > bValue) return direction === 'asc' ? 1 : -1;
        return 0;
      });
    }

    return result;
  })();

  onMount(async () => {
    const u = $user;
    if (!u?.email) {
      goto('/login');
      return;
    }

    try {
      loading = true;
      await Promise.all([loadEvents(), loadSocis()]);
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadEvents() {
    // Load only social events (not continuous ranking)
    const { data, error: eventsError } = await supabase
      .from('events')
      .select('*')
      .in('tipus_competicio', ['lliga_social', 'eliminatories'])
      .eq('actiu', true)
      .order('creat_el', { ascending: false });

    if (eventsError) throw eventsError;
    events = data || [];

    // Auto-select first event if available
    if (events.length > 0 && !selectedEventId) {
      selectedEventId = events[0].id;
      await loadEventData();
    }
  }

  async function loadSocis() {
    console.log('=== Loading socis from client-side ===');

    // First test basic connection
    console.log('Testing basic connection to socis table...');
    const { data: testData, error: testError } = await supabase
      .from('socis')
      .select('count(*)')
      .limit(1);

    console.log('Connection test result:', { data: testData, error: testError });

    // Load active socis
    console.log('Loading socis with full query...');
    const { data: socisData, error: socisError } = await supabase
      .from('socis')
      .select('numero_soci, nom, cognoms, email')
      .eq('de_baixa', false)
      .order('nom');

    if (socisError) {
      console.error('Error loading socis:', socisError);
      throw socisError;
    }

    console.log(`Loaded ${socisData?.length || 0} socis`);

    if (!socisData || socisData.length === 0) {
      socis = [];
      return;
    }

    // Now load historical averages using correct column name
    // Filter by modality and last two seasons
    console.log('Loading historical averages...');

    // First, let's see what modalities exist in the database
    const { data: allModalitiesData } = await supabase
      .from('mitjanes_historiques')
      .select('modalitat')
      .limit(100);

    if (allModalitiesData) {
      const uniqueModalitiesInDB = [...new Set(allModalitiesData.map(m => m.modalitat))];
      console.log('All modalities in database:', uniqueModalitiesInDB);
    }

    // Get current event modality
    let eventModality = null;
    if (selectedEventId) {
      const selectedEvent = events.find(e => e.id === selectedEventId);
      eventModality = selectedEvent?.modalitat;
    }

    // Calculate last two seasons
    // Temporada 2024/2025 = any 2025, Temporada 2023/2024 = any 2024
    const currentYear = new Date().getFullYear();
    const lastTwoYears = [currentYear, currentYear - 1];

    console.log(`Filtering by modality: ${eventModality}, years: ${lastTwoYears}`);

    let query = supabase
      .from('mitjanes_historiques')
      .select('soci_id, mitjana, year, modalitat')
      .in('year', lastTwoYears);

    // Only filter by modality if event is selected and has modality
    if (eventModality) {
      // Map technical names to display names used in mitjanes_historiques
      const modalityMapping = {
        'tres_bandes': '3 BANDES',
        'lliure': 'LLIURE',
        'banda': 'BANDA'
      };

      const historialModality = modalityMapping[eventModality] || eventModality.toUpperCase();
      console.log(`Mapping ${eventModality} -> ${historialModality}`);
      query = query.eq('modalitat', historialModality);
    }

    const { data: mitjanes, error: mitjErr } = await query;

    if (mitjErr) {
      console.error('Error loading mitjanes_historiques:', mitjErr);
    } else {
      console.log(`Loaded ${mitjanes?.length || 0} historical averages`);
      if (mitjanes && mitjanes.length > 0) {
        console.log('Sample mitjana:', mitjanes[0]);

        // Show unique modalities to debug
        const uniqueModalities = [...new Set(mitjanes.map(m => m.modalitat))];
        console.log('Unique modalities found:', uniqueModalities);
      }
    }

    // Combine socis data with their best historical averages
    socis = socisData.map(soci => {
      let bestMitjana = null;

      if (mitjanes) {
        const playerMitjanes = mitjanes.filter(m => m.soci_id === soci.numero_soci);

        if (playerMitjanes.length > 0) {
          // Get the best (highest) average from the last two years
          bestMitjana = Math.max(...playerMitjanes.map(m => parseFloat(m.mitjana)));

          // Log for first few socis to debug
          if (soci.numero_soci <= 3) {
            console.log(`Soci ${soci.numero_soci} (${soci.nom}):`, {
              playerMitjanes: playerMitjanes.map(m => ({ year: m.year, mitjana: m.mitjana })),
              bestMitjana: bestMitjana
            });
          }
        }
      }

      return {
        numero_soci: soci.numero_soci,
        nom: soci.nom,
        cognoms: soci.cognoms || '',
        email: soci.email,
        historicalAverage: bestMitjana
      };
    });

    console.log('Socis loaded:', socis.slice(0, 2));
  }

  async function loadEventData() {
    if (!selectedEventId) {
      console.log('⚠️ No event selected, skipping data load');
      return;
    }

    console.log('🚀 Loading event data for:', selectedEventId);

    try {
      await Promise.all([loadInscriptions(), loadCategories()]);
      console.log('✅ Event data loaded successfully');
    } catch (e) {
      console.error('❌ Error loading event data:', e);
      error = formatSupabaseError(e);
    }
  }

  async function loadInscriptions() {
    console.log('🔄 Loading inscriptions for event:', selectedEventId);

    const { data, error: inscriptionsError } = await supabase
      .from('inscripcions')
      .select(`
        *,
        socis (
          numero_soci,
          nom,
          cognoms,
          email
        ),
        categoria_assignada:categories (
          nom,
          ordre_categoria
        )
      `)
      .eq('event_id', selectedEventId)
      .order('data_inscripcio', { ascending: false });

    if (inscriptionsError) {
      console.error('❌ Error loading inscriptions:', inscriptionsError);
      throw inscriptionsError;
    }

    inscriptions = data || [];
    console.log('✅ Inscriptions loaded:', inscriptions.length, 'inscriptions');
  }

  async function loadCategories() {

    const { data, error: categoriesError } = await supabase
      .from('categories')
      .select('*')
      .eq('event_id', selectedEventId)
      .order('ordre_categoria');

    if (categoriesError) throw categoriesError;
    categories = data || [];
  }

  async function updateInscriptionCategory(inscriptionId: string, categoryId: string | null) {
    try {
  
      const { error } = await supabase
        .from('inscripcions')
        .update({ categoria_assignada_id: categoryId })
        .eq('id', inscriptionId);

      if (error) throw error;

      // Reload inscriptions
      await loadInscriptions();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function updateInscriptionStatus(inscriptionId: string, field: 'confirmat' | 'pagat', value: boolean) {
    try {
  
      const { error } = await supabase
        .from('inscripcions')
        .update({ [field]: value })
        .eq('id', inscriptionId);

      if (error) throw error;

      // Reload inscriptions
      await loadInscriptions();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function deleteInscription(inscriptionId: string) {
    if (!confirm('Estàs segur que vols eliminar aquesta inscripció?')) return;

    try {
  
      const { error } = await supabase
        .from('inscripcions')
        .delete()
        .eq('id', inscriptionId);

      if (error) throw error;

      // Reload inscriptions
      await loadInscriptions();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function handleInscribe(event) {
    const { soci, categoryId } = event.detail;

    try {
  
      const inscriptionData = {
        event_id: selectedEventId,
        soci_numero: soci.numero_soci,
        preferencies_dies: [],
        preferencies_hores: [],
        restriccions_especials: null,
        observacions: soci.historicalAverage
          ? `Mitjana històrica: ${soci.historicalAverage.toFixed(2)}`
          : 'Sense mitjana històrica',
        confirmat: true, // Admin inscription is auto-confirmed
        pagat: false,
        categoria_assignada_id: categoryId
      };

      const { error: inscriptionError } = await supabase
        .from('inscripcions')
        .insert([inscriptionData]);

      if (inscriptionError) throw inscriptionError;

      // Reload data
      await Promise.all([loadInscriptions(), loadSocis()]);

    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function handleMoveInscription(event) {
    const { inscriptionId, categoryId } = event.detail;

    try {
  
      const { error } = await supabase
        .from('inscripcions')
        .update({ categoria_assignada_id: categoryId })
        .eq('id', inscriptionId);

      if (error) throw error;

      // Reload inscriptions
      await loadInscriptions();

    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function handleRemoveInscription(event) {
    const { inscriptionId } = event.detail;

    if (!confirm('Estàs segur que vols eliminar aquesta inscripció?')) return;

    try {
  
      const { error } = await supabase
        .from('inscripcions')
        .delete()
        .eq('id', inscriptionId);

      if (error) throw error;

      // Reload data
      await Promise.all([loadInscriptions(), loadSocis()]);

    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function handleApplyAssignments(event) {
    const { assignments } = event.detail;

    try {
      processingAssignments = true;

      // Aplicar totes les assignacions en paral·lel
      const updatePromises = assignments.map(({ inscriptionId, categoryId }) =>
        supabase
          .from('inscripcions')
          .update({ categoria_assignada_id: categoryId })
          .eq('id', inscriptionId)
      );

      const results = await Promise.all(updatePromises);

      // Comprovar errors
      const errors = results.filter(result => result.error);
      if (errors.length > 0) {
        throw new Error(`Errors en ${errors.length} assignacions`);
      }

      // Reload inscriptions
      await loadInscriptions();

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      processingAssignments = false;
    }
  }

  async function handleCategoriesCreated() {
    // Reload both categories and inscriptions when categories are created
    try {
      await Promise.all([loadCategories(), loadInscriptions()]);
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  function handleCategorySetupError(event) {
    error = event.detail.message;
  }

  function handleCalendarCreated(event) {
    console.log('Calendari creat:', event.detail);
    // Opcional: recarregar dades o mostrar missatge d'èxit
  }

  async function handleIntelligentMovementCompleted(event) {
    const { movements, totalMoved, message } = event.detail;

    console.log('Intelligent movement completed:', { movements, totalMoved });

    try {
      // Recarregar inscripcions per mostrar els canvis
      await loadInscriptions();

      // Mostrar missatge d'èxit
      successMessage = message;
      setTimeout(() => successMessage = null, 5000);

    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  function handleDragDropError(event) {
    error = event.detail.message;
  }

  async function handleRegenerateCalendar() {
    try {
      // Eliminar calendari existent
      const { error: deleteError } = await supabase
        .from('calendari_partides')
        .delete()
        .eq('event_id', selectedEventId);

      if (deleteError) throw deleteError;

      successMessage = 'Calendari eliminat. Pots generar un nou calendari amb el component generador.';
      setTimeout(() => successMessage = null, 5000);

    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  function openRestrictionsEditor(inscription) {
    selectedInscriptionForRestrictions = inscription;
    restrictionsEditorOpen = true;
  }

  function handleRestrictionsUpdated(event) {
    const { id, preferencies_dies, preferencies_hores, restriccions_especials } = event.detail;

    // Actualitzar la inscripció local
    inscriptions = inscriptions.map(inscription => {
      if (inscription.id === id) {
        return {
          ...inscription,
          preferencies_dies,
          preferencies_hores,
          restriccions_especials
        };
      }
      return inscription;
    });

    console.log('Restriccions actualitzades per jugador:', id);
  }

  function toggleBulkDeleteMode() {
    bulkDeleteMode = !bulkDeleteMode;
    if (!bulkDeleteMode) {
      selectedInscriptions = [];
    }
  }

  function toggleInscriptionSelection(inscriptionId: string) {
    if (selectedInscriptions.includes(inscriptionId)) {
      selectedInscriptions = selectedInscriptions.filter(id => id !== inscriptionId);
    } else {
      selectedInscriptions = [...selectedInscriptions, inscriptionId];
    }
  }

  function selectAllInscriptions() {
    selectedInscriptions = inscriptions.map(i => i.id);
  }

  function clearSelection() {
    selectedInscriptions = [];
  }

  async function bulkDeleteInscriptions() {
    if (selectedInscriptions.length === 0) return;

    const confirmMessage = `Estàs segur que vols eliminar ${selectedInscriptions.length} inscripcions? Aquesta acció no es pot desfer.`;
    if (!confirm(confirmMessage)) return;

    try {
      processingAssignments = true;

      // Eliminar totes les inscripcions seleccionades en paral·lel
      const deletePromises = selectedInscriptions.map(inscriptionId =>
        supabase
          .from('inscripcions')
          .delete()
          .eq('id', inscriptionId)
      );

      const results = await Promise.all(deletePromises);
      const errors = results.filter(result => result.error);

      if (errors.length > 0) {
        throw new Error(`Errors eliminant ${errors.length} inscripcions`);
      }

      // Reset state
      selectedInscriptions = [];
      bulkDeleteMode = false;

      // Reload data
      await Promise.all([loadInscriptions(), loadSocis()]);

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      processingAssignments = false;
    }
  }

  async function fixCategoryAssignments() {
    if (!inscriptions.length || !categories.length) {
      error = 'Necessites inscripcions i categories per arreglar les assignacions';
      return;
    }

    if (!confirm(`Vols assignar automàticament ${inscriptions.length} jugadors a ${categories.length} categories de forma equilibrada?`)) {
      return;
    }

    processingAssignments = true;

    try {
      console.log('🔧 Arreglant assignacions de categories...');
      console.log(`📊 ${inscriptions.length} inscripcions, ${categories.length} categories`);

      // Primer, netejar totes les assignacions existents
      console.log('🧹 Netejant assignacions existents...');

      const clearPromises = inscriptions.map(inscription =>
        supabase
          .from('inscripcions')
          .update({ categoria_assignada_id: null })
          .eq('id', inscription.id)
      );

      await Promise.all(clearPromises);

      // Distribuir jugadors equitativament entre categories
      const playersPerCategory = Math.floor(inscriptions.length / categories.length);
      const remainingPlayers = inscriptions.length % categories.length;

      console.log(`📈 Distribució: ${playersPerCategory} jugadors per categoria, ${remainingPlayers} restants`);

      let assignments = [];
      let playerIndex = 0;

      // Ordenar categories per ordre
      const sortedCategories = [...categories].sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));

      // Barrejar inscripcions per evitar biaixos (jugadors que s'apunten primer van a categories altes)
      const shuffledInscriptions = [...inscriptions].sort(() => Math.random() - 0.5);

      for (let i = 0; i < sortedCategories.length; i++) {
        const category = sortedCategories[i];
        const playersInThisCategory = playersPerCategory + (i < remainingPlayers ? 1 : 0);

        console.log(`📝 Categoria ${category.nom}: ${playersInThisCategory} jugadors`);

        for (let j = 0; j < playersInThisCategory && playerIndex < shuffledInscriptions.length; j++) {
          assignments.push({
            inscriptionId: shuffledInscriptions[playerIndex].id,
            categoryId: category.id,
            categoryName: category.nom,
            playerName: `${shuffledInscriptions[playerIndex].socis?.nom} ${shuffledInscriptions[playerIndex].socis?.cognoms}`
          });
          playerIndex++;
        }
      }

      console.log('📋 Assignacions a aplicar:', assignments.length);

      // Aplicar assignacions a la base de dades en lots més petits
      const batchSize = 10;
      for (let i = 0; i < assignments.length; i += batchSize) {
        const batch = assignments.slice(i, i + batchSize);

        const updatePromises = batch.map(({ inscriptionId, categoryId }) =>
          supabase
            .from('inscripcions')
            .update({ categoria_assignada_id: categoryId })
            .eq('id', inscriptionId)
        );

        const results = await Promise.all(updatePromises);

        // Comprovar errors en aquest lot
        const errors = results.filter(r => r.error);
        if (errors.length > 0) {
          console.error('❌ Errors en lot:', errors);
          throw new Error(`Errors en ${errors.length} assignacions del lot: ${errors[0].error.message}`);
        }

        console.log(`✅ Lot ${Math.floor(i/batchSize) + 1}/${Math.ceil(assignments.length/batchSize)} completat`);
      }

      console.log('🎉 Totes les assignacions completades');

      // Recarregar inscripcions
      await loadInscriptions();

      // Mostrar missatge d'èxit detallat
      const categoryDistribution = assignments.reduce((acc, assignment) => {
        acc[assignment.categoryName] = (acc[assignment.categoryName] || 0) + 1;
        return acc;
      }, {});

      const distributionText = Object.entries(categoryDistribution)
        .map(([category, count]) => `${category}: ${count}`)
        .join('\n');

      successMessage = `✅ Assignacions arreglades correctament!\n\n${assignments.length} jugadors assignats:\n${distributionText}`;
      setTimeout(() => successMessage = null, 10000);

    } catch (e) {
      console.error('❌ Error arreglant assignacions:', e);
      error = formatSupabaseError(e);
    } finally {
      processingAssignments = false;
    }
  }

  async function addPlayerInscription() {
    if (!selectedSociId || !selectedEventId) return;

    try {
      addingInscription = true;
  
      const selectedSoci = socis.find(s => s.numero_soci === parseInt(selectedSociId));
      if (!selectedSoci) {
        error = 'Soci no trobat';
        return;
      }

      const inscriptionData = {
        event_id: selectedEventId,
        soci_numero: selectedSoci.numero_soci,
        preferencies_dies: [],
        preferencies_hores: [],
        restriccions_especials: null,
        observacions: selectedSoci.historicalAverage
          ? `Mitjana històrica: ${selectedSoci.historicalAverage.toFixed(2)}`
          : 'Sense mitjana històrica',
        confirmat: true, // Admin inscription is auto-confirmed
        pagat: false
      };

      const { error: inscriptionError } = await supabase
        .from('inscripcions')
        .insert([inscriptionData]);

      if (inscriptionError) throw inscriptionError;

      // Reset form
      selectedSociId = '';
      showAddPlayer = false;

      // Reload inscriptions
      await loadInscriptions();

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      addingInscription = false;
    }
  }

  function getInscriptionSummary(inscriptionsList = [], eventId = '') {
    // Assegurem-nos que inscriptions existeix i és un array
    const validInscriptions = Array.isArray(inscriptionsList) ? inscriptionsList : [];

    const total = validInscriptions.length;
    const confirmed = validInscriptions.filter(i => i?.confirmat).length;
    const paid = validInscriptions.filter(i => i?.pagat).length;
    const assigned = validInscriptions.filter(i => i?.categoria_assignada_id).length;

    console.log('📊 Summary calculated:', {
      total, confirmed, paid, assigned,
      inscriptions_length: validInscriptions.length,
      eventId,
      inscriptions_is_array: Array.isArray(inscriptionsList)
    });

    return { total, confirmed, paid, assigned };
  }

  $: selectedEvent = events.find(e => e.id === selectedEventId);
  $: selectedSoci = socis.find(s => s.numero_soci === parseInt(selectedSociId));
  $: summary = getInscriptionSummary(inscriptions, selectedEventId);

  // Debug CategorySetup condition
  $: if (selectedEventId) {
    console.log('CategorySetup condition check:', {
      selectedEventId: selectedEventId,
      inscriptions_length: inscriptions.length,
      categories_length: categories.length,
      event_status: selectedEvent?.estat_competicio,
      should_show: inscriptions.length > 0 && selectedEvent?.estat_competicio === 'inscripcions'
    });
  }
</script>

<svelte:head>
  <title>Inscripcions Socials - Admin</title>
</svelte:head>

<div class="max-w-7xl mx-auto p-4">
  <div class="mb-6">
    <div class="flex items-center space-x-4">
      <a
        href="/admin"
        class="text-gray-600 hover:text-gray-900"
      >
        ← Tornar a Admin
      </a>
    </div>
    <h1 class="text-2xl font-semibold text-gray-900 mt-2">Inscripcions - Lligues Socials</h1>
    <p class="text-gray-600 mt-1">Gestiona les inscripcions dels campionats socials i eliminatòries</p>
  </div>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} />
  {:else}
    {#if successMessage}
      <Banner type="success" message={successMessage} class="mb-6" />
    {/if}
    <!-- Event Selector -->
    <div class="mb-6">
      <label for="event-select" class="block text-sm font-medium text-gray-700 mb-2">
        Selecciona Event Social
      </label>
      <select
        id="event-select"
        bind:value={selectedEventId}
        on:change={loadEventData}
        class="block w-full max-w-md px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
      >
        <option value="">Selecciona un event...</option>
        {#each events as event}
          <option value={event.id}>
            {event.nom} - {event.temporada} ({modalityNames[event.modalitat]})
          </option>
        {/each}
      </select>
    </div>

    {#if selectedEvent}
      <!-- Event Info -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
        <h3 class="text-lg font-medium text-blue-900 mb-2">{selectedEvent.nom}</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <span class="font-medium text-blue-800">Modalitat:</span>
            <span class="text-blue-700">{modalityNames[selectedEvent.modalitat]}</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Tipus:</span>
            <span class="text-blue-700">{competitionTypes[selectedEvent.tipus_competicio]}</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Estat:</span>
            <span class="text-blue-700">{statusNames[selectedEvent.estat_competicio]}</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Quota:</span>
            <span class="text-blue-700">{selectedEvent.quota_inscripcio || 0}€</span>
          </div>
        </div>
      </div>

      <!-- Category Setup (shown when inscriptions are open, even with existing categories) -->
      {#if inscriptions.length > 0 && selectedEvent?.estat_competicio === 'inscripcions'}
        <CategorySetup
          eventId={selectedEventId}
          {inscriptions}
          {socis}
          {categories}
          processing={processingAssignments}
          on:categoriesCreated={handleCategoriesCreated}
          on:error={handleCategorySetupError}
        />
      {/if}

      <!-- Drag & Drop Interface -->
      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-900">Gestió d'Inscripcions</h3>
          <div class="flex items-center space-x-4">
            <!-- Toggle moviment intel·ligent -->
            <div class="flex items-center">
              <input
                type="checkbox"
                id="intelligent-movement"
                bind:checked={useIntelligentMovement}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label for="intelligent-movement" class="ml-2 text-sm text-gray-700">
                Moviment intel·ligent
              </label>
            </div>

            <button
              on:click={() => showAddPlayer = !showAddPlayer}
              class="px-3 py-1 bg-gray-600 text-white text-sm rounded hover:bg-gray-700"
            >
              {showAddPlayer ? 'Amagar Formulari' : 'Mostrar Formulari Manual'}
            </button>
          </div>
        </div>

        <DragDropInscriptions
          {socis}
          {inscriptions}
          {categories}
          {loading}
          eventId={selectedEventId}
          currentEvent={selectedEvent}
          useIntelligentMovement={useIntelligentMovement}
          on:inscribe={handleInscribe}
          on:moveInscription={handleMoveInscription}
          on:removeInscription={handleRemoveInscription}
          on:intelligentMovementCompleted={handleIntelligentMovementCompleted}
          on:error={handleDragDropError}
        />

        <!-- Formulari Manual (opcional) -->
        {#if showAddPlayer}
          <div class="mt-6 pt-6 border-t border-gray-200">
            <h4 class="text-md font-medium text-gray-900 mb-4">Inscripció Manual</h4>
            <div class="space-y-4">
              <div>
                <label for="soci-select" class="block text-sm font-medium text-gray-700 mb-2">
                  Selecciona Soci
                </label>
                <select
                  id="soci-select"
                  bind:value={selectedSociId}
                  class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                >
                  <option value="">-- Selecciona un soci --</option>
                  {#each socis as soci}
                    <option value={soci.numero_soci}>
                      {soci.nom} {soci.cognoms} (#{soci.numero_soci})
                      {#if soci.historicalAverage}
                        - Mitjana: {soci.historicalAverage.toFixed(2)}
                      {/if}
                    </option>
                  {/each}
                </select>
              </div>

              {#if selectedSoci}
                <div class="bg-gray-50 p-4 rounded-lg">
                  <h4 class="font-medium text-gray-900 mb-2">Soci Seleccionat:</h4>
                  <p class="text-sm text-gray-600">
                    <strong>{selectedSoci.nom} {selectedSoci.cognoms}</strong>
                    (Soci #{selectedSoci.numero_soci})
                  </p>
                  {#if selectedSoci.email}
                    <p class="text-sm text-gray-500">{selectedSoci.email}</p>
                  {/if}
                  {#if selectedSoci.historicalAverage !== null}
                    <p class="text-sm text-blue-600">
                      Mitjana històrica: {selectedSoci.historicalAverage.toFixed(2)}
                    </p>
                  {:else}
                    <p class="text-sm text-gray-500">Sense mitjana històrica</p>
                  {/if}
                </div>

                <div class="flex space-x-3">
                  <button
                    on:click={addPlayerInscription}
                    disabled={addingInscription}
                    class="px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 disabled:bg-gray-400"
                  >
                    {addingInscription ? 'Inscrivint...' : 'Inscriure Soci'}
                  </button>
                  <button
                    on:click={() => { selectedSociId = ''; showAddPlayer = false; }}
                    class="px-4 py-2 bg-gray-300 text-gray-700 text-sm rounded hover:bg-gray-400"
                  >
                    Cancel·lar
                  </button>
                </div>
              {/if}
            </div>
          </div>
        {/if}
      </div>

      <!-- Assignació Automàtica de Categories -->
      {#if inscriptions.length > 0 && categories.length > 0}
        <AutoCategoryAssignment
          {inscriptions}
          {categories}
          {socis}
          processing={processingAssignments}
          on:applyAssignments={handleApplyAssignments}
        />
      {/if}

      <!-- Fix assignacions -->
      <div class="bg-red-50 border border-red-200 p-4 rounded-lg mb-4">
        <p class="text-red-800 font-medium mb-2">⚠️ Problema detectat: Les assignacions de categories no estan guardades a la base de dades</p>
        <p class="text-red-700 text-sm mb-3">Summary assigned: {summary.assigned} (hauria de ser {inscriptions.length})</p>
        <button
          on:click={fixCategoryAssignments}
          class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
          disabled={processingAssignments}
        >
          {processingAssignments ? 'Arreglant...' : '🔧 Arreglar Assignacions de Categories'}
        </button>
      </div>

      <!-- Generador de Calendaris (quan hi ha assignacions de categories) -->
      {#if inscriptions.length > 0 && categories.length > 0}
        <CalendarGenerator
          eventId={selectedEventId}
          {categories}
          {inscriptions}
          processing={processingAssignments}
          on:calendarCreated={handleCalendarCreated}
          on:error={handleCategorySetupError}
        />
      {/if}

      <!-- Editor de Calendaris -->
      {#if selectedEventId && categories.length > 0}
        <CalendarEditor
          eventId={selectedEventId}
          {categories}
          on:regenerateCalendar={handleRegenerateCalendar}
        />
      {/if}

      <!-- Summary Cards -->
      {#if selectedEventId}
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div class="bg-white p-4 rounded-lg shadow border">
            <div class="text-2xl font-bold text-gray-900">{summary.total}</div>
            <div class="text-sm text-gray-600">Total Inscripcions</div>
          </div>
          <div class="bg-white p-4 rounded-lg shadow border">
            <div class="text-2xl font-bold text-green-600">{summary.confirmed}</div>
            <div class="text-sm text-gray-600">Confirmades</div>
          </div>
          <div class="bg-white p-4 rounded-lg shadow border">
            <div class="text-2xl font-bold text-blue-600">{summary.paid}</div>
            <div class="text-sm text-gray-600">Pagades</div>
          </div>
          <div class="bg-white p-4 rounded-lg shadow border">
            <div class="text-2xl font-bold text-purple-600">{summary.assigned}</div>
            <div class="text-sm text-gray-600">Assignades</div>
          </div>
        </div>
      {/if}

      <!-- Inscriptions Table -->
      {#if inscriptions.length === 0}
        <div class="text-center py-12 bg-white rounded-lg shadow">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha inscripcions</h3>
          <p class="mt-1 text-sm text-gray-500">Aquest esdeveniment no té cap inscripció encara</p>
        </div>
      {:else}
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <!-- Filter controls -->
          {#if inscriptions.length > 0}
            <div class="bg-blue-50 px-6 py-3 border-b border-gray-200">
              <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                <!-- Name filter -->
                <div>
                  <label for="filter-name" class="block text-xs font-medium text-gray-700 mb-1">
                    Cerca per nom
                  </label>
                  <input
                    id="filter-name"
                    type="text"
                    placeholder="Nom del jugador..."
                    bind:value={filterName}
                    class="w-full px-3 py-1 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                  />
                </div>

                <!-- Category filter -->
                <div>
                  <label for="filter-category" class="block text-xs font-medium text-gray-700 mb-1">
                    Categoria
                  </label>
                  <select
                    id="filter-category"
                    bind:value={filterCategory}
                    class="w-full px-3 py-1 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="">Totes les categories</option>
                    <option value="unassigned">Sense assignar</option>
                    {#each categories as category}
                      <option value={category.nom}>{category.nom}</option>
                    {/each}
                  </select>
                </div>

                <!-- Status filter -->
                <div>
                  <label for="filter-status" class="block text-xs font-medium text-gray-700 mb-1">
                    Estat
                  </label>
                  <select
                    id="filter-status"
                    bind:value={filterStatus}
                    class="w-full px-3 py-1 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="">Tots els estats</option>
                    <option value="confirmed">Confirmats</option>
                    <option value="pending">Pendents</option>
                    <option value="paid">Pagats</option>
                    <option value="unpaid">No pagats</option>
                  </select>
                </div>

                <!-- Clear filters -->
                <div class="flex items-end">
                  <button
                    on:click={() => { filterName = ''; filterCategory = ''; filterStatus = ''; }}
                    class="px-3 py-1 text-sm bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 transition-colors"
                  >
                    Netejar filtres
                  </button>
                </div>
              </div>
            </div>
          {/if}

          <!-- Bulk actions header -->
          {#if inscriptions.length > 0}
            <div class="bg-gray-50 px-6 py-3 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-4">
                  <button
                    on:click={toggleBulkDeleteMode}
                    class="px-3 py-1 text-sm rounded transition-colors"
                    class:bg-red-600={bulkDeleteMode}
                    class:text-white={bulkDeleteMode}
                    class:hover:bg-red-700={bulkDeleteMode}
                    class:bg-gray-200={!bulkDeleteMode}
                    class:text-gray-700={!bulkDeleteMode}
                    class:hover:bg-gray-300={!bulkDeleteMode}
                  >
                    {bulkDeleteMode ? 'Cancel·lar selecció' : 'Eliminar múltiples'}
                  </button>

                  {#if bulkDeleteMode}
                    <div class="flex items-center space-x-2">
                      <button
                        on:click={selectAllInscriptions}
                        class="text-sm text-blue-600 hover:text-blue-900"
                      >
                        Seleccionar tots
                      </button>
                      <span class="text-gray-300">|</span>
                      <button
                        on:click={clearSelection}
                        class="text-sm text-blue-600 hover:text-blue-900"
                      >
                        Netejar selecció
                      </button>
                    </div>
                  {/if}
                </div>

                {#if bulkDeleteMode && selectedInscriptions.length > 0}
                  <div class="flex items-center space-x-3">
                    <span class="text-sm text-gray-600">
                      {selectedInscriptions.length} seleccionades
                    </span>
                    <button
                      on:click={bulkDeleteInscriptions}
                      disabled={processingAssignments}
                      class="px-3 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700 disabled:bg-gray-400 transition-colors"
                    >
                      {processingAssignments ? 'Eliminant...' : 'Eliminar seleccionades'}
                    </button>
                  </div>
                {/if}
              </div>
            </div>
          {/if}

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  {#if bulkDeleteMode}
                    <th class="px-6 py-3 text-left">
                      <input
                        type="checkbox"
                        checked={selectedInscriptions.length === inscriptions.length && inscriptions.length > 0}
                        on:change={(e) => e.target.checked ? selectAllInscriptions() : clearSelection()}
                        class="h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300 rounded"
                      />
                    </th>
                  {/if}
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <button
                      on:click={() => handleSort('name')}
                      class="flex items-center space-x-1 hover:text-gray-700 transition-colors"
                    >
                      <span>Jugador</span>
                      {#if sortField === 'name'}
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          {#if sortDirection === 'asc'}
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                          {:else}
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                          {/if}
                        </svg>
                      {/if}
                    </button>
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <button
                      on:click={() => handleSort('date')}
                      class="flex items-center space-x-1 hover:text-gray-700 transition-colors"
                    >
                      <span>Data</span>
                      {#if sortField === 'date'}
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          {#if sortDirection === 'asc'}
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                          {:else}
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                          {/if}
                        </svg>
                      {/if}
                    </button>
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <button
                      on:click={() => handleSort('category')}
                      class="flex items-center space-x-1 hover:text-gray-700 transition-colors"
                    >
                      <span>Categoria</span>
                      {#if sortField === 'category'}
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          {#if sortDirection === 'asc'}
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                          {:else}
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                          {/if}
                        </svg>
                      {/if}
                    </button>
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <button
                      on:click={() => handleSort('status')}
                      class="flex items-center space-x-1 hover:text-gray-700 transition-colors"
                    >
                      <span>Estat</span>
                      {#if sortField === 'status'}
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          {#if sortDirection === 'asc'}
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                          {:else}
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                          {/if}
                        </svg>
                      {/if}
                    </button>
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Observacions
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Accions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each filteredAndSortedInscriptions as inscription}
                  <tr class:bg-red-50={bulkDeleteMode && selectedInscriptions.includes(inscription.id)}>
                    {#if bulkDeleteMode}
                      <td class="px-6 py-4 whitespace-nowrap">
                        <input
                          type="checkbox"
                          checked={selectedInscriptions.includes(inscription.id)}
                          on:change={() => toggleInscriptionSelection(inscription.id)}
                          class="h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300 rounded"
                        />
                      </td>
                    {/if}
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div>
                          <div class="text-sm font-medium text-gray-900">
                            {inscription.socis.nom} {inscription.socis.cognoms}
                          </div>
                          <div class="text-sm text-gray-500">
                            Soci #{inscription.socis.numero_soci}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {new Date(inscription.data_inscripcio).toLocaleDateString('ca-ES')}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <select
                        value={inscription.categoria_assignada_id || ''}
                        on:change={(e) => updateInscriptionCategory(inscription.id, e.target.value || null)}
                        class="text-sm border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
                      >
                        <option value="">Sense assignar</option>
                        {#each categories as category}
                          <option value={category.id}>
                            {category.nom}
                          </option>
                        {/each}
                      </select>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex flex-col space-y-1">
                        <label class="flex items-center text-sm">
                          <input
                            type="checkbox"
                            checked={inscription.confirmat}
                            on:change={(e) => updateInscriptionStatus(inscription.id, 'confirmat', e.target.checked)}
                            class="mr-2 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                          >
                          Confirmat
                        </label>
                        {#if selectedEvent.quota_inscripcio > 0}
                          <label class="flex items-center text-sm">
                            <input
                              type="checkbox"
                              checked={inscription.pagat}
                              on:change={(e) => updateInscriptionStatus(inscription.id, 'pagat', e.target.checked)}
                              class="mr-2 h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded"
                            >
                            Pagat
                          </label>
                        {/if}
                      </div>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-500">
                      {inscription.observacions || '-'}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <div class="flex items-center space-x-2">
                        <button
                          on:click={() => openRestrictionsEditor(inscription)}
                          class="text-blue-600 hover:text-blue-900"
                          title="Editar restriccions"
                          aria-label="Editar restriccions de {inscription.socis?.nom}"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                          </svg>
                        </button>
                        <button
                          on:click={() => deleteInscription(inscription.id)}
                          class="text-red-600 hover:text-red-900"
                          title="Eliminar inscripció"
                          aria-label="Eliminar inscripció de {inscription.socis?.nom}"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        </div>
      {/if}
    {/if}
  {/if}

  <!-- Player Restrictions Editor Modal -->
  <PlayerSelfRestrictionsEditor
    inscription={selectedInscriptionForRestrictions}
    bind:isOpen={restrictionsEditorOpen}
    on:updated={handleRestrictionsUpdated}
    on:error={handleCategorySetupError}
    on:close={() => { restrictionsEditorOpen = false; selectedInscriptionForRestrictions = null; }}
  />
</div>