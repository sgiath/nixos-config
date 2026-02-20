# https://ksa-linux.ahwoo.com/
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
  patchelf,
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
        -lvulkan -lrt
    '';

    installPhase = ''
      mkdir -p $out/lib $out/share/vulkan/implicit_layer.d
      cp libVkLayer_ksa_fix_swapchain.so $out/lib/
      substitute VkLayer_ksa_fix_swapchain.json \
        $out/share/vulkan/implicit_layer.d/VkLayer_ksa_fix_swapchain.json \
        --replace-fail "@lib_path@" "$out/lib/libVkLayer_ksa_fix_swapchain.so"
    '';
  };

  # GLFW shim that locks window size via min==max limits on Wayland.
  # Prevents the compositor from resizing windows away from the game's
  # intended size, which would cause swapchain/surface extent mismatch.
  #
  # Build strategy:
  #   1. Take the bundled libglfw.so.3.5, patchelf its SONAME to libglfw_real.so.3
  #   2. Compile glfw_diag.c as libglfw.so.3.5 (SONAME libglfw.so.3),
  #      linked against the renamed real via DT_NEEDED
  #   3. Install both into $out/lib/ — the game's LD_LIBRARY_PATH picks them up
  glfwShim = stdenv.mkDerivation {
    pname = "ksa-glfw-shim";
    version = "0.1.0";
    src = ./.;

    nativeBuildInputs = [ patchelf ];

    # We need the bundled GLFW from the game tarball
    gameSrc = fetchurl {
      url = "https://ksa-linux.ahwoo.com/download?file=setup_ksa_v2026.2.31.3640.tar.gz";
      hash = "sha256-ihh8mZ0zUK7VTQKVxqcm3w2AroTdpaEKcCrXR0wHdj4=";
    };

    buildPhase = ''
      # Extract the bundled GLFW from the game tarball
      tar xzf $gameSrc linux-x64/libglfw.so.3.5
      cp linux-x64/libglfw.so.3.5 libglfw_real.so.3.5

      # Patch the real GLFW's SONAME so it doesn't conflict with our shim
      patchelf --set-soname libglfw_real.so.3 libglfw_real.so.3.5

      # Create symlinks for the linker
      ln -s libglfw_real.so.3.5 libglfw_real.so.3
      ln -s libglfw_real.so.3.5 libglfw_real.so

      # Compile our shim — it becomes the new libglfw.so.3.5
      # DT_NEEDED on libglfw_real.so.3 means all 141+ unintercepted GLFW
      # symbols resolve through the real library automatically.
      $CC -shared -fPIC \
        -Wl,-soname,libglfw.so.3 \
        -o libglfw_shim.so.3.5 \
        glfw_diag.c \
        -L. -lglfw_real -ldl -lrt \
        -Wl,-rpath,'$ORIGIN'
    '';

    installPhase = ''
      mkdir -p $out/lib
      # Real GLFW (renamed soname)
      cp libglfw_real.so.3.5 $out/lib/
      ln -s libglfw_real.so.3.5 $out/lib/libglfw_real.so.3
      ln -s libglfw_real.so.3.5 $out/lib/libglfw_real.so
      # Shim (takes over libglfw.so.3 soname)
      cp libglfw_shim.so.3.5 $out/lib/libglfw.so.3.5
      ln -s libglfw.so.3.5 $out/lib/libglfw.so.3
      ln -s libglfw.so.3.5 $out/lib/libglfw.so
    '';
  };
