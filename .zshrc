# plugin manager

if [ -d "${HOME}/.local/bin" ]; then export PATH="${HOME}/.local/bin:$PATH" ; fi

if command -v sheldon >/dev/null 2>&1; then
  eval "$(sheldon source)"
fi

# prompt settings (if not install powerlevel10k)

if ! command -v p10k >/dev/null 2>&1; then
  setopt prompt_subst
  ## vcs_infoロード
  autoload -Uz vcs_info
  ## PROMPT変数内で変数参照する
  setopt prompt_subst

  ## vcsの表示
  zstyle ':vcs_info:*' formats ' [%s] %F{green}%b%f'
  zstyle ':vcs_info:*' actionformats ' [%s] %F{green}%b%f(%F{red}%a%f)'
  ## プロンプト表示直前にvcs_info呼び出し
  precmd() { vcs_info }
  PROMPT='%n@%m${vcs_info_msg_0_}${WINDOW:+"[$WINDOW]"}%{$fg[cyan]%}%#%{$reset_color%} '
  RPROMPT='%{$fg[white]%}%~%{$fg[cyan]%}:%{$fg[white]%}%! %T%{$reset_color%}'
fi

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=100000
SAVEHIST=100000
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '~/.zshrc'

#autocomplete
autoload -Uz compinit
compinit
# End of lines added by compinstall

# color settings
autoload -U colors
colors

# shared history (screen etc.)
setopt share_history


#keybaind
bindkey -e
bindkey "^?"    backward-delete-char
bindkey "^H"    backward-delete-char
bindkey "^[[3~" delete-char
bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line
bindkey '^P' history-beginning-search-backward
bindkey '^N' history-beginning-search-forward

#for C-w
WORDCHARS="*?_-.[]~=&;!#$%^(){}<>"

setopt HIST_IGNORE_SPACE

#auto cd when directory
setopt auto_cd

#auto list
setopt auto_list

setopt auto_param_keys

setopt auto_param_slash

setopt auto_remove_slash

#{a-c} -> a b c
setopt brace_ccl

setopt NO_beep

#spell check
setopt correct

#=command -> path of command
setopt equals

#"ls -F" at auto_list
setopt list_types

#jobs -l
setopt long_list_jobs

#--prefix=/usr <- auto
setopt magic_equal_subst

setopt mark_dirs

#auto tee or cat
setopt multios

setopt print_eightbit

export EDITOR='vim'
#export SHELL='zsh'

# for tmuxinator
if which mux > /dev/null 2>&1; then
  source ~/.tmuxinator/tmuxinator.zsh
fi

export TERM=xterm-256color

case ${OSTYPE} in
  darwin*)
    # for asdf (install from homebrew)
    # . $(brew --prefix asdf)/libexec/asdf.sh
    # for asdf (install from ansible)
    test -e "$HOME/.asdf/asdf.sh" && . "$HOME/.asdf/asdf.sh"

    # for direnv
    command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

    # for mysql8.0
    export PATH="$(brew --prefix mysql@8.0)/bin:$PATH"
    export LDFLAGS="-L$(brew --prefix mysql@8.0)/lib"
    export CPPFLAGS="-I$(brew --prefix mysql@8.0)/include"
    export PKG_CONFIG_PATH="$(brew --prefix mysql@8.0)/lib/pkgconfig"

    # use GNU sed
    alias sed='gsed'
esac

# The next line updates PATH for the Google Cloud SDK.
if [ -f "${HOME}/projects/others/google-cloud-sdk/path.zsh.inc" ]; then . '/Users/hisamatsuyoshiyuki/projects/others/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f "${HOME}/projects/others/google-cloud-sdk/completion.zsh.inc" ]; then . '/Users/hisamatsuyoshiyuki/projects/others/google-cloud-sdk/completion.zsh.inc'; fi

if [ -f "${HOME}/.iterm2_shell_integration.zsh" ]; then source "${HOME}/.iterm2_shell_integration.zsh"; fi

# Go
if [ -d "${HOME}/go" ]; then
  export GOPATH="${HOME}/go"
  export PATH="$PATH:${GOPATH}/bin"
fi

# Linuxbrew
if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; fi

# snap
if [ -d "/snap" ]; then
  export PATH="/snap/bin:$PATH"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
