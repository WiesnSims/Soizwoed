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
    # The resonators ring at about 1 % of the impulse: bring it to full scale first (build.py
    # only ever turns sounds down), or every creak ends up at -60 dB.
    return d.normalize(out, 1.0) * level


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


# --- M4 creatures (non-speech) ---------------------------------------------------------------------

def tatzel_scrape(v):
    """The Tatzelwurm burrowing: grinding salt and scraping scales inside the rock (loop)."""
    s = 3.0
    grind = d.lowpass(d.brown(s), 260) * (0.6 + 0.4 * d.smooth_noise(s, 2.5))
    scrape = d.bandpass(d.noise(s), 700 + 150 * v, 3200) * np.maximum(0, d.smooth_noise(s, 3.0 + v)) * 0.5
    crumbs = d.mix(*[(d.rng.uniform(0, s - 0.1), click(2200 + d.rng.uniform(-600, 600), 0.01, 0.2)) for _ in range(14)])
    return d.loopable(d.mix(grind, scrape, crumbs), 0.3)


def tatzel_hiss(v):
    """A long, wet, cat-like hiss from a big throat."""
    s = 1.4 + 0.3 * v
    hiss = d.bandpass(d.noise(s), 1800, 8500) * d.env_points(s, [(0, 0), (0.08, 1), (s * 0.7, 0.8), (s, 0)])
    throat = d.vowel(d.glottal(d.glide(s, 95, 70), s, 0.04, 0.4), "a", 0.7) * d.env_points(s, [(0, 0), (0.1, 0.4), (s, 0)])
    return cave(d.mix(hiss * 0.8, throat * 0.35), 1.6, 0.35)


def tatzel_burst(v):
    """Bursting out of the rock: a crack, a slide of rubble, dust."""
    s = 1.8
    crack = d.mix(click(1600, 0.03, 1.0, ring=0.3), thud(55, 0.2, 1.0))
    slide = d.bandpass(d.noise(s), 400, 4000) * d.env_points(s, [(0, 0), (0.05, 1), (1.8, 0)])
    stones = d.mix(*[(d.rng.uniform(0.05, 1.4), thud(200 + d.rng.uniform(0, 300), 0.02, 0.4)) for _ in range(10)])
    return cave(d.mix(crack, slide * 0.5, stones), 2.0, 0.4)


def tatzel_bite(v):
    """Jaws snapping shut."""
    return cave(d.mix(thud(150, 0.03, 1.0), click(3000, 0.006, 0.9), d.bandpass(d.noise(0.3), 500, 3000) * d.env_exp(0.3, 0.04) * 0.6), 1.0, 0.25)


def meister_steps(v):
    """Heavy hobnailed boots, too fast for a living man."""
    s = 0.3
    return d.mix(thud(70 + 8 * v, 0.05, 1.0), click(2800 + 200 * v, 0.004, 0.5, ring=0.4), d.bandpass(d.noise(s), 600, 3000) * d.env_exp(s, 0.03) * 0.4)


def kaser_breath(v):
    """A cold breath right by your ear (the Kasermandl in the dark)."""
    s = 1.6
    breath = d.bandpass(d.noise(s), 500, 3500) * d.env_points(s, [(0, 0), (0.6, 0.8), (0.8, 1.0), (1.6, 0)])
    return cave(breath, 2.0, 0.45)


# --- M4 tools --------------------------------------------------------------------------------------

def alphorn(v):
    """The Alphorn: a huge wooden horn blowing a deafening open fifth."""
    s = 3.0
    env = d.env_points(s, [(0, 0), (0.12, 0.9), (0.3, 1.0), (2.4, 0.9), (3.0, 0)])
    vib = 1.0 + 0.006 * d.sine(4.5, s)
    tone = d.harmonics(116.5 * vib, s, [1.0, 0.9, 0.7, 0.55, 0.4, 0.3, 0.2, 0.12]) + 0.6 * d.harmonics(174.6 * vib, s, [1.0, 0.7, 0.5, 0.3, 0.2])
    breath = d.bandpass(d.noise(s), 600, 3000) * 0.08
    return d.echo(cave(d.drive((tone * 0.3 + breath) * env, 1.6), 2.6, 0.35), 0.5, 0.35, 3)


