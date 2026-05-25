local adapter = require("user.codediff.adapter")

local M = {}

local function filter_status_entries(entries)
	local filtered = {}

	for _, entry in ipairs(entries or {}) do
		if entry.status ~= "??" then
			filtered[#filtered + 1] = vim.deepcopy(entry)
		end
	end

	return filtered
end

function M.untracked_status_result(status_result)
	if not status_result then
		return nil
	end

	return {
		unstaged = filter_status_entries(status_result.unstaged),
		staged = filter_status_entries(status_result.staged),
		conflicts = filter_status_entries(status_result.conflicts),
	}
end

function M.with_untracked_filtered_git(functions, callback)
	local git = adapter.git(nil, functions, { notify = false })
	if not git then
		return callback(nil)
	end

	local originals = {}
	local restored = false

	local function restore()
		if restored then
			return
		end

		for name, fn in pairs(originals) do
			git[name] = fn
		end
		restored = true
	end

	local function filter_callback(fn)
		return function(err, status_result)
			fn(err, M.untracked_status_result(status_result))
		end
	end

	for _, name in ipairs(functions or {}) do
		originals[name] = git[name]
	end

	if originals.get_status then
		git.get_status = function(git_root, fn)
			return originals.get_status(git_root, filter_callback(fn))
		end
	end

	if originals.get_diff_revision then
		git.get_diff_revision = function(revision, git_root, fn)
			return originals.get_diff_revision(revision, git_root, filter_callback(fn))
		end
	end

	if originals.get_diff_revisions then
		git.get_diff_revisions = function(rev1, rev2, git_root, fn)
			return originals.get_diff_revisions(rev1, rev2, git_root, filter_callback(fn))
		end
	end

	local ok, result = pcall(callback, restore)
	if not ok then
		restore()
		error(result)
	end

	return result, restore
end

return M
