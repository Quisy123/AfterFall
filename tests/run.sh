#!/usr/bin/env bash
#
# Runs the AFTERFALL test suite outside Roblox, using the Luau CLI.
#
#   ./tests/run.sh
#
# Requires the `luau` binary on PATH (https://github.com/luau-lang/luau/releases),
# or set LUAU to point at it:
#
#   LUAU=/path/to/luau ./tests/run.sh
#
# WHY THERE IS A BUILD STEP
#
# Modules in src/ use Roblox's instance-based requires -- require(script.Parent.X)
# -- which only resolve inside Roblox. The Luau CLI uses file paths instead.
#
# So this script mirrors every shared module into a flat temporary directory,
# rewriting those requires into plain relative ones. Module names are unique
# across the project, which is what makes flattening safe.
#
# The payoff is large: any module that does not touch the Roblox API can be
# tested thousands of times per second on a machine with no Roblox installed.
# That is what keeps the combat maths and the fixed timestep honest.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUAU="${LUAU:-luau}"

if ! command -v "$LUAU" >/dev/null 2>&1; then
	echo "error: '$LUAU' not found on PATH." >&2
	echo "       Install the Luau CLI, or set LUAU=/path/to/luau" >&2
	exit 127
fi

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Flatten src/shared. A folder module (Types/init.luau) takes its folder's name.
while IFS= read -r file; do
	name="$(basename "$file" .luau)"
	if [ "$name" = "init" ]; then
		name="$(basename "$(dirname "$file")")"
	fi
	sed -E 's/require\(script(\.Parent)*\.([A-Za-z0-9_]+)\)/require(".\/\2")/g' \
		"$file" >"$BUILD/$name.luau"
done < <(find "$ROOT/src/shared" -name '*.luau')

# Copy the tests, pointing their requires at the flattened copies.
for test_file in "$ROOT"/tests/*.test.luau; do
	sed -E 's#require\("[^"]*/([A-Za-z0-9_]+)"\)#require("./\1")#g' \
		"$test_file" >"$BUILD/$(basename "$test_file")"
done

failed=0
for test_file in "$BUILD"/*.test.luau; do
	if ! (cd "$BUILD" && "$LUAU" "$(basename "$test_file")"); then
		failed=1
	fi
done

if [ "$failed" -ne 0 ]; then
	echo "TEST SUITE FAILED" >&2
	exit 1
fi

echo "All test files passed."
