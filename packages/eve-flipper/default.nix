{
  lib,
  buildGoModule,
  esiCallbackUrl ? "http://localhost:13370/api/auth/callback",
  esiClientId ? (builtins.fromJSON (builtins.readFile ./../../secrets.json)).esi_client_id,
  esiClientSecret ? (builtins.fromJSON (builtins.readFile ./../../secrets.json)).esi_client_secret,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  perl,
  pnpm,
  pnpmConfigHook,
  stdenvNoCC,
}:

let
  pname = "eve-flipper";
  version = "1.6.6";

  src = fetchFromGitHub {
    owner = "ilyaux";
    repo = "Eve-flipper";
    rev = "v${version}";
    hash = "sha256-A1l7RjpPmTTTW+MFv6T4kd1Gi5vmi1e3sMbL7Ei/+/A=";
  };

  frontend = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "${pname}-frontend";
    inherit version src;

    sourceRoot = "${src.name}/frontend";
    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname version src sourceRoot;
      fetcherVersion = 3;
      hash = "sha256-S5R5RHjbpHuc6E5zJZZfbTo44iFdSxcG5xyrLaUCN9g=";
    };

    nativeBuildInputs = [
      nodejs
      pnpm
      pnpmConfigHook
    ];

    buildPhase = ''
      runHook preBuild

      pnpm build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r dist $out/

      runHook postInstall
    '';
  });
in
buildGoModule {
  inherit pname version src;

  vendorHash = "sha256-5h/PRjIB1C25EJK7zGP+rNb3HO/yyuHlOdzDB7ytB8A=";

  nativeBuildInputs = [ perl ];

  postPatch = ''
    perl -0pi -e 's|\n\t// File logs live next to the running binary \(release/build folder\)\.\n\tlogDir := "\."\n\tif exePath, err := os\.Executable\(\); err == nil \{\n\t\tif exeDir := filepath\.Dir\(exePath\); exeDir != "" \{\n\t\t\tlogDir = exeDir\n\t\t\}\n\t\}|\n\t// Nix store binaries are read-only; keep logs in the launch directory.\n\tlogDir := "."|' main.go
  '';

  preBuild = ''
    cp -r ${frontend}/dist frontend/dist
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${version}"
    "-X main.defaultESIClientID=${esiClientId}"
    "-X main.defaultESIClientSecret=${esiClientSecret}"
    "-X main.defaultESICallbackURL=${esiCallbackUrl}"
  ];

  doCheck = false;

  meta = {
    description = "Local-first market intelligence and trading tool for EVE Online";
    homepage = "https://github.com/ilyaux/Eve-flipper";
    license = lib.licenses.mit;
    mainProgram = "eve-flipper";
    platforms = lib.platforms.linux;
  };
}
