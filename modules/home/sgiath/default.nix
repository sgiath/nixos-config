{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./audio.nix
    ./bitcoin.nix
    ./chromium.nix
    ./comm.nix
    ./email_client.nix
    ./games.nix
    ./git.nix
    ./gnupg.nix
    ./hyprland.nix
    ./nvim.nix
    ./ssh.nix
    ./starship.nix
    ./tmux.nix
    ./vscode.nix
    ./waybar.nix
    ./web_browsers.nix
    ./zsh.nix

    ./targets
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    home = {
      stateVersion = "23.11";

      packages = with pkgs; [
        (writeShellScriptBin "update" ''
          pushd ~/nixos

          git add --all
          git commit --signoff -m "changes"
          git push

          nix-store --add-fixed sha256 ~/nix-root/FoundryVTT-12.331.zip

          case "$1" in
            --ceres)
              nixos-rebuild switch --use-remote-sudo --flake '.#ceres'
              ;;

            --vesta)
              nixos-rebuild switch --use-remote-sudo --flake '.#vesta' --target-host 'sgiath@vesta.local'
              ;;

            --hygiea)
              nixos-rebuild switch --use-remote-sudo --flake '.#hygiea' --target-host 'sgiath@hygiea.sgiath.dev'
              ;;

            --iso)
              nix build '.#install-isoConfigurations.live'

              echo
              echo "doas dd if=result/iso/*.iso of=/dev/sdX status=progress"
              ;;

            *)
              nixos-rebuild switch --use-remote-sudo --flake .
              ;;
          esac

          popd
        '')

        (writeShellScriptBin "upgrade" ''
          pushd ~/nixos

          git add --all
          git commit --signoff -m "changes"

          nix flake update
          git add --all
          git commit --signoff -m "flake update"
          git push

          popd
        '')

        (writeShellScriptBin "generate-thumbnail" ''
          # === Configuration ===
          # Standard EXIF thumbnail size, but you can change it
          THUMB_SIZE="160x120"
          # Set to true to modify the original file directly, false to keep backups (*_original)
          OVERWRITE_ORIGINAL=true
          # === End Configuration ===

          # --- Script Logic ---

          # Check if an input file was provided
          if [ -z "$1" ]; then
            echo "Usage: $0 <image_file>"
            exit 1
          fi

          INPUT_IMAGE="$1"

          # Check if input file exists
          if [ ! -f "$INPUT_IMAGE" ]; then
            echo "Error: Input file '$INPUT_IMAGE' not found."
            exit 1
          fi

          # Create a secure temporary file for the thumbnail
          TEMP_THUMB=$(mktemp --suffix=.jpg)
          # Ensure temporary file is deleted even if script exits unexpectedly
          trap 'rm -f "$TEMP_THUMB"' EXIT

          echo "Processing: $INPUT_IMAGE"

          # 1. Generate the thumbnail using ImageMagick
          echo " -> Generating thumbnail ($THUMB_SIZE)..."
          ${imagemagick}/bin/convert "$INPUT_IMAGE" -thumbnail "$THUMB_SIZE" "$TEMP_THUMB"
          if [ $? -ne 0 ]; then
            echo "Error: Failed to generate thumbnail with 'convert'."
            exit 1
          fi

          # Check if thumbnail was actually created and has size > 0
          if [ ! -s "$TEMP_THUMB" ]; then
            echo "Error: Temporary thumbnail file '$TEMP_THUMB' was not created or is empty."
            exit 1
          fi

          # 2. Embed the thumbnail using ExifTool
          echo " -> Embedding thumbnail into metadata..."
          if [ "$OVERWRITE_ORIGINAL" = true ]; then
            echo "    (Overwriting original file)"
            ${exiftool}/bin/exiftool -quiet -overwrite_original "-ThumbnailImage<=$TEMP_THUMB" "$INPUT_IMAGE"
          else
            echo "    (Creating backup: $INPUT_IMAGE_original)"
            exiftool -quiet "-ThumbnailImage<=$TEMP_THUMB" "$INPUT_IMAGE"
          fi

          if [ $? -ne 0 ]; then
            echo "Error: Failed to embed thumbnail with 'exiftool'."
            # Note: Temp file is removed by the trap EXIT
            exit 1
          fi

          # 3. Cleanup is handled by the 'trap' command on exit

          echo " -> Success: Thumbnail embedded in $INPUT_IMAGE"
          exit 0
        '')

        (writeShellScriptBin "fix-images" ''
          find . -type f \( \
            -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \
            -o -iname "*.tif" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.heic" \
            -o -iname "*.heif" \) -print0 | \
          ${parallel-full}/bin/parallel -0 --eta \
            exiftool -quiet -api PNGEarlyXMP=1 -JUMBF:all= -overwrite_original {}
        '')

        # general programs I want to have always available
        imagemagick
        parallel-full
        ffmpeg
        zip
        unzip
        p7zip
        wget
        dig
        killall
        inotify-tools
        lshw
        parted
        nix-du
        exfat
      ];
    };

    services = {
      gnome-keyring.enable = true;
      pass-secret-service.enable = false;
    };

    programs = {
      home-manager.enable = true;
      fastfetch.enable = true;

      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      password-store = {
        enable = true;
        settings = {
          PASSWORD_STORE_DIR = "/home/sgiath/.local/share/password-store";
        };
        package = pkgs.pass-wayland.withExtensions (exts: [ exts.pass-otp ]);
      };
    };

    systemd.user.startServices = "sd-switch";
  };
}
