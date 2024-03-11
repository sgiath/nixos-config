{ config, pkgs, stylix, userSettings, ... }:

{
  imports = [
    # default values
    ../home.nix

    # audio
    ../../user/audio.nix

    # GUI apps
    ../../user/xmonad/default.nix
    ../../user/polybar/polybar.nix
    ../../user/rofi.nix
    ../../user/wezterm.nix
    ../../user/browser.nix
    ../../user/email_client.nix
  ];

  home.packages = [
    (pkgs.writeShellScriptBin "aws-secrets" ''
      aws sts get-session-token --profile crazyegg --serial-number "arn:aws:iam::173509387151:mfa/filip" --token-code $(pass otp 2fa/amazon/code) | jq -r '.Credentials'
    '')
  ];

  programs.jq.enable = true;
  programs.awscli = {
    enable = true;
    settings."default" = {
      region = "us-east-1";
      output = "json";
    };
    credentials = {
      "default"."credential_process" = "aws-secrets";
      "crazyegg"."credential_process" = "${pkgs.pass}/bin/pass show aws/crazyegg";
    };
  };

  stylix = {
    fonts = {
      sizes = {
        applications = 12;
        terminal = 14;
      };
    };
  };
}
