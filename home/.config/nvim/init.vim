call plug#begin(stdpath('data') . '/plugged')
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
call plug#end()

set encoding=utf-8
set number
set norelativenumber
set expandtab
set smarttab
set tabstop=4
set shiftwidth=4
set hlsearch
set ignorecase
set scrolloff=2
set ruler
set cursorline
set visualbell
set title
set background=dark
set history=1000
set mouse=a

if has('termguicolors')
  set termguicolors
endif

lua <<'LUA'
require('catppuccin').setup({
  flavour = 'mocha',
})
LUA

colorscheme catppuccin

syntax enable
