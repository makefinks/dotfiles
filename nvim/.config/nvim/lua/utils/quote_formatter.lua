-- Utils for the quote display in the snacks dashboard

local M = {}

-- Utility function to wrap text to max width
local function wrap_text(text, max_width)
	local lines = {}
	local line = ""
	local function vlen(s)
		return vim.fn.strdisplaywidth(s)
	end

	for word in text:gmatch("%S+") do
		if vlen(line) == 0 then
			line = word
		elseif vlen(line .. " " .. word) <= max_width then
			line = line .. " " .. word
		else
			table.insert(lines, line)
			line = word
		end
	end
	if vlen(line) > 0 then
		table.insert(lines, line)
	end
	return lines
end

-- Format quote as boxed text
function M.format_quote(quote_text, quote_author)
	local vlen = function(s)
		return vim.fn.strdisplaywidth(s)
	end
	local max_width = 100
	local wrapped = wrap_text(quote_text, max_width)

	if quote_author and #quote_author > 0 then
		local author_line = "— " .. quote_author
		if vlen(author_line) > max_width then
			author_line = author_line:sub(1, max_width)
		end
		table.insert(wrapped, "")
		table.insert(wrapped, author_line)
	end

	local width = 0
	for _, l in ipairs(wrapped) do
		width = math.max(width, vlen(l))
	end
	if width > max_width then
		width = max_width
	end

	local top = "┌" .. string.rep("─", width + 2) .. "┐"
	local bottom = "└" .. string.rep("─", width + 2) .. "┘"
	local out = { top }
	for _, l in ipairs(wrapped) do
		local content = l
		if vlen(content) > width then
			content = content:sub(1, width)
		end
		local padding = string.rep(" ", width - vlen(content))
		table.insert(out, "│ " .. content .. padding .. " │")
	end
	table.insert(out, bottom)
	return table.concat(out, "\n")
end

return M
