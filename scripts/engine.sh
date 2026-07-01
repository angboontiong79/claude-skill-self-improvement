#!/bin/bash
# Self-Improvement Engine v2.1 - Simplified Version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${STATE_DIR:-$HOME/.claude/projects/self-improvement}"
AUDIT_LOG="$STATE_DIR/audit/log.md"
OUTPUT_DIR="$STATE_DIR/output"

ENGINE_VERSION="2.1.0"
EXPECTED_STATE_VERSION="2.1.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_s() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓${NC} $1"; }
log_w() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠${NC} $1"; }
log_e() { echo -e "${RED}[$(date +'%H:%M:%S')] ✗${NC} $1"; }

run_id() { date +%Y%m%d_%H%M%S_%N; }

# ============================================================================
# State Management
# ============================================================================

state_init() {
    mkdir -p "$STATE_DIR"/{state,audit/log,audit/diffs,output}

    if [ ! -f "$STATE_DIR/state/analyzed.json" ]; then
        echo '{"version":"2.1.0","conversations":{}}' > "$STATE_DIR/state/analyzed.json"
    fi
    if [ ! -f "$STATE_DIR/state/patterns.json" ]; then
        echo '{"version":"2.1.0","patterns":{}}' > "$STATE_DIR/state/patterns.json"
    fi
    if [ ! -f "$STATE_DIR/state/applied.json" ]; then
        echo '{"version":"2.1.0","applied":{}}' > "$STATE_DIR/state/applied.json"
    fi
    if [ ! -f "$STATE_DIR/state/config.json" ]; then
        cat > "$STATE_DIR/state/config.json" << 'CONFIGEOF'
{
    "version": "2.1.0",
    "tier": "gate",
    "preferences": {
        "max_conversations_per_run": 10,
        "min_pattern_frequency": 1,
        "git_enabled": true,
        "telemetry_enabled": true
    }
}
CONFIGEOF
    fi
}

state_load() {
    log "Loading state..."
    state_init
    ANALYZED=$(cat "$STATE_DIR/state/analyzed.json")
    PATTERNS=$(cat "$STATE_DIR/state/patterns.json")
    APPLIED=$(cat "$STATE_DIR/state/applied.json")
    CONFIG=$(cat "$STATE_DIR/state/config.json")
    log_s "State loaded"
}

state_save() {
    log "Saving state..."
    echo "$ANALYZED" > "$STATE_DIR/state/analyzed.json"
    echo "$PATTERNS" > "$STATE_DIR/state/patterns.json"
    echo "$APPLIED" > "$STATE_DIR/state/applied.json"
    log_s "State saved"
}

is_analyzed() {
    local f="$1"
    local name=$(basename "$f" .jsonl)
    echo "$ANALYZED" | jq -e ".conversations[\"$name\"]" >/dev/null 2>&1
}

mark_analyzed() {
    local f="$1"
    local name=$(basename "$f" .jsonl)
    local sum="$2"
    local pat="$3"
    ANALYZED=$(echo "$ANALYZED" | jq --arg n "$name" --arg t "$(date -Iseconds)" --arg s "$sum" --argjson p "$pat" \
        '.conversations[$n] = {"analyzed_at": $t, "status": "complete", "summary": $s, "patterns_found": $p}')
}

is_applied() {
    local id="$1"
    echo "$APPLIED" | jq -e ".applied[\"$id\"]" >/dev/null 2>&1
}

# ============================================================================
# Main
# ============================================================================

