import type { Action } from 'svelte/action';

/**
 * Mou el node arrel d'un modal d'impressió com a fill directe de document.body
 * perquè el CSS `@media print` pugui aïllar-lo de la resta de la pàgina amb
 *
 *     :global(body > *:not(.print-portal)) { display: none !important; }
 *
 * Així window.print() només imprimeix el contingut del modal i no la
 * navegació/header de l'app que hi ha darrere.
 *
 * Ús al component:
 *   <div class="modal-overlay print-portal" use:printPortal> ... </div>
 */
export const printPortal: Action<HTMLElement> = (node) => {
	document.body.appendChild(node);
	return {
		destroy() {
			if (node.parentNode === document.body) {
				document.body.removeChild(node);
			}
		}
	};
};
