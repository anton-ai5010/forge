#!/usr/bin/env bash
# maintain.sh — Periodic maintenance for Claude Code projects
#
# Runs in each discovered project directory (where .claude/ or CLAUDE.md exists):
#   1. Reindexes codebase-memory graph
#   2. Generates/updates Architecture section in CLAUDE.md
#   3. Cleans stale entries from MEMORY.md
#   4. Generates skill templates for recurring tasks
#   5. Manages agent definitions
#
# Respects per-project daily run limit (default: 1/day).
# Keeps a 10-day rolling log.
#
# Usage:
#   ~/.claude/maintain.sh [--max-daily N] [--dry-run] [--force] [--project DIR]
#
# Config: ~/.claude/maintain.conf (optional)
#
# ── How project discovery works ──────────────────────────────────────────────
#
# Claude Code stores per-project settings in ~/.claude/projects/<mangled-path>/
# The mangled path encodes the real filesystem path:
#   /mnt/9/gt/myproject → -mnt-9-gt-myproject
# (leading / → leading -, all / → -)
#
# Discovery algorithm:
#   1. List all subdirs of ~/.claude/projects/
#   2. Decode each mangled dirname back to a real path using greedy filesystem
#      walk. Naive sed 's/-/\//g' fails because dir names can contain dashes
#      (e.g. "rig-support" would wrongly become "rig/support").
#      Instead: split on dashes, then greedily match longest existing directory
#      at each level. Example:
#        -mnt-9-gt-rig-support-messages-assistent-mayor-rig
#        → try /mnt → exists ✓
#        → try /mnt/9 → exists ✓
#        → try /mnt/9/gt → exists ✓
#        → try /mnt/9/gt/rig-support-messages-assistent-mayor-rig → no
#        → try /mnt/9/gt/rig-support-messages-assistent-mayor → no
#        → ... (shrink) ...
#        → try /mnt/9/gt/rig_support_messages_assistent → wait, dashes ≠ underscores
#      NOTE: Claude Code encodes / as -, but _ stays _. So "rig_support" in
#      the dirname would contain _ not -. The greedy walk handles this correctly
#      because it only splits on -.
#   3. Check that the decoded path exists on disk
#   4. Check that it looks like a code project (has CLAUDE.md, *.py, src/,
#      package.json, Cargo.toml, or go.mod)
#   5. Deduplicate and sort
#
# This means the script ONLY processes directories where claude has already
# been used (has a ~/.claude/projects/ entry). It does NOT scan the entire
# filesystem. A project appears here because a human ran `claude` in that
# directory at least once.
#
# ── Exclude / Include logic ──────────────────────────────────────────────────
#
# EXCLUDE_DIRS: array of path prefixes to skip. A project is excluded if its
# path starts with any entry. Example: EXCLUDE_DIRS=("/mnt/9/gt") skips
# /mnt/9/gt, /mnt/9/gt/foo, /mnt/9/gt/foo/bar/baz — everything under it.
#
# INCLUDE_DIRS: array of specific paths that OVERRIDE exclusions. Checked
# BEFORE exclude. Example:
#   EXCLUDE_DIRS=("/mnt/9/gt")
#   INCLUDE_DIRS=("/mnt/9/gt/rig_support_messages_assistent/mayor/rig")
# Result: everything under /mnt/9/gt is skipped EXCEPT that one project.
#
# Priority: INCLUDE_DIRS > EXCLUDE_DIRS (include wins over exclude).
# Include checks exact match and prefix match, same as exclude.
#

set -euo pipefail

# ── Constants ───────────────────────────────────────────────────────────────
SCRIPT_NAME="claude-maintain"
CLAUDE_DIR="$HOME/.claude"
LOG_DIR="$CLAUDE_DIR/maintain-logs"
STATE_DIR="$CLAUDE_DIR/maintain-state"
CONF_FILE="$CLAUDE_DIR/maintain.conf"

# Directories to exclude from scanning (override in maintain.conf)
EXCLUDE_DIRS=(
    "/mnt/9/gt"
    "/mnt/93B34A21B34A1B76/gt"
    "/mnt/82A23910A2390A65/Trade/EducationAndHack/LLM/gt"
)

# Path patterns to exclude — if any path component matches, project is skipped.
# Checked as substring against each directory component in the project path.
# Example: "polecats" excludes /mnt/9/gt/rig_Aha/polecats/chrome/rig_Aha
EXCLUDE_PATTERNS=(
    "polecats"
    "witness"
    "refinery"
)

# Directories to include even if under EXCLUDE_DIRS (whitelist overrides blacklist)
INCLUDE_DIRS=(
    "/mnt/9/gt/rig_support_messages_assistent/mayor/rig"
)

# ── Defaults ────────────────────────────────────────────────────────────────
MAX_DAILY=1          # max maintenance runs per project per day
DRY_RUN=false
FORCE=false
VERBOSE=true         # detailed logging (false = only errors and summary)
SINGLE_PROJECT=""    # if set, only process this project
MODEL="sonnet"       # use sonnet for maintenance (cheaper)
MAX_BUDGET="0.50"    # max $ per project per run

# Ignore files to respect when scanning project code (override in maintain.conf)
IGNORE_FILES=(".gitignore" ".cgrignore" ".claudeignore")

# Only process projects with file changes in the last N hours (0 = disabled)
ACTIVITY_HOURS=3

# Task timeouts in seconds (override in maintain.conf)
TIMEOUT_REINDEX=60
TIMEOUT_ARCHITECTURE=90
TIMEOUT_MEMORY=60
TIMEOUT_SKILLS=90
TIMEOUT_AGENTS=90

# INoT: embed Introspection of Thought in improved prompts
INOT=false

# ── Colors ──────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; DIM=$'\033[2m'; NC=$'\033[0m'

