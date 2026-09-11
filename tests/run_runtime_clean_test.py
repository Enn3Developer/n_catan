"""Exercise both exit paths and reject Godot runtime errors and leak warnings."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
godot = os.environ.get("GODOT_BIN", str(root / "build/godot/Godot_v4.7.2-stable_linux.x86_64"))
for exit_mode in ([], ["--", "--wm-close"]):
    with tempfile.TemporaryDirectory(prefix="catan-runtime-clean-") as folder:
        env = os.environ | {key: str(Path(folder) / name) for key, name in (
            ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"))}
        result = subprocess.run([godot, "--headless", "--path", str(root), "--script",
                                 "tests/runtime_shutdown_test.gd", *exit_mode],
                                env=env, capture_output=True, text=True, timeout=45)
        output = result.stdout + result.stderr
        print(output, end="")
        if result.returncode or "RUNTIME_SHUTDOWN_TEST: exit requested" not in output or re.search(
                r"SCRIPT ERROR|ERROR:|WARNING:|Leaked instance", output):
            raise SystemExit("Runtime did not exit cleanly")
print("RUNTIME_CLEAN_TEST: both exit paths passed without errors or warnings")
