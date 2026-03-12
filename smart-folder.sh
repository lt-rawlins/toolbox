#!/usr/bin/env bash
# smart-folder.sh — Simulate macOS Smart Folders on Linux
#
# Runs a find command based on user-defined criteria and creates a directory
# of symlinks to all matching files, giving a unified view of config files,
# logs, or any file type regardless of where they live on disk.
#
# Usage: smart-folder.sh [OPTIONS]
#
# Options:
#   -n NAME     Smart folder name (required) — used as output dir name
#   -t TYPE     Preset type: configs, logs (omit for custom extensions)
#   -e EXTS     Comma-separated extensions without dot (e.g. conf,yaml,ini)
#   -s PATH     Search root path (default: /)
#   -m MINS     Match files modified within last N minutes
#   -H HOURS    Match files modified within last N hours
#   -d DAYS     Match files modified within last N days
#   -o OUTPUT   Parent dir for output (default: ~/smart-folders)
#   -x PATHS    Colon-separated additional paths to exclude
#   -f          Force: clear existing smart folder first
#   -r          Dry run: print matches, don't create anything
#   -h          Show this help
#
# Requires: bash 4+, GNU find
# Recommended: run with sudo for full filesystem visibility

# ANSI color codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_OUTPUT_PARENT="${HOME}/smart-folders"
DEFAULT_SEARCH_ROOT="/"
DEFAULT_EXCLUDES="/proc:/sys:/dev:/run:/tmp:/snap"

# Built-in presets
PRESET_CONFIGS="conf,cfg,ini,yaml,yml,toml,json,env"
PRESET_LOGS="log,log.1,log.2.gz"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

handle_error() {
    print_error "$1"
    exit 1
}

show_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n NAME     Smart folder name (required)"
    echo "  -t TYPE     Preset type: configs, logs"
    echo "  -e EXTS     Comma-separated extensions without dot (e.g. conf,yaml,ini)"
    echo "  -s PATH     Search root path (default: /)"
    echo "  -m MINS     Match files modified within last N minutes"
    echo "  -H HOURS    Match files modified within last N hours"
    echo "  -d DAYS     Match files modified within last N days"
    echo "  -o OUTPUT   Parent dir for output (default: ~/smart-folders)"
    echo "  -x PATHS    Colon-separated additional paths to exclude"
    echo "  -f          Force: clear existing smart folder first"
    echo "  -r          Dry run: print matches, don't create anything"
    echo "  -h          Show this help"
    echo ""
    echo "Examples:"
    echo "  sudo $(basename "$0") -n recent-configs -t configs -d 7"
    echo "  sudo $(basename "$0") -n fresh-logs -t logs -H 2"
    echo "  $(basename "$0") -n yaml-files -e yaml,yml -d 30 -s ~/projects -r"
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

check_dependencies() {
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        handle_error "bash 4.0 or newer is required. Current version: ${BASH_VERSION}"
    fi
    if ! command_exists find; then
        handle_error "'find' is not available. Please install GNU findutils."
    fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
    FOLDER_NAME=""
    PRESET_TYPE=""
    CUSTOM_EXTS=""
    SEARCH_ROOT="${DEFAULT_SEARCH_ROOT}"
    TIME_MINS=""
    TIME_HOURS=""
    TIME_DAYS=""
    OUTPUT_PARENT="${DEFAULT_OUTPUT_PARENT}"
    EXTRA_EXCLUDES=""
    FORCE=false
    DRY_RUN=false

    while getopts ":n:t:e:s:m:H:d:o:x:frh" opt; do
        case "${opt}" in
            n) FOLDER_NAME="${OPTARG}" ;;
            t) PRESET_TYPE="${OPTARG}" ;;
            e) CUSTOM_EXTS="${OPTARG}" ;;
            s) SEARCH_ROOT="${OPTARG}" ;;
            m) TIME_MINS="${OPTARG}" ;;
            H) TIME_HOURS="${OPTARG}" ;;
            d) TIME_DAYS="${OPTARG}" ;;
            o) OUTPUT_PARENT="${OPTARG}" ;;
            x) EXTRA_EXCLUDES="${OPTARG}" ;;
            f) FORCE=true ;;
            r) DRY_RUN=true ;;
            h) show_usage; exit 0 ;;
            :) handle_error "Option -${OPTARG} requires an argument." ;;
            \?) handle_error "Unknown option: -${OPTARG}" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

