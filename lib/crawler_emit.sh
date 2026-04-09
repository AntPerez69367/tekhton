#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# crawler_emit.sh — Structured index emitters (Milestone 67)
#
# Writes structured data files to .claude/index/ during a project crawl.
# Each emitter writes to a temp file then atomically moves to final path.
#
# Sourced by crawler.sh — do not run directly.
# Depends on: crawler.sh (_list_tracked_files, _crawl_directory_tree,
#             _annotate_directories, _truncate_section, _budget_allocator,
#             _build_index_header), crawler_inventory.sh (_crawl_file_inventory,
#             _crawl_config_inventory, _crawl_test_structure, _config_purpose),
#             crawler_content.sh (_add_candidate, _is_binary_file,
#             _read_sampled_file, _crawl_sample_files),
#             crawler_deps.sh (_crawl_dependency_graph),
#             detect.sh (_extract_json_keys)
# =============================================================================

# --- JSON helpers -------------------------------------------------------------

# _json_escape — Escapes a string for safe embedding in JSON values.
# Handles: backslash, double-quote, tab, newline, carriage return.
_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    printf '%s' "$s"
}

# --- Directory setup ----------------------------------------------------------

# _ensure_index_dir — Creates the structured index directory and samples subdir.
_ensure_index_dir() {
    local index_dir="$1"
    mkdir -p "${index_dir}/samples"
}

# --- Tree emitter -------------------------------------------------------------

# _emit_tree_txt — Writes complete directory tree to .claude/index/tree.txt.
# No truncation — full output preserved. M69 view generator handles display limits.
_emit_tree_txt() {
    local project_dir="$1" index_dir="$2"
    local tmp_file
    tmp_file=$(mktemp "${index_dir}/tree_XXXXXXXX")
    _crawl_directory_tree "$project_dir" 6 > "$tmp_file"
    printf '\n' >> "$tmp_file"
    mv "$tmp_file" "${index_dir}/tree.txt"
}

# --- Inventory emitter --------------------------------------------------------

# _emit_inventory_jsonl — Writes one JSONL record per tracked file.
# Fix for issue #4: writes directly to file (no O(n^2) string concatenation).
# Args: $1=project_dir, $2=file_list, $3=index_dir
_emit_inventory_jsonl() {
    local project_dir="$1" file_list="$2" index_dir="$3"
    local tmp_file
    tmp_file=$(mktemp "${index_dir}/inv_XXXXXXXX")

    if [[ -z "$file_list" ]]; then
        : > "$tmp_file"
        mv "$tmp_file" "${index_dir}/inventory.jsonl"
        return 0
    fi

    # Batch line counting (same xargs pattern as _crawl_file_inventory)
    local -A file_lines=()
    local line_data
    line_data=$(printf '%s\n' "$file_list" | while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        [[ -f "${project_dir}/${f}" ]] && printf '%s\n' "${project_dir}/${f}"
    done | xargs wc -l 2>/dev/null | grep -v ' total$' || true)

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local count path
        count=$(printf '%s' "$line" | awk '{print $1}')
        path=$(printf '%s' "$line" | awk '{$1=""; print substr($0,2)}')
        file_lines["${path#"${project_dir}/"}"]="$count"
    done <<< "$line_data"

    # Write JSONL — one record per file, directly to temp file
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
        else size_cat="huge"; fi
        printf '{"path":"%s","dir":"%s","lines":%s,"size":"%s"}\n' \
            "$(_json_escape "$f")" "$(_json_escape "$dir")" "$lines" "$size_cat"
    done <<< "$file_list" > "$tmp_file"

    mv "$tmp_file" "${index_dir}/inventory.jsonl"
}

# --- Dependencies emitter -----------------------------------------------------

