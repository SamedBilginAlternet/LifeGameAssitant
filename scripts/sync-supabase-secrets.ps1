# Pull dev secrets from Infisical and push them to Supabase Edge
# Function Secrets via `supabase secrets set --env-file` (PowerShell).
#
# Usage:
#   .\scripts\sync-supabase-secrets.ps1
#
# Prerequisites:
#   - infisical CLI authed, init'd in this repo
#   - supabase CLI authed, linked to the project (`supabase link`)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot/.."
$envName = if ($env:INFISICAL_ENV) { $env:INFISICAL_ENV } else { 'dev' }

# Server-side secrets only — public client values (SUPABASE_URL,
# SUPABASE_ANON_KEY) are auto-populated for Edge Functions by Supabase.
$serverKeys = @('GROQ_API_KEY', 'CRON_SECRET', 'SPOTIFY_CLIENT_ID')

Set-Location $repoRoot

Write-Host "→ pulling secrets from Infisical (env=$envName)..."
$allSecrets = & infisical export --env=$envName --format=dotenv

$tmpEnv = New-TemporaryFile
$kept = 0
try {
  foreach ($key in $serverKeys) {
    $line = $allSecrets -split "`n" | Where-Object { $_ -match "^$key=" } | Select-Object -First 1
    if ($line) {
      Add-Content -Path $tmpEnv -Value $line
      $kept++
    } else {
      Write-Host "  ⚠ skipping $key — not set in Infisical $envName"
    }
  }

  if ($kept -eq 0) {
    Write-Host "✗ no server-side secrets found in Infisical $envName; nothing to push."
    exit 1
  }

  Write-Host "→ pushing to Supabase Edge Function Secrets..."
  & supabase secrets set --env-file $tmpEnv
  Write-Host "✓ done."
} finally {
  Remove-Item $tmpEnv -ErrorAction SilentlyContinue
}
