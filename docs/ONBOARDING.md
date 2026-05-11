# Onboarding a fresh machine

The repo is portable but the *machine* needs some toolchain. This is
the order to bring a new PC online — Mac, Windows, or Linux.

## 1. Toolchain

| Tool        | Why                                | Install (Windows)                       |
|-------------|------------------------------------|------------------------------------------|
| Git         | Clone + commit                     | `winget install Git.Git`                 |
| Flutter SDK | Builds the app                     | `winget install -e --id flutter.flutter` |
| Supabase CLI| Deploy functions, push migrations  | `winget install Supabase.cli`            |
| Infisical CLI | Inject env vars                  | `winget install Infisical.cli`           |
| Node 20+    | Run the Astro landing page (`web/`)| `winget install OpenJS.NodeJS.LTS`       |
| VS Code     | Editor + Flutter debug             | `winget install Microsoft.VisualStudioCode` |

macOS / Linux: same tools, your package manager (`brew`, `apt`, etc).

## 2. Clone

```bash
git clone https://github.com/SamedBilginAlternet/LifeGameAssitant.git
cd LifeGameAssitant
```

## 3. Auth the CLIs

```bash
infisical login              # browser flow; one-time per machine
infisical init               # links this checkout to the Infisical workspace

supabase login --token <PAT> # PAT from https://supabase.com/dashboard/account/tokens
supabase link --project-ref duazbjnthanqpfhpifse
```

## 4. Flutter side

```bash
cd app

# Regenerate platform folders — they're gitignored and machine-specific.
flutter create . \
  --org com.samed.memoirlog \
  --project-name memoir_log \
  --platforms=ios,android,web

flutter pub get
```

Then add the native permission strings + URL scheme entries from
`app/SETUP.md` (Photo library, Microphone, HealthKit, Notifications,
Spotify deep-link). These edits live inside the regenerated
`ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml`
so they have to be reapplied every time you run `flutter create` from
scratch.

## 5. Run

```bash
# from repo root
./scripts/dev.sh           # macOS / Linux — Chrome target
.\scripts\dev.ps1          # Windows — Chrome target
./scripts/dev.sh -d ios    # pass through any flutter run args
```

The script wraps `infisical run` so every `--dart-define` (Supabase URL,
anon key, Spotify client id, etc.) comes from Infisical — no
`.vscode/launch.json` editing needed.

## 6. (Once, then never) Sync server-side secrets

After you've added `GROQ_API_KEY` / `CRON_SECRET` / `SPOTIFY_CLIENT_ID`
to Infisical, push them to Supabase:

```bash
./scripts/sync-supabase-secrets.sh
```

CI does this automatically on every push to `main` via
`.github/workflows/deploy-edge-functions.yml`.

## What lives where, summary

| Concern                          | Where                                   |
|----------------------------------|------------------------------------------|
| Source code                       | This repo                                |
| Schema migrations                 | `supabase/migrations/`, deployed via GitHub-Supabase integration |
| Edge Function code                | `supabase/functions/`, deployed via GH Action |
| Edge Function secrets             | Infisical → Supabase via `scripts/sync-supabase-secrets.sh` |
| Flutter --dart-define values      | Infisical, injected by `scripts/dev.sh` |
| Postgres custom config (GUCs)     | Supabase dashboard → Database → Custom Postgres Config (one-time per project) |
| Auth provider credentials         | Supabase dashboard → Authentication → Providers |
| Per-machine state                 | Infisical login + Supabase login + Flutter `pub get` cache + generated `app/ios/` + `app/android/` |
