return function()
	local ok, installed = pcall(function()
		return require("nvim-treesitter")
			.install({
				"bash",
				"css",
				"diff",
				"dockerfile",
				"git_config",
				"git_rebase",
				"gitcommit",
				"gitignore",
				"go",
				"gomod",
				"gosum",
				"html",
				"javascript",
				"jsdoc",
				"json",
				"lua",
				"luadoc",
				"make",
				"markdown",
				"markdown_inline",
				"python",
				"query",
				"regex",
				"rust",
				"sql",
				"toml",
				"tsx",
				"typescript",
				"vim",
				"vimdoc",
				"xml",
				"yaml",
			})
			:wait(600000)
	end)
	if not ok or not installed then
		vim.cmd.cquit(1)
	end
end
