#!/bin/bash
# Museum of All Things - Itch.io Deployment Tool
# Pushes web build to frogwizardhat.itch.io/moatmp via butler

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

# Itch.io configuration
ITCH_TARGET="frogwizardhat/moatmp:web"
WEB_DIR="dist/web"

print_usage() {
    echo -e "${BLUE}Museum of All Things - Itch.io Deployment Tool${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -b, --build       Run export.sh web before pushing"
    echo "  --dry-run         Show what would be done without executing"
    echo ""
    echo "Target: ${ITCH_TARGET}"
    echo ""
    echo "Pushes dist/web/ to itch.io using butler."
}

check_files() {
    echo -e "${BLUE}Checking web build...${NC}"

    if [[ -f "$WEB_DIR/index.html" ]]; then
        local size
        size=$(du -sh "$WEB_DIR" | cut -f1)
        echo -e "  ${GREEN}✓${NC} $WEB_DIR/index.html found ($size total)"
    else
        echo -e "  ${RED}✗${NC} $WEB_DIR/index.html (missing)"
        echo ""
        echo -e "${RED}Error: Missing web build${NC}"
        echo "Run './export.sh web' first, or use --build flag"
        return 1
    fi

    echo ""
}

push_to_itch() {
    echo -e "${BLUE}Pushing to ${ITCH_TARGET}${NC}"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would execute:"
        echo "  butler push $WEB_DIR $ITCH_TARGET"
        return 0
    fi

    if butler push "$WEB_DIR" "$ITCH_TARGET"; then
        echo ""
        echo -e "  ${GREEN}✓${NC} Push complete"
    else
        echo -e "  ${RED}✗${NC} Failed to push"
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

echo -e "${CYAN}Museum of All Things - Itch.io Deployment${NC}"
echo ""

# Build if requested
if [[ "$BUILD" == "true" ]]; then
    echo -e "${BLUE}Building web export...${NC}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would run: ./export.sh web"
    else
        ./export.sh web
    fi
    echo ""
fi

# Check files exist
if ! check_files; then
    exit 1
fi

# Push to itch.io
if ! push_to_itch; then
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Page: ${CYAN}https://frogwizardhat.itch.io/moatmp${NC}"
