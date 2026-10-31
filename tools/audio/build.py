"""Renders every sound of Soizwöd into assets/audio as OGG Vorbis.

    pip install numpy scipy soundfile
    python tools/audio/build.py              # everything
    python tools/audio/build.py drip swing   # only these names
    python tools/audio/build.py --samples [creature ...]   # voice sample pack to build/samples/

Folders: sfx/, ambience/, music/, voices/<creature>/. A sound with several variants is written as
name_1.ogg, name_2.ogg ...; one with a single variant as name.ogg. The game picks a variant at
random (autoload/audio.gd). The guns come from real recordings (guns.py). Voice lines need eSpeak NG; without it they are skipped.
Structure follows Berghittn's tools/audio/build.py."""
import sys
import zlib
from pathlib import Path

import numpy as np
import soundfile as sf

import dsp
import guns
import music
import sfx
import voices

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "assets" / "audio"
SAMPLES = ROOT / "build" / "samples"
PEAK = 0.85


def render(path: Path, fn, variant: int, loop: bool) -> float:
    dsp.seed(zlib.crc32(f"{path.stem}:{variant}".encode()))
    x = np.asarray(fn(variant), dtype=np.float64)
    if not np.all(np.isfinite(x)):
        raise ValueError(f"{path.name} is not finite")
    x = x - np.mean(x)
    if not loop:
        x = dsp.fade(x, 0.0005, min(0.03, len(x) / dsp.SR * 0.2))
    x = np.clip(x * min(1.0, PEAK / (np.max(np.abs(x)) + 1e-9)), -1.0, 1.0).astype(np.float32)
    path.parent.mkdir(parents=True, exist_ok=True)
    # In blocks: libsndfile's Vorbis encoder overflows the stack on one long write.
    with sf.SoundFile(str(path), "w", dsp.SR, 1, format="OGG", subtype="VORBIS", compression_level=0.45) as f:
        for i in range(0, len(x), 8192):
            f.write(x[i:i + 8192])
    return len(x) / dsp.SR


def jobs():
    for name, (fn, variants) in (sfx.SOUNDS | guns.SOUNDS).items():
        folder = "ambience" if name in sfx.AMBIENCE else "sfx"
        for v in range(variants):
            file = f"{name}_{v + 1}.ogg" if variants > 1 else f"{name}.ogg"
            yield name, AUDIO / folder / file, fn, v, name in sfx.LOOPS
    yield "stubenmusi", AUDIO / "music" / "stubenmusi.ogg", music.stubenmusi, 0, True
    for sting in ["sting_bergkini", "sting_seemuada", "sting_schiachpercht", "sting_boss_down"]:
        yield sting, AUDIO / "music" / f"{sting}.ogg", getattr(music, sting), 0, False
    if voices.espeak():
        for folder, name, fn in voices.voice_jobs():
            yield name, AUDIO / folder / f"{name}.ogg", fn, 0, False
    else:
        print("eSpeak NG not found: voice lines are left as they are")


def samples(creatures):
    if not voices.espeak():
        sys.exit("eSpeak NG is needed for the sample pack")
    for folder, name, fn in voices.sample_jobs(creatures):
        path = SAMPLES / folder / f"{name}.ogg"
        print(f"{path.relative_to(ROOT)}  {render(path, fn, 0, False):.2f} s")


def main(names: set) -> None:
    for name, path, fn, variant, loop in jobs():
        if names and name not in names:
            continue
        seconds = render(path, fn, variant, loop)
        print(f"{str(path.relative_to(AUDIO)):44} {seconds:6.2f} s {path.stat().st_size / 1024:7.1f} KB")


if __name__ == "__main__":
    if "--samples" in sys.argv:
        samples({a for a in sys.argv[1:] if a != "--samples"})
    else:
        main(set(sys.argv[1:]))
