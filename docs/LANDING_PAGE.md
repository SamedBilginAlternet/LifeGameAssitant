# Landing Page — The Digital Time Capsule

A marketing site that boots like a 1988 machine, scrolls like a manifesto, and converts like a 2026 funnel. The page should feel like the app is already running — visitors don't see a description of MEMOIR_LOG, they see it *operating*.

## Goals

1. Communicate the "automated memoir" thesis in under 8 seconds of scroll.
2. Demonstrate the CRT Chronicle aesthetic so the install is a visual recognition, not a leap of faith.
3. Convert: App Store + Play Store badges, plus an email capture for the TestFlight beta.
4. Survive a Hacker News spike on Vercel's free tier — Lighthouse ≥ 95 across the board.

## Tech stack

| Layer        | Choice                | Why                                           |
|--------------|----------------------|-----------------------------------------------|
| Framework    | **Astro 4.x**        | Zero JS by default. Component islands only where interactive. |
| Styling      | Tailwind CSS         | Atomic utilities, easy retro palette tokens.  |
| Type         | `@fontsource` self-hosted: VT323, Share Tech Mono, Press Start 2P | No Google Fonts CDN — eliminates a request and a privacy concern. |
| Hero canvas  | Plain HTML5 Canvas   | ~80 lines of JS. No `react-three`, no engine. |
| Demo widget  | Vanilla JS island    | Renders pre-recorded diary entries with the typewriter effect. |
| Analytics    | Plausible (self-host or hosted free tier) | Privacy-respecting, no cookie banner needed. |
| Deployment   | Vercel (free tier)   | Edge cache covers HN-spike traffic effortlessly. |
| Domain       | TBD (suggestions: `memoirlog.app`, `logbook.diary`) |                          |

## Page structure (top → bottom)

```
1. BOOT HERO            — full viewport, the boot animation + tagline + CTA
2. THE PITCH            — three sentences of "what this is"
3. DIR /CODE            — directory entry: GitHub auto-capture
4. DIR /BODY            — directory entry: workouts, meals, fitness, 250NK
5. DIR /MIND            — directory entry: German, Master's, books
6. DIR /CULTURE         — directory entry: movies + music
7. DIR /MEMORY          — directory entry: mood, voice, daily photo
8. LIVE STREAM DEMO     — scrolling preview of fake-but-realistic entries
9. THE NIGHTLY RITUAL   — diagram of the 23:50 cron
10. CTA STRIP           — store badges + email capture
11. FOOTER              — minimal ASCII signoff
```

## Section recipes

### 1. Boot hero

Full-viewport black canvas. The boot sequence types itself in over ~2.4 seconds with the click track audible (autoplay-muted by default; a `[♪ AUDIO ON]` chip in the corner unmutes after the first user interaction).

```
MEMOIR_LOG v1.0 BOOT

> CHECKING STORAGE........... OK
> CONNECTING TO SUPABASE..... OK
> SYNCING ENTRIES (1247)..... OK
> NARRATOR LINK............... ONLINE
> READY.

  THE DIARY THAT WRITES ITSELF.

  [ INITIALIZE_SYSTEM ]   ← glowing button, Amber palette
  scroll for transmission ▼
```

The CTA button has a 1-second pulse glow loop using `box-shadow` only — no animation library. Tap → smooth-scrolls to the CTA strip and triggers a download intent.

### 2. The Pitch (the only prose)

Three sentences. No more. Set in VT323 22pt.

> Your commits, your gym sets, the meal at lunch, the album on repeat — every fragment of your day lands in one place. At 23:50 a quiet narrator stitches it into a hand-written diary entry, complete with the photo you took and the soundtrack you lived in. The next morning you open the app to a new page in your life.

### 3–7. The directory blocks

Each domain rendered as a faux `dir` listing. Identical structure, different contents. The icon on the left is a 16×16 sprite from the curated pixel set.

```
┌─[ DIR /BODY ]───────────────────────────────────────┐
│                                                      │
│  [icon: dumbbell]  WORKOUTS         AUTO + MANUAL    │
│  [icon: protein ]  MEALS & MACROS   MANUAL           │
│  [icon: steps   ]  STEPS            HEALTHKIT        │
│  [icon: bike    ]  MOTORCYCLE       MANUAL           │
│                                                      │
│  > captures the body's day without making you tap    │
│    through eight screens.                            │
└──────────────────────────────────────────────────────┘
```

Hover (desktop) / tap (mobile) reveals an example diary fragment for that domain.

### 8. Live stream demo

The most important section. A faux phone bezel containing a continuously scrolling timeline of diary entries — pre-recorded, but rendered with the same typewriter effect the app uses. The visitor watches a stranger's life narrate itself in real time.

- Three example entries cycle on a 12-second loop.
- Each entry types in (~6s), holds (~3s), then scrolls up to make room for the next.
- All audio muted unless the user explicitly enabled audio in section 1.
- Pre-recorded entries are written by hand to showcase variety: a coding day, a gym day, a quiet day. Never real user data.

### 9. The Nightly Ritual

A simple ASCII diagram explaining the 23:50 cron. This is the section that converts engineers — they recognize the architecture and trust it.

```
     23:50           23:51              23:52              next morning
       │               │                  │                     │
   pg_cron        Edge Function       Llama 3.3            Diary page
    fires.         aggregates         70B writes           visible.
                   the day's          ~100 words.          Typewriter
                   rows.                                   reveal.
```

### 10. CTA strip

Three columns:

```
┌──────────────────┬──────────────────┬──────────────────┐
│   App Store      │   Play Store     │   Beta access    │
│   [download]     │   [download]     │   [email_]       │
└──────────────────┴──────────────────┴──────────────────┘
```

Email goes to a Supabase table `beta_signups` via Edge Function — no Mailchimp, no Convertkit, no third-party JS.

### 11. Footer

```
─────────────────────────────────────────────────────────
  MEMOIR_LOG · v1.0 · built by samed · groq + supabase
  [github]  [twitter]  [rss]
─────────────────────────────────────────────────────────
```

## Performance budget

| Metric                           | Target            |
|----------------------------------|-------------------|
| Total page weight (initial)      | < 80 KB gzipped   |
| JS payload (initial)             | < 10 KB           |
| Hero LCP                         | < 1.5 s on 4G     |
| Lighthouse Performance           | ≥ 95              |
| Lighthouse Accessibility         | ≥ 95              |

Tactics: Astro static output, fonts subset to `latin` only, sprites in a single PNG atlas, audio sample loaded on first user interaction (not on page load), demo widget as a deferred island below the fold.

## Accessibility

- Every animation respects `prefers-reduced-motion` — the boot sequence collapses to its end-state, the typewriter renders entire entries, the pulse glow becomes a static border.
- Audio is **never** unmuted without explicit user action.
- All ASCII-art sections have visually-hidden plaintext alternatives in `<span class="sr-only">` for screen readers.
- Color contrast: VT323 22pt amber-on-black is ~13:1, well above AA. The dim variant is ~7:1.
- Tab order follows visual order. Focus rings use the same glow as hovered CTAs.

## Out of scope (v1 of the landing page)

- Internationalization. English only at launch.
- Blog / changelog. The repo's CHANGELOG.md is enough for now.
- Self-serve account creation on the web. Install the app to use the app.
- A/B testing infrastructure. Ship one good page first.
