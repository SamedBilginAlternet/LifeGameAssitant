# Design Language — CRT Chronicle

## North-star aesthetic

> **"Logbook 1.0 — the diary your machine kept while you slept."**
>
> Glowing monochrome text on a black CRT. Scanlines drifting. Characters typing in one at a time, each one chirping a tiny 8-bit click. Modern under the hood, 1988 on the surface.

References: classic VT100 terminals, *Alien*'s Mother computer, Fallout 3's PIP-Boy, the boot screens of an Apple IIe. We're not building a "vintage-themed" app with rounded corners and beige — we're building a **monochrome terminal that happens to run on a phone**.

## Principles

1. **One color at a time.** The whole UI uses one foreground color (Amber or Phosphor Green). No accents. No data colors. Hierarchy comes from brightness.
2. **The page is a terminal window.** Cards have ASCII chrome, not Material elevation. No shadows, ever.
3. **Type, don't fade.** Every block of text reveals via typewriter. New text is *typed*; old text is *shown*. This is the line the app holds.
4. **Sound is identity.** The click track on the typewriter is not decoration; it's the second half of what makes this app feel like 1988. Default on, easily off.
5. **The diary is the product.** Stats live as 8-bit pixel meters *under* the prose. Skill tree is a side route. The home screen is one page per day.

## Palettes

The user picks one in Settings. The system has no other colors.

### Amber — "Sunset CRT" (default)

| Token            | Hex        | Use                                  |
|------------------|-----------|--------------------------------------|
| `bg.canvas`      | `#000000` | App background                       |
| `bg.surface`     | `#0A0705` | Card interior (subtly warmer black)  |
| `fg.bright`      | `#FFB000` | Body text, primary glyphs            |
| `fg.dim`         | `#A36F00` | Secondary text, frame chrome         |
| `fg.ghost`       | `#3D2A00` | Empty meter cells, dividers          |
| `glow`           | `#FFB000` @ 18% opacity | Outer glow on focused elements |

### Phosphor Green — "P3" (alt)

| Token            | Hex        |
|------------------|-----------|
| `bg.canvas`      | `#000000` |
| `bg.surface`     | `#02080A` |
| `fg.bright`      | `#00E676` |
| `fg.dim`         | `#008A45` |
| `fg.ghost`       | `#003319` |
| `glow`           | `#00E676` @ 18% opacity |

Light mode does not exist. The CRT is always on.

## Typography

| Role             | Family               | Size | Why                                      |
|------------------|----------------------|------|------------------------------------------|
| Body (diary)     | **VT323**            | 22   | Readable at distance, period-correct.    |
| UI / chrome      | **Share Tech Mono**  | 14   | Buttons, labels, frame text.             |
| Date header      | **Press Start 2P**   | 11   | Used sparingly — too heavy for body.     |
| Stat numbers     | Share Tech Mono      | 18   | Tabular figures, monospace.              |

Anti-aliasing left at default — VT323 is *designed* to look pixelated and renders cleanly on retina screens. Press Start 2P is reserved for date headers and badges; it is unreadable in long blocks.

## Scanlines

Implemented as a single full-screen `FragmentShader` overlay:

- 1px horizontal lines, 4px stride, **12% opacity** in Amber / **10%** in Green.
- Vertical drift on a 4-second sine loop, ~2px amplitude.
- Disabled automatically when `MediaQuery.disableAnimations == true`.
- Disabled automatically on devices reporting `< 90Hz` to keep performance budget.

