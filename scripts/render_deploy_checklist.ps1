# Render staging deploy helper — run after repo is on GitHub.
param(
    [string]$BaseUrl = "",
    [switch]$OpenRenderDashboard
)

$ErrorActionPreference = "Stop"

Write-Host "=== Kasir Dapur — Render Staging Checklist ===" -ForegroundColor Cyan
Write-Host ""

$steps = @(
    @{ n = 1; title = "Payment method"; detail = "Render Dashboard -> Billing -> add card (Starter + disk required)"; url = "https://dashboard.render.com/billing" },
    @{ n = 2; title = "Connect GitHub"; detail = "Render Dashboard -> Account Settings -> connect GitHub"; url = "https://dashboard.render.com/u/settings" },
    @{ n = 3; title = "Push repo"; detail = "git push -u origin main (after gh repo create or manual GitHub repo)"; url = "" },
    @{ n = 4; title = "New Blueprint"; detail = "Render -> New -> Blueprint -> select repo -> Deploy Blueprint"; url = "https://dashboard.render.com/blueprints/new" },
    @{ n = 5; title = "Fill env vars"; detail = "MIDTRANS_* (sandbox), PUBLIC_BASE_URL (.onrender.com or custom domain)"; url = "" },
    @{ n = 6; title = "Smoke test"; detail = ".\scripts\staging_smoke_test.ps1 -BaseUrl <url>"; url = "" }
)

foreach ($s in $steps) {
    Write-Host "$($s.n). $($s.title)" -ForegroundColor Yellow
    Write-Host "   $($s.detail)"
    if ($s.url) { Write-Host "   $($s.url)" -ForegroundColor DarkGray }
    Write-Host ""
}

if ($OpenRenderDashboard) {
    Start-Process "https://dashboard.render.com/blueprints/new"
}

if ($BaseUrl) {
    Write-Host "Running smoke test against $BaseUrl ..." -ForegroundColor Cyan
    & "$PSScriptRoot\staging_smoke_test.ps1" -BaseUrl $BaseUrl
}