# _emit_dependencies_json — Writes dependency manifest data as JSON.
# Args: $1=project_dir, $2=index_dir
_emit_dependencies_json() {
    local project_dir="$1" index_dir="$2"
    local tmp_m tmp_d tmp_f
    tmp_m=$(mktemp) tmp_d=$(mktemp)
    tmp_f=$(mktemp "${index_dir}/deps_XXXXXXXX")

    # --- package.json ---
    if [[ -f "${project_dir}/package.json" ]]; then
        local deps_out dev_out dc=0 ddc=0
        deps_out=$(_extract_json_keys "${project_dir}/package.json" '"dependencies"')
        dev_out=$(_extract_json_keys "${project_dir}/package.json" '"devDependencies"')
        [[ -n "$deps_out" ]] && dc=$(printf '%s\n' "$deps_out" | grep -c ':' || true)
        [[ -n "$dev_out" ]] && ddc=$(printf '%s\n' "$dev_out" | grep -c ':' || true)
        printf '{"file":"package.json","manager":"npm","deps":%d,"dev_deps":%d}\n' "$dc" "$ddc" >> "$tmp_m"
        { printf '%s\n' "$deps_out"; printf '%s\n' "$dev_out"; } | while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local pkg ver
            pkg=$(printf '%s' "$line" | sed -n 's/.*"\([^"]*\)"\s*:.*/\1/p')
            ver=$(printf '%s' "$line" | sed -n 's/.*:\s*"\([^"]*\)".*/\1/p')
            [[ -n "$pkg" ]] && printf '{"name":"%s","version":"%s","manifest":"package.json"}\n' \
                "$(_json_escape "$pkg")" "$(_json_escape "$ver")" >> "$tmp_d"
        done
    fi

    # --- Cargo.toml ---
    if [[ -f "${project_dir}/Cargo.toml" ]]; then
        local section="" cdc=0 cddc=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[dependencies\] ]]; then section="deps"; continue; fi
            if [[ "$line" =~ ^\[dev-dependencies\] ]]; then section="dev"; continue; fi
            [[ "$line" =~ ^\[ ]] && { section=""; continue; }
            [[ -z "$section" || -z "$line" ]] && continue
            local crate ver=""
            if [[ "$line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
                crate="${BASH_REMATCH[1]}"; ver="${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]*= ]]; then
                crate="${BASH_REMATCH[1]}"
                ver=$(printf '%s' "$line" | sed -n 's/.*version\s*=\s*"\([^"]*\)".*/\1/p')
                [[ -z "$ver" ]] && ver="workspace"
            else continue; fi
            [[ "$section" == "deps" ]] && cdc=$((cdc+1)) || cddc=$((cddc+1))
            printf '{"name":"%s","version":"%s","manifest":"Cargo.toml"}\n' \
                "$(_json_escape "$crate")" "$(_json_escape "$ver")" >> "$tmp_d"
        done < "${project_dir}/Cargo.toml"
        printf '{"file":"Cargo.toml","manager":"cargo","deps":%d,"dev_deps":%d}\n' "$cdc" "$cddc" >> "$tmp_m"
    fi

    # --- pyproject.toml ---
    if [[ -f "${project_dir}/pyproject.toml" ]]; then
        local in_deps=false pdc=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^dependencies[[:space:]]*= ]]; then in_deps=true; continue; fi
            [[ "$in_deps" == true && "$line" =~ ^\] ]] && { in_deps=false; continue; }
            [[ "$in_deps" != true || -z "$line" ]] && continue
            local pkg="${line#"${line%%[![:space:]\"]*}"}"
            pkg="${pkg%%[^a-zA-Z0-9_-]*}"
            [[ -z "$pkg" ]] && continue
            local constraint
            constraint=$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"[a-zA-Z0-9_-]*\([^"]*\)".*/\1/p')
            pdc=$((pdc+1))
            printf '{"name":"%s","version":"%s","manifest":"pyproject.toml"}\n' \
                "$(_json_escape "$pkg")" "$(_json_escape "${constraint:-any}")" >> "$tmp_d"
        done < "${project_dir}/pyproject.toml"
        printf '{"file":"pyproject.toml","manager":"pip","deps":%d,"dev_deps":0}\n' "$pdc" >> "$tmp_m"
    fi

    # --- go.mod ---
    if [[ -f "${project_dir}/go.mod" ]]; then
        local in_req=false gdc=0
        while IFS= read -r line; do
            [[ "$line" =~ ^require[[:space:]]*\( ]] && { in_req=true; continue; }
            [[ "$line" =~ ^\) ]] && { in_req=false; continue; }
            [[ "$in_req" != true || -z "$line" ]] && continue
            local mod ver
            mod=$(printf '%s' "$line" | awk '{print $1}')
            ver=$(printf '%s' "$line" | awk '{print $2}')
            [[ -z "$mod" ]] && continue
            gdc=$((gdc+1))
            printf '{"name":"%s","version":"%s","manifest":"go.mod"}\n' \
                "$(_json_escape "$mod")" "$(_json_escape "$ver")" >> "$tmp_d"
        done < "${project_dir}/go.mod"
        printf '{"file":"go.mod","manager":"go","deps":%d,"dev_deps":0}\n' "$gdc" >> "$tmp_m"
    fi

    # --- Gemfile ---
    if [[ -f "${project_dir}/Gemfile" ]]; then
        local rdc=0
        while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*gem[[:space:]] ]] || continue
            local gem ver
            gem=$(printf '%s' "$line" | sed -n "s/.*gem[[:space:]]*['\"]\\([^'\"]*\\)['\"].*/\\1/p")
            ver=$(printf '%s' "$line" | sed -n "s/.*gem[[:space:]]*['\"][^'\"]*['\"][[:space:]]*,[[:space:]]*['\"]\\([^'\"]*\\)['\"].*/\\1/p")
            [[ -z "$gem" ]] && continue
            rdc=$((rdc+1))
            printf '{"name":"%s","version":"%s","manifest":"Gemfile"}\n' \
                "$(_json_escape "$gem")" "$(_json_escape "${ver:-any}")" >> "$tmp_d"
        done < "${project_dir}/Gemfile"
        printf '{"file":"Gemfile","manager":"bundler","deps":%d,"dev_deps":0}\n' "$rdc" >> "$tmp_m"
    fi

    # --- Gradle ---
    local gradle_file=""
    [[ -f "${project_dir}/build.gradle.kts" ]] && gradle_file="${project_dir}/build.gradle.kts"
    [[ -f "${project_dir}/build.gradle" ]] && gradle_file="${project_dir}/build.gradle"
    if [[ -n "$gradle_file" ]]; then
        local gname gdc2=0
        gname=$(basename "$gradle_file")
        while IFS= read -r line; do
            [[ "$line" =~ implementation|api|testImplementation|compileOnly ]] || continue
            local dep
            dep=$(printf '%s' "$line" | sed -n "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/p" | head -1)
            [[ -z "$dep" ]] && continue
            gdc2=$((gdc2+1))
            printf '{"name":"%s","version":"","manifest":"%s"}\n' \
                "$(_json_escape "$dep")" "$gname" >> "$tmp_d"
        done < "$gradle_file"
        printf '{"file":"%s","manager":"gradle","deps":%d,"dev_deps":0}\n' "$gname" "$gdc2" >> "$tmp_m"
    fi

    # --- pom.xml ---
    if [[ -f "${project_dir}/pom.xml" ]]; then
        local group="" artifact="" mdc=0
        while IFS= read -r line; do
            local trimmed="${line#"${line%%[![:space:]]*}"}"
            if [[ "$trimmed" =~ \<groupId\>(.*)\</groupId\> ]]; then group="${BASH_REMATCH[1]}"
            elif [[ "$trimmed" =~ \<artifactId\>(.*)\</artifactId\> ]]; then
                artifact="${BASH_REMATCH[1]}"
                if [[ -n "$group" ]]; then
                    mdc=$((mdc+1))
                    printf '{"name":"%s:%s","version":"","manifest":"pom.xml"}\n' \
                        "$(_json_escape "$group")" "$(_json_escape "$artifact")" >> "$tmp_d"
                    group="" artifact=""
                fi
            fi
        done < "${project_dir}/pom.xml"
        printf '{"file":"pom.xml","manager":"maven","deps":%d,"dev_deps":0}\n' "$mdc" >> "$tmp_m"
    fi

    # Assemble JSON from temp files
    {
        printf '{\n  "manifests": ['
        local first=true
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            [[ "$first" != true ]] && printf ','
            printf '\n    %s' "$line"; first=false
        done < "$tmp_m"
        printf '\n  ],\n  "key_dependencies": ['
        first=true
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            [[ "$first" != true ]] && printf ','
            printf '\n    %s' "$line"; first=false
        done < "$tmp_d"
        printf '\n  ]\n}\n'
    } > "$tmp_f"
    rm -f "$tmp_m" "$tmp_d"
    mv "$tmp_f" "${index_dir}/dependencies.json"
}