log_info()  { [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE" || echo "[$(date +%H:%M:%S)] $*" >> "$LOG_FILE"; }
log_ok()    { [[ "$VERBOSE" == "true" ]] && echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE" || echo "[$(date +%H:%M:%S)] $*" >> "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE"; }
log_err()   { echo -e "${RED}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE"; }
log_dim()   { [[ "$VERBOSE" == "true" ]] && echo -e "${DIM}[$(date +%H:%M:%S)] $*${NC}" | tee -a "$LOG_FILE" || echo "[$(date +%H:%M:%S)] $*" >> "$LOG_FILE"; }

# ── Spinner with elapsed time ─────────────────────────────────────────────
# Usage: spinner_start "message" ; long_command ; spinner_stop
_SPINNER_PID=""
_SPINNER_START=""

spinner_start() {
    local msg="$1"
    _SPINNER_START=$(date +%s)
    (
        local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while true; do
            local elapsed=$(( $(date +%s) - _SPINNER_START ))
            local mins=$((elapsed / 60))
            local secs=$((elapsed % 60))
            local time_str
            if [[ $mins -gt 0 ]]; then
                time_str="${mins}m${secs}s"
            else
                time_str="${secs}s"
            fi
            printf '\r    %s %s [%s] ' "${DIM}${chars:i%${#chars}:1}${NC}" "$msg" "$time_str" >&2
            i=$((i + 1))
            sleep 0.3
        done
    ) &
    _SPINNER_PID=$!
    disown $_SPINNER_PID 2>/dev/null
}

spinner_stop() {
    local status_msg="${1:-done}"
    local color="${2:-$GREEN}"
    if [[ -n "$_SPINNER_PID" ]] && kill -0 "$_SPINNER_PID" 2>/dev/null; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null || true
    fi
    _SPINNER_PID=""
    local elapsed=$(( $(date +%s) - _SPINNER_START ))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local time_str
    if [[ $mins -gt 0 ]]; then
        time_str="${mins}m${secs}s"
    else
        time_str="${secs}s"
    fi
    printf '\r    %s [%s]                    \n' "${color}${status_msg}${NC}" "$time_str" >&2
}

# Run a command with spinner: run_with_spinner "label" command arg1 arg2...
# Captures stdout into $_RUN_RESULT
_RUN_RESULT=""
run_with_spinner() {
    local label="$1"; shift
    [[ "$VERBOSE" == "true" ]] && spinner_start "$label"
    _RUN_RESULT=$("$@" 2>&1) || true
    [[ "$VERBOSE" == "true" ]] && spinner_stop
}

# ── Load config ─────────────────────────────────────────────────────────────
load_config() {
    if [[ -f "$CONF_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONF_FILE"
    fi
}

# ── Parse args ──────────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --max-daily)  MAX_DAILY="$2"; shift 2 ;;
            --dry-run)    DRY_RUN=true; shift ;;
            --force)      FORCE=true; shift ;;
            --verbose)    VERBOSE=true; shift ;;
            --quiet|-q)   VERBOSE=false; shift ;;
            --project)    SINGLE_PROJECT="$2"; shift 2 ;;
            --model)      MODEL="$2"; shift 2 ;;
            --budget)     MAX_BUDGET="$2"; shift 2 ;;
            --ignore-files) IFS=',' read -ra IGNORE_FILES <<< "$2"; shift 2 ;;
            --activity-hours) ACTIVITY_HOURS="$2"; shift 2 ;;
            --include)    INCLUDE_DIRS+=("$2"); shift 2 ;;
            --inot)       INOT=true; shift ;;
            --help|-h)    show_help; exit 0 ;;
            *)            echo "Unknown: $1"; show_help; exit 1 ;;
        esac
    done
}

show_help() {
    cat <<'EOF'
Usage: ~/.claude/maintain.sh [options]

Options:
  --max-daily N       Max runs per project per day (default: 1)
  --dry-run           Show what would be done, don't execute
  --force             Ignore daily limit, run anyway
  --verbose           Detailed output to stdout+log (default: true)
  --quiet, -q         Suppress stdout, only errors+warnings (log still written)
  --project DIR       Process only this project directory
  --include DIR       Add to INCLUDE_DIRS whitelist (can repeat, overrides EXCLUDE_DIRS)
  --model MODEL       Claude model to use (default: sonnet)
  --budget AMOUNT     Max USD per project per run (default: 0.50)
  --ignore-files F    Comma-separated ignore files (default: .gitignore,.cgrignore,.claudeignore)
  --activity-hours N  Only process projects with file changes in last N hours (default: 3, 0=disabled)
  --inot              Embed INoT (Introspection of Thought) in improved agent prompts
  -h, --help          Show this help

Config: ~/.claude/maintain.conf
  EXCLUDE_DIRS=("/mnt/9/gt" "/mnt/03244/gt")
  INCLUDE_DIRS=("/mnt/9/gt/rig_support_messages_assistent/mayor/rig")
  EXCLUDE_PATTERNS=("polecats" "witness")    # skip if any path component contains word
  IGNORE_FILES=(".gitignore" ".cgrignore" ".claudeignore")
  ACTIVITY_HOURS=3
  VERBOSE=true
  MAX_DAILY=2
  MODEL=haiku

Exclude/Include logic:
  INCLUDE_DIRS overrides EXCLUDE_DIRS. If a project path matches any INCLUDE_DIRS
  entry (exact or prefix), it is processed even if it falls under EXCLUDE_DIRS.

  Example:
    EXCLUDE_DIRS=("/mnt/9/gt")                                    # skip everything under /mnt/9/gt
    INCLUDE_DIRS=("/mnt/9/gt/rig_support_messages_assistent/mayor/rig")  # except this one

Project discovery:
  Projects are found via ~/.claude/projects/ directory, which contains mangled
  paths created by Claude Code when you run 'claude' in a project directory.
  Only directories where 'claude' was previously used are discovered.
  See comments at top of script for detailed explanation.
EOF
}

# ── Setup ───────────────────────────────────────────────────────────────────
setup() {
    mkdir -p "$LOG_DIR" "$STATE_DIR"

    # Log file for today
    LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"

    # Prune logs older than 10 days
    find "$LOG_DIR" -name '*.log' -mtime +10 -delete 2>/dev/null || true
    # Prune state older than 2 days (daily counters)
    find "$STATE_DIR" -name '*.count' -mtime +2 -delete 2>/dev/null || true
}