def boeller_fuse(v):
    """A lit fuse sputtering (loop)."""
    s = 1.0
    spits = d.mix(*[(d.rng.uniform(0, s - 0.02), click(4000 + d.rng.uniform(-1500, 1500), 0.003, d.rng.uniform(0.2, 0.7))) for _ in range(40)])
    fizz = d.bandpass(d.noise(s), 3000, 9000) * 0.25
    return d.loopable(d.mix(spits, fizz), 0.1)


def boeller_bang(v):
    """A firecracker going off in a tunnel."""
    s = 0.8
    bang = d.mix(d.lowpass(d.noise(s), 2500) * d.env_exp(s, 0.03), thud(70, 0.08, 1.0), click(3000, 0.004, 1.0))
    return d.echo(cave(d.drive(bang, 2.0), 2.4, 0.45), 0.3, 0.3, 3)


def explosion(v):
    """Firedamp going up: a deep blast, a pressure wave, rock coming down."""
    s = 3.5
    blast = d.lowpass(d.noise(s), 900) * d.env_points(s, [(0, 0), (0.01, 1), (0.4, 0.5), (3.5, 0)])
    boom = d.sine(d.glide(s, 60, 28), s) * d.env_exp(s, 0.6)
    debris = d.mix(*[(d.rng.uniform(0.3, 3.0), thud(150 + d.rng.uniform(0, 400), 0.03, 0.3)) for _ in range(24)])
    return cave(d.drive(d.mix(blast, boom, debris * 0.6), 2.5), 3.0, 0.45)


def gas_flare(v):
    """The carbide flame flaring up in firedamp: a rising, roaring whoosh."""
    s = 1.0
    roar = d.bandpass(d.noise(s), 300, 3000) * d.env_points(s, [(0, 0), (0.6, 0.7), (1.0, 1.0)])
    return d.mix(roar, d.lowpass(d.brown(s), 200) * 0.4)


def smoke_puff(v):
    """The "Bierzelt" bomb: a pop and a long hissing cloud."""
    s = 2.5
    hiss = d.bandpass(d.noise(s), 1500, 7000) * d.env_points(s, [(0, 0), (0.1, 1), (2.5, 0)])
    return cave(d.mix(click(900, 0.02, 0.8), hiss * 0.5), 1.4, 0.3)


def eat(v):
    """Biting into a Leberkässemmel: crunch, chew, chew."""
    s = 1.2
    bites = d.mix(*[(i * 0.35, d.bandpass(d.noise(0.15), 1500, 6000) * d.env_exp(0.15, 0.03)) for i in range(3)])
    return d.mix(bites * 0.6, thud(200, 0.03, 0.3))


def drink(v):
    """A pull from a schnapps bottle: gulp gulp, and a satisfied "ah"."""
    s = 1.4
    gulps = d.mix(*[(0.1 + i * 0.32, d.sine(d.glide(0.12, 300, 180), 0.12) * d.env_exp(0.12, 0.04)) for i in range(3)])
    ah = d.vowel(d.glottal(d.glide(0.4, 160, 120), 0.4), "a") * d.env_points(0.4, [(0, 0), (0.05, 0.6), (0.4, 0)])
    return d.mix(gulps, (1.0, ah * 0.5))


def pfeiferl(v):
    """The Grubenhund whistle: a shrill two-note trill."""
    s = 1.2
    f = np.where(np.arange(d.n_of(s)) % d.n_of(0.12) < d.n_of(0.06), 2900, 3400)
    tone = d.sine(f, s) * d.env_points(s, [(0, 0), (0.03, 1), (1.0, 1), (1.2, 0)])
    return cave(d.mix(tone * 0.5, d.bandpass(d.noise(s), 2000, 6000) * 0.1), 1.6, 0.35)


