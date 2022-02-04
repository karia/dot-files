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
# vcs_infoロード    
autoload -Uz vcs_info    
# PROMPT変数内で変数参照する    
setopt prompt_subst    

# vcsの表示    
zstyle ':vcs_info:*' formats ' [%s] %F{green}%b%f'    
zstyle ':vcs_info:*' actionformats ' [%s] %F{green}%b%f(%F{red}%a%f)'    
# プロンプト表示直前にvcs_info呼び出し    
precmd() { vcs_info }
PROMPT='%n@%m${vcs_info_msg_0_}${WINDOW:+"[$WINDOW]"}%{$fg[cyan]%}%#%{$reset_color%} '
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

#$B:G=i$K%9%Z!<%9$,$"$k$H$-MzNr$K;D$5$J$$(B
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

# vcs_infoロード    
autoload -Uz vcs_info    
# PROMPT変数内で変数参照する    
setopt prompt_subst    

# for mysql5.7
export PATH="/usr/local/opt/mysql@5.7/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/mysql@5.7/lib"
export CPPFLAGS="-I/usr/local/opt/mysql@5.7/include"
export PKG_CONFIG_PATH="/usr/local/opt/mysql@5.7/lib/pkgconfig"

# for asdf
. $(brew --prefix asdf)/libexec/asdf.sh

# for direnv
eval "$(direnv hook zsh)"

