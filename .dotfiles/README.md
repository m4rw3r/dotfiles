
Using the Bare Repo solution from https://www.atlassian.com/git/tutorials/dotfiles

## Install

```bash
git clone --bare repository.git $HOME/.cfg
git --git-dir=$HOME/.cfg show HEAD:.dotfiles/install.sh | bash
```

## Updating submodules

```bash
config submodule foreach git pull origin master
```

## Intial setup

How to replicate this setup:

```bash
git init --bare $HOME/.cfg
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
config config status.showUntrackedFiles no
```
