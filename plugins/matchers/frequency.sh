#!/bin/bash
# Frequency Matcher Plugin
# Matches patterns based on frequency and similarity

PLUGIN_NAME="frequency"
PLUGIN_VERSION="1.0.0"
PLUGIN_TYPE="matcher"

# Load patterns from state
load_patterns() {
    local state_dir="$1"
    if [ -f "$state_dir/state/patterns.json" ]; then
        cat "$state_dir/state/patterns.json"
    else
        echo '{"patterns":{}}'
    fi
}

# Find matching pattern by keywords
find_match() {
    local new_pattern="$1"
    local patterns_json="$2"
    local threshold="${3:-0.7}"

    local new_id=$(echo "$new_pattern" | jq -r '.id // empty')
    local new_keywords=$(echo "$new_pattern" | jq -r '.keywords // [] | .[]' 2>/dev/null | tr '\n' ' ')

    # Check existing patterns
    local matches=$(echo "$patterns_json" | jq --arg keywords "$new_keywords" \
        '.patterns | to_entries[] | select(.value.keywords // [] | map(. + " ") | join("") | test($keywords; "i"))' 2>/dev/null)

    if [ -n "$matches" ]; then
        local match_id=$(echo "$matches" | jq -r '.key')
        local match_freq=$(echo "$matches" | jq -r '.value.frequency // 1')
        echo "$match_id"
        return 0
    fi

    # Also check by ID similarity
    local all_ids=$(echo "$patterns_json" | jq -r '.patterns | keys[]')
    for existing_id in $all_ids; do
        # Simple string similarity
        if [[ "$new_id" == *"$existing_id"* ]] || [[ "$existing_id" == *"$new_id"* ]]; then
            echo "$existing_id"
            return 0
        fi
    done

    return 1
}

# Update pattern frequency
increment_frequency() {
    local pattern_id="$1"
    local state_dir="$2"

    local patterns_file="$state_dir/state/patterns.json"

    if [ ! -f "$patterns_file" ]; then
        return 1
    fi

    jq --arg id "$pattern_id" \
       'if .patterns[$id] then
            .patterns[$id].frequency = (.patterns[$id].frequency // 0) + 1
        else
            .
        end' "$patterns_file" > "${patterns_file}.tmp" && \
        mv "${patterns_file}.tmp" "$patterns_file"
}

export -f find_match increment_frequency load_patterns 2>/dev/null || true