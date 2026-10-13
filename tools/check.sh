#!/usr/bin/env bash
# Полная проверка: сборка, анализ типов (luau-lsp), все тесты Lune.
#   tools/check.sh [test...]     (по умолчанию: map anim ui sim sim_edge)
# Переменные: TOOLS (папка с бинарниками), ROJO, LUNE, LUAU_LSP, LSP_DEFS (globalTypes.d.luau), TMPDIR
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${TOOLS:-/tmp/claude-0/tools}"
ROJO="${ROJO:-$(command -v rojo || echo "$TOOLS/rojo")}"
LUNE="${LUNE:-$(command -v lune || echo "$TOOLS/lune")}"
LUAU_LSP="${LUAU_LSP:-$(command -v luau-lsp || echo "$TOOLS/luau-lsp")}"
LSP_DEFS="${LSP_DEFS:-$TOOLS/globalTypes.d.luau}"
WORK="${TMPDIR:-/tmp}/dbd-check"
mkdir -p "$WORK"
PLACE="$WORK/build.rbxlx"
fail=0
"$ROJO" build "$ROOT/default.project.json" -o "$PLACE" >/dev/null || { echo "FAIL: rojo build"; exit 1; }
if [ -f "$LSP_DEFS" ] && [ -x "$LUAU_LSP" ]; then
	"$ROJO" sourcemap "$ROOT/default.project.json" -o "$WORK/sourcemap.json" >/dev/null
	out="$(cd "$ROOT" && "$LUAU_LSP" analyze --definitions="$LSP_DEFS" --sourcemap="$WORK/sourcemap.json" src 2>&1)"
	errs="$(printf '%s\n' "$out" | grep -cE '\): (TypeError|SyntaxError)' || true)"
	if [ "$errs" != "0" ]; then
		printf '%s\n' "$out" | grep -E '\): (TypeError|SyntaxError)' | head -40
		echo "FAIL: luau-lsp ($errs errors)"
		fail=1
	else
		echo "ok: luau-lsp"
	fi
fi
tests=("$@")
[ ${#tests[@]} -eq 0 ] && tests=(map anim ui sim sim_edge)
for t in "${tests[@]}"; do
	log="$WORK/$t.log"
	if (cd "$ROOT" && "$LUNE" run "tests/$t.test.luau" "$PLACE") >"$log" 2>&1; then
		echo "ok: $t ($(tail -1 "$log"))"
	else
		tail -30 "$log"
		echo "FAIL: $t (log: $log)"
		fail=1
	fi
done
exit $fail
