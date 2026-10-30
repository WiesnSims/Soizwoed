"""Creature voice lines (DESIGN.md §6 "Creature voices") and the players' shouts (Plärren).

Every line is spoken by eSpeak NG and run through a filter per creature voice. eSpeak NG (GPL-3)
is only a tool on the dev machine, never shipped; the audio it makes is ours.
    winget install --id eSpeak-NG.eSpeak-NG -e      (or set ESPEAK to the espeak-ng executable)

Each creature has several voice variants for the user's sample check; CHOICE says which one
the game uses. `python tools/audio/build.py --samples` writes every variant to build/samples/.
The approach (eSpeak + vocoder/rasp filters) follows Berghittn's tools/audio/voices.py."""
import os
import shutil
import subprocess
import tempfile

import numpy as np
import soundfile as sf
from scipy import signal

import dsp as d
import sfx

SR = d.SR


def espeak() -> str:
    for path in (os.environ.get("ESPEAK", ""), shutil.which("espeak-ng") or "",
                 "C:/Program Files/eSpeak NG/espeak-ng.exe", "C:/Program Files (x86)/eSpeak NG/espeak-ng.exe"):
        if path and os.path.isfile(path):
            return path
    return ""


def speak(text, voice, speed, pitch, gap=0):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    try:
        subprocess.run([espeak(), "-v", voice, "-s", str(speed), "-p", str(pitch), "-g", str(gap), "-w", path, text],
                       check=True, capture_output=True)
        x, sr = sf.read(path)
    finally:
        os.remove(path)
    if x.ndim > 1:
        x = x.mean(axis=1)
    return x, sr


def at_pitch(x, sr, factor):
    """Resampled to SR so it plays `factor` x higher (and faster)."""
    return signal.resample(x, int(round(len(x) * SR / sr / factor)))


def envelope(x, cutoff=30.0):
    return d.lowpass(np.abs(x), cutoff)


def rasp(x, amount):
    env = np.maximum(envelope(x, 25.0), 0)
    return x + d.bandpass(d.noise(len(x) / SR), 900, 5000) * env * amount


def finish(x, room=0.3, seconds=1.4):
    """Normalised, trimmed, with the mine's dark room tail."""
    x = d.reverb(d.normalize(x), seconds, room, damp=3500.0, pre=0.015)
    return d.fade(d.normalize(d.trim(x), 0.85), 0.005, 0.05)


# --- Bergmandl: three voices for the sample check ---------------------------------------------------

def mandl_a(text):
    """A: Kobold – quick, high and bright, a giggly wobble, clean."""
    x, sr = speak(text, "de+m4", 175, 78)
    x = at_pitch(x, sr, 1.32)
    t = np.arange(len(x)) / SR
    x = d.normalize(x) * (1.0 + 0.2 * np.sin(2 * np.pi * 7.0 * t))
    return finish(d.bandpass(d.drive(x, 1.3), 220, 7500), 0.28)


def mandl_b(text):
    """B: Oids Mandl – an old, raspy little man, nasal, a bit gruff."""
    x, sr = speak(text, "de+m2", 150, 62)
    x = at_pitch(x, sr, 1.18)
    x = d.drive(d.normalize(rasp(x, 0.45)), 1.9)
    x = d.bandpass(x, 300, 5200) + 0.4 * d.resonator(x, 1400, 4)
    return finish(x, 0.3)


def mandl_c(text):
    """C: Wisperl – half whispered, half voiced, sly and close, like it is right behind you."""
    voiced, sr = speak(text, "de+m4", 160, 70)
    whisper, sr2 = speak(text, "de+whisper", 160, 70)
    voiced = d.normalize(at_pitch(voiced, sr, 1.25))
    whisper = d.normalize(at_pitch(whisper, sr2, 1.25))
    n = min(len(voiced), len(whisper))
    x = 0.45 * voiced[:n] + 0.8 * whisper[:n]
    return finish(d.highpass(x, 180), 0.22, 1.1)


MANDL_VARIANTS = {"A": mandl_a, "B": mandl_b, "C": mandl_c}


def tremolo(x, rate, depth):
    t = np.arange(len(x)) / SR
    return x * (1.0 + depth * np.sin(2 * np.pi * rate * t))


def layered(a, b, gain_a=1.0, gain_b=1.0):
    n = min(len(a), len(b))
    return gain_a * d.normalize(a[:n]) + gain_b * d.normalize(b[:n])


