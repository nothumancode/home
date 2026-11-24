vim.g.mapleader = " "
vim.g.maplocalleader = " "
local opt = vim.opt
opt.termguicolors = true
opt.number = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 5
opt.ignorecase = true
opt.smartcase = true
opt.splitright = true
opt.splitbelow = true
opt.undofile = true
opt.autoread = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.timeoutlen = 350
opt.updatetime = 250

vim.cmd.colorscheme("vercel")
vim.diagnostic.config({
	severity_sort = true,
	underline = true,
	signs = true,
	virtual_text = { source = "if_many", severity = { min = vim.diagnostic.severity.WARN } },
	float = { border = "rounded", source = true },
})

local function map(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, { desc = desc })
end

map("<leader>ut", function()
	vim.o.background = vim.o.background == "dark" and "light" or "dark"
end, "Toggle light/dark theme")

-- Reload unmodified buffers automatically when AI agents or external tools edit files on disk.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermClose" }, {
	group = vim.api.nvim_create_augroup("AutoReloadExternal", { clear = true }),
	callback = function()
		if vim.fn.getcmdwintype() == "" then
			vim.cmd("checktime")
		end
	end,
})

-- Start Treesitter highlighting whenever a parser is installed for the buffer filetype.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true }),
	callback = function(ev)
		pcall(vim.treesitter.start, ev.buf)
	end,
})

local pick = require("mini.pick")
pick.setup()
require("mini.extra").setup()
require("mini.files").setup()
require("mini.diff").setup()
require("mini.statusline").setup({ use_icons = false })
require("mini.pairs").setup()
require("mini.surround").setup()

map("<leader>ff", pick.builtin.files, "Find files")
map("<leader>fg", pick.builtin.grep_live, "Live grep")
map("<leader>fb", pick.builtin.buffers, "Find buffer")
map("<leader>fh", pick.builtin.help, "Find help")
map("<leader>fr", pick.builtin.resume, "Resume last picker")
map("<leader>fd", function()
	MiniExtra.pickers.diagnostic()
end, "Find diagnostics")
map("<leader>e", function()
	MiniFiles.open(vim.api.nvim_buf_get_name(0) ~= "" and vim.api.nvim_buf_get_name(0) or nil)
end, "Explore files")
map("<leader>gd", MiniDiff.toggle_overlay, "Toggle Git diff overlay")

local cmp = require("blink.cmp")
cmp.setup({
	keymap = { preset = "default" }, -- Ctrl-Space: menu/docs; Ctrl-n/p: select; Ctrl-y: accept
	completion = {
		list = { selection = { preselect = false, auto_insert = false } },
		documentation = { auto_show = true, auto_show_delay_ms = 200 },
	},
	signature = { enabled = true },
	sources = {
		default = { "lsp", "path", "snippets", "buffer" },
		per_filetype = { nix = { inherit_defaults = true, "nixpkgs" } },
		providers = {
			lsp = { fallbacks = { "buffer", "nixpkgs" } },
			nixpkgs = { name = "Nixpkgs", module = "nixpkgs_completion", async = true },
		},
	},
})

-- Use Neovim's native LSP client and nvim-lspconfig's root/command defaults.
vim.lsp.config("*", { capabilities = cmp.get_lsp_capabilities() })
-- nvim-lint runs ShellCheck, so bashls should not report the same findings twice.
vim.lsp.config("bashls", { settings = { bashIde = { shellcheckPath = "" } } })
vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			diagnostics = { globals = { "vim" } },
			workspace = { checkThirdParty = false },
		},
	},
})
vim.lsp.enable({
	"bashls",
	"cssls",
	"gopls",
	"html",
	"jsonls",
	"lua_ls",
	"nil_ls",
	"pyright",
	"taplo",
	"ts_ls",
	"yamlls",
})

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local function lmap(lhs, rhs, desc)
			vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
		end
		lmap("gd", vim.lsp.buf.definition, "Go to definition")
		lmap("gr", function()
			MiniExtra.pickers.lsp({ scope = "references" })
		end, "Find references")
		lmap("gI", function()
			MiniExtra.pickers.lsp({ scope = "implementation" })
		end, "Find implementation")
		lmap("gy", function()
			MiniExtra.pickers.lsp({ scope = "type_definition" })
		end, "Go to type definition")
		lmap("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
		lmap("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
		lmap("<leader>ca", vim.lsp.buf.code_action, "Code action")
		lmap("<leader>fs", function()
			MiniExtra.pickers.lsp({ scope = "document_symbol" })
		end, "Find document symbol")
		lmap("<leader>fS", function()
			MiniExtra.pickers.lsp({ scope = "workspace_symbol" })
		end, "Find workspace symbol")
	end,
})

local dev_tools = require("dev_tools") -- generated from modules/dev-tools.nix
local lint = require("lint")
lint.linters_by_ft = dev_tools.linters
-- BufWritePost runs after Conform has formatted and written the buffer.
vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
	group = vim.api.nvim_create_augroup("DevLint", { clear = true }),
	callback = function(ev)
		if vim.bo[ev.buf].buftype == "" then
			local name = vim.api.nvim_buf_get_name(ev.buf)
			vim.api.nvim_buf_call(ev.buf, function()
				lint.try_lint()
				if name:match("/%.github/workflows/.*%.ya?ml$") then
					lint.try_lint("actionlint")
				end
			end)
		end
	end,
})

-- Prefer a dedicated formatter; use the LSP when no formatter is available (e.g. Go).
local conform = require("conform")
conform.setup({
	formatters_by_ft = dev_tools.formatters,
	format_on_save = function()
		if not vim.g.disable_autoformat then
			return { timeout_ms = 1500, lsp_format = "fallback" }
		end
	end,
})
map("<leader>cf", function()
	conform.format({ async = true, lsp_format = "fallback" })
end, "Format buffer")
map("<leader>uf", function()
	vim.g.disable_autoformat = not vim.g.disable_autoformat
	vim.notify("Format on save: " .. (vim.g.disable_autoformat and "off" or "on"))
end, "Toggle format on save")

local wk = require("which-key")
wk.setup({ icons = { mappings = false } })
wk.add({
	{ "<leader>c", group = "Code" },
	{ "<leader>f", group = "Find" },
	{ "<leader>g", group = "Git" },
	{ "<leader>u", group = "Preferences" },
})
