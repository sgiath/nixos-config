{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fetchurl,
  glib,
  gtk3,
  lib,
  libdrm,
  libgbm,
  libnotify,
  libsecret,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxtst,
  makeWrapper,
  nspr,
  nss,
  pango,
  stdenvNoCC,
  systemd,
  xdg-utils,
}:

let
  pname = "grok-bot";
  version = "0.47.0";
  releaseId = "c1e7d7a46549956d25f53e9c0b9f59666e03aa3a";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${releaseId}/linux/x64/grok-bot_${version}_amd64.deb";
    hash = "sha256-EcoPUaU1uXr1GjUq35wPns0uGwQwpprpRRtoinoGWAg=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libsecret
    libuuid
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxscrnsaver
    libxtst
    nspr
    nss
    pango
    systemd
  ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    runHook preUnpack

    # The archive contains Electron's setuid sandbox, so dpkg-deb -x cannot
    # preserve the original ownership in a normal Nix build sandbox.
    dpkg --fsys-tarfile "$src" | tar --extract

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib/grok-bot" "$out/share"
    cp -r "opt/Grok Bot/." "$out/lib/grok-bot/"
    cp -r usr/share/. "$out/share/"

    rm "$out/lib/grok-bot/chrome-sandbox"

    makeWrapper "$out/lib/grok-bot/grok-bot" "$out/bin/grok-bot" \
      --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --add-flags "--disable-setuid-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer --enable-wayland-ime=true}}"

    substituteInPlace "$out/share/applications/grok-bot.desktop" \
      --replace-fail 'Exec="/opt/Grok Bot/grok-bot" %U' 'Exec=grok-bot %U'

    runHook postInstall
  '';

  meta = {
    description = "Grok desktop agent";
    homepage = "https://x.ai/bot";
    license = lib.licenses.unfree;
    mainProgram = "grok-bot";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
