# Docker Build Debug Script
# This script runs docker build with verbose output to help diagnose issues
# Usage: .\docker-build-debug.ps1 [-Proxy <proxy_url>]

param(
    [Parameter()]
    [string]$Proxy = ""
)

Write-Host "=== Docker Build Debug ===" -ForegroundColor Cyan

# Set proxy if provided
if ($Proxy) {
    if (-not $Proxy.StartsWith("http://") -and -not $Proxy.StartsWith("https://") -and -not $Proxy.StartsWith("socks5://")) {
        Write-Host "Warning: Proxy should start with http://, https://, or socks5://" -ForegroundColor Yellow
        Write-Host "Assuming http:// prefix..." -ForegroundColor Yellow
        $Proxy = "http://$Proxy"
    }
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
    $env:http_proxy = $Proxy
    $env:https_proxy = $Proxy
    Write-Host "Using proxy: $Proxy" -ForegroundColor Yellow
} elseif ($env:HTTP_PROXY) {
    Write-Host "Using proxy from environment: $env:HTTP_PROXY" -ForegroundColor Yellow
} else {
    Write-Host "No proxy configured" -ForegroundColor Yellow
    Write-Host "If you need proxy, use: .\docker-build-debug.ps1 -Proxy http://127.0.0.1:7890" -ForegroundColor Cyan
}

Write-Host "`nBuilding Docker image with verbose output..." -ForegroundColor Cyan
Write-Host "This will show detailed error messages if build fails.`n" -ForegroundColor Yellow

# Build with progress=plain for full output
docker compose --progress=plain build --no-cache 2>&1 | Tee-Object -FilePath "docker-build.log"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`nBuild failed. Check docker-build.log for details." -ForegroundColor Red
    Write-Host "Last 50 lines of output:" -ForegroundColor Yellow
    Get-Content "docker-build.log" -Tail 50
}
