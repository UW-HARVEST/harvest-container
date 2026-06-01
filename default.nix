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
  # The HARVEST translation binary. Pinned to a specific commit on main and
  # built against the same pinned nixpkgs as everything else.
  harvest-code = import (pkgs.fetchFromGitHub {
    owner = "UW-HARVEST";
    repo = "harvest";
    rev = "5214d76c0f017b7a0ccf8231bcaa83f0ee911281";
    hash = "sha256-IBihlttfGzNcLoSeIC+K9N1nbpNnjHHNvXu0Sc57mWE=";
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
    pkgs.git
    pkgs.cacert         # TLS roots for cargo fetches and the Anthropic API
    pkgs.coreutils-full # provides `timeout`, the agent budget wrapper
  ];

  translate = pkgs.stdenv.mkDerivation rec {
    name = "harvest-translation";
    src = ./.;
    buildInputs = [ harvest-code pkgs.claude-code ] ++ agentRuntime;
    nativeBuildInputs = [ pkgs.makeWrapper ];
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
