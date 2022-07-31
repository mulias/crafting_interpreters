{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  unstable = import <unstable> {};
in

mkShell {
  buildInputs = [
    unstable.rubyPackages_3_1.ffi
    unstable.ruby_3_1
    unstable.rufo
  ];
  shellHook = ''
    export NVIM_RUFO_LSP=true

    bundle_install () {
      bundle binstubs --all
    }

    export PATH="./bin:$PATH"
  '';
}
