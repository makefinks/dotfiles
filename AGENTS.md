# AGENTS.md

## Scope

- This is a personal dotfiles repository.
- The main application code is the Neovim configuration under `nvim/.config/nvim`.
- `scripts/check.sh` is the repository validation entrypoint.
- `setup.sh` installs dependencies and stows the `zsh`, `nvim`, `tmux`, and `ghostty` packages.
- `vimium-c/` contains browser configuration and is not managed by `setup.sh`.

## Repository Layout

- `README.md`: root installation overview.
- `setup.sh`: Bash bootstrap script for dependencies, Oh My Zsh, Powerlevel10k, backups, and Stow links.
- `scripts/check.sh`: formats and validates shell/Lua code, then runs the Neovim spec suite.
- `nvim/.config/nvim/init.lua`: Neovim entrypoint.
- `nvim/.config/nvim/lua/`: Lua modules and Lazy plugin specifications.
- `nvim/.config/nvim/lua/plugins/`: plugin specs grouped by feature area.
- `nvim/.config/nvim/lua/user/`: user-owned integration modules, including CodeDiff.
- `nvim/.config/nvim/tests/spec/`: Plenary/Busted unit and integration specs.
- `nvim/.config/nvim/tests/smoke/`: headless startup and end-to-end smoke test runner.
- `nvim/.config/nvim/tests/fixtures/`: files and projects used by tests.
- `nvim/.config/nvim/tests/minimal_init.lua`: isolated init used by the spec suite.
- `nvim/.config/nvim/tests/smoke/init.lua`: full-config init used by smoke tests.
- `nvim/.config/nvim/selene.toml`: Selene configuration.
- `nvim/.config/nvim/neovim.yml`: Lua tooling metadata and declared globals.

## Working Directories

- Run bootstrap and repository-wide validation commands from the repository root.
- Run Neovim-specific commands from `nvim/.config/nvim` unless a command is shown with a root-relative path.
- Most Lua changes belong under `nvim/.config/nvim/lua/`.

## Bootstrap And Plugin Commands

- Install or update the dotfiles: `./setup.sh`
- Install/sync Neovim plugins: `nvim --headless "+Lazy! sync" +qa`
- Run Neovim health checks: `nvim --headless "+checkhealth" +qa`
- The Neovim config targets Neovim `>= 0.12.0` and AstroNvim v6.
- There is no Makefile, package manifest, or general application build pipeline.

## Validation Commands

From the repository root:

- Full repository check: `./scripts/check.sh`
- Format shell scripts: `shfmt -w setup.sh scripts/check.sh`
- Lint shell scripts: `shellcheck setup.sh scripts/check.sh`

From `nvim/.config/nvim`:

- Format Lua: `stylua .`
- Lint Lua: `selene .`
- Run the Plenary spec suite: `./tests/run.sh`
- Run the full-config smoke suite: `./tests/smoke/run.sh`
- Run one spec: `nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('plenary.busted').run('tests/spec/<name>_spec.lua')" -c "qall!"`

`scripts/check.sh` formats `setup.sh`, `scripts/check.sh`, and the entire Neovim config before running ShellCheck, Selene, and `tests/run.sh`. The smoke suite is separate and is not included in that script.

## Test Notes

- `tests/run.sh` changes into the Neovim config directory and runs `PlenaryBustedDirectory` over `tests/spec/`.
- The spec harness requires `plenary.nvim` and `codediff.nvim` under Neovim's lazy data directory, normally `stdpath('data') .. '/lazy'`.
- Specs use Plenary's Busted-style `describe`, `it`, `before_each`, and `after_each` API.
- Smoke tests load the full config and exercise startup, fixture opening, Snacks/fff pickers and grep, and the `ty` Python LSP.
- Smoke tests therefore require the configured plugins and the Mason `ty` binary in addition to the spec dependencies.
- Use explicit wait helpers for asynchronous UI behavior and clean up temporary repositories/editor state in teardown paths.
- Shared test support belongs in `tests/helpers/`; test-only fixtures belong in `tests/fixtures/`.

