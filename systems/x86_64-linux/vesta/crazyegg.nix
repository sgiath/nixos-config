{ pkgs, ... }:
let
  # Public mkcert root from Ceres; it signs the *.crazyeggdev.com certificate
  # served by dev-nginx. The private key stays on Ceres.
  devRootCa = ./crazyeggdev-root-ca.pem;
in
{
  # Playwright downloads its own Chrome builds; Vesta has no desktop role, so
  # nix-ld's base set lacks the libraries headless Chrome links against.
  programs.nix-ld.libraries = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    glib
    libdrm
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
  ];

  # Liberation/DejaVu/Noto Emoji so browser screenshots render like CI and
  # developer machines instead of falling back to missing glyphs.
  fonts.enableDefaultPackages = true;

  # OpenSSL/curl/Go/Ruby read the system bundle; Node ships its own roots.
  security.pki.certificateFiles = [ devRootCa ];
  environment.sessionVariables.NODE_EXTRA_CA_CERTS = "${devRootCa}";

  # Chrome on Linux trusts local roots only from the user's NSS database, as
  # `mkcert -install` does on Ceres.
  home-manager.users.sgiath =
    { lib, ... }:
    {
      home.activation.crazyeggdevNssTrust = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        nssdb="$HOME/.pki/nssdb"
        if [[ ! -f $nssdb/cert9.db ]]; then
          run mkdir -p "$nssdb"
          run ${pkgs.nssTools}/bin/certutil -N -d "sql:$nssdb" --empty-password
        fi
        run ${pkgs.nssTools}/bin/certutil -A -d "sql:$nssdb" -t C,, -n "mkcert sgiath@ceres" -i ${devRootCa}
      '';

      # sessionVariables reach login shells but not the systemd user manager,
      # so agents launched by T3 need the CA on the unit itself.
      systemd.user.services.t3code.Service.Environment = [
        "NODE_EXTRA_CA_CERTS=${devRootCa}"
      ];
    };
}
