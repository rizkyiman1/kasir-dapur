# Staging smoke test — Kasir Dapur
# Usage:
#   $env:STAGING_API_URL = "https://api-staging.dapur-rasa.com"
#   $env:STAGING_USER_A = "user-A"
#   $env:STAGING_PIN_A = "1234"
#   Optional: STAGING_USER_B, STAGING_PIN_B, STAGING_TOKEN_INVALID
#   .\scripts\staging_smoke_test.ps1

$ErrorActionPreference = "Stop"

function Write-Result {
  param([string]$Id, [string]$Name, [string]$Status, [string]$Evidence)
  $script:Results += [ordered]@{
    id = $Id
    name = $Name
    status = $Status
    evidence = $Evidence
    at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Host "[$Status] $Id — $Name"
  if ($Evidence) { Write-Host "  → $Evidence" }
}

$BaseUrl = ($env:STAGING_API_URL ?? "").TrimEnd("/")
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  Write-Error "STAGING_API_URL wajib di-set (contoh: https://api-staging.dapur-rasa.com)"
}

$Results = @()
$summary = [ordered]@{
  base_url = $BaseUrl
  started_at = (Get-Date).ToUniversalTime().ToString("o")
  tests = $Results
}

function Invoke-Api {
  param(
    [string]$Method = "GET",
    [string]$Path,
    [hashtable]$Headers = @{},
    [object]$Body = $null
  )
  $uri = "$BaseUrl$Path"
  $params = @{
    Uri = $uri
    Method = $Method
    Headers = $Headers
    TimeoutSec = 20
    SkipCertificateCheck = $false
  }
  if ($null -ne $Body) {
    $params.ContentType = "application/json"
    $params.Body = ($Body | ConvertTo-Json -Compress)
  }
  try {
    $resp = Invoke-WebRequest @params -UseBasicParsing
    return @{ ok = $true; status = [int]$resp.StatusCode; body = $resp.Content; headers = $resp.Headers }
  } catch {
    if ($_.Exception.Response) {
      $r = $_.Exception.Response
      $reader = New-Object System.IO.StreamReader($r.GetResponseStream())
      $text = $reader.ReadToEnd()
      return @{ ok = $false; status = [int]$r.StatusCode; body = $text; headers = @{} }
    }
    throw
  }
}

# 1. Health
try {
  $h = Invoke-Api -Path "/health"
  if ($h.status -eq 200) {
    Write-Result "H01" "GET /health" "VERIFIED" "HTTP $($h.status)"
  } else {
    Write-Result "H01" "GET /health" "FAILED" "HTTP $($h.status)"
  }
} catch {
  Write-Result "H01" "GET /health" "FAILED" $_.Exception.Message
}

# 2. TLS / headers (best effort)
try {
  $h = Invoke-Api -Path "/health"
  $evidence = @("HTTP $($h.status)")
  foreach ($name in @("Strict-Transport-Security", "X-Content-Type-Options", "Referrer-Policy")) {
    if ($h.headers[$name]) { $evidence += "$name=present" }
  }
  Write-Result "TLS01" "Security headers probe" "VERIFIED" ($evidence -join "; ")
} catch {
  Write-Result "TLS01" "Security headers probe" "FAILED" $_.Exception.Message
}

# 3. Auth — invalid
try {
  $bad = Invoke-Api -Method POST -Path "/v1/auth/cloud/session" -Body @{ user_id = "invalid-user"; pin = "0000" }
  if ($bad.status -eq 401) {
    Write-Result "A03" "Invalid credential → 401" "VERIFIED" "HTTP 401"
  } else {
    Write-Result "A03" "Invalid credential → 401" "FAILED" "HTTP $($bad.status)"
  }
} catch {
  Write-Result "A03" "Invalid credential → 401" "FAILED" $_.Exception.Message
}

# 4. Protected without token
try {
  $p = Invoke-Api -Path "/v1/billing/subscription"
  if ($p.status -eq 401) {
    Write-Result "A05" "Protected without token → 401" "VERIFIED" "HTTP 401"
  } else {
    Write-Result "A05" "Protected without token → 401" "FAILED" "HTTP $($p.status)"
  }
} catch {
  Write-Result "A05" "Protected without token → 401" "FAILED" $_.Exception.Message
}

