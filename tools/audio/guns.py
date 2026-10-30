"""The guns of Soizwöd, built from real recordings: "The Free Firearm Sound Library" (CC0), the
cuts Berghittn made of it, kept untouched in tools/audio/recordings/ (see docs/ASSETS.md).

Those takes come from an open shooting range: a bright crack and little body. A shot in a mine
tunnel is different – the charge goes off in a tube of rock, so there is a deep boom under the
crack and a dense rattle of slaps off walls a few metres away. That is added here, and the
Salzschrot-Flinte gets the weight a 12-bore has over a pistol. The long roll down the galleries
is shot_echo (sfx.py), played on top of every shot in the game.

The break-action reload of the Flinte (open, shell in, close) and its dry click are made from
the recorded metal sounds too. Built by build.py like every other sound."""
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

import dsp as d
from sfx import click, thud

RECORDINGS = Path(__file__).resolve().parent / "recordings"


def take(name: str) -> np.ndarray:
    x, sr = sf.read(str(RECORDINGS / f"{name}.ogg"), always_2d=True)
    x = x.mean(axis=1)
    return signal.resample_poly(x, d.SR, sr) if sr != d.SR else x


def pitched(x: np.ndarray, factor: float) -> np.ndarray:
    """Played `factor` times as fast, like a tape (< 1 = lower and longer)."""
    n = int(len(x) / factor)
    return np.interp(np.arange(n) * factor, np.arange(len(x)), x)


def rock_slaps(x: np.ndarray, count: int, first: float, last: float, damp: float) -> np.ndarray:
    """Early reflections off tunnel walls: `count` slaps between `first` and `last` seconds,
    darker and weaker the later they come."""
    ir = np.zeros(d.n_of(last) + 1)
    ir[0] = 1.0
    for i in range(count):
        at = d.rng.uniform(first, last)
        ir[d.n_of(at)] += d.rng.choice([-1.0, 1.0]) * 0.55 * (1.0 - at / (last * 1.25)) * d.rng.uniform(0.6, 1.0)
    wet = signal.fftconvolve(d.lowpass(x, damp), ir)[: len(x) + len(ir)]
    return d.mix(x * 0.5, wet * 0.5)


def boom(freq: float, decay: float) -> np.ndarray:
    """The charge going off in a tube of rock: a falling sub thump and a dark puff of air."""
    s = decay * 7
    sub = d.sine(d.glide(s, freq, freq * 0.5, 0.6), s) * d.env_exp(s, decay, 0.002)
    puff = d.lowpass(d.noise(s), 320) * d.env_exp(s, decay * 0.6, 0.001)
    return d.mix(sub, puff * 0.8)


def mine_shot(x: np.ndarray, rate: float, boom_hz: float, boom_decay: float, boom_level: float,
              weight: float, slaps: int, length: float) -> np.ndarray:
    x = d.normalize(pitched(x, rate))
    # Weight: the take itself an octave-ish down and dark, under the original.
    heavy = d.lowpass(pitched(x, 0.62), 900) * weight
    body = d.mix(x, heavy, boom(boom_hz, boom_decay) * boom_level)
    body = rock_slaps(body, slaps, 0.004, 0.045, 3200)
    body = d.reverb(body, 0.45, 0.22, 2400, 0.012)
    body = d.drive(d.normalize(body), 2.2)
    body = body[: d.n_of(length)]
    return d.fade(body, 0.0005, length * 0.45)


def shot_pistole(v):
    """Dienstpistole: the Walther PPQ take (three near-identical cuts, so each variant gets its own
    speed, boom and pattern of slaps)."""
    return mine_shot(take(f"shot_pistole_{v + 1}"), [1.0, 0.96, 1.035][v], [95, 86, 104][v], 0.045, 0.5, 0.2, 10, 1.1)


def shot_flinte(v):
    """Salzschrot-Flinte: the 12-bore takes (Winchester Model 12, Charles Daly), much heavier."""
    return mine_shot(take(f"shot_jagdflinte_{v + 1}"), [0.97, 0.94, 0.97, 0.94][v], [66, 60, 70, 62][v], 0.09, 0.9, 0.75, 14, 1.4)


def flinte_open(v):
    """Breaking the Flinte open: the lever, the hinge clunking down, the empty hulls popping out
    and falling on the rock."""
    hinge = d.lowpass(pitched(take("bolt_open_1"), 0.72), 5000)
    hull = lambda: d.mix(click(1900 + d.rng.uniform(-200, 200), 0.008, 0.5, ring=0.15), thud(240, 0.012, 0.25))
    return d.mix(click(1300, 0.006, 0.6, ring=0.3), (0.05, hinge), (0.12, thud(180, 0.02, 0.5)),
                 (0.42, hull()), (0.47, hull() * 0.7), (0.55, hull() * 0.4))


def flinte_close(v):
    """Snapping the barrels shut: a heavy steel clack."""
    clack = pitched(take("bolt_close_1"), 0.8)
    return d.mix(clack, thud(150, 0.03, 0.7), (0.004, click(2400, 0.005, 0.5, ring=0.4)))


def shell_in(v):
    """A salt shell slid into a barrel: a paper hull scraping steel, seated with a soft tock."""
    slide = d.bandpass(d.noise(0.14), 900, 3200) * d.env_points(0.14, [(0, 0), (0.03, 0.6), (0.12, 0.4), (0.14, 0)])
    return d.mix(slide * 0.6, (0.13, click(1500 + 120 * v, 0.008, 0.7, ring=0.3)), (0.13, thud(320, 0.012, 0.35)))


def dry_click_flinte(v):
    """A hammer falling on a spent shell: deeper than the pistol's click."""
    return d.mix(pitched(take("dry_click_1"), 0.7), thud(260, 0.01, 0.3))


SOUNDS = {
    "shot_pistole": (shot_pistole, 3),
    "shot_flinte": (shot_flinte, 4),
    "flinte_open": (flinte_open, 1),
    "flinte_close": (flinte_close, 1),
    "shell_in": (shell_in, 3),
    "dry_click_flinte": (dry_click_flinte, 1),
}
