"""Music for the Gasthaus (DESIGN.md §10: music only in the hub, Stubenmusi / accordion).

A little waltz in G for a musette-tuned accordion: melody in the right hand, "oom-pa-pa"
bass and chords in the left. Written as a seamless loop."""
import numpy as np

import dsp as d
from sfx import cowbell, thud

SR = d.SR
BPM = 152.0
BEAT = 60.0 / BPM

# One chord per bar (32 bars = two times the 16-bar tune with a varied ending).
CHORDS = ["G", "G", "D7", "D7", "D7", "D7", "G", "G", "G", "G", "C", "C", "G", "D7", "G", "G"]
CHORD_NOTES = {"G": (43, [55, 59, 62]), "D7": (38, [54, 57, 60]), "C": (36, [55, 60, 64])}
FIFTH = {"G": 38, "D7": 45, "C": 43}

# (midi note or None for a rest, beats) per bar of the tune.
TUNE = [
    [(71, 1), (74, 1), (79, 1)],
    [(79, 2), (78, 1)],
    [(81, 2), (78, 1)],
    [(74, 3)],
    [(72, 1), (74, 1), (78, 1)],
    [(81, 2), (84, 1)],
    [(83, 2), (81, 1)],
    [(79, 3)],
    [(74, 1), (79, 1), (83, 1)],
    [(86, 2), (83, 1)],
    [(84, 2), (79, 1)],
    [(76, 3)],
    [(74, 1), (79, 1), (83, 1)],
    [(81, 1), (84, 1), (78, 1)],
    [(79, 3)],
    [(67, 1), (71, 1), (74, 1)],
]


