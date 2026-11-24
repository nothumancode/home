-- Home Manager supplies the pinned nixpkgs package set in the 'packages' local.
local source = {}
local keywords = { "assert", "else", "if", "in", "inherit", "let", "rec", "then", "with" }

function source.new()
	return setmetatable({ cache = {} }, { __index = source })
end

function source:get_trigger_characters()
	return { "." }
end

function source:get_completions(ctx, callback)
	local before = ctx.line:sub(1, ctx.cursor[2])
	local start, _, scope, prefix = before:find("([%w_'.-]+)%.([%w_'-]*)$")
	local root = scope and scope:match("^[^.]+")
	if (root ~= "lib" and root ~= "pkgs") or scope:sub(-1) == "." or scope:find("..", 1, true) then
		return callback()
	end

	-- Only complete selections rooted at a variable, including inside Nix string interpolation.
	vim.treesitter.get_parser(ctx.bufnr):parse()
	local node = vim.treesitter.get_node({ bufnr = ctx.bufnr, pos = { ctx.cursor[1] - 1, start - 1 } })
	if not node or node:type() ~= "identifier" or node:parent():type() ~= "variable_expression" then
		return callback()
	end

	local path = root == "pkgs" and scope:sub(5) or "." .. scope
	local function respond(names)
		local items = {}
		-- The top-level package set has tens of thousands of names. Narrow large lists as the user types.
		local large = #names > 1500
		for _, name in ipairs(names) do
			if not large or vim.startswith(name, prefix) then
				local insert = name
				if not name:match("^[%a_][%w_'-]*$") or vim.list_contains(keywords, name) then
					insert = vim.json.encode(name):gsub("%${", "\\${")
				end
				items[#items + 1] = { label = name, insertText = insert }
				if large and #items == 100 then
					break
				end
			end
		end
		callback({ items = items, is_incomplete_forward = large, is_incomplete_backward = large })
	end

	if self.cache[path] then
		return respond(self.cache[path])
	end
	local process = vim.system(
		{
			"nix",
			"eval",
			"--offline",
			"--json",
			"--apply",
			"builtins.attrNames",
			packages .. path,
		},
		{ text = true },
		vim.schedule_wrap(function(result)
			if result.code ~= 0 then
				return callback()
			end
			self.cache[path] = vim.json.decode(result.stdout)
			respond(self.cache[path])
		end)
	)
	return function()
		process:kill("sigterm")
	end
end

return source
