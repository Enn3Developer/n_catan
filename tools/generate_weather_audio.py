"""Create original rain and distant-thunder ambience without external samples."""
from pathlib import Path
import math
import random
import struct
import wave
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 22050

def save(name, samples):
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32767)) for x in samples))

rng = random.Random(4509)
low = 0.0
rain = []
for i in range(RATE * 12):
    noise = rng.uniform(-1, 1)
    low = low * .82 + noise * .18
    rain.append((noise - low) * .12 + low * .22)
# Circular crossfade removes the seam without a quiet interval.
fade = RATE // 4
for i in range(fade):
    w = i / fade
    rain[i] = rain[-fade + i] * (1 - w) + rain[i] * w
save('rain', rain[:-fade])
low = 0.0
thunder = []
for i in range(RATE * 6):
    t = i / RATE
    low = low * .986 + rng.uniform(-1, 1) * .014
    envelope = (1 - math.exp(-t * 18)) * math.exp(-t * .65) * min(1, (6 - t) * 2)
    rumble = low * 2.4 + math.sin(t * 2 * math.pi * 43) * .055 + math.sin(t * 2 * math.pi * 67) * .03
    thunder.append(rumble * envelope)
save('thunder', thunder)