def freq(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def reed(f, seconds, bright=1.0):
    """One accordion reed: a buzzy, slightly nasal tone."""
    x = d.harmonics(f, seconds, [1.0, 0.75, 0.55, 0.42, 0.3, 0.22, 0.16, 0.1, 0.07, 0.05])
    return d.lowpass(x, 2600.0 * bright)


def accordion(midi, seconds, level=1.0, musette=True):
    """Musette tuning: a reed tuned a little sharp beside the main one makes the wobble."""
    f = freq(midi)
    x = reed(f, seconds)
    if musette:
        x = x + 0.8 * reed(f * 2.0 ** (12.0 / 1200.0), seconds)
    n = len(x)
    env = d.env_adsr(seconds, 0.025, 0.08, 0.85, min(0.12, seconds * 0.3))[:n]
    bellows = 1.0 + 0.06 * np.sin(2 * np.pi * 0.7 * np.arange(n) / SR)
    return x * env * bellows * level


def place(track, x, at):
    i = int(round(at * SR))
    end = min(len(track), i + len(x))
    track[i:end] += x[:end - i]


def stubenmusi(_v):
    bars = len(TUNE) * 2
    seconds = bars * 3 * BEAT
    right = np.zeros(int(seconds * SR) + SR)
    left = np.zeros_like(right)
    for bar in range(bars):
        start = bar * 3 * BEAT
        chord = CHORDS[bar % len(CHORDS)]
        root, triad = CHORD_NOTES[chord]
        bass = root if bar % 2 == 0 else FIFTH[chord]
        place(left, accordion(bass, BEAT * 0.8, 0.9, musette=False), start)
        for beat in (1, 2):
            for note in triad:
                place(left, accordion(note, BEAT * 0.42, 0.28, musette=False), start + beat * BEAT)
        t = start
        tune_bar = TUNE[bar % len(TUNE)]
        if bar == bars - 1:
            tune_bar = [(79, 1), (74, 1), (71, 1)]  # lead back into the top of the loop
        for note, beats in tune_bar:
            if note is not None:
                place(right, accordion(note, beats * BEAT * 0.94, 0.55), t)
            t += beats * BEAT
    x = d.mix(right, d.lowpass(left, 1800.0) * 0.8)
    loop_len = int(seconds * SR)
    # Fold the tail (release + reverb) back onto the start so the loop has no gap.
    x = d.reverb(x, 1.0, 0.18, damp=3500.0, pre=0.01)
    body = x[:loop_len].copy()
    tail = x[loop_len:]
    body[:len(tail)] += tail[:len(body)]
    return d.normalize(body, 0.8)


# --- M10: boss stings (DESIGN.md §10: the only music in the mine) ------------------------------------
# A few seconds when a boss wakes, and one when a boss falls. Played flat (not from a place) on the
# Music bus; built with the mine's long room so they sound as if they came out of the rock.

def brass(midi, seconds, level=1.0, dark=1.0):
    """A brass note: buzzy harmonics that open up as the note swells, a breath of air on top."""
    f = freq(midi)
    n = d.n_of(seconds)
    swell = d.env_points(seconds, [(0, 0), (min(0.08, seconds * 0.3), 1.0), (seconds * 0.7, 0.85), (seconds, 0)])[:n]
    bright = 0.45 + 0.35 * swell
    x = d.harmonics(f, seconds, [1.0, 0.8, 0.65, 0.5, 0.38, 0.28, 0.2, 0.14, 0.1, 0.07], bright)[:n]
    x = d.lowpass(x, 1800.0 * dark) + d.bandpass(d.noise(seconds), f * 2, min(f * 8, 9000))[:n] * 0.04
    return x * swell * level


def drum(level=1.0, deep=1.0):
    """A big low drum (a Perchtenlauf drum or a Blasmusik bass drum)."""
    return d.mix(thud(58 * deep, 0.14, 1.0), d.lowpass(d.noise(0.5), 600) * d.env_exp(0.5, 0.04) * 0.4) * level


def room(x, seconds=3.0):
    return d.normalize(d.reverb(x, seconds, 0.45, damp=2600.0, pre=0.03), 0.8)


def sting_bergkini(_v):
    """Da Bergkini: a crooked little Blasmusik fanfare in minor – tuba oom-pa, a bass drum and a
    trumpet call that ends a semitone too low, like a king laughing at you."""
    beat = 60.0 / 132.0
    track = np.zeros(d.n_of(beat * 12 + 4.0))
    for i, note in enumerate([38, 45, 38, 45, 37, 44, 38, 38]):
        place(track, brass(note, beat * 0.7, 0.9, 0.6), i * beat)
        if i % 2 == 0:
            place(track, drum(0.7), i * beat)
    call = [(62, 0.5), (65, 0.5), (69, 1.0), (68, 0.5), (65, 0.5), (61, 2.5)]
    t = beat * 2
    for note, beats in call:
        place(track, brass(note, beats * beat * 0.95, 0.55, 1.2), t)
        t += beats * beat
    place(track, d.mix(drum(1.0), cowbell(780, 0.8, 0.25)), beat * 8)
    return room(track, 2.6)


def sting_seemuada(_v):
    """D'Seemuada: something huge rising in black water – a sub swell, a low horn cluster that
    slides down, bubbles of glassy harmonics, one deep blow."""
    s = 7.0
    swell = d.sine(d.glide(s, 36, 31), s) * d.env_points(s, [(0, 0), (2.5, 1.0), (5.5, 0.6), (7.0, 0)])
    horns = d.mix(*[(0.6 + i * 0.25, brass(m, 5.0, 0.35, 0.45)) for i, m in enumerate([33, 40, 46])])
    glass = d.mix(*[(d.rng.uniform(0.3, 5.0), d.partials(1.2, [(d.rng.uniform(900, 2400), 0.12, 0.4)])) for _ in range(9)])
    blow = d.mix((2.4, drum(1.0, 0.75)), (2.42, d.lowpass(d.noise(1.5), 300) * d.env_exp(1.5, 0.3) * 0.5))
    return room(d.mix(swell * 0.9, horns, glass, blow), 3.5)


def sting_schiachpercht(_v):
    """Die Schiachpercht: a Perchtenlauf breaking loose – bells clanging out of time, heavy drums
    speeding up, a dissonant horn blast over it all."""
    track = np.zeros(d.n_of(7.0))
    t = 0.0
    gap = 0.55
    while t < 4.2:
        place(track, drum(0.9, 0.9), t)
        t += gap
        gap = max(0.2, gap * 0.86)
    for _ in range(28):
        at = d.rng.uniform(0.0, 4.6)
        place(track, cowbell(d.rng.uniform(320, 700), 0.6, d.rng.uniform(0.15, 0.4)), at)
    blast = d.mix(brass(41, 2.6, 0.7, 0.9), brass(47, 2.6, 0.55, 0.9), brass(48, 2.6, 0.4, 0.9))
    place(track, blast, 3.9)
    place(track, drum(1.2, 0.7), 3.9)
    return room(track, 3.0)


def sting_boss_down(_v):
    """A boss falls: the drum stops, one low horn chord resolves upward into major and dies away
    in the rock – relief, not triumph (the way back is still ahead)."""
    s = 6.0
    first = d.mix(brass(41, 2.2, 0.6, 0.7), brass(44, 2.2, 0.45, 0.7), brass(48, 2.2, 0.35, 0.7))
    second = d.mix(brass(41, 3.6, 0.6, 0.8), brass(45, 3.6, 0.45, 0.8), brass(48, 3.6, 0.35, 0.8), brass(53, 3.6, 0.25, 0.9))
    return room(d.mix(drum(0.8), (0.1, first), (1.9, second)), 3.5)
