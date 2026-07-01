#!/bin/bash
# Semantic Friction Analyzer Plugin
# Detects deep friction patterns using semantic context

PLUGIN_NAME="semantic"
PLUGIN_VERSION="1.0.0"
PLUGIN_TYPE="analyzer"

# Semantic patterns that indicate deeper issues
SEMANTIC_PATTERNS=(
    # Repetition indicators
    "same.*(error|issue|problem|thing|command|file)"
    "again"
    "still.*(not|working|fix)"
    "another.*time"
    "repeated"
    "repetitive"

    # Systemic frustration
    "why.*always"
    "every time"
    "constantly"
    "never.*works"
    "never.*right"

    # Exhaustion
    "tried.*everything"
    "i've tried all"
    "nothing.*works"
    "spent.*hours?"
    "exhausted"
    "give up"

    # Expectation mismatch
    "should.*work"
    "expected.*to"
    "thought.*would"
    "supposed to"

    # Confusion
    "don't understand"
    "confus"
    "lost"
    "overwhelm"

    # Requesting help differently
    "let me.*try"
    "what about.*instead"
    "can we.* differently"
)

# Confidence weights
declare -A WEIGHTS=(
    ["systemic"]=3
    ["exhaustion"]=4
    ["repetition"]=2
    ["confusion"]=2
    ["mismatch"]=2
)

analyze_semantic() {
    local content="$1"
    local file="$2"

    local user_messages=""
    local patterns_found=()

    # Extract user messages
    user_messages=$(echo "$content" | jq -r '.[] | select(.type == "user") | .content' 2>/dev/null || echo "")

    # Pattern matching
    local total_score=0
    local pattern_details="[]"

    for pattern in "${SEMANTIC_PATTERNS[@]}"; do
        count=$(echo "$user_messages" | grep -ciE "$pattern" || echo 0)
        if [ "$count" -gt 0 ]; then
            # Determine category
            category="repetition"
            case "$pattern" in
                *"why.*always"*|*":every time"*|*":constantly"*) category="systemic" ;;
                *"tried"*|*":exhausted"*|*":give up"*) category="exhaustion" ;;
                *"confus"*|*":overwhelm"*) category="confusion" ;;
                *"should"*|*":expected"*|*":supposed"*) category="mismatch" ;;
            esac

            weight=${WEIGHTS[$category]:-1}
            score=$((count * weight))

            total_score=$((total_score + score))

            # Extract matching quotes
            quotes=$(echo "$user_messages" | grep -iE "$pattern" | head -3 || echo "")

            pattern_details=$(echo "$pattern_details" | jq \
                --arg pattern "$pattern" \
                --arg category "$category" \
                --argjson count "$count" \
                --argjson weight "$weight" \
                --argjson score "$score" \
                --arg quotes "$quotes" \
                '. += [{
                    pattern: $pattern,
                    category: $category,
                    count: $count,
                    weight: $weight,
                    score: $score,
                    quotes: ($quotes | split("\n") | map(select(length > 0)))
                }]')

            patterns_found+=("$pattern (count: $count)")
        fi
    done

    # Determine severity
    severity="low"
    if [ "$total_score" -gt 10 ]; then
        severity="high"
    elif [ "$total_score" -gt 5 ]; then
        severity="medium"
    fi

    # Return JSON result
    jq -n \
        --arg plugin "$PLUGIN_NAME" \
        --arg file "$file" \
        --argjson total_score "$total_score" \
        --arg severity "$severity" \
        --argjson pattern_count "${#patterns_found[@]}" \
        --argjson details "$pattern_details" \
        '{
            plugin: $plugin,
            file: $file,
            semantic_score: $total_score,
            severity: $severity,
            pattern_count: $pattern_count,
            details: $details,
            timestamp: now
        }'
}

# Export for use
export -f analyze_semantic 2>/dev/null || true