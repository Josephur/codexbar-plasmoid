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

// A panel dollar label must only be shown for a payload that explicitly
// declares a finite USD amount. Changing the eligibility check must fail here.
assert.equal(catalog.dollarAmountText({ used: 12.5, currency: "USD" }), "$ 12.50")
assert.equal(catalog.dollarAmountText({ used: 12.5, currency: "EUR" }), "")
assert.equal(catalog.dollarAmountText({ used: "12.5", currency: "USD" }), "")
assert.equal(catalog.dollarAmountText({ used: 12.5 }), "")
assert.equal(catalog.dollarAmountText(null), "")

console.log("Catalog tests passed")
