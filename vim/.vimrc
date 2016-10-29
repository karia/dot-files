set number
set laststatus=2
set t_Co=256
syntax on

" tab and indent
set expandtab
set tabstop=2
set shiftwidth=2
set autoindent
set smartindent
set ambiwidth=double

" disable autoindent if paste multiline text
if &term =~ "xterm"
    let &t_SI .= "\e[?2004h"
    let &t_EI .= "\e[?2004l"
    let &pastetoggle = "\e[201~"

    function XTermPasteBegin(ret)
        set paste
        return a:ret
    endfunction

    inoremap <special> <expr> <Esc>[200~ XTermPasteBegin("")
endif
