#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# crawler_emit.sh — Core structured index emitters (Milestone 67, M69 cleanup)
#
# Contains: dependency JSON emitter, scan metadata emitter.
# Per-domain emitters live in their source files:
#   crawler_inventory.sh — _emit_inventory_jsonl, _emit_configs_json, _emit_tests_json
#   crawler_content.sh   — _emit_sampled_files
#   crawler.sh           — _json_escape, _ensure_index_dir, _emit_tree_txt
#
# Sourced by crawler.sh — do not run directly.
# Depends on: crawler.sh (_json_escape),
#             detect.sh (_extract_json_keys)
# =============================================================================

# --- Dependencies emitter -----------------------------------------------------

# _emit_dependencies_json — Writes dependency manifest data as JSON.
# Args: $1=project_dir, $2=index_dir
_emit_dependencies_json() {
    local project_dir="$1" index_dir="$2"
    local tmp_m tmp_d tmp_f
    tmp_m=$(mktemp)
    tmp_d=$(mktemp)
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

