"""Sound-effect recipes of Soizwöd. Each takes a variant number (0, 1, ...) and returns a mono
signal. Building blocks (click, thud, stick_slip, voice) follow Berghittn's tools/audio/sfx.py."""
import numpy as np

import dsp as d


# --- building blocks -------------------------------------------------------------------------------

def click(freq: float, decay: float = 0.006, level: float = 1.0, ring: float = 0.0):
    n = d.noise(decay * 6)
    x = d.bandpass(n, freq * 0.6, min(freq * 1.6, 20000)) * d.env_exp(decay * 6, decay)
    if ring > 0:
        ping = d.partials(0.25, [(freq * 1.3, 0.3, 0.05), (freq * 2.1, 0.2, 0.03)])
        x = d.mix(x, ping * ring)
    return x * level


def thud(freq: float, decay: float, level: float = 1.0):
    s = decay * 6
    body = d.sine(d.glide(s, freq, freq * 0.6), s) * d.env_exp(s, decay)
    puff = d.lowpass(d.noise(s), freq * 4) * d.env_exp(s, decay * 0.5) * 0.4
    return (body + puff) * level


def stick_slip(length: float, rate, bodies, level: float = 1.0):
    """Wood creak: a train of tiny slips ringing wooden resonances."""
    p = d.phase(rate, length)
    impulses = np.zeros_like(p)
    idx = np.nonzero(np.diff(np.floor(p)) > 0)[0]
    impulses[idx] = d.rng.uniform(0.5, 1.0, len(idx))
    out = np.zeros_like(p)
    for f, q, g in bodies:
        out += g * d.resonator(impulses, f, q)
    return out * level


WOOD = [(310, 12, 1.0), (720, 14, 0.7), (1330, 16, 0.45), (2250, 18, 0.25)]


def cave(x, seconds=1.6, wet=0.3):
    """The mine's room sound: a dark, longish tail."""
    return d.reverb(x, seconds, wet, damp=3200.0, pre=0.02)


# --- player ----------------------------------------------------------------------------------------

def footstep_gravel(v):
    """Boot on dirt and grit: a soft low thump and a short crunch."""
    s = 0.22
    crunch = d.bandpass(d.noise(s), 900 + 300 * (v % 3), 5200) * d.env_exp(s, 0.03 + 0.008 * (v % 2))
    grains = np.zeros(d.n_of(s))
    for _ in range(14):
        i = int(d.rng.uniform(0, 0.06) * d.SR)
        grains[i:i + 40] += d.rng.uniform(-1, 1, len(grains[i:i + 40])) * d.rng.uniform(0.3, 1.0)
    grains = d.highpass(grains, 2000)
    low = thud(95 + 12 * v, 0.025, 0.9)
    return d.mix(low, crunch * 0.55, grains * 0.35)


def footstep_wood(v):
    s = 0.25
    knock = thud(140 + 15 * v, 0.03, 1.0)
    body = stick_slip(0.12, 220 + 40 * v, WOOD, 0.2)
    return d.mix(knock, body, d.bandpass(d.noise(s), 400, 2500) * d.env_exp(s, 0.02) * 0.3)


def pickup(v):
    s = 0.25
    rustle = d.bandpass(d.noise(s), 1200, 6000) * d.env_points(s, [(0, 0), (0.03, 1), (0.12, 0.4), (0.25, 0)])
    return d.mix(rustle * 0.6, click(2600 + 300 * v, 0.004, 0.5))


def drop_thud(v):
    return d.mix(thud(80 + 20 * v, 0.05, 1.0), d.bandpass(d.noise(0.2), 300, 3000) * d.env_exp(0.2, 0.02) * 0.4)


def glass_clink(v):
    parts = [(2400 + 180 * v, 0.6, 0.25), (3720 + 200 * v, 0.35, 0.18), (5230, 0.25, 0.1), (6900, 0.15, 0.06)]
    return d.mix(d.partials(0.7, parts), click(5000, 0.002, 0.7))


def watschn(v):
    """An open-handed slap: a sharp, fleshy smack."""
    s = 0.18
    smack = d.bandpass(d.noise(s), 700, 7000) * d.env_exp(s, 0.012 + 0.003 * v)
    return d.mix(smack, thud(180, 0.012, 0.6))


def pick_hit(v):
    """Pickaxe on something soft (or a gnome): a dull thunk with a metal edge."""
    return d.mix(thud(120 + 15 * v, 0.04, 1.0), click(3100, 0.006, 0.6, ring=0.5))


