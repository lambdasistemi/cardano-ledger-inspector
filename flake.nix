{
  description = "Cardano ledger operations compiled to WASI";

  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://paolino.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "paolino.cachix.org-1:ecmgO3CXdgSWA2cHlm4srknd/cLFMLmK3i3NrzeDFaE="
    ];
  };

  inputs = {
    haskellNix = {
      url = "github:input-output-hk/haskell.nix/ef52c36b9835c77a255befe2a20075ba71e3bfab";
      inputs.hackage.follows = "hackageNix";
    };
    hackageNix = {
      url = "github:input-output-hk/hackage.nix/c3d44f9e5d929e86a45a48246667ea25cd1f11df";
      flake = false;
    };
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    iohkNix = {
      url = "github:input-output-hk/iohk-nix/f444d972c301ddd9f23eac4325ffcc8b5766eee9";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    CHaP = {
      url = "github:intersectmbo/cardano-haskell-packages/00c90c10812a98ef9680f4bfa269d42366d46d89";
      flake = false;
    };
    ghc-wasm-meta = {
      url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
    };
    cardanoLedgerWasm = {
      url = "github:lambdasistemi/cardano-ledger-wasm/5897e8da1c043eb53cdafa6ada9782b56c74b18e";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.haskellNix.follows = "haskellNix";
      inputs.hackageNix.follows = "hackageNix";
      inputs.flake-parts.follows = "flake-parts";
      inputs.iohkNix.follows = "iohkNix";
      inputs.CHaP.follows = "CHaP";
      inputs.ghc-wasm-meta.follows = "ghc-wasm-meta";
    };
  };

  outputs =
    inputs@
    { self
    , nixpkgs
    , flake-parts
    , haskellNix
    , iohkNix
    , CHaP
    , ghc-wasm-meta
    , cardanoLedgerWasm
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      flake = {
        lib.wasm = cardanoLedgerWasm.lib.wasm;
      };

      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              iohkNix.overlays.crypto
              haskellNix.overlay
              iohkNix.overlays.haskell-nix-crypto
              iohkNix.overlays.cardano-lib
            ];
          };

          mkdocsEnv = pkgs.python3.withPackages (
            ps: with ps; [
              mkdocs
              mkdocs-material
              pymdown-extensions
            ]
          );

          hostTargets = import ./nix/host { inherit pkgs CHaP; };

          # The protocol registry (docs/inspector/protocols) is the same
          # tree cabal's `data-dir: ../../docs/inspector/protocols` bundles
          # into tx-deep-diagnosis. Package it standalone so an external
          # consumer (e.g. the csk workbench) can `nix build
          # .#protocol-registry` without vendoring the CLI or the repo.
          protocolRegistry = pkgs.runCommand "protocol-registry" { } ''
            mkdir -p "$out"
            cp -rL ${./docs/inspector/protocols}/. "$out/"
            chmod -R u+w "$out"
          '';

          txRdfCoreSrc = pkgs.fetchgit {
            url = expectedTxRdfCore.location;
            rev = expectedTxRdfCore.rev;
            hash = "sha256:${expectedTxRdfCore.sha256}";
          };

          txInspectorWithRdfSrc =
            pkgs.runCommand "wasm-tx-inspector-src-with-tx-rdf-core" { } ''
              mkdir -p "$out"
              cp -rL ${./libs/cardano-ledger-inspector}/. "$out/"
              chmod -R u+w "$out"
              mkdir -p "$out/external"
              cp -rL ${txRdfCoreSrc}/tx-rdf-core "$out/external/tx-rdf-core"
            '';

          wasmTargetsBase = import ./nix/wasm-targets.nix {
            inherit pkgs;
            libWasm = self.lib.wasm;
            ghcWasmMeta = ghc-wasm-meta.packages.${system}.all_9_12;
            wasiSdk = ghc-wasm-meta.packages.${system}.wasi-sdk;
            chap = CHaP;
            cardanoLedgerWasmSrc = cardanoLedgerWasm;
            smokeSrc = ./nix/wasm/smoke;
            ledgerSmokeSrc = ./nix/wasm/ledger-smoke;
            txInspectorSrc = txInspectorWithRdfSrc;
            extismSpikeSrc = ./.;
          };

          wasmTargets = wasmTargetsBase // {
            wasm-tx-inspector =
              wasmTargetsBase.wasm-tx-inspector.overrideAttrs
                (old: {
                  configurePhase = old.configurePhase + ''

                    # tx-rdf-core is an injected local path package for the
                    # WASI wrapper. The upstream builder's metadata-only
                    # prebuild strips module inventories and only purges local
                    # packages at version 0.1.0.0, so remove tx-rdf-core's
                    # metadata-only artifacts here and let Cabal rebuild it
                    # from the full source tree.
                    for pkg in $(find dist-newstyle/build -mindepth 3 -maxdepth 3 -type d \
                                   -path '*/wasm32-wasi/*' -name 'tx-rdf-core-0.4.0.0'); do
                      echo "purging tx-rdf-core metadata-only dist entry: $pkg"
                      rm -rf "$pkg"
                    done
                    find dist-newstyle -name 'package.conf.d' -exec sh -c '
                      for d; do
                        for entry in "$d"/tx-rdf-core-0.4.0.0-inplace*.conf; do
                          [ -e "$entry" ] && rm -f "$entry"
                        done
                      done
                    ' sh {} +
                  '';
                });
          };

          ledgerFunctionalOpenapiSpec = import ./nix/ledger-functional-openapi.nix;

          expectedCardanoLedgerWasm = {
            rev = "5897e8da1c043eb53cdafa6ada9782b56c74b18e";
            sha256 = "1x107phcsmn2g1zw0lm39nm064rpdw7ni9jim047s825f6b53rzx";
          };

          expectedTxRdfCore = {
            location = "https://github.com/lambdasistemi/cardano-ledger-rdf";
            rev = "1c2e893d114fe335548b9cd9ec3e8538254c3573";
            sha256 = "10h59pf6ns4psdr0p0n8z2799qbcs9824zim5pqasvyihyzpacg9";
          };

          expectedPlutusPin = {
            location = "https://github.com/lambdasistemi/plutus.git";
            rev = "dec7b4980f5f171a1e46c67dd3347240da2266cf";
          };

          cardano-ledger-wasm-pin-check =
            pkgs.runCommand "cardano-ledger-wasm-pin-check" { } ''
              set -euo pipefail

              fail=0

              require_file_contains() {
                local label="$1"
                local needle="$2"
                local file="$3"
                if ! ${pkgs.gnugrep}/bin/grep -F -- "$needle" "$file" >/dev/null; then
                  echo "missing $label: $needle" >&2
                  fail=1
                fi
              }

              require_equal() {
                local label="$1"
                local expected="$2"
                local actual="$3"
                if [ "$actual" != "$expected" ]; then
                  echo "$label mismatch" >&2
                  echo "  expected: $expected" >&2
                  echo "  actual:   $actual" >&2
                  fail=1
                fi
              }

              require_file_contains "cardano-ledger-wasm SRP location" \
                "location: https://github.com/lambdasistemi/cardano-ledger-wasm" \
                ${./cabal.project}
              require_file_contains "cardano-ledger-wasm SRP tag" \
                "tag: ${expectedCardanoLedgerWasm.rev}" \
                ${./cabal.project}
              require_file_contains "cardano-ledger-wasm SRP sha256" \
                "--sha256: ${expectedCardanoLedgerWasm.sha256}" \
                ${./cabal.project}
              require_file_contains "tx-rdf-core SRP location" \
                "location: ${expectedTxRdfCore.location}" \
                ${./libs/cardano-ledger-inspector/cabal-wasm.project}
              require_file_contains "tx-rdf-core SRP tag" \
                "tag: ${expectedTxRdfCore.rev}" \
                ${./libs/cardano-ledger-inspector/cabal-wasm.project}
              require_file_contains "tx-rdf-core SRP sha256" \
                "--sha256: ${expectedTxRdfCore.sha256}" \
                ${./libs/cardano-ledger-inspector/cabal-wasm.project}
              require_file_contains "tx-rdf-core WASI package path" \
                "external/tx-rdf-core" \
                ${./libs/cardano-ledger-inspector/cabal-wasm.project}

              require_equal "cardanoLedgerWasm flake input rev" \
                "${expectedCardanoLedgerWasm.rev}" \
                "${cardanoLedgerWasm.rev}"
              require_equal "Plutus fork location" \
                "${expectedPlutusPin.location}" \
                "${cardanoLedgerWasm.lib.wasm.forks.pins.plutus.location}"
              require_equal "Plutus fork rev" \
                "${expectedPlutusPin.rev}" \
                "${cardanoLedgerWasm.lib.wasm.forks.pins.plutus.rev}"

              if [ "$fail" -ne 0 ]; then
                exit "$fail"
              fi

              touch "$out"
            '';

          ledgerFunctionalOpenapiSource = pkgs.writeText
            "cardano-ledger-functional.openapi.raw.json"
            (builtins.toJSON ledgerFunctionalOpenapiSpec);

          ledger-functional-openapi-generated =
            pkgs.runCommand "ledger-functional-openapi-generated" { } ''
              mkdir -p $out
              ${pkgs.jq}/bin/jq --sort-keys . ${ledgerFunctionalOpenapiSource} \
                > $out/cardano-ledger-functional.openapi.json
            '';

          ledger-functional-openapi = pkgs.runCommand "ledger-functional-openapi" { } ''
            mkdir -p $out
            cp ${ledger-functional-openapi-generated}/cardano-ledger-functional.openapi.json \
              $out/cardano-ledger-functional.openapi.json
            cp ${./specs/001-ledger-functional-layer/schemas}/*.json $out/
          '';

          ledger-functional-openapi-check =
            pkgs.runCommand "ledger-functional-openapi-check" { } ''
              mkdir -p generated $out
              cp ${ledger-functional-openapi-generated}/cardano-ledger-functional.openapi.json \
                generated/cardano-ledger-functional.openapi.json
              ${pkgs.diffutils}/bin/diff -u \
                ${./specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json} \
                generated/cardano-ledger-functional.openapi.json
              touch $out/passed
            '';

          tx-identify-smoke = pkgs.runCommand "tx-identify-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.identify",
                args: {}
              }' > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.identify"
              and (.result.identification.tx_id | test("^[0-9a-f]{64}$"))
              and (.result.identification.body_hash | test("^[0-9a-f]{64}$"))
              and (.result.identification.tx_size_bytes > 0)
              and (.result.identification.fee_lovelace | test("^[0-9]+$"))
              and (.result.identification.witness_counts.vkey >= 0)
              and (.result.identification.witness_counts.bootstrap >= 0)
            ' response.json
            cp request.json response.json $out/
          '';

          tx-rdf-smoke = pkgs.runCommand "tx-rdf-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.rdf",
                args: {}
              }' > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response-1.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response-2.json
            ${pkgs.jq}/bin/jq -r '.result.rdf.turtle' response-1.json > turtle-1.ttl
            ${pkgs.jq}/bin/jq -r '.result.rdf.turtle' response-2.json > turtle-2.ttl
            ${pkgs.diffutils}/bin/diff -u turtle-1.ttl turtle-2.ttl
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.rdf"
              and .result.rdf.format == "text/turtle"
              and (.result.rdf.turtle | contains("@prefix cardano:"))
              and (.result.rdf.turtle | contains("cardano:Transaction"))
            ' response-1.json
            ${pkgs.jq}/bin/jq \
              '.op = "tx.rdf"' \
              ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > resolved-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < resolved-request.json > resolved-response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.rdf"
              and .result.rdf.format == "text/turtle"
              and (.result.rdf.turtle | contains("cardano:resolvedTo"))
              and (.result.rdf.turtle | contains("resolvedInput"))
            ' resolved-response.json
            ${pkgs.jq}/bin/jq \
              --arg from "1ef2797c28a7679ca8e62693642513a44bed07bc37cdef73d4cd29956b4f83a5" \
              --arg to "87daf43c764260d9ad00342fcb0d444c15752c9215f43c6b8e74189e7ba99397" \
              '.op = "tx.rdf"
                | .args.context.producer_txs[$from].tx_cbor =
                    .args.context.producer_txs[$to].tx_cbor' \
              ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > mismatched-producer-request.json
            if ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < mismatched-producer-request.json \
              > mismatched-producer-response.json \
              2> mismatched-producer-stderr.txt; then
              echo "mismatched producer CBOR unexpectedly succeeded" >&2
              exit 1
            fi
            ${pkgs.gnugrep}/bin/grep -F \
              "malformed_ledger_operation: producer_tx_id_mismatch" \
              mismatched-producer-stderr.txt
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex} \
              --rawfile blueprint ${./docs/inspector/protocols/sundaeswap-v3/plutus.json} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.rdf",
                args: {
                  blueprints: [
                    {
                      id: "sundaeswap-v3",
                      plutus_json: $blueprint
                    }
                  ]
                }
              }' > sundae-blueprint-request.json
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.rdf",
                args: {}
              }' > sundae-no-blueprint-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < sundae-blueprint-request.json > sundae-blueprint-response.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < sundae-no-blueprint-request.json > sundae-no-blueprint-response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.rdf"
              and (.result.rdf.turtle | contains(":OrderDatum_max_protocol_fee 1280000"))
            ' sundae-blueprint-response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.rdf"
              and (.result.rdf.turtle | contains(":OrderDatum_max_protocol_fee 1280000") | not)
            ' sundae-no-blueprint-response.json
            cp request.json response-1.json response-2.json turtle-1.ttl turtle-2.ttl \
              resolved-request.json resolved-response.json \
              mismatched-producer-request.json mismatched-producer-stderr.txt \
              sundae-blueprint-request.json sundae-blueprint-response.json \
              sundae-no-blueprint-request.json sundae-no-blueprint-response.json \
              $out/
          '';

          tx-witness-plan-smoke = pkgs.runCommand "tx-witness-plan-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.witness.plan",
                args: {}
              }' > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.witness.plan"
              and (.result.witness_plan.required_signers | type == "array")
              and (.result.witness_plan.present_vkey_witnesses | type == "array")
              and (.result.witness_plan.present_bootstrap_witnesses | type == "array")
              and (.result.witness_plan.missing_vkey_witnesses | type == "array")
              and (.result.witness_plan.scripts | type == "array")
              and (.result.witness_plan.redeemers | type == "array")
              and (.result.witness_plan.datums | type == "array")
              and (.result.witness_plan.reference_inputs | type == "array")
              and (.result.witness_plan.resolved_inputs | type == "array")
              and (.result.witness_plan.resolved_reference_inputs | type == "array")
              and .result.witness_plan.context.supplied == false
              and .result.witness_plan.context.producer_tx_count == 0
              and (.result.witness_plan.summary.required_signer_count >= 0)
              and (.result.witness_plan.summary.present_vkey_witness_count >= 0)
              and (.result.witness_plan.summary.missing_vkey_witness_count >= 0)
              and (.result.witness_plan.warnings | length >= 1)
            ' response.json
            cp request.json response.json $out/
          '';

          tx-witness-attach-smoke = pkgs.runCommand "tx-witness-attach-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"

            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.identify",
                args: {}
              }' > identify-original-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < identify-original-request.json > identify-original-response.json

            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              --arg witness "825820000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f5840202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f" \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.witness.attach",
                args: {
                  vkey_witness_cbor_hex: ($witness | gsub("\\s"; ""))
                }
              }' > attach-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < attach-request.json > attach-response.json

            ${pkgs.jq}/bin/jq -n \
              --slurpfile attach attach-response.json \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: $attach[0].result.witness_attachment.signed_tx_cbor_hex,
                op: "tx.identify",
                args: {}
              }' > identify-patched-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < identify-patched-request.json > identify-patched-response.json

            ${pkgs.jq}/bin/jq -n \
              --slurpfile attach attach-response.json \
              --arg witness "825820000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f5840202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f" \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: $attach[0].result.witness_attachment.signed_tx_cbor_hex,
                op: "tx.witness.attach",
                args: {
                  vkey_witness_cbor_hex: ($witness | gsub("\\s"; ""))
                }
              }' > reattach-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < reattach-request.json > reattach-response.json

            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.witness.attach",
                args: {}
              }' > missing-witness-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < missing-witness-request.json > missing-witness-response.json

            ${pkgs.jq}/bin/jq -e -s '
              .[0].result.identification as $before
              | .[1].result.witness_attachment as $attach
              | .[2].result.identification as $after
              | .[3].result.witness_attachment as $reattach
              | .[4].result.witness_attachment as $missing
              | .[1].ledger_functional_layer == "cardano-ledger-functional/v1"
              and .[1].op == "tx.witness.attach"
              and $attach.status == "applied"
              and $attach.witness_patch_action == "inserted"
              and ($attach.signed_tx_cbor_hex | test("^[0-9a-f]+$"))
              and ($attach.tx_id | test("^[0-9a-f]{64}$"))
              and ($attach.body_hash | test("^[0-9a-f]{64}$"))
              and ($attach.errors | length == 0)
              and ($attach.warnings | type == "array")
              and $after.tx_id == $before.tx_id
              and $after.body_hash == $before.body_hash
              and $after.witness_counts.vkey == ($before.witness_counts.vkey + 1)
              and $reattach.status == "applied"
              and $reattach.witness_patch_action == "replaced"
              and $reattach.signed_tx_cbor_hex == $attach.signed_tx_cbor_hex
              and $missing.status == "rejected"
              and ($missing.errors | type == "array")
              and ([$missing.errors[]? | select(.code == "missing_vkey_witness_cbor_hex")] | length == 1)
            ' \
              identify-original-response.json \
              attach-response.json \
              identify-patched-response.json \
              reattach-response.json \
              missing-witness-response.json
            cp identify-original-request.json identify-original-response.json \
              attach-request.json attach-response.json \
              identify-patched-request.json identify-patched-response.json \
              reattach-request.json reattach-response.json \
              missing-witness-request.json missing-witness-response.json \
              $out/
          '';

          tx-intent-smoke = pkgs.runCommand "tx-intent-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq '.op = "tx.intent"' \
              ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.intent"
              and any(.result.intent.metrics[]; .label == "Signer net ADA" and .value == "-5.900913 ADA")
              and .result.intent.sections[0].title == "Signer value perspective"
              and (.result.intent.withdrawals | type) == "array"
              and (.result.intent.withdrawals | length) == 0
              and (.result.intent.signing.required_signers | type) == "array"
              and (.result.intent.signing.required_signers | length) == 0
              and (.result.intent.signing.present_vkey_witnesses | type) == "array"
              and (.result.intent.signing.present_bootstrap_witnesses | type) == "array"
              and .result.intent.value.net_spend_known == true
              and .result.intent.value.signer_lovelace.known == true
              and .result.intent.value.signer_lovelace.net_lovelace == "-5900913"
              and any(.result.intent.value.resolved_input_buckets[]; .bucket == "signer_controlled" and .lovelace == "7015148761")
              and any(.result.intent.value.output_buckets[]; .bucket == "signer_controlled" and .lovelace == "7009247848")
              and any(.result.intent.value.output_buckets[]; .bucket == "script" and .tx_out_count == 4)
              and (.result.intent.scripts | type) == "array"
              and (.result.intent.scripts | length) == 1
              and any(
                .result.intent.scripts[];
                .purpose == "minting"
                and .index == 0
                and .ex_units_committed.memory == "376813"
                and .ex_units_committed.steps == "369524043"
                and (.redeemer_cbor_hex | length) > 0
                and (has("input") | not)
              )
              and (.result.intent.value.outputs | type) == "array"
              and (.result.intent.value.outputs | length) > 0
              and any(.result.intent.value.outputs[]; .assets != {})
              and any(
                .result.intent.value.outputs[];
                .assets["193ee65211bb3b4e0ea5f751f415269355a650e2e3706f625cdf1a4b"][""] == "1"
              )
            ' response.json
            cp request.json response.json $out/
          '';

          tx-input-context-smoke = pkgs.runCommand "tx-input-context-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.inspect",
                args: {}
              }' > inspect-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < inspect-request.json > inspect-response.json
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              --slurpfile inspect inspect-response.json \
              '$inspect[0].result.inspection as $inspection
              | ($inspection.inputs + $inspection.reference_inputs) as $inputs
              | ($inputs | map(.tx_id) | unique) as $producerTxIds
              | {
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.witness.plan",
                args: {
                  input_policy: "preserve",
                  context: {
                    producer_txs: (
                      $producerTxIds
                      | map({
                          key: .,
                          value: {
                            tx_cbor: ($tx | gsub("\\s"; "")),
                            source: "smoke.synthetic.current_tx_cbor"
                          }
                        })
                      | from_entries
                    ),
                    resolution: {
                      provider: "smoke",
                      source: "synthetic-producer-tx-cbor",
                      requested_input_count: ($inspection.inputs | length),
                      requested_reference_input_count: ($inspection.reference_inputs | length),
                      requested_tx_count: ($producerTxIds | length),
                      resolved_count: ($producerTxIds | length),
                      missing: [],
                      errors: [],
                      unspent_status: "not_checked"
                    }
                  }
                }
              }' > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response.json
            ${pkgs.jq}/bin/jq -e '
              .result.witness_plan as $plan
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.witness.plan"
              and $plan.context.input_policy == "preserve"
              and $plan.context.supplied == true
              and $plan.context.producer_tx_count > 0
              and $plan.context.decoded_producer_tx_count == $plan.context.producer_tx_count
              and $plan.context.complete == true
              and $plan.context.missing_input_count == 0
              and ($plan.resolved_inputs | length == $plan.context.input_count)
              and ([$plan.resolved_inputs[]? | select(.resolved != true)] | length == 0)
            ' response.json
            cp inspect-request.json inspect-response.json request.json response.json $out/
          '';

          tx-validate-smoke = pkgs.runCommand "tx-validate-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.validate",
                args: {
                  input_policy: "preserve",
                  context: {}
                }
              }' > missing-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < missing-context-request.json > missing-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.validate"
              and $v.status == "incomplete"
              and $v.valid_for_supplied_context == null
              and $v.complete == false
              and ($v.tx_id | test("^[0-9a-f]{64}$"))
              and ($v.body_hash | test("^[0-9a-f]{64}$"))
              and ($v.checks | type == "array")
              and ([$v.checks[]? | select(.id == "ledger.apply_tx" and .status == "not_evaluated")] | length == 1)
              and ($v.failures | type == "array")
              and ($v.failures | length == 0)
              and ($v.missing_context | type == "array")
              and ($v.missing_context | length >= 1)
              and ([$v.missing_context[]? | select(.kind == "source_output")] | length >= 1)
              and ($v.resolved_inputs | type == "array")
              and ($v.resolved_reference_inputs | type == "array")
              and $v.context.input_policy == "preserve"
              and $v.context.producer_tx_count == 0
              and (.result | has("tx_cbor") | not)
            ' missing-context-response.json

            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.validate",
                args: {
                  input_policy: "preserve",
                  context: {
                    utxo: {}
                  }
                }
              }' > malformed-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < malformed-context-request.json > malformed-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .op == "tx.validate"
              and $v.status == "rejected"
              and $v.valid_for_supplied_context == null
              and ($v.errors | type == "array")
              and ([$v.errors[]? | select(.code == "unsupported_utxo_json")] | length == 1)
              and ($v.failures | length == 0)
              and (.result | has("tx_cbor") | not)
            ' malformed-context-response.json

            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} > complete-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.validate"
              and $v.status == "valid"
              and $v.valid_for_supplied_context == true
              and $v.complete == true
              and ($v.errors | length == 0)
              and ($v.failures | length == 0)
              and ($v.missing_context | length == 0)
              and $v.context.complete == true
              and $v.context.resolved_input_count == $v.context.input_count
              and $v.context.resolved_reference_input_count == $v.context.reference_input_count
              and ([$v.checks[]? | select(.id == "ledger.apply_tx" and .status == "passed")] | length == 1)
              and (.result | has("tx_cbor") | not)
            ' complete-context-response.json

            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} > complete-context-response-2.json
            ${pkgs.jq}/bin/jq -s -e '
              .[0].result.validation == .[1].result.validation
            ' complete-context-response.json complete-context-response-2.json

            ${pkgs.jq}/bin/jq '.args.context.network = "testnet"' \
              ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > invalid-network-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < invalid-network-request.json > invalid-network-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .op == "tx.validate"
              and $v.status == "invalid"
              and $v.valid_for_supplied_context == false
              and $v.complete == true
              and ($v.errors | length == 0)
              and ($v.missing_context | length == 0)
              and ($v.failures | length > 0)
              and ([$v.checks[]? | select(.id == "ledger.apply_tx" and .status == "failed")] | length == 1)
              and (.result | has("tx_cbor") | not)
            ' invalid-network-response.json
            cp missing-context-request.json missing-context-response.json \
              malformed-context-request.json malformed-context-response.json \
              ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              complete-context-response.json complete-context-response-2.json \
              invalid-network-request.json invalid-network-response.json $out/
          '';

          tx-evaluate-scripts-smoke = pkgs.runCommand "tx-evaluate-scripts-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.evaluate.scripts",
                args: {
                  input_policy: "preserve",
                  context: {}
                }
              }' > missing-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < missing-context-request.json > missing-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.script_evaluation as $e
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.evaluate.scripts"
              and $e.status == "incomplete"
              and $e.scripts_evaluate_for_supplied_context == null
              and $e.complete == false
              and ($e.tx_id | test("^[0-9a-f]{64}$"))
              and ($e.body_hash | test("^[0-9a-f]{64}$"))
              and ($e.redeemers | type == "array")
              and ($e.redeemers | length >= 1)
              and ([$e.redeemers[]? | select(.status == "not_evaluated")] | length >= 1)
              and ([$e.redeemers[]? | select(.budget_ex_units.memory | test("^[0-9]+$"))] | length >= 1)
              and ($e.total_ex_units.memory | test("^[0-9]+$"))
              and ($e.total_ex_units.steps | test("^[0-9]+$"))
              and $e.total_ex_units.partial == true
              and ($e.failures | length == 0)
              and ($e.missing_context | length >= 1)
              and ([$e.missing_context[]? | select(.kind == "source_output")] | length >= 1)
              and ($e.resolved_inputs | type == "array")
              and ($e.resolved_reference_inputs | type == "array")
              and $e.context.input_policy == "preserve"
              and $e.context.producer_tx_count == 0
              and (.result | has("tx_cbor") | not)
            ' missing-context-response.json

            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.evaluate.scripts",
                args: {
                  input_policy: "preserve",
                  context: {
                    utxo: {}
                  }
                }
              }' > malformed-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < malformed-context-request.json > malformed-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.script_evaluation as $e
              | .op == "tx.evaluate.scripts"
              and $e.status == "rejected"
              and $e.scripts_evaluate_for_supplied_context == null
              and ($e.errors | type == "array")
              and ([$e.errors[]? | select(.code == "unsupported_utxo_json")] | length == 1)
              and ($e.failures | length == 0)
              and (.result | has("tx_cbor") | not)
            ' malformed-context-response.json

            cp ${./specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-complete-request.json} \
              complete-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < complete-context-request.json > complete-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.script_evaluation as $e
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.evaluate.scripts"
              and $e.status == "succeeded"
              and $e.scripts_evaluate_for_supplied_context == true
              and $e.complete == true
              and ($e.errors | length == 0)
              and ($e.failures | length == 0)
              and ($e.missing_context | length == 0)
              and ($e.redeemers | length >= 1)
              and ([$e.redeemers[]? | select(.status == "succeeded")] | length == ($e.redeemers | length))
              and ([$e.redeemers[]? | select(.evaluated_ex_units.memory | test("^[0-9]+$"))] | length == ($e.redeemers | length))
              and ($e.total_ex_units.memory | test("^[0-9]+$"))
              and ($e.total_ex_units.steps | test("^[0-9]+$"))
              and $e.total_ex_units.partial == false
              and $e.context.complete == true
              and $e.context.evaluated_redeemer_count == $e.context.redeemer_count
              and (.result | has("tx_cbor") | not)
            ' complete-context-response.json

            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < complete-context-request.json > complete-context-response-2.json
            ${pkgs.jq}/bin/jq -s -e '
              .[0].result.script_evaluation == .[1].result.script_evaluation
            ' complete-context-response.json complete-context-response-2.json

            cp missing-context-request.json missing-context-response.json \
              malformed-context-request.json malformed-context-response.json \
              complete-context-request.json complete-context-response.json \
              complete-context-response-2.json $out/
          '';

          # Spike: native Haskell host (libextism + Wasmtime) loads the
          # plugin and calls ledger operation exports against Conway
          # fixtures. The Extism exports delegate to the same
          # runLedgerOperationInput as the WASI reactor, so responses
          # are byte-identical to the WASI reactor for the same
          # envelope.
          # The host is in nix/host/extism-spike-host; libextism is the
          # prebuilt Rust runtime fetched from the upstream release.
          tx-extism-spike-smoke = pkgs.runCommand "tx-extism-spike-smoke" { } ''
            mkdir -p $out
            # Wasmtime writes a compile cache; sandbox HOME is unwritable.
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"

            HOST=${hostTargets.extism-spike-host}/bin/extism-spike-host
            WASM=${wasmTargets.wasm-extism-spike}/wasm-extism-spike.wasm

            # tx.identify
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.identify",
                args: {}
              }' > identify-request.json
            "$HOST" "$WASM" tx_identify \
              < identify-request.json > identify-response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.identify"
              and (.result.identification.tx_id | test("^[0-9a-f]{64}$"))
              and (.result.identification.body_hash | test("^[0-9a-f]{64}$"))
              and (.result.identification.tx_size_bytes > 0)
              and (.result.identification.fee_lovelace | test("^[0-9]+$"))
              and (.result.identification.witness_counts.vkey >= 0)
            ' identify-response.json

            # tx.validate - complete-context fixture (status=valid)
            "$HOST" "$WASM" tx_validate \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > validate-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.validate"
              and $v.status == "valid"
              and $v.valid_for_supplied_context == true
              and $v.complete == true
              and ($v.failures | length == 0)
              and ([$v.checks[]? | select(.id == "ledger.apply_tx" and .status == "passed")] | length == 1)
            ' validate-response.json

            # Conformance: Extism response on tx.validate is byte-identical
            # to the WASI reactor response on the same envelope.
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > wasi-validate-response.json
            ${pkgs.jq}/bin/jq -s -e '.[0] == .[1]' \
              validate-response.json wasi-validate-response.json

            # tx.evaluate.scripts - complete-context fixture (status=succeeded)
            "$HOST" "$WASM" tx_evaluate_scripts \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-complete-request.json} \
              > evaluate-scripts-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.script_evaluation as $e
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.evaluate.scripts"
              and $e.status == "succeeded"
              and $e.scripts_evaluate_for_supplied_context == true
              and $e.complete == true
              and ($e.failures | length == 0)
              and ([$e.redeemers[]? | select(.status == "succeeded")] | length == ($e.redeemers | length))
            ' evaluate-scripts-response.json

            # Conformance: Extism response on tx.evaluate.scripts is
            # byte-identical to the WASI reactor response on the same envelope.
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-complete-request.json} \
              > wasi-evaluate-scripts-response.json
            ${pkgs.jq}/bin/jq -s -e '.[0] == .[1]' \
              evaluate-scripts-response.json wasi-evaluate-scripts-response.json

            cp identify-request.json identify-response.json \
              validate-response.json wasi-validate-response.json \
              evaluate-scripts-response.json wasi-evaluate-scripts-response.json \
              $out/
          '';

          # Snapshot harness for the explain-artifact renderers. Walks
          # apps/tx-deep-diagnosis/test/golden/<case>/ and asserts each
          # produced artifact equals expected/<file> byte-for-byte. The
          # binary calls only pure renderers — no ledger / no network.
          tx-explain-render-smoke = pkgs.runCommand "tx-explain-render-smoke"
            { LANG = "C.UTF-8"; LC_ALL = "C.UTF-8"; } ''
            mkdir -p $out
            ${hostTargets.tx-deep-diagnosis-render-snapshot}/bin/tx-deep-diagnosis-render-snapshot \
              ${./apps/tx-deep-diagnosis/test/golden} \
              | tee $out/snapshot.log
          '';

          tx-deep-diagnosis-emit-explain-smoke =
            pkgs.runCommand "tx-deep-diagnosis-emit-explain-smoke"
              { LANG = "C.UTF-8"; LC_ALL = "C.UTF-8"; } ''
              mkdir -p $out/explain
              export HOME="$PWD"
              export XDG_CACHE_HOME="$PWD/.cache"
              mkdir -p "$XDG_CACHE_HOME"
              ${hostTargets.tx-deep-diagnosis}/bin/tx-deep-diagnosis \
                --cbor ${./specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex} \
                --network mainnet \
                --format explain \
                --emit-explain $out/explain \
                > response.md
              ${pkgs.gnugrep}/bin/grep -F "# Signing summary" response.md
              ${pkgs.gnugrep}/bin/grep -F "## Verdict" response.md
              ${pkgs.gnugrep}/bin/grep -F "<details><summary>Topology</summary>" \
                response.md
              test -f $out/explain/summary.md
              test -f $out/explain/explain.md
              test -f $out/explain/parties.mmd
              test -f $out/explain/value-flow.tsv
              test -f $out/explain/topology.mmd
              ${pkgs.gnugrep}/bin/grep -F "## Verdict" $out/explain/summary.md
              ${pkgs.gnugrep}/bin/grep -F "<details><summary>Topology</summary>" \
                $out/explain/explain.md
              cp response.md $out/
            '';

          # Fails closed if tx-deep-diagnosis's bundled data (populated at
          # build time from cabal's `data-dir: ../../docs/inspector/protocols`
          # + `data-files`) ever drifts from packages.protocol-registry.
          #
          # tx-deep-diagnosis's `data-files` is a DELIBERATE, curated subset
          # of the full registry tree -- registry.json plus the per-instance
          # pin/plutus/journal files `TxDeepDiagnosisHost.Registry` actually
          # parses at runtime. Prose docs (README.md, WORKED-EXAMPLE.md) and
          # RDF/SHACL artifacts (cardano-rdf/shapes.ttl,
          # amaru-treasury/overlay.ttl) are intentionally excluded -- they
          # have no CLI consumer today. Do NOT turn this into a bidirectional
          # `diff -r` between the CLI's data dir and packages.protocol-registry;
          # that would fail permanently on files that were never meant to
          # ship in the CLI. See specs/149-protocol-registry-flake-output/
          # for the acceptance-criteria tension this resolves.
          #
          # Two directions are checked instead:
          #   1. every file the CLI actually bundles must be byte-identical
          #      to the same relative path in packages.protocol-registry;
          #   2. every file registry.json's own manifest declares as CLI
          #      lookup data (blueprint/pin/deployment-registry paths) must
          #      actually be present in the CLI's installed data dir --
          #      catches a future registry.json entry whose data-files
          #      entry was forgotten in tx-deep-diagnosis.cabal.
          protocol-registry-drift-check =
            pkgs.runCommand "protocol-registry-drift-check"
              { nativeBuildInputs = [ pkgs.diffutils pkgs.findutils pkgs.jq ]; } ''
                set -euo pipefail
                cli_data_dir=$(find ${hostTargets.tx-deep-diagnosis.data} \
                  -type f -name registry.json -exec dirname {} \; | head -n1)
                if [ -z "$cli_data_dir" ]; then
                  echo "could not locate tx-deep-diagnosis's bundled registry.json" >&2
                  exit 1
                fi
                fail=0
                while IFS= read -r -d "" f; do
                  rel=''${f#"$cli_data_dir"/}
                  expected=${protocolRegistry}/"$rel"
                  if [ ! -f "$expected" ]; then
                    echo "drift: $rel is bundled by tx-deep-diagnosis but missing from packages.protocol-registry" >&2
                    fail=1
                    continue
                  fi
                  if ! cmp -s "$f" "$expected"; then
                    echo "drift: $rel differs between tx-deep-diagnosis's bundled data and packages.protocol-registry" >&2
                    fail=1
                  fi
                done < <(find "$cli_data_dir" -type f -print0)

                while IFS= read -r rel; do
                  if [ ! -f "$cli_data_dir/$rel" ]; then
                    echo "drift: registry.json declares $rel but tx-deep-diagnosis does not bundle it (add it to apps/tx-deep-diagnosis/tx-deep-diagnosis.cabal data-files)" >&2
                    fail=1
                  fi
                done < <(${pkgs.jq}/bin/jq -r '
                  ((.blueprints // [])[] | .path, .pin),
                  ((.deployment_registries // [])[] | .path, .pin)
                ' "$cli_data_dir/registry.json")
                [ "$fail" -eq 0 ] || exit 1
                touch $out
              '';
        in
        {
          packages = {
            inherit (wasmTargets)
              wasm-smoke wasm-ledger-smoke wasm-tx-inspector wasm-extism-spike;
            inherit (hostTargets) extism-spike-host libextism
              tx-deep-diagnosis tx-deep-diagnosis-render-snapshot;
            inherit
              ledger-functional-openapi
              ledger-functional-openapi-generated
              ;
            ledger-functional-swagger = ledger-functional-openapi;
            protocol-registry = protocolRegistry;
            default = wasmTargets.wasm-tx-inspector;
          };

          checks = {
            inherit
              ledger-functional-openapi-check
              tx-identify-smoke
              tx-rdf-smoke
              tx-witness-plan-smoke
              tx-witness-attach-smoke
              tx-intent-smoke
              tx-input-context-smoke
              tx-validate-smoke
              tx-evaluate-scripts-smoke
              tx-extism-spike-smoke
              tx-explain-render-smoke
              tx-deep-diagnosis-emit-explain-smoke
              cardano-ledger-wasm-pin-check
              protocol-registry-drift-check;
            ledger-functional-swagger-check = ledger-functional-openapi-check;
          };

          apps =
            let
              mkSmokeApp = name: smoke: pkgs.writeShellApplication {
                name = "${name}-runner";
                runtimeInputs = [ pkgs.coreutils ];
                text = ''
                  set -euo pipefail
                  echo "=== ${name} ==="
                  echo "smoke artifacts: ${smoke}"
                  if [ -f ${smoke}/request.json ]; then
                    echo "--- request.json ---"
                    cat ${smoke}/request.json
                  fi
                  echo
                  if [ -f ${smoke}/response.json ]; then
                    echo "--- response.json ---"
                    cat ${smoke}/response.json
                  fi
                '';
              };
              mkApp = drv: { type = "app"; program = pkgs.lib.getExe drv; };
              format = pkgs.writeShellApplication {
                name = "format";
                runtimeInputs = [
                  pkgs.haskellPackages.fourmolu
                  pkgs.findutils
                ];
                text = ''
                  find libs apps nix/wasm -type f -name '*.hs' \
                    -exec fourmolu -m inplace {} +
                '';
              };
              format-check = pkgs.writeShellApplication {
                name = "format-check";
                runtimeInputs = [
                  pkgs.haskellPackages.fourmolu
                  pkgs.findutils
                ];
                text = ''
                  find libs apps nix/wasm -type f -name '*.hs' \
                    -exec fourmolu -m check {} +
                '';
              };
              hlint = pkgs.writeShellApplication {
                name = "hlint";
                runtimeInputs = [
                  pkgs.haskellPackages.hlint
                ];
                text = ''
                  hlint libs apps nix/wasm
                '';
              };
            in
            {
              format = mkApp format;
              format-check = mkApp format-check;
              hlint = mkApp hlint;
              tx-identify-smoke =
                mkApp (mkSmokeApp "tx-identify-smoke" tx-identify-smoke);
              tx-witness-plan-smoke =
                mkApp (mkSmokeApp "tx-witness-plan-smoke" tx-witness-plan-smoke);
              tx-witness-attach-smoke =
                mkApp (mkSmokeApp "tx-witness-attach-smoke" tx-witness-attach-smoke);
              tx-intent-smoke =
                mkApp (mkSmokeApp "tx-intent-smoke" tx-intent-smoke);
              tx-validate-smoke =
                mkApp (mkSmokeApp "tx-validate-smoke" tx-validate-smoke);
              tx-evaluate-scripts-smoke =
                mkApp (mkSmokeApp "tx-evaluate-scripts-smoke" tx-evaluate-scripts-smoke);
              tx-input-context-smoke =
                mkApp (mkSmokeApp "tx-input-context-smoke" tx-input-context-smoke);
              tx-extism-spike-smoke =
                mkApp (mkSmokeApp "tx-extism-spike-smoke" tx-extism-spike-smoke);
              tx-explain-render-smoke =
                mkApp (mkSmokeApp "tx-explain-render-smoke" tx-explain-render-smoke);
              tx-deep-diagnosis-emit-explain-smoke =
                mkApp
                  (mkSmokeApp "tx-deep-diagnosis-emit-explain-smoke"
                    tx-deep-diagnosis-emit-explain-smoke);
              ledger-functional-openapi-check =
                mkApp (mkSmokeApp "ledger-functional-openapi-check"
                  ledger-functional-openapi-check);
              ledger-functional-swagger-check =
                mkApp (mkSmokeApp "ledger-functional-swagger-check"
                  ledger-functional-openapi-check);
            };

          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.just
              pkgs.wasmtime
              pkgs.jq
              pkgs.curl
              pkgs.nixfmt-rfc-style
              pkgs.haskellPackages.fourmolu
              pkgs.haskellPackages.hlint
              mkdocsEnv
            ];
          };
        };
    };
}
