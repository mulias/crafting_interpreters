{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  unstable = import <unstable> {};
in

mkShell {
  buildInputs = [ unstable.ruby unstable.rufo ];
  shellHook = ''
    export NVIM_RUFO_LSP=true
  '';
}
