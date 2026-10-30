{
  imports = [ ./crazyegg.nix ];

  # Same CrazyEgg development environment as Ceres; the desktop apps stay behind
  # the desktop role.
  sgiath.work.crazyegg = {
    enable = true;
    # Ceres refreshes at :00; see modules/home/work/aws.nix.
    awsRefreshMinute = 30;
  };

  services = {
    openclaw.gateway.enable = true;
    t3code.channel = "nightly";
  };
}
