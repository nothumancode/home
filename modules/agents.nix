{ ... }:

{
  # One description of this environment, given to every coding agent as its
  # global context: ~/.claude/CLAUDE.md and ~/.pi/agent/AGENTS.md.
  programs.claude-code.context = ../config/agents/AGENTS.md;
  programs.pi-coding-agent.context = ../config/agents/AGENTS.md;
}
