# Tech Stack

Every dependency is justified. No library lands here just because it's popular — if a need can be met by the SDK or a 30-line helper, we don't add a package.

## Flutter (client)

### Core
| Package              | Why                                                            |
|----------------------|----------------------------------------------------------------|
| `flutter` (3.x)      | UI runtime.                                                    |
| `supabase_flutter`   | Auth, Postgres, Realtime, Storage in one client. First-party.  |
| `flutter_riverpod`   | State mgmt. Compile-time safe, testable, no `BuildContext` needed for reads. |
| `go_router`          | Declarative routing. Plays well with deep links for share-page. |

### Data & persistence
| Package                          | Why                                            |
|----------------------------------|------------------------------------------------|
| `hive_flutter`                   | Local cache + offline write queue.             |
| `flutter_secure_storage`         | Stores Supabase refresh token.                 |
| `freezed` + `json_serializable`  | Immutable models with codegen JSON.            |

### Capture (the new stuff)
| Package                          | Why                                            |
|----------------------------------|------------------------------------------------|
| `health`                         | HealthKit + Health Connect unified — steps, calories, workouts. |
| `record`                         | Voice memo capture (.m4a). Smaller and simpler than `flutter_sound`. |
| `audioplayers`                   | Playback of voice notes + 8-bit click track + power-on / confirm SFX. |
| `image_picker`                   | **Daily photo upload (v1 cover).** Camera or gallery pick → compress → Supabase Storage. |
| `image`                          | Compress cover photo to 1440px / q80 before upload. |
| `photo_manager`                  | v2 only — auto-pick from device library on opt-in. Off by default in v1. |
| `geolocator`                     | Foreground-only coarse tag for motorcycle rides. No background tracking. |
| `flutter_local_notifications`    | Evening mood-prompt nudge (~21:00).            |
| `flutter_secure_storage`         | Spotify OAuth refresh token + Supabase session. |
| `app_links`                      | Spotify OAuth deep-link redirect (`memoirlog://spotify-callback`). |
| `dio`                            | HTTP for GitHub poller (proxied via Edge Fn) and TMDB search. Interceptor for retry. |
| `HapticFeedback` (Flutter built-in) | Mechanical-keyboard feel on every primary tap. No extra package. |

### UI
| Package              | Why                                                            |
|----------------------|----------------------------------------------------------------|
| `google_fonts`       | VT323 (body) + Share Tech Mono (UI) + Press Start 2P (date headers, sparingly). |
| `animated_text_kit`  | `TypewriterAnimatedText` — every diary page reveals char-by-char on first paint. |
| `audioplayers`       | 8-bit click track on typewriter chars + power-on / confirm SFX. -12 dB ceiling, toggleable. |
| `flutter_animate`    | CRT power-on flicker on day-swipe transitions.                 |
| `shimmer`            | Loading skeletons rendered as scanline-grain placeholders.     |
| `cached_network_image` | Movie posters from TMDB.                                     |
| `fl_chart`           | Skill-tree side route (kept minimal — not on the home page).   |

### Dev
| Package              | Why                                                            |
|----------------------|----------------------------------------------------------------|
| `flutter_lints`      | Linting baseline.                                              |
| `mocktail`           | Mocking for unit tests.                                        |
| `golden_toolkit`     | Golden tests for the Diary Page — its layout *is* the product. |

### Deliberately rejected
- **Bloc / GetX** — overkill / anti-pattern soup for a single-user app.
- **Firebase** — Supabase covers everything; one backend is the rule.
- **Google Photos API** — requires OAuth + ongoing token refresh; `photo_manager` reads the local library directly. Trade-off accepted: doesn't see iCloud-only or Google-cloud-only photos.
- **Letterboxd / Trakt SDKs** — TMDB free API + a tiny picker is enough.

## Supabase (backend)

| Service          | Used for                                                        |
|------------------|-----------------------------------------------------------------|
| Postgres         | All persistence (schema in `docs/DATA_MODEL.md`).               |
| Auth             | Apple + Google sign-in.                                         |
| Edge Functions   | (1) GitHub poller, (2) `daily-summary`, (3) `voice-transcribe`, (4) `resummarize`. Deno + TypeScript. |
| Realtime         | App subscribes to `entries` → today's diary appears without refresh. |
| pg_cron          | 23:50 daily summary, 30-min GitHub poll.                        |
| Storage          | `covers/` (cover photos), `voice/` (audio memos). Both private with RLS. |
| Vault            | GitHub PAT, Groq API key, TMDB key.                             |

### Edge Function libs (Deno)
- `https://esm.sh/@supabase/supabase-js@2` — server-side client with service role.
- Native `fetch` for Groq and TMDB. **No SDK** — Groq is OpenAI-compatible, the JSON request is 8 lines.
- `https://esm.sh/zod` — input validation for cron payloads.

## AI

### Narrator
- **Model:** `llama-3.3-70b-versatile` (Groq).
- **Why:** best free-tier prose model on Groq, multilingual (handles German voice notes), JSON mode supported via `response_format`.
- **Fallback:** `llama-3.1-8b-instant` if the 70B is rate-limited.
- **Endpoint:** `POST https://api.groq.com/openai/v1/chat/completions`.
- **Parameters:** `temperature: 0.7`, `max_tokens: 350`, `response_format: { type: "json_object" }`.

### Voice transcription
- **Model:** `whisper-large-v3` (Groq, free tier).
- **Why:** same vendor, same key, German support, ~3× faster than open-source local Whisper.
- **Endpoint:** `POST https://api.groq.com/openai/v1/audio/transcriptions`.

### Movie metadata
- **TMDB API** (`api.themoviedb.org/3`). Free for personal use. Used for title search + poster URL only — no analytics.

### Music metadata
- **Spotify Web API** (`api.spotify.com/v1`). OAuth 2.0 with PKCE, scope `user-read-recently-played` only. Polled by `spotify-poll` Edge Function every 30 minutes.
- **YT Music** has no official API; v2 plan is the Last.fm public scrobble feed as a bridge. v1 is Spotify-or-manual.

## Repository layout (target)

```
LifeGameAssitant/
├── README.md
├── docs/                       # this folder
├── app/                        # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/                # router, theme, bootstrap
│   │   ├── core/               # supabase client, env, errors
│   │   ├── data/               # repositories, dtos
│   │   ├── domain/             # entities (Entry, Workout, Movie, VoiceNote)
│   │   └── features/
│   │       ├── diary/          # the home — timeline + DiaryPage
│   │       ├── capture/        # quick-add sheet, movie picker, voice memo
│   │       ├── workouts/       # set/rep entry
│   │       ├── skills/         # side-route gamification
│   │       └── settings/
│   └── pubspec.yaml
├── supabase/
│   ├── migrations/             # numbered SQL migrations
│   ├── functions/
│   │   ├── github-poll/
│   │   ├── daily-summary/
│   │   ├── voice-transcribe/
│   │   └── resummarize/
│   └── seed.sql
└── .github/workflows/          # flutter test + supabase db push
```
