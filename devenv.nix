{ lib, options, ... }:

{
  imports = [
    ./modules/committer
    ./modules/devenv-run
  ];

  config = lib.optionalAttrs (options ? instructions && options.instructions ? instructions) {
    instructions.instructions = lib.mkOrder 100 [
      (builtins.readFile ./AGENTS.md)
    ];
  };
}
