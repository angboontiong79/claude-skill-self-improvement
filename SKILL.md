---
name: self-improvement
description: Analyze conversation history to find friction patterns and suggest CLAUDE.md/skill improvements. Use when user wants to review what went wrong across sessions and systematically improve. (user)
allowed-tools: Read, Bash, Grep, Glob, Task, Write, Edit, Monitor, WebFetch
---

# Self-Improvement System v2.1

A modular, extensible self-improvement system for Claude Code that analyzes conversations, detects friction patterns, and suggests CLAUDE.md improvements. Features loop prevention, state tracking, two-tier analysis, telemetry, and Git integration.

## Quick Start

```bash
/self-improvement              # Fast gate-tier analysis
/self-improvement --tier periodic  # Deep analysis (weekly/monthly)
/self-improvement --stats      # Show statistics
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SELF-IMPROVEMENT v2.1                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                   │
│  │   Config    │────▶│   Telemetry │◀────│    Engine   │                   │
│  │   Loader    │     │    Event    │     │   Pipeline  │                   │
│  └─────────────┘     └─────────────┘     └─────────────┘                   │
│         │                   │                    │                          │
│         ▼                   ▼                    ▼                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      TWO-TIER PIPELINE                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  TIER    │  ANALYZERS              │  MAX CONV  │  WHEN              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  gate    │  friction, context      │  10        │  Every run         │   │
│  │  periodic│  friction, success,     │  50        │  Weekly/monthly    │   │
│  │          │  context, semantic      │            │                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      LOOP PREVENTION                                 │   │
│  │  1. analyzed.json - Skip already-analyzed conversations              │   │
│  │  2. patterns.json - Deduplicate pattern detection                    │   │
│  │  3. applied.json  - Never suggest what's already fixed               │   │
│  │  4. Git history   - Check CLAUDE.md git log/blame                    │   │
│  │  5. State archival - Move old records to quarterly archive           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## State Directory Structure

```
~/.claude/projects/self-improvement/
├── state/
│   ├── analyzed.json       # Conversation tracking (v2.1)
│   ├── patterns.json       # Pattern library with severity
│   ├── applied.json        # Applied fixes with git links
│   └── config.json         # User preferences (v2.1)
├── audit/
│   ├── log.md              # Chronological audit
│   ├── archived_*.json     # Quarterly archival
│   └── diffs/              # Diff snapshots
└── output/                 # Generated outputs
    └── CLAUDE_IMPROVEMENTS_YYYYMMDD_HHMMSS.md
```

## Two-Tier System

### Gate Tier (Default)
- **When**: Every run
- **Analyzers**: friction, context
- **Max conversations**: 10
- **Purpose**: Quick feedback, basic pattern detection

### Periodic Tier
- **When**: Weekly/monthly or `--tier periodic`
- **Analyzers**: friction, success, context, semantic
- **Max conversations**: 50
- **Purpose**: Deep analysis, cross-pattern correlation, success patterns

## Phase Pipeline

### Phase 0: Initialize
```bash
# 1. Create/validate state directory
# 2. Check state version, migrate if needed
# 3. Load all state files
# 4. Initialize telemetry
# 5. Show proactive hints based on state
```

### Phase 1: Discover
```bash
# 1. Find .jsonl conversations
# 2. Filter: skip already-analyzed (unless --force)
# 3. Apply tier-specific limits
# 4. Diff-based selection (optional, if git available)
```

### Phase 2: Analyze
```bash
# For each conversation:
#   - Run tier-specific analyzers
#   - Extract friction, success, context, semantic patterns
#   - Store results in ANALYSIS_RESULTS
#   - Mark conversation as analyzed
```

### Phase 3: Synthesize
```bash
# 1. Aggregate patterns across conversations
# 2. Deduplicate against patterns.json
# 3. Calculate frequency and severity
# 4. Filter against applied.json
# 5. Update patterns state
```

### Phase 4: Output
```bash
# Generate timestamped markdown with:
#   - Summary table
#   - Severity legend (🔴🟡🟢)
#   - New issues with suggested fixes
#   - Already applied patterns
#   - Known patterns with frequency
#   - Audit trail
```

### Phase 5: Git Integration
```bash
# 1. Show recent CLAUDE.md commits
# 2. Check for uncommitted changes
# 3. Link applied patterns to git commits
```

### Phase 6: Archive (Monthly)
```bash
# 1. Archive conversations older than 90 days
# 2. Move to audit/archived_YYYYMM.json
# 3. Compact active analyzed.json
```

## Telemetry

Track improvement cycles in `~/.gstack/analytics/self-improvement.jsonl`:

```json
{"event":"engine_start","timestamp":"...","run_id":"...","data":{"version":"2.1.0","tier":"gate"}}
{"event":"discover","timestamp":"...","data":{"total":50,"selected":10,"skipped":40}}
{"event":"analyze","timestamp":"...","data":{"conversations":10,"friction":15,"success":3}}
{"event":"synthesize","timestamp":"...","data":{"total":5,"pending":3,"skipped_applied":2}}
{"event":"engine_complete","timestamp":"...","data":{"patterns":3,"conversations":10}}
```

## Usage

```bash
/self-improvement                    # Normal gate-tier run
/self-improvement --tier periodic    # Deep analysis
/self-improvement --tier auto        # Auto-detect (Monday = periodic)
/self-improvement --force            # Re-analyze everything
/self-improvement --dry-run          # Analyze without saving
/self-improvement --stats            # Show statistics
/self-improvement --archive          # Force archival
```

## Scripts

```bash
# State management
~/.claude/skills/self-improvement/states.sh stats      # Show statistics
~/.claude/skills/self-improvement/states.sh audit 20   # Last 20 audit entries
~/.claude/skills/self-improvement/states.sh telemetry  # Telemetry summary
~/.claude/skills/self-improvement/states.sh patterns   # All patterns
~/.claude/skills/self-improvement/states.sh git        # Git integration
~/.claude/skills/self-improvement/states.sh clear      # Reset state

