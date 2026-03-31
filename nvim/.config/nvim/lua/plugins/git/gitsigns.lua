return {
	"lewis6991/gitsigns.nvim",
	opts = function(_, opts)
		-- Remove gitsigns hunk-stage mappings so codediff can own <leader>gs for whole-buffer staging.
		if opts.on_attach then
			local original_on_attach = opts.on_attach
			opts.on_attach = function(bufnr)
				original_on_attach(bufnr)

				-- gitsigns key defaults can change across versions; avoid hard failures.
				pcall(vim.keymap.del, "n", "<Leader>gd", { buffer = bufnr })
				pcall(vim.keymap.del, "n", "<Leader>gs", { buffer = bufnr })
				pcall(vim.keymap.del, "v", "<Leader>gs", { buffer = bufnr })
			end
		end
	end,
}