validate_args() {
    if [[ -z "${FOLDER_NAME}" ]]; then
        show_usage
        echo ""
        handle_error "Smart folder name (-n) is required."
    fi

    if [[ "${FOLDER_NAME}" == *"/"* ]]; then
        handle_error "Folder name (-n) must not contain slashes: '${FOLDER_NAME}'"
    fi

    if [[ -n "${PRESET_TYPE}" && "${PRESET_TYPE}" != "configs" && "${PRESET_TYPE}" != "logs" ]]; then
        handle_error "Invalid type '${PRESET_TYPE}'. Must be: configs or logs."
    fi

    if [[ -z "${PRESET_TYPE}" && -z "${CUSTOM_EXTS}" ]]; then
        handle_error "Either a preset type (-t configs|logs) or custom extensions (-e) is required."
    fi

    local time_count=0
    [[ -n "${TIME_MINS}" ]]  && (( time_count++ ))
    [[ -n "${TIME_HOURS}" ]] && (( time_count++ ))
    [[ -n "${TIME_DAYS}" ]]  && (( time_count++ ))
    if [[ "${time_count}" -gt 1 ]]; then
        handle_error "Only one of -m, -H, or -d may be specified."
    fi

    if [[ -n "${TIME_MINS}" ]]  && ! [[ "${TIME_MINS}"  =~ ^[0-9]+$ ]]; then
        handle_error "-m requires a positive integer (minutes). Got: '${TIME_MINS}'"
    fi
    if [[ -n "${TIME_HOURS}" ]] && ! [[ "${TIME_HOURS}" =~ ^[0-9]+$ ]]; then
        handle_error "-H requires a positive integer (hours). Got: '${TIME_HOURS}'"
    fi
    if [[ -n "${TIME_DAYS}" ]]  && ! [[ "${TIME_DAYS}"  =~ ^[0-9]+$ ]]; then
        handle_error "-d requires a positive integer (days). Got: '${TIME_DAYS}'"
    fi

    if [[ ! -d "${SEARCH_ROOT}" ]]; then
        handle_error "Search root does not exist or is not a directory: '${SEARCH_ROOT}'"
    fi

    OUTPUT_DIR="${OUTPUT_PARENT}/${FOLDER_NAME}"
}

# ---------------------------------------------------------------------------
# Build find components
# ---------------------------------------------------------------------------

build_name_patterns() {
    local ext_list=""

    if [[ -n "${PRESET_TYPE}" ]]; then
        case "${PRESET_TYPE}" in
            configs) ext_list="${PRESET_CONFIGS}" ;;
            logs)    ext_list="${PRESET_LOGS}" ;;
        esac
    else
        ext_list="${CUSTOM_EXTS}"
    fi

    local -a exts
    IFS=',' read -ra exts <<< "${ext_list}"

    NAME_PATTERN_ARGS=()
    local ext
    for ext in "${exts[@]}"; do
        ext="${ext// /}"  # strip whitespace
        [[ -z "${ext}" ]] && continue
        if [[ "${#NAME_PATTERN_ARGS[@]}" -gt 0 ]]; then
            NAME_PATTERN_ARGS+=( -o )
        fi
        NAME_PATTERN_ARGS+=( -name "*.${ext}" )
    done

    if [[ "${#NAME_PATTERN_ARGS[@]}" -eq 0 ]]; then
        handle_error "No valid extensions found. Check -t or -e options."
    fi
}

build_time_filter() {
    TIME_FILTER_ARGS=()

    if [[ -n "${TIME_MINS}" ]]; then
        TIME_FILTER_ARGS=( -mmin "-${TIME_MINS}" )
    elif [[ -n "${TIME_HOURS}" ]]; then
        local mins=$(( TIME_HOURS * 60 ))
        TIME_FILTER_ARGS=( -mmin "-${mins}" )
    elif [[ -n "${TIME_DAYS}" ]]; then
        TIME_FILTER_ARGS=( -mtime "-${TIME_DAYS}" )
    fi
}

build_exclude_args() {
    local all_excludes="${DEFAULT_EXCLUDES}"
    if [[ -n "${EXTRA_EXCLUDES}" ]]; then
        all_excludes="${all_excludes}:${EXTRA_EXCLUDES}"
    fi

    local -a exclude_paths
    IFS=':' read -ra exclude_paths <<< "${all_excludes}"

    EXCLUDE_ARGS=()
    local path
    for path in "${exclude_paths[@]}"; do
        path="${path// /}"
        [[ -z "${path}" ]] && continue
        EXCLUDE_ARGS+=( -path "${path}" -prune -o )
    done
}

# ---------------------------------------------------------------------------
# Find
# ---------------------------------------------------------------------------

