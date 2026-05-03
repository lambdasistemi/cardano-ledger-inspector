{ CHaP, pkgs }:

let
  fix-libs = { lib, pkgs, ... }: {
    packages.cardano-crypto-praos.components.library.pkgconfig =
      lib.mkForce [ [ pkgs.libsodium-vrf ] ];
    packages.cardano-crypto-class.components.library.pkgconfig =
      lib.mkForce [ [ pkgs.libsodium-vrf pkgs.secp256k1 pkgs.libblst ] ];
  };

  project = pkgs.haskell-nix.cabalProject' {
    name = "tx-deep-diagnosis-native";
    src = ./../../..;
    compiler-nix-name = "ghc984";
    modules = [ fix-libs ];
    inputMap = { "https://chap.intersectmbo.org/" = CHaP; };
  };
in
{
  inherit project;
  tx-deep-diagnosis =
    project.hsPkgs.tx-deep-diagnosis.components.exes.tx-deep-diagnosis;
  tx-deep-diagnosis-render-snapshot =
    project.hsPkgs.tx-deep-diagnosis.components.exes.tx-deep-diagnosis-render-snapshot;
}
