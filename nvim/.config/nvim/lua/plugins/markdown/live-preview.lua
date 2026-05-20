local function start_live_preview()
	local filepath = vim.api.nvim_buf_get_name(0)
	if filepath == "" then
		vim.notify("Save the file before starting live preview", vim.log.levels.WARN)
		return
	end

	local livepreview = require("livepreview")
	livepreview.close()

	vim.defer_fn(function()
		vim.cmd("LivePreview start " .. vim.fn.fnameescape(filepath))
	end, 100)
end

return {
	"brianhuster/live-preview.nvim",
	cmd = { "LivePreview" },
	ft = { "markdown" },
	opts = {
		picker = "fzf-lua",
	},
	config = function(_, opts)
		require("livepreview.config").set(opts)
	end,
	keys = {
		{ "<Leader>mb", start_live_preview, ft = "markdown", desc = "Markdown browser preview" },
		{ "<LocalLeader>b", start_live_preview, ft = "markdown", desc = "Browser preview" },
		{ "<LocalLeader>B", "<Cmd>LivePreview close<CR>", ft = "markdown", desc = "Close browser preview" },
	},
}
