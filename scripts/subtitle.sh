#!/bin/bash
#
# subtitle.sh — Generate .srt subtitles for video files using whisper.cpp
#
# Usage:
#   bash subtitle.sh /path/to/movie.mkv              # single file
#   bash subtitle.sh /path/to/media/                  # batch: all video files in directory
#   bash subtitle.sh /path/to/media/ --recursive      # batch: recursive
#
# Requirements:
#   brew install whisper-cpp ffmpeg
#   Download a model: (run once)
#     mkdir -p ~/models
#     curl -L -o ~/models/ggml-large-v3-turbo-q8_0.bin \
#       "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin"
#
# Output:
#   Creates a .srt file next to each video with the same base name.
#   Jellyfin picks these up automatically as sidecar subtitles.
#
# Notes:
#   - Skips files that already have a .srt
#   - Uses Metal GPU acceleration on Apple Silicon (~5-10x realtime)
#   - large-v3-turbo is nearly as accurate as full large-v3 but much faster
#

set -e

# ── Configuration ─────────────────────────────────────────────────────────
MODEL="${WHISPER_MODEL:-$HOME/models/ggml-large-v3-turbo-q8_0.bin}"
LANGUAGE="${WHISPER_LANG:-en}"
MAX_LINE_LEN=47
# ──────────────────────────────────────────────────────────────────────────

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $1"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $1"; }

usage() {
    sed -n '2,/^$/{ s/^# \?//; p }' "$0"
    exit 0
}

# Check dependencies
if ! command -v whisper-cpp &>/dev/null; then
    fail "whisper-cpp not found. Install with: brew install whisper-cpp"
    exit 1
fi
if ! command -v ffmpeg &>/dev/null; then
    fail "ffmpeg not found. Install with: brew install ffmpeg"
    exit 1
fi
if [ ! -f "$MODEL" ]; then
    fail "Whisper model not found at: $MODEL"
    echo "  Download it with:"
    echo "    mkdir -p ~/models"
    echo '    curl -L -o ~/models/ggml-large-v3-turbo-q8_0.bin \'
    echo '      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin"'
    echo ""
    echo "  Or set WHISPER_MODEL=/path/to/your/model.bin"
    exit 1
fi

# Metal GPU acceleration path
METAL_PATH=""
if brew --prefix whisper-cpp &>/dev/null; then
    METAL_PATH="$(brew --prefix whisper-cpp)/share/whisper-cpp"
fi

subtitle_one_file() {
    local input="$1"
    local basename="${input%.*}"
    local srt="${basename}.srt"

    if [ -f "$srt" ]; then
        ok "Subtitle exists, skipping: $(basename "$srt")"
        return 0
    fi

    info "Processing: $(basename "$input")"
    local start_time=$(date +%s)

    ffmpeg -i "$input" -ar 16000 -ac 1 -f wav -loglevel error - | \
    GGML_METAL_PATH_RESOURCES="$METAL_PATH" \
    whisper-cpp \
        --model "$MODEL" \
        --output-srt \
        --language "$LANGUAGE" \
        --max-len "$MAX_LINE_LEN" \
        --output-file "$basename" \
        - 2>/dev/null

    local end_time=$(date +%s)
    local elapsed=$(( end_time - start_time ))

    if [ -f "$srt" ]; then
        ok "Created: $(basename "$srt") (${elapsed}s)"
    else
        fail "Failed to create subtitles for: $(basename "$input")"
        return 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

INPUT="$1"
RECURSIVE=false
[ "$2" = "--recursive" ] && RECURSIVE=true

VIDEO_EXTENSIONS="mkv mp4 avi mov wmv flv webm m4v"

if [ -f "$INPUT" ]; then
    # Single file mode
    subtitle_one_file "$INPUT"
elif [ -d "$INPUT" ]; then
    # Batch mode — find all video files
    FIND_ARGS="-maxdepth 1"
    $RECURSIVE && FIND_ARGS=""

    FIND_PATTERN=""
    for ext in $VIDEO_EXTENSIONS; do
        [ -n "$FIND_PATTERN" ] && FIND_PATTERN="$FIND_PATTERN -o"
        FIND_PATTERN="$FIND_PATTERN -name *.$ext"
    done

    TOTAL=0
    CREATED=0
    SKIPPED=0
    FAILED=0

    while IFS= read -r file; do
        TOTAL=$((TOTAL + 1))
        srt="${file%.*}.srt"
        if [ -f "$srt" ]; then
            SKIPPED=$((SKIPPED + 1))
            ok "Subtitle exists, skipping: $(basename "$srt")"
        elif subtitle_one_file "$file"; then
            CREATED=$((CREATED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done < <(eval "find '$INPUT' $FIND_ARGS -type f \( $FIND_PATTERN \)" 2>/dev/null | sort)

    echo ""
    info "Done. Total: $TOTAL | Created: $CREATED | Skipped: $SKIPPED | Failed: $FAILED"
else
    fail "Not a file or directory: $INPUT"
    exit 1
fi
