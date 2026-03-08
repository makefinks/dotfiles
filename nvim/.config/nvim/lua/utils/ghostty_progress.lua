local M = {}

local group = vim.api.nvim_create_augroup("UserGhosttyLspProgress", { clear = true })
local progress_ids = {}
local active_tokens = {}

local function supports_ghostty_progress()
	return (vim.env.TERM or ""):match("ghostty")
		or vim.env.TERM_PROGRAM == "ghostty"
		or vim.env.GHOSTTY_BIN_DIR ~= nil
		or vim.env.GHOSTTY_RESOURCES_DIR ~= nil
end

local function supports_nvim_echo_progress()
	return vim.fn.has "nvim-0.12" == 1
end

local function tmux_wrap(sequence)
	if not vim.env.TMUX then
		return sequence
	end

	return "\27Ptmux;" .. sequence:gsub("\27", "\27\27") .. "\27\\"
end

local function send_osc_progress(state, percent)
	local suffix = percent ~= nil and string.format(";%d", percent) or ""
	local sequence = string.format("\27]9;4;%d%s\7", state, suffix)
	vim.api.nvim_chan_send(vim.v.stderr, tmux_wrap(sequence))
end

local function clear_terminal_progress()
	send_osc_progress(0)
end

local function token_key(client_id, token)
	return string.format("%s:%s", client_id, vim.inspect(token))
end

local function truncate_message(message)
	if not message or message == "" then
		return "done"
	end

	if #message > 40 then
		return message:sub(1, 37) .. "..."
	end

	return message
end

local function render_terminal_progress()
	local total = 0
	local count = 0

	for _, item in pairs(active_tokens) do
		if type(item.percentage) == "number" then
			total = total + math.max(0, math.min(100, item.percentage))
			count = count + 1
		end
	end

	if next(active_tokens) == nil then
		clear_terminal_progress()
		return
	end

	if count == 0 then
		send_osc_progress(3)
		return
	end

	send_osc_progress(1, math.floor(total / count + 0.5))
end

local function handle_echo_progress(ev)
	local value = ev.data.params.value or {}
	local key = token_key(ev.data.client_id, ev.data.params.token)

	local message = truncate_message(value.message)
	local title = value.title or "LSP"
	local status = value.kind ~= "end" and "running" or "success"

	vim.schedule(function()
		progress_ids[key] = vim.api.nvim_echo({ { message } }, false, {
			id = progress_ids[key],
			kind = "progress",
			title = title,
			status = status,
			percent = value.percentage,
		})
	end)

	if value.kind == "end" then
		progress_ids[key] = nil
	end
end

local function handle_terminal_progress(ev)
	local value = ev.data.params.value or {}
	local key = token_key(ev.data.client_id, ev.data.params.token)

	if value.kind == "end" then
		active_tokens[key] = nil
	else
		active_tokens[key] = {
			percentage = value.percentage,
		}
	end

	vim.schedule(render_terminal_progress)
end

function M.setup()
	if not supports_ghostty_progress() then
		return
	end

	vim.api.nvim_create_autocmd("LspProgress", {
		group = group,
		callback = function(ev)
			if supports_nvim_echo_progress() and not vim.env.TMUX then
				handle_echo_progress(ev)
				return
			end

			handle_terminal_progress(ev)
		end,
		desc = "Mirror LSP progress into Ghostty's native progress bar",
	})

	vim.api.nvim_create_autocmd({ "VimLeavePre", "ExitPre" }, {
		group = group,
		callback = clear_terminal_progress,
		desc = "Clear Ghostty progress on exit",
	})
end

return M
