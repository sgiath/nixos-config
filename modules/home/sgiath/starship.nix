{ config, lib, ... }:
{
  config = lib.mkIf config.programs.starship.enable {
    programs.starship = {
      settings = {
        format = "$all";
        right_format = "$git_branch$git_status$cmd_duration";

        line_break.disabled = false;

        character = {
          success_symbol = " [](#6791c9)";
          error_symbol = " [](#df5b61)";
          vicmd_symbol = "[  ](#78b892)";
        };

        hostname = {
          format = "[$hostname](bold blue) ";
        };

        cmd_duration = {
          min_time = 1;
          format = "[](fg:#232526 bg:none)[$duration]($style)[](fg:#232526 bg:#232526)[](fg:#bc83e3 bg:#232526)[](fg:#232526 bg:#bc83e3)[](fg:#bc83e3 bg:none) ";
          disabled = false;
          style = "fg:#edeff0 bg:#232526";
        };

        directory = {
          format = "[](fg:#232526 bg:none)[$path]($style)[](fg:#232526 bg:#232526)[](fg:#6791c9 bg:#232526)[](fg:#232526 bg:#6791c9)[](fg:#6791c9 bg:none) ";
          style = "fg:#edeff0 bg:#232526";
          truncation_length = 3;
          truncate_to_repo = false;
        };

        git_branch = {
          format = "[](fg:#232526 bg:none)[$branch]($style)[](fg:#232526 bg:#232526)[](fg:#78b892 bg:#232526)[](fg:#282c34 bg:#78b892)[](fg:#78b892 bg:none) ";
          style = "fg:#edeff0 bg:#232526";
        };

        git_status = {
          format = "[](fg:#232526 bg:none)[$all_status$ahead_behind]($style)[](fg:#232526 bg:#232526)[](fg:#67afc1 bg:#232526)[](fg:#232526 bg:#67afc1)[](fg:#67afc1 bg:none) ";
          style = "fg:#edeff0 bg:#232526";
          conflicted = "=";
          ahead = "⇡\${count} ";
          behind = "⇣\${count} ";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count} ";
          # up_to_date = "";
          untracked = "?\${count} ";
          stashed = "$\${count} ";
          modified = "!\${count} ";
          staged = "+\${count} ";
          renamed = "»\${count} ";
          deleted = "✘\${count} ";
        };

        time = {
          disabled = false;
          style = "fg:yellow bg:#232526";
          format = "[](fg:#232526 bg:none)[$time Zulu]($style)[](fg:#232526 bg:none)";
          time_format = "%H%M";
        };

        elixir = {
          symbol = " ";
          format = "[](fg:#232526 bg:none)[$version (OTP $otp_version)]($style)[](fg:#232526 bg:#232526)[](fg:purple bg:#232526)[$symbol](fg:#232526 bg:purple)[](fg:purple bg:none) ";
          style = "fg:#edeff0 bg:#232526";
        };

        aws.disabled = true;
        direnv.disabled = false;
        localip.disabled = false;
        gcloud.disabled = true;
        nix_shell.disabled = true;
        package.disabled = true;
        lua.disabled = true;
      };
    };
  };
}
