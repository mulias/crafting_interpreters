{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  unstable = import <unstable> {};
in

mkShell {
  buildInputs = [
    unstable.zig
    unstable.zls
  ];
  shellHook = ''
    export NVIM_ZIG_LSP=true
  '';
}
