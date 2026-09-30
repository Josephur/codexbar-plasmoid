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

# package NAME KEY=VALUE... prints the path of a copy of the widget whose
# config defaults are replaced, so every scenario starts from a known state.
package() {
    local dir="$work/pkg-$1"
    shift
    mkdir -p "$dir"
    cp -r "$repo/metadata.json" "$repo/contents" "$dir/"
    local xml="$dir/contents/config/main.xml" pair key value
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        awk -v key="$key" -v value="$value" '
            index($0, "<entry name=\"" key "\"") { hit = 1 }
            hit && /<default>/ { sub(/<default>.*<\/default>/, "<default>" value "</default>"); hit = 0 }
            { print }
        ' "$xml" >"$xml.new"
        mv "$xml.new" "$xml"
        grep -q -F "<default>$value</default>" "$xml" || { echo "unknown setting: $key" >&2; return 1; }
    done
    echo "$dir"
}

# render NAME PACKAGE WIDTHxHEIGHT [plasmoidviewer options...]
render() {
    local name="$1" pkg="$2" size="$3"
    shift 3
    plasmoidviewer -a "$pkg" -s "$size" "$@" >"$out/$name.log" 2>&1 &
    local pid=$!
    sleep "${SMOKE_WAIT:-15}"
    xwininfo -root -tree >"$out/$name.windows.txt" 2>&1 || true
    import -window root "$out/$name.screen.png"
    magick "$out/$name.screen.png" -crop "${size}+0+0" +repage "$out/$name.png"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}

three="enabledProviders=codex,claude,antigravity"
panel=(-c org.kde.panel -f horizontal -l topedge)
render panel-meters "$(package meters "$three" showPercentInPanel=true panelPercentSource=lowest)" \
    640x140 "${panel[@]}"
render panel-logos "$(package logos "$three" panelDisplayMode=logos showPercentInPanel=true)" \
    640x140 "${panel[@]}"
render panel-override "$(package override "$three" showPercentInPanel=true \
    'providerOverrides={"claude":{"panelDisplayMode":"logos"}}')" 640x140 "${panel[@]}"
render panel-countdown "$(package countdown "$three" panelDisplayMode=logos showPercentInPanel=true \
    showResetCountdown=true)" 640x140 "${panel[@]}"
render panel-vertical "$(package vertical "$three" showPercentInPanel=true showResetCountdown=true \
    separateIcons=true)" 160x520 -c org.kde.panel -f vertical -l leftedge
render popup "$(package popup "$three")" 560x860 -f planar
render popup-used "$(package popup-used "$three" usageBarsShowUsed=true)" 560x860 -f planar

# Middle and double click on the merged meter run the configured command.
failed=0
marker="$work/clicked"
plasmoidviewer -a "$(package clicks "$three" middleClickAction=command doubleClickAction=command \
    "launchCommand=touch $marker")" -s 640x140 "${panel[@]}" >"$out/clicks.log" 2>&1 &
clicks_pid=$!
sleep "${SMOKE_WAIT:-15}"
xdotool mousemove 27 70 click 2
sleep 3
[[ -f "$marker" ]] || { echo "Middle click did not run the command" >&2; failed=1; }
rm -f "$marker"
xdotool mousemove 27 70 click --repeat 2 --delay 60 1
sleep 3
[[ -f "$marker" ]] || { echo "Double click did not run the command" >&2; failed=1; }
kill "$clicks_pid" 2>/dev/null || true
wait "$clicks_pid" 2>/dev/null || true

# QML runtime errors from the widget's own files fail the test, and so does
# an applet or containment that could not be loaded at all.
errors="$(grep -h -E 'contents/ui/.*(Error|Unable to assign|is not a function|Cannot read property|is not defined)|does not exist|Containment doesn.t exist' "$out"/*.log || true)"
if [[ -n "$errors" ]]; then
    echo "QML runtime errors:" >&2
    echo "$errors" >&2
    exit 1
fi
[[ "$failed" == 0 ]] || exit 1
echo "Rendered: $(cd "$out" && ls ./*.png | tr '\n' ' ')"
