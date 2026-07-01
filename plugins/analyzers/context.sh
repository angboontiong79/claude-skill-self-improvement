#!/bin/bash
# Context Analyzer Plugin
# Extracts context about what the user was trying to accomplish

# Plugin metadata
PLUGIN_NAME="context"
PLUGIN_VERSION="1.0.0"
PLUGIN_TYPE="analyzer"

CONTEXT_PATTERNS=(
    "trying to"
    "want to"
    "need to"
    "need a"
    "looking for"
    "attempting"
    "trying"
    "build"
    "create"
    "implement"
    "fix"
    "update"
    "migrate"
    "setup"
    "configure"
    "deploy"
    "test"
    "debug"
)

analyze_context() {
    local content="$1"
    local file="$2"

    local user_messages=""
    local context_items=()

    # Extract user messages
    user_messages=$(echo "$content" | jq -r '.[] | select(.type == "user") | .content' 2>/dev/null | head -10 || echo "")

    # Find context items (first user messages often describe intent)
    for msg in $user_messages; do
        for pattern in "${CONTEXT_PATTERNS[@]}"; do
            if echo "$msg" | grep -qiE "$pattern"; then
                # Extract a clean version
                clean=$(echo "$msg" | sed -E 's/^(user:|Human:|)//' | cut -c1-200 | xargs)
                if [ -n "$clean" ] && [ ${#clean} -gt 10 ]; then
                    context_items+=("$clean")
                    break
                fi
            fi
        done
    done

    # Count turns
    local total_turns=$(echo "$content" | jq 'length' 2>/dev/null || echo 0)
    local user_turns=$(echo "$content" | jq '[.[] | select(.type == "user")] | length' 2>/dev/null || echo 0)
    local assistant_turns=$(echo "$content" | jq '[.[] | select(.type == "assistant")] | length' 2>/dev/null || echo 0)

    # Detect project type (simple heuristic)
    local project_type="unknown"
    if echo "$content" | grep -qiE "(react|vue|angular|component|jsx)"; then
        project_type="frontend"
    elif echo "$content" | grep -qiE "(python|django|flask|fastapi)"; then
        project_type="backend"
    elif echo "$content" | grep -qiE "(docker|kubernetes|k8s|container)"; then
        project_type="devops"
    elif echo "$content" | grep -qiE "(git|commit|push|pull|branch)"; then
        project_type="vcs"
    fi

    # Return JSON result
    jq -n \
        --arg plugin "$PLUGIN_NAME" \
        --arg file "$file" \
        --argjson total_turns "$total_turns" \
        --argjson user_turns "$user_turns" \
        --argjson assistant_turns "$assistant_turns" \
        --arg project_type "$project_type" \
        --argjson context_items "$(printf '%s\n' "${context_items[@]}" | jq -R . | jq -s .)" \
        '{
            plugin: $plugin,
            file: $file,
            total_turns: $total_turns,
            user_turns: $user_turns,
            assistant_turns: $assistant_turns,
            project_type: $project_type,
            context_items: $context_items,
            timestamp: now
        }'
}

export -f analyze_context 2>/dev/null || true