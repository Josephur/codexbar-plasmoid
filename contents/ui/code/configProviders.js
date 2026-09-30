// CodexBar's config.json decides which providers exist and which are enabled
// (#25). `codexbar config providers --json` lists them by CodexBar's internal
// id; the widget keys providers by their --provider name, so callers pass the
// id mapping (Catalog.cliProviderId).
.pragma library

// Outputs of `config providers --json` and `config dump --json` as
// [{ id, name, enabled, source }] in the CLI's order, or null when the first
// is not a provider list. A dump that cannot be read leaves every source at
// "auto".
function parse(providersJson, dumpJson, toCliId) {
    var list = null
    try {
        list = JSON.parse(providersJson)
    } catch (e) {
        return null
    }
    if (!Array.isArray(list))
        return null
    var sources = {}
    try {
        var dump = JSON.parse(dumpJson)
        var entries = dump && Array.isArray(dump.providers) ? dump.providers : []
        for (var d = 0; d < entries.length; d++) {
            var entry = entries[d]
            if (entry && typeof entry.id === "string" && typeof entry.source === "string")
                sources[entry.id] = entry.source
        }
    } catch (e) {
        // no sources; keep "auto"
    }
    var out = []
    for (var i = 0; i < list.length; i++) {
        var p = list[i]
        if (!p || typeof p.provider !== "string" || p.provider === "")
            continue
        out.push({
            id: toCliId(p.provider),
            name: typeof p.displayName === "string" && p.displayName !== "" ? p.displayName : p.provider,
            enabled: p.enabled === true,
            source: sources[p.provider] || "auto"
        })
    }
    return out
}

function enabledIds(list) {
    return (list || []).filter(function (p) { return p.enabled }).map(function (p) { return p.id })
}

// `config` subcommands that make config.json enable exactly the wanted ids,
// in list order. Wanted ids the config does not know are ignored.
function changes(list, wanted) {
    var out = []
    var ids = wanted || []
    for (var i = 0; i < (list || []).length; i++) {
        var want = ids.indexOf(list[i].id) >= 0
        if (want !== list[i].enabled)
            out.push((want ? "enable" : "disable") + " --provider " + list[i].id)
    }
    return out
}
