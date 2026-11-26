-- Selects the vercel colorscheme and remembers a chosen variant across restarts.
-- Without a saved choice, Neovim follows the terminal's reported background.
local M = {}

local state = vim.fs.joinpath(vim.fn.stdpath("state"), "theme")

local function saved()
	local ok, lines = pcall(vim.fn.readfile, state, "", 1)
	local mode = ok and lines[1]
	return (mode == "dark" or mode == "light") and mode or nil
end

function M.set(mode)
	if mode == "auto" then
		vim.fn.delete(state)
		vim.notify("Theme follows the terminal from the next start")
		return
	end
	if mode == nil or mode == "" then
		mode = vim.o.background == "dark" and "light" or "dark"
	end
	if mode ~= "dark" and mode ~= "light" then
		error("Choose dark, light or auto", 0)
	end
	vim.fn.mkdir(vim.fs.dirname(state), "p")
	vim.fn.writefile({ mode }, state)
	vim.o.background = mode
	if vim.g.colors_name ~= "vercel" then
		vim.cmd.colorscheme("vercel")
	end
end

function M.setup()
	local mode = saved()
	if mode then
		vim.o.background = mode
	end
	vim.cmd.colorscheme("vercel")

	vim.api.nvim_create_user_command("Theme", function(opts)
		M.set(opts.args)
	end, {
		nargs = "?",
		complete = function()
			return { "dark", "light", "auto" }
		end,
		desc = "Set, toggle or stop saving the light/dark theme",
	})
	vim.keymap.set("n", "<leader>ut", M.set, { desc = "Toggle light/dark theme" })
end

return M
