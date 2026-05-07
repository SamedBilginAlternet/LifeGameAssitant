# LifeGameAssistant

> *"The diary that writes itself."*

An **Automated Memoir**. Your commits, your gym sets, the movie you watched last night, the 25 minutes of German on the couch, the ride home on the CF Moto — every fragment lands in one Supabase database. At 23:50, a Groq-hosted narrator stitches the day into a hand-written diary entry. The next morning you open the app to a new page in your life.

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

| Domain     | What gets captured                                                |
|------------|-------------------------------------------------------------------|
| **Code**   | GitHub commits, PRs, repos touched                                |
| **Body**   | Workouts (sets/reps), protein, steps, motorcycle rides            |
| **Mind**   | German practice (A2), Master's research topics, books             |
| **Culture**| Movies & shows watched (TMDB-resolved title + poster)             |
| **Mood**   | 1–10 score + optional voice note (German welcomed; auto-translated) |

## Documents

Read in order — each one assumes the previous.

1. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — three planes, daily pipeline, Groq integration.
2. [docs/TECH_STACK.md](docs/TECH_STACK.md) — every library and why, plus the Groq + Whisper choices.
3. [docs/DATA_MODEL.md](docs/DATA_MODEL.md) — Supabase schema for diary entries, workouts, movies, voice notes.
4. [docs/AI_PROMPTS.md](docs/AI_PROMPTS.md) — the Diary Writer prompt, voice variants, Groq parameters.
5. [docs/DESIGN.md](docs/DESIGN.md) — CRT Chronicle aesthetic, monochrome terminal, typewriter + 8-bit click track.
6. [docs/ROADMAP.md](docs/ROADMAP.md) — phased delivery from manual MVP to voice-driven German practice.

## North star

1. **The diary is the product.** Stats, charts, and skill trees are side routes. The home screen is one page per day.
2. **Capture is invisible.** If logging takes more than a tap or two, the design has failed.
3. **The page is a terminal window.** Monochrome glow, scanlines, typewriter reveal, no exclamation marks.
4. **Free forever for one user.** Every dependency lives on a free tier. Groq, Supabase, TMDB, device photos — all $0.
