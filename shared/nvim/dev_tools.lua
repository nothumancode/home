local formatters = {
	sh = { "shfmt" },
	bash = { "shfmt" },
	python = { "ruff_format" },
	lua = { "stylua" },
	toml = { "taplo" },
}
for _, ft in ipairs({
	"javascript",
	"javascriptreact",
	"typescript",
	"typescriptreact",
	"css",
	"html",
	"json",
	"markdown",
	"yaml",
}) do
	formatters[ft] = { "prettier" }
end
local linters = {
	sh = { "shellcheck" },
	bash = { "shellcheck" },
	python = { "ruff" },
	yaml = { "yamllint" },
	dockerfile = { "hadolint" },
}
if vim.g.home_nix then
	formatters.nix = { "nixfmt" }
	linters.nix = { "statix", "deadnix" }
end
return { formatters = formatters, linters = linters }
