# Changelog

## 0.1.0 (2026-07-16)


### Features

* add Material two-pane inspect workspace ([0d2a25e](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/0d2a25ebbed2b94e23ea52bb35825d52e60adc6b))
* add rdf overlay book import model ([14560f6](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/14560f6a029c4e237dfb63fe90b0348b20fa4af0))
* add runtime --emit-explain flag ([05d5bdc](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/05d5bdc9afbc00a9fd5361cb6b1944d9e3069053))
* add stdout explain format to tx-deep-diagnosis ([99277fe](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/99277febfe3b0df9c53c7ea2df2c976f51ef657d))
* add tx.witness.attach ledger operation ([b905b09](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/b905b09bfb49f85154b1cb6d8b79375bef15bf24))
* commits as 0.x bumps until we explicitly cut 1.0.0. ([3fe3a2e](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/3fe3a2e7c717c85bf91fc840d8a8746843a6b326))
* decode rdf blueprint books in wasi ([72a7372](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/72a7372d22aceb644069d6199e925bdbaa27f175))
* emit rdf transaction graphs ([1eee2c6](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/1eee2c68f1aceac75382b1ca36d9531be480f14f))
* evaluate transaction scripts ([aa26aab](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/aa26aab5d8fb6106c1abe3505bcce7ce8aad3594))
* expose protocol registry as a flake output ([a0df0b0](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/a0df0b0e2885cc5e2591549e626f2281adaf7b26))
* expose required signer coverage in tx intent ([c3a4609](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/c3a4609a26a311f496a8bc2d16418b6bf0e0e443))
* formalize tx.intent output rows ([c13cb04](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/c13cb04dbda3ac71e033e151bf479ec0cb9aa8e1))
* implement tx identify vertical ([c206733](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/c206733de0b46c9e8a1f22cff897a7346002bfb6))
* implement tx witness plan vertical ([96fe551](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/96fe551da61dbd5f9e30984332da03747d829d4e))
* import rdf shacl shapes books ([9324ba6](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9324ba6eb7589315759ccc0034181074369932d5))
* **inspector + tx-deep-diagnosis:** per-bucket output addresses + cross-over detection ([709481f](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/709481fa7cfada17773fa4c6f0e36fc47295a23f))
* **inspector:** add class a shacl validation ([277938b](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/277938b2d2bc94dfb15af8d4679332fc30ec1278))
* **inspector:** add local book store foundation ([d532058](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/d53205835c943b4953fc2ee74469901669088919))
* **inspector:** add md3 shell foundation ([17f346f](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/17f346f9124da1c727f8e712d28784cfb8aae4a1))
* **inspector:** broken-tx examples picker + decoded-CBOR validation suite ([#131](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/131)) ([a58735f](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/a58735f65a2a11116c7ad5316be3e42289330fcf))
* **inspector:** decode inline datum CBOR to structured Plutus Data JSON ([b484e76](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/b484e7672318a3c06d54789400bc65ca4796d55b))
* **inspector:** decoded screen redesign (T2) ([6c1d56e](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/6c1d56e8b3fd6197bd223ba9914d275210c899f9))
* **inspector:** demonstrate credential resolution in Structure ([252d8eb](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/252d8ebc218ff956b94b7e647a53acbef51b7d06))
* **inspector:** design-system foundation (T1) — spec tokens + shared primitives ([746b037](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/746b03750c002caae4e45d27ec06c8814960ea9c))
* **inspector:** emit per-output detail + datum cbor in intent envelope ([6a3d0a6](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/6a3d0a67acb1b80d7958ad113e9d238225aed586))
* **inspector:** emit per-redeemer detail in intent.scripts[] ([af0af84](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/af0af8464a6da740fc76f97aa9b4845495df641d))
* **inspector:** exchange local book stores ([37a74ed](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/37a74ed3bdc08bafee2ef29bf0ad51ca5d598367))
* **inspector:** input/initial screen redesign (T3) ([ed4d563](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/ed4d563d585e45847c8fa1dc83feb4b41c0d8808))
* **inspector:** label decoded tree nodes into books ([3e35d76](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/3e35d76ea60def43f7f8e79c36d4db4e061e3f41))
* **inspector:** manage books in the library ([82a1ccc](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/82a1cccd3cc3f04986a2424e13422c842ebf7e3d))
* **inspector:** parse cert_state.rewards and seed Accounts before applyTx ([20cd707](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/20cd7077893aff44628e1b6ef4b7e8695c746c37))
* **inspector:** reskin inspect flow with md3 tokens ([9df5fb0](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9df5fb0d5bac111288092271e79f6d27d06aff9c))
* **inspector:** resolve credentials by generic hex suffix ([f45e2b0](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/f45e2b0c3f80159ae901be77bc727d9ce3b02d7d))
* **inspector:** resolve inspected trees from selected books ([165d15e](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/165d15e404b56d28c4e0cee7936f0696b1da2130))
* **inspector:** resolve opaque entities via flat cardano:txOutRef ([#126](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/126)) ([06f57ae](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/06f57ae9891d9b6384eedeb8e2a5ba5ffe26b612))
* **inspector:** ux-judge P1 burn-down — demote Books, dim empty fields ([#133](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/133)) ([5bdbae1](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/5bdbae1125c045915541f82867265db3d3a3110a))
* **inspector:** validate RDF network consistency ([#130](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/130)) ([7659482](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/7659482990f9c47e252ff97671486adc375b6954))
* **inspector:** validation screen redesign (T4) ([804ac44](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/804ac44d42d647da6cc8d6bfefeffe03ff251b68))
* move provider settings out of inspect ([f0eb556](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/f0eb55660f87fa13a8a3821f6c2fe67de38e6c76))
* narrow provider interface to tx cbor ([9a77a17](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9a77a1717eac67aaa0684f1f1eb879a1cd9bc1fa))
* preserve input utxo context ([c927e63](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/c927e6343073ad6576d095ba7f877d5daef31af5))
* **registry:** add optional DatumSchema with explicit provenance ([4bff1ce](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/4bff1cee55e9548e225b710b89c750bd86881925))
* render decoded tree from rdf sparql ([bb2219d](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/bb2219d552b590d74266b732abe8d4f10824f40d))
* render rdf blueprint book fields ([7a044c3](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/7a044c38537d13cac17903a3e15e70ced59b8bfd))
* render rdf shacl conformance ([b41d6e1](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/b41d6e1c233eb200c8b4ce350b89ee07ac21ad5f))
* render rdf sparql lens ([14fad28](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/14fad28e3a677cdab2b737ef417a21a5d9105d6a))
* render rdf transaction graphs ([02d4b52](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/02d4b52a24eaee4e1a54b0c942552831e316af5e))
* render resolved labels from rdf overlay books ([1f99b67](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/1f99b6765dd6f4997ea283986ae8a1858548d49b))
* resolve decoded tree rows from books ([94a5560](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/94a55601cbd45ab74797df6a650ba94b78feb673))
* resolve input context from producer tx cbor ([9699bd1](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9699bd1bad6b015d9dce9f3856955f643dc23ce7))
* resolve validation context from providers ([0fb1f93](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/0fb1f9368c2a29d75bc191c6da97485c5e8f24d5))
* surface ledger validation in inspector UI ([1c62066](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/1c620667061bd6681f1a9b28bd1c6b7a3b79191f))
* surface rdf provider resolution ([4488c0a](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/4488c0a11def622f81092ae58c91694524720f61))
* tx-deep-diagnosis CLI for layered Conway tx analysis ([edb880a](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/edb880a881e660ef276f0b1a5583361f6e82ffa4))
* tx-deep-diagnosis-native — host program reusing wasm-tx-inspector library ([9d7a279](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9d7a279e42b590b3fc1a8620612f6cdffce72390))
* **tx-deep-diagnosis:** auto-resolve cert_state via Blockfrost /accounts ([e3e3775](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/e3e3775da508be2d1254358ba2f07439f3f1d5cd))
* **tx-deep-diagnosis:** auto-resolve producer txs + validation context ([e2faaec](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/e2faaec563c7e2085ea194f70530c86a944eba68))
* **tx-deep-diagnosis:** Datums section pretty-prints decoded Plutus AST ([0b2a064](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/0b2a0648859a86278abca2895c0b0502d9787662))
* **tx-deep-diagnosis:** humanise validation failure messages ([4a748e1](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/4a748e129ed8e84851b89005adf932d9d6cbfcc4))
* **tx-deep-diagnosis:** make --registry additive on top of the bundle ([64694fb](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/64694fb0af9b163dd252e2e10ddb404146f210af))
* **tx-deep-diagnosis:** make explain report reader-first ([3db7800](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/3db78007eb9d131d972759607b6ccf737bba54ae))
* **tx-deep-diagnosis:** observations section — surface flow facts honestly ([de17a40](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/de17a403c8e41cfb591dd9d62f3b275911a7a217))
* **tx-deep-diagnosis:** Outputs + Smart-contract calls sections in summary ([209f4b0](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/209f4b0471d1ab6078e284ed66a8da54becbbef7))
* **tx-deep-diagnosis:** single-file explain.md with embedded diagrams ([b62f632](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/b62f632cf960e7ae4c3b4395af6828e996bde51b))
* **tx-deep-diagnosis:** T1 — Render.Doc envelope parser ([45fa69b](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/45fa69be26459ee413532a4adcff0752db25efe6))
* **tx-deep-diagnosis:** T2 — Render.Names hash → label ([3d4c0f5](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/3d4c0f58675c7328a62b33dd52fa29469be39431))
* **tx-deep-diagnosis:** T3 — render-snapshot harness + smoke ([0d9f0ad](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/0d9f0ad2c16e1f1beebbf6b7b2c85b9ebf689d40))
* **tx-deep-diagnosis:** T4 — Render.Parties (L1 cut) ([c73bd87](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/c73bd87b3fbb7bb42a47ae619acb10ebcf18efbc))
* **tx-deep-diagnosis:** T5 — Render.ValueFlow (L2 cut) ([86943ff](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/86943ffa4fd537d57e8d6f81f4f159c32c7601df))
* **tx-deep-diagnosis:** T6 — Render.Topology (L3 cut) ([99a861a](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/99a861aff426f0054954ad3007c57fc808cbe86d))
* **tx-deep-diagnosis:** T7 — Render.Failures + Render.Summary ([ba1df35](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/ba1df35076ffabbd7363c9850bd9953d70775936))
* **tx-deep-diagnosis:** typed datum rendering with provenance disclaimer ([f017cde](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/f017cde90758022846b555d9016c57cece64b498))
* **tx-intent:** surface structured withdrawals ([669defa](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/669defa7df83ef87ae657f997ac0f72c24fafc86))
* **ui:** add reusable RDF editor package ([b6423ac](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/b6423ac391b7700c51a4e03a45dc6624675897ad))
* **ui:** expose book source editor in library ([21a5939](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/21a59394416773e748e3eec556d4921162d37d5e))
* **ui:** make inspect result tree-primary tabs ([17d6f8b](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/17d6f8bcc86730ab1ed4b951db3ccaa27f2c870b))
* **ui:** validate book editor save-back ([5da1aca](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/5da1aca81b0654259f0a02f44751830679d6425e))
* **ux-judge:** automated UX/UI feedback loop (scored vs CQuisitor rubric) ([#132](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/132)) ([7131cf7](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/7131cf7102fbc9f85e984cb266bfabcccb58cf68))
* validate transactions through Conway ledger ([c5e40c2](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/c5e40c265fb4ead3300fce46988ba1a242ce67e1))
* vendor rdf shapes wasm query engine ([6cd44e9](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/6cd44e97962aff97e1a309b07088784887ba99e0))
* verify rdf producer inputs in wasm ([16c2f53](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/16c2f537fcdbfee7fd77cfb6607485bf087c0e6f))


### Bug Fixes

* declutter inspector copy controls ([49e9123](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/49e9123476721af092b13efc5f0acbea0c531d8a))
* fall back to provider validation context ([9af5300](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9af53005f34283d9a57bc6e5c1b4d5add81f2098))
* hide copy for context sentinels ([269a6fa](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/269a6fad81b9b6773acb434187bc0e31498567ed))
* **inspector:** attribute decoded field badges to fields ([e208f0e](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/e208f0e11c15db532543718314c2a9770002d44c))
* **inspector:** bind annotations to decoded entities ([6fbd532](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/6fbd532e1e417e419e1a02faa9354ad6acf8d1a1))
* **inspector:** collapse loaded rail into header ([581f823](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/581f823ed986cbf2b1e771cfaf0da7c8331ae07c))
* **inspector:** compact decoded row actions ([9f5bbe4](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9f5bbe4b9d31340c645d3d369dad9e4a55f031ba))
* **inspector:** compact decoded tree row metadata ([e5a11ab](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/e5a11ab1522ebb75d1f26ac3c40da5a3f58993b3))
* **inspector:** disable unsupported Koios browser provider ([9ff8bc8](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9ff8bc851f60496c99463675aacf0cbcdaba5731))
* **inspector:** examples reflect claims — sync bundled SHACL shapes + drift guard, banner count, empty/zero field display, surface fired shape ([9cadba2](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/9cadba2d104d56bbc0618f7a4c4a66b50416a249))
* **inspector:** flush result tab bar + responsive no-overflow lock (T5) ([c283a6f](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/c283a6f3d2c408085c0d2a455495da6a18ae9c57))
* **inspector:** keep routing inside deployed subpaths ([966f021](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/966f021c34142198fd2b258bcabf9007d6d5fb7f))
* **inspector:** make local decode offline by default ([4341473](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/4341473d9da114e8281741bf0d56b02a9173ae42))
* **inspector:** make provider dispatch explicit ([85cc545](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/85cc54517c90cbf1956768d1ea9f5219defc7fc3))
* **inspector:** normalize ledger verdict contract ([2c9d566](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/2c9d56635f5a0c73dc874309e736cbb000d60d80))
* **inspector:** rebrand cquisitor-style topbar ([798e208](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/798e208315577c19e13cf8d9afd3c26173f81a6b))
* **inspector:** render faithful Conway structure ([d7beb94](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/d7beb94c2a7aa46b876bbe270d3e411a8423ccb2))
* **inspector:** report Koios browser CORS honestly ([3447612](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/34476121311a631ebe60a043724b19e7735d9f39))
* **inspector:** restore decoded tree collapse ([a52c302](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/a52c302292553f96e435525a5eccaeaa952b689e))
* **inspector:** restore loaded result hierarchy ([c3ccd8d](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/c3ccd8d8f8c009dadf7573c09b308990c097d755))
* **inspector:** separate ledger and SHACL verdicts ([a552b80](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/a552b80bcf5453c25d586d6eae7a1a4868fed39e))
* **inspector:** stack inspect layout vertically ([e76b205](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/e76b20511da1df5bf6984514c70a114f524f64d1))
* **inspector:** surface loaded tx cbor ([e2cf950](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/e2cf9507fb7872738bc5a87aac15db2669c71df5))
* restore green build after tooling cleanup ([de231c7](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/de231c799144679c85139bdc7b1b71f9392db2ff))
* route blockfrost keys to blockfrost provider ([e37678c](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/e37678c4857f3bd630a272fa5408a097d3006bad))
* satisfy hlint producer context newtype ([5e010a0](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/5e010a0f733132f2ec083302f7860840587447c7))
* scope rdf dependency to wasm build ([bb9667c](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/bb9667c175b61e3a8660aa4e2a3ec85eae0e94b4))
* split datum groups by destination ([993cd30](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/993cd30d46dbd96cee67887c480660d47e567747))
* stabilize wasm dependency cache metadata ([1b1275d](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/1b1275d6c560079a25266264ece360de23035c1e))
* **tx-deep-diagnosis:** bundle the protocol registry into the binary ([ee4ced9](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/ee4ced9a36ab7d233164a47644dc36a00a6dbbc0))
* **tx-deep-diagnosis:** emit a single JSON document, not a text ([2c23b8e](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/2c23b8e8afb1c129011ba57d25aa50fe066ec3b4))
* **tx-deep-diagnosis:** replace Sankey value flow with ADA balance tables ([aa85ebd](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/aa85ebd974412af6deabcde2708ac2b33da90e44))
* **wasm:** pin srcMetadata sandbox name to keep prebuiltDeps cached ([#52](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/52)) ([5d22b3c](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/5d22b3cc31185bf86af49f6a43a3bc3d5836cbbc)), closes [#51](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/51)


### Performance

* **ui:** split and stream inspector wasm assets ([e0e7945](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/e0e79458600dc6f2213ca3cfb606f7c70b576b5e))


### Experiments

* extism pdk packaging for ledger conformance ([#22](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/22)) ([6e3b0cb](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/6e3b0cbcbafa4fc1e31926f63a0314b3b656f211))


### Chores

* pin release-please initial-version to 0.1.0 ([#26](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/26)) ([3fe3a2e](https://github.com/lambdasistemi/cardano-ledger-inspector/commit/3fe3a2e7c717c85bf91fc840d8a8746843a6b326))

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
