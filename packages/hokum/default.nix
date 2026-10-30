{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  pkg-config,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

rustPlatform.buildRustPackage rec {
  pname = "hokum";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "anomalyco";
    repo = "hokum";
    rev = "v${version}";
    hash = "sha256-+CS6Rq3lQsli+F7GR56vejJfkHFWRI+dJV7AnWkMs60=";
  };

  cargoHash = "sha256-r3vn64VQ0CezL+j8VUckrdNkhPxPs4Z9Q/J0jOtqNLo=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    libxkbcommon
    wayland
  ];

  postInstall = ''
    install -Dm644 packaging/hokum.desktop -t $out/share/applications
    install -Dm644 packaging/app.hokum.Notifications.service -t $out/share/dbus-1/services
    substituteInPlace $out/share/dbus-1/services/app.hokum.Notifications.service \
      --replace-fail /usr/bin/hokum $out/bin/hokum
  '';

  # winit loads the Wayland client libraries and wgpu the Vulkan loader with
  # dlopen, so neither is on the binary's RPATH.
  postFixup = ''
    wrapProgram $out/bin/hokum \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          vulkan-loader
          wayland
        ]
      }
  '';

  meta = with lib; {
    description = "Freedesktop notification daemon for Wayland layer-shell compositors";
    homepage = "https://hokum.app";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "hokum";
  };
}
