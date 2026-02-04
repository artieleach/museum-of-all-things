#!/bin/bash
# Museum of All Things - Server Deployment Tool
# Deploys server build to frogwizard.online via SFTP

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Server configuration
REMOTE_USER="root"
REMOTE_HOST="frogwizard.online"
REMOTE_PATH="/home/artie/MOAT"

# Local files (PCK is embedded in binary)
SERVER_BINARY="dist/Server/MuseumOfAllThings_Server.x86_64"

print_usage() {
    echo -e "${BLUE}Museum of All Things - Server Deployment Tool${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -b, --build       Run export.sh server before deploying"
    echo "  --dry-run         Show what would be done without executing"
    echo ""
    echo "Server: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
    echo ""
    echo "Deploys MuseumOfAllThings_Server.x86_64 and restarts the service."
}

check_files() {
    echo -e "${BLUE}Checking server build...${NC}"

    if [[ -f "$SERVER_BINARY" ]]; then
        local size
        size=$(du -h "$SERVER_BINARY" | cut -f1)
        echo -e "  ${GREEN}✓${NC} $SERVER_BINARY ($size)"
    else
        echo -e "  ${RED}✗${NC} $SERVER_BINARY (missing)"
        echo ""
        echo -e "${RED}Error: Missing server binary${NC}"
        echo "Run './export.sh server' first, or use --build flag"
        return 1
    fi

    echo ""
}

deploy_files() {
    echo -e "${BLUE}Deploying to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}${NC}"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would execute:"
        echo "  ssh ... mkdir -p ${REMOTE_PATH}"
        echo "  scp $SERVER_BINARY ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"
        echo "  ssh ... chmod +x ..."
        return 0
    fi

    # Ensure remote directory exists
    echo "Ensuring remote directory exists..."
    if ssh -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_PATH}"; then
        echo -e "  ${GREEN}✓${NC} Directory ready"
    else
        echo -e "  ${RED}✗${NC} Failed to create directory"
        return 1
    fi

    # Stop server if running (file may be locked)
    echo "Stopping server service..."
    if ssh -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "systemctl stop moat-server 2>/dev/null || true"; then
        echo -e "  ${GREEN}✓${NC} Service stopped"
    fi

    # Upload binary
    echo "Uploading server binary..."
    if scp -o ConnectTimeout=10 "$SERVER_BINARY" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"; then
        echo -e "  ${GREEN}✓${NC} Uploaded"
    else
        echo -e "  ${RED}✗${NC} Failed to upload"
        # Try to restart the service even if upload failed
        ssh -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "systemctl start moat-server 2>/dev/null || true"
        return 1
    fi

    # Ensure binary is executable and set ownership
    echo "Setting permissions..."
    ssh -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "chmod +x ${REMOTE_PATH}/MuseumOfAllThings_Server.x86_64 && chown artie:artie ${REMOTE_PATH}/MuseumOfAllThings_Server.x86_64"
    echo -e "  ${GREEN}✓${NC} Permissions set"

    # Start the service back up
    echo "Starting server service..."
    if ssh -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "systemctl start moat-server"; then
        echo -e "  ${GREEN}✓${NC} Service started"
    else
        echo -e "  ${RED}✗${NC} Failed to start service"
        return 1
    fi

    echo ""
}

# Parse arguments
BUILD="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -b|--build)
            BUILD="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

echo -e "${CYAN}Museum of All Things - Server Deployment${NC}"
echo ""

# Build if requested
if [[ "$BUILD" == "true" ]]; then
    echo -e "${BLUE}Building server...${NC}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would run: ./export.sh server"
    else
        ./export.sh server
    fi
    echo ""
fi

# Check files exist
if ! check_files; then
    exit 1
fi

# Deploy (stops service, uploads, restarts)
if ! deploy_files; then
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Server: ${CYAN}${REMOTE_HOST}:7777${NC}"