run_find() {
    print_header "Searching for Files"

    echo "Search root:  ${SEARCH_ROOT}"
    if [[ -n "${PRESET_TYPE}" ]]; then
        echo "Preset:       ${PRESET_TYPE}"
    else
        echo "Extensions:   ${CUSTOM_EXTS}"
    fi
    if [[ "${#TIME_FILTER_ARGS[@]}" -gt 0 ]]; then
        echo "Time filter:  ${TIME_FILTER_ARGS[*]}"
    else
        print_warning "No time filter specified — searching all files. This may take a while."
    fi
    if [[ "${SEARCH_ROOT}" == "/" ]]; then
        print_warning "Searching from / — this may take a while on large filesystems."
    fi
    echo ""

    local -a find_cmd
    find_cmd=( find "${SEARCH_ROOT}" )
    find_cmd+=( "${EXCLUDE_ARGS[@]}" )
    find_cmd+=( \( -type f )
    find_cmd+=( "${TIME_FILTER_ARGS[@]}" )
    find_cmd+=( \( "${NAME_PATTERN_ARGS[@]}" \) )
    find_cmd+=( \) )

    echo "Running: ${find_cmd[*]} -print0"
    echo ""

    FOUND_FILES=()
    while IFS= read -r -d '' filepath; do
        FOUND_FILES+=( "${filepath}" )
    done < <( "${find_cmd[@]}" -print0 2>/dev/null )

    echo "Found ${#FOUND_FILES[@]} matching file(s)."
}

# ---------------------------------------------------------------------------
# Output directory
# ---------------------------------------------------------------------------

prepare_output_dir() {
    if [[ -d "${OUTPUT_DIR}" ]]; then
        if [[ "${FORCE}" == "true" ]]; then
            print_warning "Force mode: removing existing directory ${OUTPUT_DIR}"
            rm -rf "${OUTPUT_DIR}" || handle_error "Failed to remove existing directory: ${OUTPUT_DIR}"
        else
            print_warning "Output directory already exists: ${OUTPUT_DIR}"
            print_warning "Use -f to force recreation."
            exit 0
        fi
    fi

    if [[ "${DRY_RUN}" == "false" ]]; then
        mkdir -p "${OUTPUT_DIR}" || handle_error "Failed to create output directory: ${OUTPUT_DIR}"
        echo "Created output directory: ${OUTPUT_DIR}"
    fi
}

# ---------------------------------------------------------------------------
# Symlink creation
# ---------------------------------------------------------------------------

create_symlinks() {
    print_header "Creating Symlinks"

    local -i created=0
    local -i skipped=0
    local -i dry_run_count=0
    local -A used_names
    WARNINGS=()

    local filepath
    for filepath in "${FOUND_FILES[@]}"; do
        local basename parent link_name

        basename="$(basename "${filepath}")"
        parent="$(basename "$(dirname "${filepath}")")"
        link_name="${parent}_${basename}"

        # Resolve collisions with counter suffix
        if [[ -v "used_names[${link_name}]" ]]; then
            local counter=2
            while [[ -v "used_names[${link_name}.${counter}]" ]]; do
                (( counter++ ))
            done
            link_name="${link_name}.${counter}"
            WARNINGS+=( "Name conflict resolved with counter: ${link_name} -> ${filepath}" )
        fi

        used_names["${link_name}"]="${filepath}"

        local link_target="${OUTPUT_DIR}/${link_name}"

        if [[ "${DRY_RUN}" == "true" ]]; then
            echo "[DRY RUN] ${link_name} -> ${filepath}"
            (( dry_run_count++ ))
        else
            if ln -s "${filepath}" "${link_target}" 2>/dev/null; then
                (( created++ ))
            else
                WARNINGS+=( "Failed to create symlink for: ${filepath}" )
                (( skipped++ ))
            fi
        fi
    done

    SYMLINKS_CREATED="${created}"
    SYMLINKS_DRY_RUN="${dry_run_count}"
    SYMLINKS_SKIPPED="${skipped}"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_summary() {
    print_header "Summary"
    echo "Files found:       ${#FOUND_FILES[@]}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "Would create:      ${SYMLINKS_DRY_RUN} symlink(s) (dry run)"
        echo "Output directory:  ${OUTPUT_DIR} (not created in dry run)"
    else
        echo "Symlinks created:  ${SYMLINKS_CREATED}"
        [[ "${SYMLINKS_SKIPPED}" -gt 0 ]] && echo "Symlinks skipped:  ${SYMLINKS_SKIPPED}"
        echo "Output directory:  ${OUTPUT_DIR}"
    fi

    if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
        echo ""
        print_warning "${#WARNINGS[@]} warning(s):"
        local warning
        for warning in "${WARNINGS[@]}"; do
            print_warning "  ${warning}"
        done
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    check_dependencies
    parse_args "$@"
    validate_args
    build_name_patterns
    build_time_filter
    build_exclude_args

    print_header "Smart Folder: ${FOLDER_NAME}"

    run_find

    if [[ "${#FOUND_FILES[@]}" -eq 0 ]]; then
        print_warning "No matching files found. Smart folder will be empty."
        if [[ "${DRY_RUN}" == "false" ]]; then
            mkdir -p "${OUTPUT_DIR}" || handle_error "Failed to create output directory: ${OUTPUT_DIR}"
            echo "Created empty output directory: ${OUTPUT_DIR}"
        fi
        print_summary
        exit 0
    fi

    prepare_output_dir
    create_symlinks
    print_summary
}

main "$@"