def rope(v):
    """A rope thrown down and an iron hook biting into rock."""
    s = 0.9
    whoosh = d.bandpass(d.pink(s), 300, 2500) * d.env_points(s, [(0, 0), (0.3, 1), (0.6, 0)])
    return d.mix(whoosh * 0.5, (0.55, click(2600, 0.008, 0.8, ring=0.6)))


def radio_static(v):
    """Funkgerät static (loop)."""
    s = 2.0
    crackle = d.mix(*[(d.rng.uniform(0, s - 0.02), click(3000 + d.rng.uniform(-1000, 2000), 0.002, d.rng.uniform(0.1, 0.5))) for _ in range(60)])
    return d.loopable(d.mix(d.bandpass(d.noise(s), 800, 5000) * 0.35 * (0.6 + 0.4 * d.smooth_noise(s, 6.0)), crackle), 0.2)


def wall_break(v):
    """A salt wall giving way under the pick."""
    s = 1.8
    return cave(d.mix(click(1800, 0.04, 1.0, ring=0.5), thud(65, 0.15, 1.0),
                      d.mix(*[(d.rng.uniform(0.05, 1.2), thud(220 + d.rng.uniform(0, 500), 0.02, 0.4)) for _ in range(14)])), 2.0, 0.4)


# --- M4 hazards and the lake -----------------------------------------------------------------------

def rockfall_warn(v):
    """Rock creaking and grit trickling from the roof: get out from under it."""
    s = 2.4
    groan = stick_slip(s, 14 + 8 * d.smooth_noise(s, 1.0), [(180, 10, 1.0), (430, 12, 0.6), (900, 14, 0.3)], 0.5)
    trickle = d.bandpass(d.noise(s), 2500, 8000) * np.maximum(0, d.smooth_noise(s, 4.0)) * 0.3
    x = d.mix(groan, trickle)
    env = d.env_points(s, [(0, 0), (0.4, 0.8), (s, 1.0)])
    n = min(len(x), len(env))
    return cave(x[:n] * env[:n], 1.8, 0.35)


def rockfall(v):
    """Rock crashing down from the roof."""
    s = 2.6
    crash = d.lowpass(d.noise(s), 1500) * d.env_points(s, [(0, 0), (0.02, 1), (2.6, 0)])
    stones = d.mix(*[(d.rng.uniform(0, 2.0), thud(120 + d.rng.uniform(0, 500), 0.03, 0.6)) for _ in range(20)])
    return cave(d.drive(d.mix(crash * 0.6, stones, thud(45, 0.3, 1.0)), 1.6), 2.4, 0.4)


def plank_crack(v):
    """Rotten wood splintering and giving way."""
    s = 1.0
    splinter = stick_slip(0.6, 120, WOOD, 1.0)
    return cave(d.mix(splinter, (0.35, click(1300, 0.03, 1.0, ring=0.4)), (0.4, thud(110, 0.06, 0.8))), 1.4, 0.3)


def plank_creak(v):
    """A rotten plank or rung complaining under a foot."""
    s = 0.9
    return cave(stick_slip(s, 30 + 15 * v, WOOD, 0.5) * d.env_points(s, [(0, 0), (0.2, 1), (s, 0)]), 1.2, 0.3)


def splash(v):
    """Something heavy going into deep brine."""
    s = 1.4
    body = d.lowpass(d.noise(s), 2500) * d.env_points(s, [(0, 0), (0.02, 1), (0.5, 0.3), (1.4, 0)])
    drops = d.mix(*[(d.rng.uniform(0.1, 1.0), d.sine(d.glide(0.08, 900, 1700), 0.08) * d.env_exp(0.08, 0.02) * 0.4) for _ in range(10)])
    return cave(d.mix(body, thud(90, 0.08, 0.7), drops), 2.0, 0.4)


