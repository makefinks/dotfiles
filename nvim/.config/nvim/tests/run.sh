#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

exec nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/spec { minimal_init = 'tests/minimal_init.lua', sequential = true, timeout = 60000 }" \
  -c "qall!"
