{ lib, ... }:
{
  options.sgiath.bitcoin = {
    enable = lib.mkEnableOption "bitcoin";
  };

  config = {
    nix-bitcoin.secretsSetupMethod = "manual";
  };
}
