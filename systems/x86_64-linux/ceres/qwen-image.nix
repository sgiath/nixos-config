{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.comfyui;
  officialWorkflow = "${cfg.dataDir}/user/default/workflows/qwen-image-2.1-int8.json";
  enhancedWorkflow = "${cfg.dataDir}/user/default/workflows/qwen-image-2.1-int8-enhanced.json";
in
{
  services.comfyui = {
    enable = true;
    user = "sgiath";
    group = "users";
    dataDir = "/home/sgiath/.local/share/comfyui";
    # Leave room for FP32 casts and attention scratch on the 16 GiB RX 6950 XT.
    extraArgs = [
      "--reserve-vram"
      "5"
    ];

    # Pure-Python prompt-enhancer nodes for the Qwen3.5-9B PE text encoders. They only use
    # ComfyUI's native clip.tokenize/generate/decode (ComfyUI >= 0.37), so no extra runtime
    # beyond the optional json_repair fallback for slightly malformed model answers.
    customNodes."ComfyUI-Qwen-Image-2.1-Prompt-Enhancer" = pkgs.fetchFromGitHub {
      owner = "benjiyaya";
      repo = "ComfyUI-Qwen-Image-2.1-Prompt-Enhancer";
      rev = "fe166a199d3d1f2397a97bab230ae74657fc5c09";
      hash = "sha256-G5c56Mm0hDJlz0K705cRUxKDiTHV6PmBxe+dqDYCPdM=";
    };
  };

  # Seed workflows once; edits saved from the UI are kept.
  systemd.services.comfyui.preStart = lib.mkAfter ''
    if [[ ! -e ${officialWorkflow} ]]; then
      mkdir -p ${dirOf officialWorkflow}
      cp --no-preserve=mode ${./qwen-image/int8.json} ${officialWorkflow}
    fi
    if [[ ! -e ${enhancedWorkflow} ]]; then
      mkdir -p ${dirOf enhancedWorkflow}
      cp --no-preserve=mode ${./qwen-image/int8-enhanced.json} ${enhancedWorkflow}
    fi
  '';

  # Fetches and SHA-verifies the model files into <dataDir>/models; run once by hand.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "qwen-image-download";
      runtimeInputs = with pkgs; [
        curl
        coreutils
      ];
      text = builtins.readFile ./qwen-image/download-models.sh;
    })
  ];
}
