<script lang="ts">
  import { onMount } from 'svelte';
  import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
  import { getSociFotoUrl } from '$lib/utils/soci-foto';

  export let numeroSoci: number | null | undefined;
  /** Si es passa directament, evita una query a `socis.foto_path`. */
  export let fotoPath: string | null | undefined = undefined;
  export let size: 'xs' | 'sm' | 'md' | 'lg' | 'xl' = 'md';
  export let round: boolean = true;
  /** Text a mostrar si no hi ha foto o no ets admin (ex: "JM"). Buit = amaga el fallback. */
  export let initials: string = '';
  /** Nom complet per l'atribut alt. */
  export let alt: string = '';
  /** Classes Tailwind addicionals. */
  let extraClass = '';
  export { extraClass as class };

  const sizePx: Record<string, number> = { xs: 24, sm: 32, md: 48, lg: 80, xl: 128 };
  $: px = sizePx[size] ?? 48;
  $: fontPx = Math.round(px * 0.38);

  let url: string | null = null;
  let loading = false;

  async function resolveUrl() {
    if (!$adminChecked || !$isAdmin) {
      url = null;
      return;
    }
    loading = true;
    try {
      if (fotoPath !== undefined) {
        url = fotoPath ? await getSociFotoUrl(fotoPath) : null;
      } else if (numeroSoci != null) {
        url = await getSociFotoUrl(numeroSoci);
      } else {
        url = null;
      }
    } finally {
      loading = false;
    }
  }

  // Reactive: es recarrega quan canvia l'admin status o el soci
  $: if ($adminChecked) {
    $isAdmin;
    numeroSoci;
    fotoPath;
    resolveUrl();
  }
</script>

{#if url}
  <img
    src={url}
    {alt}
    class="{round ? 'rounded-full' : 'rounded'} object-cover bg-gray-200 {extraClass}"
    style="width: {px}px; height: {px}px;"
    loading="lazy"
  />
{:else if initials}
  <div
    class="{round ? 'rounded-full' : 'rounded'} bg-gray-300 text-gray-700 flex items-center justify-center font-semibold select-none {extraClass}"
    style="width: {px}px; height: {px}px; font-size: {fontPx}px;"
    title={alt}
  >
    {initials}
  </div>
{/if}
