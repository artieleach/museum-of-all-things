#!/bin/bash
# Museum of All Things - Build Export Tool
# Exports game builds to dist/ using Godot's command-line interface

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Available presets (from export_presets.cfg)
declare -A PRESETS=(
    ["linux"]="MOATMPLinux"
    ["windows"]="Windows Desktop"
    ["macos"]="macOS"
    ["quest"]="Meta Quest"
    ["web"]="Web"
    ["linux-vr"]="Linux (OpenXR)"
    ["windows-vr"]="Windows Desktop (OpenXR)"
    ["server"]="Server"
)

# Export paths (for verification)
declare -A EXPORT_PATHS=(
    ["linux"]="dist/Linux/MOATMPLinux.x86_64"
    ["windows"]="dist/Windows/MOATMPWindows.exe"
    ["macos"]="dist/MuseumOfAllThings_OSX.zip"
    ["quest"]="dist/MuseumOfAllThings_Quest.apk"
    ["web"]="dist/web/index.html"
    ["linux-vr"]="dist/MuseumOfAllThings_Linux_OpenXR.x86_64"
    ["windows-vr"]="dist/MuseumOfAllThings_OpenXR.exe"
    ["server"]="dist/Server/MuseumOfAllThings_Server.x86_64"
)

# Find Godot executable
find_godot() {
    # Check common locations and names
    local godot_names=("godot" "godot4" "godot-4" "godot4.6" "org.godotengine.Godot")

    for name in "${godot_names[@]}"; do
        if command -v "$name" &> /dev/null; then
            echo "$name"
            return 0
        fi
    done

    # Check flatpak
    if flatpak list 2>/dev/null | grep -q "org.godotengine.Godot"; then
        echo "flatpak run org.godotengine.Godot"
        return 0
    fi

    # Check for GODOT environment variable
    if [[ -n "$GODOT" ]] && [[ -x "$GODOT" ]]; then
        echo "$GODOT"
        return 0
    fi

    return 1
}

print_usage() {
    echo -e "${BLUE}Museum of All Things - Build Export Tool${NC}"
    echo ""
    echo "Usage: $0 [options] [preset...]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -l, --list        List available presets"
    echo "  -a, --all         Export all presets"
    echo "  -d, --debug       Export in debug mode (includes debugging symbols)"
    echo "  --dry-run         Show what would be exported without running"
    echo ""
    echo "Presets:"
    for key in "${!PRESETS[@]}"; do
        printf "  %-12s  %s\n" "$key" "${PRESETS[$key]}"
    done | sort
    echo ""
    echo "Examples:"
    echo "  $0 linux windows      # Export Linux and Windows builds"
    echo "  $0 --all              # Export all platforms"
    echo "  $0 server             # Export dedicated server only"
    echo ""
    echo "Environment:"
    echo "  GODOT=/path/to/godot  # Specify custom Godot executable"
}

list_presets() {
    echo -e "${BLUE}Available Export Presets:${NC}"
    echo ""
    printf "  ${YELLOW}%-12s${NC}  %-28s  %s\n" "Key" "Preset Name" "Output Path"
    echo "  ------------------------------------------------------------"
    for key in "${!PRESETS[@]}"; do
        printf "  %-12s  %-28s  %s\n" "$key" "${PRESETS[$key]}" "${EXPORT_PATHS[$key]}"
    done | sort
}

export_preset() {
    local key="$1"
    local debug_flag="$2"
    local preset_name="${PRESETS[$key]}"
    local export_path="${EXPORT_PATHS[$key]}"

    if [[ -z "$preset_name" ]]; then
        echo -e "${RED}Error: Unknown preset '$key'${NC}"
        return 1
    fi

    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$export_path")
    mkdir -p "$output_dir"

    echo -e "${BLUE}Exporting:${NC} $preset_name"
    echo -e "  Output: $export_path"

    local export_cmd="--export-release"
    if [[ "$debug_flag" == "true" ]]; then
        export_cmd="--export-debug"
        echo -e "  Mode: ${YELLOW}Debug${NC}"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY RUN]${NC} Would run: $GODOT_CMD --headless $export_cmd \"$preset_name\" \"$export_path\""
        return 0
    fi

    # Run export
    if $GODOT_CMD --headless $export_cmd "$preset_name" "$export_path" 2>&1; then
        if [[ -f "$export_path" ]]; then
            local size
            size=$(du -h "$export_path" | cut -f1)
            echo -e "  ${GREEN}✓ Success${NC} ($size)"
        else
            echo -e "  ${GREEN}✓ Export completed${NC}"
        fi
    else
        echo -e "  ${RED}✗ Export failed${NC}"
        return 1
    fi
}

# Parse arguments
DEBUG_MODE="false"
DRY_RUN="false"
EXPORT_ALL="false"
PRESETS_TO_EXPORT=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -l|--list)
            list_presets
            exit 0
            ;;
        -a|--all)
            EXPORT_ALL="true"
            shift
            ;;
        -d|--debug)
            DEBUG_MODE="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            print_usage
            exit 1
            ;;
        *)
            PRESETS_TO_EXPORT+=("$1")
            shift
            ;;
    esac
done

# Find Godot
GODOT_CMD=$(find_godot) || {
    echo -e "${RED}Error: Could not find Godot executable${NC}"
    echo "Please install Godot 4.x or set the GODOT environment variable"
    echo "  export GODOT=/path/to/godot"
    exit 1
}

echo -e "${GREEN}Using Godot:${NC} $GODOT_CMD"
echo ""

# Determine what to export
if [[ "$EXPORT_ALL" == "true" ]]; then
    PRESETS_TO_EXPORT=(linux windows macos quest web linux-vr windows-vr server)
elif [[ ${#PRESETS_TO_EXPORT[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No presets specified. Use --help for usage.${NC}"
    echo ""
    list_presets
    exit 1
fi

# Validate presets
for preset in "${PRESETS_TO_EXPORT[@]}"; do
    if [[ -z "${PRESETS[$preset]}" ]]; then
        echo -e "${RED}Error: Unknown preset '$preset'${NC}"
        echo "Use --list to see available presets"
        exit 1
    fi
done

# Export
echo -e "${BLUE}Starting export...${NC}"
echo ""

FAILED=()
SUCCEEDED=()

for preset in "${PRESETS_TO_EXPORT[@]}"; do
    if export_preset "$preset" "$DEBUG_MODE"; then
        SUCCEEDED+=("$preset")
    else
        FAILED+=("$preset")
    fi
    echo ""
done

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Export Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [[ ${#SUCCEEDED[@]} -gt 0 ]]; then
    echo -e "${GREEN}Succeeded:${NC} ${SUCCEEDED[*]}"
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "${RED}Failed:${NC} ${FAILED[*]}"
    exit 1
fi

echo -e "\n${GREEN}All exports completed successfully!${NC}"
