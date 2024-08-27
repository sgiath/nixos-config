{ lib ? <nixpkgs/lib> }: {
  mkEnableOption = name: { default ? false }: lib.mkOption {
    inherit default;

    example = true;
    description = "Whether to enable ${name}.";
    type = lib.types.bool;
  };
}
