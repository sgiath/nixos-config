{ config, lib, ... }:
{
  config = lib.mkIf config.programs.starship.enable {
    programs.starship = {
      settings = {
        format = "$hostname$directory$git_branch$git_status$line_break$character";

        character = {
          success_symbol = " [](#6791c9)";
          error_symbol = " [](#df5b61)";
          vicmd_symbol = "[  ](#78b892)";
        };

        hostname = {
          format = "[$hostname](bold blue) ";
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
      };
    };
  };
}