in
stdenv.mkDerivation rec {
  pname = "ksa";
  version = "2026.2.31.3640";

  src = fetchurl {
    url = "https://ksa-linux.ahwoo.com/download?file=setup_ksa_v${version}.tar.gz";
    hash = "sha256-ihh8mZ0zUK7VTQKVxqcm3w2AroTdpaEKcCrXR0wHdj4=";
  };

  sourceRoot = ".";
  unpackCmd = "tar xzf $curSrc";

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

    # Replace the bundled GLFW with our shim + renamed real
    rm -f $out/opt/ksa/libglfw.so $out/opt/ksa/libglfw.so.3 $out/opt/ksa/libglfw.so.3.5
    # Copy the real (renamed) GLFW
    install -m 755 ${glfwShim}/lib/libglfw_real.so.3.5 $out/opt/ksa/
    ln -sf libglfw_real.so.3.5 $out/opt/ksa/libglfw_real.so.3
    ln -sf libglfw_real.so.3.5 $out/opt/ksa/libglfw_real.so
    # Copy the shim as the new libglfw.so.3.5
    install -m 755 ${glfwShim}/lib/libglfw.so.3.5 $out/opt/ksa/
    ln -sf libglfw.so.3.5 $out/opt/ksa/libglfw.so.3
    ln -sf libglfw.so.3.5 $out/opt/ksa/libglfw.so

    mkdir -p $out/bin

    # Base wrapper: sets up LD_LIBRARY_PATH and Vulkan layer
    # Does NOT set RADV_DEBUG — that's controlled per-variant by the outer scripts
    makeWrapper $out/opt/ksa/KSA $out/bin/ksa-unwrapped \
      --prefix LD_LIBRARY_PATH : "$out/opt/ksa" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeDeps}" \
      --set DOTNET_ROOT "" \
      --set VK_KSA_FIX_SWAPCHAIN 1 \
      --prefix VK_IMPLICIT_LAYER_PATH : "${vkFixSwapchain}/share/vulkan/implicit_layer.d" \
      --prefix XDG_DATA_DIRS : "${vkFixSwapchain}/share" \
      --chdir "$out/opt/ksa"

    # Default launcher: shim active (it's installed), syncshaders ON
    cat > $out/bin/ksa <<'WRAPPER'
    #!/usr/bin/env bash
    export RADV_DEBUG=syncshaders
    export VK_KSA_TRACK_RESOURCES=1
    logdir="$HOME/Documents/My Games/Kitten Space Agency/logs"
    mkdir -p "$logdir"
    ts=$(date +%Y%m%d-%H%M%S)
    logfile="$logdir/ksa-$ts.log"
    echo "KSA [shim+syncshaders] log: $logfile"
    exec @out@/bin/ksa-unwrapped "$@" >"$logfile" 2>&1
    WRAPPER

    substituteInPlace $out/bin/ksa --replace-fail "@out@" "$out"
    chmod +x $out/bin/ksa

    # Test variant: shim only (no syncshaders)
    cat > $out/bin/ksa-shim-only <<'WRAPPER'
    #!/usr/bin/env bash
    logdir="$HOME/Documents/My Games/Kitten Space Agency/logs"
    mkdir -p "$logdir"
    ts=$(date +%Y%m%d-%H%M%S)
    logfile="$logdir/ksa-shim-only-$ts.log"
    echo "KSA [shim-only] log: $logfile"
    exec @out@/bin/ksa-unwrapped "$@" >"$logfile" 2>&1
    WRAPPER

    substituteInPlace $out/bin/ksa-shim-only --replace-fail "@out@" "$out"
    chmod +x $out/bin/ksa-shim-only

    # Test variant: syncshaders only (bypass shim by preloading original GLFW)
    # The shim is still installed but we override LD_LIBRARY_PATH to put the
    # Nix store's original libglfw.so.3.5 first, shadowing the shim.
    # However, since we replaced the bundled GLFW in-place, we need a different
    # approach: set an env var that the shim checks to disable itself.
    # Actually simpler: just set RADV_DEBUG and note the shim is still active.
    # The shim doesn't cause crashes, it just locks sizes. For a true no-shim
    # test we'd need a separate derivation. For now, this tests syncshaders
    # with the shim also active (same as default but explicitly labeled).
    cat > $out/bin/ksa-syncshaders-only <<'WRAPPER'
    #!/usr/bin/env bash
    export RADV_DEBUG=syncshaders
    # NOTE: GLFW shim is still installed (it's baked into the package).
    # This variant tests syncshaders with the shim present.
    # For a true no-shim test, use the ksa-no-shim package.
    logdir="$HOME/Documents/My Games/Kitten Space Agency/logs"
    mkdir -p "$logdir"
    ts=$(date +%Y%m%d-%H%M%S)
    logfile="$logdir/ksa-syncshaders-only-$ts.log"
    echo "KSA [syncshaders+shim] log: $logfile"
    exec @out@/bin/ksa-unwrapped "$@" >"$logfile" 2>&1
    WRAPPER

    substituteInPlace $out/bin/ksa-syncshaders-only --replace-fail "@out@" "$out"
    chmod +x $out/bin/ksa-syncshaders-only

    # Also make the subprocess monitor executable
    chmod +x $out/opt/ksa/Brutal.Monitor.Subprocess

    runHook postInstall
  '';

  meta = {
    description = "Kitten Space Agency";
    platforms = [ "x86_64-linux" ];
  };
}
