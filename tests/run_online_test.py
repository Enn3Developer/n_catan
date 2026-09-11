"""A real dedicated server and 3–6 independent Godot client processes."""
import os, subprocess, sys, time
from pathlib import Path
player_count=int(sys.argv[1]) if len(sys.argv)>1 else 3
project = Path(__file__).resolve().parents[1]
godot = os.environ.get('GODOT_BIN', '/home/enn3/Downloads/Godot/Godot.x86_64')
env = dict(os.environ, XDG_DATA_HOME='/tmp/catan-online-test')
base = [godot, '--headless', '--path', str(project)]
server = subprocess.Popen(base+['--','--server','--password=test-room'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
clients=[]
try:
    invite = ""
    while not invite:
        line = server.stdout.readline()
        if not line: raise RuntimeError("Server failed before producing secure invite")
        if line.startswith('CATAN_SECURE_INVITE '): invite = line.strip().split(' ', 1)[1]
    for name in ['Ada','Morgan','Robin','Kai','Ash','Sage'][:player_count]:
        clients.append(subprocess.Popen(base+['--script','res://tests/online_client.gd','--',name,str(player_count),invite], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env))
    failed=False
    for client in clients:
        output,_=client.communicate(timeout=30)
        print(output)
        failed |= client.returncode != 0 or 'ONLINE_CLIENT_PASS' not in output or 'SCRIPT ERROR' in output
    if failed: sys.exit(1)
    print(f'DEDICATED_ONLINE_TEST: independent server + {player_count} client processes passed')
finally:
    for proc in clients+[server]:
        if proc.poll() is None: proc.terminate()
        try: proc.wait(timeout=3)
        except subprocess.TimeoutExpired: proc.kill()
