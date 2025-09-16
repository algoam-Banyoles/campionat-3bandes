import adapterStatic from '@sveltejs/adapter-static';
import adapterAuto from '@sveltejs/adapter-auto';

const dev = process.env.NODE_ENV === 'development';
const vercel = !!process.env.VERCEL;
// Substitueix EL_TEU_REPO pel nom real del teu repo GitHub Pages
const base = dev || vercel ? '' : '/c3b';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: vercel
      ? adapterAuto()
      : adapterStatic({ fallback: '200.html' }), // evita errors 404 refrescant rutes
    paths: { base }
  }
};

export default config;
