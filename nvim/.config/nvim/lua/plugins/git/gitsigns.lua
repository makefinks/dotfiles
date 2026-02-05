return {
	"lewis6991/gitsigns.nvim",
	opts = function(_, opts)
		-- Remove <leader>gd from gitsigns (we use vgit instead)
		if opts.on_attach then
			local original_on_attach = opts.on_attach
			opts.on_attach = function(bufnr)
				original_on_attach(bufnr)
				-- gitsigns key defaults can change across versions; avoid hard failures.
				pcall(vim.keymap.del, "n", "<Leader>gd", { buffer = bufnr })
			end
		end
	end,
}