# --- Kasermandl: an old herder's ghost, heard only in the dark ----------------------------------------

def kaser_a(text):
    """A: Hauch – a slow, breathy whisper right next to you, long cold tail."""
    x, sr = speak(text, "de+whisper", 115, 38, 4)
    x = tremolo(at_pitch(x, sr, 0.92), 4.0, 0.15)
    return finish(d.highpass(x, 160), 0.4, 1.6)


def kaser_b(text):
    """B: Oida Hirt – a croaky old man, half voice, half breath, shaking."""
    voiced, sr = speak(text, "de+croak", 115, 28, 3)
    whisper, sr2 = speak(text, "de+whisper", 115, 28, 3)
    x = layered(rasp(at_pitch(voiced, sr, 0.86), 0.6), at_pitch(whisper, sr2, 0.86), 0.7, 0.6)
    x = tremolo(d.bandpass(x, 200, 4500), 5.5, 0.25)
    return finish(x, 0.32, 1.3)


def kaser_c(text):
    """C: Geist – a hollow chorus of whispers, slightly out of tune with itself, far away."""
    whisper, sr = speak(text, "de+whisper", 125, 45, 2)
    voiced, sr2 = speak(text, "de+m7", 125, 45, 2)
    low = at_pitch(voiced, sr2, 0.8)
    x = layered(at_pitch(whisper, sr, 1.0), low, 0.9, 0.35)
    x = layered(x, at_pitch(whisper, sr, 1.015), 1.0, 0.5)
    return finish(d.bandpass(x, 250, 6000), 0.45, 1.9)


KASER_VARIANTS = {"A": kaser_a, "B": kaser_b, "C": kaser_c}

KASERMANDL_LINES = {
    "spot_kimm": ("SPOT", "Kimm her. Kimm zu mir."),
    "spot_siag": ("SPOT", "I siag di."),
    "idle_koid": ("IDLE", "I friar so. So koid is do herunt."),
    "idle_kua": ("IDLE", "Wo is denn mei Kua?"),
    "idle_liacht": ("IDLE", "Mach's Liacht aus, Bua."),
    "strike_hob": ("ACTION", "Hob di!"),
    "strike_mei": ("ACTION", "Jetzt bist mei."),
    "hit_spuer": ("HIT", "Hehe. Des spür i ned."),
}


# --- Schichtmeister: the dead foreman, after the whistle --------------------------------------------

def meister_a(text):
    """A: Kommandant – a deep, booming barking voice filling the tunnels."""
    x, sr = speak(text, "de+m3", 140, 22)
    x = d.drive(d.normalize(at_pitch(x, sr, 0.82)), 2.0)
    return d.echo(finish(d.bandpass(x, 80, 6000), 0.32, 1.6), 0.3, 0.25, 2)


def meister_b(text):
    """B: Geisterstimme – the same bark doubled an octave down, dead and hollow."""
    x, sr = speak(text, "de+m1", 135, 20)
    x = layered(at_pitch(x, sr, 0.8), at_pitch(x, sr, 0.5), 1.0, 0.45)
    x = layered(x, at_pitch(*speak(text, "de+m1", 135, 20), 0.81), 1.0, 0.5)
    return finish(d.lowpass(d.drive(x, 1.5), 5000), 0.4, 1.9)


def meister_c(text):
    """C: Megafon – shouted through an old tin funnel, nasal, with the shaft's echo."""
    x, sr = speak(text, "de+m3", 150, 30)
    x = d.drive(d.normalize(at_pitch(x, sr, 0.9)), 3.0)
    x = d.bandpass(x, 380, 3300) + 0.5 * d.resonator(x, 1100, 5)
    return d.echo(finish(x, 0.25, 1.2), 0.38, 0.3, 2)


MEISTER_VARIANTS = {"A": meister_a, "B": meister_b, "C": meister_c}

SCHICHTMEISTER_LINES = {
    "appear_aus": ("ACTION", "Schicht is aus! Wer is no do unten?!"),
    "appear_aufi": ("ACTION", "Aufi mit eich, ihr Hundling!"),
    "spot_siag": ("SPOT", "I siag di, Kumpl!"),
    "spot_troedl": ("SPOT", "Wer trödelt, bleibt do!"),
    "idle_wo": ("IDLE", "Wo seid's denn?!"),
    "idle_stempl": ("IDLE", "Wer ned stempelt, kriagt nix!"),
    "die_zspat": ("DIE", "Zspät, Kumpl."),
    "hit_vorgsetzt": ("HIT", "An Vorgsetztn haun? Des werd vermerkt!"),
}

