return {
	{
		"rebelot/heirline.nvim",
		opts = function(_, opts)
			local status = require("astroui.status")

			local function codediff_view()
				return package.loaded["plugins.git.codediff.view"]
			end

			local function codediff_statusline_state()
				local view = codediff_view()
				return view and view.get_statusline_state and view.get_statusline_state() or nil
			end

			local function codediff_statusline_progress()
				local state = codediff_statusline_state()
				return state and state.progress or vim.b.codediff_status_progress
			end

			local function not_codediff()
				return codediff_statusline_progress() == nil
			end

			local function hunk_progress()
				local view = codediff_view()
				return view and view.get_statusline_hunk_progress and view.get_statusline_hunk_progress() or nil
			end

			opts.statusline = {
				-- default highlight for the entire statusline
				hl = { fg = "fg", bg = "bg" },
				-- each element following is a component in astroui.status module

				-- add the vim mode component
				status.component.mode({
					-- enable mode text with padding as well as an icon before it
					mode_text = {
						icon = { kind = "VimIcon", padding = { right = 1, left = 1 } },
					},
					-- surround the component with a separators
					surround = {
						separator = "left",
						-- set the color of the surrounding based on the current mode using astronvim.utils.status module
						color = function()
							return { main = status.hl.mode_bg(), right = "blank_bg" }
						end,
					},
				}),
				-- we want an empty space here so we can use the component builder to make a new section with just an empty string
				status.component.builder({
					{ provider = "" },
					-- define the surrounding separator and colors to be used inside of the component
					-- and the color to the right of the separated out section
					surround = {
						separator = "left",
						color = { main = "blank_bg", right = "file_info_bg" },
					},
				}),
				-- add a section for the currently opened file information
				status.component.file_info({
					-- enable the file_icon and disable the highlighting based on filetype
					filename = {
						fname = function(nr)
							local bufnr = nr and vim.api.nvim_buf_is_valid(nr) and nr or vim.api.nvim_get_current_buf()
							local state = codediff_statusline_state()
							return vim.b[bufnr].codediff_status_name
								or state and state.name
								or vim.api.nvim_buf_get_name(bufnr)
						end,
						fallback = "Empty",
					},
					-- disable some of the info
					filetype = false,
					file_read_only = false,
					-- add padding
					padding = { right = 1 },
					-- define the section separator
					surround = { separator = "left", condition = false },
				}),
				-- add a component for the current git branch if it exists and use no separator for the sections
				status.component.git_branch({
					git_branch = { padding = { left = 1 } },
					surround = { separator = "none" },
				}),
				-- add a component for the current git diff if it exists and use no separator for the sections
				-- codediff now handles the dedicated diff view, so this keeps the statusline lightweight.
				status.component.git_diff({
					padding = { left = 1 },
					surround = { separator = "none" },
				}),
				-- fill the rest of the statusline
				-- the elements after this will appear in the middle of the statusline
				status.component.fill(),
				-- add a component to display if the LSP is loading, disable showing running client names, and use no separator
				status.component.lsp({
					condition = not_codediff,
					lsp_client_names = false,
					surround = { separator = "none", color = "bg" },
				}),
				-- fill the rest of the statusline
				-- the elements after this will appear on the right of the statusline
				status.component.fill(),
				-- add a component for the current diagnostics if it exists and use the right separator for the section
				status.component.diagnostics({ condition = not_codediff, surround = { separator = "right" } }),
				-- add a component to display LSP clients, disable showing LSP progress, and use the right separator
				status.component.lsp({
					condition = not_codediff,
					lsp_progress = false,
					surround = { separator = "right" },
				}),
				-- NvChad has some nice icons to go along with information, so we can create a parent component to do this
				-- all of the children of this table will be treated together as a single component
				{
					condition = not_codediff,
					-- define a simple component where the provider is just a folder icon
					status.component.builder({
						-- astronvim.get_icon gets the user interface icon for a closed folder with a space after it
						{ provider = require("astroui").get_icon("FolderClosed") },
						-- add padding after icon
						padding = { right = 1 },
						-- set the foreground color to be used for the icon
						hl = { fg = "bg" },
						-- use the right separator and define the background color
						surround = { separator = "right", color = "folder_icon_bg" },
					}),
					-- add a file information component and only show the current working directory name
					status.component.file_info({
						-- we only want filename to be used and we can change the fname
						-- function to get the current working directory name
						filename = {
							fname = function(nr)
								return vim.fn.getcwd(nr)
							end,
							padding = { left = 1 },
						},
						-- disable all other elements of the file_info component
						filetype = false,
						file_icon = false,
						file_modified = false,
						file_read_only = false,
						-- use no separator for this part but define a background color
						surround = {
							separator = "none",
							color = "file_info_bg",
							condition = false,
						},
					}),
				},
				-- the final component of the NvChad statusline is the navigation section
				-- this is very similar to the previous current working directory section with the icon
				{ -- make nav section with icon border
					condition = not_codediff,
					-- define a custom component with just a file icon
					status.component.builder({
						{ provider = require("astroui").get_icon("ScrollText") },
						-- add padding after icon
						padding = { right = 1 },
						-- set the icon foreground
						hl = { fg = "bg" },
						-- use the right separator and define the background color
						-- as well as the color to the left of the separator
						surround = {
							separator = "right",
							color = { main = "nav_icon_bg", left = "file_info_bg" },
						},
					}),
					-- add a navigation component and just display the percentage of progress in the file
					status.component.nav({
						-- add some padding for the percentage provider
						percentage = { padding = { right = 1 } },
						-- disable all other providers
						ruler = false,
						scrollbar = false,
						-- use no separator and define the background color
						surround = { separator = "none", color = "file_info_bg" },
					}),
				},
				status.component.builder({
					{
						provider = function()
							local hunk = hunk_progress()
							local progress = codediff_statusline_progress()
							if hunk then
								return string.format("File %s  Hunk %s", progress, hunk)
							end

							return "File " .. progress
						end,
					},
					condition = function()
						return codediff_statusline_progress() ~= nil
					end,
					surround = { separator = "none", color = "bg" },
				}),
			}
		end,
	},
}
