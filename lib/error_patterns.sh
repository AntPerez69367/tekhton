#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# error_patterns.sh — Declarative error pattern registry & classification engine
#
# Sourced by tekhton.sh — do not run directly.
# Provides: load_error_patterns(), classify_build_error(),
#           classify_build_errors_all(), get_pattern_count()
#
# Milestone 53: Error Pattern Registry & Build Gate Classification.
#
# Each registry entry: REGEX_PATTERN|CATEGORY|SAFETY|REMEDIATION_CMD|DIAGNOSIS
# Categories: env_setup, service_dep, toolchain, resource, test_infra, code
# Safety: safe, prompt, manual, code
# =============================================================================

# --- Pattern storage (parallel arrays) --------------------------------------
_EP_PATTERNS=()
_EP_CATEGORIES=()
_EP_SAFETIES=()
_EP_REMEDIATIONS=()
_EP_DIAGNOSES=()
_EP_LOADED=false

# --- _build_pattern_registry ------------------------------------------------
# Returns the heredoc registry. Patterns are ordered by specificity:
# more specific patterns BEFORE generic ones.
_build_pattern_registry() {
    cat <<'REGISTRY'
# --- Node.js / npm: environment setup ---
npx playwright install|env_setup|safe|npx playwright install|Playwright browsers not installed
npx cypress install|env_setup|safe|npx cypress install|Cypress binary not installed
PLAYWRIGHT_BROWSERS_PATH|env_setup|safe|npx playwright install|Playwright browser path not configured
Executable doesn't exist.*chrom|env_setup|safe|npx playwright install chromium|Browser binary missing (Chromium)
browser.*not found|env_setup|safe|npx playwright install|Browser binary not found
# --- Node.js / npm: toolchain ---
Cannot find module.*node_modules|toolchain|safe|npm install|Node module missing from node_modules
ERR_MODULE_NOT_FOUND|toolchain|safe|npm install|ES module not found
ENOENT.*node_modules|toolchain|safe|npm install|node_modules path missing
npm ERR! Missing|toolchain|safe|npm install|npm dependency missing
npm ERR! ERESOLVE|toolchain|safe|npm install --legacy-peer-deps|npm dependency resolution conflict
Cannot find module|toolchain|safe|npm install|Node module not found
# --- Python: environment setup ---
venv.*not found|env_setup|safe|python3 -m venv .venv|Python virtual environment missing
# --- Python: toolchain ---
ModuleNotFoundError|toolchain|safe|pip install -r requirements.txt|Python module not installed
ImportError.*No module|toolchain|safe|pip install -r requirements.txt|Python import failed — module not installed
No module named|toolchain|safe|pip install -r requirements.txt|Python module not found
# --- Go: toolchain ---
missing go\.sum entry|toolchain|safe|go mod download|Go module checksum missing
go: cannot find package|toolchain|safe|go mod download|Go package not found
cannot find package|toolchain|safe|go mod download|Go package not found
# --- Rust: code (compilation is code) ---
could not compile|code|code||Rust compilation error
unresolved import|code|code||Rust unresolved import
# --- Java/Kotlin: code ---
ClassNotFoundException|code|code||Java class not found at runtime
NoClassDefFoundError|code|code||Java class definition missing
BUILD FAILED|code|code||Build failed (Gradle/Maven)
# --- Database: service dependencies ---
ECONNREFUSED.*5432|service_dep|manual||PostgreSQL not running (port 5432)
ECONNREFUSED.*3306|service_dep|manual||MySQL not running (port 3306)
ECONNREFUSED.*27017|service_dep|manual||MongoDB not running (port 27017)
ECONNREFUSED.*6379|service_dep|manual||Redis not running (port 6379)
connection refused.*database|service_dep|manual||Database connection refused
Connection refused.*localhost|service_dep|manual||Local service connection refused
# --- Docker ---
Cannot connect to the Docker daemon|service_dep|manual||Docker daemon not running
docker.*not found|env_setup|safe|docker --version|Docker not installed
# --- E2E / Browser ---
WebDriverError|env_setup|safe|npx playwright install|WebDriver error — browser setup needed
# --- Generated code ---
@prisma/client.*not.*generated|toolchain|safe|npx prisma generate|Prisma client not generated
prisma generate|toolchain|safe|npx prisma generate|Prisma codegen needed
protoc.*not found|env_setup|manual||Protocol Buffers compiler not installed
codegen.*not found|toolchain|prompt|npm run codegen|Code generation output missing
# --- Resource constraints ---
EADDRINUSE|resource|manual||Port already in use
ENOMEM|resource|manual||Out of memory
heap out of memory|resource|manual||JavaScript heap out of memory
ENOSPC|resource|manual||No disk space left
EACCES|resource|manual||Permission denied (EACCES)
Permission denied|resource|manual||Permission denied
# --- Test infrastructure ---
Snapshot.*obsolete|test_infra|prompt|npm test -- -u|Test snapshots are obsolete
snapshot.*mismatch|test_infra|prompt|npm test -- -u|Snapshot mismatch — may need update
TIMEOUT|test_infra|manual||Test timeout
fixture.*not found|test_infra|manual||Test fixture file missing
# --- Generic patterns (MUST be last — least specific) ---
command not found|env_setup|manual||Required command not installed
No such file or directory|code|code||File or directory not found
error TS[0-9]+:|code|code||TypeScript compilation error
SyntaxError:|code|code||Syntax error in source code
ReferenceError:|code|code||JavaScript reference error
TypeError:|code|code||Type error
REGISTRY
}