# --- Percht: growls under the bells, a word or two at most -------------------------------------------

def percht_a(text):
    """A: Untier – a word dragged up from a huge chest, an octave down, half growl."""
    x, sr = speak(text, "de+m1", 95, 10, 6)
    x = d.drive(d.normalize(rasp(at_pitch(x, sr, 0.62), 0.9)), 2.6)
    growl = d.lowpass(d.glottal(55, len(x) / SR + 0.01, 0.12, 0.6)[: len(x)], 400) * envelope(x, 12.0) * 2.0
    return finish(d.mix(d.bandpass(x, 60, 3800), growl), 0.4, 1.8)


def percht_b(text):
    """B: Maske – spoken from behind the carved wooden mask: boxy, hollow, resonant."""
    x, sr = speak(text, "de+m3", 105, 18, 4)
    x = d.drive(d.normalize(at_pitch(x, sr, 0.72)), 1.8)
    x = d.bandpass(x, 90, 2600) + 0.6 * d.resonator(x, 420, 6) + 0.3 * d.resonator(x, 900, 8)
    return finish(x, 0.42, 1.6)


def percht_c(text):
    """C: Raunacht – two voices at once, one growling low, one whispering on top."""
    low, sr = speak(text, "de+m1", 100, 12, 5)
    whisper, sr2 = speak(text, "de+whisper", 100, 30, 5)
    x = layered(rasp(at_pitch(low, sr, 0.58), 1.0), at_pitch(whisper, sr2, 0.85), 1.0, 0.5)
    return finish(d.lowpass(d.drive(x, 2.2), 4500), 0.45, 2.0)


PERCHT_VARIANTS = {"A": percht_a, "B": percht_b, "C": percht_c}

PERCHT_LINES = {
    "spot_riach": ("SPOT", "I riach di."),
    "spot_do": ("SPOT", "Do bist jo."),
    "idle_raunacht": ("IDLE", "Raunacht."),
    "idle_brumm": ("IDLE", "Mmmh. Pfui."),
    "strike_hob": ("ACTION", "Hob di!"),
    "hit_ha": ("HIT", "Ha!"),
    "flee_wo": ("FLEE", "Wo bist?"),
}


# --- Salzweibl: generic calls when there is no teammate voice to copy ---------------------------------

def weibl_a(text):
    """A: Kumpl – a miner calling from further down the tunnel: a plain man's voice, a bit far."""
    x, sr = speak(text, "de+m3", 150, 45)
    x = d.bandpass(d.normalize(at_pitch(x, sr, 1.0)), 200, 4200)
    return d.echo(finish(x, 0.35, 1.6), 0.28, 0.2, 2)


def weibl_b(text):
    """B: Weibl – a woman's voice, sweet, a little too close and slightly out of tune."""
    x, sr = speak(text, "de+f2", 140, 62)
    x = tremolo(d.normalize(at_pitch(x, sr, 1.04)), 5.0, 0.08)
    detuned = at_pitch(x, SR, 1.012)
    return finish(d.bandpass(layered(x, detuned, 1.0, 0.35), 220, 6000), 0.4, 1.8)


def weibl_c(text):
    """C: Echo – a voice that is not quite anyone's: half voice, half breath, under the salt."""
    voiced, sr = speak(text, "de+m4", 140, 50)
    whisper, sr2 = speak(text, "de+whisper", 140, 50)
    x = layered(at_pitch(voiced, sr, 0.97), at_pitch(whisper, sr2, 0.97), 0.7, 0.6)
    return d.echo(finish(d.bandpass(x, 250, 5000), 0.45, 2.0), 0.35, 0.3, 3)


WEIBL_VARIANTS = {"A": weibl_a, "B": weibl_b, "C": weibl_c}

SALZWEIBL_LINES = {
    "call_hilfe": ("IDLE", "Hilfe! Do herüben!"),
    "call_kumpl": ("IDLE", "Kumpl? Bist du des?"),
    "call_gfundn": ("IDLE", "Kimm her, i hob wos gfundn!"),
    "call_aussi": ("IDLE", "I find nimma aussi."),
    "call_hallo": ("IDLE", "Hallo? Is do wer?"),
    "take_mei": ("ACTION", "Jetzt bist mei."),
    "flee_zwoa": ("FLEE", "Zu zweit? Na."),
    "hit_au": ("HIT", "Lass mi!"),
}

