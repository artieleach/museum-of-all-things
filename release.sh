#!/bin/bash
# Museum of All Things - GitHub Release Tool
# Creates a new GitHub release and uploads build artifacts from dist/

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

# Build artifacts to upload (server PCK is embedded in binary)
declare -A ARTIFACTS=(
    ["Linux"]="dist/Linux/MOATMPLinux.x86_64"
    ["Windows"]="dist/Windows/MOATMPWindows.exe"
    ["macOS"]="dist/MuseumOfAllThings_OSX.zip"
    ["Quest"]="dist/MuseumOfAllThings_Quest.apk"
    ["Web"]="dist/web"
    ["Server"]="dist/Server/MuseumOfAllThings_Server.x86_64"
)

print_usage() {
    echo -e "${BLUE}Museum of All Things - GitHub Release Tool${NC}"
    echo ""
    echo "Usage: $0 <version> [options]"
    echo ""
    echo "Arguments:"
    echo "  version             Version tag (e.g., v1.2.0 or 1.2.0)"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -d, --draft         Create as draft release"
    echo "  -p, --prerelease    Mark as prerelease"
    echo "  -n, --notes TEXT    Release notes (or use --notes-file)"
    echo "  -f, --notes-file F  Read release notes from file"
    echo "  -t, --title TITLE   Custom release title (default: version)"
    echo "  --no-build          Skip running export.sh before release"
    echo "  --dry-run           Show what would be done without executing"
    echo "  --latest            Mark as latest release (default for non-prerelease)"
    echo "  --no-latest         Don't mark as latest release"
    echo ""
    echo "Examples:"
    echo "  $0 v1.2.0                          # Release v1.2.0"
    echo "  $0 v1.2.0-beta.1 --prerelease      # Prerelease"
    echo "  $0 v1.2.0 --draft                  # Draft release for review"
    echo "  $0 v1.2.0 -n \"Bug fixes\"           # With inline notes"
    echo "  $0 v1.2.0 -f CHANGELOG.md          # Notes from file"
    echo ""
    echo "Current version tags:"
    git tag --list --sort=-version:refname | head -5 | sed 's/^/  /'
}

check_prerequisites() {
    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi

    # Check gh auth
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}Error: Not authenticated with GitHub CLI${NC}"
        echo "Run: gh auth login"
        exit 1
    fi

    # Check we're in a git repo with a remote
    if ! git remote get-url origin &> /dev/null; then
        echo -e "${RED}Error: No git remote 'origin' configured${NC}"
        exit 1
    fi
}

get_latest_version() {
    git tag --list --sort=-version:refname | head -1
}

validate_version() {
    local version="$1"

    # Add 'v' prefix if missing
    if [[ ! "$version" =~ ^v ]]; then
        version="v$version"
    fi

    # Validate format (semver with optional prerelease)
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        echo -e "${RED}Error: Invalid version format '$version'${NC}" >&2
        echo "Expected format: v1.2.3 or v1.2.3-beta.1" >&2
        return 1
    fi

    # Check if tag already exists
    if git tag --list | grep -q "^${version}$"; then
        echo -e "${RED}Error: Tag '$version' already exists${NC}" >&2
        echo "Use a different version or delete the existing tag:" >&2
        echo "  git tag -d $version" >&2
        echo "  git push origin :refs/tags/$version" >&2
        return 1
    fi

    echo "$version"
}