def swing(v):
    s = 0.3
    n = d.pink(s)
    t = np.linspace(0, 1, len(n))
    shape = np.sin(np.pi * t) ** 2
    return d.bandpass(n, 500 + 100 * v, 3000) * shape * 0.8


def cart_rattle(v):
    """An iron-rimmed wheel crunching over grit, the tray rattling (loop)."""
    s = 2.0
    crunch = d.bandpass(d.noise(s), 600, 4000) * (0.6 + 0.4 * d.smooth_noise(s, 9.0))
    p = d.phase(6.0 + d.smooth_noise(s, 1.0), s)
    impulses = np.zeros(d.n_of(s))
    idx = np.nonzero(np.diff(np.floor(p)) > 0)[0]
    impulses[idx] = d.rng.uniform(0.2, 1.0, len(idx))
    clank = d.resonator(impulses, 900, 8) * 0.5 + d.resonator(impulses, 2300, 12) * 0.25
    squeak = d.sine(1900 + 150 * d.smooth_noise(s, 2.0), s) * np.maximum(0, d.smooth_noise(s, 1.3)) * 0.08
    return d.loopable(d.mix(crunch * 0.35, clank, squeak), 0.2)


def lamp_click(v):
    return d.mix(click(1800, 0.004, 0.8), click(900, 0.006, 0.4))


def lamp_hiss(v):
    """Carbide flame: a soft gas hiss with a slow flutter (loop)."""
    s = 3.0
    hiss = d.bandpass(d.noise(s), 2500, 9000) * (0.75 + 0.25 * d.smooth_noise(s, 4.0))
    roar = d.lowpass(d.brown(s), 180) * 0.25
    return d.loopable(d.mix(hiss * 0.5, roar), 0.25)


def lamp_refill(v):
    """Water dripping onto carbide, then the hiss coming back up."""
    s = 1.2
    fizz = d.bandpass(d.noise(s), 3000, 10000) * d.env_points(s, [(0, 0), (0.2, 0.9), (1.0, 0.4), (1.2, 0)])
    drips = d.mix(*[(0.05 + i * 0.12, thud(900 + 120 * i, 0.01, 0.35)) for i in range(4)])
    return d.mix(fizz * 0.5, drips)


def karbid_open(v):
    return d.mix(click(1200, 0.01, 0.8, ring=0.6), (0.08, click(800, 0.02, 0.5)))


# --- the lift and the shift ------------------------------------------------------------------------

def grubenpfeife(v):
    """The shift whistle: a steam whistle chord, swelling and dying, with the shaft's echo."""
    s = 3.2
    env = d.env_points(s, [(0, 0), (0.15, 0.8), (0.4, 1.0), (2.4, 0.9), (3.2, 0)])
    vib = 1.0 + 0.004 * d.sine(5.5, s)
    tone = sum(d.harmonics(f * vib, s, [1, 0.5, 0.3, 0.15, 0.08]) * g for f, g in [(392, 1.0), (494, 0.8), (587, 0.6)])
    steam = d.bandpass(d.noise(s), 1500, 7000) * 0.25
    x = d.drive((tone * 0.4 + steam) * env, 1.4)
    return d.echo(cave(x, 2.5, 0.35), 0.45, 0.35, 3)


def schacht_signal(v):
    """The shaft signal bell: hammer strikes on a heavy iron bell (v+1 strikes)."""
    parts = lambda: [(620, 1.0, 1.2), (1480, 0.5, 0.6), (2390, 0.3, 0.35), (3410, 0.15, 0.2)]
    strikes = [(i * 0.45, d.mix(d.partials(1.6, parts()), click(3500, 0.003, 0.6))) for i in range(v + 1)]
    return cave(d.mix(*strikes), 1.8, 0.3)


def lift_motor(v):
    """The winding engine heard down the shaft: hum, rattling chain, creaking cage (loop)."""
    s = 4.0
    hum = d.harmonics(50, s, [1, 0.6, 0.35, 0.2]) * 0.3
    rumble = d.lowpass(d.brown(s), 120) * 0.6
    rattle_phase = d.phase(9.0, s)
    impulses = np.zeros(d.n_of(s))
    idx = np.nonzero(np.diff(np.floor(rattle_phase)) > 0)[0]
    impulses[idx] = d.rng.uniform(0.3, 1.0, len(idx))
    rattle = d.resonator(impulses, 1700, 10) * 0.25 + d.resonator(impulses, 3100, 14) * 0.12
    creak = stick_slip(s, 30 + 10 * d.smooth_noise(s, 0.6), WOOD, 0.06)
    return d.loopable(d.mix(hum, rumble, rattle, creak), 0.3)


