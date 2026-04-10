#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/../.."

exec nvim --headless --noplugin -u tests/smoke/init.lua \
  -c "lua require('tests.smoke.runner').run()" \
  -c "qall!"
