# Docker Mirror Configuration Script
# Configures Docker Desktop to use mirror registry for faster image pulls

Write-Host "=== Docker Mirror Configuration ===" -ForegroundColor Cyan

$settingsPath = "$env:APPDATA\Docker\settings.json"

# Check if Docker Desktop settings file exists
if (-not (Test-Path $settingsPath)) {
    Write-Host "Docker Desktop settings file not found at: $settingsPath" -ForegroundColor Red
    Write-Host "Please make sure Docker Desktop is installed and has been started at least once." -ForegroundColor Yellow
    exit 1
}

# Read current settings
try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Failed to read settings file: $_" -ForegroundColor Red
    exit 1
}

# Common mirror registries (you can modify these)
$mirrors = @(
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
)

Write-Host "`nCurrent registry mirrors configuration:" -ForegroundColor Yellow
if ($settings.PSObject.Properties.Name -contains "registry-mirrors") {
    if ($settings.'registry-mirrors') {
        $settings.'registry-mirrors' | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  (empty)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  (not configured)" -ForegroundColor Yellow
}

Write-Host "`nAvailable mirror options:" -ForegroundColor Yellow
Write-Host "  1. USTC Mirror (recommended)"
Write-Host "  2. NetEase Mirror"
Write-Host "  3. Baidu Mirror"
Write-Host "  4. Configure all mirrors"
Write-Host "  5. Remove all mirrors"
Write-Host "  6. Exit"

$choice = Read-Host "`nPlease select an option (1-6)"

# Ensure registry-mirrors property exists
if (-not ($settings.PSObject.Properties.Name -contains "registry-mirrors")) {
    $settings | Add-Member -MemberType NoteProperty -Name "registry-mirrors" -Value @()
}

switch ($choice) {
    "1" {
        $settings.'registry-mirrors' = @($mirrors[0])
        Write-Host "`nConfigured USTC mirror" -ForegroundColor Green
    }
    "2" {
        $settings.'registry-mirrors' = @($mirrors[1])
        Write-Host "`nConfigured NetEase mirror" -ForegroundColor Green
    }
    "3" {
        $settings.'registry-mirrors' = @($mirrors[2])
        Write-Host "`nConfigured Baidu mirror" -ForegroundColor Green
    }
    "4" {
        $settings.'registry-mirrors' = $mirrors
        Write-Host "`nConfigured all mirrors" -ForegroundColor Green
    }
    "5" {
        $settings.'registry-mirrors' = @()
        Write-Host "`nRemoved all mirrors" -ForegroundColor Green
    }
    "6" {
        Write-Host "Exiting" -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "Invalid selection" -ForegroundColor Red
        exit 1
    }
}

# Save settings
try {
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    Write-Host "`nSettings saved successfully!" -ForegroundColor Green
    Write-Host "`nPlease restart Docker Desktop for changes to take effect." -ForegroundColor Yellow
    Write-Host "After restarting, you can verify the configuration by running:" -ForegroundColor Yellow
    Write-Host "  docker info | Select-String -Pattern 'Registry Mirrors'" -ForegroundColor Cyan
} catch {
    Write-Host "Failed to save settings: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nDone!" -ForegroundColor Green
