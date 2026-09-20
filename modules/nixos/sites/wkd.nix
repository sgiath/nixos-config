{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sgiath.sites.sgiath-dev;
  domain = "sgiath.dev";
  wkdCors = ''
    add_header Access-Control-Allow-Origin '*' always;
    add_header Access-Control-Allow-Methods 'GET' always;
  '';
  wkd =
    pkgs.runCommand "wkd-${domain}"
      {
        nativeBuildInputs = [ pkgs.gnupg ];
        key = ./wkd/sgiath.asc;
        keyId = "0x70F9C7DE34CB3BC8";
        inherit domain;
      }
      ''
        export GNUPGHOME="$(mktemp -d)"
        trap 'rm -rf "$GNUPGHOME"' EXIT
        gpg --batch --quiet --import "$key"
        mkdir -p "$out/hu"
        gpg --batch --with-colons --list-keys "$keyId" \
          | awk -F: '$1 == "uid" { print $10 }' \
          | grep -F "@$domain" \
          | sed -n 's/.*<\([^>]*\)>.*/\1/p' \
          | while read -r email; do
              hash="$(gpg-wks-client --print-wkd-hash "$email" | awk '{ print $1 }')"
              gpg --batch --export "$keyId" > "$out/hu/$hash"
            done
        find "$out/hu" -type f | grep -q . || {
          echo "no WKD hashes generated for @$domain" >&2
          exit 1
        }
      '';
  wkdLocations = prefix: {
    "= ${prefix}policy" = {
      extraConfig = ''
        default_type text/plain;
        ${wkdCors}
        return 200 "";
      '';
    };
    "^~ ${prefix}hu/" = {
      alias = "${wkd}/hu/";
      extraConfig = ''
        default_type application/octet-stream;
        ${wkdCors}
      '';
    };
  };
in
{
  config = lib.mkIf (config.sgiath.roles.server.enable && cfg.enable) {
    services.nginx.virtualHosts = {
      ${domain}.locations = wkdLocations "/.well-known/openpgpkey/";
      "openpgpkey.${domain}" = {
        onlySSL = true;
        kTLS = true;
        enableACME = true;
        acmeRoot = null;
        locations = wkdLocations "/.well-known/openpgpkey/${domain}/" // {
          "/" = {
            extraConfig = ''
              return 404;
            '';
          };
        };
      };
    };
  };
}
