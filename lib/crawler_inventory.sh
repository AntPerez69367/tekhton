#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# crawler_inventory.sh — File inventory, config inventory, test structure
#
# Sourced by crawler.sh — do not run directly.
# Depends on: common.sh (log, warn), crawler.sh (_CRAWL_EXCLUDE_DIRS,
#             _list_tracked_files)
# =============================================================================

# --- Helpers -----------------------------------------------------------------

# _count_files_in_dir — Count files in file_list matching a directory prefix.
# Args: $1 = newline-delimited file list, $2 = directory prefix
# Returns: integer count (0 if no matches)
_count_files_in_dir() {
    echo "$1" | grep -c "^${2}" || true
}

# --- File inventory -----------------------------------------------------------

# _crawl_file_inventory — Catalogues tracked files with size and grouping.
# Args: $1 = project directory, $2 = file list (optional, avoids re-listing)
# Output: Markdown table grouped by directory
_crawl_file_inventory() {
    local project_dir="$1"
    local file_list="${2:-}"
    [[ -z "$file_list" ]] && file_list=$(_list_tracked_files "$project_dir")

    [[ -z "$file_list" ]] && { echo "(no files found)"; return 0; }

    # Batch line counting for performance
    local -A file_lines=()
    local line_data f

    # Use xargs + wc for batched line counting
    line_data=$(echo "$file_list" | while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        local full="${project_dir}/${f}"
        if [[ -f "$full" ]]; then
            printf '%s\n' "$full"
        fi
    done | xargs wc -l 2>/dev/null | grep -v ' total$' || true)

    # Parse wc output into associative array
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local count path
        count=$(echo "$line" | awk '{print $1}')
        path=$(echo "$line" | awk '{$1=""; print substr($0,2)}')
        # Strip project_dir prefix
        local rel="${path#"${project_dir}/"}"
        file_lines["$rel"]="$count"
    done <<< "$line_data"

    # Group by directory
    local output=""
    local prev_dir=""

    output+="| Path | Lines | Size |"$'\n'
    output+="| ---- | ----: | ---- |"$'\n'

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        local dir="${f%/*}"
        [[ "$dir" == "$f" ]] && dir="."
        local lines="${file_lines[$f]:-0}"
        local size_cat

        if [[ "$lines" -lt 50 ]]; then size_cat="tiny"
        elif [[ "$lines" -lt 200 ]]; then size_cat="small"
        elif [[ "$lines" -lt 500 ]]; then size_cat="medium"
        elif [[ "$lines" -lt 1000 ]]; then size_cat="large"
        else size_cat="huge"
        fi

        # Directory separator
        if [[ "$dir" != "$prev_dir" ]]; then
            [[ -n "$prev_dir" ]] && output+=$'\n'
            output+="| **${dir}/** | | |"$'\n'
            prev_dir="$dir"
        fi

        output+="| ${f} | ${lines} | ${size_cat} |"$'\n'
    done < <(echo "$file_list" | sort)

    printf '%s' "$output"
}

# --- Config purpose helper (shared by markdown and JSON emitters) ------------

