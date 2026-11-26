-- Navigation, editing helpers, Git and the keymap guide. Plugins come from mini.nvim
-- and which-key, installed by modules/neovim.nix. Icons stay ASCII: no Nerd Font is assumed.
local M = {}

local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

local function setup_mini()
	local icons = require("mini.icons")
	icons.setup({ style = "ascii" })
	icons.mock_nvim_web_devicons()

	local notify = require("mini.notify")
	notify.setup({ window = { config = { border = "rounded" }, winblend = 0 } })
	vim.notify = notify.make_notify()

	require("mini.pick").setup()
	require("mini.extra").setup()
	-- mini.files clears netrw's FileExplorer group to own directory buffers; create it first so
	-- that clearing does not fail before netrw loads.
	vim.api.nvim_create_augroup("FileExplorer", { clear = false })
	require("mini.files").setup({
		options = { permanent_delete = false }, -- deletions go to the trash directory
		windows = { preview = true, width_preview = 60 },
	})
	require("mini.git").setup()
	require("mini.diff").setup({
		view = { style = "sign", signs = { add = "+", change = "~", delete = "_" } },
	})
	require("mini.statusline").setup({ use_icons = false })
	require("mini.pairs").setup()
	require("mini.surround").setup()
	require("mini.splitjoin").setup()
	require("mini.move").setup()
	require("mini.bufremove").setup()

	-- Tree-sitter text objects (queries from nvim-treesitter-textobjects): af/if, ac/ic, ao/io.
	local ai = require("mini.ai")
	ai.setup({
		n_lines = 500,
		custom_textobjects = {
			f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
			c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
			o = ai.gen_spec.treesitter({
				a = { "@conditional.outer", "@loop.outer" },
				i = { "@conditional.inner", "@loop.inner" },
			}),
			g = require("mini.extra").gen_ai_spec.buffer(),
		},
	})

	local hipatterns = require("mini.hipatterns")
	local word = function(w)
		return "%f[%w]()" .. w .. "()%f[%W]"
	end
	hipatterns.setup({
		highlighters = {
			fixme = { pattern = word("FIXME"), group = "MiniHipatternsFixme" },
			hack = { pattern = word("HACK"), group = "MiniHipatternsHack" },
			todo = { pattern = word("TODO"), group = "MiniHipatternsTodo" },
			note = { pattern = word("NOTE"), group = "MiniHipatternsNote" },
			hex_color = hipatterns.gen_highlighter.hex_color(),
		},
	})

	require("mini.indentscope").setup({
		symbol = "|",
		draw = { delay = 50, animation = require("mini.indentscope").gen_animation.none() },
		options = { try_as_border = true },
	})
	vim.api.nvim_create_autocmd({ "FileType", "TermOpen" }, {
		group = vim.api.nvim_create_augroup("HomeIndentscope", { clear = true }),
		callback = function(ev)
			local ft = vim.bo[ev.buf].filetype
			if vim.bo[ev.buf].buftype ~= "" or ft == "help" or ft:match("^mini") then
				vim.b[ev.buf].miniindentscope_disable = true
			end
		end,
	})
end

