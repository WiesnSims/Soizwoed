"""Music for the Gasthaus (DESIGN.md §10: music only in the hub, Stubenmusi / accordion).

A little waltz in G for a musette-tuned accordion: melody in the right hand, "oom-pa-pa"
bass and chords in the left. Written as a seamless loop."""
import numpy as np

import dsp as d

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
