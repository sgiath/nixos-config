# Nebula for the original JetKVM (Rockchip RV1106: armv7 hard-float, BusyBox):
# the version the NixOS hosts run, cross-built without PKCS#11, which leaves
# cgo off. Nix's cross Go still links externally against glibc, so force the
# internal linker for a static binary. scripts/nebula-jetkvm.sh installs it.
{ pkgsCross }:
(pkgsCross.armv7l-hf-multiplatform.nebula.override { withPkcs11 = false; }).overrideAttrs (old: {
  ldflags = old.ldflags ++ [ "-linkmode=internal" ];
})
