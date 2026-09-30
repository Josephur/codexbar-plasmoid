# Contributing

Thanks for helping with the Plasma port of CodexBar. Two things keep reviews short: putting a setting on the right side of the config boundary, and small pull requests.

## Where a setting lives

**If the CodexBar CLI needs it to fetch, it lives in CodexBar's `config.json`. If only Plasma needs it to render, it lives in the plasmoid config.**

The CLI reads `~/.config/codexbar/config.json`, and the macOS app writes the same file. Fetch-side settings are managed there (`codexbar config …`) instead of being mirrored in the widget. The rule was agreed in [#18](https://github.com/psimaker/codexbar-plasmoid/issues/18).

| Fetch-side: CodexBar `config.json` | Display-side: plasmoid config (`contents/config/main.xml`) |
|---|---|
| provider enabled, data source | panel display mode |
| API keys, cookie headers | percentage label, window and style |
| hosts, region, workspace | critters |
| token accounts | click and launch actions |
| hooks | refresh interval |

`enabledProviders` and `providerSources` predate the rule; moving them to `config.json` is tracked in [#25](https://github.com/psimaker/codexbar-plasmoid/issues/25). Please do not add new fetch-side keys to the plasmoid.

Requests for new providers, data sources, credentials or fetch behavior belong upstream in [steipete/CodexBar](https://github.com/steipete/CodexBar/issues). The widget only renders what the CLI reports.

## Pull requests

- `main` only accepts pull requests, and each one needs an approving review.
- Keep a pull request small and about one topic. Split refactors, new settings and behavior changes into separate pull requests; review time is the bottleneck.
- Say what changed and how you tested it, link the issue, and add a screenshot for visible UI changes.
- Commit subjects follow the existing history: `feat:`, `fix:`, `docs:`, `build:`, `chore:`.

## Development

```bash
kpackagetool6 -t Plasma/Applet -i .    # install from the checkout; -u . to update
tests/run-tests.sh                     # Python and Node tests, as in CI
/usr/lib/qt6/bin/qmllint -I contents/ui $(find contents -name '*.qml')
```

Every pull request also runs a Plasma smoke test (`.github/workflows/plasma-smoke.yml`): it renders the widget with `plasmoidviewer` against the mock CLI in `tests/smoke/`, fails on QML runtime errors and attaches screenshots to the workflow run. Add a scenario to `tests/smoke/run.sh` when you change what the panel or popup shows.

Plasma keeps the loaded QML until it restarts (`systemctl --user restart plasma-plasmashell.service`); `plasmoidviewer -a .` from plasma-sdk is quicker for iterating.

Logic that does not need QML lives in `contents/ui/code/*.js` and is tested with Node in `tests/`. Keep new helpers there so they stay testable.

### Syncing providers with upstream

A daily workflow (`.github/workflows/upstream-check.yml`) compares the pinned list with the latest CodexBar CLI release and opens an issue labelled `upstream-sync` when providers were added or removed. `DRY_RUN=1 scripts/check-upstream-providers.sh` runs the same check locally.

When the CodexBar CLI gains or drops providers:

1. Regenerate `tests/data/cli-provider-ids.txt` with the command in its header.
2. Update `contents/ui/code/catalog.js` in the same order. Name, color, dashboard and status come from the provider descriptors in upstream's `Sources/CodexBarCore/Providers`; `minCli` is the CLI release that introduced the provider.
3. Take the icon from upstream's `Sources/CodexBar/Resources`. Monochrome artwork gets the `ColorScheme-Text` wrapper the existing icons use; a fully colored logo keeps its colors and sets `logoColor`.
4. `tests/test_catalog.py` checks the order, required fields, icons and logo colors.
