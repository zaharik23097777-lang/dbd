#!/usr/bin/env bash
# Превью моделей и поз: собрать место, экспортировать сцену, отрисовать PNG.
#   tools/preview/preview.sh <out.png> <mode> [args...]   (режимы — см. export.luau)
# Переменные: ROJO, LUNE (пути к бинарникам), SIZE (размер тайла), VIEWS (через запятую), COLS
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$1"; shift
ROJO="${ROJO:-rojo}"
LUNE="${LUNE:-lune}"
WORK="${TMPDIR:-/tmp}/dbd-preview"
mkdir -p "$WORK"
PLACE="$WORK/place.rbxlx"
"$ROJO" build "$ROOT/default.project.json" -o "$PLACE" >/dev/null
JSON="$WORK/scene-$$.json"
"$LUNE" run "$ROOT/tools/preview/export.luau" "$PLACE" "$JSON" "$@"
ARGS=(--size "${SIZE:-420}")
[ -n "${VIEWS:-}" ] && ARGS+=(--views "$VIEWS")
[ -n "${COLS:-}" ] && ARGS+=(--cols "$COLS")
python3 "$ROOT/tools/preview/render.py" "$JSON" "$OUT" "${ARGS[@]}"
rm -f "$JSON"
