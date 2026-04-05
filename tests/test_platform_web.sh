#!/usr/bin/env bash
# =============================================================================
# test_platform_web.sh — Unit tests for platforms/web/ (Milestone 58)
#
# Tests:
#   1.  Tailwind detected from tailwind.config.ts
#   2.  Tailwind detected from tailwind.config.js
#   3.  Tailwind detected from tailwind.config.cjs
#   4.  Tailwind detected from tailwind.config.mjs
#   5.  Tailwind detected from tailwindcss in package.json deps
#   6.  Tailwind config path is set to config file
#   7.  MUI detected from @mui/material in deps
#   8.  MUI overrides Tailwind when both present
#   9.  shadcn detected from components.json
#  10.  Chakra detected from @chakra-ui/react
#  11.  Ant Design detected from antd
#  12.  Radix detected from @radix-ui/react-*
#  13.  Headless UI detected from @headlessui/react
#  14.  Headless UI detected from @headlessui/vue
#  15.  Bootstrap detected from bootstrap in deps
#  16.  Bulma detected from bulma in deps
#  17.  UnoCSS detected from unocss in deps
#  18.  UnoCSS config path set when uno.config.ts exists
#  19.  Vuetify detected from vuetify in deps
#  20.  Element Plus detected from element-plus in deps
#  21.  Component directory detection finds src/components/ui/
#  22.  Component directory detection finds src/components/common/
#  23.  Component directory detection finds app/components/ui/
#  24.  CSS custom property file detection (variables.css in src/)
#  25.  CSS custom property file detection (tokens.scss in root)
#  26.  Design tokens not overridden when config already set
#  27.  Empty project produces no design system
#  28.  Fragment files are syntactically valid markdown
#  29.  detect.sh passes bash -n
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

# Source detect.sh for _extract_json_keys and _check_dep
# shellcheck source=../lib/detect.sh
source "${TEKHTON_HOME}/lib/detect.sh"

# Helper to reset globals and create fresh project dir
reset_and_make() {
    DESIGN_SYSTEM=""
    DESIGN_SYSTEM_CONFIG=""
    COMPONENT_LIBRARY_DIR=""
    PROJECT_DIR="${TEST_TMPDIR}/proj_${1}"
    rm -rf "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
}

# Helper to source detect.sh for web platform
run_web_detect() {
    # shellcheck source=/dev/null
    source "${TEKHTON_HOME}/platforms/web/detect.sh"
}

echo "=== test_platform_web.sh ==="

# --- Tailwind CSS detection ---------------------------------------------------

# Test 1: Tailwind from tailwind.config.ts
reset_and_make "tw_ts"
touch "$PROJECT_DIR/tailwind.config.ts"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{ "dependencies": {} }
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "tailwind" ]] && pass "1: Tailwind from config.ts" || fail "1: Tailwind from config.ts (got: $DESIGN_SYSTEM)"

# Test 2: Tailwind from tailwind.config.js
reset_and_make "tw_js"
touch "$PROJECT_DIR/tailwind.config.js"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{ "dependencies": {} }
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "tailwind" ]] && pass "2: Tailwind from config.js" || fail "2: Tailwind from config.js (got: $DESIGN_SYSTEM)"

# Test 3: Tailwind from tailwind.config.cjs
reset_and_make "tw_cjs"
touch "$PROJECT_DIR/tailwind.config.cjs"
run_web_detect
[[ "$DESIGN_SYSTEM" == "tailwind" ]] && pass "3: Tailwind from config.cjs" || fail "3: Tailwind from config.cjs (got: $DESIGN_SYSTEM)"

# Test 4: Tailwind from tailwind.config.mjs
reset_and_make "tw_mjs"
touch "$PROJECT_DIR/tailwind.config.mjs"
run_web_detect
[[ "$DESIGN_SYSTEM" == "tailwind" ]] && pass "4: Tailwind from config.mjs" || fail "4: Tailwind from config.mjs (got: $DESIGN_SYSTEM)"

