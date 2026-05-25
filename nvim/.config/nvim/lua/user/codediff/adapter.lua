local helpers = require("user.codediff.helpers")

local M = {}

function M.git(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.core.git", error_message, opts)
end

function M.lifecycle(error_message, opts)
	return helpers.require_module("codediff.ui.lifecycle", error_message or "Codediff is not available", opts)
end

function M.loaded_lifecycle()
	return helpers.get_loaded_module("codediff.ui.lifecycle")
end

function M.view(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.ui.view", error_message, opts)
end

function M.explorer(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.ui.explorer", error_message, opts)
end

function M.explorer_refresh(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions or "refresh" })
	return helpers.require_module("codediff.ui.explorer.refresh", error_message, opts)
end

function M.explorer_tree(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.ui.explorer.tree", error_message, opts)
end

function M.explorer_render(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.ui.explorer.render", error_message, opts)
end

function M.explorer_actions(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.ui.explorer.actions", error_message, opts)
end

function M.navigation(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.ui.view.navigation", error_message, opts)
end

function M.inline_view(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.ui.view.inline_view", error_message, opts)
end

function M.side_by_side(error_message, functions, opts)
	opts = vim.tbl_extend("force", opts or {}, { functions = functions })
	return helpers.require_module("codediff.ui.view.side_by_side", error_message, opts)
end

function M.config(error_message, opts)
	return helpers.require_module("codediff.config", error_message, opts)
end

return M
