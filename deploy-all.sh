#!/bin/bash
# Museum of All Things - Full Deploy Pipeline
# Exports all builds, creates a GitHub release, pushes to itch.io, and deploys the server

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

print_usage() {
    echo -e "${BLUE}Museum of All Things - Full Deploy Pipeline${NC}"
    echo ""
    echo "Usage: $0 <version> [options]"
    echo ""
    echo "Runs the full pipeline: export -> GitHub release -> itch.io -> server"
    echo ""
    echo "Arguments:"
    echo "  version               Version tag (e.g., v1.2.0 or 1.2.0)"
    echo ""
    echo "Options:"
    echo "  -h, --help            Show this help message"
    echo "  --skip-export         Skip Godot exports (use existing dist/ builds)"
    echo "  --skip-github         Skip GitHub release"
    echo "  --skip-itch           Skip itch.io deployment"
    echo "  --skip-server         Skip server deployment"
    echo "  -d, --draft           Create GitHub release as draft"
    echo "  -p, --prerelease      Mark GitHub release as prerelease"
    echo "  -n, --notes TEXT      Release notes for GitHub"
    echo "  -f, --notes-file F    Read release notes from file"
    echo "  --dry-run             Show what would be done without executing"
    echo ""
    echo "Examples:"
    echo "  $0 v1.2.0                        # Full deploy"
    echo "  $0 v1.2.0 --skip-export          # Deploy existing builds"
    echo "  $0 v1.2.0 --skip-github          # Deploy without GitHub release"
    echo "  $0 v1.2.0 --draft                # GitHub release as draft"
    echo "  $0 v1.2.0 --dry-run              # Preview all steps"
}

# Parse arguments
VERSION=""
SKIP_EXPORT="false"
SKIP_GITHUB="false"
SKIP_ITCH="false"
SKIP_SERVER="false"
DRY_RUN="false"
RELEASE_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        --skip-export)
            SKIP_EXPORT="true"
            shift
            ;;
        --skip-github)
            SKIP_GITHUB="true"
            shift
            ;;
        --skip-itch)
            SKIP_ITCH="true"
            shift
            ;;
        --skip-server)
            SKIP_SERVER="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -d|--draft)
            RELEASE_ARGS+=(--draft)
            shift
            ;;
        -p|--prerelease)
            RELEASE_ARGS+=(--prerelease)
            shift
            ;;
        -n|--notes)
            RELEASE_ARGS+=(--notes "$2")
            shift 2
            ;;
        -f|--notes-file)
            RELEASE_ARGS+=(--notes-file "$2")
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            print_usage
            exit 1
            ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION="$1"
            else
                echo -e "${RED}Error: Unexpected argument $1${NC}"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo -e "${RED}Error: Version is required${NC}"
    echo ""
    print_usage
    exit 1
fi

# Add 'v' prefix if missing
if [[ ! "$VERSION" =~ ^v ]]; then
    VERSION="v$VERSION"
fi

DRY_FLAG=""
if [[ "$DRY_RUN" == "true" ]]; then
    DRY_FLAG="--dry-run"
fi

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Museum of All Things - Full Deploy      ║${NC}"
echo -e "${CYAN}║  Version: $(printf '%-30s' "$VERSION")║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Build summary of what will run
echo -e "${BLUE}Pipeline steps:${NC}"
[[ "$SKIP_EXPORT" == "false" ]] && echo "  1. Export all builds" || echo -e "  1. ${YELLOW}Export (skipped)${NC}"
[[ "$SKIP_GITHUB" == "false" ]] && echo "  2. GitHub release" || echo -e "  2. ${YELLOW}GitHub release (skipped)${NC}"
[[ "$SKIP_ITCH"   == "false" ]] && echo "  3. Itch.io deploy" || echo -e "  3. ${YELLOW}Itch.io deploy (skipped)${NC}"
[[ "$SKIP_SERVER" == "false" ]] && echo "  4. Server deploy" || echo -e "  4. ${YELLOW}Server deploy (skipped)${NC}"
echo ""

FAILED=()

# ── Step 1: Export ──────────────────────────────────────────
if [[ "$SKIP_EXPORT" == "false" ]]; then
    echo -e "${CYAN}━━━ Step 1/4: Exporting builds ━━━${NC}"
    echo ""
    if ./export.sh --all $DRY_FLAG; then
        echo -e "${GREEN}✓ Export complete${NC}"
    else
        echo -e "${RED}✗ Export failed${NC}"
        FAILED+=("export")
        echo -e "${YELLOW}Continuing with remaining steps...${NC}"
    fi
    echo ""
fi

# ── Step 2: GitHub Release ──────────────────────────────────
if [[ "$SKIP_GITHUB" == "false" ]]; then
    echo -e "${CYAN}━━━ Step 2/4: GitHub release ━━━${NC}"
    echo ""
    if ./release.sh "$VERSION" --no-build "${RELEASE_ARGS[@]}" $DRY_FLAG; then
        echo -e "${GREEN}✓ GitHub release complete${NC}"
    else
        echo -e "${RED}✗ GitHub release failed${NC}"
        FAILED+=("github")
    fi
    echo ""
fi

# ── Step 3: Itch.io ────────────────────────────────────────
if [[ "$SKIP_ITCH" == "false" ]]; then
    echo -e "${CYAN}━━━ Step 3/4: Itch.io deployment ━━━${NC}"
    echo ""
    if ./deploy-itch.sh $DRY_FLAG; then
        echo -e "${GREEN}✓ Itch.io deployment complete${NC}"
    else
        echo -e "${RED}✗ Itch.io deployment failed${NC}"
        FAILED+=("itch")
    fi
    echo ""
fi

# ── Step 4: Server ──────────────────────────────────────────
if [[ "$SKIP_SERVER" == "false" ]]; then
    echo -e "${CYAN}━━━ Step 4/4: Server deployment ━━━${NC}"
    echo ""
    if ./deploy-server.sh $DRY_FLAG; then
        echo -e "${GREEN}✓ Server deployment complete${NC}"
    else
        echo -e "${RED}✗ Server deployment failed${NC}"
        FAILED+=("server")
    fi
    echo ""
fi

# ── Summary ─────────────────────────────────────────────────
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo -e "${CYAN}║${NC}  ${GREEN}All steps completed successfully!${NC}        ${CYAN}║${NC}"
else
    echo -e "${CYAN}║${NC}  ${RED}Some steps failed: ${FAILED[*]}$(printf '%*s' $((17 - ${#FAILED[*]} * 5)) '')${CYAN}║${NC}"
fi
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    exit 1
fi
