-- Coding agents, Lazygit, Brain, WIT and a shell in a bottom split at the project root.
-- Each command keeps one terminal: its key reopens or focuses it while the job runs.
local M = {}

local terminals = {}

local function root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function running(buf)
	local job = buf and vim.api.nvim_buf_is_valid(buf) and vim.b[buf].terminal_job_id
	return job and vim.fn.jobwait({ job }, 0)[1] == -1
end

function M.open(argv, key)
	key = key or table.concat(argv, " ")
	local buf = terminals[key]
	if running(buf) then
		local win = vim.fn.bufwinid(buf)
		if win == -1 then
			vim.cmd("botright 15split")
			vim.api.nvim_win_set_buf(0, buf)
		else
			vim.api.nvim_set_current_win(win)
		end
		vim.cmd.startinsert()
		return buf
	end
	if vim.fn.executable(argv[1]) ~= 1 then
		vim.notify("Missing executable: " .. argv[1], vim.log.levels.ERROR)
		return
	end
	vim.cmd("botright 15new")
	buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].bufhidden = "hide"
	local job = vim.fn.jobstart(argv, { term = true, cwd = root() })
	if job <= 0 then
		error("Unable to start " .. argv[1])
	end
	terminals[key] = buf
	vim.cmd.startinsert()
	return buf
end

function M.setup()
	vim.api.nvim_create_autocmd("TermOpen", {
		group = vim.api.nvim_create_augroup("HomeTerminal", { clear = true }),
		callback = function()
			vim.opt_local.number = false
			vim.opt_local.relativenumber = false
			vim.opt_local.signcolumn = "no"
		end,
	})

	local agents = { "pi", "codex", "claude" }
	vim.api.nvim_create_user_command("Agent", function(opts)
		if not vim.list_contains(agents, opts.args) then
			error("Choose pi, codex or claude", 0)
		end
		M.open({ opts.args })
	end, {
		nargs = 1,
		complete = function()
			return agents
		end,
		desc = "Open a coding agent at the project root",
	})

	local function map(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { desc = desc })
	end
	map("<leader>ap", "<cmd>Agent pi<cr>", "Pi")
	map("<leader>ac", "<cmd>Agent codex<cr>", "Codex")
	map("<leader>al", "<cmd>Agent claude<cr>", "Claude Code")
	map("<leader>ab", function()
		M.open({ "brain", "tui" })
	end, "Search local agent history (Brain)")
	map("<leader>aw", function()
		vim.ui.input({ prompt = "GitHub repository (owner/name): " }, function(repo)
			if not repo or repo == "" then
				return
			end
			if not repo:match("^[%w_.-]+/[%w_.-]+$") then
				vim.notify("Enter a GitHub repository as owner/name", vim.log.levels.WARN)
				return
			end
			M.open({ "wit", "tree", repo }, "wit")
		end)
	end, "Explore a GitHub repository (WIT)")
	map("<leader>at", function()
		M.open({ vim.o.shell }, "shell")
	end, "Project shell")
	map("<leader>gg", function()
		M.open({ "lazygit" })
	end, "Lazygit")
end

return M
