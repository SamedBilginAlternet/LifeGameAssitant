# Run the Flutter app locally with env injected by Infisical (PowerShell).
# Usage:
#   .\scripts\dev.ps1                # defaults to -d chrome
#   .\scripts\dev.ps1 -d <device>    # passes through to flutter run
#
# Prerequisites:
#   - infisical CLI: https://infisical.com/docs/cli/overview
#   - You've run `infisical login` and `infisical init` once in this repo
#   - Flutter is on PATH

param([Parameter(ValueFromRemainingArguments)]$Args)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot/.."
$envName = if ($env:INFISICAL_ENV) { $env:INFISICAL_ENV } else { 'dev' }

Set-Location "$repoRoot/app"

# infisical run --command dispatches through the system shell; on
# Windows that's cmd.exe by default, where %VAR% is the env-expansion
# syntax. We pass --shell sh so the bash-style $VAR works the same on
# every OS (requires Git for Windows or WSL on PATH).
$flutterArgs = $Args -join ' '

$cmd = "flutter run " +
       "--dart-define=SUPABASE_URL=`$SUPABASE_URL " +
       "--dart-define=SUPABASE_ANON_KEY=`$SUPABASE_ANON_KEY " +
       "--dart-define=SPOTIFY_CLIENT_ID=`${SPOTIFY_CLIENT_ID:-} " +
       "--dart-define=SPOTIFY_REDIRECT_URI=`${SPOTIFY_REDIRECT_URI:-memoirlog://spotify-callback} " +
       $flutterArgs

& infisical run --env=$envName --shell sh --command $cmd
