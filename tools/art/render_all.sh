#!/usr/bin/env bash
# Tüm oyun görsellerini üretir. Blender (bpy) içeren bir Python ortamı ister:
#   python3 -m venv .venv && .venv/bin/pip install bpy tifffile imagecodecs numpy scipy scikit-image pillow
# Kullanım: PY=.venv/bin/python ./render_all.sh
set -euo pipefail
cd "$(dirname "$0")"
PY=${PY:-python3}
$PY render_world.py 6144 48
SAMPLES=48 $PY sprites/pumpjack.py
SAMPLES=64 FRAMES=12 $PY sprites/derrick.py
SAMPLES=48 DIRS=16 $PY sprites/vehicles.py
SAMPLES=32 $PY sprites/workers.py
SAMPLES=64 $PY sprites/facilities.py
SAMPLES=40 $PY sprites/site_bg.py
$PY pack.py
