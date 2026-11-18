vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.termguicolors = true
vim.cmd.colorscheme("vercel-dark")
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 4
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = -1
vim.opt.winborder = "single"
vim.opt.completeopt = { "menu", "menuone", "noselect", "popup" }
vim.opt.laststatus = 3

local group = vim.api.nvim_create_augroup("Engineering", { clear = true })
local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc })
end

-- Use parsers already on runtimepath. No :TSInstall, compiler or network on startup.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= "" then return end
    local lang = vim.treesitter.language.get_lang(ev.match)
    if lang and vim.treesitter.language.add(lang) then
      vim.treesitter.start(ev.buf, lang)
    end
  end,
})

require("mini.icons").setup({ style = "ascii" })
require("mini.statusline").setup({ use_icons = false })
require("mini.files").setup()
require("mini.pick").setup()
require("mini.extra").setup()
require("mini.diff").setup({ view = { style = "sign", signs = { add = "+", change = "~", delete = "-" } } })

map("<leader>e", function() MiniFiles.open() end, "Explore files")
map("<leader>ff", "<Cmd>Pick files<CR>", "Find files")
map("<leader>fg", "<Cmd>Pick grep_live<CR>", "Grep working directory")
map("<leader>fb", "<Cmd>Pick buffers<CR>", "Find buffers")
map("<leader>fd", "<Cmd>Pick diagnostic<CR>", "Find diagnostics")
map("<leader>?", "<Cmd>Pick keymaps<CR>", "Find keymaps")
map("<leader>gh", function() MiniDiff.toggle_overlay() end, "Preview Git hunks")
map("<leader>cd", vim.diagnostic.open_float, "Show diagnostic details")

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, source = "if_many" },
  float = { source = true },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false -- ty supplies Python hover.
    end
    if client:supports_method("textDocument/definition", ev.buf) then
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf, desc = "Go to definition" })
    end
    if client:supports_method("textDocument/completion", ev.buf) then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})

vim.lsp.enable({ "nixd", "bashls", "lua_ls", "ty", "ruff", "tsc", "gopls", "jsonls", "yamlls", "html", "cssls" })

local conform = require("conform")
local formatters = {
  nix = { "nixfmt" },
  lua = { "stylua" },
  sh = { "shfmt" },
  bash = { "shfmt" },
  python = { "ruff_format" },
  go = { "gofmt" },
}
for _, ft in ipairs({
  "javascript", "javascriptreact", "typescript", "typescriptreact",
  "json", "jsonc", "html", "css", "yaml", "markdown",
}) do
  formatters[ft] = { "prettier" }
end
conform.setup({
  formatters_by_ft = formatters,
  default_format_opts = { lsp_format = "fallback", timeout_ms = 2000 },
  format_on_save = function(buf)
    if vim.b[buf].autoformat then return {} end
  end,
})
map("<leader>cf", function() conform.format() end, "Format buffer")
map("<leader>uf", function()
  vim.b.autoformat = not vim.b.autoformat
  vim.notify("Format on save: " .. (vim.b.autoformat and "on" or "off") .. " (this buffer)")
end, "Toggle format on save for this buffer")
