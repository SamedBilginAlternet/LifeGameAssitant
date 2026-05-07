# MEMOIR_LOG · v1.0

> *"The diary that writes itself."*
>
> Codename: **Logbook 1.0**.

An **Automated Memoir**. Your commits, your gym sets, the meal at lunch, the album on repeat, the movie you watched, the 25 minutes of German on the couch, the ride home on the CF Moto, a single photo of the day — every fragment lands in one Supabase database. At 23:50, a Groq-hosted narrator stitches the day into a hand-written diary entry. The next morning you open the app to a new page in your life.

You don't write the diary. You live, and the diary writes itself.

## Status

Planning. No code yet. This repo holds the design and architecture documents the implementation will follow.

## Stack at a glance

| Layer        | Choice                                                  |
|--------------|---------------------------------------------------------|
| Client       | Flutter 3.x (iOS + Android)                             |
| Backend      | Supabase (Postgres + Auth + Edge Functions + pg_cron)   |
| AI Narrator  | Groq · `llama-3.3-70b-versatile` (OpenAI-compatible)    |
| Photos       | Device library via `photo_manager` → Supabase Storage   |
| Voice        | `record` (capture) → Groq `whisper-large-v3` (transcribe) |

## The five domains tracked

| Domain     | What gets captured                                                              |
|------------|---------------------------------------------------------------------------------|
| **Code**   | GitHub commits, PRs, repos touched                                              |
| **Body**   | Workouts (sets/reps), steps, protein, **meals**, motorcycle rides               |
| **Mind**   | German practice (A2), Master's research topics, books                           |
| **Culture**| Movies & shows (TMDB), **top track / album of the day** (Spotify recently-played) |
| **Memory** | Mood 1–10, optional voice note (German welcomed; auto-translated), **one photo of the day** |

## Documents

Read in order — each one assumes the previous.

1. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — three planes, daily pipeline, Groq integration.
2. [docs/TECH_STACK.md](docs/TECH_STACK.md) — every library and why, plus the Groq + Whisper choices.
3. [docs/DATA_MODEL.md](docs/DATA_MODEL.md) — Supabase schema for diary entries, workouts, movies, voice notes.
4. [docs/AI_PROMPTS.md](docs/AI_PROMPTS.md) — the Diary Writer prompt, voice variants, Groq parameters.
5. [docs/DESIGN.md](docs/DESIGN.md) — CRT Chronicle aesthetic, monochrome terminal, typewriter + 8-bit click track.
6. [docs/ROADMAP.md](docs/ROADMAP.md) — phased delivery from manual MVP to voice-driven German practice.
7. [docs/LANDING_PAGE.md](docs/LANDING_PAGE.md) — the Digital Time Capsule: marketing site with boot-sequence hero.
8. [docs/CODE_STANDARDS.md](docs/CODE_STANDARDS.md) — Clean Architecture, SOLID, Riverpod DI, `fpdart` Either, `ThemeExtension`, when *not* to layer.

## North star

1. **The diary is the product.** Stats, charts, and skill trees are side routes. The home screen is one page per day.
2. **Capture is invisible.** If logging takes more than a tap or two, the design has failed.
3. **The page is a terminal window.** Monochrome glow, scanlines, typewriter reveal, no exclamation marks.
4. **Free forever for one user.** Every dependency lives on a free tier. Groq, Supabase, TMDB, device photos — all $0.