# _config_purpose — Returns a purpose annotation for a known config file.
# Args: $1 = file path (relative)
# Output: purpose string, or empty if not a recognized config file
_config_purpose() {
    local f="$1"
    local base
    base=$(basename "$f")
    case "$base" in
        .gitignore)           echo "Git ignore rules" ;;
        .gitattributes)       echo "Git attributes" ;;
        .editorconfig)        echo "Editor configuration" ;;
        .eslintrc*|.eslintignore) echo "ESLint configuration" ;;
        .prettierrc*|.prettierignore) echo "Prettier code formatter" ;;
        tsconfig*.json)       echo "TypeScript configuration" ;;
        jest.config*|vitest.config*) echo "Test framework configuration" ;;
        webpack.config*)      echo "Webpack bundler configuration" ;;
        vite.config*)         echo "Vite build configuration" ;;
        rollup.config*)       echo "Rollup bundler configuration" ;;
        babel.config*|.babelrc*) echo "Babel transpiler configuration" ;;
        Dockerfile*)          echo "Docker container definition" ;;
        docker-compose*)      echo "Docker Compose orchestration" ;;
        .dockerignore)        echo "Docker ignore rules" ;;
        Makefile|makefile)    echo "Make build system" ;;
        CMakeLists.txt)       echo "CMake build system" ;;
        .env.example|.env.template|.env.sample) echo "Environment variable template" ;;
        pyproject.toml)       echo "Python project configuration" ;;
        setup.py|setup.cfg)   echo "Python package setup" ;;
        package.json)         echo "Node.js package manifest" ;;
        Cargo.toml)           echo "Rust crate manifest" ;;
        go.mod)               echo "Go module definition" ;;
        Gemfile)              echo "Ruby dependencies" ;;
        pubspec.yaml)         echo "Dart/Flutter package manifest" ;;
        composer.json)        echo "PHP package manifest" ;;
        build.gradle*)        echo "Gradle build configuration" ;;
        pom.xml)              echo "Maven build configuration" ;;
        *.csproj)             echo ".NET project file" ;;
        *.sln)                echo ".NET solution file" ;;
        renovate.json|.renovaterc*) echo "Renovate dependency updater" ;;
        .github/*)            echo "GitHub Actions / configuration" ;;
        .gitlab-ci.yml)       echo "GitLab CI pipeline" ;;
        .circleci/*)          echo "CircleCI pipeline" ;;
        Jenkinsfile)          echo "Jenkins pipeline" ;;
        .travis.yml)          echo "Travis CI configuration" ;;
        tox.ini)              echo "Python tox test runner" ;;
        .flake8)              echo "Python flake8 linter" ;;
        ruff.toml|.ruff.toml) echo "Python Ruff linter" ;;
        clippy.toml)          echo "Rust Clippy linter" ;;
        rustfmt.toml|.rustfmt.toml) echo "Rust formatter" ;;
        .shellcheckrc)        echo "ShellCheck configuration" ;;
        .yamllint*)           echo "YAML linter" ;;
        nginx.conf|apache.conf) echo "Web server configuration" ;;
        fly.toml)             echo "Fly.io deployment" ;;
        vercel.json)          echo "Vercel deployment" ;;
        netlify.toml)         echo "Netlify deployment" ;;
        *)
            case "$f" in
                .github/*) echo "GitHub configuration" ;;
                .circleci/*) echo "CircleCI configuration" ;;
            esac
            ;;
    esac
}

# --- Config inventory ---------------------------------------------------------

# _crawl_config_inventory — Lists configuration files with purpose annotations.
# Args: $1 = project directory, $2 = file list (optional)
_crawl_config_inventory() {
    local project_dir="$1"
    local output=""
    local file_list="${2:-}"
    [[ -z "$file_list" ]] && file_list=$(_list_tracked_files "$project_dir")

    output+="| File | Purpose |"$'\n'
    output+="| ---- | ------- |"$'\n'

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        local purpose
        purpose=$(_config_purpose "$f")
        [[ -z "$purpose" ]] && continue
        output+="| ${f} | ${purpose} |"$'\n'
    done < <(echo "$file_list" | sort)

    printf '%s' "$output"
}

# --- Test structure -----------------------------------------------------------

# _crawl_test_structure — Identifies test directory layout and framework.
# Args: $1 = project directory, $2 = file list (optional)
_crawl_test_structure() {
    local project_dir="$1"
    local output=""
    local file_list="${2:-}"
    [[ -z "$file_list" ]] && file_list=$(_list_tracked_files "$project_dir")

    # Find test directories
    local test_dirs
    test_dirs=$(echo "$file_list" | grep -oE '^[^/]+/' | sort -u | \
        grep -iE '^(tests?|spec|__tests__|e2e|integration|cypress)/' || true)

    output+="### Test Directories"$'\n\n'
    if [[ -n "$test_dirs" ]]; then
        while IFS= read -r d; do
            [[ -z "$d" ]] && continue
            local count
            count=$(_count_files_in_dir "$file_list" "$d")
            output+="- \`${d}\` (${count} files)"$'\n'
        done <<< "$test_dirs"
    else
        output+="(no dedicated test directories found)"$'\n'
    fi

    # Count test files (including inline)
    local test_file_count
    test_file_count=$(echo "$file_list" | \
        grep -cE '\.(test|spec)\.[^.]+$|_test\.[^.]+$|test_[^/]+\.[^.]+$' || true)
    [[ -z "$test_file_count" ]] && test_file_count=0
    output+=$'\n'"### Test File Count"$'\n\n'
    output+="Total test files: ${test_file_count}"$'\n'

    # Detect test framework
    output+=$'\n'"### Test Framework"$'\n\n'
    local frameworks_found=false
    if [[ -f "${project_dir}/package.json" ]]; then
        local deps
        deps=$(cat "${project_dir}/package.json" 2>/dev/null)
        echo "$deps" | grep -q '"jest"'    && { output+="- Jest (JavaScript/TypeScript)"$'\n'; frameworks_found=true; }
        echo "$deps" | grep -q '"vitest"'  && { output+="- Vitest (JavaScript/TypeScript)"$'\n'; frameworks_found=true; }
        echo "$deps" | grep -q '"mocha"'   && { output+="- Mocha (JavaScript)"$'\n'; frameworks_found=true; }
        echo "$deps" | grep -q '"cypress"' && { output+="- Cypress (E2E)"$'\n'; frameworks_found=true; }
        echo "$deps" | grep -q '"playwright"' && { output+="- Playwright (E2E)"$'\n'; frameworks_found=true; }
    fi
    if [[ -f "${project_dir}/pytest.ini" ]] || [[ -f "${project_dir}/conftest.py" ]] || \
        grep -q 'pytest' "${project_dir}/pyproject.toml" 2>/dev/null; then
        output+="- pytest (Python)"$'\n'
        frameworks_found=true
    fi
    [[ -f "${project_dir}/Cargo.toml" ]] && \
        { output+="- cargo test (Rust built-in)"$'\n'; frameworks_found=true; }
    echo "$file_list" | grep -q '_test\.go$' && \
        { output+="- go test (Go built-in)"$'\n'; frameworks_found=true; }

    if [[ "$frameworks_found" != true ]]; then
        output+="(no test framework detected)"$'\n'
    fi

    # Coverage configuration
    output+=$'\n'"### Coverage"$'\n\n'
    local coverage_found=false
    if [[ -f "${project_dir}/.nycrc" ]] || [[ -f "${project_dir}/.nycrc.json" ]]; then
        output+="- NYC/Istanbul coverage configured"$'\n'
        coverage_found=true
    fi
    if [[ -f "${project_dir}/.coveragerc" ]] || [[ -f "${project_dir}/coverage.xml" ]]; then
        output+="- Python coverage configured"$'\n'
        coverage_found=true
    fi
    echo "$file_list" | grep -q 'codecov\|coveralls' && \
        { output+="- CI coverage reporting detected"$'\n'; coverage_found=true; }

    if [[ "$coverage_found" != true ]]; then
        output+="(no coverage configuration found)"$'\n'
    fi

    printf '%s' "$output"
}

# Source emitter functions from separate file (keeps crawler_inventory.sh under 300 lines)
# shellcheck source=lib/crawler_inventory_emitters.sh
source "${BASH_SOURCE[0]%/*}/crawler_inventory_emitters.sh"
