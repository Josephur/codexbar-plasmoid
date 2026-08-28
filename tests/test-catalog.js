#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "catalog.js"),
    "utf8"
).replace(/\.pragma library\s*/, "")
const catalog = {}
vm.createContext(catalog)
vm.runInContext(source, catalog, { filename: "catalog.js" })

// A dollar panel label represents remaining credit, never a used amount or a
// subscription quota. These fixtures mirror the live OpenRouter and DeepSeek
// payload shapes captured on this machine.
assert.equal(catalog.remainingDollarAmountText({
    details: [{
        title: "Credits",
        rows: [
            { label: "Remaining", value: "$11.52" },
            { label: "Used", value: "$18.48" }
        ]
    }]
}), "$11.52")
assert.equal(catalog.remainingDollarAmountText({
    primary: { usedPercent: 0, resetDescription: "$8.93 (Paid: $8.93 / Granted: $0.00)" }
}), "$8.93")
assert.equal(catalog.remainingDollarAmountText({
    details: [{ title: "Credits", rows: [{ label: "Used", value: "$18.48" }] }]
}), "")
assert.equal(catalog.remainingDollarAmountText({
    primary: { usedPercent: 0, resetDescription: "Resets in 3 hours" }
}), "")

console.log("Catalog tests passed")
