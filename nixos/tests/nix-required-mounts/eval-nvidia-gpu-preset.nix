{
  evalSystem,
  runCommand,
  lib,
  ...
}:
let
  machine = evalSystem (
    { lib, ... }:
    {
      services.userborn.enable = true;
      hardware.graphics.enable = true;
      programs.nix-required-mounts = {
        enable = true;
        presets.nvidia-gpu.enable = true;
      };
      fileSystems."/".device = "/dev/null";
      boot.loader.grub.enable = false;
      system.stateVersion = lib.trivial.release;
    }
  );

  cfg = machine.config;
  driverSearchPath = cfg.hardware.graphics.driverSearchPath;
  tmpfilesTarget = cfg.systemd.tmpfiles.settings.graphics-driver."/run/opengl-driver"."L+".argument;
  nvidiaPaths = cfg.programs.nix-required-mounts.allowedPatterns.nvidia-gpu.paths;
in

assert toString driverSearchPath == tmpfilesTarget;
assert lib.any (p: p == driverSearchPath) nvidiaPaths;

runCommand "nix-required-mounts-eval-test" { } ''
  touch $out
''
