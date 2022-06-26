
Using the Bare Repo solution from https://www.atlassian.com/git/tutorials/dotfiles

## Requirements

 * Bash
 * Fzf
 * Git
 * Kitty
 * Tmux
 * VIM / NeoVIM
 * ZSH

### Fonts

 * [Roboto Mono](https://fonts.google.com/specimen/Roboto+Mono)
 * [Symbola](https://fontlibrary.org/en/font/symbola)
 * [Standalone 2048 NerdFont Symbols](https://github.com/ryanoasis/nerd-fonts/blob/master/src/glyphs/Symbols-2048-em%20Nerd%20Font%20Complete.ttf)
 * [Noto Emoji](https://github.com/googlefonts/noto-emoji) (Install this using the system package manager if possible to get proper fallback behaviour.)

### Linux

 * Grim
 * Rofi
 * Slurp
 * Sway
 * Waybar
 * lm-sensors
 * wl-clipboard

## Install

```bash
git clone --bare repository.git $HOME/.cfg
git --git-dir=$HOME/.cfg show HEAD:.config/install.sh | bash
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
