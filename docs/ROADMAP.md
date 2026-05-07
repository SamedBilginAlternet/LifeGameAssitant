# Roadmap

The build is sliced so that **after every phase, the app is usable end-to-end** — even if the feature set is small. We never spend a week on plumbing without a screen to show for it.

## Phase 0 — Scaffolding (1–2 days)

**Goal:** running app + running backend, with auth.

- [ ] `flutter create app` with riverpod + go_router skeleton.
- [ ] Supabase project created. Auth (Apple + Google) wired.
- [ ] Migration `0001_init.sql`: `profiles`, RLS, trigger to auto-create profile on signup.
- [ ] Theme tokens from `DESIGN.md` baked into `app/theme/` (Amber palette, VT323 + Share Tech Mono via `google_fonts`).
- [ ] CI: `flutter analyze` + `flutter test` on PR.

**Done when:** sign in → see an empty timeline that says `> NO ENTRIES YET. LIVE A DAY.`

## Phase 1 — Manual MVP + first Groq entry (3–4 days)

**Goal:** the app works end-to-end with manual data only.

- [ ] Migration `0002_logs.sql`: `daily_logs`, `fitness_data`, `learning_logs`, `entries`.
- [ ] Groq API key stored in Supabase Vault.
- [ ] Capture sheet with quick-add for Mood, Protein, German, Note.
- [ ] Diary timeline with the **terminal-window Page** component (basic styling — full CRT polish lands in Phase 2).
- [ ] Edge Function `daily-summary` v1 with the `mentor` prompt (`AI_PROMPTS.md`), Llama 3.3 70B.
- [ ] `pg_cron` job at 23:50 UTC.
- [ ] Realtime subscription on `entries` so the next morning's page appears without refresh.

**Done when:** Samed logs three days manually and gets three coherent diary entries.

## Phase 2 — CRT Polish (2–3 days)

**Goal:** the aesthetic flip. The app *looks* like Logbook 1.0.

- [ ] Scanline `FragmentShader` overlay (12% opacity, 4s vertical drift).
- [ ] Typewriter reveal on first paint of any new entry (`animated_text_kit`).
- [ ] 8-bit click sample (`audioplayers`), preloaded, gated by Settings toggle. -12 dB ceiling.
- [ ] Pixel-meter component (block-by-block fill).
- [ ] Press Start 2P date headers, box-drawing chrome on every page.
- [ ] CRT power-on flicker on day-swipe transitions.
- [ ] Settings → Display: palette picker (Amber / Phosphor Green), CRT Flicker toggle, Audio toggle.
- [ ] Reduced-motion + reduced-sound fallbacks verified.

**Done when:** the screenshot is good enough to post.

## Phase 3 — GitHub & Fitness ingestion (3–4 days)

**Goal:** the boring stuff captures itself.

