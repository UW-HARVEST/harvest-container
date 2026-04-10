{ pkgs ? import <nixpkgs> { }}:

let
  translate = pkgs.stdenv.mkDerivation rec {
    name = "harvest-translation";
    src = ./.;
    buildInputs = [
      harvest-code
      kiro-cli
      pkgs.coreutils-full
    ];
    nativeBuildInputs = [
      pkgs.makeWrapper
    ];
    PATH = pkgs.lib.makeBinPath buildInputs;
    installPhase = ''
      mkdir -p $out/bin
      cp $src/translate.sh $out/bin/translate-wrapper
      wrapProgram $out/bin/translate-wrapper --prefix PATH : ${pkgs.lib.makeBinPath buildInputs }
    '';
  };
  harvest-code = import (pkgs.fetchFromGitHub {
      owner = "UW-Harvest";
      repo = "harvest";
      rev = "april15te";
      hash = "sha256-04YKZolqV8znxwlPVJBpKXnFsZogekmGkywGefrh4XQ=";
  }) {};
  kiro-cli = pkgs.stdenv.mkDerivation rec {
    name = "kiro-cli";
    src = builtins.fetchTarball {
      url = "https://prod.download.cli.kiro.dev/stable/1.29.6/kirocli-x86_64-linux-musl.tar.gz";
      sha256 = "079c583ilcrgvladccivgcw0pa6jmqmfkgg37034qd6ckqmkipnl";
    };
    buildInputs = [
    ];
    nativeBuildInputs = [
      pkgs.makeWrapper
    ];
    PATH = pkgs.lib.makeBinPath buildInputs;
    installPhase = ''
      mkdir -p $out/bin
      cp $src/bin/* $out/bin/
      wrapProgram $out/bin/kiro-cli --set OPENSSL_DIR "${pkgs.openssl.dev}";
      wrapProgram $out/bin/kiro-cli-chat --set OPENSSL_DIR "${pkgs.openssl.dev}";
    '';
  };
in pkgs.stdenv.mkDerivation rec {
    name = "s3_wrapper";
    src = ./.;
    buildInputs = [
      translate (pkgs.python3.withPackages (p: [ p.boto3 ]))
      pkgs.openssl
      pkgs.openssl.dev
      pkgs.pkg-config
    ];
    nativeBuildInputs = [
      pkgs.makeWrapper
    ];
    installPhase = ''
      mkdir -p $out/bin
      cp $src/s3_wrapper.py $out/bin/s3_wrapper.py
      wrapProgram $out/bin/s3_wrapper.py --prefix PATH : ${pkgs.lib.makeBinPath buildInputs }
    '';
  }
