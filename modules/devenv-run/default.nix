{ pkgs, lib, options, ... }:

let
  devenvRun = pkgs.writeShellApplication {
    name = "devenv-run";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.devenv
      pkgs.findutils
      pkgs.gawk
    ];
    text = builtins.readFile ./devenv-run.sh;
  };
in
{
  config = lib.mkMerge [
    {
      packages = [ devenvRun ];

      outputs.devenv-run = devenvRun;
    }
    (lib.optionalAttrs (options ? instructions && options.instructions ? instructions) {
      instructions.instructions = lib.mkOrder 300 [ (builtins.readFile ./AGENTS.md) ];
    })
  ];
}
