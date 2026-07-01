#!/bin/bash
# Self-Improvement State Manager v2.1
# Handles statistics, audit logs, and state management

STATE_DIR="$HOME/.claude/projects/self-improvement"
ANALYTICS_DIR="$HOME/.gstack/analytics"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# Helpers
# ============================================================================

has_jq() {
    command -v jq &>/dev/null
}

check_state() {
    if [ ! -d "$STATE_DIR" ]; then
        echo -e "${RED}Error: State directory not found. Run /self-improvement first.${NC}"
        exit 1
    fi
}

# ============================================================================
# Stats Command
# ============================================================================

cmd_stats() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Self-Improvement Statistics v2.1                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_state

    local state_file="$STATE_DIR/state"
    local analyzed_file="$state_file/analyzed.json"
    local patterns_file="$state_file/patterns.json"
    local applied_file="$state_file/applied.json"
    local config_file="$state_file/config.json"

    # Engine version
    local engine_version="2.1.0"
    local state_version=$(has_jq && jq -r '.version // "unknown"' "$config_file" 2>/dev/null || echo "unknown")

    echo -e "${CYAN}Engine:${NC} v$engine_version | ${CYAN}State:${NC} v$state_version"
    echo ""

    # Conversations section
    if [ -f "$analyzed_file" ] && has_jq; then
        local total=$(jq '.conversations | length' "$analyzed_file" 2>/dev/null || echo "0")
        local complete=$(jq '[.conversations[] | select(.status == "complete")] | length' "$analyzed_file" 2>/dev/null || echo "0")
        local by_tier=$(jq '[.conversations[] | select(.status == "complete") | .tier // "unknown"] | group_by(.) | map({tier: .[0], count: length})' "$analyzed_file" 2>/dev/null || echo "[]")

        echo -e "${CYAN}📁 Conversations${NC}"
        echo -e "   ├─ Total tracked: $total"
        echo -e "   ├─ Complete: $complete"
        echo -e "   └─ Engine: v$engine_version"

        # Show tier breakdown
        if [ "$total" -gt 0 ]; then
            echo ""
            echo "   Tier breakdown:"
            local gate_count=$(jq '[.conversations[] | select(.tier == "gate")] | length' "$analyzed_file" 2>/dev/null || echo "0")
            local periodic_count=$(jq '[.conversations[] | select(.tier == "periodic")] | length' "$analyzed_file" 2>/dev/null || echo "0")
            echo -e "   ├─ Gate: $gate_count"
            echo -e "   └─ Periodic: $periodic_count"
        fi
        echo ""
    fi

    # Patterns section
    if [ -f "$patterns_file" ] && has_jq; then
        local total=$(jq '.patterns | length' "$patterns_file" 2>/dev/null || echo "0")
        local pending=$(jq '[.patterns[] | select(.status == "pending")] | length' "$patterns_file" 2>/dev/null || echo "0")
        local suggested=$(jq '[.patterns[] | select(.status == "suggested")] | length' "$patterns_file" 2>/dev/null || echo "0")
        local applied_count=$(jq '[.patterns[] | select(.status == "applied")] | length' "$patterns_file" 2>/dev/null || echo "0")

        echo -e "${CYAN}🔍 Patterns${NC}"
        echo -e "   ├─ Total unique: $total"
        echo -e "   ├─ Pending: $pending"
        echo -e "   ├─ Suggested: $suggested"
        echo -e "   └─ Applied: $applied_count"
        echo ""

        # Top patterns by frequency
        if [ "$total" -gt 0 ]; then
            echo -e "   ${CYAN}Top Patterns by Frequency:${NC}"
            jq -r '.patterns | to_entries | sort_by(-.value.frequency) | .[0:5] | .[] |
                "   \(.value.frequency)x | \(.key) [\(.value.severity // "medium")]"' \
                "$patterns_file" 2>/dev/null | while read -r line; do
                echo -e "   $line"
            done || echo "   (none)"
            echo ""
        fi

        # Severity breakdown
        local high=$(jq '[.patterns[] | select(.severity == "high")] | length' "$patterns_file" 2>/dev/null || echo "0")
        local medium=$(jq '[.patterns[] | select(.severity == "medium")] | length' "$patterns_file" 2>/dev/null || echo "0")
        local info=$(jq '[.patterns[] | select(.severity == "info")] | length' "$patterns_file" 2>/dev/null || echo "0")

        if [ "$total" -gt 0 ]; then
            echo -e "   ${CYAN}Severity:${NC}"
            echo -e "   ├─ 🔴 High: $high"
            echo -e "   ├─ 🟡 Medium: $medium"
            echo -e "   └─ 🟢 Info: $info"
            echo ""
        fi
    fi

    # Applied fixes section
    if [ -f "$applied_file" ] && has_jq; then
        local total=$(jq '.applied | length' "$applied_file" 2>/dev/null || echo "0")
        echo -e "${CYAN}✅ Applied Fixes: $total${NC}"
        echo ""

        # Recent applications
        if [ "$total" -gt 0 ]; then
            echo -e "   ${CYAN}Recent Applications:${NC}"
            jq -r '.applied | to_entries | sort_by(-.value.applied_at) | .[0:3] | .[] |
                "   - \(.key) (\(.value.applied_at | split("T")[0]))"' \
                "$applied_file" 2>/dev/null | while read -r line; do
                echo -e "   $line"
            done
            echo ""
        fi
    fi

    # Git integration status
    if [ -d ".git" ] || git rev-parse --git-dir &>/dev/null 2>&1; then
        local claude_changes=$(git log --oneline --all --since="30 days ago" -- "*CLAUDE.md" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "${CYAN}📦 Git Integration${NC}"
        echo -e "   └─ CLAUDE.md commits (30 days): $claude_changes"
        echo ""
    fi

    # Telemetry
    if [ -f "$ANALYTICS_DIR/self-improvement.jsonl" ]; then
        local events=$(wc -l < "$ANALYTICS_DIR/self-improvement.jsonl" 2>/dev/null || echo "0")
        local last_event=$(tail -1 "$ANALYTICS_DIR/self-improvement.jsonl" 2>/dev/null | jq -r '.timestamp // "unknown"' 2>/dev/null || echo "unknown")
        echo -e "${CYAN}📊 Telemetry${NC}"
        echo -e "   ├─ Events logged: $events"
        echo -e "   └─ Last event: $last_event"
        echo ""
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# Audit Command
# ============================================================================

cmd_audit() {
    local lines="${1:-50}"
    local audit_log="$STATE_DIR/audit/log.md"

    check_state

    if [ -f "$audit_log" ]; then
        echo ""
        echo -e "${CYAN}=== Last $lines Audit Log Entries ===${NC}"
        echo ""
        tail -n "$lines" "$audit_log"
    else
        echo "No audit log found."
    fi
}

# ============================================================================
# Telemetry Command
# ============================================================================

cmd_telemetry() {
    local analytics_file="$ANALYTICS_DIR/self-improvement.jsonl"

    if [ ! -f "$analytics_file" ]; then
        echo "No telemetry data found."
        return
    fi

    echo ""
    echo -e "${CYAN}=== Telemetry Summary ===${NC}"
    echo ""

    local total_events=$(wc -l < "$analytics_file" 2>/dev/null || echo "0")
    echo "Total events: $total_events"
    echo ""

    if has_jq; then
        echo "Events by type:"
        jq -r '.event' "$analytics_file" 2>/dev/null | sort | uniq -c | sort -rn | while read -r count type; do
            echo "  $count - $type"
        done
        echo ""

        echo "Recent runs:"
        jq -r 'select(.event == "engine_complete") | "\(.data.patterns // 0) patterns, \(.data.conversations // 0) convs - \(.timestamp | split("T")[0])"' \
            "$analytics_file" 2>/dev/null | head -5 | while read -r line; do
            echo "  $line"
        done
    fi
}

# ============================================================================
# Clear Command
# ============================================================================

cmd_clear() {
    echo ""
    echo -e "${RED}⚠️  DANGER: This will reset ALL self-improvement state.${NC}"
    echo ""
    echo "The following will be DELETED:"
    echo "  - $STATE_DIR/state/*.json"
    echo "  - $STATE_DIR/audit/log.md"
    echo "  - $STATE_DIR/audit/diffs/*"
    echo "  - $ANALYTICS_DIR/self-improvement.jsonl (optional)"
    echo ""
    read -p "Type 'yes' to confirm deletion: " confirm

    if [ "$confirm" = "yes" ]; then
        rm -rf "$STATE_DIR/state" "$STATE_DIR/audit/log.md" "$STATE_DIR/audit/diffs"
        rm -f "$ANALYTICS_DIR/self-improvement.jsonl" 2>/dev/null

        echo -e "${GREEN}✓ State cleared${NC}"
        echo ""
        echo "Run /self-improvement to start fresh."
    else
        echo "Aborted."
    fi
}

# ============================================================================
# Git Command
# ============================================================================

cmd_git() {
    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        echo "Not a git repository. Git integration unavailable."
        return
    fi

    check_state

    echo ""
    echo -e "${CYAN}=== Git Integration Status ===${NC}"
    echo ""

    # Applied patterns with git tracking
    local applied_file="$STATE_DIR/state/applied.json"
    if [ -f "$applied_file" ] && has_jq; then
        local count=$(jq '.applied | length' "$applied_file" 2>/dev/null || echo "0")
        echo "Applied patterns: $count"

        if [ "$count" -gt 0 ]; then
            echo ""
            jq -r '.applied | to_entries[] |
                "\(.key) | commit:\(.value.git_commit // "none") | applied:\(.value.applied_at | split("T")[0])"' \
                "$applied_file" 2>/dev/null | while IFS='|' read -r pattern commit applied; do
                echo "  $pattern"
                echo "    └─ commit: $commit, applied: $applied"
            done
        fi
    fi

    echo ""
    echo "Recent CLAUDE.md changes:"
    git log --oneline -10 -- "*CLAUDE.md" 2>/dev/null || echo "  No CLAUDE.md in git history"
}

# ============================================================================
# Patterns Command
# ============================================================================

cmd_patterns() {
    check_state

    local patterns_file="$STATE_DIR/state/patterns.json"

    if [ ! -f "$patterns_file" ]; then
        echo "No patterns found."
        return
    fi

    echo ""
    echo -e "${CYAN}=== All Patterns ===${NC}"
    echo ""

    if has_jq; then
        jq -r '.patterns | to_entries[] |
            "[\(.value.severity // "?")] \(.value.frequency)x | \(.key)\n" +
            "       \(.value.description // "")\n" +
            "       Status: \(.value.status // "pending") | Last seen: \(.value.last_seen // "unknown" | split("T")[0])\n"' \
            "$patterns_file" 2>/dev/null | while read -r line; do
            echo "$line"
        done
    fi
}

# ============================================================================
# Main
# ============================================================================

usage() {
    cat << 'EOF'
Self-Improvement State Manager v2.1

Usage: states.sh <command>

Commands:
    stats          Show statistics (default)
    audit [N]      Show last N audit log entries (default: 50)
    telemetry      Show telemetry summary
    patterns       Show all tracked patterns
    git            Show git integration status
    clear          Reset all state (requires confirmation)
    help           Show this help

Examples:
    states.sh stats
    states.sh audit 20
    states.sh telemetry
    states.sh clear
EOF
}

COMMAND="${1:-stats}"
shift 2>/dev/null

case "$COMMAND" in
    stats|--stats|-s) cmd_stats ;;
    audit|--audit|-a) cmd_audit "$@" ;;
    telemetry|--telemetry|-t) cmd_telemetry ;;
    patterns|--patterns|-p) cmd_patterns ;;
    git|--git|-g) cmd_git ;;
    clear|--clear|-c) cmd_clear ;;
    help|--help|-h) usage ;;
    *) usage ;;
esac