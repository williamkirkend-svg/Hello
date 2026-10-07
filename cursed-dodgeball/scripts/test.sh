#!/usr/bin/env bash
# Runs the headless Luau tests. LUAU env var overrides the binary path.
cd "$(dirname "$0")/.." || exit 1
LUAU=${LUAU:-$(command -v luau || echo /tmp/claude-0/-home-user-Hello/c5ac8de5-9467-5cae-b51a-866dacf2df14/scratchpad/luau/luau)}
exec "$LUAU" tests/run.luau