def lift_stop(v):
    return cave(d.mix(thud(60, 0.12, 1.0), click(2200, 0.02, 0.6, ring=0.8), (0.12, thud(90, 0.05, 0.5))), 1.4, 0.3)


def lever(v):
    return d.mix(click(900, 0.02, 0.8, ring=0.4), (0.15, thud(140, 0.03, 0.8)), (0.16, click(2600, 0.005, 0.5)))


def sell(v):
    """Coins counted onto a wooden counter."""
    coins = [(i * 0.07 + d.rng.uniform(0, 0.02), d.partials(0.4, [(3200 + d.rng.uniform(-300, 300), 0.5, 0.12),
                                                                 (5100 + d.rng.uniform(-400, 400), 0.3, 0.08)])) for i in range(7)]
    return d.mix(*coins)


def ui_click(v):
    return click(2000 + 400 * v, 0.003, 0.6)


# --- mine ambience ---------------------------------------------------------------------------------

def drip(v):
    """A brine drop into a puddle: a pitched plip with a cave tail."""
    s = 0.25
    f0 = 1300 + 260 * v
    plip = d.sine(d.glide(s, f0 * 0.7, f0 * 1.6, 0.5), s) * d.env_exp(s, 0.03, 0.002)
    return cave(plip * 0.6, 1.4, 0.45)


def creak(v):
    s = 1.6 + 0.4 * (v % 2)
    rate = 18 + 22 * (0.5 + 0.5 * d.smooth_noise(s, 1.5))
    return cave(stick_slip(s, rate, WOOD, 0.6) * d.env_points(s, [(0, 0), (0.2, 1), (s - 0.3, 0.8), (s, 0)]), 1.5, 0.3)


def rumble(v):
    """Something heavy settling far away in the rock."""
    s = 4.0
    x = d.lowpass(d.brown(s), 90) * d.env_points(s, [(0, 0), (0.8, 1), (2.5, 0.6), (4.0, 0)])
    pebbles = d.mix(*[(1.0 + i * 0.3 + d.rng.uniform(0, 0.2), click(2500, 0.01, 0.15)) for i in range(4)])
    return cave(d.mix(x, pebbles), 2.5, 0.4)


# --- creatures (non-speech) ------------------------------------------------------------------------

def mandl_steps(v):
    """Quick little bare feet pattering on grit."""
    s = 0.12
    return d.mix(d.bandpass(d.noise(s), 1800, 7000) * d.env_exp(s, 0.012) * 0.6, thud(260, 0.01, 0.3))


def poof(v):
    """A Bergmandl vanishing: a puff of dust and a tiny pop."""
    s = 0.7
    puff = d.lowpass(d.noise(s), 1800) * d.env_points(s, [(0, 0), (0.03, 1), (0.7, 0)])
    return cave(d.mix(puff * 0.7, click(1500, 0.01, 0.6)), 1.2, 0.3)


SOUNDS = {
    "footstep_gravel": (footstep_gravel, 6),
    "footstep_wood": (footstep_wood, 4),
    "pickup": (pickup, 3),
    "drop_thud": (drop_thud, 3),
    "glass_clink": (glass_clink, 1),
    "watschn": (watschn, 2),
    "pick_hit": (pick_hit, 2),
    "swing": (swing, 2),
    "cart_rattle": (cart_rattle, 1),
    "lamp_click": (lamp_click, 1),
    "lamp_hiss": (lamp_hiss, 1),
    "lamp_refill": (lamp_refill, 1),
    "karbid_open": (karbid_open, 1),
    "grubenpfeife": (grubenpfeife, 1),
    "schacht_signal": (schacht_signal, 3),
    "lift_motor": (lift_motor, 1),
    "lift_stop": (lift_stop, 1),
    "lever": (lever, 1),
    "sell": (sell, 1),
    "ui_click": (ui_click, 1),
    "drip": (drip, 4),
    "creak": (creak, 3),
    "rumble": (rumble, 2),
    "mandl_steps": (mandl_steps, 3),
    "poof": (poof, 1),
}
LOOPS = {"lamp_hiss", "lift_motor", "cart_rattle"}
AMBIENCE = {"drip", "creak", "rumble"}