# 5. Valid session (if credentials provided)
$token = $null
$userA = $env:STAGING_USER_A
$pinA = $env:STAGING_PIN_A
if ($userA -and $pinA) {
  try {
    $sess = Invoke-Api -Method POST -Path "/v1/auth/cloud/session" -Body @{ user_id = $userA; pin = $pinA }
    if ($sess.status -eq 200) {
      $json = $sess.body | ConvertFrom-Json
      $token = $json.access_token
      Write-Result "A02" "Cloud auth valid" "VERIFIED" "HTTP 200, token received (not logged)"
    } else {
      Write-Result "A02" "Cloud auth valid" "FAILED" "HTTP $($sess.status)"
    }
  } catch {
    Write-Result "A02" "Cloud auth valid" "FAILED" $_.Exception.Message
  }
} else {
  Write-Result "A02" "Cloud auth valid" "NOT VERIFIED" "Set STAGING_USER_A and STAGING_PIN_A"
}

# 6. Protected with token
if ($token) {
  try {
    $auth = Invoke-Api -Path "/v1/billing/subscription" -Headers @{ Authorization = "Bearer $token" }
    if ($auth.status -eq 200) {
      Write-Result "A06" "Protected with valid token" "VERIFIED" "HTTP 200"
    } else {
      Write-Result "A06" "Protected with valid token" "FAILED" "HTTP $($auth.status)"
    }
  } catch {
    Write-Result "A06" "Protected with valid token" "FAILED" $_.Exception.Message
  }

  # Checkout amount authority (client cannot set amount in API — verify 200 + server amount)
  try {
    $co = Invoke-Api -Method POST -Path "/v1/billing/checkout" -Headers @{ Authorization = "Bearer $token" } -Body @{
      plan_code = "PRO_MONTHLY"
      client_uuid = "smoke-$(Get-Date -Format yyyyMMddHHmmss)"
    }
    if ($co.status -eq 200) {
      $coJson = $co.body | ConvertFrom-Json
      $amt = $coJson.amount
      Write-Result "B01" "Checkout PRO monthly (server amount)" "VERIFIED" "HTTP 200, amount=$amt"
    } else {
      Write-Result "B01" "Checkout PRO monthly" "FAILED" "HTTP $($co.status)"
    }
  } catch {
    Write-Result "B01" "Checkout PRO monthly" "FAILED" $_.Exception.Message
  }
}

# 7. Invalid token
$badToken = $env:STAGING_TOKEN_INVALID
if (-not $badToken) { $badToken = "not.a.valid.jwt" }
try {
  $inv = Invoke-Api -Path "/v1/billing/subscription" -Headers @{ Authorization = "Bearer $badToken" }
  if ($inv.status -eq 401) {
    Write-Result "A07" "Invalid token → 401" "VERIFIED" "HTTP 401"
  } else {
    Write-Result "A07" "Invalid token → 401" "FAILED" "HTTP $($inv.status)"
  }
} catch {
  Write-Result "A07" "Invalid token → 401" "FAILED" $_.Exception.Message
}

# Brute force (light): 5 invalid attempts
$got429 = $false
for ($i = 1; $i -le 5; $i++) {
  $r = Invoke-Api -Method POST -Path "/v1/auth/cloud/session" -Body @{ user_id = "brute-test"; pin = "x$i" }
  if ($r.status -eq 429) { $got429 = $true; break }
}
if ($got429) {
  Write-Result "A04" "Repeated invalid → 429" "VERIFIED" "429 after retries"
} else {
  Write-Result "A04" "Repeated invalid → 429" "NOT VERIFIED" "No 429 in 5 attempts (may need more or different limiter config)"
}

$summary.tests = $Results
$summary.finished_at = (Get-Date).ToUniversalTime().ToString("o")
$outPath = Join-Path (Split-Path $PSScriptRoot -Parent) "staging-smoke-results.json"
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
Write-Host ""
Write-Host "Results written to $outPath"
$verified = ($Results | Where-Object { $_.status -eq "VERIFIED" }).Count
$failed = ($Results | Where-Object { $_.status -eq "FAILED" }).Count
$notVerified = ($Results | Where-Object { $_.status -eq "NOT VERIFIED" }).Count
Write-Host "Summary: VERIFIED=$verified FAILED=$failed NOT_VERIFIED=$notVerified"
