#!/bin/bash
# Success Analyzer Plugin
# Detects what worked well in conversations

# Plugin metadata
PLUGIN_NAME="success"
PLUGIN_VERSION="1.0.0"
PLUGIN_TYPE="analyzer"

SUCCESS_PATTERNS=(
    "perfect"
    "great"
    "thanks"
    "thank you"
    "worked"
    "excellent"
    "awesome"
    "nice"
    "love it"
    "that.*works"
    "exactly"
    "ideal"
    "solved"
)

analyze_success() {
    local content="$1"
    local file="$2"

    local user_messages=""
    local success_count=0
    local praise_count=0

    # Extract user messages
    user_messages=$(echo "$content" | jq -r '.[] | select(.type == "user") | .content' 2>/dev/null || echo "")

    # Count success patterns
    for pattern in "${SUCCESS_PATTERNS[@]}"; do
        count=$(echo "$user_messages" | grep -ciE "$pattern" || echo 0)
        success_count=$((success_count + count))
    done

    # Count praise (thank*, great!, perfect)
    praise_count=$(echo "$user_messages" | grep -ciE "^(thanks|thank you|great|perfect|excellent)" || echo 0)

    # Extract positive quotes
    local quotes=$(echo "$user_messages" | grep -iE "$(IFS='|'; echo "${SUCCESS_PATTERNS[*]}")" | head -5 || echo "")

    # Return JSON result
    jq -n \
        --arg plugin "$PLUGIN_NAME" \
        --arg file "$file" \
        --argjson success_count "$success_count" \
        --argjson praise_count "$praise_count" \
        --arg quotes "$quotes" \
        '{
            plugin: $plugin,
            file: $file,
            success_count: $success_count,
            praise_count: $praise_count,
            quotes: ($quotes | split("\n") | map(select(length > 0))),
            timestamp: now
        }'
}

export -f analyze_success 2>/dev/null || true