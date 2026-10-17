#!/usr/bin/env python3
"""Renders onboarding's sound cues into GymBlock/Resources/Sounds/onboarding/*.wav.

Every cue is synthesized here from first principles (sine partials, filtered noise, a small room),
so the app ships no third-party audio: the notification dings are GymBlock's own, not Instagram's
or TikTok's. The voices match the onboarding mockups (docs/onboarding-mockups/index.html), and each
scene's timing lives in JourneyScores.swift.

Pure Python, no dependencies: python3 scripts/generate-onboarding-sounds.py
"""
import math
import os
import random
import struct
import wave

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "GymBlock", "Resources", "Sounds", "onboarding")
random.seed(7)


def silence(seconds):
    return [0.0] * int(seconds * SR)


def add(buf, start, samples):
    i0 = int(start * SR)
    need = i0 + len(samples)
    if need > len(buf):
        buf.extend([0.0] * (need - len(buf)))
    for i, v in enumerate(samples):
        buf[i0 + i] += v


def expenv(n, attack, peak, decay):
    """The mockups' envelope: exponential rise to `peak`, exponential fall to silence."""
    out = []
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    lo = 0.0001
    for i in range(n):
        if i < a:
            out.append(lo * (peak / lo) ** (i / a))
        elif i < a + d:
            out.append(peak * (lo / peak) ** ((i - a) / d))
        else:
            out.append(0.0)
    return out


def osc(kind, f0, seconds, f1=None):
    n = int(seconds * SR)
    out, ph = [], 0.0
    for i in range(n):
        f = f0 if f1 is None else f0 * (f1 / f0) ** (i / n)
        ph += f / SR
        x = ph % 1.0
        if kind == "sine":
            v = math.sin(2 * math.pi * x)
        elif kind == "triangle":
            v = 4 * abs(x - 0.5) - 1
        elif kind == "square":
            v = 1.0 if x < 0.5 else -1.0
        else:  # saw
            v = 2 * x - 1
        out.append(v)
    return out


def noise(seconds):
    return [random.uniform(-1, 1) for _ in range(int(seconds * SR))]


