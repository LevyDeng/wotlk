# Docker Proxy Configuration Check and Fix Script
# Used to resolve Docker proxy connection issues

Write-Host "=== Docker Proxy Configuration Check ===" -ForegroundColor Cyan

# 1. Check system environment variables
Write-Host "`n1. Checking system environment variables:" -ForegroundColor Yellow
$envVars = @("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy", "NO_PROXY", "no_proxy")
foreach ($var in $envVars) {
    $value = [Environment]::GetEnvironmentVariable($var, "User")
    if ($value) {
        Write-Host "  $var = $value" -ForegroundColor Red
    } else {
        Write-Host "  $var = (not set)" -ForegroundColor Green
    }
}

# 2. Check current session environment variables
Write-Host "`n2. Checking current session environment variables:" -ForegroundColor Yellow
foreach ($var in $envVars) {
    $envValue = (Get-Item "Env:\$var" -ErrorAction SilentlyContinue).Value
    if ($envValue) {
        Write-Host "  $var = $envValue" -ForegroundColor Red
    }
}

# 3. Check Docker Desktop settings
Write-Host "`n3. Checking Docker Desktop settings:" -ForegroundColor Yellow
$settingsPath = "$env:APPDATA\Docker\settings.json"
if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($settings.PSObject.Properties.Name -contains "proxies") {
            Write-Host "  Found proxy configuration:" -ForegroundColor Red
            $settings.proxies | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Red
        } else {
            Write-Host "  No proxy configuration found" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Failed to read settings file: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  Settings file does not exist: $settingsPath" -ForegroundColor Yellow
}

# 4. Check Docker config.json
Write-Host "`n4. Checking Docker config.json:" -ForegroundColor Yellow
$configPath = "$env:USERPROFILE\.docker\config.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($config.PSObject.Properties.Name -contains "proxies") {
            Write-Host "  Found proxy configuration:" -ForegroundColor Red
            $config.proxies | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Red
        } else {
            Write-Host "  No proxy configuration found" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Failed to read config file: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  Config file does not exist" -ForegroundColor Yellow
}

