#!/usr/bin/env bash
# =============================================================================
# test_platform_base.sh — Unit tests for platforms/_base.sh (Milestone 57)
#
# Tests:
#   1.  detect_ui_platform() maps react → web
#   2.  detect_ui_platform() maps vue → web
#   3.  detect_ui_platform() maps svelte → web
#   4.  detect_ui_platform() maps angular → web
#   5.  detect_ui_platform() maps next.js → web
#   6.  detect_ui_platform() maps playwright → web
#   7.  detect_ui_platform() maps cypress → web
#   8.  detect_ui_platform() maps testing-library → web
#   9.  detect_ui_platform() maps puppeteer → web
#  10.  detect_ui_platform() maps selenium → web
#  11.  detect_ui_platform() maps flutter → mobile_flutter
#  12.  detect_ui_platform() maps swiftui → mobile_native_ios
#  13.  detect_ui_platform() maps jetpack-compose → mobile_native_android
#  14.  detect_ui_platform() maps phaser → game_web
#  15.  detect_ui_platform() maps pixi → game_web
#  16.  detect_ui_platform() maps three → game_web
#  17.  detect_ui_platform() maps babylon → game_web
#  18.  detect_ui_platform() maps detox → mobile_flutter
#  19.  detect_ui_platform() generic + web-game → game_web
#  20.  detect_ui_platform() generic + mobile-app → mobile_flutter
#  21.  detect_ui_platform() generic + other → web
#  22.  detect_ui_platform() returns 1 for non-UI project
#  23.  detect_ui_platform() honors explicit UI_PLATFORM (not auto)
#  24.  detect_ui_platform() handles custom_<name> platform
#  25.  load_platform_fragments() loads universal coder guidance
#  26.  load_platform_fragments() loads universal specialist checklist
#  27.  load_platform_fragments() appends platform-specific content
#  28.  load_platform_fragments() appends user override content
#  29.  load_platform_fragments() handles missing platform dir gracefully
#  30.  load_platform_fragments() appends design system info
#  31.  load_platform_fragments() appends component library info
# =============================================================================
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

# Set up minimal environment
PROJECT_DIR="$TEST_TMPDIR/project"
mkdir -p "$PROJECT_DIR"

# Source the module under test
source "${TEKHTON_HOME}/platforms/_base.sh"

# Helper to reset globals before each test
reset_ui_globals() {
    UI_PLATFORM=""
    UI_PLATFORM_DIR=""
    UI_PROJECT_DETECTED="false"
    UI_FRAMEWORK=""
    PROJECT_TYPE=""
    DESIGN_SYSTEM=""
    DESIGN_SYSTEM_CONFIG=""
    COMPONENT_LIBRARY_DIR=""
    UI_CODER_GUIDANCE=""
    UI_SPECIALIST_CHECKLIST=""
    UI_TESTER_PATTERNS=""
}

make_proj() {
    rm -rf "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
}

echo "=== test_platform_base.sh ==="

# --- detect_ui_platform() framework → platform mapping tests ---

# Test 1: react → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="react"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "1: react → web" || fail "1: react → web (got: $UI_PLATFORM)"

# Test 2: vue → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="vue"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "2: vue → web" || fail "2: vue → web (got: $UI_PLATFORM)"

# Test 3: svelte → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="svelte"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "3: svelte → web" || fail "3: svelte → web (got: $UI_PLATFORM)"

# Test 4: angular → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="angular"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "4: angular → web" || fail "4: angular → web (got: $UI_PLATFORM)"

# Test 5: next.js → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="next.js"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "5: next.js → web" || fail "5: next.js → web (got: $UI_PLATFORM)"

# Test 6: playwright → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="playwright"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "6: playwright → web" || fail "6: playwright → web (got: $UI_PLATFORM)"

# Test 7: cypress → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="cypress"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "7: cypress → web" || fail "7: cypress → web (got: $UI_PLATFORM)"

# Test 8: testing-library → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="testing-library"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "8: testing-library → web" || fail "8: testing-library → web (got: $UI_PLATFORM)"

