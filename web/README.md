# MEMOIR_LOG · web

The marketing site, separate from `app/`. Static Astro 4.x build.

```bash
cd web
npm install
npm run dev      # localhost:4321
npm run build    # → dist/
npm run preview  # serve dist/
```

Design spec lives in `docs/LANDING_PAGE.md` — read that first.

The page is intentionally one-file for clarity: every section composes
small Astro components. Only two of them ship JS (BootCanvas,
LiveStreamTypewriter), each as an island so the rest of the page is
zero-JS.

Lighthouse target: ≥ 95 on Performance and Accessibility. Verify with
`npx lhci autorun` before any release.
