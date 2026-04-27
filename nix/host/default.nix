# Native (not wasm) host program for the Extism PDK spike.
#
# Builds extism-spike-host with the Haskell `extism` Hackage SDK, which
# links libextism — the Rust + Wasmtime runtime that supports wasm
# tail-calls (unlike the wazero embedded in pkgs.extism-cli).
{ pkgs }:

let
  libextism = pkgs.callPackage ./libextism.nix { };

  haskellPackages = pkgs.haskellPackages.override {
    overrides = self: super: {
      # nixpkgs marks `extism` and `extism-manifest` as broken because
      # libextism isn't packaged there. Override with our libextism +
      # clear the broken flag.
      extism-manifest = pkgs.haskell.lib.compose.doJailbreak
        (pkgs.haskell.lib.compose.overrideCabal
          (_: { broken = false; })
          super.extism-manifest);

      extism = pkgs.haskell.lib.compose.dontCheck
        (pkgs.haskell.lib.compose.doJailbreak
          (pkgs.haskell.lib.compose.overrideCabal
            (drv: {
              broken = false;
              librarySystemDepends =
                (drv.librarySystemDepends or [ ]) ++ [ libextism ];
              libraryPkgconfigDepends =
                (drv.libraryPkgconfigDepends or [ ]) ++ [ libextism ];
            })
            super.extism));
    };
  };

  extism-spike-host = haskellPackages.callCabal2nix
    "extism-spike-host"
    ./extism-spike-host
    { };
in
{
  inherit libextism extism-spike-host;
}