# ── Project discovery ───────────────────────────────────────────────────────
# Derives real project paths from ~/.claude/projects/ directory names.
#
# Claude Code encodes paths by replacing / with - and prepending -.
# Example: /mnt/9/gt/myproject → -mnt-9-gt-myproject
#
# Problem: directory names can also contain dashes (e.g. "rig-support" vs
# "rig/support"). A naive sed 's/-/\//g' cannot distinguish path separators
# from literal dashes. Example:
#   -mnt-9-gt-rig-support-messages-assistent-mayor-rig
# could be /mnt/9/gt/rig/support/messages/... or /mnt/9/gt/rig-support-messages-assistent/...
#
# Solution: greedy left-to-right filesystem walk. Start from /, try the
# longest matching real directory at each step. This always finds the correct
# path if it exists on disk.
#
# _decode_mangled_path: reconstruct real filesystem path from Claude Code's
# mangled directory name.
#
# Claude Code encodes project paths by replacing BOTH '/' AND '_' with '-',
# then prepending '-'. Examples:
#   /mnt/9/gt/rig_support_messages_assistent/mayor/rig
#     → -mnt-9-gt-rig-support-messages-assistent-mayor-rig
#   /mnt/9/gt/test-cli-wraper
#     → -mnt-9-gt-test-cli-wraper
#
# This makes decoding ambiguous: each '-' could be '/', '_', or literal '-'.
# Algorithm: greedy left-to-right with filesystem probing.
# At each directory level, try accumulating dash-segments into a single
# directory name (joining with _, -, or splitting as /), and check which
# combination matches a real directory on disk. Prefer '/' first (shortest
# name), then '_', then '-'.
#
_decode_mangled_path() {
    local mangled="$1"
    mangled="${mangled#-}"

    # Fast path: if simple sed decode works (no underscores, dashes, or dots in names)
    local simple="/${mangled//-//}"
    if [[ -d "$simple" ]]; then
        echo "$simple"
        return
    fi

    # Split into dash-segments
    IFS='-' read -ra segs <<< "$mangled"
    local n=${#segs[@]}

    # Iterative greedy: at each step, find the longest segment combo that
    # forms a real directory/file (trying _, ., -, and / as joiners)
    local path=""
    local i=0

    while [[ $i -lt $n ]]; do
        local found=false
        # Try from longest to shortest accumulation (greedy)
        local j=$((n))
        while [[ $j -gt $i ]]; do
            # Build candidate name from segs[i..j-1] with different joiners
            # Try underscores first (most common: rig_support_messages)
            local name_us="${segs[$i]}"
            for (( k=i+1; k<j; k++ )); do
                name_us="${name_us}_${segs[$k]}"
            done
            if [[ -e "${path}/${name_us}" ]]; then
                path="${path}/${name_us}"
                i=$j
                found=true
                break
            fi

            # Try dots (e.g. whisper.cpp → whisper-cpp in mangled form)
            if [[ $j -gt $((i+1)) ]]; then
                local name_dot="${segs[$i]}"
                for (( k=i+1; k<j; k++ )); do
                    name_dot="${name_dot}.${segs[$k]}"
                done
                if [[ -e "${path}/${name_dot}" ]]; then
                    path="${path}/${name_dot}"
                    i=$j
                    found=true
                    break
                fi
            fi

            # Try dashes (literal dashes in dir name: test-cli-wrapper)
            if [[ $j -gt $((i+1)) ]]; then
                local name_dash="${segs[$i]}"
                for (( k=i+1; k<j; k++ )); do
                    name_dash="${name_dash}-${segs[$k]}"
                done
                if [[ -e "${path}/${name_dash}" ]]; then
                    path="${path}/${name_dash}"
                    i=$j
                    found=true
                    break
                fi
            fi

            j=$((j - 1))
        done

        # If nothing matched, take single segment as path component
        if [[ "$found" == "false" ]]; then
            path="${path}/${segs[$i]}"
            i=$((i + 1))
        fi
    done

    # Return the decoded path (caller checks existence)
    echo "$path"
}

# discover_all_projects: returns TAB-separated lines: mangled_name\tdecoded_path\tstatus
# status: resolved (dir exists) or unresolved (doesn't exist on disk)
# Further filtering (exclude, code markers, activity) happens in main loop.
discover_all_projects() {
    for proj_dir in "$CLAUDE_DIR/projects/"*/; do
        [[ -d "$proj_dir" ]] || continue

        local dirname
        dirname=$(basename "$proj_dir")

        local real_path
        real_path=$(_decode_mangled_path "$dirname")

        if [[ -d "$real_path" ]]; then
            printf '%s\t%s\t%s\n' "$dirname" "$real_path" "resolved"
        else
            printf '%s\t%s\t%s\n' "$dirname" "$real_path" "unresolved"
        fi
    done
}

# _is_code_project: always true — if ~/.claude/projects/<mangled> exists,
# Claude Code was already used there, that's sufficient.
_is_code_project() {
    return 0
}

# _get_exclude_reason: returns reason string if excluded, empty if not
# Used by categorize to distinguish exclude-by-dir vs exclude-by-pattern
_get_exclude_reason() {
    local dir="$1"

    # Whitelist takes priority
    if is_included "$dir"; then
        return 1
    fi

    # Check EXCLUDE_DIRS
    for excl in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$dir" == "$excl" ]] || [[ "$dir" == "$excl"/* ]]; then
            echo "dir:$excl"
            return 0
        fi
    done

    # Check EXCLUDE_PATTERNS
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        IFS='/' read -ra components <<< "$dir"
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            for comp in "${components[@]}"; do
                if [[ "$comp" == *"$pattern"* ]]; then
                    echo "pattern:$pattern"
                    return 0
                fi
            done
        done
    fi

    return 1
}

# ── Check if dir is explicitly included (whitelist overrides blacklist) ────
is_included() {
    local dir="$1"
    # If INCLUDE_DIRS is empty, nothing is whitelisted
    [[ ${#INCLUDE_DIRS[@]} -eq 0 ]] && return 1
    for incl in "${INCLUDE_DIRS[@]}"; do
        # Exact match or dir is under an included path
        if [[ "$dir" == "$incl" ]] || [[ "$dir" == "$incl"/* ]]; then
            return 0
        fi
    done
    return 1
}

# ── Check if dir is excluded ───────────────────────────────────────────────
# Priority: INCLUDE_DIRS > EXCLUDE_DIRS > EXCLUDE_PATTERNS (include wins)
is_excluded() {
    local dir="$1"

    # Whitelist takes priority — if included, never excluded
    if is_included "$dir"; then
        return 1  # not excluded
    fi

    # Check exact path prefixes
    for excl in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$dir" == "$excl" ]] || [[ "$dir" == "$excl"/* ]]; then
            return 0
        fi
    done

    # Check path component patterns (e.g. "polecats" matches any dir named *polecats*)
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        # Split path into components and check each against patterns
        IFS='/' read -ra components <<< "$dir"
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            for comp in "${components[@]}"; do
                if [[ "$comp" == *"$pattern"* ]]; then
                    return 0
                fi
            done
        done
    fi

    return 1
}

# ── Check if project has recent activity ────────────────────────────────────
# Returns 0 (active) if any file was modified within ACTIVITY_HOURS.
# Respects ignore patterns from IGNORE_FILES to skip build artifacts, caches, etc.
has_recent_activity() {
    local project_dir="$1"

    # Disabled check — treat all as active
    if [[ "$ACTIVITY_HOURS" -eq 0 ]]; then
        return 0
    fi

    # Build find exclusion args from ignore files
    local find_excludes=()
    # Always exclude common non-source dirs
    for d in .git .docker node_modules __pycache__ .venv venv .tox .mypy_cache .pytest_cache; do
        find_excludes+=(-path "*/$d" -prune -o)
    done

    # Add patterns from project ignore files
    for ignore_file in "${IGNORE_FILES[@]}"; do
        local fpath="$project_dir/$ignore_file"
        if [[ -f "$fpath" ]]; then
            while IFS= read -r pattern; do
                [[ -z "$pattern" ]] && continue
                # Strip trailing slash (directory marker)
                pattern="${pattern%/}"
                # Skip negation patterns (lines starting with !)
                [[ "$pattern" == "!"* ]] && continue
                # Convert simple glob to find -path pattern
                find_excludes+=(-path "*/$pattern" -prune -o)
            done < <(grep -v '^\s*#' "$fpath" | grep -v '^\s*$' 2>/dev/null || true)
        fi
    done

    # Find at least 1 file modified within ACTIVITY_HOURS hours
    local recent
    recent=$(find "$project_dir" \
        "${find_excludes[@]}" \
        -type f -mmin "-$((ACTIVITY_HOURS * 60))" -print -quit \
        2>/dev/null)

    [[ -n "$recent" ]]
}

# ── Collect ignore patterns from project ────────────────────────────────────
# Reads .gitignore, .cgrignore, .claudeignore (or whatever IGNORE_FILES lists)
# and produces a single block of patterns for claude prompts to respect.
collect_ignore_patterns() {
    local project_dir="$1"
    local patterns=""

    for ignore_file in "${IGNORE_FILES[@]}"; do
        local fpath="$project_dir/$ignore_file"
        if [[ -f "$fpath" ]]; then
            # Read non-empty, non-comment lines
            local file_patterns
            file_patterns=$(grep -v '^\s*#' "$fpath" | grep -v '^\s*$' 2>/dev/null || true)
            if [[ -n "$file_patterns" ]]; then
                patterns+="
# From $ignore_file:
$file_patterns"
            fi
        fi
    done

    echo "$patterns"
}

# ── Check daily run limit ──────────────────────────────────────────────────
check_daily_limit() {
    local project_hash
    project_hash=$(echo "$1" | md5sum | cut -d' ' -f1)
    local count_file="$STATE_DIR/${project_hash}_$(date +%Y-%m-%d).count"

    local count=0
    if [[ -f "$count_file" ]]; then
        count=$(cat "$count_file")
    fi

    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    if [[ "$count" -ge "$MAX_DAILY" ]]; then
        return 1  # limit reached
    fi
    return 0
}

# ── Increment daily counter ────────────────────────────────────────────────
increment_counter() {
    local project_hash
    project_hash=$(echo "$1" | md5sum | cut -d' ' -f1)
    local count_file="$STATE_DIR/${project_hash}_$(date +%Y-%m-%d).count"

    local count=0
    if [[ -f "$count_file" ]]; then
        count=$(cat "$count_file")
    fi
    echo $((count + 1)) > "$count_file"
}

# ── Call MCP tool directly via JSON-RPC (no LLM needed) ────────────────────
# Usage: _mcp_call "tool_name" '{"arg":"val"}' [timeout_sec]
# Returns the MCP tool result text on stdout
_mcp_call() {
    local tool_name="$1"
    local args_json="${2:-\{\}}"
    local timeout_sec="${3:-30}"

    MCP_TOOL="$tool_name" MCP_ARGS="$args_json" MCP_TIMEOUT="$timeout_sec" \
    python3 - <<'PYEOF'
import subprocess, json, time, os

tool = os.environ["MCP_TOOL"]
args = json.loads(os.environ["MCP_ARGS"])
timeout = int(os.environ["MCP_TIMEOUT"])

proc = subprocess.Popen(["codebase-memory-mcp", "serve"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

init = json.dumps({"jsonrpc":"2.0","id":0,"method":"initialize",
    "params":{"protocolVersion":"2024-11-05","capabilities":{},
    "clientInfo":{"name":"maintain","version":"1.0"}}})
call = json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call",
    "params":{"name": tool, "arguments": args}})

proc.stdin.write(init + "\n")
proc.stdin.flush()
time.sleep(0.3)
proc.stdin.write(call + "\n")
proc.stdin.flush()

deadline = time.time() + timeout
for line in proc.stdout:
    if time.time() > deadline:
        print("ERROR: MCP call timed out")
        break
    line = line.strip()
    if line and '"id":1' in line:
        try:
            r = json.loads(line)
            content = r.get("result", {}).get("content", [])
            if content:
                print(content[0].get("text", ""))
            elif "error" in r:
                print("ERROR: " + json.dumps(r["error"]))
        except:
            print(line)
        break

proc.terminate()
try:
    proc.wait(timeout=3)
except:
    proc.kill()
PYEOF
}

# ── Task 1: Reindex codebase-memory ─────────────────────────────────────────
task_reindex() {
    local project_dir="$1"
    local ignore_patterns="${2:-}"
    local detail_log="${3:-/dev/null}"
    log_info "  [1/5] Reindexing codebase-memory graph..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dim "    (dry-run) Would reindex $project_dir"
        return 0
    fi

    # Call MCP tool directly — no LLM, no budget, instant
    [[ "$VERBOSE" == "true" ]] && spinner_start "codebase-memory → index_repository (direct MCP call)"
    local result
    result=$(_mcp_call "index_repository" "{\"repo_path\":\"$project_dir\"}" 2>&1) || true

    _log_task_result "$detail_log" "reindex" "$result"

    if echo "$result" | grep -qi '"error"'; then
        [[ "$VERBOSE" == "true" ]] && spinner_stop "issues" "$YELLOW"
        log_warn "    Reindex had issues: $(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('error',{}).get('message','unknown'))" 2>/dev/null || echo "$result" | tail -1)"
    else
        [[ "$VERBOSE" == "true" ]] && spinner_stop "done" "$GREEN"
        log_ok "    Reindex complete"
    fi
}

# ── Task 2: Generate Architecture section in CLAUDE.md ──────────────────────
task_architecture() {
    local project_dir="$1"
    local ignore_patterns="${2:-}"
    local detail_log="${3:-/dev/null}"
    log_info "  [2/5] Updating Architecture in CLAUDE.md..."

    if [[ ! -f "$project_dir/CLAUDE.md" ]]; then
        log_dim "    No CLAUDE.md found, skipping"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dim "    (dry-run) Would update Architecture section"
        return 0
    fi

    local ignore_block=""
    if [[ -n "$ignore_patterns" ]]; then
        ignore_block="
IMPORTANT: When scanning the project, completely SKIP files and directories matching these ignore patterns:
${ignore_patterns}
Do NOT include ignored paths in the architecture map.
"
    fi

    local prompt="${ignore_block}CRITICAL: Read CLAUDE.md first. It contains manually written instructions that are VITAL. You MUST preserve ALL existing content exactly as-is.

Your ONLY job: find or create a section \"## Architecture (auto-generated)\". This section (and ONLY this section) can be replaced.

Generate a concise project map for that section:
1. Key directories and their purpose (1 line each)
2. Key files: entry points, config, main modules (path + 1-line description)
3. Key classes/functions (name + file + 1-line purpose)
4. API endpoints if any (method + path + purpose)

Rules:
- Keep the Architecture section under 60 lines
- ONLY touch the \"## Architecture (auto-generated)\" section (from that header to the next ## header)
- Do NOT modify, delete, reorder, or reformat ANY other section
- Do NOT add new sections (no Code Style, no other additions)
- Add a comment inside: <!-- Auto-generated by maintain.sh, do not edit manually -->
- If the section doesn't exist, append it at the very end of the file
- If you notice that existing manually-written sections in CLAUDE.md contradict the current project state (e.g. describe removed features, wrong paths), do NOT fix them. Instead, output a line starting with REVIEW: describing what seems outdated and why. The human will decide.
- If in doubt, make NO changes rather than risk losing existing content"

    [[ "$VERBOSE" == "true" ]] && spinner_start "claude → update Architecture in CLAUDE.md (timeout ${TIMEOUT_ARCHITECTURE}s)"
    local result
    result=$(cd "$project_dir" && unset CLAUDECODE && timeout --signal=KILL "$TIMEOUT_ARCHITECTURE" \
        claude -p \
        --model "$MODEL" \
        --max-budget-usd 0.10 \
        --dangerously-skip-permissions \
        --no-session-persistence \
        --allowedTools "Read,Glob,Grep,Edit" \
        <<< "$prompt" \
        2>&1) || true

    _log_task_result "$detail_log" "architecture" "$result"

    if echo "$result" | grep -qi "error\|fail"; then
        [[ "$VERBOSE" == "true" ]] && spinner_stop "issues" "$YELLOW"
        log_warn "    Architecture update had issues"
    else
        [[ "$VERBOSE" == "true" ]] && spinner_stop "done" "$GREEN"
        log_ok "    Architecture updated"
    fi
}

# ── Task 3: Clean stale MEMORY.md entries ───────────────────────────────────
task_clean_memory() {
    local project_dir="$1"
    local detail_log="${2:-/dev/null}"
    log_info "  [3/5] Cleaning stale MEMORY.md entries..."

    # Find the memory directory for this project
    # Claude Code mangles paths: / → -, _ → -, prepend -
    local mangled
    mangled=$(echo "$project_dir" | sed 's|^/|-|' | sed 's|[/_]|-|g')
    local memory_dir="$CLAUDE_DIR/projects/${mangled}/memory"
    local memory_file="$memory_dir/MEMORY.md"

    if [[ ! -f "$memory_file" ]]; then
        log_dim "    No MEMORY.md found, skipping"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dim "    (dry-run) Would clean stale entries in $memory_file"
        return 0
    fi

    local prompt="CRITICAL: MEMORY.md contains important knowledge accumulated across many sessions. Be EXTREMELY conservative.

Read $memory_file and check each entry against the actual project.

DO NOT remove or modify any entries. Instead:
- If an entry references a file that no longer exists, output: REVIEW: [entry summary] — file [path] not found, may be stale
- If an entry describes a removed feature, output: REVIEW: [entry summary] — [feature] appears removed
- For all other entries, leave them untouched

The ONLY change you may make directly: fix a clearly wrong file path if you can find the correct new path (e.g. file was renamed/moved but still exists). In that case, update the path and output: FIXED: updated path [old] → [new]

NEVER remove entries about: user preferences, architecture decisions, server addresses, benchmark results, configuration, gotchas.

If unsure — DO NOTHING. Output REVIEW: lines for the human to decide."

    [[ "$VERBOSE" == "true" ]] && spinner_start "claude → clean stale MEMORY.md entries (timeout ${TIMEOUT_MEMORY}s)"
    local result
    result=$(cd "$project_dir" && unset CLAUDECODE && timeout --signal=KILL "$TIMEOUT_MEMORY" \
        claude -p \
        --model "$MODEL" \
        --max-budget-usd 0.10 \
        --dangerously-skip-permissions \
        --no-session-persistence \
        --allowedTools "Read,Glob,Edit" \
        <<< "$prompt" \
        2>&1) || true

    _log_task_result "$detail_log" "clean_memory" "$result"
    [[ "$VERBOSE" == "true" ]] && spinner_stop "done" "$GREEN"
    log_ok "    Memory cleanup done"
}

# ── Task 4: Generate skill templates ────────────────────────────────────────
task_skills() {
    local project_dir="$1"
    local ignore_patterns="${2:-}"
    local detail_log="${3:-/dev/null}"
    log_info "  [4/5] Generating skill templates..."

    local commands_dir="$project_dir/.claude/commands"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dim "    (dry-run) Would generate skills in $commands_dir"
        return 0
    fi

    local ignore_block=""
    if [[ -n "$ignore_patterns" ]]; then
        ignore_block="
IMPORTANT: When scanning the project structure, skip files/directories matching these ignore patterns:
${ignore_patterns}
"
    fi

    local prompt="${ignore_block}Check .claude/commands/ directory in this project.

CRITICAL: Do NOT overwrite or modify any existing .md files in .claude/commands/. They contain carefully crafted prompts. Only CREATE new files that don't already exist.

Only create skills that make sense for THIS project based on what you see:

1. If the project has tests: create run-tests.md:
   \"Run the test suite for this project. Show failures clearly. If tests fail, analyze the error and suggest a fix.\"

2. If the project has a Dockerfile or docker-compose: create deploy-check.md:
   \"Check deployment readiness: verify Dockerfile builds, docker-compose config is valid, and .env.example has all required vars.\"

3. If the project is a Python project: create lint-fix.md:
   \"Run linting (ruff/flake8/mypy if configured) and fix any auto-fixable issues. Report remaining issues.\"

4. If the project has an API (FastAPI/Flask/Express): create api-overview.md:
   \"List all API endpoints with their methods, parameters, and auth requirements. Format as a table.\"

5. Always create review-changes.md if it doesn't exist:
   \"Review all uncommitted changes (git diff). For each change: check correctness, security (OWASP top 10), and style. Flag issues by severity.\"

Rules:
- Do NOT overwrite existing skill files
- Keep each skill under 10 lines
- Create .claude/commands/ directory if needed
- Report which skills were created/skipped"

    [[ "$VERBOSE" == "true" ]] && spinner_start "claude → generate skill templates (timeout ${TIMEOUT_SKILLS}s)"
    local result
    result=$(cd "$project_dir" && unset CLAUDECODE && timeout --signal=KILL "$TIMEOUT_SKILLS" \
        claude -p \
        --model "$MODEL" \
        --max-budget-usd 0.10 \
        --dangerously-skip-permissions \
        --no-session-persistence \
        --allowedTools "Read,Glob,Grep,Write,Bash(ls:*)" \
        <<< "$prompt" \
        2>&1) || true

    _log_task_result "$detail_log" "skills" "$result"
    [[ "$VERBOSE" == "true" ]] && spinner_stop "done" "$GREEN"
    log_ok "    Skills check done"
}

# ── Task 5: Manage agents and roles ─────────────────────────────────────────
task_agents() {
    local project_dir="$1"
    local ignore_patterns="${2:-}"
    local detail_log="${3:-/dev/null}"
    log_info "  [5/5] Managing agents and roles..."

    local agents_file="$project_dir/.claude/agents.json"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dim "    (dry-run) Would update agents in $agents_file"
        return 0
    fi

    local ignore_block=""
    if [[ -n "$ignore_patterns" ]]; then
        ignore_block="
IMPORTANT: When analyzing the project, skip files/directories matching these ignore patterns:
${ignore_patterns}
"
    fi

    local prompt="${ignore_block}CRITICAL: If .claude/agents.json already exists, read it first. Preserve ALL existing agents exactly as they are — their descriptions and prompts were carefully written. Only ADD new agents that don't exist yet.

If agents.json does not exist, create it.

Full agent schema — use ALL relevant fields for each agent:
{
  \"agent-name\": {
    \"description\": \"When to delegate to this agent (required)\",
    \"prompt\": \"System prompt with specific instructions for this project (required)\",
    \"model\": \"sonnet | opus | haiku | inherit (choose wisely per task)\",
    \"tools\": \"Comma-separated allowed tools: Read,Glob,Grep,Edit,Write,Bash,Agent,WebFetch,WebSearch\",
    \"disallowedTools\": \"Tools to deny (remove from inherited set)\",
    \"permissionMode\": \"default | acceptEdits | bypassPermissions\",
    \"maxTurns\": 10,
    \"isolation\": \"worktree (for agents that modify code — keeps changes isolated)\"
  }
}

Model selection — choose the CHEAPEST model that can handle the task effectively:
- haiku: fast reviews, linting, simple checks, status reports, formatting. Use for repetitive/mechanical tasks.
- sonnet: code analysis, debugging, documentation, refactoring suggestions. Default for most agents.
- opus: complex architecture decisions, multi-file refactoring, security audits. Only when deep reasoning is needed.

Tool selection — give MINIMUM tools needed. Examples:
- reviewer: Read,Glob,Grep (read-only, no write access)
- architect: Read,Glob,Grep (analysis only)
- debugger: Read,Glob,Grep,Bash (needs to run tests/commands)
- documenter: Read,Glob,Grep,Edit (needs to write docs)
- fixer/refactorer: Read,Glob,Grep,Edit,Write,Bash (full write access)

Use isolation=worktree for agents that write code — their changes go to a separate branch for review.
Use permissionMode=acceptEdits for trusted write agents, permissionMode=default for others.
Set maxTurns to prevent runaway agents (5-10 for focused tasks, 15-20 for complex ones).

Create agents that make sense for THIS project. Analyze the codebase first. Consider:
1. reviewer — always useful (model: haiku, read-only tools)
2. architect — for projects with 10+ files (model: sonnet, read-only tools)
3. debugger — for projects with tests/APIs (model: sonnet, +Bash for running tests)
4. documenter — for projects with APIs/docs (model: sonnet, +Edit for updating docs)
5. Project-specific agents based on what you find

Rules:
- NEVER remove or modify existing agents
- NEVER overwrite agents.json if it has content — only append new keys
- Create .claude/ directory if needed
- If existing agents lack model/tools/maxTurns fields, output REVIEW: lines suggesting additions but do NOT modify them
- Report what agents were added (and what was preserved unchanged)"

    [[ "$VERBOSE" == "true" ]] && spinner_start "claude → manage agents.json (timeout ${TIMEOUT_AGENTS}s)"
    local result
    result=$(cd "$project_dir" && unset CLAUDECODE && timeout --signal=KILL "$TIMEOUT_AGENTS" \
        claude -p \
        --model "$MODEL" \
        --max-budget-usd 0.10 \
        --dangerously-skip-permissions \
        --no-session-persistence \
        --allowedTools "Read,Glob,Grep,Write,Bash(ls:*)" \
        <<< "$prompt" \
        2>&1) || true

    _log_task_result "$detail_log" "agents" "$result"
    [[ "$VERBOSE" == "true" ]] && spinner_stop "done" "$GREEN"
    log_ok "    Agents check done"
}

task_improve_prompts() {
    local project_dir="$1"
    local detail_log="${2:-/dev/null}"
    log_info "  [6/6] Improving agent prompts..."

    local agents_file="$project_dir/.claude/agents.json"

    if [[ ! -f "$agents_file" ]]; then
        log_dim "    No agents.json found, skipping prompt improvement"
        return 0
    fi

    # Check file has content (at least 2 agents)
    local agent_count
    agent_count=$(python3 -c "
import json
try:
    with open('$agents_file') as f:
        data = json.load(f)
    print(len(data))
except:
    print(0)
" 2>/dev/null) || agent_count=0

    if [[ "$agent_count" -lt 1 ]]; then
        log_dim "    agents.json empty or invalid, skipping"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dim "    (dry-run) Would improve $agent_count agent prompts in $agents_file"
        [[ "$INOT" == "true" ]] && log_dim "    (dry-run) INoT mode enabled"
        return 0
    fi

    local improve_script="$CLAUDE_DIR/improve-prompts.sh"
    if [[ ! -x "$improve_script" ]]; then
        log_warn "    improve-prompts.sh not found or not executable at $improve_script"
        return 0
    fi

    local inot_flag=""
    [[ "$INOT" == "true" ]] && inot_flag="--inot"

    [[ "$VERBOSE" == "true" ]] && spinner_start "improve-prompts → agents.json ($agent_count agents)"

    local result
    result=$("$improve_script" \
        --agents "$agents_file" \
        --model "$MODEL" \
        --budget "$MAX_BUDGET" \
        --max-repair 3 \
        --lang ru \
        $inot_flag \
        2>&1) || true

    _log_task_result "$detail_log" "improve_prompts" "$result"
    [[ "$VERBOSE" == "true" ]] && spinner_stop "done" "$GREEN"
    log_ok "    Prompt improvement done"
}

# ── Human review file ──────────────────────────────────────────────────────
# When a task detects a conflict that needs human decision, it appends here.
# Human checks this file after maintain.sh finishes.
REVIEW_FILE="$CLAUDE_DIR/maintain-review.md"

_add_review_note() {
    local project_dir="$1"
    local task="$2"
    local message="$3"
    {
        echo ""
        echo "### [$task] $(basename "$project_dir") — $(date '+%Y-%m-%d %H:%M')"
        echo "Project: \`$project_dir\`"
        echo ""
        echo "$message"
        echo ""
        echo "---"
    } >> "$REVIEW_FILE"
    log_warn "    ⚡ Review needed — see $REVIEW_FILE"
}

# ── Save task output to per-project detail log ───────────────────────────
# Each project gets a detail log: maintain-logs/YYYY-MM-DD_<hash>.detail.log
# Contains full Claude output for each task + git diff summary.
_detail_log_path() {
    local project_dir="$1"
    local project_hash
    project_hash=$(echo "$project_dir" | md5sum | cut -d' ' -f1)
    echo "$LOG_DIR/$(date +%Y-%m-%d)_${project_hash:0:8}.detail.log"
}

_log_detail() {
    local detail_log="$1"; shift
    echo "[$(date +%H:%M:%S)] $*" >> "$detail_log"
}

_log_task_result() {
    local detail_log="$1"
    local task_name="$2"
    local result="$3"
    {
        echo ""
        echo "════════ $task_name ════════"
        echo "$result"
        echo "════════ /$task_name ════════"
    } >> "$detail_log"

    # Extract REVIEW: lines from claude output → human review file
    local review_lines
    review_lines=$(echo "$result" | grep -i '^REVIEW:' || true)
    if [[ -n "$review_lines" ]]; then
        _add_review_note "${_CURRENT_PROJECT:-unknown}" "$task_name" "$review_lines"
    fi
}

# ── Process a single project ───────────────────────────────────────────────
process_project() {
    local project_dir="$1"
    _CURRENT_PROJECT="$project_dir"

    log_info "Processing: $project_dir"

    # Check daily limit
    if ! check_daily_limit "$project_dir"; then
        log_dim "  Skipped (daily limit $MAX_DAILY reached)"
        return 0
    fi

    # Setup detail log for this project
    local detail_log
    detail_log=$(_detail_log_path "$project_dir")
    _log_detail "$detail_log" "=== Processing: $project_dir ==="

    # Capture git state before tasks (for diff summary)
    local git_status_before=""
    if [[ -d "$project_dir/.git" ]]; then
        git_status_before=$(cd "$project_dir" && git diff --stat HEAD 2>/dev/null || true)
        _log_detail "$detail_log" "Git status before: $(cd "$project_dir" && git status --short 2>/dev/null | wc -l) changed files"
    fi

    # Collect ignore patterns once per project, pass to all tasks
    local ignore_patterns
    ignore_patterns=$(collect_ignore_patterns "$project_dir")
    if [[ -n "$ignore_patterns" ]]; then
        log_dim "  Loaded ignore patterns from: ${IGNORE_FILES[*]}"
    fi

    # Run all tasks (pass detail_log for verbose output capture)
    task_reindex "$project_dir" "$ignore_patterns" "$detail_log"
    task_architecture "$project_dir" "$ignore_patterns" "$detail_log"
    task_clean_memory "$project_dir" "$detail_log"
    task_skills "$project_dir" "$ignore_patterns" "$detail_log"
    task_agents "$project_dir" "$ignore_patterns" "$detail_log"
    task_improve_prompts "$project_dir" "$detail_log"

    # Only increment counter for real runs (not dry-run)
    if [[ "$DRY_RUN" == "true" ]]; then
        log_ok "Done (dry-run): $project_dir"
        log_dim "  Detail log: $detail_log"
        echo "" >> "$LOG_FILE"
        return 0
    fi

    # Show what changed (git diff after tasks)
    if [[ -d "$project_dir/.git" ]]; then
        local changes
        changes=$(cd "$project_dir" && git diff --stat HEAD 2>/dev/null || true)
        local untracked
        untracked=$(cd "$project_dir" && git ls-files --others --exclude-standard 2>/dev/null || true)

        _log_detail "$detail_log" ""
        _log_detail "$detail_log" "════════ Changes Summary ════════"

        if [[ -n "$changes" ]]; then
            echo "$changes" >> "$detail_log"
            # Show summary in main log
            local file_count
            file_count=$(echo "$changes" | grep -c '|' || echo 0)
            log_info "  Changes: $file_count file(s) modified"
            # Show changed file names in verbose mode
            if [[ "$VERBOSE" == "true" ]]; then
                echo "$changes" | grep '|' | while IFS= read -r line; do
                    log_dim "    $line"
                done
            fi
        fi

        if [[ -n "$untracked" ]]; then
            echo "New files:" >> "$detail_log"
            echo "$untracked" >> "$detail_log"
            local new_count
            new_count=$(echo "$untracked" | grep -c . || echo 0)
            log_info "  New files: $new_count"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "$untracked" | head -10 | while IFS= read -r line; do
                    log_dim "    + $line"
                done
            fi
        fi

        if [[ -z "$changes" ]] && [[ -z "$untracked" ]]; then
            log_dim "  No changes made"
            _log_detail "$detail_log" "No changes made"
        fi

        # Full diff in detail log (for review)
        local full_diff
        full_diff=$(cd "$project_dir" && git diff HEAD 2>/dev/null || true)
        if [[ -n "$full_diff" ]]; then
            {
                echo ""
                echo "════════ Full Diff ════════"
                echo "$full_diff"
            } >> "$detail_log"
        fi
    fi

    # Write per-project report (visible in git diff)
    local project_report="$project_dir/.maintain-report.md"
    {
        echo "# Maintain Report — $(date '+%Y-%m-%d %H:%M')"
        echo ""
        if [[ -n "$changes" ]] || [[ -n "$untracked" ]]; then
            echo "## Changes"
            [[ -n "$changes" ]] && echo '```' && echo "$changes" && echo '```'
            if [[ -n "$untracked" ]]; then
                echo "### New files"
                echo "$untracked" | while IFS= read -r f; do echo "- \`$f\`"; done
            fi
        else
            echo "## No changes made"
        fi
        echo ""
        # Include REVIEW notes if any were generated for this project
        local project_reviews
        project_reviews=$(grep -A 50 "Project: \`$project_dir\`" "$REVIEW_FILE" 2>/dev/null | head -50 || true)
        if [[ -n "$project_reviews" ]]; then
            echo "## Needs human review"
            echo "$project_reviews"
        fi
    } > "$project_report"
    log_dim "  Project report: $project_report"

    # Mark as done for today
    increment_counter "$project_dir"

    log_ok "Done: $project_dir"
    log_dim "  Detail log: $detail_log"
    echo "" >> "$LOG_FILE"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    load_config
    parse_args "$@"
    setup

    log_info "=== Claude Maintain started $(date '+%Y-%m-%d %H:%M:%S') ==="
    log_info "Config: max_daily=$MAX_DAILY, model=$MODEL, budget=$MAX_BUDGET/project, activity=${ACTIVITY_HOURS}h, verbose=$VERBOSE"

    # Validate EXCLUDE_DIRS — strip trailing slashes, warn about non-existent paths
    if [[ ${#EXCLUDE_DIRS[@]} -gt 0 ]]; then
        local valid_excludes=()
        for d in "${EXCLUDE_DIRS[@]}"; do
            d="${d%/}"  # strip trailing slash
            if [[ -d "$d" ]]; then
                valid_excludes+=("$d")
            else
                log_warn "EXCLUDE_DIRS: path does not exist, ignoring: $d"
            fi
        done
        EXCLUDE_DIRS=("${valid_excludes[@]}")
        log_dim "Exclude: ${EXCLUDE_DIRS[*]}"
    fi

    # Validate INCLUDE_DIRS — strip trailing slashes, warn about non-existent paths
    if [[ ${#INCLUDE_DIRS[@]} -gt 0 ]]; then
        local valid_includes=()
        for d in "${INCLUDE_DIRS[@]}"; do
            d="${d%/}"  # strip trailing slash
            if [[ -d "$d" ]]; then
                valid_includes+=("$d")
            else
                log_warn "INCLUDE_DIRS: path does not exist, ignoring: $d"
            fi
        done
        INCLUDE_DIRS=("${valid_includes[@]}")
        if [[ ${#INCLUDE_DIRS[@]} -gt 0 ]]; then
            log_info "Include (override): ${INCLUDE_DIRS[*]}"
        fi
    fi
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        log_dim "Exclude patterns: ${EXCLUDE_PATTERNS[*]}"
    fi

    if [[ -n "$SINGLE_PROJECT" ]]; then
        # Process single project
        if [[ ! -d "$SINGLE_PROJECT" ]]; then
            log_err "Project directory not found: $SINGLE_PROJECT"
            exit 1
        fi
        process_project "$SINGLE_PROJECT"
    else
        # ── Phase 1: Discover and categorize all projects ──────────────
        # Groups: unresolved, not_a_project, excluded_dir, excluded_pattern,
        #         included, daily_limit, inactive, active
        local -a grp_unresolved=()      # mangled path couldn't be decoded
        local -a grp_not_project=()     # reserved (currently unused)
        local -a grp_excluded_dir=()    # matched EXCLUDE_DIRS
        local -a grp_excluded_pat=()    # matched EXCLUDE_PATTERNS
        local -a grp_included=()        # matched INCLUDE_DIRS (override)
        local -a grp_daily_limit=()     # daily limit reached
        local -a grp_inactive=()        # no recent file changes
        local -a grp_active=()          # will be processed

        # Extra detail for excluded entries (reason)
        local -A excl_reasons=()

        local total=0

        while IFS=$'\t' read -r mangled decoded status; do
            [[ -z "$mangled" ]] && continue
            total=$((total + 1))

            case "$status" in
                unresolved)
                    grp_unresolved+=("$mangled → $decoded")
                    continue
                    ;;
            esac

            # From here on, status=resolved — apply filters in order:
            # 1. Exclude (dir/pattern) — but include overrides exclude
            local excl_reason
            if excl_reason=$(_get_exclude_reason "$decoded"); then
                case "$excl_reason" in
                    dir:*)
                        grp_excluded_dir+=("$decoded")
                        excl_reasons["$decoded"]="${excl_reason#dir:}"
                        ;;
                    pattern:*)
                        grp_excluded_pat+=("$decoded")
                        excl_reasons["$decoded"]="${excl_reason#pattern:}"
                        ;;
                esac
                continue
            fi

            # 2. Code markers — only after exclude check
            if ! _is_code_project "$decoded"; then
                grp_not_project+=("$decoded")
                continue
            fi

            # 3. Whitelist flag (informational — already passed exclude check)
            local is_whitelisted=false
            if is_included "$decoded"; then
                is_whitelisted=true
            fi

            # 4. Daily limit
            if ! check_daily_limit "$decoded"; then
                grp_daily_limit+=("$decoded")
                continue
            fi

            # 5. Activity check
            if [[ "$ACTIVITY_HOURS" -gt 0 ]] && ! has_recent_activity "$decoded"; then
                grp_inactive+=("$decoded")
                continue
            fi

            # 6. Active — will be processed
            grp_active+=("$decoded")
            if [[ "$is_whitelisted" == "true" ]]; then
                grp_included+=("$decoded")
            fi
        done < <(discover_all_projects)

        log_info "Discovered $total project entries in ~/.claude/projects/"
        echo "" >> "$LOG_FILE"

        # ── Phase 2: Display each group ────────────────────────────────
        _print_group() {
            local label="$1" color="$2"; shift 2
            local -a items=("$@")
            local count=${#items[@]}
            [[ $count -eq 0 ]] && return
            echo -e "${color}── ${label} (${count}) ──${NC}" | tee -a "$LOG_FILE"
            for item in "${items[@]}"; do
                echo -e "  ${color}${item}${NC}" | tee -a "$LOG_FILE"
            done
            echo "" | tee -a "$LOG_FILE"
        }

        # Unresolved (red — these are bugs in the decoder)
        if [[ ${#grp_unresolved[@]} -gt 0 ]]; then
            echo -e "${RED}── Unresolved paths (${#grp_unresolved[@]}) ── decoder couldn't find directory on disk${NC}" | tee -a "$LOG_FILE"
            for item in "${grp_unresolved[@]}"; do
                echo -e "  ${RED}${item}${NC}" | tee -a "$LOG_FILE"
            done
            echo "" | tee -a "$LOG_FILE"
        fi

        # Not a project (dim)
        _print_group "Not a project (no code markers)" "$DIM" "${grp_not_project[@]}"

        # Excluded by EXCLUDE_DIRS (yellow)
        if [[ ${#grp_excluded_dir[@]} -gt 0 ]]; then
            echo -e "${YELLOW}── Excluded by EXCLUDE_DIRS (${#grp_excluded_dir[@]}) ──${NC}" | tee -a "$LOG_FILE"
            for item in "${grp_excluded_dir[@]}"; do
                echo -e "  ${YELLOW}${item}${DIM}  (under ${excl_reasons[$item]})${NC}" | tee -a "$LOG_FILE"
            done
            echo "" | tee -a "$LOG_FILE"
        fi

        # Excluded by EXCLUDE_PATTERNS (yellow)
        if [[ ${#grp_excluded_pat[@]} -gt 0 ]]; then
            echo -e "${YELLOW}── Excluded by EXCLUDE_PATTERNS (${#grp_excluded_pat[@]}) ──${NC}" | tee -a "$LOG_FILE"
            for item in "${grp_excluded_pat[@]}"; do
                echo -e "  ${YELLOW}${item}${DIM}  (matches \"${excl_reasons[$item]}\")${NC}" | tee -a "$LOG_FILE"
            done
            echo "" | tee -a "$LOG_FILE"
        fi

        # Daily limit reached (dim)
        _print_group "Daily limit reached ($MAX_DAILY/day)" "$DIM" "${grp_daily_limit[@]}"

        # Inactive (dim)
        if [[ ${#grp_inactive[@]} -gt 0 ]]; then
            _print_group "Inactive (no changes in ${ACTIVITY_HOURS}h)" "$DIM" "${grp_inactive[@]}"
        fi

        # Included (whitelist override, informational — green)
        if [[ ${#grp_included[@]} -gt 0 ]]; then
            echo -e "${GREEN}── Whitelisted via INCLUDE_DIRS (${#grp_included[@]}) ── overrides EXCLUDE_DIRS${NC}" | tee -a "$LOG_FILE"
            for item in "${grp_included[@]}"; do
                echo -e "  ${GREEN}${item}${NC}" | tee -a "$LOG_FILE"
            done
            echo "" | tee -a "$LOG_FILE"
        fi

        # Active — will process (green)
        _print_group "Active — will process" "$GREEN" "${grp_active[@]}"

        # ── Phase 3: Process active projects ───────────────────────────
        local processed=0
        for proj in "${grp_active[@]}"; do
            process_project "$proj"
            processed=$((processed + 1))
        done

        local skipped=$((total - ${#grp_active[@]}))
        log_info "=== Finished: $processed processed, $skipped skipped ==="
    fi

    # Show review summary if there are items needing human attention
    if [[ -f "$REVIEW_FILE" ]] && [[ -s "$REVIEW_FILE" ]]; then
        local review_count
        review_count=$(grep -c '^### \[' "$REVIEW_FILE" 2>/dev/null || echo 0)
        if [[ "$review_count" -gt 0 ]]; then
            log_warn "⚡ $review_count item(s) need human review: $REVIEW_FILE"
        fi
    fi

    log_info "=== Claude Maintain ended $(date '+%Y-%m-%d %H:%M:%S') ==="
}

main "$@"
