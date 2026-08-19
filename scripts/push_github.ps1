# Push Kasir Dapur to GitHub (required before Render Blueprint deploy).
# Run from repo root: .\scripts\push_github.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

function Get-GhExe {
    $cached = Get-ChildItem -Path "$env:TEMP\gh-cli" -Recurse -Filter "gh.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cached) { return $cached.FullName }
    if (Get-Command gh -ErrorAction SilentlyContinue) { return "gh" }
    throw "GitHub CLI (gh) not found. Install from https://cli.github.com/ or re-run setup."
}

$gh = Get-GhExe
Write-Host "Using GitHub CLI: $gh" -ForegroundColor Cyan

$auth = & $gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Login GitHub dulu (browser akan terbuka):" -ForegroundColor Yellow
    & $gh auth login -h github.com -p https -w
}

$repoName = "kasir-dapur"
Write-Host ""
Write-Host "Creating private GitHub repo '$repoName' (skip if already exists)..." -ForegroundColor Cyan
& $gh repo create $repoName --private --source=. --remote=origin --push 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Repo mungkin sudah ada — coba push manual:" -ForegroundColor Yellow
    Write-Host "  git remote add origin https://github.com/<username>/$repoName.git"
    Write-Host "  git push -u origin main"
    exit 1
}

Write-Host ""
Write-Host "Done. Repo URL:" -ForegroundColor Green
& $gh repo view --json url -q .url
Write-Host ""
Write-Host "Next: Render Dashboard -> New -> Blueprint -> pilih repo ini." -ForegroundColor Cyan
Write-Host "  https://dashboard.render.com/blueprints/new"
