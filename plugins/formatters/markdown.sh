#!/bin/bash
# Markdown Formatter Plugin
# Outputs improvement suggestions as Markdown

PLUGIN_NAME="markdown"
PLUGIN_VERSION="1.0.0"
PLUGIN_TYPE="formatter"
EXTENSION=".md"

format_output() {
    local run_id="$1"
    local patterns="$2"
    local config="$3"
    local analyses="$4"

    local timestamp=$(date -Iseconds)
    local project_path="${5:-$(pwd)}"

    cat << EOF
# CLAUDE.md Improvement Suggestions

**Generated:** $timestamp
**Run ID:** $run_id
**Project:** $project_path

---

## Summary

| Metric | Count |
|--------|-------|
| Conversations analyzed | $(echo "$analyses" | jq 'length') |
| Patterns detected | $(echo "$patterns" | jq 'length') |
| New suggestions | $(echo "$patterns" | jq 'length') |

---

## New Issues Found

EOF

    local num=1
    while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue

        local id=$(echo "$pattern" | jq -r '.id')
        local title=$(echo "$pattern" | jq -r '.title')
        local desc=$(echo "$pattern" | jq -r '.description')
        local freq=$(echo "$pattern" | jq -r '.frequency // 1')

        cat << EOF
### $num. $title (seen $freq times)

**Pattern ID:** \`$id\`

**Problem:** $desc

**Suggested fix:**

\`\`\`markdown
<!-- Add your improvement here -->
\`\`\`

**Status:** ⏳ Pending review

---
EOF
        ((num++))
    done < <(echo "$patterns" | jq -c '.[]')

    cat << EOF

## Already Applied

No patterns marked as applied yet.

---

## Audit Trail

- Run ID: $run_id
- Timestamp: $timestamp
- Project: $project_path

*This file was auto-generated. Review suggestions before applying.*
EOF
}

write_output() {
    local content="$1"
    local output_dir="$2"

    mkdir -p "$output_dir"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="CLAUDE_IMPROVEMENTS_${timestamp}.md"
    local filepath="$output_dir/$filename"

    echo "$content" > "$filepath"
    echo "$filepath"
}

export -f format_output write_output 2>/dev/null || true