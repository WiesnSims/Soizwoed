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


def shot_stutzen(v):
    """Mannlicher-Stutzen: the bolt-action takes (Tikka T3, two cuts, three variants). A sharp,
    high-pressure crack: less boom than the Flinte, more slaps and a longer tail."""
    return mine_shot(take(f"shot_stutzen_{[1, 2, 1][v]}"), [1.0, 0.97, 1.03][v], [78, 70, 84][v], 0.07, 0.7, 0.45, 16, 1.7)


def bolt_cycle(v):
    """Working the Stutzen's bolt after a shot: up and back (the case rings on the rock), forward
    and down."""
    case = d.mix(click(2600, 0.01, 0.4, ring=0.3), (0.06, click(2300, 0.01, 0.25, ring=0.3)))
    return d.mix(take("bolt_open_1"), (0.2, take("bolt_close_1")), (0.32, case))


def round_in(v):
    """A rifle round pressed down into the magazine through the open action."""
    slide = d.bandpass(d.noise(0.09), 1500, 5000) * d.env_points(0.09, [(0, 0), (0.02, 0.6), (0.09, 0)])
    return d.mix(slide * 0.5, (0.08, click(2100 + 150 * v, 0.006, 0.8, ring=0.35)), (0.085, thud(400, 0.01, 0.3)))


def shot_leucht(v):
    """The Leuchtpistole: a big, soft, low-pressure "plopp" and the flare's charge catching with
    a hiss as it leaves."""
    plop = d.lowpass(pitched(take("shot_pistole_1"), 0.55), 1600) * 0.6
    hiss = d.bandpass(d.noise(0.9), 2200, 7000) * d.env_points(0.9, [(0, 0), (0.03, 0.5), (0.9, 0)])
    body = d.mix(boom(105, 0.05) * 0.9, plop, (0.02, hiss * 0.4))
    return d.fade(d.reverb(d.drive(d.normalize(body), 1.6), 0.6, 0.25, 2400, 0.012), 0.0005, 0.4)


# --- M10: the Leuchtpistole's own break, the pistol's slide, drawing a weapon -----------------------

def leucht_open(v):
    """Breaking the Leuchtpistole: a light brass latch and the barrel dropping, the burnt
    cardboard case falling out (softer than the Flinte's hulls)."""
    latch = d.lowpass(pitched(take("bolt_open_1"), 1.15), 6000) * 0.6
    case = d.mix(thud(300, 0.012, 0.35), d.bandpass(d.noise(0.06), 600, 2500) * d.env_exp(0.06, 0.015) * 0.3)
    return d.mix(click(2100, 0.004, 0.5, ring=0.25), (0.03, latch), (0.36, case))


def leucht_close(v):
    """Snapping the flare gun shut: a light clack."""
    return d.mix(pitched(take("bolt_close_1"), 1.2) * 0.8, (0.002, click(3000, 0.004, 0.4, ring=0.3)))


def flare_in(v):
    """A fat flare cartridge pushed into the wide barrel: cardboard on brass, a hollow tock."""
    slide = d.bandpass(d.noise(0.18), 500, 2200) * d.env_points(0.18, [(0, 0), (0.04, 0.6), (0.16, 0.4), (0.18, 0)])
    return d.mix(slide * 0.6, (0.17, thud(240, 0.02, 0.6)), (0.17, click(1100, 0.01, 0.4, ring=0.2)))


def slide_rack(v):
    """Racking the Dienstpistole's slide after a fresh magazine: back, and slammed forward."""
    back = d.lowpass(pitched(take("bolt_open_1"), 1.5), 7000) * 0.7
    home = pitched(take("bolt_close_1"), 1.45)
    return d.mix(back, (0.11, home), (0.115, click(3400, 0.004, 0.6, ring=0.4)))


def weapon_draw(v):
    """Bringing a weapon up: cloth and leather, a light rattle of steel."""
    s = 0.35
    cloth = d.bandpass(d.pink(s), 400, 2500) * d.env_points(s, [(0, 0), (0.08, 0.7), (0.35, 0)])
    rattle = d.mix(*[(0.12 + i * 0.03 + d.rng.uniform(0, 0.01), click(2500 + 400 * v + d.rng.uniform(-300, 300), 0.004, 0.35, ring=0.3)) for i in range(2 + v)])
    return d.mix(cloth * 0.5, rattle)


SOUNDS = {
    "shot_stutzen": (shot_stutzen, 3),
    "bolt_cycle": (bolt_cycle, 1),
    "round_in": (round_in, 3),
    "shot_leucht": (shot_leucht, 1),
    "shot_pistole": (shot_pistole, 3),
    "shot_flinte": (shot_flinte, 4),
    "flinte_open": (flinte_open, 1),
    "flinte_close": (flinte_close, 1),
    "shell_in": (shell_in, 3),
    "dry_click_flinte": (dry_click_flinte, 1),
    "leucht_open": (leucht_open, 1),
    "leucht_close": (leucht_close, 1),
    "flare_in": (flare_in, 2),
    "slide_rack": (slide_rack, 1),
    "weapon_draw": (weapon_draw, 2),
}
