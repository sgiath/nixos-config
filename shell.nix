# Shell for bootstrapping flake-enabled nix and home-manager
# You can enter it through 'nix develop'
{
  pkgs ? (import ./nixpkgs.nix) { },
}:
{
  default = pkgs.mkShell {
    NIX_CONFIG = "experimental-features = nix-command flakes";
    nativeBuildInputs = with pkgs; [
      nix
      home-manager
      git
      git-crypt
      gnupg
    ];
  };
}