# Test 9: puppeteer → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="puppeteer"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "9: puppeteer → web" || fail "9: puppeteer → web (got: $UI_PLATFORM)"

# Test 10: selenium → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="selenium"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "10: selenium → web" || fail "10: selenium → web (got: $UI_PLATFORM)"

# Test 11: flutter → mobile_flutter
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="flutter"
detect_ui_platform
[[ "$UI_PLATFORM" == "mobile_flutter" ]] && pass "11: flutter → mobile_flutter" || fail "11: flutter → mobile_flutter (got: $UI_PLATFORM)"

# Test 12: swiftui → mobile_native_ios
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="swiftui"
detect_ui_platform
[[ "$UI_PLATFORM" == "mobile_native_ios" ]] && pass "12: swiftui → mobile_native_ios" || fail "12: swiftui → mobile_native_ios (got: $UI_PLATFORM)"

# Test 13: jetpack-compose → mobile_native_android
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="jetpack-compose"
detect_ui_platform
[[ "$UI_PLATFORM" == "mobile_native_android" ]] && pass "13: jetpack-compose → mobile_native_android" || fail "13: jetpack-compose → mobile_native_android (got: $UI_PLATFORM)"

# Test 14: phaser → game_web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="phaser"
detect_ui_platform
[[ "$UI_PLATFORM" == "game_web" ]] && pass "14: phaser → game_web" || fail "14: phaser → game_web (got: $UI_PLATFORM)"

# Test 15: pixi → game_web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="pixi"
detect_ui_platform
[[ "$UI_PLATFORM" == "game_web" ]] && pass "15: pixi → game_web" || fail "15: pixi → game_web (got: $UI_PLATFORM)"

# Test 16: three → game_web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="three"
detect_ui_platform
[[ "$UI_PLATFORM" == "game_web" ]] && pass "16: three → game_web" || fail "16: three → game_web (got: $UI_PLATFORM)"

# Test 17: babylon → game_web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="babylon"
detect_ui_platform
[[ "$UI_PLATFORM" == "game_web" ]] && pass "17: babylon → game_web" || fail "17: babylon → game_web (got: $UI_PLATFORM)"

# Test 18: detox → mobile_flutter
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="detox"
detect_ui_platform
[[ "$UI_PLATFORM" == "mobile_flutter" ]] && pass "18: detox → mobile_flutter" || fail "18: detox → mobile_flutter (got: $UI_PLATFORM)"

# Test 19: generic + web-game → game_web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK=""
PROJECT_TYPE="web-game"
detect_ui_platform
[[ "$UI_PLATFORM" == "game_web" ]] && pass "19: generic + web-game → game_web" || fail "19: generic + web-game → game_web (got: $UI_PLATFORM)"

# Test 20: generic + mobile-app → mobile_flutter
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK=""
PROJECT_TYPE="mobile-app"
detect_ui_platform
[[ "$UI_PLATFORM" == "mobile_flutter" ]] && pass "20: generic + mobile-app → mobile_flutter" || fail "20: generic + mobile-app → mobile_flutter (got: $UI_PLATFORM)"

# Test 21: generic + other → web
reset_ui_globals
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK=""
PROJECT_TYPE="web-app"
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "21: generic + other → web" || fail "21: generic + other → web (got: $UI_PLATFORM)"

# Test 22: non-UI project returns 1
reset_ui_globals
UI_PROJECT_DETECTED="false"
if detect_ui_platform; then
    fail "22: non-UI project should return 1"
else
    [[ -z "$UI_PLATFORM" ]] && pass "22: non-UI project returns 1" || fail "22: non-UI platform should be empty (got: $UI_PLATFORM)"
fi

# Test 23: explicit UI_PLATFORM (not auto) is honored
reset_ui_globals
UI_PLATFORM="web"
UI_PROJECT_DETECTED="true"
UI_FRAMEWORK="flutter"  # Would normally map to mobile_flutter
detect_ui_platform
[[ "$UI_PLATFORM" == "web" ]] && pass "23: explicit UI_PLATFORM honored" || fail "23: explicit UI_PLATFORM should be honored (got: $UI_PLATFORM)"

