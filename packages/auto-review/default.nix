{
  lib,
  python3,
  stdenvNoCC,
}:
# Stdlib only; its tests run as part of the build.
stdenvNoCC.mkDerivation {
  pname = "auto-review";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./auto_review
      ./tests
    ];
  };

  nativeBuildInputs = [ python3 ];
  dontBuild = true;
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    PYTHONDONTWRITEBYTECODE=1 python3 -I -m unittest discover -s tests -t .
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/auto-review $out/bin
    cp -r auto_review $out/lib/auto-review/
    cat > $out/bin/auto-review <<EOF
    #!${lib.getExe python3} -I
    import sys
    sys.path.insert(0, "$out/lib/auto-review")
    from auto_review.cli import main
    sys.exit(main())
    EOF
    chmod +x $out/bin/auto-review
    runHook postInstall
  '';

  meta = {
    description = "Review the MRs and PRs that request sgiath's review in T3 threads";
    mainProgram = "auto-review";
  };
}