main() {
    local force="false"
    local tier="gate"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force) force="true" ;;
            --tier) tier="$2"; shift ;;
            --stats)
                "$SCRIPT_DIR/../states.sh" stats
                exit 0
                ;;
            --clear)
                "$SCRIPT_DIR/../states.sh" clear
                exit 0
                ;;
            --help)
                echo "Usage: engine.sh [--force] [--tier gate|periodic] [--stats] [--clear] [--help]"
                exit 0
                ;;
        esac
        shift
    done

    echo ""
    echo "=========================================="
    echo "SELF-IMPROVEMENT ENGINE v$ENGINE_VERSION"
    echo "=========================================="
    echo ""

    local rid=$(run_id)
    log "Run ID: $rid"
    log "Tier: $tier"

    local project_path=$(pwd)
    local project_encoded=$(echo "$project_path" | tr '/' '-' | sed 's/^-//')
    local conv_dir="$HOME/.claude/projects/$project_encoded"

    state_load
    echo ""

    # Phase 1: Discover
    echo "--- PHASE 1: Discover ---"
    if [ ! -d "$conv_dir" ]; then
        log_e "No conversations directory: $conv_dir"
        return 1
    fi

    mapfile -t all_files < <(ls -lt "$conv_dir"/*.jsonl 2>/dev/null | awk '{print $NF}')
    log "Found ${#all_files[@]} conversation files"

    conversations=()
    local skipped=0
    local max_conv=10
    [ "$tier" = "periodic" ] && max_conv=50

    for f in "${all_files[@]}"; do
        local name=$(basename "$f" .jsonl)
        if [ "$force" != "true" ] && is_analyzed "$f"; then
            ((skipped++))
            continue
        fi
        conversations+=("$f")
        [ ${#conversations[@]} -ge $max_conv ] && break
    done

    log "Selected ${#conversations[@]} for analysis (skipped: $skipped)"
    echo ""

    # Phase 2: Analyze
    echo "--- PHASE 2: Analyze ---"
    local analyses="[]"
    local total_friction=0
    local total_success=0

    for f in "${conversations[@]}"; do
        local name=$(basename "$f")
        log "Analyzing: $name"

        local content=$(cat "$f" 2>/dev/null || echo "{}")

        local friction=$(echo "$content" | jq '[.[] | select(.type == "user") | select(.content | test("again|repeat|same|wrong|broken|fail|error"; "i"))] | length' 2>/dev/null || echo 0)
        local success=$(echo "$content" | jq '[.[] | select(.type == "user") | select(.content | test("perfect|thanks|worked|excellent|awesome"; "i"))] | length' 2>/dev/null || echo 0)
        local turns=$(echo "$content" | jq 'length' 2>/dev/null || echo 0)

        log "  -> turns=$turns, friction=$friction, success=$success"

        mark_analyzed "$f" "turns=$turns friction=$friction" $((friction + success))

        analyses=$(echo "$analyses" | jq --arg f "$name" --argjson fr "$friction" --argjson su "$success" --argjson t "$turns" \
            '. += [{file: $f, friction: $fr, success: $su, turns: $t}]')

        total_friction=$((total_friction + friction))
        total_success=$((total_success + success))
    done

    log_s "Analyzed ${#conversations[@]} conversations (friction: $total_friction, success: $total_success)"
    echo ""

    # Phase 3: Synthesize
    echo "--- PHASE 3: Synthesize ---"
    local new_patterns="[]"

    if [ "$total_friction" -gt 2 ]; then
        local freq=$((total_friction / 2))
        new_patterns=$(echo "$new_patterns" | jq --arg id "repeated-commands" --argjson f "$freq" \
            '. += [{id: $id, title: "Repeated Commands", description: "User running same commands multiple times", frequency: $f, severity: "medium"}]')
        log "-> Pattern: repeated-commands (freq: $freq)"
    fi

    if [ "$total_success" -gt 0 ]; then
        new_patterns=$(echo "$new_patterns" | jq --arg id "success-patterns" --argjson f "$total_success" \
            '. += [{id: $id, title: "Success Patterns", description: "Document what worked well", frequency: $f, severity: "info"}]')
        log "-> Pattern: success-patterns (freq: $total_success)"
    fi

    local filtered="[]"
    local skipped_applied=0
    while IFS= read -r pat; do
        [ -z "$pat" ] && continue
        local pid=$(echo "$pat" | jq -r '.id')
        if is_applied "$pid"; then
            ((skipped_applied++))
            continue
        fi
        filtered=$(echo "$filtered" | jq --argjson p "$pat" '. += [$p]')
    done < <(echo "$new_patterns" | jq -c '.[]')

    log_s "Found $(echo "$new_patterns" | jq 'length') patterns, $(echo "$filtered" | jq 'length') new (skipped applied: $skipped_applied)"
    echo ""

    # Phase 4: Output
    echo "--- PHASE 4: Output ---"
    if [ "$(echo "$filtered" | jq 'length')" -eq 0 ]; then
        log_w "No new patterns to suggest"
        OUTPUT_FILE=""
    else
        local timestamp=$(date +%Y%m%d_%H%M%S)
        OUTPUT_FILE="$OUTPUT_DIR/CLAUDE_IMPROVEMENTS_${timestamp}.md"

        cat > "$OUTPUT_FILE" << MDEOF
# CLAUDE.md Improvement Suggestions

**Generated:** $(date -Iseconds)
**Run ID:** $rid
**Project:** $project_path
**Tier:** $tier

---

## Summary

| Metric | Count |
|--------|-------|
| Conversations analyzed | ${#conversations[@]} |
| Patterns detected | $(echo "$new_patterns" | jq 'length') |
| New suggestions | $(echo "$filtered" | jq 'length') |

---

## New Issues Found

MDEOF

        local pnum=1
        while IFS= read -r pat; do
            [ -z "$pat" ] && continue
            local pid=$(echo "$pat" | jq -r '.id')
            local ptitle=$(echo "$pat" | jq -r '.title')
            local pdesc=$(echo "$pat" | jq -r '.description')
            local pfreq=$(echo "$pat" | jq -r '.frequency')
            local psev=$(echo "$pat" | jq -r '.severity')

            echo "### $pnum. [$psev] $ptitle (seen $pfreq times)" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "**Pattern ID:** \`$pid\`" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "**Problem:** $pdesc" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "**Suggested fix:** <!-- Add improvement here -->" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "**Status:** Pending review" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "---" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"

            ((pnum++))
        done < <(echo "$filtered" | jq -c '.[]')

        log_s "Output: $OUTPUT_FILE"
    fi
    echo ""

    # Save state
    state_save

    # Complete
    echo "=========================================="
    log_s "SELF-IMPROVEMENT COMPLETE"
    echo "=========================================="
    echo ""

    if [ -n "$OUTPUT_FILE" ]; then
        log "Review: $OUTPUT_FILE"
    fi
}

main "$@"
