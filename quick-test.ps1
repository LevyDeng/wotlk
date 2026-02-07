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
        Write-Info "Full items workflow: stop -> regenerate DB -> start -> server -> UI"

        # Step 1: Stop container to avoid conflicts
        if (Test-ContainerRunning) {
            Write-Info "Step 1/5: Stopping container..."
            docker stop $CONTAINER_NAME
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to stop container."
                exit 1
            }
        } else {
            Write-Info "Step 1/5: Container not running, skip stop."
        }

        # Step 2: Regenerate items database locally
        Write-Info "Step 2/5: Regenerating items database..."
        go run ./tools/database/gen_db -outDir ./assets -gen db
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Database generation failed!"
            exit 1
        }

        # Step 3: Start container
        Write-Info "Step 3/5: Starting container..."
        if ($env:HTTP_PROXY) {
            Write-Info "Using proxy: $env:HTTP_PROXY"
        }
        docker-compose -f docker-compose.dev.yml up -d --build
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to start container."
            exit 1
        }

        # Wait for container to be ready for docker exec
        $maxWait = 30
        $waited = 0
        while (-not (Test-ContainerRunning) -and $waited -lt $maxWait) {
            Start-Sleep -Seconds 2
            $waited += 2
        }
        if (-not (Test-ContainerRunning)) {
            Write-Error "Container did not become ready in time."
            exit 1
        }
        Start-Sleep -Seconds 3

        # Step 4: Rebuild server
        Write-Info "Step 4/5: Rebuilding server..."
        docker exec $CONTAINER_NAME sh -c "make devserver"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Server build failed!"
            exit 1
        }
        docker restart $CONTAINER_NAME | Out-Null

        # Step 5: Rebuild UI
        Write-Info "Step 5/5: Rebuilding UI..."
        docker exec $CONTAINER_NAME sh -c "make binary_dist"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "UI build failed!"
            exit 1
        }

        Write-Info "Items workflow complete! Server at http://localhost:3333"
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
        Write-Host "  items   - Full workflow: stop -> regenerate DB -> start -> server -> UI"
        Write-Host "  server  - Rebuild server binary only"
        Write-Host "  ui      - Rebuild UI only"
        Write-Host "  full    - Rebuild everything (items + server + UI)"
        Write-Host "  restart - Restart server without rebuilding"
        Write-Host ""
        Write-Host "Example workflow (after adding/changing gear in overrides.go):"
        Write-Host "  .\quick-test.ps1 items   # one command: stop, regen DB, start, rebuild server+UI"
        exit 1
    }
}

exit 0