local function setup_keymaps()
	local pick, extra = require("mini.pick").builtin, require("mini.extra").pickers
	local files, diff, git = require("mini.files"), require("mini.diff"), require("mini.git")
	local bufremove = require("mini.bufremove")
	local n = "n"

	-- Find
	map(n, "<leader>ff", pick.files, "Find files")
	map(n, "<leader>fg", pick.grep_live, "Live grep")
	map(n, "<leader>fw", function()
		pick.grep({ pattern = vim.fn.expand("<cword>") })
	end, "Grep word under cursor")
	map(n, "<leader>fb", pick.buffers, "Find buffer")
	map(n, "<leader>fh", pick.help, "Find help")
	map(n, "<leader>fr", pick.resume, "Resume last picker")
	map(n, "<leader>fo", extra.oldfiles, "Recent files")
	map(n, "<leader>f/", extra.buf_lines, "Search buffer lines")
	map(n, "<leader>fk", extra.keymaps, "Find keymap")
	map(n, "<leader>fc", extra.commands, "Find command")
	map(n, "<leader>fd", extra.diagnostic, "Find diagnostics")
	map(n, "<leader>fq", function()
		extra.list({ scope = "quickfix" })
	end, "Find in quickfix list")
	map(n, "<leader>?", extra.keymaps, "Find a keybinding")

	-- Files and buffers
	map(n, "<leader>e", function()
		local file = vim.api.nvim_buf_get_name(0)
		files.open(vim.fn.filereadable(file) == 1 and file or nil)
		files.reveal_cwd()
	end, "Explore files (current file)")
	map(n, "<leader>E", function()
		files.open(vim.fn.getcwd())
	end, "Explore files (working directory)")
	map(n, "<leader>bd", bufremove.delete, "Delete buffer (keep window)")
	map(n, "<leader>bo", function()
		local current = vim.api.nvim_get_current_buf()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if buf ~= current and vim.bo[buf].buflisted and not vim.bo[buf].modified then
				bufremove.delete(buf)
			end
		end
	end, "Delete other saved buffers")

	-- Git (Lazygit lives in home.terminals)
	map(n, "<leader>gd", diff.toggle_overlay, "Toggle Git diff overlay")
	map(n, "<leader>gh", function()
		extra.git_hunks({ scope = "unstaged" })
	end, "Find changed hunks")
	map(n, "<leader>gl", extra.git_commits, "Browse commits")
	map(n, "<leader>gL", function()
		extra.git_commits({ path = vim.fn.expand("%:p") })
	end, "Browse commits for this file")
	map({ "n", "x" }, "<leader>gb", git.show_at_cursor, "Show Git history at cursor")
	map(n, "<leader>gB", "<cmd>vertical Git blame -- %<cr>", "Blame file")

	-- Diagnostics lists
	map(n, "<leader>xx", function()
		extra.diagnostic({ scope = "all" })
	end, "Workspace diagnostics")
	map(n, "<leader>xb", function()
		extra.diagnostic({ scope = "current" })
	end, "Buffer diagnostics")
	map(n, "<leader>xl", vim.diagnostic.setloclist, "Diagnostics to location list")
	map(n, "<leader>xq", function()
		local open = vim.iter(vim.fn.getwininfo()):any(function(w)
			return w.quickfix == 1 and w.loclist == 0
		end)
		vim.cmd(open and "cclose" or "copen")
	end, "Toggle quickfix list")

	-- Preferences
	map(n, "<leader>uw", "<cmd>setlocal wrap!<cr>", "Toggle wrap")
	map(n, "<leader>ul", "<cmd>setlocal list!<cr>", "Toggle whitespace characters")
	map(n, "<leader>ur", "<cmd>setlocal relativenumber!<cr>", "Toggle relative numbers")
	map(n, "<leader>un", require("mini.notify").show_history, "Notification history")

	-- Windows and editing
	for _, key in ipairs({ "h", "j", "k", "l" }) do
		map(n, "<C-" .. key .. ">", "<C-w>" .. key, "Go to window " .. key)
	end
	map(n, "<Esc>", "<cmd>nohlsearch<cr><Esc>", "Clear search highlight")
	map("x", "<", "<gv", "Dedent and keep selection")
	map("x", ">", ">gv", "Indent and keep selection")
	-- Leaves terminal input without taking Esc from agents (Esc Esc rewinds in Claude Code and Codex).
	map("t", "<C-q>", "<C-\\><C-n>", "Leave terminal input")
end

local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("HomeEditor", { clear = true })
	vim.api.nvim_create_autocmd("TextYankPost", {
		group = group,
		callback = function()
			vim.hl.on_yank({ timeout = 150 })
		end,
	})
	-- Reload unmodified buffers when agents or external tools edit files on disk.
	vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermClose" }, {
		group = group,
		callback = function()
			if vim.fn.getcmdwintype() == "" then
				vim.cmd("checktime")
			end
		end,
	})
	-- Reopen files at the last edited position.
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		callback = function(ev)
			local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
			local ft = vim.bo[ev.buf].filetype
			if
				ft ~= "gitcommit"
				and ft ~= "gitrebase"
				and mark[1] > 0
				and mark[1] <= vim.api.nvim_buf_line_count(ev.buf)
			then
				pcall(vim.api.nvim_win_set_cursor, 0, mark)
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimResized", { group = group, command = "tabdo wincmd =" })
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = { "help", "qf", "checkhealth", "man", "git" },
		callback = function(ev)
			vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, desc = "Close window" })
		end,
	})
end

local function setup_which_key()
	local wk = require("which-key")
	-- Text labels replace which-key's Nerd Font key glyphs.
	local keys = { C = "C-", M = "M-", D = "D-", S = "S-" }
	for _, name in ipairs({ "Up", "Down", "Left", "Right", "CR", "NL", "Esc", "BS", "Space", "Tab" }) do
		keys[name] = "<" .. name .. ">"
	end
	keys.ScrollWheelDown, keys.ScrollWheelUp = "<ScrollDown>", "<ScrollUp>"
	for i = 1, 12 do
		keys["F" .. i] = "<F" .. i .. ">"
	end
	wk.setup({ preset = "helix", icons = { mappings = false, keys = keys } })
	wk.add({
		{ "<leader>a", group = "Agents and terminals" },
		{ "<leader>b", group = "Buffers" },
		{ "<leader>c", group = "Code" },
		{ "<leader>f", group = "Find" },
		{ "<leader>g", group = "Git" },
		{ "<leader>u", group = "Preferences" },
		{ "<leader>x", group = "Diagnostics" },
	})
end

function M.setup()
	setup_mini()
	setup_keymaps()
	setup_autocmds()
	setup_which_key()
end

return M