# 5. Check Docker daemon proxy settings
Write-Host "`n5. Checking Docker daemon proxy settings:" -ForegroundColor Yellow
$daemonPath = "$env:ProgramData\Docker\config\daemon.json"
if (Test-Path $daemonPath) {
    try {
        $daemon = Get-Content $daemonPath -Raw | ConvertFrom-Json
        if ($daemon.PSObject.Properties.Name -contains "proxies") {
            Write-Host "  Found proxy configuration:" -ForegroundColor Red
            $daemon.proxies | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Red
        } else {
            Write-Host "  No proxy configuration found" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Failed to read daemon config: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  daemon.json does not exist" -ForegroundColor Yellow
}

# 6. Check Docker info for proxies
Write-Host "`n6. Checking Docker info for proxies:" -ForegroundColor Yellow
try {
    $dockerInfo = docker info 2>&1
    $proxyLines = $dockerInfo | Select-String -Pattern "Proxy"
    if ($proxyLines) {
        $proxyLines | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  No proxy information found" -ForegroundColor Green
    }
} catch {
    Write-Host "  Failed to get Docker info: $_" -ForegroundColor Red
}

# 7. Check WSL/Linux environment variables
Write-Host "`n7. Checking WSL/Linux environment variables:" -ForegroundColor Yellow
try {
    $wslDistros = (wsl --list --quiet 2>$null)
    if ($wslDistros) {
        foreach ($distro in $wslDistros) {
            if ($distro.Trim()) {
                Write-Host "  Checking WSL distribution: $distro" -ForegroundColor Cyan
                foreach ($var in $envVars) {
                    $wslValue = wsl -d $distro -e sh -c "echo `$${var}" 2>$null
                    if ($wslValue -and $wslValue.Trim() -ne "") {
                        Write-Host "    $var = $wslValue" -ForegroundColor Red
                    }
                }
            }
        }
    } else {
        Write-Host "  No WSL distributions found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Failed to check WSL: $_" -ForegroundColor Red
}

# 8. Check WSL shell configuration files
Write-Host "`n8. Checking WSL shell configuration files:" -ForegroundColor Yellow
try {
    $wslDistros = (wsl --list --quiet 2>$null)
    if ($wslDistros) {
        foreach ($distro in $wslDistros) {
            if ($distro.Trim()) {
                Write-Host "  Checking $distro shell configs:" -ForegroundColor Cyan
                $configFiles = @(".bashrc", ".profile", ".bash_profile", ".zshrc")
                foreach ($configFile in $configFiles) {
                    $proxyLines = wsl -d $distro -e sh -c "grep -i proxy ~/$configFile 2>/dev/null || true" 2>$null
                    if ($proxyLines -and $proxyLines.Trim()) {
                        Write-Host "    ~/$configFile contains proxy settings:" -ForegroundColor Red
                        $proxyLines -split "`n" | ForEach-Object {
                            if ($_.Trim()) {
                                Write-Host "      $_" -ForegroundColor Red
                            }
                        }
                    }
                }
            }
        }
    }
} catch {
    Write-Host "  Failed to check WSL config files: $_" -ForegroundColor Red
}

# 9. Check WSL Docker daemon config
Write-Host "`n9. Checking WSL Docker daemon configuration:" -ForegroundColor Yellow
try {
    $wslDistros = (wsl --list --quiet 2>$null)
    if ($wslDistros) {
        foreach ($distro in $wslDistros) {
            if ($distro.Trim()) {
                Write-Host "  Checking ${distro}:" -ForegroundColor Cyan
                $daemonPaths = @("/etc/docker/daemon.json", "~/.docker/daemon.json")
                foreach ($daemonPath in $daemonPaths) {
                    $daemonContent = wsl -d $distro -e sh -c "cat $daemonPath 2>/dev/null || true" 2>$null
                    if ($daemonContent -and $daemonContent.Trim()) {
                        try {
                            $daemonJson = $daemonContent | ConvertFrom-Json
                            if ($daemonJson.PSObject.Properties.Name -contains "proxies") {
                                Write-Host "    Found proxy in ${daemonPath}:" -ForegroundColor Red
                                $daemonJson.proxies | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Red
                            }
                        } catch {
                            # Not valid JSON or no proxies
                        }
                    }
                }
            }
        }
    }
} catch {
    Write-Host "  Failed to check WSL Docker daemon: $_" -ForegroundColor Red
}

Write-Host "`n=== Fix Options ===" -ForegroundColor Cyan
Write-Host "1. Clear proxy from system environment variables"
Write-Host "2. Clear proxy from Docker Desktop settings"
Write-Host "3. Clear proxy from Docker config.json"
Write-Host "4. Clear proxy from WSL environment variables"
Write-Host "5. Clear proxy from WSL shell configuration files"
Write-Host "6. Clear all proxy configurations (Windows + WSL)"
Write-Host "7. Exit"

$choice = Read-Host "`nPlease select an option (1-7)"

switch ($choice) {
    "1" {
        Write-Host "`nClearing system environment variables..." -ForegroundColor Yellow
        foreach ($var in $envVars) {
            [Environment]::SetEnvironmentVariable($var, $null, "User")
            Remove-Item "Env:\$var" -ErrorAction SilentlyContinue
            Write-Host "  Cleared $var" -ForegroundColor Green
        }
        Write-Host "`nPlease reopen PowerShell or restart your computer for changes to take effect" -ForegroundColor Yellow
    }
    "2" {
        Write-Host "`nClearing proxy from Docker Desktop settings..." -ForegroundColor Yellow
        if (Test-Path $settingsPath) {
            try {
                $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
                if ($settings.PSObject.Properties.Name -contains "proxies") {
                    $settings.PSObject.Properties.Remove('proxies')
                    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
                    Write-Host "  Cleared Docker Desktop proxy settings" -ForegroundColor Green
                    Write-Host "  Please restart Docker Desktop for changes to take effect" -ForegroundColor Yellow
                } else {
                    Write-Host "  No proxy settings found" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  Error: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  Settings file does not exist" -ForegroundColor Yellow
        }
    }
    "3" {
        Write-Host "`nClearing proxy from Docker config.json..." -ForegroundColor Yellow
        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($config.PSObject.Properties.Name -contains "proxies") {
                    $config.PSObject.Properties.Remove('proxies')
                    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
                    Write-Host "  Cleared proxy from config.json" -ForegroundColor Green
                } else {
                    Write-Host "  No proxy configuration found" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  Error: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  Config file does not exist" -ForegroundColor Yellow
        }
    }
    "4" {
        Write-Host "`nClearing proxy from WSL environment variables..." -ForegroundColor Yellow
        try {
            $wslDistros = (wsl --list --quiet 2>$null)
            if ($wslDistros) {
                foreach ($distro in $wslDistros) {
                    if ($distro.Trim()) {
                        Write-Host "  Clearing from $distro..." -ForegroundColor Cyan
                        foreach ($var in $envVars) {
                            wsl -d $distro -e sh -c "unset $var" 2>$null
                            wsl -d $distro -e sh -c "sed -i '/export $var=/d' ~/.bashrc ~/.profile ~/.bash_profile 2>/dev/null || true" 2>$null
                        }
                        Write-Host "    Cleared environment variables from $distro" -ForegroundColor Green
                    }
                }
                Write-Host "`nPlease restart WSL or reopen WSL terminals for changes to take effect" -ForegroundColor Yellow
            } else {
                Write-Host "  No WSL distributions found" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  Error: $_" -ForegroundColor Red
        }
    }
    "5" {
        Write-Host "`nClearing proxy from WSL shell configuration files..." -ForegroundColor Yellow
        try {
            $wslDistros = (wsl --list --quiet 2>$null)
            if ($wslDistros) {
                foreach ($distro in $wslDistros) {
                    if ($distro.Trim()) {
                        Write-Host "  Clearing from $distro..." -ForegroundColor Cyan
                        $configFiles = @(".bashrc", ".profile", ".bash_profile", ".zshrc")
                        foreach ($configFile in $configFiles) {
                            wsl -d $distro -e sh -c "sed -i '/proxy/d' ~/$configFile 2>/dev/null || true" 2>$null
                            wsl -d $distro -e sh -c "sed -i '/PROXY/d' ~/$configFile 2>/dev/null || true" 2>$null
                        }
                        Write-Host "    Cleared proxy settings from shell configs in $distro" -ForegroundColor Green
                    }
                }
                Write-Host "`nPlease restart WSL or reopen WSL terminals for changes to take effect" -ForegroundColor Yellow
            } else {
                Write-Host "  No WSL distributions found" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  Error: $_" -ForegroundColor Red
        }
    }
    "6" {
        Write-Host "`nClearing all proxy configurations (Windows + WSL)..." -ForegroundColor Yellow

        # Clear Windows environment variables
        foreach ($var in $envVars) {
            [Environment]::SetEnvironmentVariable($var, $null, "User")
            Remove-Item "Env:\$var" -ErrorAction SilentlyContinue
        }
        Write-Host "  Cleared Windows environment variables" -ForegroundColor Green

        # Clear Docker Desktop settings
        if (Test-Path $settingsPath) {
            try {
                $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
                if ($settings.PSObject.Properties.Name -contains "proxies") {
                    $settings.PSObject.Properties.Remove('proxies')
                    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
                    Write-Host "  Cleared Docker Desktop proxy settings" -ForegroundColor Green
                }
            } catch {
                Write-Host "  Warning: Unable to modify Docker Desktop settings" -ForegroundColor Yellow
            }
        }

        # Clear config.json
        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($config.PSObject.Properties.Name -contains "proxies") {
                    $config.PSObject.Properties.Remove('proxies')
                    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
                    Write-Host "  Cleared proxy from config.json" -ForegroundColor Green
                }
            } catch {
                Write-Host "  Warning: Unable to modify config.json" -ForegroundColor Yellow
            }
        }

        # Clear WSL environment variables
        try {
            $wslDistros = (wsl --list --quiet 2>$null)
            if ($wslDistros) {
                foreach ($distro in $wslDistros) {
                    if ($distro.Trim()) {
                        Write-Host "  Clearing from WSL $distro..." -ForegroundColor Cyan
                        foreach ($var in $envVars) {
                            wsl -d $distro -e sh -c "unset $var" 2>$null
                            wsl -d $distro -e sh -c "sed -i '/export $var=/d' ~/.bashrc ~/.profile ~/.bash_profile 2>/dev/null || true" 2>$null
                        }
                        $configFiles = @(".bashrc", ".profile", ".bash_profile", ".zshrc")
                        foreach ($configFile in $configFiles) {
                            wsl -d $distro -e sh -c "sed -i '/proxy/d' ~/$configFile 2>/dev/null || true" 2>$null
                            wsl -d $distro -e sh -c "sed -i '/PROXY/d' ~/$configFile 2>/dev/null || true" 2>$null
                        }
                        Write-Host "    Cleared WSL $distro" -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Host "  Warning: Unable to clear WSL configurations" -ForegroundColor Yellow
        }

        Write-Host "`nPlease perform the following actions:" -ForegroundColor Yellow
        Write-Host "  1. Restart Docker Desktop" -ForegroundColor Yellow
        Write-Host "  2. Restart WSL (wsl --shutdown)" -ForegroundColor Yellow
        Write-Host "  3. Reopen PowerShell or restart your computer" -ForegroundColor Yellow
    }
    "7" {
        Write-Host "Exiting" -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "Invalid selection" -ForegroundColor Red
    }
}

Write-Host "`nDone!" -ForegroundColor Green
