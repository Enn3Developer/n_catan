"""Compose four original instrumental tracks using synthesis; no external samples.

Requires numpy and ffmpeg (libvorbis). Existing harbor music and effects are kept.
The exact PCM frame counts also define the network playlist timeline.
"""
from functools import lru_cache
from pathlib import Path
import json
import subprocess
import tempfile
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SR = 44100
PI = np.pi
TRACKS = [
    dict(id='sunlit_fields', title='Sunlit Fields', mood='Bright harp, flute and warm strings', bpm=92, beats=4, bars=32,
         chords=[[43,50,55,59],[38,45,50,54],[40,47,52,55],[36,43,48,52],[43,50,55,59],[45,52,57,60],[38,45,50,54],[43,50,55,59]],
         melody=[74,71,67,69,71,74,76,74,71,69,67,66,67,71,69,67], instrument='flute', pluck='harp'),
    dict(id='trade_winds', title='Trade Winds', mood='Nylon strings, marimba and gentle percussion', bpm=84, beats=4, bars=32,
         chords=[[38,45,50,53],[41,48,53,57],[36,43,48,52],[43,50,55,59],[38,45,50,53],[46,53,58,62],[45,52,57,60],[38,45,50,53]],
         melody=[69,72,74,77,76,74,72,69,67,69,72,74,72,69,65,62], instrument='marimba', pluck='guitar'),
    dict(id='lantern_water', title='Lanterns on the Water', mood='Soft piano, glass bells and evening strings', bpm=64, beats=4, bars=24,
         chords=[[39,46,51,55],[36,43,48,51],[44,51,56,60],[46,53,58,62],[43,50,55,58],[44,51,56,60],[46,53,58,62],[39,46,51,55]],
         melody=[79,77,74,75,72,74,75,79,77,75,74,70,72,74,75,70], instrument='bell', pluck='piano'),
    dict(id='voyager_waltz', title="Voyager's Waltz", mood='Pizzicato strings, woodwinds and a lilting waltz', bpm=86, beats=3, bars=32,
         chords=[[41,48,53,57],[45,52,57,60],[46,53,58,62],[48,55,60,64],[41,48,53,57],[38,45,50,53],[43,50,55,58],[48,55,60,64]],
         melody=[77,76,72,74,77,79,81,79,77,74,72,69,70,72,74,77], instrument='flute', pluck='pizzicato'),
]

@lru_cache(maxsize=1024)
def tone(midi, duration, instrument):
    t = np.arange(round(SR * duration), dtype=np.float64) / SR
    hz = 440 * 2 ** ((midi - 69) / 12)
    phase = 2 * PI * hz * t
    if instrument == 'strings':
        y = sum(np.sin(phase * k + .08 * np.sin(2*PI*(4.2+k*.13)*t)) / k**2 for k in range(1,5))
        y += .3*np.sin(phase * 1.002)
        y *= np.minimum(t/.5, 1) * np.minimum((duration-t)/.7, 1)
    elif instrument == 'flute':
        vibrato = .022 * np.sin(2*PI*4.7*t) * np.minimum(t/.4,1)
        y = np.sin(phase+vibrato) + .18*np.sin(2*phase) + .045*np.sin(3*phase)
        y *= np.minimum(t/.08,1) * np.minimum((duration-t)/.2,1) * np.exp(-t*.12)
    elif instrument == 'bell':
        y = np.sin(phase)*np.exp(-t*1.4) + .2*np.sin(phase*2.76)*np.exp(-t*3.5) + .07*np.sin(phase*4.01)*np.exp(-t*5)
        y *= np.minimum(t/.005,1)
    elif instrument == 'marimba':
        y = np.sin(phase)*np.exp(-t*3) + .22*np.sin(phase*4)*np.exp(-t*9)
        y *= np.minimum(t/.004,1)
    else:
        decay = {'harp':1.7, 'piano':1.1, 'guitar':2.0, 'pizzicato':3.4}.get(instrument,1.5)
        y = sum(np.sin(phase*k + .015*k)*np.exp(-t*(decay+k*.7))/k**1.7 for k in range(1,7))
        y *= np.minimum(t/.006,1)
    y *= np.clip((duration-t)/.035,0,1)
    return y.astype(np.float32)

def place(buffer, sound, start, gain, pan):
    first = round(start*SR)
    n = min(len(sound), len(buffer)-first)
    if n <= 0: return
    buffer[first:first+n,0] += sound[:n] * gain * np.sqrt((1-pan)/2)
    buffer[first:first+n,1] += sound[:n] * gain * np.sqrt((1+pan)/2)

