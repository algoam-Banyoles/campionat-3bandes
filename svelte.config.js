import adapterStatic from '@sveltejs/adapter-static';
import adapterAuto from '@sveltejs/adapter-auto';

const dev = process.env.NODE_ENV === 'development';
const vercel = !!process.env.VERCEL;
// Base path sempre buit - ja no necessitem el prefix /c3b
const base = '';

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
