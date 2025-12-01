{ pkgs ? import <nixpkgs> { }}:

let
  translate = pkgs.stdenv.mkDerivation rec {
    name = "harvest-translation";
    src = ./.;
    buildInputs = [
      harvest-code
      pkgs.coreutils-full
    ];
    nativeBuildInputs = [
      pkgs.makeWrapper
    ];
    PATH = pkgs.lib.makeBinPath buildInputs;
    installPhase = ''
      mkdir -p $out/bin
      cp $src/translate.sh $out/bin/translate
      wrapProgram $out/bin/translate --prefix PATH : ${pkgs.lib.makeBinPath buildInputs }
    '';
  };
  harvest-code = import (pkgs.fetchFromGitHub {
      owner = "betterbytes-org";
      repo = "harvest-code";
      rev = "fa788c7d3f27013b8aeef953181ab962396c2ab6";
      hash = "sha256-2vdcIOZ52RCbJ1xqNUQN4tmNQsNCigxxLgyxnoV9bAw=";
  }) {};
in pkgs.stdenv.mkDerivation rec {
    name = "s3_wrapper";
    src = ./.;
    buildInputs = [
      translate (pkgs.python3.withPackages (p: [ p.boto3 ]))
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
