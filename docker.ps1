# WoW WOTLK Simulator Docker Management Script (PowerShell)
# Usage: .\docker.ps1 [start|restart|frestart|stop|status|logs] [-Proxy <proxy_url>]

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "frestart", "status", "logs")]
    [string]$Action = "start",
    [Parameter()]
    [string]$Proxy = ""
)

$CONTAINER_NAME = "wowsims-wotlk"
$COMPOSE_FILE = "docker-compose.yml"

# Load proxy from parameter, environment variable, or .env file
if ($Proxy) {
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
    $env:http_proxy = $Proxy
    $env:https_proxy = $Proxy
} elseif (-not $env:HTTP_PROXY) {
    # Try to load from .env file
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

# Function to print colored messages
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed or not in PATH. Please install Docker Desktop."
    exit 1
}

# Check if docker-compose is available
$DOCKER_COMPOSE = $null
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $composeVersion = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $DOCKER_COMPOSE = "docker compose"
    } else {
        if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
            $DOCKER_COMPOSE = "docker-compose"
        } else {
            Write-Error "docker-compose is not installed. Please install Docker Compose."
            exit 1
        }
    }
}

# Function to check if container is running
function Test-ContainerRunning {
    $running = docker ps --format '{{.Names}}' | Select-String -Pattern "^${CONTAINER_NAME}$"
    return $null -ne $running
}

# Function to check if container exists
function Test-ContainerExists {
    $exists = docker ps -a --format '{{.Names}}' | Select-String -Pattern "^${CONTAINER_NAME}$"
    return $null -ne $exists
}

# Start the container
function Start-Container {
    Write-Info "Starting ${CONTAINER_NAME}..."

    if (Test-ContainerRunning) {
        Write-Warn "Container ${CONTAINER_NAME} is already running."
        return
    }

    if (Test-ContainerExists) {
        Write-Info "Starting existing container..."
        docker start $CONTAINER_NAME
    } else {
        Write-Info "Building and starting new container..."
        if ($env:HTTP_PROXY) {
            Write-Info "Using proxy: $env:HTTP_PROXY"
        }
        Invoke-Expression "${DOCKER_COMPOSE} up -d --build"
    }

    if (Test-ContainerRunning) {
        Write-Info "Container ${CONTAINER_NAME} started successfully!"
        Write-Info "Server should be available at http://localhost:3333"
    } else {
        Write-Error "Failed to start container ${CONTAINER_NAME}"
        exit 1
    }
}

# Stop the container
function Stop-Container {
    Write-Info "Stopping ${CONTAINER_NAME}..."

    if (-not (Test-ContainerRunning)) {
        Write-Warn "Container ${CONTAINER_NAME} is not running."
        return
    }

    docker stop $CONTAINER_NAME

    if (-not (Test-ContainerRunning)) {
        Write-Info "Container ${CONTAINER_NAME} stopped successfully!"
    } else {
        Write-Error "Failed to stop container ${CONTAINER_NAME}"
        exit 1
    }
}

# Restart the container
function Restart-Container {
    Write-Info "Restarting ${CONTAINER_NAME}..."

    if (Test-ContainerExists) {
        docker restart $CONTAINER_NAME
        Write-Info "Container ${CONTAINER_NAME} restarted successfully!"
    } else {
        Write-Warn "Container ${CONTAINER_NAME} does not exist. Starting new container..."
        Start-Container
    }
}

# Force restart (pull latest code and rebuild)
function Force-Restart {
    Write-Info "Force restarting ${CONTAINER_NAME} (updating code and rebuilding)..."

    # Stop if running
    if (Test-ContainerRunning) {
        Stop-Container
    }

    # Remove existing container
    if (Test-ContainerExists) {
        Write-Info "Removing existing container..."
        docker rm -f $CONTAINER_NAME 2>$null
    }

    # Pull latest code (if in git repo)
    if (Test-Path .git) {
        Write-Info "Pulling latest code from git..."
        try {
            git pull
        } catch {
            Write-Warn "Failed to pull from git. Continuing with local code..."
        }
    } else {
        Write-Warn "Not a git repository. Skipping git pull."
    }

    # Rebuild and start
    Write-Info "Rebuilding container..."
    if ($env:HTTP_PROXY) {
        Write-Info "Using proxy: $env:HTTP_PROXY"
    }
    Invoke-Expression "${DOCKER_COMPOSE} build --no-cache"

    Write-Info "Starting container..."
    Invoke-Expression "${DOCKER_COMPOSE} up -d"

    if (Test-ContainerRunning) {
        Write-Info "Container ${CONTAINER_NAME} force restarted successfully!"
        Write-Info "Server should be available at http://localhost:3333"
    } else {
        Write-Error "Failed to start container ${CONTAINER_NAME}"
        exit 1
    }
}

# Show container status
function Show-Status {
    if (Test-ContainerRunning) {
        Write-Info "Container ${CONTAINER_NAME} is running"
        Write-Host ""
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    } elseif (Test-ContainerExists) {
        Write-Warn "Container ${CONTAINER_NAME} exists but is not running"
        docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    } else {
        Write-Warn "Container ${CONTAINER_NAME} does not exist"
    }
}

# Show container logs
function Show-Logs {
    if (Test-ContainerExists) {
        Write-Info "Showing logs for ${CONTAINER_NAME} (Ctrl+C to exit)..."
        docker logs -f $CONTAINER_NAME
    } else {
        Write-Error "Container ${CONTAINER_NAME} does not exist"
        exit 1
    }
}

# Main script logic
switch ($Action) {
    "start" {
        Start-Container
    }
    "stop" {
        Stop-Container
    }
    "restart" {
        Restart-Container
    }
    "frestart" {
        Force-Restart
    }
    "status" {
        Show-Status
    }
    "logs" {
        Show-Logs
    }
    default {
        Write-Host "Usage: .\docker.ps1 [start|stop|restart|frestart|status|logs] [-Proxy <proxy_url>]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  start     - Start the container"
        Write-Host "  stop      - Stop the container"
        Write-Host "  restart   - Restart the container"
        Write-Host "  frestart  - Force restart (pull code, rebuild, restart)"
        Write-Host "  status    - Show container status"
        Write-Host "  logs      - Show container logs (follow mode)"
        Write-Host ""
        Write-Host "Proxy Options:"
        Write-Host "  -Proxy <url>  - Set proxy URL (e.g., http://127.0.0.1:7890)"
        Write-Host ""
        Write-Host "Proxy can also be set via:"
        Write-Host "  1. Environment variables: `$env:HTTP_PROXY, `$env:HTTPS_PROXY"
        Write-Host "  2. .env file in the project root"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  .\docker.ps1 start -Proxy http://127.0.0.1:7890"
        exit 1
    }
}

exit 0
