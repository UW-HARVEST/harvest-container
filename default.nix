# Pin nixpkgs so the T&E image is reproducible regardless of the channel the
# base image happens to ship. Bump the rev/hash together when updating.
# This is a pinned nixpkgs-unstable rev: it ships claude-code 2.1.154, which
# defaults to the latest Opus (claude-opus-4-8); the 25.11/26.05 stable
# channels still default to opus-4-7. allowUnfree is required because
# claude-code is distributed under an unfree license.
{ pkgs ? import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/e9a7635a57597d9754eccebdfc7045e6c8600e6b.tar.gz";
    sha256 = "sha256-u6WU/yd/o8iYQrHX3RAwO1hYa3LkoSL+WNQD0rJfJZQ=";
  }) { config.allowUnfree = true; } }:

let
  # The HARVEST translation binary. Pinned to the june-te branch (the June T&E
  # experiment: the optional clar test oracle, plus the translate-prompt fix that
  # makes the agent finish the whole codebase in one run instead of stopping at a
  # foundation milestone). Built against the same pinned nixpkgs as everything else.
  harvest-code = import (pkgs.fetchFromGitHub {
    owner = "UW-HARVEST";
    repo = "harvest";
    rev = "1680e6b7db34d6d1b88049b96d0cdf2d3dce1959";
    hash = "sha256-djPjZiqieSYW4nqji4VCvfeqPoE0jLxicKFehFWLn3w=";
  }) { inherit pkgs; };

  # Tools the agentic Claude agent invokes from its own shell while it builds
  # and tests the translated crate. (HARVEST's own C parsing happens inside the
  # `translate` binary, which harvest-code already wraps with CLANG_PATH.)
  agentRuntime = [
    pkgs.cargo
    pkgs.rustc
    pkgs.gcc            # provides `cc`, the linker rustc drives
    pkgs.binutils
    pkgs.pkg-config
    pkgs.cmake          # the clar harness (and many C projects) build via CMake
    pkgs.gnumake        # cmake's default generator backend
    pkgs.python3        # clar's generate.py emits the test suite
    pkgs.git
    pkgs.cacert         # TLS roots for cargo fetches and the Anthropic API
    pkgs.coreutils-full # provides `timeout`, the agent budget wrapper
  ];

  translate = pkgs.stdenv.mkDerivation rec {
    name = "harvest-translation";
    src = ./.;
    buildInputs = [ harvest-code pkgs.claude-code pkgs.pkg-config pkgs.llhttp pkgs.zlib pkgs.pcre2 pkgs.cmake pkgs.python3 pkgs.openssl ] ++ agentRuntime;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # cmake is only needed on the agent's runtime PATH (via makeBinPath below),
    # not to build this wrapper. Suppress cmake's setup hook, which would
    # otherwise try to cmake-configure our source (which has no CMakeLists.txt).
    dontUseCmakeConfigure = true;
    installPhase = ''
      mkdir -p $out/bin
      cp $src/translate.sh $out/bin/translate-wrapper
      wrapProgram $out/bin/translate-wrapper \
        --prefix PATH : ${pkgs.lib.makeBinPath buildInputs} \
        --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    '';
  };
in pkgs.stdenv.mkDerivation rec {
  name = "s3_wrapper";
  src = ./.;
  buildInputs = [
    translate
    (pkgs.python3.withPackages (p: [ p.boto3 ]))
    pkgs.coreutils-full
  ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin
    cp $src/s3_wrapper.py $out/bin/s3_wrapper.py
    chmod +x $out/bin/s3_wrapper.py
    wrapProgram $out/bin/s3_wrapper.py --prefix PATH : ${pkgs.lib.makeBinPath buildInputs}
  '';
}
