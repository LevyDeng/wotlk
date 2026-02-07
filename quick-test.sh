#!/bin/bash

# Quick Test Script for Development
# Rebuilds only changed code and restarts the server

CONTAINER_NAME="wowsims-wotlk-dev"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

is_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

TARGET="${1:-server}"

case "$TARGET" in
    start)
        print_info "Starting dev container (docker-compose.dev.yml)..."

        if is_running; then
            print_info "Container $CONTAINER_NAME is already running. Use ./quick-test.sh restart to restart."
            exit 0
        fi

        docker-compose -f docker-compose.dev.yml up -d --build

        if [ $? -eq 0 ]; then
            print_info "Container started! Server will be at http://localhost:3333 (first start may take a minute to build frontend)."
        else
            print_error "Failed to start container."
            exit 1
        fi
        ;;

    items)
        print_info "Regenerating items database..."

        # Run database generation locally (fast, no Docker rebuild)
        go run ./tools/database/gen_db -outDir ./assets -gen db

        if [ $? -eq 0 ]; then
            print_info "Database regenerated successfully!"
            print_info "Restart the server to load new database: ./quick-test.sh restart"
        else
            print_error "Database generation failed!"
            exit 1
        fi
        ;;

    server)
        print_info "Rebuilding server binary..."

        if is_running; then
            # Rebuild inside container (uses cached dependencies)
            docker exec $CONTAINER_NAME sh -c "make devserver"

            if [ $? -eq 0 ]; then
                print_info "Server rebuilt! Restarting container..."
                docker restart $CONTAINER_NAME
                print_info "Server restarted! Available at http://localhost:3333"
            else
                print_error "Server build failed!"
                exit 1
            fi
        else
            print_error "Container $CONTAINER_NAME is not running. Start it with: ./quick-test.sh start"
            exit 1
        fi
        ;;

    ui)
        print_info "Rebuilding UI..."

        if is_running; then
            docker exec $CONTAINER_NAME sh -c "make binary_dist"

            if [ $? -eq 0 ]; then
                print_info "UI rebuilt successfully! Refresh your browser."
            else
                print_error "UI build failed!"
                exit 1
            fi
        else
            print_error "Container $CONTAINER_NAME is not running. Start it with: ./quick-test.sh start"
            exit 1
        fi
        ;;

    full)
        print_info "Full rebuild (items + server + UI)..."

        # Regenerate items database
        print_info "Step 1/3: Regenerating items database..."
        go run ./tools/database/gen_db -outDir ./assets -gen db

        if [ $? -ne 0 ]; then
            print_error "Database generation failed!"
            exit 1
        fi

        if is_running; then
            # Rebuild server
            print_info "Step 2/3: Rebuilding server..."
            docker exec $CONTAINER_NAME sh -c "make devserver"

            if [ $? -ne 0 ]; then
                print_error "Server build failed!"
                exit 1
            fi

            # Rebuild UI
            print_info "Step 3/3: Rebuilding UI..."
            docker exec $CONTAINER_NAME sh -c "make binary_dist"

            if [ $? -ne 0 ]; then
                print_error "UI build failed!"
                exit 1
            fi

            print_info "Restarting server..."
            docker restart $CONTAINER_NAME
            print_info "Full rebuild complete! Server available at http://localhost:3333"
        else
            print_error "Container $CONTAINER_NAME is not running. Start it with: ./quick-test.sh start"
            exit 1
        fi
        ;;

    restart)
        print_info "Restarting server..."

        if is_running; then
            docker restart $CONTAINER_NAME
            print_info "Server restarted!"
        else
            print_error "Container $CONTAINER_NAME is not running. Start it with: ./quick-test.sh start"
            exit 1
        fi
        ;;

    stop)
        print_info "Stopping dev container..."

        if is_running; then
            docker stop $CONTAINER_NAME
            print_info "Container $CONTAINER_NAME stopped."
        else
            print_info "Container $CONTAINER_NAME is not running."
        fi
        ;;

    *)
        echo "Usage: ./quick-test.sh [start|stop|items|server|ui|full|restart]"
        echo ""
        echo "Commands:"
        echo "  start   - Start dev container (docker-compose.dev.yml, build if needed)"
        echo "  stop    - Stop dev container"
        echo "  items   - Regenerate items database only (fastest)"
        echo "  server  - Rebuild server binary only"
        echo "  ui      - Rebuild UI only"
        echo "  full    - Rebuild everything (items + server + UI)"
        echo "  restart - Restart server without rebuilding"
        echo ""
        echo "Example workflow:"
        echo "  1. ./quick-test.sh start          # start Docker dev container"
        echo "  2. Modify tools/database/overrides.go"
        echo "  3. ./quick-test.sh items; ./quick-test.sh restart"
        exit 1
        ;;
esac

exit 0
