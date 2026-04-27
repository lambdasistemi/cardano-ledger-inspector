# Changelog

## 1.0.0 (2026-04-27)


### Features

* implement tx identify vertical ([c206733](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/c206733de0b46c9e8a1f22cff897a7346002bfb6))
* implement tx witness plan vertical ([96fe551](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/96fe551da61dbd5f9e30984332da03747d829d4e))
* narrow provider interface to tx cbor ([9a77a17](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/9a77a1717eac67aaa0684f1f1eb879a1cd9bc1fa))
* preserve input utxo context ([c927e63](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/c927e6343073ad6576d095ba7f877d5daef31af5))
* resolve input context from producer tx cbor ([9699bd1](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/9699bd1bad6b015d9dce9f3856955f643dc23ce7))
* resolve validation context from providers ([0fb1f93](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/0fb1f9368c2a29d75bc191c6da97485c5e8f24d5))
* surface ledger validation in inspector UI ([1c62066](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/1c620667061bd6681f1a9b28bd1c6b7a3b79191f))
* validate transactions through Conway ledger ([c5e40c2](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/c5e40c265fb4ead3300fce46988ba1a242ce67e1))


### Bug Fixes

* declutter inspector copy controls ([49e9123](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/49e9123476721af092b13efc5f0acbea0c531d8a))
* fall back to provider validation context ([9af5300](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/9af53005f34283d9a57bc6e5c1b4d5add81f2098))
* hide copy for context sentinels ([269a6fa](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/269a6fad81b9b6773acb434187bc0e31498567ed))
* route blockfrost keys to blockfrost provider ([e37678c](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/e37678c4857f3bd630a272fa5408a097d3006bad))
* stabilize wasm dependency cache metadata ([1b1275d](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/1b1275d6c560079a25266264ece360de23035c1e))


### Experiments

* extism pdk packaging for ledger conformance ([#22](https://github.com/lambdasistemi/cardano-ledger-wasi/issues/22)) ([6e3b0cb](https://github.com/lambdasistemi/cardano-ledger-wasi/commit/6e3b0cbcbafa4fc1e31926f63a0314b3b656f211))

## Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

Tagged releases are produced by
[release-please](https://github.com/googleapis/release-please) from
conventional-commit history; the
[release-assets workflow](.github/workflows/release-assets.yml) attaches
the WASI reactor, the Extism conformance plugin
(`cardano-ledger-reference-<tag>.wasm`), and the OpenAPI contract bundle
to each release.
