return {
	{
		"igorlfs/nvim-dap-view",
		opts = {
			keymaps = {
				scopes = {
					copy_value = "c",
					toggle = { "<2-LeftMouse>", "s" },
					set_value = "<CR>",
				},
				watches = {
					toggle = { "<2-LeftMouse>", "s" },
					set_value = "<CR>",
				},
				hover = {
					toggle = { "<2-LeftMouse>", "s" },
					set_value = "<CR>",
				},
			},
			-- Avoid "uselast": dap-view's window has winfixbuf, so jumping to a
			-- source location in the last-used window fails with E1513.
			switchbuf = "useopen,usetab",
			virtual_text = {
				enabled = true,
				position = "inline",
			},
			winbar = {
				show_keymap_hints = false,
				base_sections = {
					watches = { label = "Watch", keymap = "W" },
					scopes = { label = "Scope", keymap = "S" },
					exceptions = { label = "Except", keymap = "E" },
					breakpoints = { label = "Break", keymap = "B" },
					threads = { label = "Thread", keymap = "T" },
					repl = { label = "REPL", keymap = "R" },
					console = { label = "Console", keymap = "C" },
				},
				controls = {
					enabled = true,
					position = "right",
				},
			},
			windows = {
				position = "right",
				size = 0.4,
				terminal = {
					position = "below",
					size = 0.4,
				},
			},
		},
		config = function(_, opts)
			require("dap-view").setup(opts)

			require("dap-view.scopes.keymaps").copy_value = {
				action = function()
					require("dap-view.util.trigger").at_cursor(function(line)
						local state = require("dap-view.state")
						local path = state.line_to_variable_path[line]
						local value = path and state.variable_path_to_value[path]
						if not value then
							vim.notify("No scope value under cursor", vim.log.levels.WARN)
							return
						end

						vim.fn.setreg('"', value)
						vim.fn.setreg("+", value)
						vim.notify("Copied scope value")
					end)
				end,
				desc = "copy value",
			}

			local function clear_dapview_restore_size()
				local ok, state = pcall(require, "dap-view.state")
				if not ok or not state.winnr or not vim.api.nvim_win_is_valid(state.winnr) then
					return
				end

				-- dap-view restores these on WinNew/WinClosed. Search/completion UI can
				-- trigger those events, so clear them after manual sizing/search usage.
				state.og_width = nil
				state.og_height = nil
			end

			local group = vim.api.nvim_create_augroup("UserDapViewStableSize", { clear = true })
			vim.api.nvim_create_autocmd({ "WinResized", "CmdlineEnter", "CmdlineLeave" }, {
				group = group,
				callback = clear_dapview_restore_size,
			})
		end,
	},
	{
		"mfussenegger/nvim-dap",
		optional = true,
		opts = function()
			local dap = require("dap")
			local dap_status_timer
			local dap_status_frame = 1
			local dap_status_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

			-- Keep a source-line breadcrumb while execution is running. nvim-dap clears
			-- DapStopped immediately on continue/step, which otherwise makes slow steps
			-- feel like they have no visible origin.
			local dap_last_stop_ns = vim.api.nvim_create_namespace("user_dap_last_stop")
			local dap_last_stop_mark

			local function redraw_status()
				vim.schedule(function()
					vim.cmd.redrawstatus()
				end)
			end

			local function stop_dap_status_timer()
				if dap_status_timer then
					dap_status_timer:stop()
					dap_status_timer:close()
					dap_status_timer = nil
				end
			end

			local function start_dap_status_timer()
				if dap_status_timer then
					return
				end

				dap_status_timer = vim.uv.new_timer()
				dap_status_timer:start(0, 120, function()
					dap_status_frame = dap_status_frame % #dap_status_frames + 1
					vim.g.dap_status_frame = dap_status_frames[dap_status_frame]
					redraw_status()
				end)
			end

			local function set_dap_status(status)
				vim.g.dap_status = status

				if status == "running" then
					start_dap_status_timer()
				else
					stop_dap_status_timer()
				end

				redraw_status()
			end

			local function clear_last_stop_mark()
				if not dap_last_stop_mark then
					return
				end

				if vim.api.nvim_buf_is_valid(dap_last_stop_mark.bufnr) then
					vim.api.nvim_buf_del_extmark(dap_last_stop_mark.bufnr, dap_last_stop_ns, dap_last_stop_mark.id)
				end

				dap_last_stop_mark = nil
			end

			local function mark_last_stop_line()
				local session = dap.session()
				local frame = session and session.current_frame
				local source = frame and frame.source
				local path = source and source.path
				local line = frame and frame.line
				if not path or not line then
					return
				end

				local bufnr = vim.fn.bufadd(path)
				vim.fn.bufload(bufnr)
				if not vim.api.nvim_buf_is_valid(bufnr) then
					return
				end

				clear_last_stop_mark()
				local id = vim.api.nvim_buf_set_extmark(bufnr, dap_last_stop_ns, line - 1, 0, {
					line_hl_group = "DapLastStoppedLine",
					number_hl_group = "DapStoppedSign",
					priority = 90,
				})
				dap_last_stop_mark = { bufnr = bufnr, id = id }
			end

			local function mark_last_stop_before_resume()
				-- Capture the current frame before sending the resume request; after that,
				-- the adapter may no longer expose a stopped frame until the next pause.
				mark_last_stop_line()
				set_dap_status("running")
			end

			dap.listeners.before.launch.user_dap_status = function()
				set_dap_status("running")
			end
			dap.listeners.before.attach.user_dap_status = function()
				set_dap_status("running")
			end
			dap.listeners.after.event_initialized.user_dap_status = function()
				set_dap_status("running")
			end
			dap.listeners.after.event_continued.user_dap_status = function()
				set_dap_status("running")
			end
			dap.listeners.after.continue.user_dap_status = function()
				set_dap_status("running")
			end

			dap.listeners.before.continue.user_dap_last_stop = mark_last_stop_before_resume
			dap.listeners.before.next.user_dap_last_stop = mark_last_stop_before_resume
			dap.listeners.before.stepIn.user_dap_last_stop = mark_last_stop_before_resume
			dap.listeners.before.stepOut.user_dap_last_stop = mark_last_stop_before_resume

			dap.listeners.after.event_stopped.user_dap_status = function()
				-- Once paused again, the real DapStopped sign/line highlight takes over.
				clear_last_stop_mark()
				set_dap_status("paused")
			end
			dap.listeners.before.event_terminated.user_dap_status = function()
				clear_last_stop_mark()
				set_dap_status(nil)
			end
			dap.listeners.before.event_exited.user_dap_status = function()
				clear_last_stop_mark()
				set_dap_status(nil)
			end
			dap.listeners.before.disconnect.user_dap_status = function()
				clear_last_stop_mark()
				set_dap_status(nil)
			end

			-- dap-view's set_value action doesn't re-render scopes or inline virtual
			-- text after the async setVariable/setExpression request completes.
			-- Virtual text reads from frame.scopes[*].variables, which are only
			-- refreshed by the scopes/variables DAP events. setVariable doesn't
			-- trigger those, so we re-request scopes here before refreshing.
			local function refresh_scopes_after_set()
				vim.schedule(function()
					coroutine.wrap(function()
						local session = dap.session()
						local frame = session and session.current_frame
						if not frame then
							return
						end

						local err, scopes_resp = session:request("scopes", { frameId = frame.id })
						if err or not scopes_resp then
							return
						end

						frame.scopes = scopes_resp.scopes
						for _, scope in ipairs(frame.scopes or {}) do
							if not scope.expensive then
								local v_err, v_resp = session:request("variables", {
									variablesReference = scope.variablesReference,
								})
								if not v_err and v_resp then
									scope.variables = v_resp.variables
									for _, v in ipairs(scope.variables or {}) do
										v.parent = scope
									end
								end
							end
						end

						local dv_state = require("dap-view.state")
						if dv_state.current_section == "scopes" then
							require("dap-view.views").switch_to_view("scopes")
						end

						require("dap-view.virtual-text").virtual_text()
					end)()
				end)
			end

			dap.listeners.after.setVariable.user_dap_refresh_scopes = refresh_scopes_after_set
			dap.listeners.after.setExpression.user_dap_refresh_scopes = refresh_scopes_after_set

			vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#252345", default = true })
			vim.api.nvim_set_hl(0, "DapLastStoppedLine", { bg = "#252345", default = true })
			vim.api.nvim_set_hl(0, "DapStoppedSign", { fg = "#89b4fa", default = true })
			vim.fn.sign_define("DapStopped", {
				text = "",
				texthl = "DapStoppedSign",
				linehl = "DapStoppedLine",
				numhl = "DapStoppedSign",
			})

			dap.adapters.python = {
				type = "executable",
				command = vim.fn.exepath("debugpy-adapter"),
			}
			dap.configurations.python = {
				{
					type = "python",
					request = "launch",
					name = "Launch file",
					program = "${file}",
					python = function()
						return vim.fn.exepath("python") ~= "" and vim.fn.exepath("python") or vim.fn.exepath("python3")
					end,
					cwd = "${workspaceFolder}",
				},
			}
		end,
	},
}
