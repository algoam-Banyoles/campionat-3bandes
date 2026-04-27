<script lang="ts">
  /**
   * Encapçalament professional pensat només per a impressió. A pantalla
   * està amagat (`display: none`) — el CSS d'impressió del pare el fa
   * visible al moment d'imprimir.
   */
  export let eventName: string | null | undefined = null;
  export let temporada: string | null | undefined = null;
</script>

<div class="print-title-show" style="display: none;">
  <div class="print-header-container">
    <div class="print-header-left">
      <img src="/logo.png" alt="Foment Martinenc" class="print-logo" />
    </div>
    <div class="print-header-center">
      <h1 class="print-main-title">
        FOMENT MARTINENC - SECCIÓ BILLAR
      </h1>
      <h2 class="print-event-title">
        {eventName || 'Campionat de Billar'}
      </h2>
      <h3 class="print-season">
        Temporada {temporada || new Date().getFullYear()}
      </h3>
    </div>
    <div class="print-header-right"></div>
  </div>
  <hr class="print-divider" />
</div>

<style>
  /* Estils per a l'encapçalament d'impressió. Originalment vivien al
     pare SocialLeagueCalendarViewer; com que l'encapçalament ara és un
     component fill, es mouen aquí per a mantenir l'scoping correcte. */
  @media print {
    .print-header-container {
      display: flex !important;
      align-items: center !important;
      justify-content: space-between !important;
      margin-bottom: 20px !important;
      padding: 15px 20px !important;
    }

    .print-header-left {
      flex: 0 0 auto !important;
    }

    .print-logo {
      height: 60px !important;
      width: auto !important;
      object-fit: contain !important;
    }

    .print-header-center {
      flex: 1 !important;
      text-align: center !important;
      margin: 0 20px !important;
    }

    .print-main-title {
      font-size: 16px !important;
      font-weight: bold !important;
      margin: 0 0 8px 0 !important;
      color: #000 !important;
      text-transform: uppercase !important;
      letter-spacing: 0.5px !important;
    }

    .print-event-title {
      font-size: 14px !important;
      font-weight: bold !important;
      margin: 0 0 6px 0 !important;
      color: #333 !important;
    }

    .print-season {
      font-size: 12px !important;
      font-weight: normal !important;
      margin: 0 0 6px 0 !important;
      color: #666 !important;
    }

    .print-header-right {
      flex: 0 0 auto !important;
    }

    .print-divider {
      border: none !important;
      border-top: 2px solid #333 !important;
      margin: 0 0 20px 0 !important;
    }
  }
</style>
