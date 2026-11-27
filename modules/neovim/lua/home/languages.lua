-- Syntax, language servers, completion, diagnostics, linting and formatting.
-- Servers are on Neovim's PATH (modules/neovim.nix); formatters and linters come from
-- the generated dev_tools module (modules/dev-tools.nix).
local M = {}

-- Python: ty owns types and navigation, Ruff owns lint diagnostics and fixes.
M.servers = {
	"bashls",
	"cssls",
	"gopls",
	"html",
	"jsonls",
	"lua_ls",
	"marksman",
	"nil_ls",
	"ruff",
	"taplo",
	"ts_ls",
	"ty",
	"yamlls",
}

local function map(mode, lhs, rhs, desc, buf)
	vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
end

local function setup_diagnostics()
	local virtual_text = { source = "if_many", spacing = 2, severity = { min = vim.diagnostic.severity.WARN } }
	vim.diagnostic.config({
		severity_sort = true,
		underline = true,
		update_in_insert = false,
		signs = { text = { "E", "W", "I", "H" } },
		virtual_text = virtual_text,
		virtual_lines = false,
		float = { source = true },
	})
	map("n", "<leader>ud", function()
		local lines = not vim.diagnostic.config().virtual_lines
		vim.diagnostic.config({
			virtual_lines = lines and { current_line = true } or false,
			virtual_text = not lines and virtual_text or false,
		})
	end, "Toggle diagnostic lines under cursor")
end

local function setup_treesitter()
	require("treesitter-context").setup({ max_lines = 3, multiline_threshold = 1, trim_scope = "inner" })
	map("n", "<leader>uc", require("treesitter-context").toggle, "Toggle sticky scope context")

	-- Start highlighting and folding when a parser is installed, except for very large files.
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("HomeTreesitter", { clear = true }),
		callback = function(ev)
			if vim.bo[ev.buf].buftype ~= "" then
				return
			end
			local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(ev.buf))
			if stat and stat.size > 1024 * 1024 then
				return
			end
			if pcall(vim.treesitter.start, ev.buf) and vim.api.nvim_get_current_buf() == ev.buf then
				vim.wo[0][0].foldmethod = "expr"
				vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
			end
		end,
	})
end

