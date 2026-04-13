#!/usr/bin/env bash
# Test: Milestone 76 — detect_project_version_files + parse_current_version
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Stub logging functions
log()     { :; }
warn()    { :; }
error()   { :; }
success() { :; }
header()  { :; }

# Source detection library
# shellcheck source=../lib/project_version.sh
source "${TEKHTON_HOME}/lib/project_version.sh"

# =============================================================================
# Helper: create a project dir with config
# =============================================================================
make_proj() {
    local name="$1"
    local dir="${TEST_TMPDIR}/${name}"
    mkdir -p "$dir/.claude"
    echo "$dir"
}

# =============================================================================
# Test: package.json detection
# =============================================================================
echo "=== detect: package.json ==="
PROJ=$(make_proj "npm")
echo '{"name":"test","version":"1.2.3"}' > "$PROJ/package.json"
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files

cfg="$PROJ/.claude/project_version.cfg"
if [[ -f "$cfg" ]]; then pass "config file created for package.json"; else fail "config file not created"; fi
if grep -q 'CURRENT_VERSION=1.2.3' "$cfg"; then pass "version 1.2.3 detected"; else fail "version not 1.2.3: $(cat "$cfg")"; fi
if grep -q 'package.json' "$cfg"; then pass "package.json in VERSION_FILES"; else fail "package.json not in VERSION_FILES"; fi

# =============================================================================
# Test: pyproject.toml detection
# =============================================================================
echo "=== detect: pyproject.toml ==="
PROJ=$(make_proj "python")
cat > "$PROJ/pyproject.toml" <<'TOML'
[project]
name = "myapp"
version = "2.0.1"
TOML
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=2.0.1' "$cfg"; then pass "pyproject.toml version detected"; else fail "pyproject.toml version not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: Cargo.toml detection
# =============================================================================
echo "=== detect: Cargo.toml ==="
PROJ=$(make_proj "rust")
cat > "$PROJ/Cargo.toml" <<'TOML'
[package]
name = "mylib"
version = "0.3.7"
TOML
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=0.3.7' "$cfg"; then pass "Cargo.toml version detected"; else fail "Cargo.toml version not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: setup.py detection
# =============================================================================
echo "=== detect: setup.py ==="
PROJ=$(make_proj "setup_py")
cat > "$PROJ/setup.py" <<'PY'
from setuptools import setup
setup(name='test', version='1.0.5')
PY
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=1.0.5' "$cfg"; then pass "setup.py version detected"; else fail "setup.py version not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: setup.cfg detection
# =============================================================================
echo "=== detect: setup.cfg ==="
PROJ=$(make_proj "setup_cfg")
cat > "$PROJ/setup.cfg" <<'CFG'
[metadata]
name = test
version = 3.1.0
CFG
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=3.1.0' "$cfg"; then pass "setup.cfg version detected"; else fail "setup.cfg version not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: gradle.properties detection
# =============================================================================
echo "=== detect: gradle.properties ==="
PROJ=$(make_proj "gradle")
echo "version=4.2.0" > "$PROJ/gradle.properties"
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=4.2.0' "$cfg"; then pass "gradle.properties version detected"; else fail "gradle.properties version not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: Chart.yaml detection
# =============================================================================
echo "=== detect: Chart.yaml ==="
PROJ=$(make_proj "helm")
cat > "$PROJ/Chart.yaml" <<'YAML'
apiVersion: v2
name: my-chart
version: 0.1.0
YAML
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=0.1.0' "$cfg"; then pass "Chart.yaml version detected"; else fail "Chart.yaml version not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: composer.json detection
# =============================================================================
echo "=== detect: composer.json ==="
PROJ=$(make_proj "php")
echo '{"name":"vendor/pkg","version":"5.0.0"}' > "$PROJ/composer.json"
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=5.0.0' "$cfg"; then pass "composer.json version detected"; else fail "composer.json version not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: pubspec.yaml detection
# =============================================================================
echo "=== detect: pubspec.yaml ==="
PROJ=$(make_proj "flutter")
cat > "$PROJ/pubspec.yaml" <<'YAML'
name: my_app
version: 1.0.0+1
YAML
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=1.0.0' "$cfg"; then pass "pubspec.yaml version detected"; else fail "pubspec.yaml version not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: plain VERSION file detection
# =============================================================================
echo "=== detect: VERSION file ==="
PROJ=$(make_proj "plain")
echo "6.7.8" > "$PROJ/VERSION"
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=6.7.8' "$cfg"; then pass "VERSION file detected"; else fail "VERSION file not detected: $(cat "$cfg")"; fi

# =============================================================================
# Test: no version file → creates VERSION with 0.1.0
# =============================================================================
echo "=== detect: no version file ==="
PROJ=$(make_proj "empty")
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if [[ -f "$PROJ/VERSION" ]]; then pass "VERSION file created"; else fail "VERSION file not created"; fi
if grep -q 'CURRENT_VERSION=0.1.0' "$cfg"; then pass "default 0.1.0 in config"; else fail "default version not 0.1.0: $(cat "$cfg")"; fi

# =============================================================================
# Test: idempotent — config not overwritten
# =============================================================================
echo "=== detect: idempotency ==="
PROJ=$(make_proj "idempotent")
mkdir -p "$PROJ/.claude"
echo "VERSION_STRATEGY=calver" > "$PROJ/.claude/project_version.cfg"
echo "VERSION_FILES=VERSION:." >> "$PROJ/.claude/project_version.cfg"
echo "CURRENT_VERSION=2026.04.0" >> "$PROJ/.claude/project_version.cfg"
echo '{"name":"test","version":"9.9.9"}' > "$PROJ/package.json"
PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" \
    PROJECT_VERSION_STRATEGY="semver" detect_project_version_files
cfg="$PROJ/.claude/project_version.cfg"
if grep -q 'CURRENT_VERSION=2026.04.0' "$cfg"; then pass "idempotent — config unchanged"; else fail "idempotent — config overwritten: $(cat "$cfg")"; fi

# =============================================================================
# Test: parse_current_version reads cached version
# =============================================================================
echo "=== parse_current_version ==="
PROJ=$(make_proj "parse")
mkdir -p "$PROJ/.claude"
echo "VERSION_STRATEGY=semver" > "$PROJ/.claude/project_version.cfg"
echo "VERSION_FILES=package.json:.version" >> "$PROJ/.claude/project_version.cfg"
echo "CURRENT_VERSION=3.2.1" >> "$PROJ/.claude/project_version.cfg"
ver=$(PROJECT_DIR="$PROJ" PROJECT_VERSION_CONFIG=".claude/project_version.cfg" parse_current_version)
if [[ "$ver" == "3.2.1" ]]; then pass "parse_current_version returns 3.2.1"; else fail "parse_current_version returned '$ver'"; fi

# =============================================================================
# Summary
# =============================================================================
echo
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