def wade(v):
    """A boot sloshing through ankle-deep brine."""
    s = 0.35
    return d.mix(d.bandpass(d.noise(s), 400, 3000) * d.env_points(s, [(0, 0), (0.05, 1), (0.35, 0)]) * 0.6, thud(140, 0.03, 0.4))


def gurgle(v):
    """Something under the water, close: bubbles and a wet grunt."""
    s = 1.8
    bubbles = d.mix(*[(d.rng.uniform(0, 1.5), d.sine(d.glide(0.06, 300, 700), 0.06) * d.env_exp(0.06, 0.02)) for _ in range(18)])
    grunt = d.lowpass(d.glottal(d.glide(s, 70, 50), s, 0.08, 0.5), 600) * d.env_points(s, [(0, 0), (0.6, 0.8), (s, 0)])
    return cave(d.mix(bubbles * 0.5, grunt * 0.5), 1.8, 0.4)


def ferry_bell(v):
    """The bell at the landing: "Hol über!" – a bright little bronze bell rung three times."""
    parts = lambda: [(1250, 1.0, 1.0), (2980, 0.5, 0.6), (4500, 0.25, 0.3)]
    return cave(d.mix(*[(i * 0.5, d.partials(1.4, parts())) for i in range(3)]), 3.0, 0.45)


def row(v):
    """An oar dipping and pulling, the boat creaking (loop)."""
    s = 2.0
    strokes = d.mix(*[(i * 1.0, d.bandpass(d.noise(0.5), 300, 2000) * d.env_points(0.5, [(0, 0), (0.1, 1), (0.5, 0)])) for i in range(2)])
    creak_ = stick_slip(s, 20 + 8 * d.smooth_noise(s, 1.0), WOOD, 0.15)
    return d.loopable(d.mix(strokes * 0.5, creak_), 0.2)


# --- M5: Percht, Salzweibl, loot, emotes, Die Tiefe ------------------------------------------------

def cowbell(freq, seconds, level=1.0):
    """One dented cowbell clonk: an inharmonic, quickly dying metal ring."""
    ring = d.partials(seconds, [(freq, 1.0, 0.18), (freq * 1.48, 0.7, 0.12), (freq * 2.13, 0.45, 0.07), (freq * 3.4, 0.25, 0.04)])
    return d.mix(ring, click(freq * 2.5, 0.004, 0.4)) * level


def percht_bells(v):
    """The Percht's belt of cowbells swinging as it walks (loop): uneven clonks, never in step."""
    s = 4.0
    hits = []
    t = 0.0
    while t < s - 0.3:
        hits.append((t, cowbell(d.rng.choice([330, 392, 440, 523, 587]) * d.rng.uniform(0.98, 1.02), 0.6, d.rng.uniform(0.35, 1.0))))
        t += d.rng.uniform(0.09, 0.28)
    jangle = d.bandpass(d.noise(s), 2500, 8000) * (0.5 + 0.5 * d.smooth_noise(s, 3.0)) * 0.04
    return d.loopable(cave(d.mix(*hits, jangle), 1.4, 0.3)[: d.n_of(s)], 0.3)


def percht_steps(v):
    """A heavy, fur-wrapped foot: a deep thud and a shake of bells."""
    s = 0.6
    return d.mix(thud(48 + 6 * v, 0.09, 1.0), d.lowpass(d.noise(s), 400) * d.env_exp(s, 0.06) * 0.4,
                 (0.03, cowbell(440 + 60 * v, 0.4, 0.3)))


def percht_roar(v):
    """A bellow from behind the wooden mask: deep, rough and close."""
    s = 1.8
    voice = d.vowel_morph(d.glottal(d.glide(s, 70, 52), s, 0.08, 0.5), [(0.0, "o"), (0.6, "a"), (1.8, "u")], 0.75)
    rasp = d.bandpass(d.noise(s), 300, 2500) * 0.4
    env = d.env_points(s, [(0, 0), (0.08, 1.0), (1.2, 0.8), (1.8, 0)])
    return cave(d.drive((voice + rasp) * env, 2.5), 2.0, 0.4)


