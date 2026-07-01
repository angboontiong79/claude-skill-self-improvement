#!/bin/bash
# After Analyze Hook Template
# Run after analyzing each conversation

# This hook is called after analyzing a conversation.
# Use it to:
# - Post-process analysis results
# - Trigger side effects
# - Update external systems

# Parameters:
#   $1 - conversation file path
#   $2 - analysis result JSON
#   $3 - run ID

HOOK_NAME="afterAnalyze"
HOOK_VERSION="1.0.0"

after_analyze_hook() {
    local file="$1"
    local result="$2"
    local run_id="$3"

    # Example: Log the completion
    # local patterns_found=$(echo "$result" | jq '.patterns | length')
    # audit_log "HOOK:AFTER" "FILE:$file | PATTERNS:$patterns_found | RUN:$run_id"

    # Example: Send notification if high friction
    # local friction=$(echo "$result" | jq '.friction_count // 0')
    # if [ "$friction" -gt 5 ]; then
    #     send_notification "High friction detected: $friction points in $file"
    # fi

    return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    after_analyze_hook "$1" "$2" "$3"
fi

export -f after_analyze_hook 2>/dev/null || true