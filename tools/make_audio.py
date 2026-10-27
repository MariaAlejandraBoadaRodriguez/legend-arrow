#!/usr/bin/env python3
"""Synthesises every Legend Arrow sound from code (no samples, no third-party
assets). Deterministic: running it again rewrites byte-identical files.

    python3 tools/make_audio.py        # writes assets/audio/*.wav

Sounds are soft (sine/triangle partials, slow attacks, peak <= -6 dBFS) so
nothing is harsh for small children or at night.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
PEAK = 0.5  # -6 dBFS


def note(n):
    """MIDI note -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def env(i, n, attack, release):
    a = int(attack * RATE)
    r = int(release * RATE)
    if i < a:
        return i / max(1, a)
    if i > n - r:
        return max(0.0, (n - i) / max(1, r))
    return 1.0


def tone(freq, dur, attack=0.005, release=None, partials=((1, 1.0),), decay=0.0, bend=0.0):
    n = int(dur * RATE)
    release = dur * 0.6 if release is None else release
    out = []
    for i in range(n):
        t = i / RATE
        f = freq * (1 + bend * t / dur)
        s = sum(a * math.sin(2 * math.pi * f * k * t) for k, a in partials)
        out.append(s * env(i, n, attack, release) * math.exp(-decay * t))
    return out


def mix(dst, src, at=0.0, gain=1.0):
    o = int(at * RATE)
    need = o + len(src)
    if len(dst) < need:
        dst.extend([0.0] * (need - len(dst)))
    for i, s in enumerate(src):
        dst[o + i] += s * gain
    return dst


def normalise(buf, peak=PEAK):
    m = max(1e-9, max(abs(s) for s in buf))
    return [s * peak / m for s in buf]


def write(name, buf, peak=PEAK):
    buf = normalise(buf, peak)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in buf))
    return path


BELL = ((1, 1.0), (2, 0.35), (3, 0.12), (4.2, 0.05))
SOFT = ((1, 1.0), (2, 0.2))


def sfx():
    write("tap", tone(note(79), 0.06, 0.002, 0.05, SOFT, decay=30))
    # Exit: quick rising whoosh-like glide on a soft partial stack.
    write("exit", tone(note(72), 0.22, 0.01, 0.15, SOFT, decay=6, bend=0.5))
    # Blocked: low, short, falling thud (never a buzzer).
    write("blocked", tone(note(50), 0.18, 0.004, 0.14, ((1, 1.0), (1.5, 0.3)), decay=14, bend=-0.15))
    # Hint: two-note sparkle.
    buf = mix([], tone(note(84), 0.25, 0.004, 0.2, BELL, decay=8))
    write("hint", mix(buf, tone(note(91), 0.35, 0.004, 0.3, BELL, decay=7), 0.09))
    # Complete: gentle major arpeggio.
    buf = []
    for k, n in enumerate([72, 76, 79, 84]):
        mix(buf, tone(note(n), 0.9, 0.006, 0.7, BELL, decay=3.5), 0.11 * k)
    write("complete", buf)
    write("ui", tone(note(76), 0.08, 0.003, 0.06, SOFT, decay=25), PEAK * 0.7)


# Each creature: a short motif (MIDI notes, step seconds, timbre, octave shift).
CREATURES = {
    "forest_drake": ([55, 62, 67, 74], 0.16, SOFT, 0),
    "moon_owl": ([72, 69, 72, 76], 0.22, BELL, 0),
    "antler_fox": ([67, 71, 74, 79, 74], 0.11, BELL, 0),
    "basilisk": ([52, 51, 58, 57], 0.2, ((1, 1.0), (3, 0.3)), 0),
    "wyvern": ([60, 67, 72, 79], 0.12, SOFT, 0),
    "arctic_drake": ([76, 83, 88, 83, 91], 0.12, BELL, 0),
    "griffin": ([64, 71, 76, 71, 79], 0.13, SOFT, 0),
    "cloud_serpent": ([69, 72, 74, 76, 79, 81], 0.12, BELL, 0),
    "stone_wyrm": ([43, 50, 43, 55], 0.22, ((1, 1.0), (2, 0.5), (3, 0.25)), 0),
    "unicorn": ([79, 83, 86, 91], 0.16, BELL, 0),
    "phoenix": ([65, 69, 72, 77, 81, 84], 0.1, BELL, 0),
    "ancient_dragon": ([41, 48, 53, 60, 65], 0.2, ((1, 1.0), (2, 0.45), (3, 0.2)), 0),
}


def creatures():
    for cid, (notes, step, timbre, shift) in CREATURES.items():
        buf = []
        for k, n in enumerate(notes):
            last = k == len(notes) - 1
            mix(buf, tone(note(n + shift), 1.4 if last else 0.6, 0.01, 1.0 if last else 0.4, timbre, decay=2.0), step * k)
        write("creature_" + cid, buf)


def music():
    """A calm 32 s pad loop (I-vi-IV-V in C, slow attacks) with soft bell
    notes from a seeded RNG. Loop-safe: every voice ends before the loop point
    and the tail of each chord is folded back onto the start."""
    rng = random.Random(7)
    length = 32.0
    n = int(length * RATE)
    buf = [0.0] * n
    chords = [[48, 55, 60, 64], [45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59]]
    seg = length / len(chords)
    for c, chord in enumerate(chords):
        for m in chord:
            v = tone(note(m), seg + 2.0, 1.5, 2.5, ((1, 1.0), (2, 0.08)))
            start = int(c * seg * RATE)
            for i, s in enumerate(v):
                buf[(start + i) % n] += s * 0.22
        scale = [72, 74, 76, 79, 81]
        for b in range(3):
            t = c * seg + 1.0 + b * 2.4 + rng.random() * 0.6
            v = tone(note(rng.choice(scale)), 2.0, 0.01, 1.6, BELL, decay=1.6)
            start = int(t * RATE)
            for i, s in enumerate(v):
                buf[(start + i) % n] += s * 0.12
    write("music_ambient", buf, PEAK * 0.8)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    creatures()
    music()
    print("wrote", sorted(os.listdir(OUT)))
