#!/bin/bash
#
# test-screenshots-spaces.sh
#
# Tests the TWO real failure modes for /screenshots on macOS:
#
#   Bug 1 — Word-splitting: inlining the path unquoted in a bash command string
#            causes shell word-split on ASCII spaces → tile-image.sh receives
#            a fragment instead of the full path.
#            Repro: bash -c "tile-image.sh $UNQUOTED_PATH --limit 1568"
#
#   Bug 2 — U+202F literal loss: macOS screenshot filenames contain a Unicode
#            narrow no-break space (U+202F, e2 80 af) before AM/PM. Assigning
#            the path as a hardcoded string literal loses this byte, so the
#            file-existence check fails even though the file is present on disk.
#            Repro: tile-image.sh "Screenshot ... 9.57.31 PM.png"  (ASCII space, not U+202F)
#
# The fix for both: capture via $() from screenshots.sh, pass as "$IMG_PATH".
#
# Requires: macOS + sips + python3
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TILE_SCRIPT="$REPO_DIR/scripts/tile-image.sh"
SCREENSHOTS_SCRIPT="$REPO_DIR/scripts/screenshots.sh"
PASS=0
FAIL=0
BLOCKED=0

pass()    { echo "  ✓ $1"; ((PASS++)) || true; }
fail()    { echo "  ✗ $1"; ((FAIL++)) || true; }
blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

TMPDIR_TEST=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_TEST"; }
trap cleanup EXIT

echo ""
echo "tile-image.sh / screenshots — real failure mode tests"
echo "======================================================"

# ── Guards ───────────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
    blocked "all tests" "requires macOS (sips)"
    echo ""; echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked"; exit 0
fi
if ! command -v sips &>/dev/null; then
    blocked "all tests" "sips not found"
    echo ""; echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked"; exit 0
fi
if ! command -v python3 &>/dev/null; then
    blocked "all tests" "python3 required to create fixtures with exact byte sequences"
    echo ""; echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked"; exit 0
fi

# ── Create fixtures via python3 ───────────────────────────────────────────────
# python3 is the only reliable way to write filenames with U+202F through bash.
# All fixture paths are captured via `find` to preserve exact bytes.
python3 -c "
import struct, zlib, os

def chunk(name, data):
    c = name + data
    return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

sig  = b'\x89PNG\r\n\x1a\n'
ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
idat = chunk(b'IDAT', zlib.compress(b'\x00\xff\xff\xff'))
iend = chunk(b'IEND', b'')
png  = sig + ihdr + idat + iend

base = '$TMPDIR_TEST'

# ASCII-space version (Bug 1 fixture)
open(os.path.join(base, 'Screenshot 2026-05-28 at 11.36.50.png'), 'wb').write(png)

# U+202F version (Bug 2 fixture) — real macOS AM/PM pattern
open(os.path.join(base, 'Screenshot 2026-05-28 at 9.57.31' + chr(0x202F) + 'PM.png'), 'wb').write(png)
"

# Capture fixture paths via find (preserves U+202F in bash variable)
ASCII_SPACE=$(find "$TMPDIR_TEST" -name "*11.36*" | head -1)
U202F_PATH=$(find "$TMPDIR_TEST" -name "*PM*" | head -1)

if [[ -z "$ASCII_SPACE" || -z "$U202F_PATH" ]]; then
    blocked "all tests" "fixture creation failed"
    echo ""; echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked"; exit 0
fi

# Verify U+202F fixture actually has the right bytes
u202f_in_name=$(printf '%s' "$U202F_PATH" | xxd | tr -d ' \n' | grep -o "e280af" || true)
if [[ "$u202f_in_name" != "e280af" ]]; then
    blocked "Bug 2 tests" "U+202F fixture missing correct bytes — filesystem may have normalized"
fi

# ── Bug 1: Word-splitting on ASCII spaces ─────────────────────────────────────
echo ""
echo "Bug 1: word-splitting — inline unquoted path in bash -c string"

# Reproduce: path inlined unquoted → shell word-splits on spaces
ws_out=$(bash -c "$TILE_SCRIPT $ASCII_SPACE --limit 1568" 2>&1) && ws_exit=0 || ws_exit=$?
if [[ $ws_exit -ne 0 ]]; then
    pass "inlined unquoted path fails with word-split error"
else
    fail "inlined unquoted path did NOT fail — word-split not triggered"
fi
if echo "$ws_out" | grep -q "image file not found"; then
    pass "error is 'image file not found' (fragment received, not full path)"
else
    fail "unexpected error: $ws_out"
fi

