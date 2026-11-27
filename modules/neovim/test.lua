-- Headless check of the Neovim configuration, run by checks.neovim in flake.nix inside an
-- empty Git project ($NVIM_TEST_PROJECT). It exercises the features the config promises.
local join = vim.fs.joinpath
local cwd = assert(vim.uv.fs_realpath(vim.env.NVIM_TEST_PROJECT))
local function write(name, lines)
	assert(vim.fn.writefile(lines, join(cwd, name)) == 0)
end
local function open(name)
	vim.cmd.edit(vim.fn.fnameescape(join(cwd, name)))
	return vim.api.nvim_get_current_buf()
end
local function wait(label, test, ms)
	assert(vim.wait(ms or 30000, test, 50), "Timed out waiting for " .. label)
end

-- Startup and theme
assert(vim.v.errmsg == "", "Startup error: " .. vim.v.errmsg)
local messages = vim.api.nvim_exec2("messages", { output = true }).output
assert(not messages:find("E%d+:") and not messages:find("rror"), "Startup messages: " .. messages)
local function normal_bg()
	return vim.api.nvim_get_hl(0, { name = "Normal" }).bg
end
assert(vim.g.colors_name == "vercel" and vim.o.background == "dark" and normal_bg() == 0x0a0a0a)
vim.cmd.Theme("light")
assert(vim.g.colors_name == "vercel" and normal_bg() == 0xffffff, "Light theme not applied")

-- Keymaps from each module
for lhs, desc in pairs({
	["<Space>ff"] = "Find files",
	["<Space>fg"] = "Live grep",
	["<Space>e"] = "Explore files (current file)",
	["<Space>gg"] = "Lazygit",
	["<Space>al"] = "Claude Code",
	["<Space>ut"] = "Toggle light/dark theme",
	["<Space>uf"] = "Toggle format on save (buffer)",
	["<Space>xx"] = "Workspace diagnostics",
}) do
	local found = vim.fn.maparg(lhs, "n", false, true).desc
	assert(found == desc, lhs .. " is " .. vim.inspect(found))
end

-- Parsers and text-object queries
for _, lang in ipairs({ "bash", "go", "json", "lua", "markdown", "nix", "python", "toml", "tsx", "yaml" }) do
	assert(vim.treesitter.language.add(lang), "Missing parser: " .. lang)
end
assert(#vim.treesitter.query.get_files("python", "textobjects") > 0, "Missing text-object queries")

-- Directory buffers open in mini.files
vim.cmd.edit(vim.fn.fnameescape(cwd))
wait("mini.files explorer", function()
	return require("mini.files").get_explorer_state() ~= nil
end, 5000)
require("mini.files").close()

-- Lua: highlighting, folding and format on save
write("sample.lua", { "local value={1,2}", "return value" })
local lua = open("sample.lua")
assert(vim.treesitter.highlighter.active[lua], "Tree-sitter highlighting did not start")
assert(vim.wo.foldmethod == "expr", "Tree-sitter folding not enabled")
vim.cmd.write()
assert(vim.api.nvim_buf_get_lines(lua, 0, 1, false)[1] == "local value = { 1, 2 }", "Format on save did not run")

-- Python: cross-file navigation through ty, and one diagnostic per problem from ty and Ruff
write("pyproject.toml", { "[project]", 'name = "nvim-test"', 'version = "0.1.0"' })
write("helper.py", { "def greeting() -> str:", '    return "hello"' })
write("use.py", { "from helper import greeting", "", "print(greeting())" })
write("bad.py", { "import os", "", 'number: int = "wrong"' })
local use = open("use.py")
local ty
wait("ty", function()
	ty = vim.lsp.get_clients({ name = "ty", bufnr = use })[1]
	return ty and ty.initialized
end)
local response = assert(ty:request_sync("textDocument/definition", {
	textDocument = { uri = vim.uri_from_bufnr(use) },
	position = { line = 2, character = 8 },
}, 10000, use))
local locations = assert(response.result, vim.inspect(response.err))
local location = locations[1] or locations
local uri = assert(location.targetUri or location.uri, "ty returned no definition")
assert(vim.uv.fs_realpath(vim.uri_to_fname(uri)) == join(cwd, "helper.py"), "Definition went to " .. uri)

local bad = open("bad.py")
local function count(code)
	return #vim.tbl_filter(function(d)
		return d.code == code
	end, vim.diagnostic.get(bad))
