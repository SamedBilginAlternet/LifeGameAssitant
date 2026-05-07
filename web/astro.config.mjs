import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';

// Static-only output. Vercel serves it from the edge cache, so an HN
// spike doesn't pierce through to any compute.
export default defineConfig({
  output: 'static',
  integrations: [tailwind({ applyBaseStyles: false })],
  build: {
    inlineStylesheets: 'always',
  },
  prefetch: { prefetchAll: false },
});
