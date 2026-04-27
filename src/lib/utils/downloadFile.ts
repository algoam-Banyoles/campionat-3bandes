/**
 * Disparar la descàrrega d'un fitxer al navegador a partir de contingut
 * en memòria. Encapsula la creació del Blob, l'URL temporal i el clic
 * sintètic. Si el navegador no suporta `link.download`, no fa res.
 */
export function downloadAsFile(content: string, filename: string, mimeType: string): void {
  const blob = new Blob([content], { type: mimeType });
  const link = document.createElement('a');
  if (link.download === undefined) return;
  const url = URL.createObjectURL(blob);
  link.setAttribute('href', url);
  link.setAttribute('download', filename);
  link.style.visibility = 'hidden';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/** Sanititza un text per fer-lo segur dins d'un nom de fitxer. */
export function sanitizeFilename(name: string): string {
  return name.replace(/[^a-zA-Z0-9]/g, '_');
}