local function setup_completion()
	local icons = require("mini.icons")
	local cmp = require("blink.cmp")
	-- blink.cmp ignores the mouse, so a click or tap on a menu row would focus the menu window.
	local function accept_tapped()
		local menu = require("blink.cmp.completion.windows.menu").win:get_win()
		local pos = vim.fn.getmousepos()
		return menu ~= nil and pos.winid == menu and pos.line > 0 and cmp.accept({ index = pos.line })
	end
	cmp.setup({
		-- Ctrl-Space: menu/docs; Ctrl-n/p or Up/Down: select; Enter, Tab, Ctrl-y or a tap: accept
		-- the highlighted item (the first one until another is selected).
		keymap = {
			preset = "default",
			["<CR>"] = { "select_and_accept", "fallback" },
			["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
			["<LeftMouse>"] = { accept_tapped, "fallback" },
		},
		completion = {
			list = { selection = { preselect = true, auto_insert = false } },
			documentation = { auto_show = true, auto_show_delay_ms = 200 },
			menu = {
				draw = {
					columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
					components = {
						kind_icon = {
							text = function(ctx)
								return icons.get("lsp", ctx.kind) .. ctx.icon_gap
							end,
							highlight = function(ctx)
								return select(2, icons.get("lsp", ctx.kind))
							end,
						},
					},
				},
			},
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
	return cmp
end

local function setup_servers(cmp)
	-- nvim-lspconfig supplies each server's command, filetypes and root markers.
	vim.lsp.config("*", { capabilities = cmp.get_lsp_capabilities() })
	-- nvim-lint runs ShellCheck, so bashls should not report the same findings twice.
	vim.lsp.config("bashls", { settings = { bashIde = { shellcheckPath = "" } } })
	vim.lsp.config("gopls", {
		settings = {
			gopls = {
				hints = { parameterNames = true, assignVariableTypes = true, compositeLiteralFields = true },
				staticcheck = true,
			},
		},
	})
	local schemastore = require("schemastore")
	vim.lsp.config("jsonls", {
		settings = { json = { schemas = schemastore.json.schemas(), validate = { enable = true } } },
	})
	vim.lsp.config("yamlls", {
		settings = { yaml = { schemaStore = { enable = false, url = "" }, schemas = schemastore.yaml.schemas() } },
	})
	-- Neovim's runtime types for any Lua workspace without its own .luarc.json.
	vim.lsp.config("lua_ls", {
		settings = { Lua = { workspace = { checkThirdParty = false } } },
		on_init = function(client)
			local folder = client.workspace_folders and client.workspace_folders[1]
			if
				folder
				and (vim.uv.fs_stat(folder.name .. "/.luarc.json") or vim.uv.fs_stat(folder.name .. "/.luarc.jsonc"))
			then
				return
			end
			client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
				runtime = { version = "LuaJIT", path = { "lua/?.lua", "lua/?/init.lua" } },
				workspace = { library = { vim.env.VIMRUNTIME, "${3rd}/luv/library" } },
			})
		end,
	})
	vim.lsp.enable(M.servers)

	local group = vim.api.nvim_create_augroup("HomeLsp", { clear = true })
	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(ev)
			local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
			local buf = ev.buf
			if client.name == "ruff" then
				client.server_capabilities.hoverProvider = false -- ty answers K
			end
			local pickers = require("mini.extra").pickers
			local function lsp(scope)
				return function()
					pickers.lsp({ scope = scope })
				end
			end
			-- Neovim's defaults stay: K hover, grn rename, gra code action, gO symbols, Ctrl-S signature.
			map("n", "gd", vim.lsp.buf.definition, "Go to definition", buf)
			map("n", "gD", vim.lsp.buf.declaration, "Go to declaration", buf)
			map("n", "grr", lsp("references"), "Find references", buf)
			map("n", "gri", lsp("implementation"), "Find implementation", buf)
			map("n", "gI", lsp("implementation"), "Find implementation", buf)
			map("n", "gy", lsp("type_definition"), "Go to type definition", buf)
			map("n", "<leader>cd", vim.diagnostic.open_float, "Line diagnostics", buf)
			map("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol", buf)
			map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action", buf)
			map("n", "<leader>co", function()
				vim.lsp.buf.code_action({
					context = { only = { "source.organizeImports" }, diagnostics = {} },
					apply = true,
				})
			end, "Organize imports", buf)
			map("n", "<leader>cl", "<cmd>checkhealth vim.lsp<cr>", "Language server status", buf)
			map("n", "<leader>fs", lsp("document_symbol"), "Find document symbol", buf)
			map("n", "<leader>fS", lsp("workspace_symbol"), "Find workspace symbol", buf)
			if client:supports_method("textDocument/inlayHint", buf) then
				map("n", "<leader>uh", function()
					vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
				end, "Toggle inlay hints", buf)
			end
			-- Highlight other uses of the symbol under the cursor after a pause.
			if client:supports_method("textDocument/documentHighlight", buf) then
				local hl = vim.api.nvim_create_augroup("HomeLspHighlight" .. buf, { clear = true })
				vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
					group = hl,
					buffer = buf,
					callback = vim.lsp.buf.document_highlight,
				})
				vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
					group = hl,
					buffer = buf,
					callback = vim.lsp.buf.clear_references,
				})
			end
		end,
	})
	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(ev)
			if #vim.lsp.get_clients({ bufnr = ev.buf, method = "textDocument/documentHighlight" }) <= 1 then
				pcall(vim.api.nvim_del_augroup_by_name, "HomeLspHighlight" .. ev.buf)
				vim.lsp.buf.clear_references()
			end
		end,
	})
end

local function setup_lint(dev_tools)
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
end

local function setup_format(dev_tools)
	-- Prefer a dedicated formatter; use the LSP when no formatter is available (e.g. Go).
	local conform = require("conform")
	conform.setup({
		formatters_by_ft = dev_tools.formatters,
		format_on_save = function(buf)
			if not vim.g.disable_autoformat and not vim.b[buf].disable_autoformat then
				return { timeout_ms = 1500, lsp_format = "fallback" }
			end
		end,
	})
	map({ "n", "x" }, "<leader>cf", function()
		conform.format({ async = true, lsp_format = "fallback" })
	end, "Format buffer or selection")
	map("n", "<leader>uf", function()
		vim.b.disable_autoformat = not vim.b.disable_autoformat
		vim.notify("Format on save for this buffer: " .. (vim.b.disable_autoformat and "off" or "on"))
	end, "Toggle format on save (buffer)")
	map("n", "<leader>uF", function()
		vim.g.disable_autoformat = not vim.g.disable_autoformat
		vim.notify("Format on save: " .. (vim.g.disable_autoformat and "off" or "on"))
	end, "Toggle format on save (all buffers)")
end

function M.setup()
	setup_diagnostics()
	setup_treesitter()
	setup_servers(setup_completion())
	local dev_tools = require("dev_tools") -- generated from modules/dev-tools.nix
	setup_lint(dev_tools)
	setup_format(dev_tools)
end

return M
