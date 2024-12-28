{ pkgs, ... }:
let
  beamPackages = pkgs.beam_minimal.packages.erlang_27;
  erlang = beamPackages.erlang;
  elixir = beamPackages.elixir_1_18;
in 
{
  imports = [ ./hardware.nix ];

  networking.hostName = "ceres";

  sgiath = {
    enable = true;
    gpu = "amd";
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    xamond.enable = true;
    printing.enable = true;
    razer.enable = false;
    wayland.enable = true;
  };

  crazyegg.enable = true;

  services = {
    ollama.enable = true;

    livebook = {
      enableUserService = true;
      environmentFile = "/var/lib/livebook.env";
      package = pkgs.livebook.override {
        inherit beamPackages erlang elixir;
      };
    };
  };

  programs = {
    gamescope.enable = true;
    gamemode.enable = true;
    steam = {
      enable = true;
      protontricks.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };
  };

  # users.users.sgiath.extraGroups = [ "libvirtd" ];
  # virtualisation.libvirtd = {
  #   enable = true;
  #   qemu = {
  #     package = pkgs.qemu_kvm;
  #     runAsRoot = true;
  #     swtpm.enable = true;
  #     ovmf = {
  #       enable = true;
  #       packages = [
  #         (pkgs.OVMF.override {
  #           secureBoot = true;
  #           tpmSupport = true;
  #         }).fd
  #       ];
  #     };
  #   };
  # };
}