## Runtime Assumptions

- Lua targets Neovim's embedded Lua 5.1 runtime.
- Production modules assume Neovim globals such as `vim`, `vim.api`, and `vim.fn` exist.
- `selene.toml` uses the `neovim` standard library.
- `init.lua` can clone `lazy.nvim` into Neovim's data directory when it is absent.

## Code Organization

- Plugin spec files return Lazy spec tables.
- Module files generally start with `local M = {}` and end with `return M`.
- Keep private helpers above exported functions when practical.
- Prefer small helpers over deeply nested inline logic.
- Keep plugin-specific helpers next to the plugin they support.
- Put test-only support code in `tests/helpers/`, not production modules.

## Imports And Requires

- Match the file's existing style: both `require "module.path"` and `require("module.path")` are used.
- Group local module requires near the top of the file.
- Avoid dynamic requires unless they help with optional dependencies or startup cost.
- Use `pcall(require, ...)` when a dependency may be absent at runtime.

## Formatting And Naming

- `stylua` is the source of truth for Lua formatting; do not hand-align whitespace.
- Keep blank lines between logical sections and do not add semicolons.
- Respect `-- stylua: ignore` only for intentionally hand-crafted layouts.
- Use `snake_case` for file names, locals, and functions.
- Prefix predicates with `is_`, `has_`, `can_`, or `ok_` when it improves clarity.
- Reserve ALL_CAPS for genuine constants.
- Add EmmyLua annotations when they materially improve editor support, especially for plugin specs and tricky state tables.

## Error Handling And Neovim Patterns

- Prefer guard clauses and graceful handling for recoverable failures.
- Use `pcall` for optional plugin modules and unstable integrations.
- Use `vim.notify(..., vim.log.levels.ERROR/WARN)` for user-visible runtime failures.
- Wrap UI-facing work in `vim.schedule` when running from asynchronous callbacks.
- Use `assert(...)` freely in tests; reserve hard assertions in production for true invariants.
- Use `vim.api.nvim_create_autocmd` and `vim.api.nvim_create_augroup` for autocommands.
- Use `vim.keymap.set` for mappings.
- Prefer buffer- or tab-scoped behavior for plugin UIs.
- Validate windows, buffers, and tabpages before using them.
- Use `vim.deepcopy` for state that should not be mutated in place and `vim.tbl_extend("force", ...)` for merged options.

## Plugin Configuration

- AstroNvim/Lazy plugin specs are returned directly as tables.
- Keep `opts`, `config`, `keys`, `cmd`, and `event` sections easy to scan.
- Preserve existing `desc` strings unless behavior changes.
- Disable inherited mappings by setting the relevant entry to `false`, following nearby examples.
- Move custom behavior into a local helper module when a setup table becomes too large.
- For CodeDiff changes, inspect neighboring modules under `lua/user/codediff/` and the spec/helper files before changing behavior.
- For LSP or formatter changes, inspect both `lua/plugins/lsp/` and the Mason/Conform settings.

## Shell Scripts

- `setup.sh` and `scripts/check.sh` are Bash scripts; test scripts under `nvim/.config/nvim/tests/` are POSIX `sh`.
- Bash scripts use `set -euo pipefail` near the top.
- Use uppercase names for global Bash variables and `snake_case` for shell functions.
- Quote variable expansions unless unquoted behavior is intentional.
- Prefer `[[ ... ]]` in Bash conditionals.

## Editing And Verification Strategy

- Preserve the existing personalized architecture and avoid broad refactors.
- Do not remove Unicode artwork or decorative UI content unless required.
- Run `stylua` on edited Lua files before finishing.
- Run `selene .` after non-trivial Lua changes.
- Run `./tests/run.sh` for changes affecting tested Neovim behavior.
- Run `./tests/smoke/run.sh` when changing startup, plugin loading, pickers, LSP setup, or other full-config behavior.
- Run `./scripts/check.sh` for repository-wide changes when its required tools are available.
- If a command cannot run because a dependency is missing, report the dependency explicitly.
