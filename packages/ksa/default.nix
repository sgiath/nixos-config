# https://github.com/Aetherall/ksa
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  icu,
  libx11,
  libxcursor,
  libxinerama,
  libxi,
  libxrandr,
  libGL,
  libglvnd,
  wayland,
  libxkbcommon,
  vulkan-headers,
  vulkan-loader,
  libpulseaudio,
  alsa-lib,
}:
let
  vkFixSwapchain = stdenv.mkDerivation {
    pname = "vk-fix-swapchain";
    version = "0.1.0";
    src = ./.;

    nativeBuildInputs = [ vulkan-headers ];
    buildInputs = [ vulkan-loader ];

    buildPhase = ''
      $CC -shared -fPIC -o libVkLayer_ksa_fix_swapchain.so \
        vk_fix_swapchain.c \
        -I${vulkan-headers}/include \
        -lvulkan
    '';

    installPhase = ''
      mkdir -p $out/lib $out/share/vulkan/implicit_layer.d
      cp libVkLayer_ksa_fix_swapchain.so $out/lib/
      substitute VkLayer_ksa_fix_swapchain.json \
        $out/share/vulkan/implicit_layer.d/VkLayer_ksa_fix_swapchain.json \
        --replace-fail "@lib_path@" "$out/lib/libVkLayer_ksa_fix_swapchain.so"
    '';
  };
in
stdenv.mkDerivation rec {
  pname = "ksa";
  version = "2026.2.18.3622";

  src = fetchurl {
    url = "https://ksa-linux.ahwoo.com/download?file=setup_ksa_v${version}.tar";
    hash = "sha256-ffMHPXQnAFGWpoHbyWqEVwToabsIn88BO+1/bAFY6wI=";
  };

  sourceRoot = ".";
  unpackCmd = "tar xf $curSrc";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++
    vulkan-loader
  ];

  # Libraries that are dlopen'd at runtime by the .NET runtime, bundled glfw, and fmod
  runtimeDeps = [
    icu
    libx11
    libxcursor
    libxinerama
    libxi
    libxrandr
    libGL
    libglvnd
    wayland
    libxkbcommon
    vulkan-loader
    libpulseaudio
    alsa-lib
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/ksa
    cp -r linux-x64/* $out/opt/ksa/

    mkdir -p $out/bin
    makeWrapper $out/opt/ksa/KSA $out/bin/ksa \
      --unset WAYLAND_DISPLAY \
      --unset WAYLAND_SOCKET \
      --prefix LD_LIBRARY_PATH : "$out/opt/ksa" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeDeps}" \
      --set DOTNET_ROOT "" \
      --set VK_KSA_FIX_SWAPCHAIN 1 \
      --prefix VK_IMPLICIT_LAYER_PATH : "${vkFixSwapchain}/share/vulkan/implicit_layer.d" \
      --prefix XDG_DATA_DIRS : "${vkFixSwapchain}/share" \
      --chdir "$out/opt/ksa"

    # Also wrap the subprocess monitor
    chmod +x $out/opt/ksa/Brutal.Monitor.Subprocess

    runHook postInstall
  '';

  meta = {
    description = "Kitten Space Agency";
    platforms = [ "x86_64-linux" ];
  };
}
