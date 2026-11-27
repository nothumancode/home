"""Measure ble.sh edit and completion latency in a private tmux terminal."""

import argparse
import os
import shlex
import shutil
import statistics
import subprocess
import tempfile
import time
from pathlib import Path


def benchmark(rcfile, runs, work):
    env = os.environ.copy()
    for key in (
        "BLE_DISABLE",
        "CI",
        "PI_CODING_AGENT",
        "CODEX_SANDBOX",
        "CLAUDECODE",
        "TMUX",
    ):
        env.pop(key, None)
    env.update(
        TERM="xterm-256color", HISTFILE=str(work / "history"), _ZO_DATA_DIR=str(work)
    )
    # One known history suggestion. Keep the user's history out of the samples.
    (work / "history").write_text("echo history-fixture\n")
    (work / "fixture-file").touch()
    wrapper = work / "bashrc"
    wrapper.write_text(
        f"source {shlex.quote(str(rcfile))}\n"
        "[[ -v BLE_VERSION ]] || exit 1\n"
        "PS1='bench> '\n"
    )
    tmux = ["tmux", "-S", str(work / "socket"), "-f", "/dev/null"]

    def call(*args):
        return subprocess.check_output([*tmux, *args], env=env, text=True)

    def send(*keys):
        call("send-keys", "-t", "bench:0.0", *keys)

    def wait_cursor(column):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if call(
                "display-message", "-p", "-t", "bench:0.0", "#{cursor_x}"
            ).strip() == str(column):
                return
            time.sleep(0.005)
        raise RuntimeError(f"cursor never reached column {column}")

    cases = [
        ("command Tab", "hm-swit", "Tab", "hm-switch "),
        ("file Tab", "cat fixture-f", "Tab", "cat fixture-file "),
        ("Git Tab", "git statu", "Tab", "git status "),
        ("typing during suggestion", "hm-swi", "t", "hm-swit"),
    ]
    if shutil.which("cmd.exe"):
        cases.insert(1, ("Windows command Tab", "cmd.ex", "Tab", "cmd.exe "))
    samples = {name: [] for name, *_ in cases}
    try:
        call(
            "new-session",
            "-d",
            "-x",
            "100",
            "-y",
            "24",
            "-s",
            "bench",
            "-c",
            str(work),
            "bash",
            "--noprofile",
            "--rcfile",
            str(wrapper),
            "-i",
        )
        for i in range(runs + 1):
            for name, prefix, key, expected in cases:
                wait_cursor(len("bench> "))
                send("-l", prefix)
                wait_cursor(len("bench> " + prefix))
                time.sleep(0.075)
                start = time.perf_counter()
                send(key)
                wait_cursor(len("bench> " + expected))
                elapsed = (time.perf_counter() - start) * 1000
                if "bench> " + expected.rstrip() not in call(
                    "capture-pane", "-p", "-t", "bench:0.0"
                ):
                    raise RuntimeError(f"{name} produced an unexpected line")
                if i:
                    samples[name].append(elapsed)
                send("C-u")
        for name, values in samples.items():
            print(
                f"{name:25} {statistics.median(values):7.1f} ms median   "
                f"samples: {', '.join(f'{v:.0f}' for v in values)}"
            )
    finally:
        subprocess.run(
            [*tmux, "kill-server"], check=False, env=env, stderr=subprocess.DEVNULL
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bashrc", type=Path)
    parser.add_argument("--runs", type=int, default=7)
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("--runs must be positive")
    with tempfile.TemporaryDirectory() as directory:
        benchmark(args.bashrc.resolve(strict=True), args.runs, Path(directory))
