{ pkgs, lib, options, ... }:

let
  committer = pkgs.writeShellApplication {
    name = "committer";
    runtimeInputs = [
      pkgs.git
      pkgs.gnugrep
      pkgs.prek
    ];
    text = builtins.readFile ./committer.sh;
  };
in
{
  config = lib.mkMerge [
    {
      packages = [ committer ];

      outputs.committer = committer;
    }
    (lib.optionalAttrs (options ? instructions && options.instructions ? instructions) {
      instructions.instructions = lib.mkOrder 200 [ (builtins.readFile ./AGENTS.md) ];
    })
  ];
}
