#!/usr/bin/env bash
# Compare the pinned provider list (tests/data/cli-provider-ids.txt) with the
# latest CodexBar CLI release. When providers were added or removed, open or
# update one issue labelled upstream-sync. DRY_RUN=1 prints the issue instead.
set -euo pipefail

repo_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$repo_root"

upstream="steipete/CodexBar"
pinned_file="${PINNED_FILE:-tests/data/cli-provider-ids.txt}"
label="upstream-sync"

pinned_version="$(sed -n 's/.*of CodexBar CLI \([0-9][0-9.]*[0-9]\)\..*/\1/p' "$pinned_file" | head -n 1)"
latest_tag="$(gh release view --repo "$upstream" --json tagName --jq .tagName)"
latest_version="${latest_tag#v}"
echo "Pinned: ${pinned_version:-unknown}, latest: $latest_version"
if [[ "$latest_version" == "$pinned_version" ]]; then
    echo "The provider list is pinned to the latest release."
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
asset="CodexBarCLI-${latest_tag}-linux-x86_64.tar.gz"
gh release download "$latest_tag" --repo "$upstream" \
    --pattern "$asset" --pattern "$asset.sha256" --dir "$work"
(cd "$work" && sha256sum --check --quiet "$asset.sha256" && tar -xzf "$asset")

# An isolated HOME keeps the CLI away from any real configuration.
mkdir -p "$work/home"
HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" "$work/CodexBarCLI" usage --help 2>&1 \
    | grep -o -- '--provider [^]]*' | head -n 1 | sed 's/^--provider //' | tr '|' '\n' \
    | grep -v -x -e both -e all >"$work/latest.txt"
grep -v '^#' "$pinned_file" | sed '/^$/d' >"$work/pinned.txt"
[[ -s "$work/latest.txt" ]] || { echo "Could not read the provider list from the CLI" >&2; exit 1; }

added="$(comm -13 <(sort "$work/pinned.txt") <(sort "$work/latest.txt"))"
removed="$(comm -23 <(sort "$work/pinned.txt") <(sort "$work/latest.txt"))"
if [[ -z "$added" && -z "$removed" ]]; then
    echo "No providers added or removed since ${pinned_version:-the pinned list}."
    exit 0
fi

bullets() {
    if [[ -n "$1" ]]; then sed 's/^/- `/; s/$/`/' <<<"$1"; else echo "- none"; fi
}
title="Sync providers with CodexBar $latest_version"
body="CodexBar [$latest_version](https://github.com/$upstream/releases/tag/$latest_tag) changed the provider list that \`$pinned_file\` pins to ${pinned_version:-an unknown version}.

**Added**
$(bullets "$added")

**Removed**
$(bullets "$removed")

Follow \"Syncing providers with upstream\" in CONTRIBUTING.md. Colors, names and dashboard links can change without touching the list, so check the [release notes](https://github.com/$upstream/releases) since ${pinned_version:-the pinned version} too."

if [[ "${DRY_RUN:-}" == 1 ]]; then
    printf '%s\n\n%s\n' "$title" "$body"
    exit 0
fi

gh label create "$label" --color 1d99f3 \
    --description "Provider list differs from the latest CodexBar CLI" 2>/dev/null || true
existing="$(gh issue list --label "$label" --state open --json number --jq '.[0].number // empty')"
if [[ -n "$existing" ]]; then
    gh issue edit "$existing" --title "$title" --body "$body"
else
    gh issue create --title "$title" --body "$body" --label "$label"
fi
