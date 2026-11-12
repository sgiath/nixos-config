# Nebula for the original JetKVM (Rockchip RV1106: armv7 hard-float, BusyBox):
# the version the NixOS hosts run, cross-built without PKCS#11, which leaves
# cgo off and the binary static. scripts/nebula-jetkvm.sh installs it.
{ pkgsCross }:
pkgsCross.armv7l-hf-multiplatform.nebula.override { withPkcs11 = false; }
