#!/bin/bash
# Git Integration Helper for Self-Improvement
# Manages CLAUDE.md changes, blame tracking, and commit linking

STATE_DIR="$HOME/.claude/projects/self-improvement"
APPLIED_FILE="$STATE_DIR/state/applied.json"
AUDIT_DIFFS="$STATE_DIR/audit/diffs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  blame <pattern_id>    Show git blame for when a pattern was added"
    echo "  history [N]           Show last N CLAUDE.md commits"
    echo "  diff <commit>         Show diff for a specific commit"
    echo "  apply <pattern_id>    Record applying a pattern fix"
    echo "  unapply <pattern_id>  Mark a pattern as not applied"
    echo "  link <commit> <id>    Link a git commit to a pattern"
    echo ""
}

# Ensure we're in a git repo
check_git() {
    if ! git rev-parse --git-dir &>/dev/null; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        exit 1
    fi
}

# Ensure state directory exists
check_state() {
    if [ ! -d "$STATE_DIR" ]; then
        echo -e "${RED}Error: State directory not found. Run /self-improvement first.${NC}"
        exit 1
    fi
}

cmd_blame() {
    check_git
    check_state
    local pattern_id="$1"

    if [ -z "$pattern_id" ]; then
        echo "Error: Pattern ID required"
        exit 1
    fi

    # Find CLAUDE.md or .claude/CLAUDE.md
    local claude_file=""
    for f in "CLAUDE.md" ".claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"; do
        if [ -f "$f" ]; then
            claude_file="$f"
            break
        fi
    done

    if [ -z "$claude_file" ]; then
        echo "No CLAUDE.md found in project"
        exit 1
    fi

    # Get keywords from pattern for matching
    local keywords=$(jq -r ".patterns.\"$pattern_id\".keywords // [] | .[]" \
        "$STATE_DIR/state/patterns.json" 2>/dev/null)

    if [ -z "$keywords" ]; then
        echo "No keywords found for pattern: $pattern_id"
        echo "Trying basic grep..."
        git blame "$claude_file" 2>/dev/null | grep -i "$pattern_id" || \
            echo "Pattern not found in git history"
    else
        echo "Searching for keywords: $keywords"
        git blame "$claude_file" 2>/dev/null | grep -iE "$(echo $keywords | tr ' ' '|')" || \
            echo "Pattern keywords not found in git history"
    fi
}

cmd_history() {
    check_git
    local count="${1:-10}"

    echo "=== Last $count CLAUDE.md Changes ==="
    echo ""

    # Find CLAUDE.md in repo
    local claude_file=""
    for f in "CLAUDE.md" ".claude/CLAUDE.md"; do
        if [ -f "$f" ]; then
            claude_file="$f"
            break
        fi
    done

    if [ -z "$claude_file" ]; then
        echo "No CLAUDE.md found in current directory"
        echo ""
        echo "Checking recent commits with CLAUDE.md..."
        git log --oneline --all --since="90 days" --name-only | \
            grep -B1 "CLAUDE.md" | head -20
    else
        git log --oneline -"$count" -- "$claude_file"
    fi
}

cmd_diff() {
    check_git
    local commit="$1"

    if [ -z "$commit" ]; then
        echo "Error: Commit hash required"
        exit 1
    fi

    git show "$commit" --stat
    echo ""
    git show "$commit" -- .claude/ CLAUDE.md 2>/dev/null || \
        git show "$commit"
}

