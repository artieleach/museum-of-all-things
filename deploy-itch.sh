#!/bin/bash
# Museum of All Things - Itch.io Deployment Tool
# Pushes web, Linux, Windows, and macOS builds to frogwizardhat.itch.io/moatmp via butler

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

# Itch.io configuration: platform -> channel
ITCH_USER="frogwizardhat/moatmp"
PLATFORMS=(web linux windows macos)

declare -A ITCH_CHANNELS=(
    [web]="web"
    [linux]="linux"
    [windows]="windows"
    [macos]="macos"
)

declare -A BUILD_PATHS=(
    [web]="dist/web"
    [linux]="dist/Linux"
    [windows]="dist/Windows"
    [macos]="dist/MuseumOfAllThings_OSX.zip"
)

declare -A CHECK_FILES=(
    [web]="dist/web/index.html"
    [linux]="dist/Linux/MOATMPLinux.x86_64"
    [windows]="dist/Windows/MOATMPWindows.exe"
    [macos]="dist/MuseumOfAllThings_OSX.zip"
)

print_usage() {
    echo -e "${BLUE}Museum of All Things - Itch.io Deployment Tool${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -b, --build       Run export.sh for all platforms before pushing"
    echo "  --dry-run         Show what would be done without executing"
    echo ""
    echo "Platforms:"
    for platform in "${PLATFORMS[@]}"; do
        echo "  ${platform}  ->  ${ITCH_USER}:${ITCH_CHANNELS[$platform]}  (${BUILD_PATHS[$platform]})"
    done
    echo ""
    echo "Pushes all platform builds to itch.io using butler."
}

check_files() {
    echo -e "${BLUE}Checking builds...${NC}"

    local missing=0
    for platform in "${PLATFORMS[@]}"; do
        local check_path="${CHECK_FILES[$platform]}"
        if [[ -e "$check_path" ]]; then
            local size
            size=$(du -sh "${BUILD_PATHS[$platform]}" | cut -f1)
            echo -e "  ${GREEN}✓${NC} ${platform}: ${check_path} ($size)"
        else
            echo -e "  ${RED}✗${NC} ${platform}: ${check_path} (missing)"
            missing=$((missing + 1))
        fi
    done

    echo ""

    if [[ $missing -gt 0 ]]; then
        echo -e "${RED}Error: $missing platform build(s) missing${NC}"
        echo "Run './export.sh web linux windows macos' first, or use --build flag"
        return 1
    fi
}

push_to_itch() {
    local failed=0
    for platform in "${PLATFORMS[@]}"; do
        local target="${ITCH_USER}:${ITCH_CHANNELS[$platform]}"
        local path="${BUILD_PATHS[$platform]}"

        echo -e "${BLUE}Pushing ${platform} to ${target}${NC}"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY RUN]${NC} butler push $path $target"
        else
            if butler push "$path" "$target"; then
                echo -e "  ${GREEN}✓${NC} ${platform} push complete"
            else
                echo -e "  ${RED}✗${NC} ${platform} push failed"
                failed=$((failed + 1))
            fi
        fi
        echo ""
    done

    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}$failed platform(s) failed to push${NC}"
        return 1
    fi
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
    echo -e "${BLUE}Building all platform exports...${NC}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would run: ./export.sh web linux windows macos"
    else
        ./export.sh web linux windows macos
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