# Test 5: Tailwind from package.json deps
reset_and_make "tw_pkg"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "devDependencies": {
    "tailwindcss": "^3.3.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "tailwind" ]] && pass "5: Tailwind from package.json" || fail "5: Tailwind from package.json (got: $DESIGN_SYSTEM)"

# Test 6: Tailwind config path set
reset_and_make "tw_config_path"
touch "$PROJECT_DIR/tailwind.config.ts"
run_web_detect
[[ "$DESIGN_SYSTEM_CONFIG" == "${PROJECT_DIR}/tailwind.config.ts" ]] && pass "6: Tailwind config path" || fail "6: Tailwind config path (got: $DESIGN_SYSTEM_CONFIG)"

# --- Component library detection (higher precedence) --------------------------

# Test 7: MUI from @mui/material
reset_and_make "mui"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "@mui/material": "^5.0.0",
    "react": "^18.0.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "mui" ]] && pass "7: MUI from @mui/material" || fail "7: MUI from @mui/material (got: $DESIGN_SYSTEM)"

# Test 8: MUI overrides Tailwind when both present
reset_and_make "mui_tw"
touch "$PROJECT_DIR/tailwind.config.js"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "@mui/material": "^5.0.0",
    "tailwindcss": "^3.3.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "mui" ]] && pass "8: MUI overrides Tailwind" || fail "8: MUI overrides Tailwind (got: $DESIGN_SYSTEM)"

# Test 9: shadcn from components.json
reset_and_make "shadcn"
cat > "$PROJECT_DIR/components.json" <<'EOF'
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "aliases": { "components": "@/components" }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "shadcn" ]] && pass "9: shadcn from components.json" || fail "9: shadcn from components.json (got: $DESIGN_SYSTEM)"

# Test 10: Chakra from @chakra-ui/react
reset_and_make "chakra"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "@chakra-ui/react": "^2.0.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "chakra" ]] && pass "10: Chakra from deps" || fail "10: Chakra from deps (got: $DESIGN_SYSTEM)"

# Test 11: Ant Design from antd
reset_and_make "antd"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "antd": "^5.0.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "antd" ]] && pass "11: Ant Design from antd" || fail "11: Ant Design from antd (got: $DESIGN_SYSTEM)"

# Test 12: Radix from @radix-ui/react-*
reset_and_make "radix"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "@radix-ui/react-dialog": "^1.0.0",
    "@radix-ui/react-dropdown-menu": "^2.0.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "radix" ]] && pass "12: Radix from deps" || fail "12: Radix from deps (got: $DESIGN_SYSTEM)"

# Test 13: Headless UI from @headlessui/react
reset_and_make "headlessui_react"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "@headlessui/react": "^1.7.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "headlessui" ]] && pass "13: Headless UI React" || fail "13: Headless UI React (got: $DESIGN_SYSTEM)"

# Test 14: Headless UI from @headlessui/vue
reset_and_make "headlessui_vue"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "@headlessui/vue": "^1.7.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "headlessui" ]] && pass "14: Headless UI Vue" || fail "14: Headless UI Vue (got: $DESIGN_SYSTEM)"

# Test 15: Bootstrap from bootstrap in deps
reset_and_make "bootstrap"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "bootstrap": "^5.3.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "bootstrap" ]] && pass "15: Bootstrap from deps" || fail "15: Bootstrap from deps (got: $DESIGN_SYSTEM)"

# Test 16: Bulma from bulma in deps
reset_and_make "bulma"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "bulma": "^0.9.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "bulma" ]] && pass "16: Bulma from deps" || fail "16: Bulma from deps (got: $DESIGN_SYSTEM)"

# Test 17: UnoCSS from unocss in deps
reset_and_make "unocss"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "devDependencies": {
    "unocss": "^0.50.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "unocss" ]] && pass "17: UnoCSS from deps" || fail "17: UnoCSS from deps (got: $DESIGN_SYSTEM)"

# Test 18: UnoCSS config path set when uno.config.ts exists
reset_and_make "unocss_config"
touch "$PROJECT_DIR/uno.config.ts"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "devDependencies": {
    "unocss": "^0.50.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM_CONFIG" == "${PROJECT_DIR}/uno.config.ts" ]] && pass "18: UnoCSS config path" || fail "18: UnoCSS config path (got: $DESIGN_SYSTEM_CONFIG)"

# Test 19: Vuetify from vuetify in deps
reset_and_make "vuetify"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "vuetify": "^3.0.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "vuetify" ]] && pass "19: Vuetify from deps" || fail "19: Vuetify from deps (got: $DESIGN_SYSTEM)"