check_artifacts() {
    echo -e "${BLUE}Checking build artifacts...${NC}"
    local missing=()
    local found=()

    for name in "${!ARTIFACTS[@]}"; do
        local path="${ARTIFACTS[$name]}"
        if [[ -e "$path" ]]; then
            if [[ -d "$path" ]]; then
                local size
                size=$(du -sh "$path" | cut -f1)
                found+=("$name ($size)")
            else
                local size
                size=$(du -h "$path" | cut -f1)
                found+=("$name ($size)")
            fi
        else
            missing+=("$name: $path")
        fi
    done

    if [[ ${#found[@]} -gt 0 ]]; then
        echo -e "${GREEN}Found:${NC}"
        for item in "${found[@]}"; do
            echo "  ✓ $item"
        done
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Missing:${NC}"
        for item in "${missing[@]}"; do
            echo "  ✗ $item"
        done
    fi

    if [[ ${#found[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No build artifacts found!${NC}"
        echo "Run ./export.sh --all first, or use --no-build to skip the check"
        exit 1
    fi

    echo ""
}

create_web_zip() {
    local web_dir="dist/web"
    local zip_file="dist/MuseumOfAllThings_Web.zip"

    if [[ -d "$web_dir" ]]; then
        echo -e "${BLUE}Creating web build archive...${NC}"
        (cd dist && zip -r "MuseumOfAllThings_Web.zip" web)
        echo "  Created: $zip_file"
    fi
}

generate_release_notes() {
    local version="$1"
    local prev_version
    prev_version=$(get_latest_version)

    echo "## What's Changed"
    echo ""

    if [[ -n "$prev_version" ]]; then
        # Get commits since last version
        local commits
        commits=$(git log --oneline "${prev_version}..HEAD" 2>/dev/null | head -20)

        if [[ -n "$commits" ]]; then
            echo "$commits" | while read -r line; do
                echo "- $line"
            done
        else
            echo "- Various improvements and bug fixes"
        fi
        echo ""
        echo "**Full Changelog**: https://github.com/artieleach/museum-of-all-things/compare/${prev_version}...${version}"
    else
        echo "- Initial release"
    fi
}

# Parse arguments
VERSION=""
DRAFT="false"
PRERELEASE="false"
NOTES=""
NOTES_FILE=""
TITLE=""
NO_BUILD="false"
DRY_RUN="false"
LATEST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -d|--draft)
            DRAFT="true"
            shift
            ;;
        -p|--prerelease)
            PRERELEASE="true"
            shift
            ;;
        -n|--notes)
            NOTES="$2"
            shift 2
            ;;
        -f|--notes-file)
            NOTES_FILE="$2"
            shift 2
            ;;
        -t|--title)
            TITLE="$2"
            shift 2
            ;;
        --no-build)
            NO_BUILD="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --latest)
            LATEST="true"
            shift
            ;;
        --no-latest)
            LATEST="false"
            shift
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

# Validate version argument
if [[ -z "$VERSION" ]]; then
    echo -e "${RED}Error: Version is required${NC}"
    echo ""
    print_usage
    exit 1
fi

# Check prerequisites
check_prerequisites

# Validate and normalize version
if ! VERSION=$(validate_version "$VERSION"); then
    exit 1
fi
echo -e "${CYAN}Preparing release: ${VERSION}${NC}"
echo ""

# Set title
if [[ -z "$TITLE" ]]; then
    TITLE="$VERSION"
fi

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    git status --short
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run builds if needed
if [[ "$NO_BUILD" != "true" ]]; then
    echo -e "${BLUE}Running export.sh --all ...${NC}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would run: ./export.sh --all"
    else
        ./export.sh --all
    fi
    echo ""
fi

# Check artifacts
check_artifacts

# Create web zip for upload
if [[ "$DRY_RUN" != "true" ]]; then
    create_web_zip
fi

# Prepare release notes
if [[ -n "$NOTES_FILE" ]]; then
    if [[ ! -f "$NOTES_FILE" ]]; then
        echo -e "${RED}Error: Notes file not found: $NOTES_FILE${NC}"
        exit 1
    fi
    RELEASE_NOTES=$(cat "$NOTES_FILE")
elif [[ -n "$NOTES" ]]; then
    RELEASE_NOTES="$NOTES"
else
    echo -e "${BLUE}Generating release notes from commits...${NC}"
    RELEASE_NOTES=$(generate_release_notes "$VERSION")
fi

echo -e "${BLUE}Release Notes:${NC}"
echo "$RELEASE_NOTES" | head -20
if [[ $(echo "$RELEASE_NOTES" | wc -l) -gt 20 ]]; then
    echo "  ... (truncated)"
