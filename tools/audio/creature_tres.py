"""Writes enemies/<id>/<id>.tres for talking creatures from the line tables in voices.py, so the
lines the game lists always match the .ogg files build.py renders.

    python tools/audio/creature_tres.py kasermandl schichtmeister"""
import sys
from pathlib import Path

import voices

ROOT = Path(__file__).resolve().parents[2]
MOMENTS = ["SPOT", "IDLE", "ACTION", "HIT", "DIE", "FLEE", "SHOUTED_AT"]  # VoiceLine.Moment


def tres(creature: str) -> str:
    _variants, lines = voices.CREATURES[creature]
    out = ['[gd_resource type="Resource" script_class="EnemyData" format=3]', "",
           '[ext_resource type="Script" path="res://enemies/enemy_data.gd" id="1_data"]',
           '[ext_resource type="Script" path="res://enemies/voice_line.gd" id="2_line"]',
           f'[ext_resource type="PackedScene" path="res://enemies/{creature}/{creature}.tscn" id="3_scene"]']
    for i, line_id in enumerate(lines):
        out.append(f'[ext_resource type="AudioStream" path="res://assets/audio/voices/{creature}/{line_id}.ogg" id="s{i}"]')
    subs = []
    for i, (line_id, (moment, _text)) in enumerate(lines.items()):
        subs.append(f"line_{line_id}")
        out += ["", f'[sub_resource type="Resource" id="line_{line_id}"]', 'script = ExtResource("2_line")',
                f'id = &"{line_id}"', f"moment = {MOMENTS.index(moment)}", f'stream = ExtResource("s{i}")']
    refs = ", ".join(f'SubResource("{s}")' for s in subs)
    out += ["", "[resource]", 'script = ExtResource("1_data")', f'id = &"{creature}"',
            f'name_key = "CREATURE_{creature.upper()}"', 'scene = ExtResource("3_scene")',
            f'voice_lines = Array[ExtResource("2_line")]([{refs}])', ""]
    return "\n".join(out)


if __name__ == "__main__":
    for name in sys.argv[1:]:
        path = ROOT / "enemies" / name / f"{name}.tres"
        path.write_text(tres(name), encoding="utf-8")
        print(path.relative_to(ROOT))