# The voice the game uses until the user picks one in the sample check.
# Bergmandl A (2026-10-29), Kasermandl A and Schichtmeister A (2026-10-30) are approved;
# Percht B and Salzweibl B (2026-10-30) too.
CHOICE = {"bergmandl": "A", "kasermandl": "A", "schichtmeister": "A", "percht": "B", "salzweibl": "B"}


def giggle(fn):
    """A run of quick, rising and falling "hi"s in the creature's voice."""
    def make(_text):
        x = fn("hi hi hi hi hihi")
        t = np.arange(len(x)) / SR
        return d.normalize(x * (1.0 + 0.25 * np.sin(2 * np.pi * 9 * t)))
    return make


# Line id -> (moment, how eSpeak is to say it). Moments match VoiceLine.Moment.
BERGMANDL_LINES = {
    "spot_schau": ("SPOT", "Do schau her!"),
    "spot_wos": ("SPOT", "Hehe, wos hamma denn do?"),
    "steal_ghert": ("ACTION", "Des ghert jetzt mir!"),
    "steal_meins": ("ACTION", "Meins! Meins!"),
    "flee_langsam": ("FLEE", "Hihi, zlangsam!"),
    "flee_fangts": ("FLEE", "Fangts mi doch!"),
    "shouted_laut": ("SHOUTED_AT", "Ned so laut!"),
    "shouted_guat": ("SHOUTED_AT", "Is jo scho guat, is jo scho guat!"),
    "hit_grobian": ("HIT", "Au! Du Grobian!"),
    "hit_aua": ("HIT", "Aua!"),
    "die_kumm": ("DIE", "I kumm wieder."),
    "idle_salz": ("IDLE", "Salz, Salz, ois mei Salz."),
    "idle_psst": ("IDLE", "Psst. Do is wer."),
    "idle_wer": ("IDLE", "Wer is do? Wer is do?"),
}

# Creature -> (voice variants, lines). Folders and file names follow the creature id.
CREATURES = {
    "bergmandl": (MANDL_VARIANTS, BERGMANDL_LINES),
    "kasermandl": (KASER_VARIANTS, KASERMANDL_LINES),
    "schichtmeister": (MEISTER_VARIANTS, SCHICHTMEISTER_LINES),
    "percht": (PERCHT_VARIANTS, PERCHT_LINES),
    "salzweibl": (WEIBL_VARIANTS, SALZWEIBL_LINES),
}


# --- players' shouts --------------------------------------------------------------------------------

def shouter(text):
    """A miner yelling down the tunnel: loud, a bit hoarse, big echo."""
    x, sr = speak(text, "de+m3", 150, 42)
    x = at_pitch(x, sr, 0.95)
    x = d.drive(d.normalize(rasp(x, 0.2)), 2.2)
    return d.echo(finish(d.bandpass(x, 150, 6500), 0.32, 1.8), 0.35, 0.25, 2)


SHOUTS = ["He! Schleichts eich!", "Hoi! Weg do!", "Schauts, dass weiterkummts!"]


def voice_jobs():
    """(folder, file name, recipe) for every voice file the game uses."""
    jobs = []
    for creature, (variants, lines) in CREATURES.items():
        fn = variants[CHOICE[creature]]
        for line_id, (_moment, text) in lines.items():
            jobs.append((f"voices/{creature}", line_id, lambda _v, f=fn, t=text: f(t)))
    mandl = MANDL_VARIANTS[CHOICE["bergmandl"]]
    jobs.append(("voices/bergmandl", "giggle", lambda _v: giggle(mandl)("")))
    for i, text in enumerate(SHOUTS, 1):
        jobs.append(("sfx", f"shout_{i}", lambda _v, t=text: shouter(t)))
    return jobs


def sample_jobs(creatures=None):
    """Every line of the given creatures (default: all) in every variant, for the sample check."""
    jobs = []
    for creature, (variants, lines) in CREATURES.items():
        if creatures and creature not in creatures:
            continue
        for variant, fn in variants.items():
            for line_id, (_moment, text) in lines.items():
                jobs.append((f"{creature}_{variant}", line_id, lambda _v, f=fn, t=text: f(t)))
    return jobs