def biquad(x, kind, f, q=0.707):
    w = 2 * math.pi * f / SR
    cw, sw = math.cos(w), math.sin(w)
    al = sw / (2 * q)
    if kind == "low":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "high":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:  # band
        b0, b1, b2 = al, 0, -al
    a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def sweep_filter(x, kind, f0, f1, q=0.707):
    """A filter whose cutoff glides exponentially from f0 to f1, recomputed every 64 samples."""
    out, n = [], len(x)
    x1 = x2 = y1 = y2 = 0.0
    coef = None
    for i, v in enumerate(x):
        if i % 64 == 0:
            f = f0 * (f1 / f0) ** (i / max(1, n))
            w = 2 * math.pi * min(f, SR * 0.45) / SR
            cw, sw = math.cos(w), math.sin(w)
            al = sw / (2 * q)
            if kind == "low":
                b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
            else:
                b0, b1, b2 = al, 0, -al
            a0, a1, a2 = 1 + al, -2 * cw, 1 - al
            coef = (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
        b0, b1, b2, a1, a2 = coef
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        out.append(o)
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def room(x, wet=0.2, tail=0.7):
    """A small Schroeder room: four combs into two all-passes."""
    x = x + [0.0] * int(tail * SR)
    combs = [(int(SR * d), g) for d, g in ((0.0297, 0.77), (0.0371, 0.75), (0.0411, 0.73), (0.0437, 0.71))]
    acc = [0.0] * len(x)
    for delay, g in combs:
        buf = [0.0] * delay
        k = 0
        for i, v in enumerate(x):
            o = buf[k]
            buf[k] = v + o * g
            k = (k + 1) % delay
            acc[i] += o * 0.25
    for delay, g in ((int(SR * 0.005), 0.7), (int(SR * 0.0017), 0.7)):
        buf = [0.0] * delay
        k = 0
        for i, v in enumerate(acc):
            o = buf[k]
            y = -g * v + o
            buf[k] = v + g * y
            k = (k + 1) % delay
            acc[i] = y
    return [d + wet * r for d, r in zip(x, acc)]


# ---------- Voices (the mockups' WebAudio voices, sample by sample) ----------

def tick(f=1500, v=0.1, d=0.035):
    n = int((d + 0.03) * SR)
    return mul(osc("sine", f, n / SR, f * 0.85), expenv(n, 0.002, v, d))


def bell(f, v, d=0.55):
    out = silence(d + 0.1)
    for m, a, dk in ((1, 1, 1), (2.01, 0.32, 0.6), (2.76, 0.2, 0.45), (5.4, 0.07, 0.25)):
        if f * m > SR * 0.45:
            continue
        n = int((d * dk + 0.05) * SR)
        add(out, 0, mul(osc("sine", f * m, n / SR), expenv(n, 0.0015, v * a, d * dk)))
    return out


def ding(app, v=0.11):
    seq = {"ig": [(0, 1568)], "tt": [(0, 1175), (0.075, 1568)], "yt": [(0, 1760)], "msg": [(0, 1319), (0.11, 1760)]}[app]
    out = []
    for dt, f in seq:
        add(out, dt, bell(f, v))
    return out


def thud(v=0.5):
    n = int(0.5 * SR)
    out = mul(osc("sine", 120, 0.5, 40), expenv(n, 0.004, v, 0.42))
    m = int(0.1 * SR)
    add(out, 0, mul(biquad(noise(0.1), "low", 500), expenv(m, 0.002, v * 0.35, 0.07)))
    return out


def clack(v=0.3):
    m = int(0.08 * SR)
    out = mul(biquad(noise(0.08), "high", 2500), expenv(m, 0.001, v, 0.05))
    for i, f in enumerate((2100, 3150)):
        n = int(0.16 * SR)
        add(out, 0, mul(osc("triangle", f, 0.16), expenv(n, 0.001, v * 0.2 / (i + 1), 0.12)))
    return out


def whoosh(d=0.8, f0=300, f1=2600, v=0.14):
    n = int(d * SR)
    shaped = sweep_filter(noise(d), "band", f0, f1, 1.1)
    env = []
    lo = 0.0001
    for i in range(n):
        t = i / n
        env.append(lo * (v / lo) ** (t / 0.75) if t < 0.75 else v * (lo / v) ** ((t - 0.75) / 0.25))
    return mul(shaped, env)


def note(f, v=0.09, d=0.55):
    n = int((d + 0.05) * SR)
    out = mul(osc("sine", f, n / SR), expenv(n, 0.008, v, d))
    add(out, 0, mul(osc("sine", f * 2, n / SR), expenv(n, 0.008, v * 0.25, d * 0.6)))
    return out


def blur(f, v):
    out = note(f, v, 0.6)
    add(out, 0.01, note(f * 1.018, v * 0.7, 0.55))
    return out


def chime(notes, gap=0.09, v=0.08):
    out = []
    for i, f in enumerate(notes):
        add(out, i * gap, note(f, v, 0.9))
    return out


def sparkle(v=0.05):
    out = []
    for i, f in enumerate((1318.5, 1975.5, 2637)):
        n = int(1.15 * SR)
        add(out, i * 0.075, mul(osc("sine", f, 1.15), expenv(n, 0.02, v, 1.08)))
    n = int(0.6 * SR)
    env = [0.0001 * (0.018 / 0.0001) ** (i / (0.25 * SR)) if i < 0.25 * SR else 0.018 * (0.0001 / 0.018) ** ((i - 0.25 * SR) / (0.35 * SR)) for i in range(n)]
    add(out, 0, mul(biquad(noise(0.6), "band", 7000, 1.5), env))
    return out


def pad(d, f, c0, c1, v0, v1, drop=None):
    n = int((d + 0.3) * SR)
    mix = [0.0] * n
    for k, (x, kind) in enumerate(((f, "saw"), (f * 1.006, "saw"), (f * 1.498, "triangle"))):
        add(mix, 0, osc(kind, x, n / SR, x * drop if drop else None))
    shaped = sweep_filter(mix, "low", c0, c1, 0.7)
    env = []
    for i in range(n):
        t = i / SR
        if t < 0.4:
            g = v0 * t / 0.4
        elif t < d - 0.2:
            g = v0 + (v1 - v0) * (t - 0.4) / (d - 0.6)
        else:
            g = v1 * max(0, 1 - (t - (d - 0.2)) / 0.5)
        env.append(g)
    return mul(shaped, env)


def zap(d=0.7, v=0.06, cut=3000, f0=220, f1=660):
    n = int(d * SR)
    lo = 0.0001
    env = [lo * (v / lo) ** (i / (0.3 * n)) if i < 0.3 * n else v * (lo / v) ** ((i - 0.3 * n) / (0.7 * n)) for i in range(n)]
    return mul(biquad(osc("triangle", f0, d, f1), "low", cut, 1), env)


def pluck(f=330, v=0.1):
    n = int(0.5 * SR)
    out = mul(biquad(osc("triangle", f, 0.5), "low", 2200), expenv(n, 0.003, v, 0.45))
    m = int(0.25 * SR)
    add(out, 0, mul(osc("sine", f * 2, 0.25), expenv(m, 0.002, v * 0.5, 0.2)))
    return out


def swell(d=0.5, v=0.08):
    n = int((d + 0.4) * SR)
    env = [0.0001 * (v / 0.0001) ** (i / (d * SR)) if i < d * SR else v * (0.0001 / v) ** ((i - d * SR) / (0.35 * SR)) for i in range(n)]
    mix = [0.0] * n
    for f in (98, 147):
        add(mix, 0, osc("sine", f, n / SR, f * 1.12))
    return mul(mix, env)


def buzz(v=0.07):
    out = []
    for dt in (0, 0.13):
        n = int(0.1 * SR)
        add(out, dt, mul(biquad(osc("square", 165, 0.1), "low", 900), expenv(n, 0.004, v, 0.07)))
    return out


def pulse(v=0.4, f=85):
    n = int(0.22 * SR)
    return mul(osc("sine", f, 0.22, f * 0.7), expenv(n, 0.006, v, 0.18))


# ---------- The cues ----------

def cues():
    c = {}
    for app in ("ig", "tt", "yt", "msg"):
        c["ding-" + app] = (ding(app), 0.22)
    for k in range(12):
        c["count-%02d" % k] = (tick(900 + k * 70, 0.05), 0.08)
    for k in range(4):
        c["rattle-%d" % k] = (tick(1400 + k * 260, 0.03, 0.02), 0.05)
    c["tick-high"] = (tick(1568, 0.06), 0.15)
    c["tick-soft"] = (tick(1100, 0.04), 0.1)
    c["tick-low"] = (tick(900, 0.05), 0.1)
    c["tick-countdown"] = (tick(1000, 0.06), 0.1)
    c["scroll-flick"] = (tick(2600, 0.015, 0.02), 0.03)
    c["thud"] = (thud(0.6), 0.2)
    c["thud-soft"] = (thud(0.16), 0.15)
    c["clack"] = (clack(0.3), 0.15)
    c["fall"] = (whoosh(0.38, 2400, 350, 0.07), 0.15)
    c["air"] = (whoosh(0.55, 200, 1200, 0.06), 0.2)
    c["swell"] = (swell(0.5), 0.2)
    c["chime-flex"] = (chime((523.3, 784, 1046.5), 0.05, 0.07), 0.4)
    c["chime-gain"] = (chime((988, 1319)), 0.4)
    c["chime-pump"] = (chime((784, 1175)), 0.4)
    c["chime-rest"] = (chime((880, 1319), 0.09, 0.08), 0.4)
    c["chime-commit"] = (chime((523, 659, 784), 0.06, 0.07), 0.5)
    c["chime-mind"] = (chime((659.3, 830.6, 987.8), 0.06, 0.06), 0.5)
    c["sparkle"] = (sparkle(0.05), 0.4)
    c["sparkle-soft"] = (sparkle(0.035), 0.4)
    c["pump-flat"] = (note(220, 0.09, 0.45), 0.25)
    for name, f in (("c4", 261.6), ("e4", 329.6), ("g4", 392), ("c5", 523.3), ("e5", 659.3)):
        c["pump-" + name] = (note(f, 0.09), 0.25)
    for k, (f, v) in enumerate(((659, 0.07), (587, 0.055), (523, 0.04), (440, 0.03))):
        c["forget-%d" % k] = (blur(f, v), 0.3)
    for k, f in enumerate((392, 494, 440, 587, 784)):
        c["log-%d" % k] = (note(f, 0.07), 0.25)
    c["buzz"] = (buzz(), 0.1)
    c["pad-drain"] = (pad(3.6, 110, 1600, 220, 0.035, 0.008, 0.94), 0.3)
    c["pad-open"] = (pad(3.6, 110, 300, 1800, 0.02, 0.035), 0.3)
    c["zap-full"] = (zap(0.65, 0.07, 3200), 0.15)
    c["zap-steady"] = (zap(0.65, 0.06, 3400), 0.15)
    c["zap-fading-1"] = (zap(0.55, 0.05, 1500, 220, 520), 0.15)
    c["zap-fading-2"] = (zap(0.38, 0.035, 800, 220, 420), 0.15)
    c["zap-fading-3"] = (zap(0.22, 0.022, 450, 220, 330), 0.15)
    c["pluck"] = (pluck(330, 0.1), 0.25)
    c["pluck-soft"] = (pluck(330, 0.09), 0.25)
    return c


def write(name, samples, peak_target=0.9):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for v in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767))
        w.writeframes(bytes(frames))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (samples, tail) in cues().items():
        # Levels stay as designed (relative loudness is part of the score); only clipping is guarded.
        mixed = room(samples, 0.2, tail)
        peak = max(1e-9, max(abs(v) for v in mixed))
        gain = 4.0 if peak * 4.0 < 0.95 else 0.95 / peak
        write(name, [v * gain for v in mixed])
        print(name)


if __name__ == "__main__":
    main()
