#!/bin/bash
# Friction Analyzer Plugin
# Detects friction points in conversations

# Plugin metadata
PLUGIN_NAME="friction"
PLUGIN_VERSION="1.0.0"
PLUGIN_TYPE="analyzer"

# Friction indicators
declare -a FRICTION_PATTERNS=(
    "again"
    "repeat"
    "same"
    "already"
    "no work"
    "wrong"
    "broken"
    "fail"
    "error"
    "doesn't work"
    "still"
    "nothing"
    "help"
)

FRUSTRATION_PATTERNS=(
    "frustrat"
    "annoy"
    "terrible"
    "worst"
    "hate"
    "ugh"
    "why.*not"
    "spent.*hour"
    "waste"
    "ridiculous"
    "can't believe"
)

analyze_friction() {
    local content="$1"
    local file="$2"

    # Count friction indicators
    local friction_count=0
    local frustration_count=0
    local user_messages=""

    # Extract user messages
    user_messages=$(echo "$content" | jq -r '.[] | select(.type == "user") | .content' 2>/dev/null || echo "")

    # Count friction patterns
    for pattern in "${FRICTION_PATTERNS[@]}"; do
        count=$(echo "$user_messages" | grep -ciE "$pattern" || echo 0)
        friction_count=$((friction_count + count))
    done

    # Count frustration patterns
    for pattern in "${FRUSTRATION_PATTERNS[@]}"; do
        count=$(echo "$user_messages" | grep -ciE "$pattern" || echo 0)
        frustration_count=$((frustration_count + count))
    done

    # Extract sample quotes
    local quotes=$(echo "$user_messages" | grep -iE "$(IFS='|'; echo "${FRICTION_PATTERNS[*]}")" | head -5 || echo "")

    # Return JSON result
    jq -n \
        --arg plugin "$PLUGIN_NAME" \
        --arg file "$file" \
        --argjson friction_count "$friction_count" \
        --argjson frustration_count "$frustration_count" \
        --arg quotes "$quotes" \
        '{
            plugin: $plugin,
            file: $file,
            friction_count: $friction_count,
            frustration_count: $frustration_count,
            quotes: ($quotes | split("\n") | map(select(length > 0))),
            timestamp: now
        }'
}

# Export for use
export -f analyze_friction 2>/dev/null || true