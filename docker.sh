#!/bin/bash

# WoW WOTLK Simulator Docker Management Script
# Usage: ./docker.sh [start|restart|frestart|stop|status|logs]

CONTAINER_NAME="wowsims-wotlk"
COMPOSE_FILE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "docker-compose is not installed. Please install Docker Compose."
    exit 1
fi

# Use 'docker compose' if available, otherwise fall back to 'docker-compose'
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Function to check if container is running
is_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Function to check if container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Start the container
start() {
    print_info "Starting ${CONTAINER_NAME}..."

    if is_running; then
        print_warn "Container ${CONTAINER_NAME} is already running."
        return 0
    fi

    if container_exists; then
        print_info "Starting existing container..."
        docker start ${CONTAINER_NAME}
    else
        print_info "Building and starting new container..."
        ${DOCKER_COMPOSE} up -d --build
    fi

    if is_running; then
        print_info "Container ${CONTAINER_NAME} started successfully!"
        print_info "Server should be available at http://localhost:3333"
    else
        print_error "Failed to start container ${CONTAINER_NAME}"
        exit 1
    fi
}

# Stop the container
stop() {
    print_info "Stopping ${CONTAINER_NAME}..."

    if ! is_running; then
        print_warn "Container ${CONTAINER_NAME} is not running."
        return 0
    fi

    docker stop ${CONTAINER_NAME}

    if ! is_running; then
        print_info "Container ${CONTAINER_NAME} stopped successfully!"
    else
        print_error "Failed to stop container ${CONTAINER_NAME}"
        exit 1
    fi
}

# Restart the container
restart() {
    print_info "Restarting ${CONTAINER_NAME}..."

    if container_exists; then
        docker restart ${CONTAINER_NAME}
        print_info "Container ${CONTAINER_NAME} restarted successfully!"
    else
        print_warn "Container ${CONTAINER_NAME} does not exist. Starting new container..."
        start
    fi
}

# Force restart (pull latest code and rebuild)
frestart() {
    print_info "Force restarting ${CONTAINER_NAME} (updating code and rebuilding)..."

    # Stop if running
    if is_running; then
        stop
    fi

    # Remove existing container
    if container_exists; then
        print_info "Removing existing container..."
        docker rm -f ${CONTAINER_NAME} 2>/dev/null || true
    fi

    # Pull latest code (if in git repo)
    if [ -d .git ]; then
        print_info "Pulling latest code from git..."
        git pull || print_warn "Failed to pull from git. Continuing with local code..."
    else
        print_warn "Not a git repository. Skipping git pull."
    fi

    # Rebuild and start
    print_info "Rebuilding container..."
    ${DOCKER_COMPOSE} build --no-cache

    print_info "Starting container..."
    ${DOCKER_COMPOSE} up -d

    if is_running; then
        print_info "Container ${CONTAINER_NAME} force restarted successfully!"
        print_info "Server should be available at http://localhost:3333"
    else
        print_error "Failed to start container ${CONTAINER_NAME}"
        exit 1
    fi
}

# Show container status
status() {
    if is_running; then
        print_info "Container ${CONTAINER_NAME} is running"
        echo ""
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    elif container_exists; then
        print_warn "Container ${CONTAINER_NAME} exists but is not running"
        docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        print_warn "Container ${CONTAINER_NAME} does not exist"
    fi
}

# Show container logs
logs() {
    if container_exists; then
        print_info "Showing logs for ${CONTAINER_NAME} (Ctrl+C to exit)..."
        docker logs -f ${CONTAINER_NAME}
    else
        print_error "Container ${CONTAINER_NAME} does not exist"
        exit 1
    fi
}

# Main script logic
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    frestart)
        frestart
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|frestart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start     - Start the container"
        echo "  stop      - Stop the container"
        echo "  restart   - Restart the container"
        echo "  frestart  - Force restart (pull code, rebuild, restart)"
        echo "  status    - Show container status"
        echo "  logs      - Show container logs (follow mode)"
        exit 1
        ;;
esac

exit 0
