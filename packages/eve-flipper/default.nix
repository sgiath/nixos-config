{
  lib,
  buildGoModule,
  buildNpmPackage,
  esiCallbackUrl ? "http://localhost:13370/api/auth/callback",
  esiClientId ? (builtins.fromJSON (builtins.readFile ./../../secrets.json)).esi_client_id,
  esiClientSecret ? (builtins.fromJSON (builtins.readFile ./../../secrets.json)).esi_client_secret,
  fetchFromGitHub,
  perl,
}:

let
  pname = "eve-flipper";
  version = "1.6.2";

  src = fetchFromGitHub {
    owner = "ilyaux";
    repo = "Eve-flipper";
    rev = "v${version}";
    hash = "sha256-y60rUZvFpPZ5a4AyaB1yJ5NF9j9wAQnbxrueB2IHIQs=";
  };

  frontend = buildNpmPackage {
    pname = "${pname}-frontend";
    inherit version src;

    sourceRoot = "${src.name}/frontend";
    npmDepsHash = "sha256-P0LtydngzHJJWBqNNjMZBh6N1EHUDkoypSqvRKNMEmI=";

    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r dist $out/

      runHook postInstall
    '';
  };
in
buildGoModule {
  inherit pname version src;

  vendorHash = "sha256-6qIQ84BFk8daoWVmoOuTIbQG9Rw+eTiOlhKiiNlvTdg=";

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
