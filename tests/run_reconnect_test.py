"""Reconnect with fresh processes, including takeover before an old peer times out."""
import os, subprocess, tempfile, time
from pathlib import Path
project = Path(__file__).resolve().parents[1]
godot = os.environ.get('GODOT_BIN', '/home/enn3/Downloads/Godot/Godot.x86_64')
with tempfile.TemporaryDirectory(prefix='catan-reconnect-') as temp:
    folder = Path(temp)
    processes = []
    def start(role, storage):
        log = open(folder / (role + '.log'), 'w')
        env = dict(os.environ, XDG_DATA_HOME=str(folder / storage))
        proc = subprocess.Popen([godot, '--headless', '--path', str(project), '--script', 'res://tests/reconnect_process.gd', '--', role, temp], env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append((proc, log))
        return proc
    def wait(role):
        deadline = time.monotonic() + 15
        while not (folder / role).exists():
            if time.monotonic() > deadline:
                raise RuntimeError('Timed out: ' + role)
            time.sleep(.1)
    try:
        host = start('host', 'server')
        time.sleep(.8)
        first = start('first', 'client'); wait('first')
        second = start('second', 'client'); wait('second')
        second.kill(); second.wait()
        third = start('third', 'client'); wait('third')
        print('RECONNECT_PROCESS_TEST: saved seat restored with live old peer and after abrupt client termination; action and private cards passed')
    finally:
        for proc, log in processes:
            if proc.poll() is None: proc.terminate()
            proc.wait(timeout=3); log.close()
        for log in folder.glob('*.log'):
            print(log.name + ':\n' + log.read_text())