cmd_apply() {
    check_state
    local pattern_id="$1"

    if [ -z "$pattern_id" ]; then
        echo "Error: Pattern ID required"
        echo "Use: $0 apply <pattern_id>"
        exit 1
    fi

    # Get pattern info
    local pattern_title=$(jq -r ".patterns.\"$pattern_id\".title // \"Unknown\"" \
        "$STATE_DIR/state/patterns.json" 2>/dev/null)

    if [ "$pattern_title" = "Unknown" ]; then
        echo -e "${YELLOW}Warning: Pattern not found in patterns.json${NC}"
        read -p "Continue anyway? (y/N) " confirm
        [ "$confirm" != "y" ] && exit 0
    fi

    # Check git status
    check_git
    local git_commit=""
    if git diff --quiet; then
        echo "Git working tree is clean"
        read -p "Enter commit hash (or 'none'): " git_commit
    else
        echo -e "${YELLOW}Git working tree has changes${NC}"
        git status --short
        read -p "Enter commit hash after committing (or 'none'): " git_commit
    fi

    # Update applied.json
    local now=$(date -Iseconds)
    local output_file=$(ls -t "$STATE_DIR"/output/CLAUDE_IMPROVEMENTS_*.md 2>/dev/null | head -1)

    jq --arg id "$pattern_id" \
       --arg applied_at "$now" \
       --arg git_commit "$git_commit" \
       --arg location "$PWD/CLAUDE.md" \
       --arg source_file "${output_file:-unknown}" \
       --argjson user_confirmed true \
       '.applied[$id] = {
            "pattern_id": $id,
            "applied_at": $applied_at,
            "git_commit": $git_commit,
            "location": $location,
            "source_file": $source_file,
            "user_confirmed": $user_confirmed
        } | .updated_at = $applied_at' \
        "$STATE_DIR/state/applied.json" > "$STATE_DIR/state/applied.json.tmp" && \
        mv "$STATE_DIR/state/applied.json.tmp" "$STATE_DIR/state/applied.json"

    # Update patterns.json status
    jq --arg id "$pattern_id" \
       --arg applied_at "$now" \
       --arg git_commit "$git_commit" \
       '.patterns[$id].status = "applied" |
        .patterns[$id].applied_info = {
            "applied_at": $applied_at,
            "commit_hash": $git_commit
        } | .updated_at = $applied_at' \
        "$STATE_DIR/state/patterns.json" > "$STATE_DIR/state/patterns.json.tmp" && \
        mv "$STATE_DIR/state/patterns.json.tmp" "$STATE_DIR/state/patterns.json"

    # Log to audit
    {
        echo "[$(date -Iseconds)] | ACTION:APPLIED | PATTERN:$pattern_id | COMMIT:$git_commit"
    } >> "$STATE_DIR/audit/log.md"

    echo -e "${GREEN}✓ Applied: $pattern_id${NC}"
    echo "  Title: $pattern_title"
    echo "  At: $now"
    echo "  Commit: ${git_commit:-none}"
}

cmd_unapply() {
    check_state
    local pattern_id="$1"

    if [ -z "$pattern_id" ]; then
        echo "Error: Pattern ID required"
        exit 1
    fi

    jq --arg id "$pattern_id" \
       'del(.applied[$id]) | .updated_at = now | .applied[$id].status = "pending"' \
        "$STATE_DIR/state/applied.json" > "$STATE_DIR/state/applied.json.tmp" && \
        mv "$STATE_DIR/state/applied.json.tmp" "$STATE_DIR/state/applied.json"

    jq --arg id "$pattern_id" \
       '.patterns[$id].status = "pending" | del(.patterns[$id].applied_info) | .updated_at = now' \
        "$STATE_DIR/state/patterns.json" > "$STATE_DIR/state/patterns.json.tmp" && \
        mv "$STATE_DIR/state/patterns.json.tmp" "$STATE_DIR/state/patterns.json"

    {
        echo "[$(date -Iseconds)] | ACTION:UNAPPLIED | PATTERN:$pattern_id"
    } >> "$STATE_DIR/audit/log.md"

    echo -e "${YELLOW}✓ Unapplied: $pattern_id${NC}"
}

cmd_link() {
    check_state
    local commit="$1"
    local pattern_id="$2"

    if [ -z "$commit" ] || [ -z "$pattern_id" ]; then
        echo "Error: Both commit and pattern_id required"
        echo "Usage: $0 link <commit> <pattern_id>"
        exit 1
    fi

    # Verify commit exists
    if ! git cat-file -t "$commit" &>/dev/null; then
        echo -e "${RED}Error: Invalid commit hash: $commit${NC}"
        exit 1
    fi

    # Update applied.json
    jq --arg id "$pattern_id" \
       --arg commit "$commit" \
       --arg applied_at "$(date -Iseconds)" \
       '.applied[$id] += {
            "git_commit": $commit,
            "applied_at": $applied_at
        } | .updated_at = $applied_at' \
        "$STATE_DIR/state/applied.json" > "$STATE_DIR/state/applied.json.tmp" && \
        mv "$STATE_DIR/state/applied.json.tmp" "$STATE_DIR/state/applied.json"

    # Save diff snapshot
    mkdir -p "$AUDIT_DIFFS"
    git show "$commit" -- .claude/ CLAUDE.md > "$AUDIT_DIFFS/${pattern_id}_${commit:0:8}.diff" 2>/dev/null

    echo -e "${GREEN}✓ Linked pattern $pattern_id to commit $commit${NC}"
}

# Main
COMMAND="${1:-usage}"
shift 2>/dev/null

case "$COMMAND" in
    blame) cmd_blame "$@" ;;
    history) cmd_history "$@" ;;
    diff) cmd_diff "$@" ;;
    apply) cmd_apply "$@" ;;
    unapply) cmd_unapply "$@" ;;
    link) cmd_link "$@" ;;
    usage|--help|-h) usage ;;
    *) usage ;;
esac