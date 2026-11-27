# 0001. Reduce interactive Bash completion latency on WSL

Accepted on 2026-11-27.

## Context

On this WSL2 workstation, 37 of the 54 inherited PATH entries pointed into Windows drives. Bash's `compgen -c -- hm-swit` alone took about 400 ms. Running the same lookup with only the Linux portion of this PATH took about 7 ms. The user wants to run Windows programs by name and complete those names with Tab.

## Decision

In interactive ble.sh sessions on WSL, wait 250 ms after typing before starting an automatic suggestion. The pinned default is 1 ms. This gives a following keystroke or Tab a chance to arrive first. History and syntax suggestions still appear after a pause.

For ordinary command-name prefixes, check drive directories under `/mnt/<letter>` with up to eight concurrent directory reads. Pass Bash a function-local PATH containing the Linux entries and every Windows directory with a possible match, in their original order. Bash still decides which entries are executable. Readline case and hyphen/underscore matching are accounted for when selecting directories. A new completion sees newly installed tools. An interrupted scan yields to input through ble.sh's cancellation check.

This approach avoids a persistent Windows executable index and its invalidation rules. Removing Windows directories from the interactive PATH was faster in isolation but would break the required command lookup. Limiting automatic suggestions to history also reduced typing latency, at the cost of inline suggestions for commands and files the user has never entered.

The optimization wraps the pinned ble.sh command-name generator. Explicit paths, empty prefixes, and ambiguous matching use the original generator. Uncertain directory reads retain that directory, and helper failure falls back to the full PATH. The hook uses ble.sh's optional function advice so an upstream rename can disable the optimization. Rerun the benchmark after a ble.sh update.

## Measurements

| Input and measured key | Before | After |
| --- | ---: | ---: |
| `hm-swit` + Tab → `hm-switch` | 617.2 ms | 148.1 ms |
| `cmd.ex` + Tab → `cmd.exe` | 632.6 ms | 216.6 ms |
| `cat fixture-f` + Tab → `cat fixture-file` | 71.7 ms | 79.7 ms |
| `git statu` + Tab → `git status` | 217.4 ms | 221.3 ms |
| `hm-swi` + the next letter `t` | 80.9 ms | 15.3 ms |

Command-name completion saw the largest gains. The file and Git cases took 8 ms and 4 ms longer respectively in this run. Their sample ranges overlapped across configurations.

The benchmark runs interactive Bash with the generated Home Manager bashrc in a private tmux terminal. It sets a short prompt and uses a temporary directory, history and file fixture. After the prefix reaches the cursor, it pauses 75 ms and measures from sending the next key until the cursor reaches the completed position. It also checks the resulting text. The timings include tmux and polling overhead and exclude shell startup.

Both runs used the same WSL2 host, inherited PATH, Bash 5.3.20, ble.sh 0.4.0-devel3 (2026-10-31), and tmux 3.8. Each table entry is the median of nine observations after one warm-up per case.

## Reproduce

Run from the repository root with this Home Manager profile on PATH, Python 3 and tmux. The Windows case runs when `cmd.exe` is on PATH. The commands build just the two bashrc files and exercise each in a fresh terminal.

```bash
base=4cd477308226e5fddc6d9daab0e02b592ce3b8d1
attr='homeConfigurations.rodat.config.home.file.".bashrc".source'
before=$(nix build --no-link --print-out-paths "git+file://$PWD?rev=$base#$attr")
after=$(nix build --no-link --print-out-paths ".#$attr")

python3 benchmarks/bash-completion.py "$before" --runs 9
python3 benchmarks/bash-completion.py "$after" --runs 9
```
