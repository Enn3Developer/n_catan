#!/usr/bin/env python3
"""Cross-compile the standard-library-only updater shipped beside the game."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def build(platform, output):
    target = {'linux-x86_64': 'linux', 'windows-x86_64': 'windows'}[platform]
    output = Path(output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    flags = '-s -w' + (' -H=windowsgui' if target == 'windows' else '')
    env = dict(os.environ, GOOS=target, GOARCH='amd64', CGO_ENABLED='0')
    subprocess.run(['go', 'build', '-trimpath', '-ldflags', flags, '-o', str(output), '.'],
                   cwd=ROOT / 'updater', env=env, check=True)
    output.chmod(0o755)
    return output

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['linux-x86_64', 'windows-x86_64'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.platform, args.output)
