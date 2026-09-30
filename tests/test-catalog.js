#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "catalog.js"),
    "utf8"
).replace(/^\.pragma library$/m, "")
const catalog = {}
vm.createContext(catalog)
vm.runInContext(source, catalog, { filename: "catalog.js" })

// An unknown --provider makes the CLI report the providers enabled in its
// own config; only the requested provider's entries may be shown.
const fallbackReport = [
    { provider: "codex", source: "auto", usage: { primary: { usedPercent: 12 } } },
    { provider: "claude", source: "auto", usage: { primary: { usedPercent: 34 } } },
]
const providersOf = (entries) => Array.from(entries, (entry) => entry.provider)
assert.equal(catalog.entriesForProvider(fallbackReport, "hyper").length, 0)
assert.deepEqual(providersOf(catalog.entriesForProvider(fallbackReport, "claude")), ["claude"])
// the report uses CodexBar's internal id for a few --provider names
assert.equal(catalog.reportedProviderId("groqcloud"), "groq")
assert.equal(catalog.reportedProviderId("codex"), "codex")
assert.deepEqual(providersOf(catalog.entriesForProvider(
    [{ provider: "abacus", usage: {} }], "abacusai")), ["abacus"])
for (const id of Object.keys(catalog.REPORTED_PROVIDER_IDS))
    assert.ok(catalog.PROVIDERS[id] !== undefined, id)
// entries without a provider field (older CLI output) are kept; junk is not
assert.equal(catalog.entriesForProvider([{ usage: {} }], "codex").length, 1)
assert.equal(catalog.entriesForProvider([null, 3, "x"], "codex").length, 0)
assert.equal(catalog.entriesForProvider({ provider: "codex" }, "codex").length, 0)
assert.equal(catalog.entriesForProvider(null, "codex").length, 0)

// fully colored logos keep a transparent chip; near-white brands get a dark one
assert.equal(catalog.logoBackgroundColor("codebuff"), "transparent")
assert.equal(catalog.logoBackgroundColor("vercel"), "#000000")
assert.equal(catalog.logoBackgroundColor("codex"), "#49A3B0")

const now = Date.parse("2026-08-30T12:00:00Z")
const weeklyExtra = {
    usedPercent: 10,
    windowMinutes: 10080,
    resetsAt: "2026-09-05T00:00:00Z",
}
const sessionExtra = {
    usedPercent: 10,
    windowMinutes: 300,
    resetsAt: "2026-08-30T14:00:00Z",
}

const weeklyMinutes = catalog.effectiveWindowMinutes(
    weeklyExtra, "codex", "extra"
)
assert.equal(weeklyMinutes, 10080)
assert.equal(
    catalog.paceLine(null, weeklyExtra, weeklyMinutes, now, "codex"),
    "Pace: 11% in reserve · Lasts until reset"
)

const sessionMinutes = catalog.effectiveWindowMinutes(
    sessionExtra, "codex", "extra"
)
assert.equal(sessionMinutes, 300)
assert.equal(
    catalog.paceLine(null, sessionExtra, sessionMinutes, now, "codex"),
    ""
)

console.log("Catalog tests passed")
