local github = "https://github.com/"
vim.pack.add({
	{ src = github .. "Saghen/blink.cmp", version = "v1.10.2" },
	{ src = github .. "rafamadriz/friendly-snippets", version = "7a1c9f7897a4eb078b157a04c7af81e5869215b1" },
	{ src = github .. "nvim-mini/mini.nvim", version = "v0.18.0" },
	{ src = github .. "neovim/nvim-lspconfig", version = "v2.12.0" },
	{ src = github .. "stevearc/conform.nvim", version = "016802de402556da54c36bd7359b441266b01cdd" },
	{ src = "https://codeberg.org/mfussenegger/nvim-lint", version = "52107ce2076a27a285af781248e2c59bad817cd0" },
	{ src = github .. "folke/which-key.nvim", version = "3aab2147e74890957785941f0c1ad87d0a44c15a" },
	{ src = github .. "nvim-treesitter/nvim-treesitter", version = "37e52c733ada9d8d544d53a763140ef1ba404353" },
}, { confirm = false })

local function npm_file(tool, relative)
	local result = vim.system({ "mise", "where", "npm:" .. tool }, { text = true }):wait()
	if result.code == 0 then
		return vim.fs.joinpath(vim.trim(result.stdout), "node_modules", tool, relative)
	end
end
vim.g.node_host_prog = npm_file("neovim", "bin/cli.js")
vim.lsp.config("ts_ls", {
	init_options = { tsserver = { fallbackPath = npm_file("typescript", "lib/tsserver.js") } },
})
require("home")
