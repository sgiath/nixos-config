{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    ./disko.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      kernelModules = [
        "atlantic"
        "igc"
      ];
      availableKernelModules = [
        "nvme"
        "thunderbolt"
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
    };
    # FIXME: nixpkgs adds its tools 128-bit types backport to XanMod main,
    # but XanMod 7.3 already contains it, so patching fails in the kernel and
    # cpupower builds. Drop once the selected nixpkgs omits it for 7.3+ as it
    # does for mainline linux_7_3; see
    # UPSTREAM-WORKAROUNDS.md#xanmod-tools-128bit-types-duplicate.
    kernelPackages = pkgs.linuxPackagesFor (
      pkgs.linux_xanmod_latest.override (old: {
        kernelPatches =
          if pkgs.linux_xanmod_latest.kernelAtLeast "7.3" then
            lib.filter (
              patch: patch.name != pkgs.linuxKernel.kernelPatches.tools_128bit_types.name
            ) old.kernelPatches
          else
            old.kernelPatches;
      })
    );
    # AMD Zen sensors
    extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    kernelParams = [ "amd_pstate=active" ];

    # Docker and Podman create and delete host-side veths constantly. Each
    # kernel-generated link-local address on them makes Chromium report a
    # network change (ERR_NETWORK_CHANGED in open tabs). New interfaces get
    # no automatic IPv6 addresses; the Ethernet ports keep link-local and
    # SLAAC. Explicit addresses (Nebula, the static ULAs) are unaffected.
    # FIXME: A new physical NIC needs its own addr_gen_mode = 0 entry below;
    # replace this policy with per-link handling if Ceres needs hotplug NICs.
    kernel.sysctl = {
      "net.ipv6.conf.default.addr_gen_mode" = 1;
      "net.ipv6.conf.enp57s0.addr_gen_mode" = 0;
      "net.ipv6.conf.enp59s0.addr_gen_mode" = 0;
    };

    # Windows 11 boot
    # loader.systemd-boot.edk2-uefi-shell.enable = true;
    loader.systemd-boot.windows."11".efiDeviceHandle = "HD1b";
  };

  services = {
    nfs.server.enable = false;
    fstrim.enable = true;
  };

  networking = {
    useDHCP = false;
    interfaces = {
      # 10G Aquantia, atlantic
      enp57s0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.1.6";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = "fd39:f21:ea9::6";
            prefixLength = 64;
          }
        ];
      };

      # 2.5G Intel I225-V, igc
      enp59s0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.1.7";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = "fd39:f21:ea9::7";
            prefixLength = 64;
          }
        ];
      };
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
