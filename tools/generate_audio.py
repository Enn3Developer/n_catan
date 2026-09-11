"""Original procedural score and sound design. No downloaded samples."""
from pathlib import Path
import numpy as np
import wave
ROOT=Path(__file__).resolve().parents[1]/'assets/audio'
ROOT.mkdir(parents=True,exist_ok=True)
SR=44100
rng=np.random.default_rng(927)
def save(name,data):
    if data.ndim==1: data=np.column_stack((data,data))
    data=np.clip(data,-.95,.95)
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR)
        f.writeframes((data*32767).astype('<i2').tobytes())
def note(midi,length=2,kind='pluck'):
    t=np.arange(int(SR*length))/SR
    hz=440*2**((midi-69)/12)
    if kind=='pad':
        y=(np.sin(2*np.pi*hz*t)+.25*np.sin(2*np.pi*(hz*1.002)*t))
        y*=np.minimum(t/.45,1)*np.minimum((length-t)/.6,1)*.11
    elif kind=='flute':
        y=(np.sin(2*np.pi*hz*t+.016*np.sin(2*np.pi*4*t))+.12*np.sin(4*np.pi*hz*t))
        y*=np.minimum(t/.10,1)*np.minimum((length-t)/.25,1)*.17
    else:
        y=sum(np.sin(2*np.pi*hz*(k+1)*t)*np.exp(-t*(1.6+k*.9))/(k+1)**1.8 for k in range(5))
        y*=np.minimum(t/.005,1)*.28
    y*=np.minimum((length-t)/.04,1)
    return y
beat=60/82
length=beat*4*16
music=np.zeros((int(length*SR),2))
def place(buffer,sound,start,amp=1,pan=0):
    i=int(start*SR); n=min(len(sound),len(buffer)-i)
    if n<=0:return
    buffer[i:i+n,0]+=sound[:n]*amp*(1-pan*.35)
    buffer[i:i+n,1]+=sound[:n]*amp*(1+pan*.35)
chords=[[50,57,62,66],[47,54,59,62],[43,50,55,59],[45,52,57,61]]
melody=[74,78,76,74,71,74,78,76,74,71,69,67,69,73,76,73]
for bar in range(16):
    chord=chords[bar%4]; start=bar*4*beat
    for n in chord: place(music,note(n,4*beat,'pad'),start,.7,(-1 if n%2 else 1)*.4)
    for i in range(8):
        n=chord[[0,2,1,3,2,1,3,2][i]]+12
        place(music,note(n,1.8),start+i*beat/2,.43,np.sin(i)*.7)
    place(music,note(chord[0]-12,2.6),start,.6)
    for i in [0,2]: place(music,note(melody[(bar+i)%16],beat*1.65,'flute'),start+i*beat,.48,0.22)
# Circular stereo echoes retain a seamless looping tail.
music+=np.roll(music,int(beat*.75*SR),axis=0)[:,::-1]*.15
music+=np.roll(music,int(beat*1.5*SR),axis=0)[:,::-1]*.08
music*=.65/max(.65,np.abs(music).max())
fade=int(.05*SR)
music[:fade]*=np.linspace(0,1,fade)[:,None]
music[-fade:]*=np.linspace(1,0,fade)[:,None]
save('harbor',music)
t=np.arange(SR*16)/SR
white=rng.normal(0,1,len(t))
# Smooth spectral rolloff removes the box filter sidelobes that sound like hiss.
freq=np.fft.rfftfreq(len(white),1/SR)
low=np.fft.irfft(np.fft.rfft(white)*np.exp(-(freq/420)**2),n=len(white))
sea=low*(.13+.09*np.sin(2*np.pi*t/8))
sea[:1000]*=np.linspace(0,1,1000);sea[-1000:]*=np.linspace(1,0,1000)
save('sea',sea)
save('click',note(81,.12)*.45)
save('build',note(50,.26)*.8+note(57,.26)*.3)
trade=np.zeros((round(.55*SR),2))
place(trade,note(74,.55),0,.6)
place(trade,note(81,.35),.2,.4)
save('trade',trade)
save('card',note(78,.32)*.45)
save('turn',note(74,.5)*.5+note(81,.5)*.2)
save('error',note(43,.2)*.4)
y=np.zeros(int(SR*.7))
for i in range(8):
    a=int((i*.065)*SR);n=int(.065*SR);tx=np.arange(n)/SR
    hit=(rng.normal(0,1,n)*.2+np.sin(2*np.pi*(160+i*17)*tx)*.25)*np.exp(-tx*75)
    y[a:a+n]+=hit
save('dice',y)
y=np.zeros((int(SR*2.5),2))
for i,n in enumerate([62,66,69,74,78,81]):place(y,note(n,1.3),i*.18,.7)
save('win',y)
print('Generated',len(list(ROOT.glob('*.wav'))),'original stereo audio assets')
