{ pkgs, lib, ... }:

let
  committer = pkgs.writeShellApplication {
    name = "committer";
    runtimeInputs = [
      pkgs.git
      pkgs.gnugrep
    ];
    text = builtins.readFile ./committer.sh;
  };
in
{
  options.instructions.fragments = lib.mkOption {
    type = with lib.types; listOf str;
    default = [];
    description = "Shared instruction text fragments that modules can add.";
  };

  config = {
    instructions.fragments = lib.mkBefore [ (builtins.readFile ./AGENTS.md) ];

    packages = [ committer ];

    outputs.committer = committer;
  };
}