# --- load_error_patterns ----------------------------------------------------
# Parse the registry into parallel arrays. Cached: only loads once.
load_error_patterns() {
    if [[ "$_EP_LOADED" == "true" ]]; then
        return 0
    fi

    _EP_PATTERNS=()
    _EP_CATEGORIES=()
    _EP_SAFETIES=()
    _EP_REMEDIATIONS=()
    _EP_DIAGNOSES=()

    local line
    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue

        local pattern category safety remediation diagnosis
        pattern=$(echo "$line" | cut -d'|' -f1)
        category=$(echo "$line" | cut -d'|' -f2)
        safety=$(echo "$line" | cut -d'|' -f3)
        remediation=$(echo "$line" | cut -d'|' -f4)
        diagnosis=$(echo "$line" | cut -d'|' -f5)

        [[ -z "$pattern" ]] && continue

        _EP_PATTERNS+=("$pattern")
        _EP_CATEGORIES+=("$category")
        _EP_SAFETIES+=("$safety")
        _EP_REMEDIATIONS+=("$remediation")
        _EP_DIAGNOSES+=("$diagnosis")
    done < <(_build_pattern_registry)

    _EP_LOADED=true
}

# --- get_pattern_count ------------------------------------------------------
# Returns the number of loaded patterns.
get_pattern_count() {
    load_error_patterns
    echo "${#_EP_PATTERNS[@]}"
}

# --- classify_build_error ---------------------------------------------------
# Takes error output string, returns FIRST matching classification.
# Output: CATEGORY|SAFETY|REMEDIATION_CMD|DIAGNOSIS
# Falls back to code|code||Unclassified build error if no match.
#
# Usage: classify_build_error "error text line"
classify_build_error() {
    local error_text="${1:-}"
    [[ -z "$error_text" ]] && { echo "code|code||Empty error input"; return 0; }

    load_error_patterns

    local i
    for i in "${!_EP_PATTERNS[@]}"; do
        if printf '%s\n' "$error_text" | grep -qiE "${_EP_PATTERNS[$i]}" 2>/dev/null; then
            echo "${_EP_CATEGORIES[$i]}|${_EP_SAFETIES[$i]}|${_EP_REMEDIATIONS[$i]}|${_EP_DIAGNOSES[$i]}"
            return 0
        fi
    done

    echo "code|code||Unclassified build error"
}

# --- classify_build_errors_all ----------------------------------------------
# Returns ALL matching patterns from multi-line error output.
# Processes line-by-line with deduplication by category+diagnosis.
# Output: one CATEGORY|SAFETY|REMEDIATION_CMD|DIAGNOSIS line per unique match.
#
# Usage: classify_build_errors_all "$multi_line_error_output"
classify_build_errors_all() {
    local error_output="${1:-}"
    [[ -z "$error_output" ]] && return 0

    load_error_patterns

    # Track seen classifications to deduplicate
    local -A _seen=()
    local line i key

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local matched=false
        for i in "${!_EP_PATTERNS[@]}"; do
            if printf '%s\n' "$line" | grep -qiE "${_EP_PATTERNS[$i]}" 2>/dev/null; then
                key="${_EP_CATEGORIES[$i]}|${_EP_DIAGNOSES[$i]}"
                if [[ -z "${_seen[$key]+x}" ]]; then
                    _seen[$key]=1
                    echo "${_EP_CATEGORIES[$i]}|${_EP_SAFETIES[$i]}|${_EP_REMEDIATIONS[$i]}|${_EP_DIAGNOSES[$i]}"
                fi
                matched=true
                break  # First match per line, then next line
            fi
        done

        # Unmatched lines default to code category (only emit once)
        if [[ "$matched" == "false" ]]; then
            key="code|Unclassified: ${line:0:80}"
            if [[ -z "${_seen[$key]+x}" ]]; then
                _seen[$key]=1
                echo "code|code||Unclassified build error"
            fi
        fi
    done <<< "$error_output"
}