# Test 24: custom_<name> platform resolves to user directory
reset_ui_globals
make_proj
mkdir -p "${PROJECT_DIR}/.claude/platforms/custom_myplatform"
UI_PLATFORM="custom_myplatform"
detect_ui_platform
[[ "$UI_PLATFORM" == "custom_myplatform" ]] && pass "24a: custom platform name preserved" || fail "24a: custom platform name (got: $UI_PLATFORM)"
[[ "$UI_PLATFORM_DIR" == "${PROJECT_DIR}/.claude/platforms/custom_myplatform" ]] && pass "24b: custom platform dir resolves" || fail "24b: custom platform dir (got: $UI_PLATFORM_DIR)"

# --- load_platform_fragments() tests ---

# Test 25: loads universal coder guidance
reset_ui_globals
make_proj
UI_PLATFORM="web"
load_platform_fragments
[[ "$UI_CODER_GUIDANCE" == *"State Presentation"* ]] && pass "25: universal coder guidance loaded" || fail "25: universal coder guidance not found in UI_CODER_GUIDANCE"

# Test 26: loads universal specialist checklist
reset_ui_globals
make_proj
UI_PLATFORM="web"
load_platform_fragments
[[ "$UI_SPECIALIST_CHECKLIST" == *"Component Structure"* ]] && pass "26: universal specialist checklist loaded" || fail "26: universal specialist checklist not found"

# Test 27: appends platform-specific content
reset_ui_globals
make_proj
# Create a mock platform-specific coder guidance
mkdir -p "${TEKHTON_HOME}/platforms/web"
echo "### Web-specific guidance" > "${TEKHTON_HOME}/platforms/web/coder_guidance.prompt.md"
UI_PLATFORM="web"
load_platform_fragments
# Should have both universal and platform content
[[ "$UI_CODER_GUIDANCE" == *"State Presentation"* ]] && [[ "$UI_CODER_GUIDANCE" == *"Web-specific guidance"* ]] \
    && pass "27: platform-specific content appended" \
    || fail "27: platform-specific content not appended"
# Clean up the mock file
rm -f "${TEKHTON_HOME}/platforms/web/coder_guidance.prompt.md"

# Test 28: appends user override content
reset_ui_globals
make_proj
mkdir -p "${PROJECT_DIR}/.claude/platforms/web"
echo "### Custom project guidance" > "${PROJECT_DIR}/.claude/platforms/web/coder_guidance.prompt.md"
UI_PLATFORM="web"
load_platform_fragments
[[ "$UI_CODER_GUIDANCE" == *"Custom project guidance"* ]] \
    && pass "28: user override content appended" \
    || fail "28: user override content not found in UI_CODER_GUIDANCE"

# Test 29: handles missing platform dir gracefully
reset_ui_globals
make_proj
UI_PLATFORM="nonexistent_platform"
load_platform_fragments
# Should still have universal content
[[ "$UI_CODER_GUIDANCE" == *"State Presentation"* ]] \
    && pass "29: graceful fallback with missing platform dir" \
    || fail "29: universal content missing on fallback"

# Test 30: appends design system info
reset_ui_globals
make_proj
UI_PLATFORM="web"
DESIGN_SYSTEM="Tailwind CSS"
DESIGN_SYSTEM_CONFIG="tailwind.config.js"
load_platform_fragments
[[ "$UI_CODER_GUIDANCE" == *"Design System: Tailwind CSS"* ]] \
    && pass "30: design system info appended" \
    || fail "30: design system info not found"

# Test 31: appends component library info
reset_ui_globals
make_proj
UI_PLATFORM="web"
COMPONENT_LIBRARY_DIR="src/components"
load_platform_fragments
[[ "$UI_CODER_GUIDANCE" == *"src/components"* ]] \
    && pass "31: component library info appended" \
    || fail "31: component library info not found"

# --- Summary ---
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
exit "$FAIL"
