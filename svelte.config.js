import adapter from '@sveltejs/adapter-static';

const dev = process.env.NODE_ENV === 'development';
// Substitueix EL_TEU_REPO pel nom real del teu repo GitHub Pages
const base = dev ? '' : '/c3b';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter({
      fallback: '200.html'   // evita errors 404 refrescant rutes
    }),
    paths: { base }
  }
};

export default config;
