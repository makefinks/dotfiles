# AGENTS.md
## Scope
- This is a personal dotfiles repo.
- The main programmable code lives in `nvim/.config/nvim`.
- `setup.sh` is the root bootstrap script.
- `zsh/`, `tmux/`, and `ghostty/` are mostly configuration, not application code.

## Repository Layout
- `README.md`: root install overview.
- `setup.sh`: installs dependencies and stows configs.
- `nvim/.config/nvim/init.lua`: Neovim entrypoint.
- `nvim/.config/nvim/lua/`: Lua modules and plugin specs.
- `nvim/.config/nvim/tests/`: Plenary-based tests.
- `nvim/.config/nvim/selene.toml`: Lua lint config.
- `nvim/.config/nvim/neovim.yml`: tooling metadata (`lua51`).

## Working Directories
- Run root/bootstrap commands from `/Users/leon/dotfiles`.
- Run Neovim dev, lint, and test commands from `/Users/leon/dotfiles/nvim/.config/nvim`.
- Most code changes will be under `nvim/.config/nvim/lua/`.

## Build And Bootstrap Commands
- Root setup: `./setup.sh`
- Sync/install Neovim plugins: `nvim --headless "+Lazy! sync" +qa`
- Optional dependency health check: `nvim --headless "+checkhealth" +qa`
- There is no Makefile, `package.json`, or general root build pipeline.

## Test Commands
- Full Neovim suite: `./tests/run.sh`
- Verified single spec file: `nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('plenary.busted').run('tests/spec/codediff_spec.lua')" -c "qall!"`
- Generic single spec file: `nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('plenary.busted').run('tests/spec/<name>_spec.lua')" -c "qall!"`

## Test Notes
- `tests/run.sh` changes into the Neovim config directory before running tests.
- Tests use `tests/minimal_init.lua`.
- The harness expects `plenary.nvim` and `codediff.nvim` in Neovim's lazy plugin directory.
- Specs use Plenary's Busted-style `describe` / `it` API.
- Shared helpers belong in `tests/helpers/`.
- Current tests mainly cover the custom CodeDiff integration.

## Lint And Format Commands
- Format Lua: `stylua .`
- Lint Lua: `selene .`
- Format the bootstrap script: `shfmt -w setup.sh`
- Lint the bootstrap script: `shellcheck setup.sh`

## Command Strategy For Agents
- Run `stylua` on edited Lua files before finishing.
- Run `selene .` after non-trivial Lua changes.
- Run `./tests/run.sh` when changing behavior under `lua/plugins/git/codediff*` or `tests/helpers/`.
- If a change is narrowly scoped to one spec or one CodeDiff behavior, run the focused single-spec command first.
- If a command cannot run because a dependency is missing, say so explicitly.

## Runtime Assumptions
- Lua code targets Neovim's embedded Lua runtime.
- Tooling metadata declares `lua51` in `neovim.yml`.
- Selene uses `std = "neovim"`.
- Production modules assume Neovim globals like `vim`, `vim.api`, and `vim.fn` exist.

## Code Organization
- Most Lua files follow one of two patterns:
  - plugin spec files that `return { ... }`
  - module files that start with `local M = {}` and end with `return M`
- Put `require` statements near the top.
- Keep private helper functions above exported functions when practical.
- Prefer small helpers over deeply nested inline logic.
- Keep plugin-specific helpers next to the plugin they support.
- Put test-only support code in `tests/helpers/`, not production modules.

## Imports And Requires
- Existing code often uses `require "module.path"` for simple string-literal imports.
- `require("module.path")` is also used when immediately indexing or when clearer in context.
- Match the style already used in the file you are editing.
- Group local module requires together near the top of the file.
- Avoid dynamic requires unless they help with optional dependencies or startup cost.
- Use `pcall(require, ...)` when a dependency may be absent at runtime.

