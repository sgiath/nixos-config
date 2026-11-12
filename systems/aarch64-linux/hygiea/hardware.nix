# OCI VM.Standard.A1.Flex (Ampere, aarch64): UEFI, paravirtualized (virtio)
# boot volume and NIC, DHCP from the VCN. Kernel parameters and NTP follow
# nixpkgs' virtualisation/oci-common.nix, which is not imported because it
# fixes its own filesystems and GRUB layout against disko.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nixpkgs.hostPlatform = "aarch64-linux";

  boot = {
    loader = {
      # No EFI variables: bootctl also installs the removable-media fallback
      # path the OCI firmware boots.
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = false;
    };
    # VNC console and the serial console in the OCI console connection.
    kernelParams = [
      "console=tty1"
      "console=ttyAMA0,115200"
    ];
  };

  networking = {
    useNetworkd = true;
    useDHCP = true;
    # Link-local OCI NTP service.
    timeServers = [ "169.254.169.254" ];
  };
}
