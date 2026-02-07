# Quick Test Script for Development
# Rebuilds only changed code and restarts the server
# Usage: .\quick-test.ps1 [start|stop|items|server|ui|full|restart] [-Proxy <url>]

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "items", "server", "ui", "full", "restart")]
    [string]$Target = "server",
    [Parameter()]
    [string]$Proxy = ""
)

$CONTAINER_NAME = "wowsims-wotlk-dev"

# Load proxy from parameter, environment variable, or .env (same as docker.ps1)
if ($Proxy) {
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
    $env:http_proxy = $Proxy
    $env:https_proxy = $Proxy
} elseif (-not $env:HTTP_PROXY) {
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                if ($key -and $value) {
                    [Environment]::SetEnvironmentVariable($key, $value, "Process")
                }
            }
        }
    }
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-ContainerRunning {
    $running = docker ps --format '{{.Names}}' | Select-String -Pattern "^${CONTAINER_NAME}$"
    return $null -ne $running
}

switch ($Target) {
    "start" {
        Write-Info "Starting dev container (docker-compose.dev.yml)..."

        if (Test-ContainerRunning) {
            Write-Info "Container $CONTAINER_NAME is already running. Use .\quick-test.ps1 restart to restart."
            exit 0
        }

        if ($env:HTTP_PROXY) {
            Write-Info "Using proxy: $env:HTTP_PROXY"
        }

        docker-compose -f docker-compose.dev.yml up -d --build

        if ($LASTEXITCODE -eq 0) {
            Write-Info "Container started! Server will be at http://localhost:3333 (first start may take a minute to build frontend)."
        } else {
            Write-Error "Failed to start container."
            exit 1
        }
    }

    "items" {
        Write-Info "Regenerating items database..."

        # Run database generation locally (fast, no Docker rebuild)
        go run ./tools/database/gen_db -outDir ./assets -gen db

        if ($LASTEXITCODE -eq 0) {
            Write-Info "Database regenerated successfully!"
            Write-Info "Restart the server to load new database: .\quick-test.ps1 restart"
        } else {
            Write-Error "Database generation failed!"
            exit 1
        }
    }

    "server" {
        Write-Info "Rebuilding server binary..."

        if (Test-ContainerRunning) {
            # Rebuild inside container (uses cached dependencies)
            docker exec $CONTAINER_NAME sh -c "make devserver"

            if ($LASTEXITCODE -eq 0) {
                Write-Info "Server rebuilt! Restarting container..."
                docker restart $CONTAINER_NAME
                Write-Info "Server restarted! Available at http://localhost:3333"
            } else {
                Write-Error "Server build failed!"
                exit 1
            }
        } else {
            Write-Error "Container $CONTAINER_NAME is not running. Start it with: .\quick-test.ps1 start"
            exit 1
        }
    }

    "ui" {
        Write-Info "Rebuilding UI..."

        if (Test-ContainerRunning) {
            docker exec $CONTAINER_NAME sh -c "make binary_dist"

            if ($LASTEXITCODE -eq 0) {
                Write-Info "UI rebuilt successfully! Refresh your browser."
            } else {
                Write-Error "UI build failed!"
                exit 1
            }
        } else {
            Write-Error "Container $CONTAINER_NAME is not running. Start it with: .\quick-test.ps1 start"
            exit 1
        }
    }

    "full" {
        Write-Info "Full rebuild (items + server + UI)..."

        # Regenerate items database
        Write-Info "Step 1/3: Regenerating items database..."
        go run ./tools/database/gen_db -outDir ./assets -gen db

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Database generation failed!"
            exit 1
        }

        if (Test-ContainerRunning) {
            # Rebuild server
            Write-Info "Step 2/3: Rebuilding server..."
            docker exec $CONTAINER_NAME sh -c "make devserver"

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Server build failed!"
                exit 1
            }

            # Rebuild UI
            Write-Info "Step 3/3: Rebuilding UI..."
            docker exec $CONTAINER_NAME sh -c "make binary_dist"

            if ($LASTEXITCODE -ne 0) {
                Write-Error "UI build failed!"
                exit 1
            }

            Write-Info "Restarting server..."
            docker restart $CONTAINER_NAME
            Write-Info "Full rebuild complete! Server available at http://localhost:3333"
        } else {
            Write-Error "Container $CONTAINER_NAME is not running. Start it with: .\quick-test.ps1 start"
            exit 1
        }
    }

    "restart" {
        Write-Info "Restarting server..."

        if (Test-ContainerRunning) {
            docker restart $CONTAINER_NAME
            Write-Info "Server restarted!"
        } else {
            Write-Error "Container $CONTAINER_NAME is not running. Start it with: .\quick-test.ps1 start"
            exit 1
        }
    }

    "stop" {
        Write-Info "Stopping dev container..."

        if (Test-ContainerRunning) {
            docker stop $CONTAINER_NAME
            Write-Info "Container $CONTAINER_NAME stopped."
        } else {
            Write-Info "Container $CONTAINER_NAME is not running."
        }
    }

    default {
        Write-Host "Usage: .\quick-test.ps1 [start|stop|items|server|ui|full|restart]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  start   - Start dev container (docker-compose.dev.yml, build if needed)"
        Write-Host "  stop    - Stop dev container"
        Write-Host "  items   - Regenerate items database only (fastest)"
        Write-Host "  server  - Rebuild server binary only"
        Write-Host "  ui      - Rebuild UI only"
        Write-Host "  full    - Rebuild everything (items + server + UI)"
        Write-Host "  restart - Restart server without rebuilding"
        Write-Host ""
        Write-Host "Example workflow:"
        Write-Host "  1. .\quick-test.ps1 start          # start Docker dev container"
        Write-Host "  2. Modify tools/database/overrides.go"
        Write-Host "  3. .\quick-test.ps1 items; .\quick-test.ps1 restart"
        exit 1
    }
}

exit 0