def salzweibl_shriek(v):
    """The salt woman's shriek: a high, thin scream that cracks into hiss."""
    s = 1.3
    scream = d.vowel(d.glottal(d.glide(s, 900, 1300, 0.5) * (1 + 0.03 * d.sine(9, s)), s, 0.05, 0.3), "i", 1.6)
    hiss = d.bandpass(d.noise(s), 3000, 9000) * d.env_points(s, [(0, 0), (0.6, 0.2), (1.3, 0.7)])
    env = d.env_points(s, [(0, 0), (0.05, 1.0), (0.8, 0.7), (1.3, 0)])
    return cave(d.mix(scream * env, hiss * 0.5), 2.2, 0.45)


def salzweibl_hum(v):
    """Her humming close by in the dark: a wavering lullaby with the mouth shut."""
    notes = [(0.0, 392), (0.5, 440), (1.0, 392), (1.5, 349), (2.2, 330)]
    s = 3.0
    f = np.full(d.n_of(s), 392.0)
    t = np.arange(len(f)) / d.SR
    for start, freq in notes:
        f[t >= start] = freq
    f = d.lowpass(f, 8.0) * (1 + 0.012 * d.sine(5.0, s))
    voice = d.vowel(d.glottal(f, s, 0.02, 0.2), "m", 1.3)
    return cave(voice * d.env_points(s, [(0, 0), (0.3, 1.0), (2.5, 0.8), (3.0, 0)]), 2.4, 0.5)


def cuckoo(v):
    """A cuckoo clock in the dark: two wooden whistle notes, twice, and the click of its door."""
    def note(freq, s=0.28):
        return d.sine(freq * (1 + 0.004 * d.sine(6, s)), s) * d.env_points(s, [(0, 0), (0.02, 1), (0.2, 0.7), (s, 0)])
    calls = []
    for i in range(2):
        calls += [(0.15 + i * 0.75, note(784)), (0.45 + i * 0.75, note(659, 0.36))]
    door = [(0.02, click(1800, 0.01, 0.6)), (1.75, click(1600, 0.01, 0.5))]
    return cave(d.mix(*calls, *door) * 0.8, 1.4, 0.3)


def curse_whisper(v):
    """Something old murmuring from the salt lump you carry: breathy, wordless, very close."""
    s = 2.2
    breath = d.bandpass(d.noise(s), 600, 4500)
    words = np.maximum(0, d.smooth_noise(s, 9.0)) ** 2
    shaped = d.vowel_morph(breath, [(0.0, "u"), (0.7, "a"), (1.4, "i"), (2.2, "o")], 0.9)
    return d.normalize(cave(shaped * words * d.env_points(s, [(0, 0), (0.3, 1), (1.9, 1), (2.2, 0)]), 1.8, 0.45), 0.6)


def jodler(v):
    """A miner's yodel: chest voice and falsetto flipping back and forth (heard far)."""
    tune = [(0.0, 220, "o"), (0.35, 330, "a"), (0.6, 440, "i"), (0.85, 330, "o"), (1.1, 440, "i"), (1.35, 554, "i"), (1.7, 440, "o"), (2.1, 330, "u")]
    s = 2.6
    f = np.full(d.n_of(s), 220.0)
    t = np.arange(len(f)) / d.SR
    for start, freq, _ in tune:
        f[t >= start] = freq * (0.98 + 0.04 * v)
    f = d.lowpass(f, 25.0) * (1 + 0.01 * d.sine(5.5, s))
    voice = d.vowel_morph(d.glottal(f, s, 0.02, 0.15), [(start, vow) for start, _, vow in tune], 1.0)
    env = d.env_points(s, [(0, 0), (0.05, 1.0), (2.2, 0.9), (2.6, 0)])
    return d.echo(cave(d.drive(voice * env, 1.3), 2.4, 0.35), 0.45, 0.35, 3)


