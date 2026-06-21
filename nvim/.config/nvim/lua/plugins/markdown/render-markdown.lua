---@type LazySpec
return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown" },
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-mini/mini.icons",
	},
	---@module "render-markdown"
	---@type render.md.UserConfig
	opts = {
		enabled = false,
		completions = {
			lsp = { enabled = false },
		},
	},
	keys = {
		{ "<Leader>mp", "<Cmd>RenderMarkdown preview<CR>", ft = "markdown", desc = "Markdown preview pane" },
		{ "<Leader>mt", "<Cmd>RenderMarkdown toggle<CR>", ft = "markdown", desc = "Toggle Markdown render" },
	},
}