# Test 20: Element Plus from element-plus in deps
reset_and_make "element_plus"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "dependencies": {
    "element-plus": "^2.3.0"
  }
}
EOF
run_web_detect
[[ "$DESIGN_SYSTEM" == "element-plus" ]] && pass "20: Element Plus from deps" || fail "20: Element Plus from deps (got: $DESIGN_SYSTEM)"

# --- Component directory detection --------------------------------------------

# Test 21: src/components/ui/
reset_and_make "comp_ui"
mkdir -p "$PROJECT_DIR/src/components/ui"
run_web_detect
[[ "$COMPONENT_LIBRARY_DIR" == "${PROJECT_DIR}/src/components/ui" ]] && pass "21: Component dir src/components/ui/" || fail "21: Component dir (got: $COMPONENT_LIBRARY_DIR)"

# Test 22: src/components/common/
reset_and_make "comp_common"
mkdir -p "$PROJECT_DIR/src/components/common"
run_web_detect
[[ "$COMPONENT_LIBRARY_DIR" == "${PROJECT_DIR}/src/components/common" ]] && pass "22: Component dir src/components/common/" || fail "22: Component dir (got: $COMPONENT_LIBRARY_DIR)"

# Test 23: app/components/ui/
reset_and_make "comp_app"
mkdir -p "$PROJECT_DIR/app/components/ui"
run_web_detect
[[ "$COMPONENT_LIBRARY_DIR" == "${PROJECT_DIR}/app/components/ui" ]] && pass "23: Component dir app/components/ui/" || fail "23: Component dir (got: $COMPONENT_LIBRARY_DIR)"

# --- CSS custom property / design token detection -----------------------------

# Test 24: variables.css in src/
reset_and_make "tokens_src"
mkdir -p "$PROJECT_DIR/src"
touch "$PROJECT_DIR/src/variables.css"
run_web_detect
[[ "$DESIGN_SYSTEM_CONFIG" == "${PROJECT_DIR}/src/variables.css" ]] && pass "24: CSS tokens in src/" || fail "24: CSS tokens in src/ (got: $DESIGN_SYSTEM_CONFIG)"

# Test 25: tokens.scss in root
reset_and_make "tokens_root"
touch "$PROJECT_DIR/tokens.scss"
run_web_detect
[[ "$DESIGN_SYSTEM_CONFIG" == "${PROJECT_DIR}/tokens.scss" ]] && pass "25: CSS tokens in root" || fail "25: CSS tokens in root (got: $DESIGN_SYSTEM_CONFIG)"

# Test 26: Design tokens not overridden when config already set (e.g., Tailwind)
reset_and_make "tokens_no_override"
touch "$PROJECT_DIR/tailwind.config.js"
mkdir -p "$PROJECT_DIR/src"
touch "$PROJECT_DIR/src/variables.css"
run_web_detect
[[ "$DESIGN_SYSTEM_CONFIG" == "${PROJECT_DIR}/tailwind.config.js" ]] && pass "26: Tokens don't override existing config" || fail "26: Tokens don't override existing config (got: $DESIGN_SYSTEM_CONFIG)"

# --- Edge cases ---------------------------------------------------------------

# Test 27: Empty project produces no design system
reset_and_make "empty"
run_web_detect
[[ -z "$DESIGN_SYSTEM" ]] && pass "27: Empty project → no design system" || fail "27: Empty project → no design system (got: $DESIGN_SYSTEM)"

# --- Fragment file validation -------------------------------------------------

# Test 28: Fragment files exist and are non-empty
local_fail=0
for frag in coder_guidance.prompt.md specialist_checklist.prompt.md tester_patterns.prompt.md; do
    fpath="${TEKHTON_HOME}/platforms/web/${frag}"
    if [[ ! -f "$fpath" ]]; then
        fail "28: Missing fragment: ${frag}"
        local_fail=1
    elif [[ ! -s "$fpath" ]]; then
        fail "28: Empty fragment: ${frag}"
        local_fail=1
    fi
done
[[ "$local_fail" -eq 0 ]] && pass "28: All fragment files exist and are non-empty"

# Test 29: detect.sh passes bash -n
if bash -n "${TEKHTON_HOME}/platforms/web/detect.sh" 2>/dev/null; then
    pass "29: detect.sh passes bash -n"
else
    fail "29: detect.sh fails bash -n"
fi

# --- Summary ------------------------------------------------------------------

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
