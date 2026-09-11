"""Three independent processes follow the shared music clock and audio position."""
import os, subprocess, tempfile, time
from pathlib import Path
project=Path(__file__).resolve().parents[1]
godot=os.environ.get('GODOT_BIN','/home/enn3/Downloads/Godot/Godot.x86_64')
with tempfile.TemporaryDirectory(prefix='catan-music-process-') as temp:
    processes=[]
    try:
        for role in ['host','Ada','Bo']:
            env=dict(os.environ,XDG_DATA_HOME=str(Path(temp)/role))
            proc=subprocess.Popen([godot,'--headless','--path',str(project),'--script','res://tests/music_process.gd','--',role,temp],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            processes.append(proc)
            if role == 'host':
                deadline = time.monotonic() + 10
                while not (Path(temp) / 'invite').exists():
                    if time.monotonic() > deadline: raise RuntimeError('No host invite')
                    time.sleep(.05)
            else: time.sleep(.3)
        failed=False
        for proc in processes:
            output,_=proc.communicate(timeout=20)
            print(output)
            failed |= proc.returncode != 0 or 'result=PASS' not in output or 'SCRIPT ERROR' in output
        if failed:raise SystemExit(1)
        print('MUSIC_PROCESS_TEST: host and two clients passed track changes, shared pause and audio drift checks')
    finally:
        for proc in processes:
            if proc.poll() is None:proc.terminate()
            proc.wait(timeout=3)
