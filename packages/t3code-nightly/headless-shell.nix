# Chrome for Testing headless shell that T3 downloads into ~/.t3/tools for
# preview automation. ./update.sh pins the archive the nightly itself pins in
# apps/server/src/preview/PreviewBrowser.ts. The install checks use it to prove
# the wrappers' LD_LIBRARY_PATH covers every library the browser needs.
{
  lib,
  stdenv,
  fetchurl,
}:

let
  sources = lib.importJSON ./sources.json;
  platform =
    {
      x86_64-linux = "linux64";
      aarch64-linux = "linux-arm64";
    }
    .${stdenv.hostPlatform.system};
in
fetchurl {
  url = "https://storage.googleapis.com/chrome-for-testing-public/${sources.headlessShellVersion}/${platform}/chrome-headless-shell-${platform}.zip";
  hash = sources.${stdenv.hostPlatform.system}.headlessShell;
}
