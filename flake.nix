{
  description = "Cardano ledger operations compiled to WASI";

  nixConfig = {
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys =
      [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
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
    purescript-overlay = {
      url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mkSpagoDerivation = {
      url = "github:jeslie0/mkSpagoDerivation";
      inputs.nixpkgs.follows = "nixpkgs";
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
    , purescript-overlay
    , mkSpagoDerivation
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      flake = {
        lib.wasm = import ./nix/wasm { lib = nixpkgs.lib; };
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

          psPkgs = import nixpkgs {
            inherit system;
            overlays = [
              purescript-overlay.overlays.default
              mkSpagoDerivation.overlays.default
            ];
          };

          mkdocsEnv = pkgs.python3.withPackages (
            ps: with ps; [
              mkdocs
              mkdocs-material
              pymdown-extensions
            ]
          );

          wasmTargets = import ./nix/wasm-targets.nix {
            inherit pkgs;
            libWasm = self.lib.wasm;
            ghcWasmMeta = ghc-wasm-meta.packages.${system}.all_9_12;
            wasiSdk = ghc-wasm-meta.packages.${system}.wasi-sdk;
            chap = CHaP;
            smokeSrc = ./nix/wasm/smoke;
            ledgerSmokeSrc = ./nix/wasm/ledger-smoke;
            txInspectorSrc = ./nix/wasm/tx-inspector;
          };

          tx-inspector-ui = import ./nix/wasm-ui.nix {
            inherit system nixpkgs purescript-overlay mkSpagoDerivation;
            wasmArtifact = wasmTargets.wasm-tx-inspector;
            wasmArtifactName = "wasm-tx-inspector";
            src = ./docs/inspector;
          };

          ledgerFunctionalOpenapiSpec = import ./nix/ledger-functional-openapi.nix;

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
        in
        {
          packages = {
            inherit (wasmTargets) wasm-smoke wasm-ledger-smoke wasm-tx-inspector;
            inherit
              ledger-functional-openapi
              ledger-functional-openapi-generated
              tx-inspector-ui
              ;
            ledger-functional-swagger = ledger-functional-openapi;
            default = tx-inspector-ui;
          };

          checks = {
            inherit ledger-functional-openapi-check;
            ledger-functional-swagger-check = ledger-functional-openapi-check;
          };

          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.just
              pkgs.wasmtime
              pkgs.jq
              pkgs.curl
              pkgs.nixfmt-rfc-style
              pkgs.haskellPackages.fourmolu
              mkdocsEnv
              psPkgs.purs
              psPkgs.spago-unstable
              psPkgs.esbuild
              psPkgs.nodejs_20
            ];
          };
        };
    };
}
