-- :checkhealth home reports every executable this configuration starts.
local M = {}

local function report(cmd, hint)
	local path = vim.fn.exepath(cmd)
	if path == "" then
		vim.health.warn(cmd .. " is not on Neovim's PATH", hint)
	else
		vim.health.ok(cmd .. "  " .. path)
	end
end

function M.check()
	vim.health.start("Configuration")
	vim.health.info("Config: " .. vim.fn.resolve(vim.fn.stdpath("config")))
	vim.health.info("Theme: " .. (vim.g.colors_name or "none") .. " " .. vim.o.background .. " (:Theme to switch)")

	vim.health.start("Language servers")
	for _, name in ipairs(require("home.languages").servers) do
		local cmd = vim.lsp.config[name] and vim.lsp.config[name].cmd
		if type(cmd) == "table" then
			report(cmd[1], { "Add its package to programs.neovim.extraPackages in modules/neovim.nix." })
		else
			vim.health.info(name .. " starts through a function; see :checkhealth vim.lsp")
		end
	end

	vim.health.start("Formatters and linters")
	local dev_tools = require("dev_tools")
	local conform = require("conform")
	local seen = {}
	for _, names in pairs(dev_tools.formatters) do
		for _, name in ipairs(names) do
			if not seen[name] then
				seen[name] = true
				local info = conform.get_formatter_info(name)
				if info.available then
					vim.health.ok(name .. "  " .. (info.command or ""))
				else
					vim.health.warn(name .. ": " .. (info.available_msg or "unavailable"))
				end
			end
		end
	end
	local lint = require("lint")
	for _, names in pairs(dev_tools.linters) do
		for _, name in ipairs(names) do
			if not seen[name] then
				seen[name] = true
				local linter = lint.linters[name]
				local cmd = type(linter) == "function" and linter().cmd or linter and linter.cmd
				report(type(cmd) == "function" and cmd() or cmd or name)
			end
		end
	end

	vim.health.start("Tools and agents")
	for _, cmd in ipairs({ "git", "rg", "fd", "nix", "lazygit", "pi", "codex", "claude", "brain", "wit" }) do
		report(cmd, { "Installed by Home Manager; open Neovim from a shell with the profile on PATH." })
	end
end

return M
