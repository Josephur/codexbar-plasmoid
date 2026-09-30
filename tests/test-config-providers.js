#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

function load(file) {
    const source = fs.readFileSync(
        path.join(__dirname, "..", "contents", "ui", "code", file), "utf8"
    ).replace(/^\.pragma library$/m, "")
    const context = {}
    vm.createContext(context)
    vm.runInContext(source, context, { filename: file })
    return context
}

const lib = load("configProviders.js")
const catalog = load("catalog.js")

// objects cross the vm boundary with a foreign prototype; compare plain copies
function plain(value) { return JSON.parse(JSON.stringify(value)) }

// `config providers --json` and `config dump --json` as CodexBar 0.70 prints them
const providers = JSON.stringify([
    { displayName: "Codex", enabled: true, provider: "codex", defaultEnabled: true },
    { displayName: "Groq", enabled: false, provider: "groq", defaultEnabled: false },
    { displayName: "Claude", enabled: true, provider: "claude", defaultEnabled: false },
    { displayName: "My Plugin", enabled: true, provider: "myplugin", defaultEnabled: false },
])
const dump = JSON.stringify({ providers: [
    { id: "codex", enabled: true },
    { id: "claude", enabled: true, source: "oauth" },
] })

const list = lib.parse(providers, dump, catalog.cliProviderId)
assert.deepEqual(plain(list), [
    { id: "codex", name: "Codex", enabled: true, source: "auto" },
    { id: "groqcloud", name: "Groq", enabled: false, source: "auto" },
    { id: "claude", name: "Claude", enabled: true, source: "oauth" },
    { id: "myplugin", name: "My Plugin", enabled: true, source: "auto" },
])
assert.deepEqual(plain(lib.enabledIds(list)), ["codex", "claude", "myplugin"])

// an unreadable dump keeps every source at auto; an unreadable list is null
assert.equal(lib.parse(providers, "", catalog.cliProviderId)[2].source, "auto")
assert.equal(lib.parse("", dump, catalog.cliProviderId), null)
assert.equal(lib.parse('{"providers":[]}', dump, catalog.cliProviderId), null)
assert.deepEqual(plain(lib.parse('[{"enabled":true},null,{"provider":""}]', "", catalog.cliProviderId)), [])
// a provider without a display name shows its id
assert.equal(lib.parse('[{"provider":"x","enabled":true}]', "", catalog.cliProviderId)[0].name, "x")

// writes: enable exactly what is wanted, in list order, known ids only
assert.deepEqual(plain(lib.changes(list, ["codex", "groqcloud", "unknown"])),
    ["enable --provider groqcloud", "disable --provider claude", "disable --provider myplugin"])
assert.deepEqual(plain(lib.changes(list, ["codex", "claude", "myplugin"])), [])
assert.deepEqual(plain(lib.changes(null, ["codex"])), [])
assert.deepEqual(plain(lib.enabledIds(null)), [])

console.log("Config provider tests passed")
