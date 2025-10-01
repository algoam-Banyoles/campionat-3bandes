<script lang="ts">
  let visible = false;

  function handleFocus() {
    visible = true;
  }

  function handleBlur() {
    visible = false;
  }
</script>

<a
  href="#main-content"
  class="skip-link"
  class:visible
  on:focus={handleFocus}
  on:blur={handleBlur}
>
  Salta al contingut principal
</a>

<style>
  .skip-link {
    position: absolute;
    top: -100px;
    left: 20px;
    z-index: 9999;
    padding: 12px 16px;
    background: #1f2937;
    color: white;
    text-decoration: none;
    border-radius: 4px;
    font-weight: 600;
    font-size: 1.125rem;
    transition: top 0.2s ease;
  }

  .skip-link.visible,
  .skip-link:focus {
    top: 20px;
  }

  /* Enhanced focus for desktop */
  @media (hover: hover) and (pointer: fine) {
    .skip-link:focus-visible {
      outline: 4px solid #fbbf24;
      outline-offset: 3px;
      box-shadow: 0 0 0 2px white, 0 0 0 7px #fbbf24, 0 0 16px rgba(251, 191, 36, 0.4);
      transform: translateY(-2px);
    }
  }

  /* Standard focus for non-desktop */
  @media not all and (hover: hover) and (pointer: fine) {
    .skip-link:focus-visible {
      outline: 3px solid #fbbf24;
      outline-offset: 2px;
    }
  }

  /* High contrast mode */
  :global(.high-contrast) .skip-link {
    background: #000000 !important;
    color: #ffffff !important;
    border: 3px solid #ffffff !important;
  }

  :global(.high-contrast) .skip-link:focus {
    outline: 4px solid #ff0000 !important;
    outline-offset: 2px !important;
  }

  /* Respect reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .skip-link {
      transition: none;
    }
  }
</style>