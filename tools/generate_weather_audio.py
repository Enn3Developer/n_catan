"""Create original rain and thunder ambience without external samples.

Run: python3 tools/generate_weather_audio.py
Writes assets/audio/rain.wav (a stereo loop) and thunder_0.wav to
thunder_2.wav, from a near crack to a far rumble.
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 22050


def save(name, left, right=None):
    channels = 1 if right is None else 2
    peak = max(max(abs(x) for x in left), max(abs(x) for x in right) if right else 0)
    scale = .8 / peak
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        frames = []
        for i in range(len(left)):
            frames.append(struct.pack('<h', int(left[i] * scale * 32767)))
            if right:
                frames.append(struct.pack('<h', int(right[i] * scale * 32767)))
        wav.writeframes(b''.join(frames))


def one_pole(samples, cutoff):
    """A gentle low-pass; subtract its output from the input for a high-pass."""
    k = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += (x - y) * k
        out.append(y)
    return out


def band(samples, low, high):
    lowpassed = one_pole(one_pole(samples, high), high)
    floor = one_pole(lowpassed, low)
    return [a - b for a, b in zip(lowpassed, floor)]


rng = random.Random(4509)

# ---------------------------------------------------------------- rain
# A soft hiss band for the bed, and many separate drops on top. The old loop
# was bright white noise; this one sits between 300 Hz and 3.5 kHz.
SECONDS = 16
count = RATE * SECONDS
fade = RATE // 2


def rain_channel(shared):
    own = [rng.uniform(-1, 1) for _ in range(count + fade)]
    mix = [a * .55 + b * .45 for a, b in zip(shared, own)]
    bed = band(mix, 300, 3500)
    # Slow gusts swell the bed by a few decibels.
    phase = rng.uniform(0, math.tau)
    bed = [x * (.8 + .2 * math.sin(i / RATE * .7 + phase) * math.sin(i / RATE * .23)) for i, x in enumerate(bed)]
    drops = [0.0] * (count + fade)
    t = 0.0
    while t < SECONDS + fade / RATE:
        t += rng.expovariate(90)
        start = int(t * RATE)
        heavy = rng.random() < .12
        freq = rng.uniform(450, 1100) if heavy else rng.uniform(1800, 5200)
        decay = rng.uniform(.012, .03) if heavy else rng.uniform(.002, .006)
        level = rng.expovariate(1) * (.5 if heavy else .22)
        for j in range(int(decay * 6 * RATE)):
            if start + j >= len(drops):
                break
            s = j / RATE
            drops[start + j] += math.sin(math.tau * freq * s * (1 - s * 8)) * math.exp(-s / decay) * level
    drops = band(drops, 250, 6000)
    return [b * .9 + d for b, d in zip(bed, drops)]


shared = [rng.uniform(-1, 1) for _ in range(count + fade)]
channels = []
for _ in range(2):
    channel = rain_channel(shared)
    # Circular crossfade removes the seam without a quiet interval.
    for i in range(fade):
        w = i / fade
        channel[i] = channel[count + i] * (1 - w) + channel[i] * w
    channels.append(channel[:count])
save('rain', channels[0], channels[1])

# ---------------------------------------------------------------- thunder


def thunder(seconds, crack, rumble_cutoff, swells, seed):
    local = random.Random(seed)
    n = int(RATE * seconds)
    brown, y = [], 0.0
    for _ in range(n):
        y = y * .995 + local.uniform(-1, 1) * .06
        brown.append(y)
    rumble = one_pole(one_pole(brown, rumble_cutoff), rumble_cutoff)
    # Rolling thunder: overlapping swells at uneven times.
    peaks = [(local.uniform(.1, seconds * .6), local.uniform(.4, 1.1), local.uniform(.3, 1.0)) for _ in range(swells)]
    out = []
    for i in range(n):
        t = i / RATE
        envelope = sum(a * math.exp(-((t - at) / width) ** 2) for at, width, a in peaks)
        envelope += .35 * math.exp(-t * .5)
        tail = min(1, (seconds - t) * 1.5)
        out.append(rumble[i] * envelope * tail * (1 - math.exp(-t * 30)))
    if crack:
        burst = band([local.uniform(-1, 1) for _ in range(int(RATE * .6))], 120, 4000)
        for i, x in enumerate(burst):
            t = i / RATE
            out[i] += x * crack * math.exp(-t * 9) * (1 - math.exp(-t * 400))
    return out


save('thunder_0', thunder(5.5, 1.6, 180, 4, 11))
save('thunder_1', thunder(6.0, .5, 130, 5, 23))
save('thunder_2', thunder(6.5, 0.0, 90, 6, 37))
