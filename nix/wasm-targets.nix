# WASM targets wired through the external cardano-ledger-wasm lib.wasm export.
#
# All three use the two-phase FOD pattern; dependenciesHash is locked per
# target. Bump the external cardano-ledger-wasm fork metadata or the local
# cabal-wasm.project inputs, then recompute by setting dependenciesHash =
# pkgs.lib.fakeHash and replacing it with the hash Nix prints on the next build.
#
# - wasm-smoke        : cborg-only; validates infrastructure end-to-end
# - wasm-ledger-smoke : full ledger closure + wasm32-built C libs; prints a
#                       version reference
# - wasm-tx-inspector : real Conway tx decoder; reads hex on stdin, emits JSON
# - wasm-extism-spike : Conway tx decoder packaged as an Extism PDK plugin;
#                       proof-of-concept for Extism-driven conformance tests
{ pkgs
, libWasm
, ghcWasmMeta
, wasiSdk
, chap
, cardanoLedgerWasmSrc
, smokeSrc
, ledgerSmokeSrc
, txInspectorSrc
, extismSpikeSrc
}:
let
  # Full ledger override set + wasm32-built C libs — the superset both
  # wasm-ledger-smoke and wasm-tx-inspector need.
  fullLedgerForks = [
    "cborg"
    "plutus"
    "hs-memory"
    "foundation"
    "network"
    "double-conversion"
    "criterion-measurement"
    "haskell-lmdb-mock"
  ];

  withExternalKernel = name: src:
    pkgs.runCommand "${name}-with-cardano-ledger-wasm" { } ''
      mkdir -p "$out"
      cp -rL ${src}/. "$out/"
      chmod -R u+w "$out"
      mkdir -p "$out/external"
      cp -rL ${cardanoLedgerWasmSrc}/cardano-ledger-wasm \
        "$out/external/cardano-ledger-wasm"
    '';
in
{
  wasm-smoke = libWasm.mkCardanoLedgerWasm {
    inherit pkgs ghcWasmMeta chap;
    src = smokeSrc;
    packages = [ "wasm-smoke" ];
    srpForks = [ "cborg" ];
    dependenciesHash = "sha256-77vajpEB8aCCJUaWtFGLLFEnSVMBeXKf9uEYLwA+a+E=";
  };

  wasm-ledger-smoke = libWasm.mkCardanoLedgerWasm {
    inherit pkgs ghcWasmMeta wasiSdk chap;
    src = ledgerSmokeSrc;
    packages = [ "wasm-ledger-smoke" ];
    srpForks = fullLedgerForks;
    withCLibs = true;
    dependenciesHash = "sha256-7dU3eySn+38cWtWHY5L5SNKXjiHNSn5ll1Sjrxr8zbY=";
  };

  wasm-tx-inspector = libWasm.mkCardanoLedgerWasm {
    inherit pkgs ghcWasmMeta wasiSdk chap;
    src = withExternalKernel "wasm-tx-inspector-src" txInspectorSrc;
    packages = [ "wasm-tx-inspector" ];
    srpForks = fullLedgerForks;
    withCLibs = true;
    # dependenciesHash distinct from wasm-ledger-smoke because the inspector
    # pulls additional Hackage tarballs (aeson, base16-bytestring, text,
    # microlens, ...) that expand the cabal cache.
    dependenciesHash = "sha256-KmY5jyyPc2NFXZSP133Tq6rQWp3d7STwT4O51h7Ukys=";
  };

  # Spike depends on cardano-ledger-wasm via an external path package injected
  # into the source root from the pinned flake input. The source remains the
  # repo root so the project file can address apps/wasm-extism-spike by path
  # while srpForks come from the external builder metadata.
  wasm-extism-spike = libWasm.mkCardanoLedgerWasm {
    inherit pkgs ghcWasmMeta wasiSdk chap;
    src = withExternalKernel "wasm-extism-spike-src" extismSpikeSrc;
    projectFile = "apps/wasm-extism-spike/cabal-wasm.project";
    packages = [ "wasm-extism-spike" ];
    srpForks = fullLedgerForks;
    withCLibs = true;
    dependenciesHash = "sha256-I6srK/QXzWcr5dbOFBV1cPJ7C5iNPCgSs1oshVoMvpU=";
  };
}