end
wait("ty and Ruff diagnostics", function()
	return count("invalid-assignment") >= 1 and count("F401") >= 1
end)
vim.wait(1500) -- a duplicate producer would report by now
assert(count("invalid-assignment") == 1 and count("F401") == 1, vim.inspect(vim.diagnostic.get(bad)))
vim.api.nvim_buf_set_lines(bad, 0, -1, false, { "number: int = 1" })
vim.cmd.write()
wait("cleared diagnostics", function()
	return count("invalid-assignment") == 0 and count("F401") == 0
end)

-- Completion: Enter and Tab accept the highlighted (first) item, a tap accepts the tapped one.
-- It runs in a child Neovim with a terminal UI: without a UI, clicks never reach floating windows.
local sock = vim.fn.tempname()
local child = vim.fn.jobstart({ vim.v.progpath, "--listen", sock }, { pty = true, width = 80, height = 24 })
wait("child Neovim socket", function()
	return vim.uv.fs_stat(sock) ~= nil
end, 10000)
local rpc = vim.fn.sockconnect("pipe", sock, { rpc = true })
local function remote(code, ...)
	return vim.rpcrequest(rpc, "nvim_exec_lua", code, { ... })
end
wait("child Neovim startup", function()
	return remote("return vim.v.vim_did_enter") == 1
end)
local function menu_open()
	return remote("return require('blink.cmp').is_menu_visible()")
end
remote("vim.cmd.enew() vim.api.nvim_buf_set_lines(0, 0, -1, false, { '', 'alphabet alpaca alpine' })")
local function complete(accept)
	remote("vim.api.nvim_buf_set_lines(0, 0, 1, false, { '' }) vim.api.nvim_win_set_cursor(0, { 1, 0 })")
	vim.rpcrequest(rpc, "nvim_input", "<Esc>ialp")
	wait("completion menu", menu_open, 10000)
	local labels = remote("return vim.tbl_map(function(i) return i.label end, require('blink.cmp').get_items())")
	local expected = labels[accept()]
	wait("accepted completion", function()
		return not menu_open()
	end, 5000)
	local line = remote("return vim.api.nvim_get_current_line()")
	assert(line == expected, "Completed " .. vim.inspect(line) .. ", expected " .. vim.inspect(expected))
	assert(vim.rpcrequest(rpc, "nvim_get_mode").mode == "i", "Accepting left insert mode")
end
for _, key in ipairs({ "<CR>", "<Tab>" }) do
	complete(function()
		vim.rpcrequest(rpc, "nvim_input", key)
		return 1
	end)
end
complete(function()
	local pos = remote([[
		local win = require('blink.cmp.completion.windows.menu').win:get_win()
		return vim.fn.screenpos(win, 2, 1)
	]])
	for _, action in ipairs({ "press", "release" }) do
		vim.rpcrequest(rpc, "nvim_input_mouse", "left", action, "", 0, pos.row - 1, pos.col)
	end
	return 2
end)
-- Without a menu, Enter still breaks the line.
vim.rpcrequest(rpc, "nvim_input", "<CR>")
wait("newline", function()
	return remote("return vim.api.nvim_buf_line_count(0)") == 3
end, 5000)
vim.fn.jobstop(child)

-- Terminals: one per command, reopened while the job runs
local terminals = require("home.terminals")
local term = terminals.open({ vim.o.shell, "-c", "sleep 30" }, "test")
assert(term and vim.bo[term].buftype == "terminal", "Terminal did not open")
vim.cmd.stopinsert()
vim.cmd.close()
assert(terminals.open({ vim.o.shell, "-c", "sleep 30" }, "test") == term, "Terminal was not reused")
vim.fn.jobstop(vim.b[term].terminal_job_id)

-- :checkhealth home runs to completion
vim.cmd("checkhealth home")
local report = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(report:find("Language servers") and not report:find("Failed to run healthcheck"), report)

print(
	"Theme, keymaps, parsers, explorer, formatting, ty/Ruff navigation and diagnostics, completion, terminals and health passed."
)