- [ ] `integrations` table + Vault-encrypted GitHub PAT.
- [ ] Settings → Integrations → Connect GitHub (paste token, validate via `/user`).
- [ ] Edge Function `github-poll` running every 30 min via `pg_cron` → fills `github_events`.
- [ ] `health` package wired in the app — read steps + calories on foreground, batch upsert.
- [ ] Manual protein quick-add stays (the `health` package can't infer this on Android).
- [ ] Pixel meters pull from real data.

**Done when:** Samed doesn't have to log commits or steps manually for a full week.

## Phase 4 — Movies, Workouts, Motorcycle, Meals (3 days)

**Goal:** the diary covers everything that actually happens in the day.

- [ ] Migration `0003_richer_logs.sql`: `workouts`, `workout_sets`, `movies_watched`, `motorcycle_rides`, `meals`.
- [ ] Workouts feature: set/rep entry sheet, exercise picker (curated list of ~30 lifts).
- [ ] Movies feature: TMDB search → quick-add with poster + year + 1–5 star rating.
- [ ] Meals feature: quick-add with title + optional macros + optional photo.
- [ ] Motorcycle quick-add: distance + route tag (free-text, autocomplete from history).
- [ ] Diary writer prompt updated to mention movies + the CF Moto 250NK by name + meals when notable.

**Done when:** an entry can authentically say "the evening closed with Blade Runner."

## Phase 4.5 — Music & Daily Photo (2 days)

**Goal:** the soundtrack and the snapshot.

- [ ] Migration `0004_music_photo.sql`: `music_listens`, `media_assets` extensions.
- [ ] Spotify OAuth (PKCE) wired via `app_links` deep-link callback.
- [ ] Edge Function `spotify-poll` running every 30 min via `pg_cron` → fills `music_listens`.
- [ ] Top-of-day track derivation in the nightly summary (play count + duration).
- [ ] `[+ PHOTO]` chip on the active diary page → `image_picker` → compress → upload to `covers/`.
- [ ] 1-bit dither shader on cover photo render so it sits inside the CRT aesthetic.
- [ ] Diary writer prompt updated for `music` block and `cover_photo.present`.

**Done when:** an entry says "the day moved to Radiohead in the background" and the cover photo is dithered into the page.

## Phase 5 — Voice notes & German A2 loop (3–4 days)

**Goal:** the app pulls double duty as a German practice tool.

- [ ] Migration `0004_voice.sql`: `voice_notes`, `media_assets`, Storage buckets `voice/` + `covers/`.
- [ ] `record` package wired — mic button on the diary page, max 60s.
- [ ] Edge Function `voice-transcribe`: Whisper (Groq) → Llama for translation + A2 corrections.
- [ ] Voice-note card on the diary page: play button, transcript, English translation, corrections list.
- [ ] Diary writer mentions the voice note inline when present.

**Done when:** Samed records a thought in German on the couch, and the next morning's page shows what he said, what he meant, and how to fix it.

## Phase 6 — Skill Tree + integrations health (2 days)

**Goal:** the `STATUS` tab earns its place.

- [ ] Skill Tree screen (radial layout, 5 nodes: Logic, Vitality, Linguistics, Culture, Academic).
- [ ] XP formula: rolling 30-day domain activity. Each entry's `top_skill` adds bonus XP.
- [ ] Pixel-art level-up animation. The one place in the app where motion is *delight* rather than confirmation.
- [ ] Integrations health panel: per-source `OK / STALE / FAILED` chips with last-poll timestamp.

**Done when:** opening STATUS at the end of a productive month both feels rewarding and tells you which pollers are healthy.

## Phase 7 — Landing page (Digital Time Capsule) (2 days)

**Goal:** a portfolio-grade marketing site that doubles as the install funnel.

- [ ] Astro 4.x + Tailwind project at `web/` (separate from `app/`).
- [ ] Boot sequence hero (Canvas-rendered, ~80 lines of JS, lazy-loaded as an island).
- [ ] Feature directory blocks: `DIR /CODE`, `DIR /BODY`, `DIR /MIND`, `DIR /CULTURE`, `DIR /MEMORY`.
- [ ] Live-stream demo: scrolling preview of pre-recorded diary entries with the typewriter effect.
- [ ] Glowing CTA: `[ INITIALIZE_SYSTEM ]` → App Store + Play Store badges.
- [ ] Deployed on Vercel free tier. Lighthouse score ≥ 95 on Performance + Accessibility.

**Done when:** the landing page can survive a Hacker News front-page spike on the free tier.

## Phase 7+ — Quality of life (rolling)

- Cover-photo workflow (curated pixel icons → optional dithered photo render via shader → optional AI pixel art via Pollinations / HF Inference).
- Evening mood-prompt local notification.
- Share-card export (PNG of the diary page styled as a CRT screenshot).
- Backup / export (full JSON dump from Settings).
- Weekly synthesis on Sundays.

## Out of scope (and staying that way)

- Multi-user / social features. The product is for one person.
- Web dashboard. Mobile-only is the constraint that keeps focus.
- Photos / journal media uploads. Privacy cost > value (cover photo flow stays local-first).
- Streaks-and-badges habit tracking. That's a different app; this one narrates, doesn't gamify into anxiety.
- Background GPS. Coarse foreground tags only.

## Capacity & cadence

- Solo build. Realistic cadence: **one phase per weekend.**
- Phases 0–3 form the actual MVP. Shippable to TestFlight after Phase 3.
- Phase 5 (voice + German) is the "second product moment" — worth showing publicly.
- Phases beyond 5 are quality and joy — never blockers for using the app daily.