# --- Configs emitter ----------------------------------------------------------

# _emit_configs_json — Writes config file inventory as JSON.
# Args: $1=project_dir, $2=file_list, $3=index_dir
_emit_configs_json() {
    local project_dir="$1" file_list="$2" index_dir="$3"
    local tmp_file
    tmp_file=$(mktemp "${index_dir}/configs_XXXXXXXX")
    {
        printf '{\n  "configs": ['
        local first=true
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            local purpose
            purpose=$(_config_purpose "$f")
            [[ -z "$purpose" ]] && continue
            [[ "$first" != true ]] && printf ','
            printf '\n    {"path":"%s","purpose":"%s"}' \
                "$(_json_escape "$f")" "$(_json_escape "$purpose")"
            first=false
        done < <(printf '%s\n' "$file_list" | sort)
        printf '\n  ]\n}\n'
    } > "$tmp_file"
    mv "$tmp_file" "${index_dir}/configs.json"
}

# --- Tests emitter ------------------------------------------------------------

# _emit_tests_json — Writes test infrastructure data as JSON.
# Args: $1=project_dir, $2=file_list, $3=index_dir
_emit_tests_json() {
    local project_dir="$1" file_list="$2" index_dir="$3"
    local tmp_file
    tmp_file=$(mktemp "${index_dir}/tests_XXXXXXXX")

    # Test directories
    local test_dirs
    test_dirs=$(printf '%s\n' "$file_list" | grep -oE '^[^/]+/' | sort -u | \
        grep -iE '^(tests?|spec|__tests__|e2e|integration|cypress)/' || true)

    # Test file count
    local test_file_count
    test_file_count=$(printf '%s\n' "$file_list" | \
        grep -cE '\.(test|spec)\.[^.]+$|_test\.[^.]+$|test_[^/]+\.[^.]+$' || true)
    [[ -z "$test_file_count" ]] && test_file_count=0

    # Detect frameworks
    local -a frameworks=()
    if [[ -f "${project_dir}/package.json" ]]; then
        local pdeps
        pdeps=$(cat "${project_dir}/package.json" 2>/dev/null)
        echo "$pdeps" | grep -q '"jest"' && frameworks+=("jest")
        echo "$pdeps" | grep -q '"vitest"' && frameworks+=("vitest")
        echo "$pdeps" | grep -q '"mocha"' && frameworks+=("mocha")
        echo "$pdeps" | grep -q '"cypress"' && frameworks+=("cypress")
        echo "$pdeps" | grep -q '"playwright"' && frameworks+=("playwright")
    fi
    if [[ -f "${project_dir}/pytest.ini" ]] || [[ -f "${project_dir}/conftest.py" ]] || \
        grep -q 'pytest' "${project_dir}/pyproject.toml" 2>/dev/null; then
        frameworks+=("pytest")
    fi
    [[ -f "${project_dir}/Cargo.toml" ]] && frameworks+=("cargo-test")
    printf '%s\n' "$file_list" | grep -q '_test\.go$' && frameworks+=("go-test")

    # Detect coverage
    local -a coverage=()
    [[ -f "${project_dir}/.nycrc" || -f "${project_dir}/.nycrc.json" ]] && coverage+=("nyc")
    [[ -f "${project_dir}/.coveragerc" || -f "${project_dir}/coverage.xml" ]] && coverage+=("python-coverage")
    printf '%s\n' "$file_list" | grep -q 'codecov\|coveralls' && coverage+=("ci-coverage")

    # Assemble JSON
    {
        printf '{\n  "test_dirs": ['
        local first=true
        while IFS= read -r d; do
            [[ -z "$d" ]] && continue
            local cnt
            cnt=$(_count_files_in_dir "$file_list" "$d")
            [[ "$first" != true ]] && printf ','
            printf '\n    {"path":"%s","file_count":%d}' "$(_json_escape "$d")" "$cnt"
            first=false
        done <<< "$test_dirs"
        printf '\n  ],\n  "test_file_count": %d,\n  "frameworks": [' "$test_file_count"
        first=true
        for fw in "${frameworks[@]+"${frameworks[@]}"}"; do
            [[ "$first" != true ]] && printf ','
            printf '"%s"' "$fw"; first=false
        done
        printf '],\n  "coverage": ['
        first=true
        for cov in "${coverage[@]+"${coverage[@]}"}"; do
            [[ "$first" != true ]] && printf ','
            printf '"%s"' "$cov"; first=false
        done
        printf ']\n}\n'
    } > "$tmp_file"
    mv "$tmp_file" "${index_dir}/tests.json"
}

