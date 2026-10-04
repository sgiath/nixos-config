{
  services = {
    openclaw.gateway.enable = true;
    # Ceres's nightly desktop reaches this server over SSH and needs the same
    # orchestration protocol.
    t3code.channel = "nightly";
  };
}
