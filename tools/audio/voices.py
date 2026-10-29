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

# The voice the game uses until the user picks one in the sample check.
CHOICE = {"bergmandl": "A"}


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
    mandl = MANDL_VARIANTS[CHOICE["bergmandl"]]
    for line_id, (_moment, text) in BERGMANDL_LINES.items():
        jobs.append(("voices/bergmandl", line_id, lambda _v, t=text: mandl(t)))
    jobs.append(("voices/bergmandl", "giggle", lambda _v: giggle(mandl)("")))
    for i, text in enumerate(SHOUTS, 1):
        jobs.append(("sfx", f"shout_{i}", lambda _v, t=text: shouter(t)))
    return jobs


def sample_jobs():
    """Every Bergmandl line in every variant, for the user's sample check."""
    jobs = []
    for variant, fn in MANDL_VARIANTS.items():
        for line_id, (_moment, text) in BERGMANDL_LINES.items():
            jobs.append((f"bergmandl_{variant}", line_id, lambda _v, f=fn, t=text: f(t)))
        jobs.append((f"bergmandl_{variant}", "giggle", lambda _v, f=fn: giggle(f)("")))
    return jobs