# --- Samples emitter ----------------------------------------------------------

# _emit_sampled_files — Writes individual sample files and a manifest.
# Args: $1=project_dir, $2=file_list, $3=index_dir, $4=budget_chars
_emit_sampled_files() {
    local project_dir="$1" file_list="$2" index_dir="$3" budget_chars="$4"
    local samples_dir="${index_dir}/samples"
    mkdir -p "$samples_dir"

    # Clean stale sample files from prior crawl
    rm -f "${samples_dir}"/*.txt

    local budget=$(( budget_chars * 55 / 100 ))
    local used=0 total_chars=0 manifest_entries=""

    # Build priority-ordered candidate list (same as _crawl_sample_files)
    local -a candidates=()
    _add_candidate candidates "$file_list" "README.md" "README.rst" "README" "README.txt"
    _add_candidate candidates "$file_list" "main.py" "app.py" "index.ts" "index.js" \
        "main.ts" "main.go" "main.rs" "lib.rs" "src/main.rs" "src/lib.rs" \
        "src/index.ts" "src/index.js" "src/app.ts" "src/app.js" "src/main.py" "cmd/main.go"
    _add_candidate candidates "$file_list" "package.json" "Cargo.toml" "pyproject.toml" \
        "go.mod" "Gemfile" "pubspec.yaml" "composer.json"
    _add_candidate candidates "$file_list" "ARCHITECTURE.md" "CONTRIBUTING.md" \
        "DESIGN.md" "docs/ARCHITECTURE.md" "docs/design.md"
    local test_file
    test_file=$(echo "$file_list" | grep -E '\.(test|spec)\.[^.]+$|_test\.[^.]+$' | head -1 || true)
    [[ -n "$test_file" ]] && candidates+=("$test_file")
    local src_file
    src_file=$(echo "$file_list" | grep -E '^src/.*\.(py|ts|js|go|rs|java|rb)$' | head -1 || true)
    [[ -n "$src_file" ]] && candidates+=("$src_file")

    local f
    for f in "${candidates[@]+"${candidates[@]}"}"; do
        [[ "$used" -ge "$budget" ]] && break
        local full_path="${project_dir}/${f}"
        [[ ! -f "$full_path" ]] && continue
        _is_binary_file "$full_path" && continue

        local remaining=$(( budget - used ))
        local content
        content=$(_read_sampled_file "$full_path" "$remaining")
        local content_size=${#content}
        [[ "$content_size" -eq 0 ]] && continue

        local stored_name="${f//\//__}.txt"
        printf '%s' "$content" > "${samples_dir}/${stored_name}"

        [[ -n "$manifest_entries" ]] && manifest_entries+=","
        manifest_entries+=$(printf '\n    {"original":"%s","stored":"%s","chars":%d}' \
            "$(_json_escape "$f")" "$(_json_escape "$stored_name")" "$content_size")
        used=$(( used + content_size + ${#f} + 20 ))
        total_chars=$(( total_chars + content_size ))
    done

    # Write samples manifest
    local tmp_file
    tmp_file=$(mktemp "${index_dir}/samples_m_XXXXXXXX")
    printf '{\n  "samples": [%s\n  ],\n  "total_chars": %d,\n  "budget_chars": %d\n}\n' \
        "$manifest_entries" "$total_chars" "$budget" > "$tmp_file"
    mv "$tmp_file" "${samples_dir}/manifest.json"
}

# --- Meta emitter -------------------------------------------------------------

# _emit_meta_json — Writes scan metadata JSON, reading counts from inventory.
# Must be called AFTER _emit_inventory_jsonl and _emit_tree_txt.
# Args: $1=project_dir, $2=index_dir, $3=doc_quality_score
_emit_meta_json() {
    local project_dir="$1" index_dir="$2" doc_quality_score="${3:-0}"
    local scan_date scan_commit project_name file_count total_lines tree_lines

    scan_date=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    project_name=$(basename "$project_dir")

    if git -C "$project_dir" rev-parse --git-dir &>/dev/null; then
        scan_commit=$(git -C "$project_dir" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    else
        scan_commit="non-git"
    fi

    # Read from inventory.jsonl (M67 fix: no per-file wc -l)
    file_count=0 total_lines=0
    if [[ -s "${index_dir}/inventory.jsonl" ]]; then
        file_count=$(wc -l < "${index_dir}/inventory.jsonl" | tr -d '[:space:]')
        total_lines=$(awk -F'"lines":' '{split($2,a,/[,}]/); s+=a[1]} END {print s+0}' \
            "${index_dir}/inventory.jsonl" 2>/dev/null || echo "0")
    fi

    tree_lines=0
    [[ -s "${index_dir}/tree.txt" ]] && \
        tree_lines=$(wc -l < "${index_dir}/tree.txt" | tr -d '[:space:]')

    local tmp_file
    tmp_file=$(mktemp "${index_dir}/meta_XXXXXXXX")
    printf '{\n  "schema_version": 1,\n  "project_name": "%s",\n  "scan_date": "%s",\n  "scan_commit": "%s",\n  "file_count": %d,\n  "total_lines": %d,\n  "tree_lines": %d,\n  "doc_quality_score": %s\n}\n' \
        "$(_json_escape "$project_name")" "$scan_date" "$scan_commit" \
        "$file_count" "$total_lines" "$tree_lines" "$doc_quality_score" > "$tmp_file"
    mv "$tmp_file" "${index_dir}/meta.json"
}

# --- Legacy bridge ------------------------------------------------------------

# _generate_legacy_index — Assembles PROJECT_INDEX.md from existing markdown
# producers for backward compatibility. Uses cached file_list to avoid
# redundant _list_tracked_files calls. Temporary — replaced by M69 view generator.
# Args: $1=project_dir, $2=file_list, $3=budget_chars, $4=index_file, $5=doc_quality_score
_generate_legacy_index() {
    local project_dir="$1" file_list="$2" budget_chars="$3"
    local index_file="$4" doc_quality_score="${5:-0}"

    # Generate sections using existing markdown producers (with cached file_list)
    local tree_section inventory_section dep_section config_section test_section
    tree_section=$(_crawl_directory_tree "$project_dir" 6)
    inventory_section=$(_crawl_file_inventory "$project_dir" "$file_list")
    dep_section=$(_crawl_dependency_graph "$project_dir")
    config_section=$(_crawl_config_inventory "$project_dir" "$file_list")
    test_section=$(_crawl_test_structure "$project_dir" "$file_list")

    # Budget allocation
    local remaining_budget
    remaining_budget=$(_budget_allocator "$budget_chars" \
        "${#tree_section}" "${#inventory_section}" "${#dep_section}" \
        "${#config_section}" "${#test_section}")

    local sample_section
    sample_section=$(_crawl_sample_files "$project_dir" "$file_list" "$remaining_budget")

    # Truncate sections
    tree_section=$(_truncate_section "$tree_section" $(( budget_chars * 10 / 100 )))
    inventory_section=$(_truncate_section "$inventory_section" $(( budget_chars * 15 / 100 )))
    dep_section=$(_truncate_section "$dep_section" $(( budget_chars * 10 / 100 )))
    config_section=$(_truncate_section "$config_section" $(( budget_chars * 5 / 100 )))
    test_section=$(_truncate_section "$test_section" $(( budget_chars * 5 / 100 )))

    # Build header (reads from inventory.jsonl if available)
    local doc_quality_section=""
    [[ "$doc_quality_score" -gt 0 ]] 2>/dev/null && \
        doc_quality_section="DOC_QUALITY_SCORE: ${doc_quality_score}"
    local header_section
    header_section=$(_build_index_header "$project_dir" "$file_list" "$doc_quality_section")

    {
        printf '%s\n\n' "$header_section"
        printf '## Directory Tree\n\n%s\n\n' "$tree_section"
        printf '## File Inventory\n\n%s\n\n' "$inventory_section"
        printf '## Key Dependencies\n\n%s\n\n' "$dep_section"
        printf '## Configuration Files\n\n%s\n\n' "$config_section"
        printf '## Test Infrastructure\n\n%s\n\n' "$test_section"
        printf '## Sampled File Content\n\n%s\n' "$sample_section"
    } > "$index_file"
}
