<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError } from '$lib/ui/alerts';

  let loading = false;
  let error: string | null = null;
  let success: string | null = null;
  let socis: any[] = [];
  let downloading = false;
  let showNewSociForm = false;
  let editingSoci: any = null;
  let uploading = false;
  let uploadSummary: {
    toAdd: any[];
    toDeactivate: any[];
    existing: any[];
  } | null = null;
  let showUploadConfirmation = false;

  // Formulari per nou soci
  let newSoci = {
    numero_soci: '',
    nom: '',
    cognoms: '',
    email: '',
    telefon: '',
    adresa: '',
    data_naixement: '',
    de_baixa: false
  };

  // Filtres i cerca
  let searchTerm = '';
  let showInactive = false; // Per mostrar socis de baixa

  onMount(async () => {
    await loadSocis();
  });

  async function loadSocis() {
    try {
      loading = true;
      error = null;

      const { data, error: supabaseError } = await supabase
        .from('socis')
        .select('*')
        .order('numero_soci');

      if (supabaseError) {
        throw supabaseError;
      }

      socis = data || [];
    } catch (e: any) {
      error = formatSupabaseError(e);
      socis = [];
    } finally {
      loading = false;
    }
  }

  // Funció per crear nou soci
  async function createSoci() {
    try {
      error = null;
      success = null;

      // Validacions bàsiques
      if (!newSoci.numero_soci || !newSoci.nom || !newSoci.cognoms) {
        error = 'Els camps Número Soci, Nom i Cognoms són obligatoris';
        return;
      }

      // Comprovar que el número de soci no existeixi
      const { data: existingSoci } = await supabase
        .from('socis')
        .select('numero_soci')
        .eq('numero_soci', parseInt(newSoci.numero_soci))
        .single();

      if (existingSoci) {
        error = 'Ja existeix un soci amb aquest número';
        return;
      }

      const { error: createError } = await supabase
        .from('socis')
        .insert([{
          numero_soci: parseInt(newSoci.numero_soci),
          nom: newSoci.nom.trim(),
          cognoms: newSoci.cognoms.trim(),
          email: newSoci.email?.trim() || null,
          telefon: newSoci.telefon?.trim() || null,
          adresa: newSoci.adresa?.trim() || null,
          data_naixement: newSoci.data_naixement || null,
          de_baixa: false
        }]);

      if (createError) {
        throw createError;
      }

      success = 'Soci creat correctament';
      showNewSociForm = false;
      resetNewSociForm();
      await loadSocis();

    } catch (e: any) {
      error = formatSupabaseError(e);
    }
  }

  // Funció per actualitzar soci
  async function updateSoci() {
    try {
      error = null;
      success = null;

      if (!editingSoci) return;

      const { error: updateError } = await supabase
        .from('socis')
        .update({
          nom: editingSoci.nom.trim(),
          cognoms: editingSoci.cognoms.trim(),
          email: editingSoci.email?.trim() || null,
          telefon: editingSoci.telefon?.trim() || null,
          adresa: editingSoci.adresa?.trim() || null,
          data_naixement: editingSoci.data_naixement || null,
          de_baixa: editingSoci.de_baixa
        })
        .eq('numero_soci', editingSoci.numero_soci);

      if (updateError) {
        throw updateError;
      }

      success = 'Soci actualitzat correctament';
      editingSoci = null;
      await loadSocis();

    } catch (e: any) {
      error = formatSupabaseError(e);
    }
  }

  // Funció per donar de baixa/alta un soci
  async function toggleSociStatus(soci: any) {
    try {
      error = null;
      success = null;

      const newStatus = !soci.de_baixa;

      const { error: updateError } = await supabase
        .from('socis')
        .update({ de_baixa: newStatus })
        .eq('numero_soci', soci.numero_soci);

      if (updateError) {
        throw updateError;
      }

      success = `Soci ${newStatus ? 'donat de baixa' : 'donat d\'alta'} correctament`;
      await loadSocis();

    } catch (e: any) {
      error = formatSupabaseError(e);
    }
  }

  // Funció per eliminar soci (amb confirmació)
  async function deleteSoci(soci: any) {
    if (!confirm(`Estàs segur que vols eliminar definitivament el soci ${soci.nom} ${soci.cognoms}? Aquesta acció no es pot desfer.`)) {
      return;
    }

    try {
      error = null;
      success = null;

      const { error: deleteError } = await supabase
        .from('socis')
        .delete()
        .eq('numero_soci', soci.numero_soci);

      if (deleteError) {
        throw deleteError;
      }

      success = 'Soci eliminat correctament';
      await loadSocis();

    } catch (e: any) {
      error = formatSupabaseError(e);
    }
  }

  function resetNewSociForm() {
    newSoci = {
      numero_soci: '',
      nom: '',
      cognoms: '',
      email: '',
      telefon: '',
      adresa: '',
      data_naixement: '',
      de_baixa: false
    };
  }

  function startEditing(soci: any) {
    editingSoci = { ...soci };
    showNewSociForm = false;
  }

  function cancelEditing() {
    editingSoci = null;
  }

  // Filtrar socis segons cerca i filtres
  $: filteredSocis = socis.filter(soci => {
    const matchesSearch = searchTerm === '' ||
      soci.nom.toLowerCase().includes(searchTerm.toLowerCase()) ||
      soci.cognoms.toLowerCase().includes(searchTerm.toLowerCase()) ||
      soci.numero_soci.toString().includes(searchTerm);

    // Mostrar només actius per defecte, o també inactius si el checkbox està activat
    const matchesStatus = !soci.de_baixa || showInactive;

    return matchesSearch && matchesStatus;
  });

  function formatPlayerName(nom: string, cognoms: string): string {
    if (!nom || !cognoms) return 'NOM INCOMPLET';

    // Obtenir primera inicial del nom
    const inicialNom = nom.charAt(0).toUpperCase();

    // Obtenir primer cognom (dividir per espais i agafar el primer) i posar-lo en majúscules
    const primerCognom = cognoms.split(' ')[0].toUpperCase();

    return `${inicialNom}. ${primerCognom}`;
  }

  async function downloadCSV() {
    try {
      downloading = true;

      // Capçalera del CSV
      const headers = ['Número Soci', 'Nom Formatat', 'Nom Complet', 'Email', 'Telèfon', 'Estat'];

      // Convertir dades a format CSV
      const rows = filteredSocis.map(soci => [
        soci.numero_soci,
        formatPlayerName(soci.nom, soci.cognoms || ''),
        `${soci.nom} ${soci.cognoms || ''}`,
        soci.email || '',
        soci.telefon || '',
        soci.de_baixa ? 'De baixa' : 'Actiu'
      ]);

      // Combinar capçalera i files
      const csvContent = [headers, ...rows]
        .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
        .join('\n');

      // Crear i descarregar l'arxiu
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');

      if (link.download !== undefined) {
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `llistat_socis_${new Date().toISOString().split('T')[0]}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }
    } catch (e: any) {
      error = formatSupabaseError(e);
    } finally {
      downloading = false;
    }
  }

  async function handleCSVUpload(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];

    if (!file) return;

    try {
      uploading = true;
      error = null;
      success = null;

      // Llegir arxiu CSV
      const text = await file.text();
      const lines = text.split('\n').filter(line => line.trim());

      if (lines.length < 2) {
        error = 'L\'arxiu CSV està buit o no té el format correcte';
        return;
      }

      // Parse CSV (columnes: C=numero, F=nom, G=cognoms, J=email, L=telefon, Q=data_naixement)
      // Índexs de columna (0-indexed): C=2, F=5, G=6, J=9, L=11, Q=16
      const csvSocis: any[] = [];
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;

        // Split per comes, tenint en compte que alguns camps poden estar entre cometes
        const values = line.match(/(".*?"|[^,]+)(?=\s*,|\s*$)/g)?.map(v => v.replace(/^"|"$/g, '').trim()) || [];

        if (values.length < 17) continue; // Necessitem almenys fins la columna Q

        const numeroSoci = parseInt(values[2]) || 0; // Columna C
        const nom = values[5] || ''; // Columna F
        const cognoms = values[6] || ''; // Columna G
        const email = values[9] || null; // Columna J
        const telefon = values[11] || null; // Columna L
        const dataNaixement = values[16] || null; // Columna Q

        if (!numeroSoci || !nom || !cognoms) continue; // Mínim necessitem número, nom i cognoms

        csvSocis.push({
          numero_soci: numeroSoci,
          nom: nom,
          cognoms: cognoms,
          email: email,
          telefon: telefon,
          data_naixement: dataNaixement
        });
      }

      if (csvSocis.length === 0) {
        error = 'No s\'han trobat socis vàlids a l\'arxiu CSV';
        return;
      }

      // Comparar amb la base de dades
      const csvNumeros = new Set(csvSocis.map(s => s.numero_soci));
      const dbNumeros = new Set(socis.map(s => s.numero_soci));

      // Socis per donar d'alta (estan al CSV però no a la BD)
      const toAdd = csvSocis.filter(s => !dbNumeros.has(s.numero_soci));

      // Socis per donar de baixa (estan a la BD actius però no al CSV)
      const toDeactivate = socis.filter(s => !s.de_baixa && !csvNumeros.has(s.numero_soci));

      // Socis que ja existeixen
      const existing = csvSocis.filter(s => dbNumeros.has(s.numero_soci));

      uploadSummary = { toAdd, toDeactivate, existing };
      showUploadConfirmation = true;

    } catch (e: any) {
      error = `Error processant l'arxiu CSV: ${e.message}`;
    } finally {
      uploading = false;
      // Reset input
      input.value = '';
    }
  }

  async function confirmCSVUpload() {
    if (!uploadSummary) return;

    try {
      uploading = true;
      error = null;
      success = null;

      // 1. Donar d'alta nous socis
      if (uploadSummary.toAdd.length > 0) {
        const { error: insertError } = await supabase
          .from('socis')
          .insert(uploadSummary.toAdd.map(s => ({
            numero_soci: s.numero_soci,
            nom: s.nom,
            cognoms: s.cognoms,
            email: s.email,
            telefon: s.telefon,
            data_naixement: s.data_naixement,
            de_baixa: false
          })));

        if (insertError) {
          throw insertError;
        }
      }

      // 2. Donar de baixa socis que no estan al CSV
      if (uploadSummary.toDeactivate.length > 0) {
        const numerosToDeactivate = uploadSummary.toDeactivate.map(s => s.numero_soci);

        const { error: updateError } = await supabase
          .from('socis')
          .update({ de_baixa: true })
          .in('numero_soci', numerosToDeactivate);

        if (updateError) {
          throw updateError;
        }
      }

      success = `CSV processat correctament: ${uploadSummary.toAdd.length} socis donats d'alta, ${uploadSummary.toDeactivate.length} socis donats de baixa`;

      showUploadConfirmation = false;
      uploadSummary = null;
      await loadSocis();

    } catch (e: any) {
      error = formatSupabaseError(e);
    } finally {
      uploading = false;
    }
  }

  function cancelCSVUpload() {
    showUploadConfirmation = false;
    uploadSummary = null;
  }
</script>

<svelte:head>
  <title>Gestió de Socis - Administració</title>
</svelte:head>

<div class="max-w-7xl mx-auto p-4">
  <div class="mb-6">
    <h1 class="text-3xl font-semibold text-gray-900">Gestió de Socis</h1>
    <p class="mt-2 text-gray-600">Gestiona els socis del club: alta, baixa, modificació i consulta.</p>
  </div>

  <!-- Messages -->
  {#if error}
    <div class="mb-6 bg-red-50 border border-red-200 rounded-lg p-4">
      <p class="text-red-700">{error}</p>
    </div>
  {/if}

  {#if success}
    <div class="mb-6 bg-green-50 border border-green-200 rounded-lg p-4">
      <p class="text-green-700">{success}</p>
    </div>
  {/if}

  <!-- Actions -->
  <div class="mb-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
    <div class="flex flex-wrap items-center gap-3">
      <button
        on:click={() => { showNewSociForm = !showNewSociForm; editingSoci = null; }}
        class="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 flex items-center gap-2"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Nou Soci
      </button>

      <button
        on:click={loadSocis}
        disabled={loading}
        class="bg-gray-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-gray-700 disabled:opacity-50"
      >
        {#if loading}
          <div class="flex items-center space-x-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
            <span>Carregant...</span>
          </div>
        {:else}
          Actualitzar
        {/if}
      </button>

      <button
        on:click={downloadCSV}
        disabled={downloading || filteredSocis.length === 0}
        class="bg-green-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-green-700 disabled:opacity-50"
      >
        {#if downloading}
          <div class="flex items-center space-x-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
            <span>Descarregant...</span>
          </div>
        {:else}
          📥 Descarregar CSV
        {/if}
      </button>

      <label class="bg-purple-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-purple-700 disabled:opacity-50 cursor-pointer flex items-center gap-2">
        {#if uploading}
          <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
          <span>Processant...</span>
        {:else}
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
          Pujar CSV
        {/if}
        <input
          type="file"
          accept=".csv"
          on:change={handleCSVUpload}
          disabled={uploading}
          class="hidden"
        />
      </label>
    </div>

    <div class="text-sm text-gray-600 bg-gray-50 px-3 py-2 rounded-lg">
      <span class="font-medium">Total: {socis.length}</span>
      <span class="ml-2 text-green-600">Actius: {socis.filter(s => !s.de_baixa).length}</span>
      <span class="ml-2 text-red-600">De baixa: {socis.filter(s => s.de_baixa).length}</span>
    </div>
  </div>

  <!-- CSV Upload Info -->
  <div class="mb-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
    <div class="flex items-start space-x-3">
      <svg class="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
      </svg>
      <div class="flex-1">
        <h3 class="text-sm font-semibold text-blue-900 mb-1">Format del CSV per pujar socis</h3>
        <p class="text-sm text-blue-800">
          El sistema llegeix les columnes: <code class="bg-blue-100 px-1 rounded">C (numero), F (nom), G (cognoms), J (email), L (telefon), Q (data naixement)</code>
          <br>
          <strong>Important:</strong> Els socis que estiguin al CSV seran marcats com actius. Els socis que NO estiguin al CSV però sí a la base de dades seran automàticament donats de baixa.
        </p>
      </div>
    </div>
  </div>

  <!-- Filters and Search -->
  <div class="mb-6 bg-white border border-gray-200 rounded-lg p-4">
    <div class="flex flex-col sm:flex-row gap-4 items-end">
      <div class="flex-1">
        <label for="search" class="block text-sm font-medium text-gray-700 mb-2">Cercar socis</label>
        <input
          id="search"
          type="text"
          bind:value={searchTerm}
          placeholder="Cercar per nom, cognoms o número de soci..."
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      <div class="flex items-center space-x-2 pb-2">
        <input
          id="show-inactive"
          type="checkbox"
          bind:checked={showInactive}
          class="rounded border-gray-300 text-blue-600 focus:ring-blue-500 w-4 h-4"
        />
        <label for="show-inactive" class="text-sm font-medium text-gray-700 cursor-pointer">
          Mostrar socis de baixa
        </label>
      </div>
    </div>
  </div>

  <!-- New Soci Form -->
  {#if showNewSociForm}
    <div class="mb-6 bg-blue-50 border border-blue-200 rounded-lg p-6">
      <h2 class="text-xl font-semibold text-blue-900 mb-4">Nou Soci</h2>
      <form on:submit|preventDefault={createSoci} class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label for="numero_soci" class="block text-sm font-medium text-gray-700 mb-2">Número Soci *</label>
          <input
            id="numero_soci"
            type="number"
            bind:value={newSoci.numero_soci}
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="nom" class="block text-sm font-medium text-gray-700 mb-2">Nom *</label>
          <input
            id="nom"
            type="text"
            bind:value={newSoci.nom}
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="cognoms" class="block text-sm font-medium text-gray-700 mb-2">Cognoms *</label>
          <input
            id="cognoms"
            type="text"
            bind:value={newSoci.cognoms}
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="email" class="block text-sm font-medium text-gray-700 mb-2">Email</label>
          <input
            id="email"
            type="email"
            bind:value={newSoci.email}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="telefon" class="block text-sm font-medium text-gray-700 mb-2">Telèfon</label>
          <input
            id="telefon"
            type="tel"
            bind:value={newSoci.telefon}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="data_naixement" class="block text-sm font-medium text-gray-700 mb-2">Data de Naixement</label>
          <input
            id="data_naixement"
            type="date"
            bind:value={newSoci.data_naixement}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div class="md:col-span-2">
          <label for="adresa" class="block text-sm font-medium text-gray-700 mb-2">Adreça</label>
          <textarea
            id="adresa"
            bind:value={newSoci.adresa}
            rows="2"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          ></textarea>
        </div>
        <div class="md:col-span-2 flex justify-end space-x-3">
          <button
            type="button"
            on:click={() => { showNewSociForm = false; resetNewSociForm(); }}
            class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
          >
            Cancel·lar
          </button>
          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Crear Soci
          </button>
        </div>
      </form>
    </div>
  {/if}

  <!-- CSV Upload Confirmation Dialog -->
  {#if showUploadConfirmation && uploadSummary}
    <div class="mb-6 bg-purple-50 border-2 border-purple-300 rounded-lg p-6">
      <h2 class="text-xl font-semibold text-purple-900 mb-4">Confirmació de Pujada CSV</h2>

      <div class="space-y-4 mb-6">
        <div class="bg-white rounded-lg p-4 border border-gray-200">
          <h3 class="font-semibold text-gray-900 mb-2">Resum dels canvis:</h3>
          <ul class="space-y-2 text-sm">
            <li class="flex items-center space-x-2">
              <span class="text-green-600 font-medium">✅ Socis ja registrats:</span>
              <span class="font-semibold">{uploadSummary.existing.length}</span>
            </li>
            <li class="flex items-center space-x-2">
              <span class="text-blue-600 font-medium">➕ Nous socis a donar d'alta:</span>
              <span class="font-semibold">{uploadSummary.toAdd.length}</span>
            </li>
            <li class="flex items-center space-x-2">
              <span class="text-red-600 font-medium">➖ Socis a donar de baixa:</span>
              <span class="font-semibold">{uploadSummary.toDeactivate.length}</span>
            </li>
          </ul>
        </div>

        {#if uploadSummary.toAdd.length > 0}
          <div class="bg-blue-50 rounded-lg p-4 border border-blue-200">
            <h4 class="font-semibold text-blue-900 mb-2">Nous socis ({uploadSummary.toAdd.length}):</h4>
            <div class="max-h-40 overflow-y-auto">
              <ul class="text-sm space-y-1">
                {#each uploadSummary.toAdd as soci}
                  <li class="text-blue-800">
                    #{soci.numero_soci} - {soci.nom} {soci.cognoms}
                  </li>
                {/each}
              </ul>
            </div>
          </div>
        {/if}

        {#if uploadSummary.toDeactivate.length > 0}
          <div class="bg-red-50 rounded-lg p-4 border border-red-200">
            <h4 class="font-semibold text-red-900 mb-2">Socis a donar de baixa ({uploadSummary.toDeactivate.length}):</h4>
            <div class="max-h-40 overflow-y-auto">
              <ul class="text-sm space-y-1">
                {#each uploadSummary.toDeactivate as soci}
                  <li class="text-red-800">
                    #{soci.numero_soci} - {soci.nom} {soci.cognoms}
                  </li>
                {/each}
              </ul>
            </div>
          </div>
        {/if}
      </div>

      <div class="flex justify-end space-x-3">
        <button
          type="button"
          on:click={cancelCSVUpload}
          disabled={uploading}
          class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 disabled:opacity-50"
        >
          Cancel·lar
        </button>
        <button
          type="button"
          on:click={confirmCSVUpload}
          disabled={uploading}
          class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50"
        >
          {#if uploading}
            <div class="flex items-center space-x-2">
              <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
              <span>Processant...</span>
            </div>
          {:else}
            Confirmar Canvis
          {/if}
        </button>
      </div>
    </div>
  {/if}

  <!-- Edit Soci Form -->
  {#if editingSoci}
    <div class="mb-6 bg-yellow-50 border border-yellow-200 rounded-lg p-6">
      <h2 class="text-xl font-semibold text-yellow-900 mb-4">Editar Soci: {editingSoci.nom} {editingSoci.cognoms}</h2>
      <form on:submit|preventDefault={updateSoci} class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label for="edit-numero-soci" class="block text-sm font-medium text-gray-700 mb-2">Número Soci</label>
          <input
            id="edit-numero-soci"
            type="number"
            value={editingSoci.numero_soci}
            disabled
            class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100"
          />
        </div>
        <div>
          <label for="edit-nom" class="block text-sm font-medium text-gray-700 mb-2">Nom *</label>
          <input
            id="edit-nom"
            type="text"
            bind:value={editingSoci.nom}
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="edit-cognoms" class="block text-sm font-medium text-gray-700 mb-2">Cognoms *</label>
          <input
            id="edit-cognoms"
            type="text"
            bind:value={editingSoci.cognoms}
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="edit-email" class="block text-sm font-medium text-gray-700 mb-2">Email</label>
          <input
            id="edit-email"
            type="email"
            bind:value={editingSoci.email}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="edit-telefon" class="block text-sm font-medium text-gray-700 mb-2">Telèfon</label>
          <input
            id="edit-telefon"
            type="tel"
            bind:value={editingSoci.telefon}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="edit-data-naixement" class="block text-sm font-medium text-gray-700 mb-2">Data de Naixement</label>
          <input
            id="edit-data-naixement"
            type="date"
            bind:value={editingSoci.data_naixement}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div class="md:col-span-2">
          <label for="edit-adresa" class="block text-sm font-medium text-gray-700 mb-2">Adreça</label>
          <textarea
            id="edit-adresa"
            bind:value={editingSoci.adresa}
            rows="2"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          ></textarea>
        </div>
        <div class="md:col-span-2">
          <label class="flex items-center space-x-2">
            <input
              type="checkbox"
              bind:checked={editingSoci.de_baixa}
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <span class="text-sm font-medium text-gray-700">Marcar com a baixa</span>
          </label>
        </div>
        <div class="md:col-span-2 flex justify-end space-x-3">
          <button
            type="button"
            on:click={cancelEditing}
            class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
          >
            Cancel·lar
          </button>
          <button
            type="submit"
            class="px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700"
          >
            Actualitzar Soci
          </button>
        </div>
      </form>
    </div>
  {/if}
    <div class="flex items-center space-x-4">
      <button
        on:click={loadSocis}
        disabled={loading}
        class="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50"
      >
        {#if loading}
          <div class="flex items-center space-x-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
            <span>Carregant...</span>
          </div>
        {:else}
          Actualitzar
        {/if}
      </button>

      <button
        on:click={downloadCSV}
        disabled={downloading || socis.length === 0}
        class="bg-green-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-green-700 disabled:opacity-50"
      >
        {#if downloading}
          <div class="flex items-center space-x-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
            <span>Descarregant...</span>
          </div>
        {:else}
          📥 Descarregar CSV
        {/if}
      </button>
    </div>

    <div class="text-sm text-gray-600">
      Total socis: <span class="font-medium">{socis.length}</span>
      <span class="ml-2">
        (Actius: {socis.filter(s => !s.de_baixa).length}, De baixa: {socis.filter(s => s.de_baixa).length})
      </span>
    </div>
  </div>

  <!-- Error display -->
  {#if error}
    <div class="mb-6 bg-red-50 border border-red-200 rounded-lg p-4">
      <p class="text-red-700">{error}</p>
    </div>
  {/if}

  <!-- Socis Table -->
  {#if !loading && filteredSocis.length > 0}
    <div class="bg-white shadow rounded-lg overflow-hidden">
      <div class="bg-gray-50 px-6 py-4 border-b">
        <h2 class="text-lg font-medium text-gray-900">
          Llistat de Socis
          {#if searchTerm || showInactive}
            <span class="text-sm font-normal text-gray-600">
              ({filteredSocis.length} de {socis.length} socis)
            </span>
          {/if}
        </h2>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Número Soci
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Nom Complet
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Contacte
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Estat
              </th>
              <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                Accions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each filteredSocis as soci}
              <tr class="hover:bg-gray-50" class:bg-red-50={soci.de_baixa}>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  #{soci.numero_soci}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-medium text-gray-900">{soci.nom} {soci.cognoms}</div>
                  <div class="text-sm text-gray-500">{formatPlayerName(soci.nom, soci.cognoms)}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <div>
                    {#if soci.email}
                      <div class="flex items-center space-x-1">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207"/>
                        </svg>
                        <span>{soci.email}</span>
                      </div>
                    {/if}
                    {#if soci.telefon}
                      <div class="flex items-center space-x-1 mt-1">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
                        </svg>
                        <span>{soci.telefon}</span>
                      </div>
                    {/if}
                    {#if !soci.email && !soci.telefon}
                      <span class="text-gray-400">Sense contacte</span>
                    {/if}
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {soci.de_baixa ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'}">
                    {soci.de_baixa ? '❌ De baixa' : '✅ Actiu'}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-center text-sm font-medium">
                  <div class="flex items-center justify-center space-x-2">
                    <!-- Edit Button -->
                    <button
                      on:click={() => startEditing(soci)}
                      class="text-blue-600 hover:text-blue-900 p-1 rounded hover:bg-blue-50"
                      title="Editar soci"
                      aria-label="Editar soci {soci.nom} {soci.cognoms}"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                      </svg>
                    </button>

                    <!-- Toggle Status Button -->
                    <button
                      on:click={() => toggleSociStatus(soci)}
                      class="{soci.de_baixa ? 'text-green-600 hover:text-green-900 hover:bg-green-50' : 'text-red-600 hover:text-red-900 hover:bg-red-50'} p-1 rounded"
                      title="{soci.de_baixa ? 'Donar d\'alta' : 'Donar de baixa'}"
                    >
                      {#if soci.de_baixa}
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                      {:else}
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                      {/if}
                    </button>

                    <!-- Delete Button -->
                    <button
                      on:click={() => deleteSoci(soci)}
                      class="text-red-600 hover:text-red-900 p-1 rounded hover:bg-red-50"
                      title="Eliminar soci"
                      aria-label="Eliminar soci {soci.nom} {soci.cognoms}"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
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
  {:else if !loading && filteredSocis.length === 0 && socis.length > 0}
    <div class="text-center py-12 bg-white rounded-lg border border-gray-200">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">Cap soci trobat</h3>
      <p class="mt-1 text-sm text-gray-500">No hi ha socis que coincideixin amb els filtres aplicats.</p>
      <div class="mt-6">
        <button
          on:click={() => { searchTerm = ''; showInactive = false; }}
          class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
        >
          Esborrar filtres
        </button>
      </div>
    </div>
  {:else if !loading && socis.length === 0}
    <div class="text-center py-12 bg-white rounded-lg border border-gray-200">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">Cap soci registrat</h3>
      <p class="mt-1 text-sm text-gray-500">Comença afegint el primer soci del club.</p>
      <div class="mt-6">
        <button
          on:click={() => { showNewSociForm = true; }}
          class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          Afegir primer soci
        </button>
      </div>
    </div>
  {/if}

  <!-- Loading state -->
  {#if loading}
    <div class="flex justify-center py-12">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
    </div>
  {/if}
