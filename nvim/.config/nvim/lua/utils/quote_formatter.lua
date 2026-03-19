-- Utils for the quote display in the snacks dashboard

local M = {}

local function vlen(s)
	return vim.fn.strdisplaywidth(s)
end

-- Utility function to wrap text to max width
local function wrap_text(text, max_width)
	local lines = {}
	local line = ""

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

local function center_line(text, width)
	local content_width = vlen(text)
	if content_width >= width then
		return text
	end

	local total_padding = width - content_width
	local left_padding = math.floor(total_padding / 2)
	local right_padding = total_padding - left_padding
	return string.rep(" ", left_padding) .. text .. string.rep(" ", right_padding)
end

-- Format quote as boxed text
function M.format_quote(quote_text, quote_author)
	local max_width = 100
	local wrapped = wrap_text(quote_text, max_width)
	local quote_line_count = #wrapped

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
	for index, l in ipairs(wrapped) do
		local content = l
		if vlen(content) > width then
			content = content:sub(1, width)
		end
		if index <= quote_line_count and vlen(content) > 0 then
			content = center_line(content, width)
		end
		local padding = string.rep(" ", width - vlen(content))
		table.insert(out, "│ " .. content .. padding .. " │")
	end
	table.insert(out, bottom)
	return table.concat(out, "\n")
end

return M