# Fix: capture via $() and pass as "$IMG_PATH"
IMG_PATH=$(ls "$ASCII_SPACE")
fix1_out=$("$TILE_SCRIPT" "$IMG_PATH" --limit 1568 2>&1) && fix1_exit=0 || fix1_exit=$?
if [[ $fix1_exit -eq 0 && -n "$fix1_out" ]]; then
    pass "captured + quoted ASCII-space path exits 0"
else
    fail "fix failed for ASCII-space path (exit $fix1_exit: $fix1_out)"
fi

# ── Bug 2: U+202F lost when path assigned as string literal ──────────────────
echo ""
echo "Bug 2: U+202F narrow no-break space (e2 80 af) lost in literal assignment"

if [[ "$u202f_in_name" != "e280af" ]]; then
    blocked "U+202F repro" "fixture doesn't have U+202F bytes"
    blocked "U+202F fix"   "fixture doesn't have U+202F bytes"
else
    # Confirm the real macOS pattern: U+202F is present in the fixture
    pass "U+202F (e2 80 af) confirmed in fixture filename"

    # Reproduce: simulate what Claude does when it types the path as a literal —
    # it types a regular space (0x20) where U+202F (e2 80 af) actually is.
    # We construct the "wrong" path by replacing U+202F with ASCII space in a new string.
    WRONG_PATH=$(python3 -c "
import os
path = '$U202F_PATH'
wrong = path.replace('\u202f', ' ')
print(wrong)
")
    lit_out=$("$TILE_SCRIPT" "$WRONG_PATH" --limit 1568 2>&1) && lit_exit=0 || lit_exit=$?
    if [[ $lit_exit -ne 0 ]]; then
        pass "path with ASCII space instead of U+202F fails (literal loss reproduced)"
    else
        fail "path with wrong encoding did NOT fail — repro broken"
    fi

    # Fix: captured path via find/\$() preserves U+202F intact
    captured_hex=$(printf '%s' "$U202F_PATH" | xxd | tr -d ' \n' | grep -o "e280af" || true)
    if [[ "$captured_hex" == "e280af" ]]; then
        pass "path captured via find preserves U+202F intact"
    else
        fail "path captured via find lost U+202F"
    fi

    fix2_out=$("$TILE_SCRIPT" "$U202F_PATH" --limit 1568 2>&1) && fix2_exit=0 || fix2_exit=$?
    if [[ $fix2_exit -eq 0 && -n "$fix2_out" ]]; then
        pass "captured + quoted U+202F path exits 0"
    else
        fail "captured + quoted U+202F path failed (exit $fix2_exit: $fix2_out)"
    fi
fi

# ── End-to-end: screenshots.sh → tile-image.sh with real Desktop file ─────────
echo ""
echo "End-to-end: screenshots.sh | tile-image.sh on real Desktop screenshot"

REAL_PATH=$("$SCREENSHOTS_SCRIPT" 1 2>/dev/null || true)
if [[ -z "$REAL_PATH" ]]; then
    blocked "end-to-end" "no screenshots on ~/Desktop"
else
    # Verify U+202F is present in the real path (confirms macOS behaviour still holds)
    real_u202f=$(printf '%s' "$REAL_PATH" | xxd | tr -d ' \n' | grep -o "e280af" || true)
    if [[ "$real_u202f" == "e280af" ]]; then
        pass "real screenshot from screenshots.sh contains U+202F before AM/PM"
    else
        # Not every screenshot has AM/PM (e.g. 24h locale) — warn but don't fail
        echo "  ⚠ real screenshot path has no U+202F (no AM/PM or 24h locale)"
    fi

    # The fix: $() capture preserves bytes, "$IMG_PATH" passes them intact
    IMG_PATH="$REAL_PATH"
    e2e_out=$("$TILE_SCRIPT" "$IMG_PATH" --limit 1568 2>&1) && e2e_exit=0 || e2e_exit=$?
    if [[ $e2e_exit -eq 0 && -n "$e2e_out" ]]; then
        pass "end-to-end: screenshots.sh | tile-image.sh exits 0 with output"
    else
        fail "end-to-end failed (exit $e2e_exit): $e2e_out"
    fi
fi

# ── Baseline: missing file still errors ───────────────────────────────────────
echo ""
echo "Baseline: missing file exits non-zero with message"

MISSING="$TMPDIR_TEST/does not exist.png"
miss_out=$("$TILE_SCRIPT" "$MISSING" --limit 1568 2>&1) && miss_exit=0 || miss_exit=$?
if [[ $miss_exit -ne 0 && -n "$miss_out" ]]; then
    pass "missing file exits non-zero with error message"
else
    fail "missing file handling broken (exit $miss_exit, output: $miss_out)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked (skipped)"
[ $FAIL -eq 0 ] && exit 0 || exit 1
