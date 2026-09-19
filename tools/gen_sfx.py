#!/usr/bin/env python3
"""Procedural placeholder SFX (no external deps). Regenerate with: python3 tools/gen_sfx.py
Everything here is synthesised; nothing is sampled from any game."""
import math, random, struct, wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")
random.seed(7)


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = 0.9 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * norm)) * 32767)) for s in samples))


def env(t, a, d):  # attack/decay seconds
    if t < a: return t / a
    return math.exp(-(t - a) / d)


def lowpass(samples, alpha):
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y); out.append(y)
    return out


def noise(n): return [random.uniform(-1, 1) for _ in range(n)]


def sfx_ar_fire():
    n = int(SR * 0.16); ns = noise(n); out = []
    for i in range(n):
        t = i / SR
        crack = ns[i] * env(t, 0.001, 0.018)
        body = lowpass([ns[i]], 0.15)[0] * env(t, 0.002, 0.05) * 1.6
        thump = math.sin(2 * math.pi * (140 - 400 * t) * t) * env(t, 0.001, 0.03) * 0.9
        out.append(crack + body + thump)
    return lowpass(out, 0.6)


def sfx_hit():
    n = int(SR * 0.09); ns = noise(n); out = []
    for i in range(n):
        t = i / SR
        out.append(ns[i] * env(t, 0.001, 0.012) + math.sin(2 * math.pi * 220 * t) * env(t, 0.001, 0.03) * 0.5)
    return lowpass(out, 0.35)


def sfx_kill():
    n = int(SR * 0.32); ns = noise(n); out = []
    for i in range(n):
        t = i / SR
        f = 420 * math.exp(-t * 6)
        squelch = math.sin(2 * math.pi * f * t + 3 * math.sin(2 * math.pi * 9 * t)) * env(t, 0.004, 0.09)
        splat = ns[i] * env(t, 0.002, 0.06) * 0.8
        out.append(squelch + splat)
    return lowpass(out, 0.25)


def sfx_reload_start():
    n = int(SR * 0.12); out = []
    for i in range(n):
        t = i / SR
        out.append(math.sin(2 * math.pi * 1800 * t) * env(t, 0.001, 0.01) + random.uniform(-1, 1) * env(t, 0.0005, 0.006) * 0.6)
    return out


def sfx_reload_end():
    n = int(SR * 0.18); out = []
    for i in range(n):
        t = i / SR
        c1 = math.sin(2 * math.pi * 1200 * t) * env(t, 0.001, 0.012)
        c2 = math.sin(2 * math.pi * 900 * (t - 0.07)) * env(max(0, t - 0.07), 0.001, 0.02) if t > 0.07 else 0
        out.append(c1 + c2 * 1.2 + random.uniform(-1, 1) * env(t, 0.0005, 0.004) * 0.5)
    return out


def sfx_dash():
    n = int(SR * 0.22); ns = lowpass(noise(n), 0.08); out = []
    for i in range(n):
        t = i / SR
        out.append(ns[i] * env(t, 0.03, 0.06) * 3.0)
    return out


def sfx_player_hurt():
    n = int(SR * 0.25); out = []
    for i in range(n):
        t = i / SR
        out.append(math.sin(2 * math.pi * (90 + 30 * math.sin(2 * math.pi * 30 * t)) * t) * env(t, 0.003, 0.08) + random.uniform(-1, 1) * env(t, 0.001, 0.02) * 0.5)
    return lowpass(out, 0.3)


def sfx_enemy_attack():
    n = int(SR * 0.14); ns = noise(n); out = []
    for i in range(n):
        t = i / SR
        out.append(math.sin(2 * math.pi * 620 * math.exp(-t * 4) * t) * env(t, 0.005, 0.04) + ns[i] * env(t, 0.002, 0.03) * 0.4)
    return lowpass(out, 0.4)


if __name__ == "__main__":
    for name, fn in [("ar_fire", sfx_ar_fire), ("hit", sfx_hit), ("kill", sfx_kill), ("reload_start", sfx_reload_start),
                     ("reload_end", sfx_reload_end), ("dash", sfx_dash), ("player_hurt", sfx_player_hurt), ("enemy_attack", sfx_enemy_attack)]:
        write(name, fn()); print("wrote", name)