Optional flicker layer: 30Hz square wave at 2% brightness modulation. Toggle in Settings → Display → CRT Flicker. Default off (it's vertigo-inducing for some users).

## The Page (a terminal window)

```
┌─[ DAY 1247 ─ 07-MAY-2026 ─ TUE ]──────────────────────┐
│                                                        │
│ > Today the engineer pushed 12 commits to              │
│   Echo-App-Mobile, the most active repo of the week.   │
│   He hit 185g of protein and rode home on the 250NK    │
│   in the cool of evening. The German lesson stuck —    │
│   "Modalverben" finally clicked.                       │
│                                                        │
│ ───────────────────────────────────────────────────    │
│  COMMITS  ████████████░░░░  12/15                      │
│  PROTEIN  ████████████░░░░  185/200g                   │
│  STEPS    ███████░░░░░░░░░  9.2k/12k                   │
│  GERMAN   ███░░░░░░░░░░░░░  25/30m                     │
│                                                        │
│  [SKILL+] LOGIC                                        │
└────────────────────────────────────────────────────────┘
```

- **Box-drawing characters**, not borders. The frame is part of the type, not a `BoxDecoration`.
- The `> ` prompt prefix on the body marks AI-generated text.
- 24px gap between days on the timeline. No card shadows, no hover states.

## Bottom navigation

Three tabs, period-correct chrome. The bar is a single 56pt strip with box-drawing dividers, no background fill — it sits directly on `bg.canvas`.

```
─────────────────────────────────────────────────
  [ TIMELINE ]   [ + CREATE ]   [ STATUS ]
─────────────────────────────────────────────────
```

| Tab          | Route             | Contents                                        |
|--------------|-------------------|-------------------------------------------------|
| `TIMELINE`   | `/`               | The diary — infinite vertical scroll.           |
| `+ CREATE`   | `/capture`        | Voice memo (default action), then quick-add chips for meal, mood, movie, motorcycle, workout. The mic button is the largest target. |
| `STATUS`     | `/status`         | Skill Tree (5 nodes) + integrations health (GitHub, Spotify, Health, Storage). |

Active tab gets a leading `>` cursor (`> [ TIMELINE ]`) and full-bright `fg.bright`; inactive tabs sit at `fg.dim`. Switching plays a soft `confirm.wav` and the redraws cascade column-by-column over 180ms.

## Boot sequence

The first launch after a cold start (or after the user manually pulls down on the Timeline) replays the boot animation. Skipped on warm starts to keep daily use fast.

```
MEMOIR_LOG v1.0 BOOT
> CHECKING STORAGE........... OK
> CONNECTING TO SUPABASE..... OK
> SYNCING ENTRIES (42 days).. OK
> NARRATOR LINK............... ONLINE
> READY.

  [ENTER] TO BEGIN_
```

- Each line types in over ~250ms with the click track.
- The `OK` lights up at full brightness when the underlying check resolves.
- If a check fails, the line shows `FAIL — [R] RETRY` instead. The boot does not block: tapping ENTER skips the failed check and the app degrades gracefully (offline mode, cached entries).
- Animation duration capped at **2.4s total** even if some checks take longer (they finish in the background after the boot completes).
- Disabled if `MediaQuery.disableAnimations == true` — the app boots straight to the timeline.

The same animation is used in the landing page hero — see `LANDING_PAGE.md`.

## Pixel meters

8-bit progress bars built from filled (`█`) and empty (`░`) blocks, snapped to 16 cells. Filling animates block-by-block on first paint, 400ms total. Over-target is shown by changing the trailing block to `▓` rather than overflowing.

## Pixel icons

Curated **16×16 PNG sprite set**, ~40 icons:

- Code: `commit`, `branch`, `pr`, `terminal`
- Body: `dumbbell`, `running`, `protein`, `motorcycle`
- Mind: `book`, `brain`, `flag-de`
- Culture: `film`, `tv`, `headphones`
- Mood: face frames at 1, 4, 7, 10

Stored in `app/assets/icons/`. Two-tone palette per active theme — the icon itself is a 1-bit mask, tinted at render time. AI-generated pixel art is a v2 enhancement (see ROADMAP).

## Motion vocabulary

| Element             | Effect                              | Duration              |
|---------------------|-------------------------------------|-----------------------|
| Page first reveal   | Typewriter + 8-bit click per char   | length ÷ ~28 char/sec |
| Day swipe           | CRT power-on flicker (3 frames)     | 240ms                 |
| Pixel meter fill    | Block-by-block reveal               | 400ms                 |
| Empty state cursor  | `_` blink at 1Hz                    | infinite              |
| Sheet present       | Lines redraw top-down               | 280ms                 |

`MediaQuery.disableAnimations` collapses every motion above to its end-state instantly. Typewriter still respects this — the text appears whole, click track muted.

## Sound design

| Sample              | When                          | Notes                                |
|---------------------|-------------------------------|--------------------------------------|
| `key-click.wav`     | Each typewriter char          | 6ms square-wave click, -12 dB ceiling |
| `power-on.wav`      | Day swipe                     | 180ms warm-up sweep                  |
| `confirm.wav`       | Save action                   | Two-tone arpeggio                    |
| `error.wav`         | Failed sync / Groq error      | Descending two-tone                  |

Implementation:
- Single `audioplayers` `AudioPlayer` instance, pooled across the app.
- Click sample preloaded into memory on app start to avoid first-tap latency.
- Settings → Audio toggle (default **ON**). Per-session mute via long-press anywhere on a diary page.
- Respects iOS silent switch and Android DnD automatically.
- Volume capped at -12 dB; cannot be jarring even in a quiet room.

## Haptics

Subtle, not chatty. Every haptic uses Flutter's built-in `HapticFeedback` — no external package.

| Trigger                          | Pattern                  | API                                  |
|----------------------------------|--------------------------|--------------------------------------|
| Primary tap (action button)      | Mechanical-key click     | `HapticFeedback.lightImpact()`       |
| Tab switch                       | Soft tick                | `HapticFeedback.selectionClick()`    |
| Save / commit succeeded          | Two-pulse confirmation   | `HapticFeedback.mediumImpact()` ×2 (50ms apart) |
| Error (Groq fail, network)       | Single firm thump        | `HapticFeedback.heavyImpact()`       |
| Long-press toggles (mute, etc.)  | Long buzz                | `HapticFeedback.vibrate()`           |

Toggleable globally in Settings → Haptics. Default **ON**. The combination of a 6ms click sound + a `lightImpact` on each typewriter character is *not* recommended — too noisy. Click track plays per-char; haptic fires only on the user-initiated **tap that started** the typewriter, not on each glyph.

## States (in terminal voice)

- **Loading:** `> CONNECTING ███▒▒▒▒▒▒▒▒▒▒▒▒░  31%`
- **Empty day:** `> NO DATA RECORDED FOR 07-MAY-2026.`
- **Sync error:** `> CONNECTION TIMEOUT. RETRY IN 30s  [R]`
- **Groq failure:** `> NARRATOR OFFLINE. RETRY AT 23:50 TOMORROW.`

Every error is a sentence the user can read out loud and understand. No stack traces, no `[object Object]`.

## Brand voice (UI copy)

- Hints in lowercase: `> log something_`
- Actions in caps with brackets: `[ENTER]`, `[SAVE]`, `[ABORT]`
- Headers in caps: `LOGBOOK · 1.0`
- No exclamation marks. The terminal is calm.

## Accessibility

- VT323 at 22pt passes WCAG AA on both palettes (~13:1 contrast in Amber, ~14:1 in Green).
- Dynamic type respected up to **130%**; the diary page wraps, never truncates.
- All motion respects `disableAnimations`.
- All sound respects a one-tap toggle and the system silent switch.
- The Press Start 2P date header has a Share Tech Mono fallback when the user's accessibility flag indicates "prefer simple fonts."
- Pixel icons paired with text labels everywhere — colorblindness is irrelevant since the UI is monochrome, but the redundancy still helps icon-blindness.
