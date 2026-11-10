#!/bin/zsh
path=(${(s.:.)_zshenv_path} $path)
typeset -U path
unset _zshenv_path
