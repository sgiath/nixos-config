{
  sgiath = {
    enable = true;
    targets.terminal = true;
  };

  home.file.nixos = {
    recursive = true;
    source = fetchGit {
      url = "https://git.sr.ht/~sgiath/nixos-config";
      name = "nixos-config";
    };
  };
}