def footstep_salt(v):
    """A boot on rock salt: a sharp, glassy crunch over a firm thump."""
    s = 0.2
    crunch = d.bandpass(d.noise(s), 2500 + 300 * (v % 3), 9000) * d.env_exp(s, 0.02 + 0.005 * (v % 2))
    ticks = d.mix(*[(d.rng.uniform(0, 0.05), click(4500 + d.rng.uniform(-1000, 1500), 0.002, d.rng.uniform(0.2, 0.6))) for _ in range(8)])
    return d.mix(thud(110 + 10 * v, 0.02, 0.8), crunch * 0.5, ticks * 0.5)


def deep_groan(v):
    """The deep rock groaning under its own weight, far below."""
    s = 5.0
    groan = d.lowpass(d.glottal(d.glide(s, 38 + 6 * v, 30), s, 0.15, 0.6), 220)
    env = d.env_points(s, [(0, 0), (1.5, 0.8), (3.0, 1.0), (5.0, 0)])
    return cave(d.mix(groan * env, d.lowpass(d.brown(s), 70) * env * 0.5), 3.0, 0.5)


def stone_settle(v):
    """A few pebbles trickling somewhere in the dark."""
    s = 1.6
    pebbles = d.mix(*[(0.1 + i * d.rng.uniform(0.08, 0.25), click(2200 + d.rng.uniform(-800, 800), 0.012, d.rng.uniform(0.2, 0.6))) for i in range(6)])
    return d.normalize(cave(pebbles, 2.0, 0.5), 0.7)


def water_lap(v):
    """Brine lapping against the rock of a lake shore."""
    s = 2.5
    laps = d.mix(*[(i * 0.8 + d.rng.uniform(0, 0.2), d.bandpass(d.noise(0.6), 250, 1500) * d.env_points(0.6, [(0, 0), (0.15, 1), (0.6, 0)])) for i in range(3)])
    return cave(laps * 0.6, 1.8, 0.45)


SOUNDS = {
    "percht_bells": (percht_bells, 1),
    "percht_steps": (percht_steps, 3),
    "percht_roar": (percht_roar, 1),
    "salzweibl_shriek": (salzweibl_shriek, 1),
    "salzweibl_hum": (salzweibl_hum, 1),
    "cuckoo": (cuckoo, 1),
    "curse_whisper": (curse_whisper, 2),
    "jodler": (jodler, 2),
    "footstep_salt": (footstep_salt, 5),
    "deep_groan": (deep_groan, 2),
    "stone_settle": (stone_settle, 2),
    "water_lap": (water_lap, 2),
    "tatzel_scrape": (tatzel_scrape, 1),
    "tatzel_hiss": (tatzel_hiss, 2),
    "tatzel_burst": (tatzel_burst, 1),
    "tatzel_bite": (tatzel_bite, 1),
    "meister_steps": (meister_steps, 3),
    "kaser_breath": (kaser_breath, 1),
    "alphorn": (alphorn, 1),
    "boeller_fuse": (boeller_fuse, 1),
    "boeller_bang": (boeller_bang, 1),
    "explosion": (explosion, 1),
    "gas_flare": (gas_flare, 1),
    "smoke_puff": (smoke_puff, 1),
    "eat": (eat, 1),
    "drink": (drink, 1),
    "pfeiferl": (pfeiferl, 1),
    "rope": (rope, 1),
    "radio_static": (radio_static, 1),
    "wall_break": (wall_break, 1),
    "rockfall_warn": (rockfall_warn, 1),
    "rockfall": (rockfall, 1),
    "plank_crack": (plank_crack, 1),
    "plank_creak": (plank_creak, 2),
    "splash": (splash, 1),
    "wade": (wade, 3),
    "gurgle": (gurgle, 1),
    "ferry_bell": (ferry_bell, 1),
    "row": (row, 1),
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
LOOPS = {"percht_bells", "lamp_hiss", "lift_motor", "cart_rattle", "tatzel_scrape", "boeller_fuse", "radio_static", "row"}
AMBIENCE = {"drip", "creak", "rumble", "deep_groan", "stone_settle", "water_lap"}
