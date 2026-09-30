#!/usr/bin/env bash
# Render the widget in plasmoidviewer against the mock CodexBar CLI, save a
# screenshot per scenario and fail on QML runtime errors. Run it inside a
# D-Bus session with Xvfb, plasmoidviewer and ImageMagick installed, as
# .github/workflows/plasma-smoke.yml does:
#   dbus-run-session -- bash tests/smoke/run.sh [output-dir]
set -euo pipefail

repo="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
out="${1:-$repo/dist/smoke}"
mkdir -p "$out"

work="$(mktemp -d)"
export HOME="$work/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache" XDG_RUNTIME_DIR="$work/run"
mkdir -p "$HOME/.local/bin" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
# The widget puts ~/.local/bin first on the CLI's PATH.
ln -s "$repo/tests/smoke/codexbar" "$HOME/.local/bin/codexbar"
export CODEXBAR_FIXTURES="$repo/tests/smoke/fixtures"

export DISPLAY=:99 QT_QPA_PLATFORM=xcb
Xvfb "$DISPLAY" -screen 0 1280x900x24 -nolisten tcp &
xvfb_pid=$!
trap 'kill "$xvfb_pid" 2>/dev/null || true' EXIT
sleep 2

# render NAME [plasmoidviewer options...]
render() {
    local name="$1"
    shift
    plasmoidviewer -a "$repo" "$@" >"$out/$name.log" 2>&1 &
    local pid=$!
    sleep "${SMOKE_WAIT:-15}"
    import -window root "$out/$name.full.png"
    magick "$out/$name.full.png" -trim +repage "$out/$name.png"
    rm -f "$out/$name.full.png"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}

render panel-horizontal -f horizontal -l bottomedge -s 420x48
render popup -f planar -s 560x820

find "$XDG_CONFIG_HOME" -type f -name '*appletsrc' -print -exec cat {} \; >"$out/appletsrc.txt" || true

# QML runtime errors from the widget's own files fail the test.
errors="$(grep -h -E 'contents/ui/.*(Error|Unable to assign|is not a function|Cannot read property|is not defined)' "$out"/*.log || true)"
if [[ -n "$errors" ]]; then
    echo "QML runtime errors:" >&2
    echo "$errors" >&2
    exit 1
fi
echo "Rendered: $(cd "$out" && ls ./*.png | tr '\n' ' ')"
