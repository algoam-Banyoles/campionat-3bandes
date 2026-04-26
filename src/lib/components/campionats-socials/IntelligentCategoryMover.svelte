<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import {
    loadPreviousChampions,
    calculateCascadeMovements,
    applyMovements,
    buildUndoMovements,
    type IntelligentContext
  } from '$lib/services/intelligentMovementService';
  import { rememberBatch, clearBatch } from '$lib/stores/movementUndoStore';
  import type {
    Category,
    CategoryMovement,
    InscripcioWithSoci,
    PreviousChampion,
    SociMin,
    UUID
  } from '$lib/types';

  const dispatch = createEventDispatcher<{
    movementsCompleted: { movements: CategoryMovement[]; totalMoved: number };
    error: { message: string };
    /** Notifica que hi ha moviments pendents de confirmació (cascada > 1). */
    movementsPending: { movements: CategoryMovement[] };
  }>();

  export let inscriptions: InscripcioWithSoci[] = [];
  export let categories: Category[] = [];
  export let socis: SociMin[] = [];
  export let eventId: string = '';
  export let currentEvent: { modalitat?: string; temporada?: string } | null = null;
  /**
   * Si és true, els moviments amb cascada (>1 moviment) emeten l'esdeveniment
   * `movementsPending` perquè el component pare mostri un preview abans
   * d'aplicar. El moviment es confirma via `applyPendingMovements()`.
   */
  export let confirmCascade: boolean = true;

  let previousChampions = new Map<number, PreviousChampion>();
  let processing = false;
  let pending: CategoryMovement[] = [];

  $: if (eventId && currentEvent?.modalitat && currentEvent?.temporada) {
    void refreshChampions();
  }

  async function refreshChampions() {
    if (!currentEvent?.modalitat || !currentEvent?.temporada) return;
    previousChampions = await loadPreviousChampions(
      supabase,
      currentEvent.modalitat,
      currentEvent.temporada
    );
  }

  /**
   * Calcula els moviments necessaris i, segons el flux configurat:
   * - Si només hi ha el moviment manual (sense cascada) → aplica directament.
   * - Si hi ha cascada i `confirmCascade` és true → emet `movementsPending`.
   * - Si `confirmCascade` és false → aplica directament (comportament antic).
   */
  export async function movePlayerIntelligently(
    inscriptionId: UUID,
    targetCategoryId: UUID
  ) {
    if (processing) return;

    const ctx: IntelligentContext = {
      inscriptions,
      categories,
      socis,
      previousChampions
    };

    const movements = calculateCascadeMovements(ctx, inscriptionId, targetCategoryId);
    if (movements.length === 0) {
      dispatch('error', { message: 'Inscripció o categoria destí no vàlides' });
      return;
    }

    // Aplicació directa: sense cascada o sense confirmació configurada.
    if (movements.length === 1 || !confirmCascade) {
      await runApply(movements);
      return;
    }

    // Cascada amb confirmació: emetre l'event i recordar pending.
    pending = movements;
    dispatch('movementsPending', { movements });
  }

  /** Confirma i aplica els moviments pendents (cridada pel pare). */
  export async function applyPendingMovements() {
    if (processing || pending.length === 0) return;
    const toApply = pending;
    pending = [];
    await runApply(toApply);
  }

  /** Cancel·la el lot pendent sense aplicar res. */
  export function cancelPendingMovements() {
    pending = [];
  }

  async function runApply(movements: CategoryMovement[]) {
    processing = true;
    try {
      const err = await applyMovements(supabase, movements);
      if (err) throw err;

      rememberBatch(movements, eventId);

      dispatch('movementsCompleted', {
        movements,
        totalMoved: movements.length
      });
    } catch (error: any) {
      console.error('Error in intelligent movement:', error);
      dispatch('error', { message: error.message || 'Error desconegut' });
    } finally {
      processing = false;
    }
  }

  /**
   * Desfà l'últim lot aplicat. Cridada des del pare quan l'usuari clica
   * "Desfer". Retorna true si s'ha pogut desfer.
   */
  export async function undoLastBatch(batch: CategoryMovement[]): Promise<boolean> {
    if (processing || batch.length === 0) return false;
    processing = true;
    try {
      const reversal = buildUndoMovements(batch);
      const err = await applyMovements(supabase, reversal);
      if (err) throw err;
      clearBatch();
      dispatch('movementsCompleted', {
        movements: reversal,
        totalMoved: reversal.length
      });
      return true;
    } catch (error: any) {
      console.error('Error undoing movements:', error);
      dispatch('error', { message: error.message || 'Error desfent moviments' });
      return false;
    } finally {
      processing = false;
    }
  }
</script>

<!-- Aquest component no té UI, només funcionalitat -->