# Git integration
~/.claude/skills/self-improvement/git-integration.sh history 10
~/.claude/skills/self-improvement/git-integration.sh apply <pattern_id>
~/.claude/skills/self-improvement/git-integration.sh blame <pattern_id>
```

## Plugin System

### Analyzers
| Plugin | Tier | Purpose |
|--------|------|---------|
| `friction.sh` | both | Detect friction keywords |
| `success.sh` | periodic | Detect success patterns |
| `context.sh` | both | Extract context and intent |
| `semantic.sh` | periodic | Deep semantic analysis |

### Matchers
| Plugin | Purpose |
|--------|---------|
| `frequency.sh` | Match by keyword frequency |
| `similarity.sh` | Fuzzy string matching |

### Formatters
| Plugin | Purpose |
|--------|---------|
| `markdown.sh` | Markdown output |

### Hooks
| Plugin | When |
|--------|------|
| `beforeAnalyze.sh` | Before each conversation |
| `afterAnalyze.sh` | After each conversation |
| `onPatternDetected.sh` | When pattern detected |

## State File Schemas

### analyzed.json
```json
{
  "version": "2.1.0",
  "conversations": {
    "<filename.jsonl>": {
      "analyzed_at": "ISO8601",
      "status": "complete",
      "summary": "Brief description",
      "patterns_found": 3,
      "tier": "gate|periodic",
      "run_id": "run_YYYYMMDD_HHMMSS"
    }
  }
}
```

### patterns.json
```json
{
  "version": "2.1.0",
  "patterns": {
    "<pattern_id>": {
      "id": "pattern_id",
      "title": "Human readable title",
      "description": "What this pattern is about",
      "frequency": 5,
      "severity": "high|medium|info",
      "status": "pending|suggested|applied|rejected",
      "first_seen": "ISO8601",
      "last_seen": "ISO8601",
      "tier": "gate|periodic",
      "evidence": []
    }
  }
}
```

### applied.json
```json
{
  "version": "2.1.0",
  "applied": {
    "<pattern_id>": {
      "pattern_id": "...",
      "applied_at": "ISO8601",
      "source_file": "CLAUDE_IMPROVEMENTS_*.md",
      "location": "/path/to/file",
      "git_commit": "sha or null",
      "user_confirmed": true
    }
  }
}
```

## Loop Prevention Rules

1. **Never re-analyze** - Check `analyzed.json` status before processing
2. **Never re-detect** - Pattern ID deduplication in merge phase
3. **Never re-suggest** - Check `applied.json` before including in output
4. **Never re-commit** - Track git commits in applied.json
5. **Archive old state** - Quarterly archival prevents unbounded growth
6. **State versioning** - Automatic migration on version mismatch

## Severity Levels

| Level | Icon | Meaning | Action |
|-------|------|---------|--------|
| High | 🔴 | User frustrated, immediate attention | Fix soon |
| Medium | 🟡 | Repeated friction | Add guidance |
| Info | 🟢 | Good patterns to document | Replicate |

## Output Format

Generates `CLAUDE_IMPROVEMENTS_YYYYMMDD_HHMMSS.md`:

```markdown
# CLAUDE.md Improvement Suggestions

| **Generated:** | 2024-07-01T10:30:00Z |
| **Run ID:** | run_20240701_103000_123 |
| **Tier:** | gate |

---

## Summary
| Metric | Count |
|--------|-------|
| Conversations analyzed | 10 |
| Patterns detected | 5 |
| New suggestions | 3 |

---

## Severity Legend
- 🔴 High - User is frustrated, needs immediate attention
- 🟡 Medium - Repeated friction, consider adding guidance
- 🟢 Info - Good patterns to document/replicate

---

## New Issues Found

### 1. 🔴 Repeated Commands (seen 3 times)

**Pattern ID:** `repeated-commands`
**Severity:** high

**Problem:** User running same commands multiple times...

**Status:** ⏳ Pending review

---

## Audit Trail
```
Run ID: run_20240701_103000_123
Timestamp: 2024-07-01T10:30:00Z
Tier: gate
```
```

## Extending

### Adding a New Analyzer
```bash
# plugins/analyzers/my-analyzer.sh
#!/bin/bash
PLUGIN_NAME="my-analyzer"
PLUGIN_TYPE="analyzer"

analyze_my_pattern() {
    local content="$1"
    local file="$2"
    # Your analysis logic
    jq -n '{plugin: $name, file: $file, ...}'
}

export -f analyze_my_pattern
```

### Adding to Config
Update `state/config.json` to include your analyzer:
```json
{
  "two_tier": {
    "periodic": {
      "analyzers": ["friction", "success", "context", "semantic", "my-analyzer"]
    }
  }
}
```

## Installation

```bash
git clone <repo> ~/.claude/skills/self-improvement
```