fi
echo ""

# Build gh release command
GH_CMD="gh release create \"$VERSION\""
GH_CMD+=" --title \"$TITLE\""

if [[ "$DRAFT" == "true" ]]; then
    GH_CMD+=" --draft"
fi

if [[ "$PRERELEASE" == "true" ]]; then
    GH_CMD+=" --prerelease"
fi

if [[ "$LATEST" == "true" ]]; then
    GH_CMD+=" --latest"
elif [[ "$LATEST" == "false" ]]; then
    GH_CMD+=" --latest=false"
fi

# Add artifacts
UPLOAD_FILES=()
for name in "${!ARTIFACTS[@]}"; do
    path="${ARTIFACTS[$name]}"

    # Skip web directory, use zip instead
    if [[ "$name" == "Web" ]]; then
        if [[ -f "dist/MuseumOfAllThings_Web.zip" ]]; then
            UPLOAD_FILES+=("dist/MuseumOfAllThings_Web.zip")
        fi
        continue
    fi

    if [[ -f "$path" ]]; then
        UPLOAD_FILES+=("$path")
    fi
done

echo -e "${BLUE}Files to upload:${NC}"
for file in "${UPLOAD_FILES[@]}"; do
    size=$(du -h "$file" | cut -f1)
    echo "  • $file ($size)"
done
echo ""

# Create release
# Get the repo from origin remote (not upstream)
ORIGIN_URL=$(git remote get-url origin)
# Extract owner/repo from URL (handles both https and ssh formats)
REPO=$(echo "$ORIGIN_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')

echo -e "${BLUE}Creating GitHub release...${NC}"
echo "Target repository: $REPO"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would execute:"
    echo "  git tag $VERSION"
    echo "  git push origin $VERSION"
    echo "  gh release create $VERSION --repo $REPO --title \"$VERSION\" --notes \"...\""
    echo ""
    echo "Would upload files:"
    for file in "${UPLOAD_FILES[@]}"; do
        echo "  $file"
    done
    echo ""
    echo -e "${GREEN}Dry run complete!${NC}"
    exit 0
fi

# Create and push tag
echo "Creating tag $VERSION..."
if ! git tag "$VERSION"; then
    echo -e "${RED}Error: Failed to create tag${NC}"
    exit 1
fi

echo "Pushing tag to origin..."
if ! git push origin "$VERSION"; then
    echo -e "${RED}Error: Failed to push tag${NC}"
    echo "You may need to delete the local tag: git tag -d $VERSION"
    exit 1
fi

# Build gh command arguments
GH_ARGS=("$VERSION" --repo "$REPO" --title "$TITLE" --notes "$RELEASE_NOTES")

if [[ "$DRAFT" == "true" ]]; then
    GH_ARGS+=(--draft)
fi

if [[ "$PRERELEASE" == "true" ]]; then
    GH_ARGS+=(--prerelease)
fi

# Add files to upload
GH_ARGS+=("${UPLOAD_FILES[@]}")

# Create release with notes
echo "Creating release and uploading files..."
echo "This may take a while for large files..."
echo ""

if ! RELEASE_URL=$(gh release create "${GH_ARGS[@]}" 2>&1); then
    echo -e "${RED}Error: Failed to create release${NC}"
    echo "$RELEASE_URL"
    echo ""
    echo "The tag was pushed. You may want to delete it:"
    echo "  git tag -d $VERSION"
    echo "  git push origin :refs/tags/$VERSION"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Release created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Version: ${CYAN}$VERSION${NC}"
echo -e "URL: ${CYAN}$RELEASE_URL${NC}"
if [[ "$DRAFT" == "true" ]]; then
    echo -e "Status: ${YELLOW}Draft${NC} (publish from GitHub)"
fi
if [[ "$PRERELEASE" == "true" ]]; then
    echo -e "Type: ${YELLOW}Pre-release${NC}"
fi
