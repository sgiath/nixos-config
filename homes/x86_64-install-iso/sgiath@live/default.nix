{
  sgiath = {
    enable = true;
    targets.terminal = true;
  };

  home.file.nixos.source = fetchGit {
      url = "git@git.sr.ht:~sgiath/nixos-config";
      name = "nixos-config";
    };

}
