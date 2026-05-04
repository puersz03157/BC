# -*- coding: utf-8 -*-
"""Generate short placeholder SFX as mono 16-bit 22050 Hz WAV for Godot 4."""
from __future__ import annotations

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def _write_wav(path: str, samples: list[int]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        for s in samples:
            w.writeframes(struct.pack("<h", max(-32767, min(32767, int(s)))))


def _env_linear(n: int, fade_in: int, fade_out: int) -> list[float]:
    e = []
    for i in range(n):
        v = 1.0
        if i < fade_in and fade_in > 0:
            v = i / fade_in
        j = n - 1 - i
        if j < fade_out and fade_out > 0:
            v = min(v, j / fade_out)
        e.append(v)
    return e


def gen_attack_chop() -> list[int]:
    """Short impact + noise for melee / axe on wood or stone."""
    dur = 0.11
    n = int(SAMPLE_RATE * dur)
    env = _env_linear(n, 8, 40)
    out: list[int] = []
    random.seed(42)
    for i in range(n):
        t = i / SAMPLE_RATE
        # Low thump + band-limited noise burst
        thump = 0.55 * math.sin(2 * math.pi * 95 * t) * math.exp(-t * 38)
        noise = (random.random() * 2 - 1) * 0.35 * math.exp(-t * 55)
        mid = 0.12 * math.sin(2 * math.pi * 420 * t) * math.exp(-t * 30)
        v = (thump + noise + mid) * env[i]
        out.append(int(32767 * v))
    return out


def gen_cook() -> list[int]:
    """Sizzle / crackle for campfire cooking."""
    dur = 0.22
    n = int(SAMPLE_RATE * dur)
    env = _env_linear(n, 20, 60)
    out: list[int] = []
    random.seed(7)
    for i in range(n):
        t = i / SAMPLE_RATE
        crack = (random.random() * 2 - 1) * 0.22 * (0.5 + 0.5 * math.sin(2 * math.pi * 6 * t))
        hiss = (random.random() * 2 - 1) * 0.08
        v = (crack + hiss) * env[i] * (0.65 + 0.35 * math.sin(2 * math.pi * 2.2 * t))
        out.append(int(32767 * v))
    return out


def gen_craft() -> list[int]:
    """Hammer / anvil-ish: two tone hits."""
    total = int(SAMPLE_RATE * 0.2)
    out = [0] * total

    def add_hit(start_sec: float, f0: float) -> None:
        start = int(SAMPLE_RATE * start_sec)
        seg_n = int(SAMPLE_RATE * 0.055)
        for i in range(seg_n):
            idx = start + i
            if idx >= total:
                break
            t = i / SAMPLE_RATE
            env = math.exp(-t * 30)
            s = 0.44 * math.sin(2 * math.pi * f0 * t) + 0.1 * math.sin(2 * math.pi * f0 * 2.4 * t)
            out[idx] += int(32767 * s * env)

    add_hit(0.015, 540)
    add_hit(0.09, 360)
    return out


def gen_interact() -> list[int]:
    """Soft UI / use-object blip."""
    dur = 0.07
    n = int(SAMPLE_RATE * dur)
    env = _env_linear(n, 4, 20)
    out: list[int] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        v = 0.32 * (
            math.sin(2 * math.pi * 660 * t) + 0.45 * math.sin(2 * math.pi * 990 * t)
        ) * env[i]
        out.append(int(32767 * v))
    return out


def gen_pickup() -> list[int]:
    """Quick rising chirp."""
    dur = 0.09
    n = int(SAMPLE_RATE * dur)
    env = _env_linear(n, 6, 25)
    out: list[int] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 380 + 620 * (t / (dur * 0.95))
        v = 0.34 * math.sin(2 * math.pi * f * t) * env[i]
        out.append(int(32767 * v))
    return out


def gen_place() -> list[int]:
    """Wood thud for placing build."""
    dur = 0.14
    n = int(SAMPLE_RATE * dur)
    env = _env_linear(n, 4, 45)
    out: list[int] = []
    random.seed(99)
    for i in range(n):
        t = i / SAMPLE_RATE
        body = 0.5 * math.sin(2 * math.pi * 70 * t) * math.exp(-t * 22)
        tap = 0.18 * math.sin(2 * math.pi * 200 * t) * math.exp(-t * 40)
        nse = (random.random() * 2 - 1) * 0.06 * math.exp(-t * 35)
        v = (body + tap + nse) * env[i]
        out.append(int(32767 * v))
    return out


def gen_skill_whoosh() -> list[int]:
    """Noise sweep for weapon skill."""
    dur = 0.18
    n = int(SAMPLE_RATE * dur)
    env = _env_linear(n, 10, 50)
    out: list[int] = []
    random.seed(3)
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 800 + 2200 * (t / dur)
        # pseudo bandpass: sine * noise
        car = math.sin(2 * math.pi * f * t * 0.015)
        ns = (random.random() * 2 - 1) * 0.35
        v = ns * (0.4 + 0.6 * abs(car)) * math.exp(-t * 8) * env[i]
        out.append(int(32767 * v))
    return out


def gen_eat() -> list[int]:
    """Small munch for consuming food."""
    dur = 0.08
    n = int(SAMPLE_RATE * dur)
    env = _env_linear(n, 4, 25)
    out: list[int] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        v = 0.22 * math.sin(2 * math.pi * 180 * t) * math.sin(2 * math.pi * 45 * t) * env[i]
        out.append(int(32767 * v))
    return out


def main() -> None:
    mapping = {
        "attack_chop.wav": gen_attack_chop,
        "cook.wav": gen_cook,
        "craft.wav": gen_craft,
        "interact.wav": gen_interact,
        "pickup.wav": gen_pickup,
        "place.wav": gen_place,
        "skill_whoosh.wav": gen_skill_whoosh,
        "eat.wav": gen_eat,
    }
    for name, fn in mapping.items():
        path = os.path.normpath(os.path.join(OUT_DIR, name))
        _write_wav(path, fn())
        print("Wrote", path)


if __name__ == "__main__":
    main()