def compose(spec, seed):
    rng = np.random.default_rng(seed)
    beat = 60/spec['bpm']
    duration = spec['bars']*spec['beats']*beat + 3.0
    data = np.zeros((round(duration*SR),2),dtype=np.float32)
    for bar in range(spec['bars']):
        chord = spec['chords'][bar%len(spec['chords'])]
        start = bar*spec['beats']*beat
        # Four phrases: opening, melodic answer, a lighter bridge, and return.
        phrase = bar//8
        dynamic = [.75,1,.62,.9][min(phrase,3)]
        ending = bar >= spec['bars']-2
        for j,note in enumerate(chord):
            place(data,tone(note,round(spec['beats']*beat+.8,3),'strings'),start,.045*dynamic,(j-1.5)*.32)
        place(data,tone(chord[0]-12,round(2.3*beat,3),'piano'),start,.17*dynamic,-.12)
        order = [0,2,1,3,2,1,3,2]
        for sub in range(spec['beats']*2):
            if phrase==2 and sub%2: continue
            note = chord[order[sub]]+12
            place(data,tone(note,round(2.1*beat,3),spec['pluck']),start+sub*beat/2,.12*dynamic*rng.uniform(.88,1.1),.45*np.sin(sub*1.3))
        if bar%8>=2 or phrase==1:
            for step in range(2 if spec['beats']==4 else 1):
                note = spec['melody'][(bar*2+step)%len(spec['melody'])]
                if phrase==2: note-=12
                place(data,tone(note,round(1.6*beat,3),spec['instrument']),start+step*2*beat,.15*dynamic,.18)
        if spec['id']=='lantern_water' and bar%4==0:
            place(data,tone(chord[3]+24,3,'bell'),start+.12,.055,-.5)
        if spec['id']=='trade_winds' and bar%8>=2 and not ending:
            for sub in range(8):
                tx=np.arange(round(SR*.075))/SR
                noise=rng.normal(0,1,len(tx)).astype(np.float32)
                noise=np.concatenate(([0],np.diff(noise)))
                noise*=np.exp(-tx*65)*np.minimum(tx/.004,1)
                place(data,noise,start+sub*beat/2,.013 if sub%2 else .008,(-1 if sub%2 else 1)*.65)
        if spec['beats']==3:
            for step in [1,2]:
                for note in chord[1:]:
                    place(data,tone(note,round(.75*beat,3),'pizzicato'),start+step*beat,.055*dynamic,-.25)
    # Short stereo room reflections: no discontinuity at the end of a track.
    dry=data.copy()
    for seconds,gain in [(.073,.12),(.121,.085),(.197,.055),(.311,.035)]:
        delay=round(seconds*SR)
        data[delay:]+=dry[:-delay,::-1]*gain
    fade_in=round(.45*SR);fade_out=round(2.5*SR)
    data[:fade_in]*=np.linspace(0,1,fade_in)[:,None]
    data[-fade_out:]*=np.linspace(1,0,fade_out)[:,None]
    rms=np.sqrt(np.mean(data**2))
    data*=min(.105/max(rms,1e-6),.79/max(np.max(np.abs(data)),1e-6))
    return data

def main():
    audio=ROOT/'assets/audio';audio.mkdir(exist_ok=True)
    reports=[]
    for index,spec in enumerate(TRACKS):
        pcm=compose(spec,2091+index)
        with tempfile.TemporaryDirectory(prefix='catan-score-') as temp:
            source=Path(temp)/'score.wav'
            with wave.open(str(source),'wb') as f:
                f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR)
                f.writeframes((pcm*32767).astype('<i2').tobytes())
            dest=audio/(spec['id']+'.ogg')
            subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(source),'-c:a','libvorbis','-q:a','6','-metadata','title='+spec['title'],'-metadata','artist=CATAN · Tides & Timber',str(dest)],check=True)
        reports.append(dict(id=spec['id'],title=spec['title'],mood=spec['mood'],duration=len(pcm)/SR,bytes=dest.stat().st_size,peak=float(np.abs(pcm).max()),rms=float(np.sqrt(np.mean(pcm**2)))))
        print(json.dumps(reports[-1]),flush=True)
        tone.cache_clear()
    (ROOT/'docs/soundtrack-generation.json').write_text(json.dumps(reports,indent=2)+'\n')
if __name__=='__main__':main()
