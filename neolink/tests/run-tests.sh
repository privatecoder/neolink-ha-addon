#!/usr/bin/env bash
# Runs every fixture case under tests/cases/ and diffs gen-config.sh output
# against the expected TOML. Cases whose name starts with "fail-" must exit
# non-zero instead.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
gen="$here/../gen-config.sh"
fail=0
for dir in "$here"/cases/*/; do
  name="$(basename "$dir")"
  if [[ "$name" == fail-* ]]; then
    if out="$("$gen" < "$dir/options.json" 2>/dev/null)"; then
      echo "FAIL $name: expected non-zero exit"; fail=1
    else
      echo "ok   $name (rejected as expected)"
    fi
    continue
  fi
  got="$("$gen" < "$dir/options.json")"
  if diff -u "$dir/expected.toml" <(printf '%s\n' "$got") >/dev/null; then
    echo "ok   $name"
  else
    echo "FAIL $name:"; diff -u "$dir/expected.toml" <(printf '%s\n' "$got"); fail=1
  fi
done
exit "$fail"
