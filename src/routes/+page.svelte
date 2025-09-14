<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user, authReady } from '$lib/authStore';
  import { getSettings, type AppSettings } from '$lib/settings';
  import { get } from 'svelte/store';

  type Challenge = {
    id: string;
    reptador_id: string;
    reptat_id: string;
    estat: string;
    data_proposta: string;
    data_programada: string | null;
    reptador_nom?: string;
    reptat_nom?: string;
  };

  let loading = true;
  let error: string | null = null;
  let active: Challenge[] = [];
  let pending: Challenge[] = [];
  let recent: Challenge[] = [];
  let warnings: string[] = [];
  let settings: AppSettings;

  onMount(() => {
    const unsub = authReady.subscribe(async (ready) => {
      if (!ready) return;
      const u = get(user);
      if (!u?.email) {
        goto('/ranking');
        loading = false;
        unsub();
        return;
      }
      try {
        const { supabase } = await import('$lib/supabaseClient');
        settings = await getSettings();

        const { data: p, error: e1 } = await supabase
          .from('players')
          .select('id')
          .eq('email', u.email)
          .maybeSingle();
        if (e1) throw e1;
        if (!p) {
          error = 'El teu email no està vinculat a cap jugador.';
          return;
        }
        const myId = p.id;

        const { data: ch, error: e2 } = await supabase
          .from('challenges')
          .select('id,reptador_id,reptat_id,estat,data_proposta,data_programada')
          .or(`reptador_id.eq.${myId},reptat_id.eq.${myId}`)
          .order('data_proposta', { ascending: false });
        if (e2) throw e2;

        const ids = Array.from(
          new Set([...(ch ?? []).map((c) => c.reptador_id), ...(ch ?? []).map((c) => c.reptat_id)])
        );
        let nameById = new Map<string, string>();
        if (ids.length) {
          const { data: players, error: e3 } = await supabase
            .from('players')
            .select('id,nom')
            .in('id', ids);
          if (e3) throw e3;
          nameById = new Map(players?.map((pl) => [pl.id, pl.nom]) ?? []);
        }

        active = [];
        pending = [];
        recent = [];
        warnings = [];

        const now = new Date();
        for (const c of ch ?? []) {
          const item: Challenge = {
            ...c,
            reptador_nom: nameById.get(c.reptador_id) ?? '—',
            reptat_nom: nameById.get(c.reptat_id) ?? '—'
          };
          if (['acceptat', 'programat'].includes(c.estat)) {
            active.push(item);
          }
          if (c.estat === 'proposat' && c.reptat_id === myId) {
            pending.push(item);
            const daysPassed = diffDays(new Date(c.data_proposta), now);
            const daysLeft = settings.dies_acceptar_repte - daysPassed;
            if (daysLeft <= 2) {
              warnings.push(
                `Queden ${daysLeft} dies per acceptar el repte de ${item.reptador_nom}.`
              );
            }
          }
          if (c.estat === 'jugat') {
            recent.push(item);
          }
        }
        recent = recent
          .sort(
            (a, b) =>
              new Date(b.data_programada ?? 0).getTime() -
              new Date(a.data_programada ?? 0).getTime()
          )
          .slice(0, 5);
      } catch (e: any) {
        error = e?.message ?? 'Error desconegut carregant dades.';
      } finally {
        loading = false;
      }
      unsub();
    });
  });

  function diffDays(d1: Date, d2: Date) {
    const ms = d2.getTime() - d1.getTime();
    return Math.floor(ms / (1000 * 60 * 60 * 24));
  }
</script>

<h1 class="text-2xl font-bold mb-4">Resum del campionat</h1>

{#if error}
  <div class="rounded border border-red-300 bg-red-50 text-red-900 p-4 mb-4">{error}</div>
{:else if loading}
  <p>Carregant...</p>
{:else}
  <section class="mb-6">
    <h2 class="text-xl font-semibold mb-2">Reptes actius</h2>
    {#if active.length}
      <ul class="space-y-2">
        {#each active as r}
          <li class="p-3 border rounded">
            <div class="font-medium">{r.reptador_nom} vs {r.reptat_nom}</div>
            <div class="text-sm text-slate-600">{r.estat}</div>
          </li>
        {/each}
      </ul>
    {:else}
      <p class="text-slate-600">No tens reptes actius.</p>
    {/if}
  </section>

  <section class="mb-6">
    <h2 class="text-xl font-semibold mb-2">Reptes pendents de resposta</h2>
    {#if pending.length}
      <ul class="space-y-2">
        {#each pending as r}
          <li class="p-3 border rounded">
            <div class="font-medium">{r.reptador_nom} vs {r.reptat_nom}</div>
            <div class="text-sm text-slate-600">
              Proposat {new Date(r.data_proposta).toLocaleDateString()}
            </div>
          </li>
        {/each}
      </ul>
    {:else}
      <p class="text-slate-600">No tens reptes pendents.</p>
    {/if}
  </section>

  <section class="mb-6">
    <h2 class="text-xl font-semibold mb-2">Reptes jugats recentment</h2>
    {#if recent.length}
      <ul class="space-y-2">
        {#each recent as r}
          <li class="p-3 border rounded">
            <div class="font-medium">{r.reptador_nom} vs {r.reptat_nom}</div>
            <div class="text-sm text-slate-600">
              {r.data_programada
                ? new Date(r.data_programada).toLocaleDateString()
                : ''}
            </div>
          </li>
        {/each}
      </ul>
    {:else}
      <p class="text-slate-600">No hi ha reptes recents.</p>
    {/if}
  </section>

  <section class="mb-6">
    <h2 class="text-xl font-semibold mb-2">Avisos de terminis</h2>
    {#if warnings.length}
      <ul class="list-disc list-inside space-y-1">
        {#each warnings as w}
          <li>{w}</li>
        {/each}
      </ul>
    {:else}
      <p class="text-slate-600">No hi ha avisos.</p>
    {/if}
  </section>
{/if}
