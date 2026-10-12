{
  imports = [ ./crazyegg.nix ];

  # Same CrazyEgg development environment as Ceres; the desktop apps stay behind
  # the desktop role.
  sgiath.work.crazyegg.enable = true;

  services = {
    openclaw.gateway.enable = true;
    # Ceres's nightly desktop reaches this server over SSH and needs the same
    # orchestration protocol.
    t3code.channel = "nightly";
  };
}
