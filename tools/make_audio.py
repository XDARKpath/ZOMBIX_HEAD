"""Suoni originali per ZOMBIX HEAD: sintesi pura, nessun campione esterno."""
import math
import os
import random
import struct
import wave

SR = 22050
random.seed(7)
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


def save(name, data):
    peak = max(1e-6, max(abs(x) for x in data))
    scale = 0.85 / peak
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767)) for x in data
    )
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(frames)


def noise(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(int(SR * seconds))]


def lowpass(data, alpha):
    out, y = [], 0.0
    for sample in data:
        y += alpha * (sample - y)
        out.append(y)
    return out


def highpass(data, alpha):
    out, y = [], 0.0
    for sample in data:
        y += alpha * (sample - y)
        out.append(sample - y)
    return out


def envelope(n, attack, decay):
    out = []
    for i in range(n):
        t = i / SR
        a = min(1.0, t / max(attack, 1e-4))
        out.append(a * math.exp(-t / max(decay, 1e-4)))
    return out


def synth_impact(low_hz, decay, noise_amount):
    n = int(SR * decay * 4)
    env = envelope(n, 0.004, decay)
    raw = noise(decay * 4)
    body = [math.sin(2 * math.pi * low_hz * i / SR) for i in range(n)]
    out = []
    for i in range(n):
        out.append(env[i] * (body[i] * (1.0 - noise_amount) + raw[i] * noise_amount))
    return lowpass(out, 0.25)


def synth_whoosh(seconds=0.34):
    env = envelope(int(SR * seconds), 0.02, seconds * 0.45)
    raw = lowpass(noise(seconds), 0.12)
    return [raw[i] * env[i] for i in range(len(env))]


def synth_footstep():
    n = int(SR * 0.16)
    env = envelope(n, 0.002, 0.05)
    raw = lowpass(noise(0.16), 0.35)
    out = []
    for i in range(n):
        click = math.sin(2 * math.pi * 140 * i / SR) * 0.3
        out.append(env[i] * (raw[i] + click))
    return out


def synth_fire(seconds=3.0):
    n = int(SR * seconds)
    base = lowpass(noise(seconds), 0.05)
    out = []
    pops = {int(SR * random.uniform(0.05, seconds - 0.05)) for _ in range(26)}
    for i in range(n):
        t = i / SR
        value = base[i] * 0.20 + math.sin(2 * math.pi * 62 * t) * 0.05
        if i in pops:
            value += random.uniform(0.4, 0.9)
        out.append(value)
    # Il fuoco gira in loop: raccordo breve ai bordi.
    fade = int(SR * 0.02)
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return out


def synth_forest(seconds=4.0):
    n = int(SR * seconds)
    wind = lowpass(noise(seconds), 0.02)
    out = [wind[i] * 0.5 for i in range(n)]
    for chirp_start in (0.4, 1.6, 2.7, 3.4):
        start = int(SR * chirp_start)
        length = int(SR * 0.12)
        for k in range(length):
            if start + k >= n:
                break
            t = k / SR
            freq = 2100 + 700 * math.sin(math.pi * k / length)
            out[start + k] += math.sin(2 * math.pi * freq * t) * 0.16 * math.sin(math.pi * k / length)
    return out


def synth_engine(seconds=2.0):
    n = int(SR * seconds)
    out = []
    for i in range(n):
        t = i / SR
        saw = 0.0
        for hz, amp in ((55, 0.5), (110, 0.22), (165, 0.12)):
            phase = (hz * t) % 1.0
            saw += (2.0 * phase - 1.0) * amp
        rattle = math.sin(2 * math.pi * 6.5 * t) * 0.05
        out.append(saw + rattle)
    return out


def synth_hover():
    n = int(SR * 0.09)
    return [math.sin(2 * math.pi * 880 * i / SR) * math.exp(-i / SR * 38) for i in range(n)]


def synth_press():
    n = int(SR * 0.16)
    out = []
    for i in range(n):
        t = i / SR
        freq = 520 - 260 * (t / 0.16)
        out.append(math.sin(2 * math.pi * freq * t) * math.exp(-t * 18))
    return out


save("hit.wav", synth_impact(90, 0.10, 0.55))
save("heavy.wav", synth_impact(55, 0.22, 0.45))
save("swing.wav", synth_whoosh())
save("footstep.wav", synth_footstep())
save("fire.wav", synth_fire())
save("forest.wav", synth_forest())
save("vehicle_engine.wav", synth_engine())
save("menu_hover.wav", synth_hover())
save("menu_press.wav", synth_press())
print("AUDIO OK")
