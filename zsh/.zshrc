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

# from UNIX USER 2002.06
# eval 'dircolors'

# export LS_COLORS 'di=01;36'
# zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# shared history (screen etc.)
setopt share_history

# prompt settings
setopt prompt_subst
PROMPT='%n@%m${WINDOW:+"[$WINDOW]"}%{$fg[cyan]%}%#%{$reset_color%} '
RPROMPT='%{$fg[white]%}%~%{$fg[cyan]%}:%{$fg[white]%}%! %T%{$reset_color%}'

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

#editor settings
# export EDITOR=emacs
# PAGER=jless
# export LC_CTYPE="ja_JP.eucJP"

#java settings
# export JAVA_HOME=/usr/local/diablo-jdk1.5.0
# export CLASSPATH=.:/usr/local/diablo-jdk1.5.0/lib/tools.jar:/usr/local/tomcat5.5/common/lib/servlet-api.jar:/usr/local/share/java/classes/commons-codec.jar
# export PATH=$PATH:$JAVA_HOME/bin

#alias
# alias ls="ls -wFG"
# alias -g L="| $PAGER"
# alias -g G="| grep"
# alias -g W="| wc"
# alias -g H="| head"
# alias -g T="| tail"
# alias -g ....="../.."
# alias man="jman"
# alias less="jless"

#最初にスペースがあるとき履歴に残さない
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

#2010/02/21 not use screen

# screen -xRU
# if [ $TERM != screen ]; then
#    exit
# fi

export EDITOR='vim'
export SHELL='zsh'

# for tmuxinator
if which mux > /dev/null 2>&1; then
  source ~/.tmuxinator/tmuxinator.zsh
fi

export TERM=xterm-256color

# for rbenv
if which rbenv > /dev/null 2>&1; then
  eval "$(rbenv init -)"
fi


# The next line updates PATH for the Google Cloud SDK.
source '/Users/karia/google-cloud-sdk/path.zsh.inc'

# The next line enables shell command completion for gcloud.
source '/Users/karia/google-cloud-sdk/completion.zsh.inc'

export NVM_DIR="/home/karia/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
