set encoding=utf-8      "Use UTF-8 encoding that supports unicode.
set number              "Show line numbers on the sidebar.
set norelativenumber    "Show line number on the current line and disable (no) relative numbers on all other lines.
set expandtab           "Convert tabs to spaces.
set smarttab            "Insert 'tabstop' number of spaces when the 'tab' key is pressed.
set tabstop=4           "Indent using four spaces.
set shiftwidth=4        "When shifting, indent using four spaces.
set hlsearch            "Enable search highlighting.
set ignorecase          "Ignore case when searching.
set scrolloff=2         "The number of screen lines to keep above and below the cursor.
set ruler               "Always show cursor position.
set cursorline          "Highlight the line currently under cursor.
set visualbell          "Flash the screen instead of beeping on errors.
set title               "Set the window's title, reflecting the file currently being edited.
set background=dark     "Use colors that suit a dark background.
set history=1000        "Increase the undo limit.
set mouse=a             "Enable Mouse support in all modes.

if has('termguicolors')
    set termguicolors   "Enable true color support when available."
endif

let g:lightline = {'colorscheme': 'catppuccin_mocha'}
let g:airline_theme = 'catppuccin_mocha'
colorscheme catppuccin_mocha

syntax enable           "Enable syntax highlighting
