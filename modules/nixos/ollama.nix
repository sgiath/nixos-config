{ pkgs, ... }:
{
  services.ollama = {
    acceleration = "rocm";
    loadModels = [ "llama3.2" ];
    package = pkgs.master.ollama-rocm;
  };
}
