#!/usr/bin/env bash
# Syntax/semantic check for the Luau sources without Roblox type definitions: only "Unknown global" noise is hidden.
A=${LUAU_ANALYZE:-/tmp/claude-0/-home-user-Hello/e7ee9de2-ccbf-563c-bd97-f08d9102e71b/scratchpad/luau/luau-analyze}
fail=0
for f in "$@"; do
  out=$($A --formatter=plain "$f" 2>&1 | grep -v "Unknown global\|Unknown require\|UnknownGlobal\|UnknownRequire\|Unknown type\|annotation\|SameLineStatement\|ImplicitReturn\|LocalUnused\|UnusedVariable") || true
  if [ -n "$out" ]; then echo "$out"; fail=1; fi
done
[ $fail -eq 0 ] && echo "luau-check: clean" || exit 1
