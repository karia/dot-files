" view and color
set number
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

" status line
set laststatus=2 " ステータスラインを常に表示
set showmode " 現在のモードを表示
set showcmd " 打ったコマンドをステータスラインの下に表示
set ruler " ステータスラインの右側にカーソルの位置を表示する
set wildmenu " コマンドモードの補完
set history=5000 " 保存するコマンド履歴の数
