{
  features.tty = true;
  cli.ro = [
    "$HOME/.gitconfig"
    "$HOME/.config/git/config"
  ];
  cli.rw = [
    # Git needs to write to the repository
    "$PWD/.git"
  ];
}