# --- filter_code_errors -----------------------------------------------------
# Filters BUILD_ERRORS.md content to extract only code-category errors.
# Returns a markdown block with non-code errors summarized and code errors
# preserved in full.
#
# Usage: filter_code_errors "$build_errors_content"
filter_code_errors() {
    local content="${1:-}"
    [[ -z "$content" ]] && return 0

    load_error_patterns

    local code_lines="" non_code_summaries=""
    local line

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local is_code=true
        local i
        for i in "${!_EP_PATTERNS[@]}"; do
            if printf '%s\n' "$line" | grep -qiE "${_EP_PATTERNS[$i]}" 2>/dev/null; then
                if [[ "${_EP_CATEGORIES[$i]}" != "code" ]]; then
                    is_code=false
                    local _diag="${_EP_DIAGNOSES[$i]}"
                    local _cat="${_EP_CATEGORIES[$i]}"
                    non_code_summaries+="- ${_cat}: ${_diag}"$'\n'
                fi
                break
            fi
        done

        if [[ "$is_code" == "true" ]]; then
            code_lines+="${line}"$'\n'
        fi
    done <<< "$content"

    # Emit filtered output
    if [[ -n "$non_code_summaries" ]]; then
        echo "## Already Handled (not code errors)"
        # Deduplicate summary lines
        echo "$non_code_summaries" | sort -u
        echo ""
    fi

    if [[ -n "$code_lines" ]]; then
        echo "## Code Errors to Fix"
        echo "$code_lines"
    fi
}

# --- annotate_build_errors --------------------------------------------------
# Takes raw error output and stage label, returns annotated BUILD_ERRORS.md
# content with classification headers.
#
# Usage: annotate_build_errors "$raw_output" "$stage_label"
annotate_build_errors() {
    local raw_output="${1:-}"
    local stage_label="${2:-unknown}"

    load_error_patterns

    local classifications
    classifications=$(classify_build_errors_all "$raw_output")

    local has_env=false has_code=false
    local classification_block=""
    local env_count=0 code_count=0

    while IFS='|' read -r cat safety remed diag; do
        [[ -z "$cat" ]] && continue
        if [[ "$cat" == "code" ]]; then
            has_code=true
            code_count=$((code_count + 1))
            classification_block+="- **${cat}** (${safety}): ${diag}"$'\n'
        else
            has_env=true
            env_count=$((env_count + 1))
            if [[ -n "$remed" ]]; then
                classification_block+="- **${cat}** (${safety}): ${diag}"$'\n'
                classification_block+="  -> Auto-fix: \`${remed}\`"$'\n'
            else
                classification_block+="- **${cat}** (${safety}): ${diag}"$'\n'
            fi
        fi
    done <<< "$classifications"

    # Build annotated output
    echo "# Build Errors — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "## Stage"
    echo "${stage_label}"
    echo ""

    if [[ -n "$classification_block" ]]; then
        echo "## Error Classification"
        printf '%s' "$classification_block"
        echo ""
    fi

    if [[ "$has_env" == "true" ]]; then
        echo "## Classified as Environment/Setup (${env_count} issue(s))"
    fi
    if [[ "$has_code" == "true" ]]; then
        echo "## Classified as Code Error (${code_count} issue(s))"
    fi
}

# --- has_only_noncode_errors ------------------------------------------------
# Returns 0 if ALL classifications are non-code, 1 otherwise.
#
# Usage: has_only_noncode_errors "$raw_error_output"
has_only_noncode_errors() {
    local raw_output="${1:-}"
    [[ -z "$raw_output" ]] && return 1

    local classifications
    classifications=$(classify_build_errors_all "$raw_output")

    while IFS='|' read -r cat _safety _remed _diag; do
        [[ -z "$cat" ]] && continue
        if [[ "$cat" == "code" ]]; then
            return 1
        fi
    done <<< "$classifications"

    return 0
}
