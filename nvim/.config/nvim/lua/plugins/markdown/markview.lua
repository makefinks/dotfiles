return {
	"OXY2DEV/markview.nvim",
	ft = { "markdown", "quarto", "rmd" },
	config = function()
		vim.api.nvim_create_autocmd("User", {
			pattern = "DiffviewDiffBufRead",
			callback = function(args)
				local ok, commands = pcall(require, "markview.commands")
				if ok then
					commands.disable(args.buf)
				end
			end,
		})
	end,
}
