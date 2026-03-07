{ pkgs, lib, ... }:

let
  committerAgentsText = builtins.readFile ./AGENTS.md;
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
  agentsInstructions.ownFragments.committer = [ committerAgentsText ];
  agentsInstructions.mergedFragments = lib.mkAfter [ committerAgentsText ];

  packages = [ committer ];

  outputs.committer = committer;
}
