# Prebuilt libextism (Rust + Wasmtime) — fetched from the upstream
# release because nixpkgs does not package the C runtime, only the Go
# CLI. The Haskell `extism` Hackage package links this at build time.
#
# The runtime is what bakes in the wasm proposals supported by the
# host. v1.21.0 ships Wasmtime 41, which has tail-call support — the
# missing feature in nixpkgs's wazero-based extism-cli that traps the
# spike plugin during hs_init.
{ lib, stdenv, fetchurl, autoPatchelfHook, gcc-unwrapped }:

let
  version = "1.21.0";
  source = {
    "x86_64-linux" = {
      tag = "x86_64-unknown-linux-gnu";
      sha256 = "d1b768c192cb2818b8d7f75eb0eab0ddc3d67eb2d77452abeeb29b3363d22dd0";
    };
    "aarch64-linux" = {
      tag = "aarch64-unknown-linux-gnu";
      sha256 = lib.fakeSha256;
    };
    "aarch64-darwin" = {
      tag = "aarch64-apple-darwin";
      sha256 = lib.fakeSha256;
    };
    "x86_64-darwin" = {
      tag = "x86_64-apple-darwin";
      sha256 = lib.fakeSha256;
    };
  }.${stdenv.hostPlatform.system} or (throw
    "libextism: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "libextism";
  inherit version;

  src = fetchurl {
    url =
      "https://github.com/extism/extism/releases/download/v${version}/"
      + "libextism-${source.tag}-v${version}.tar.gz";
    sha256 = source.sha256;
  };

  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux gcc-unwrapped.lib;

  unpackPhase = ''
    runHook preUnpack
    mkdir -p source
    tar -xzf $src -C source
    cd source
    runHook postUnpack
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/include $out/lib/pkgconfig

    install -m644 extism.h $out/include/
    install -m755 libextism.${if stdenv.hostPlatform.isDarwin then "dylib" else "so"} \
      $out/lib/ 2>/dev/null \
      || install -m755 libextism.so $out/lib/
    install -m644 libextism.a $out/lib/

    substitute extism.pc.in $out/lib/pkgconfig/extism.pc \
      --replace-fail '@CMAKE_INSTALL_PREFIX@' "$out"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Extism runtime (Rust, Wasmtime-backed) — prebuilt";
    homepage = "https://extism.org";
    license = licenses.bsd3;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
