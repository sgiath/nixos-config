{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  makeWrapper,
  nodejs_22,
  perl,
}:

buildNpmPackage (finalAttrs: {
  pname = "beadboard";
  version = "0.1.0-unstable-2026-03-29";

  src = fetchFromGitHub {
    owner = "jordanhindo";
    repo = "beadboard";
    rev = "9993738b297592b202bd570a8f12039ca2b03624";
    hash = "sha256-k1qLA4/agj+5hPWp5EoPFWFY40OHbmG3HHgQy5uJM0Q=";
  };

  npmDepsHash = "sha256-F8enXwwkZSjf3ftrGM/+Kcr0Hp8dOic3pT4lv19oc6k=";

  nodejs = nodejs_22;

  nativeBuildInputs = [
    makeWrapper
    perl
  ];

  env.NEXT_TELEMETRY_DISABLED = "1";

  dontNpmPrune = true;

  postPatch = ''
    substituteInPlace install/beadboard.mjs \
      --replace-fail "spawn('npm', ['run', 'dev']" "spawn('npm', ['run', 'start']" \
      --replace-fail "Starting BeadBoard dev server..." "Starting BeadBoard server..."
    substituteInPlace bin/beadboard.js \
      --replace-fail "['--import', 'tsx', cliPath, ...process.argv.slice(2)]" "['--import', path.resolve(__dirname, '../node_modules/tsx/dist/loader.mjs'), cliPath, ...process.argv.slice(2)]"

    perl -0pi -e "s#import \{ Noto_Sans \} from 'next/font/google';\r?\n##; s#\r?\nconst notoSans = Noto_Sans\(\{\r?\n  subsets: \['latin'\],\r?\n  variable: '--font-ui',\r?\n\}\);\r?\n##; s#<body className=\{notoSans\.variable\} suppressHydrationWarning>#<body suppressHydrationWarning>#" src/app/layout.tsx

    perl -0pi -e "s#const nextConfig: NextConfig = \{#const nextConfig: NextConfig = {\n  eslint: {\n    ignoreDuringBuilds: true,\n  },\n  typescript: {\n    ignoreBuildErrors: true,\n  },#" next.config.ts
  '';

  installPhase = ''
    runHook preInstall

    packageRoot="$out/lib/beadboard"
    mkdir -p "$out/bin" "$packageRoot"

    rm -f skills/shadcn-ui
    cp -R . "$packageRoot/"

    makeWrapper ${lib.getExe nodejs_22} "$out/bin/beadboard" \
      --add-flags "$packageRoot/bin/beadboard.js" \
      --prefix PATH : "${lib.makeBinPath [ nodejs_22 ]}" \
      --set BB_RUNTIME_ROOT "$packageRoot" \
      --set BB_RUNTIME_VERSION "${finalAttrs.version}" \
      --set BB_INSTALL_MODE "nix"

    ln -s "$out/bin/beadboard" "$out/bin/bb"

    runHook postInstall
  '';

  meta = {
    description = "Multi-agent orchestration and communication system built on Beads";
    homepage = "https://github.com/jordanhindo/beadboard";
    license = lib.licenses.mit;
    mainProgram = "beadboard";
    platforms = lib.platforms.linux;
  };
})
