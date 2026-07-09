local function is_autoformat_enabled(bufnr)
	local enabled = vim.b[bufnr].autoformat
	if enabled == nil then
		return vim.g.user_autoformat_enabled == true
	end
	return enabled
end

local function notify_autoformat(scope, enabled)
	vim.notify(string.format("%s autoformatting %s", scope, enabled and "on" or "off"))
end

return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ToggleAutoformat", "ToggleAutoformatGlobal" },
	keys = {
		{
			"<leader>lf",
			function()
				require("conform").format({ lsp_format = "fallback" })
			end,
			mode = { "n", "x" },
			desc = "Format buffer or selection",
		},
	},
	desc = "Configurable format on save with conform.nvim.",
	config = function()
		if vim.g.user_autoformat_enabled == nil then
			vim.g.user_autoformat_enabled = false
		end

		vim.api.nvim_create_user_command("ToggleAutoformat", function()
			local bufnr = vim.api.nvim_get_current_buf()
			vim.b[bufnr].autoformat = not is_autoformat_enabled(bufnr)
			notify_autoformat("Buffer", vim.b[bufnr].autoformat)
		end, { desc = "Toggle format on save for the current buffer" })

		vim.api.nvim_create_user_command("ToggleAutoformatGlobal", function()
			vim.g.user_autoformat_enabled = not vim.g.user_autoformat_enabled
			notify_autoformat("Global", vim.g.user_autoformat_enabled)
		end, { desc = "Toggle format on save globally" })

		require("conform").setup({
			format_on_save = function(bufnr)
				if not is_autoformat_enabled(bufnr) then
					return
				end
				return { timeout_ms = 1500, lsp_format = "fallback", notify_on_error = false }
			end,

			-- Define formatters for each filetype
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_format" },
				javascript = { "biome", "prettierd", "prettier" },
				javascriptreact = { "biome", "prettierd", "prettier" },
				typescript = { "biome", "prettierd", "prettier" },
				typescriptreact = { "biome", "prettierd", "prettier" },
				json = { "biome", "prettierd", "prettier" },
				yaml = { "prettierd", "prettier" },
				markdown = { "prettierd", "prettier" },
				html = { "prettierd", "prettier" },
				css = { "prettierd", "prettier" },
				sh = { "shfmt" },
				bash = { "shfmt" },
				toml = { "taplo" },
			},
		})
	end,
}
