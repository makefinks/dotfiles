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
}
