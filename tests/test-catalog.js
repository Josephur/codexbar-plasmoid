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

// objects cross the vm boundary with a foreign prototype; compare plain copies
function plain(value) { return JSON.parse(JSON.stringify(value)) }

// Antigravity (#27): the slots repeat each model family's most constrained
// bucket; the weekly quotas only exist in the quota summary extra windows.
const antigravity = {
    primary: { usedPercent: 40, windowMinutes: 300 },
    secondary: { usedPercent: 0, windowMinutes: 300 },
    extraRateWindows: [
        { id: "antigravity-quota-summary-gemini-5h", title: "Gemini 5-hour",
          window: { usedPercent: 40, windowMinutes: 300 } },
        { id: "antigravity-quota-summary-gemini-weekly", title: "Gemini weekly",
          window: { usedPercent: 65, windowMinutes: 10080 } },
        { id: "antigravity-quota-summary-3p-5h", title: "Claude/GPT 5-hour",
          window: { usedPercent: 0, windowMinutes: 300 } },
        { id: "antigravity-quota-summary-3p-weekly", title: "Claude/GPT weekly",
          window: { usedPercent: 90, windowMinutes: 10080 }, usageKnown: false },
    ],
}
// the most constrained known bucket wins; an unknown one never does
assert.equal(catalog.windowFor(antigravity, "antigravity", 10080).usedPercent, 65)
assert.equal(catalog.windowFor(antigravity, "antigravity", 300).usedPercent, 40)
assert.deepEqual(plain(catalog.cardSlots(antigravity, "antigravity")), [])
// local reports: the family pools carry no cadence, so no session or weekly
const antigravityLocal = {
    primary: { usedPercent: 30, resetDescription: "in 5h" },
    secondary: { usedPercent: 0 },
}
assert.equal(catalog.windowFor(antigravityLocal, "antigravity", 300), null)
assert.equal(catalog.windowFor(antigravityLocal, "antigravity", 10080), null)
assert.deepEqual(plain(catalog.cardSlots(antigravityLocal, "antigravity")),
    ["primary", "secondary", "tertiary"])
assert.equal(catalog.slotTitle("antigravity", "primary", 300), "Gemini Models")
assert.equal(catalog.slotTitle("antigravity", "secondary", 0), "Claude and GPT")
// every other provider keeps the slot contract and duration titles
const legacy = { primary: { usedPercent: 5 }, secondary: { usedPercent: 7 } }
assert.equal(catalog.windowFor(legacy, "codex", 300).usedPercent, 5)
assert.equal(catalog.windowFor(legacy, "codex", 10080).usedPercent, 7)
assert.deepEqual(plain(catalog.cardSlots(antigravity, "codex")),
    ["primary", "secondary", "tertiary"])
assert.equal(catalog.slotTitle("codex", "secondary", 10080), "Weekly")
assert.equal(catalog.slotTitle("codex", "tertiary", 0), "Monthly")

// unknown usage on a named extra window reaches the window helpers
const unknownExtra = catalog.namedWindow(antigravity.extraRateWindows[3])
assert.equal(catalog.windowUsedText(unknownExtra), "–")
assert.equal(catalog.windowBarPercent(unknownExtra), 0)
assert.equal(catalog.namedWindow(antigravity.extraRateWindows[1]).usedPercent, 65)
assert.equal(catalog.namedWindow({ id: "x", window: { isSyntheticPlaceholder: true } }), null)
assert.equal(catalog.namedWindow(null), null)

console.log("Catalog tests passed")
