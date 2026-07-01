#!/bin/bash
# Similarity Matcher Plugin
# Fuzzy matching using string similarity

PLUGIN_NAME="similarity"
PLUGIN_VERSION="1.0.0"
PLUGIN_TYPE="matcher"

# Calculate Levenshtein distance (simplified)
levenshtein() {
    local s1="$1"
    local s2="$2"

    # Simple bash implementation for short strings
    if [ ${#s1} -eq 0 ]; then echo ${#s2}; return; fi
    if [ ${#s2} -eq 0 ]; then echo ${#s1}; return; fi

    if [ "$s1" = "$s2" ]; then
        echo 0
        return
    fi

    local diff=$(diff <(echo "$s1" | fold -w1) <(echo "$s2" | fold -w1) 2>/dev/null | grep "^<" | wc -l)
    echo $((diff + 1))
}

# Calculate similarity score (0-1)
similarity_score() {
    local s1="$1"
    local s2="$2"

    local len1=${#s1}
    local len2=${#s2}

    if [ $len1 -eq 0 ] && [ $len2 -eq 0 ]; then
        echo 1
        return
    fi

    local distance=$(levenshtein "$s1" "$s2")
    local max_len=$((len1 > len2 ? len1 : len2))

    local score=$(echo "scale=2; 1 - ($distance / $max_len)" | bc 2>/dev/null || echo "0")
    echo "$score"
}

# Find similar pattern
find_similar() {
    local pattern="$1"
    local patterns_json="$2"
    local threshold="${3:-0.6}"

    local pattern_title=$(echo "$pattern" | jq -r '.title // empty')
    local pattern_desc=$(echo "$pattern" | jq -r '.description // empty')

    local all_patterns=$(echo "$patterns_json" | jq -r '.patterns | to_entries[]')

    local best_match=""
    local best_score=0

    while IFS= read -r entry; do
        [ -z "$entry" ] && continue

        local existing_id=$(echo "$entry" | jq -r '.key')
        local existing_title=$(echo "$entry" | jq -r '.value.title // empty')
        local existing_desc=$(echo "$entry" | jq -r '.value.description // empty')

        # Compare titles
        local title_score=$(similarity_score "$pattern_title" "$existing_title")

        # Compare descriptions
        local desc_score=$(similarity_score "$pattern_desc" "$existing_desc")

        # Use better score
        local score=$(echo "$title_score $desc_score" | awk '{print ($1 > $2 ? $1 : $2)}')

        if (( $(echo "$score > $best_score" | bc -l 2>/dev/null || echo "0") )); then
            best_score=$score
            best_match=$existing_id
        fi
    done <<< "$all_patterns"

    # Check if above threshold
    if (( $(echo "$best_score >= $threshold" | bc -l 2>/dev/null || echo "0") )); then
        echo "$best_match"
        return 0
    fi

    return 1
}

export -f similarity_score find_similar 2>/dev/null || true