## Formatting
- `stylua` is the source of truth for Lua formatting.
- Do not hand-align whitespace for aesthetics.
- Some files still contain legacy tab-indented blocks; prefer normalized formatter output over preserving manual spacing.
- Keep blank lines between logical sections, not between every statement.
- Do not add semicolons.
- Expand tables when options become multi-line or hard to scan.
- Respect `-- stylua: ignore` only where layout is intentionally hand-crafted.

## Naming
- Use `snake_case` for file names, locals, and function names.
- Use descriptive helper names such as `find_status_entry`, `refresh_hidden_explorer`, or `capture_echoes`.
- Prefix booleans and predicates with `is_`, `has_`, `can_`, or `ok_` when it helps clarity.
- Reserve ALL_CAPS for genuine constants only.
- Plugin spec tables usually keep descriptive keys rather than temporary aliases.

## Types And Annotations
- Use EmmyLua annotations where they materially help editor support.
- Existing code uses `---@type LazySpec`, `---@type AstroLSPOpts`, and targeted `---@diagnostic` comments.
- Add annotations for plugin spec returns and tricky option/state tables.
- Do not over-annotate obvious locals.
- Prefer clear table structure and naming before reaching for comments.

## Error Handling
- Prefer early-return guard clauses.
- Use `pcall` for optional plugin modules and unstable integrations.
- Use `vim.notify(..., vim.log.levels.ERROR/WARN)` for user-visible runtime failures.
- In async callbacks, wrap UI-facing work in `vim.schedule` when needed.
- Use `assert(...)` freely in tests and test helpers.
- In production code, reserve hard assertions for true invariants; prefer graceful notifications for recoverable problems.

## Neovim-Specific Patterns
- Use `vim.api.nvim_create_autocmd` and `vim.api.nvim_create_augroup` for autocommands.
- Use `vim.keymap.set` for mappings.
- Prefer buffer- or tab-scoped behavior when integrating with plugin UIs.
- Validate windows, buffers, and tabpages before using them.
- Use `vim.deepcopy` when copying state that should not be mutated in place.
- Use `vim.tbl_extend("force", ...)` for merged option or state tables.

## Plugin Configuration Style
- AstroNvim/Lazy plugin specs are returned directly as Lua tables.
- Keep `opts`, `config`, `keys`, `cmd`, and `event` sections easy to scan.
- Preserve existing `desc` strings unless behavior changes.
- If you disable inherited mappings, follow the existing pattern of setting that entry to `false`.
- Move custom behavior into local helper modules when a setup table becomes too large.

## Testing Style
- Use Busted-style `describe`, `it`, `before_each`, and `after_each` blocks.
- Prefer helper-driven setup over repeated temp repo/editor boilerplate.
- Use explicit wait helpers for async UI behavior.
- Keep test names behavior-oriented and specific.
- Clean up temporary repos and editor state in teardown paths.

## Shell Script Style
- `setup.sh` is Bash, not POSIX `sh`.
- Keep `set -euo pipefail` at the top of Bash scripts.
- Use uppercase names for global script variables.
- Use `snake_case` for shell function names.
- Quote variable expansions unless unquoted behavior is intentional.
- Prefer `[[ ... ]]` in Bash conditionals.

## Practical Editing Advice
- Preserve the existing architecture; this repo is highly personalized and plugin-specific.
- Avoid broad refactors unless they clearly simplify a localized area.
- Do not remove Unicode artwork or decorative UI content unless the task requires it.
- For CodeDiff work, read neighboring files under `lua/plugins/git/codediff/` before changing behavior.
- For LSP or formatter changes, inspect both `lua/plugins/lsp/` and Mason/conform settings together.
- When adding tests, use the existing Plenary harness rather than inventing a new runner.

## Minimal Validation Checklist
- Format changed Lua with `stylua`.
- Lint Lua with `selene .` when feasible.
- Run the focused spec command for localized test work.
- Run `./tests/run.sh` for broader CodeDiff behavior changes.
