{ lib, package }:
{
  programs.codex = {
    enable = lib.mkEnableOption "Codex, OpenAI's terminal coding agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = package;
      description = "Codex package to install.";
    };
  };
}
