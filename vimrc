" General {
	set nocompatible
	set encoding=utf-8
	setglobal fileencoding=utf-8
	set fileencodings=ucs-bom,utf-8
	" Display incomplete commands
	set showcmd
	" Allow switching buffsers without saving changes to file
	set hidden
	" Don't add invisible linebreak at EOF
	set binary noeol

	let mapleader = "§"
" }

" Vundle {
	" Brief help
	" :BundleList          - list configured bundles
	" :BundleInstall(!)    - install(update) bundles
	" :BundleSearch(!) foo - search(or refresh cache first) for foo
	" :BundleClean(!)      - confirm(or auto-approve) removal of unused bundles
	"
	" see :h vundle for more details or wiki for FAQ
	" NOTE: comments after Bundle command are not allowed..
	
	set rtp+=~/.vim/bundle/vundle/
	call vundle#rc()
	
	" Let Vundle manage Vundle
	" Required!
	Bundle 'gmarik/vundle'
	
	" Syntax
	Bundle 'beyondwords/vim-twig'
	Bundle 'ekalinin/Dockerfile.vim'
	Bundle 'groenewege/vim-less'
	Bundle 'kchmck/vim-coffee-script'
	Bundle 'lukerandall/haskellmode-vim'
	Bundle 'othree/html5.vim'
	Bundle 'tpope/vim-markdown'
	Bundle 'google/vim-ft-go'
	Bundle 'vim-scripts/haskell.vim'
	Bundle 'vim-scripts/nginx.vim'
	Bundle 'wting/rust.vim'

	" Clojure
	Bundle 'guns/vim-clojure-highlight'
	Bundle 'guns/vim-clojure-static'
	Bundle 'tpope/vim-fireplace.git'

	" Tools
	Bundle 'airblade/vim-rooter'
	Bundle 'christoomey/vim-tmux-navigator'
	Bundle 'FuzzyFinder'
	Bundle 'godlygeek/tabular'
	Bundle 'kien/ctrlp.vim'
	Bundle 'kikijump/tslime.vim'
	Bundle 'L9'
	Bundle 'Lokaltog/vim-powerline'
	Bundle 'mileszs/ack.vim'
	Bundle 'scrooloose/nerdtree'
	Bundle 'scrooloose/syntastic'
	Bundle 'tpope/vim-fugitive'
	Bundle 'vim-scripts/Smart-Tabs'
	Bundle 'vim-scripts/bufkill.vim'

	" Colorschemes
	Bundle 'junegunn/seoul256.vim'
	Bundle 'Lokaltog/vim-distinguished'

	" Required!
	filetype plugin indent on
" }

" Syntastic {
	let g:syntastic_check_on_open=1
	
	" It uses PHP Mess Detector and PHP_CodeSniffer, I do not like how those behaves
	let g:syntastic_php_checkers=['php']
	let g:syntastic_css_checkers=['csslint', 'prettycss']
	let g:synastic_java_checkers=[]

	let g:syntastic_error_symbol='✗'
	let g:syntastic_warning_symbol='⚠'

	let g:syntastic_hdevtools_options='-g -W -g -Wall -g -fwarn-tabs -g -fwarn-incomplete-record-updates'
" }

" vim-powerline {
	set laststatus=2
	let g:Powerline_symbols = 'fancy'
" }

" Rooter {
	let g:rooter_use_lcd = 1
" }

" Bufkill {
	let g:BufKillCreateMappings = 0
" }

" Ack.vim {
	" Use The Silver Searcher
	let g:ackprg = 'ag --nogroup --nocolor --column'
" }

" lukerandall/haskellmode-vim {
	let g:haddock_browser = "open"
	let g:haddock_browser_callformat = "%s %s"
" }

" Backup, Swap and View Files {
	" Create dirs
	silent execute '!mkdir -p $HOME/.vim/.backup'
	silent execute '!mkdir -p $HOME/.vim/.swap'
	silent execute '!mkdir -p $HOME/.vim/.views'
	silent execute '!mkdir -p $HOME/.vim/.undo'
	" Store backups in $HOME to keep the directory trees clean
	set backup
	set undofile
	set backupdir=$HOME/.vim/.backup/
	set directory=$HOME/.vim/.swap/
	set viewdir=$HOME/.vim/.views/
	set undodir=$HOME/.vim/.undo/
" }

" Tabs and Indentation {
	set noexpandtab
	set autoindent
	
	set tabstop=4
	set shiftwidth=4
	
	" Different tab-width on YAML and Ruby files
	autocmd FileType yaml setlocal expandtab shiftwidth=2 tabstop=2
	autocmd FileType ruby setlocal expandtab shiftwidth=2 tabstop=2
	autocmd FileType coffee setlocal expandtab shiftwidth=2 tabstop=2
	" Python should be indented with spaces preferrably
	autocmd FileType python setlocal expandtab shiftwidth=4 tabstop=4
	" Haskell should be indented with spaces preferrably
	autocmd FileType haskell setlocal expandtab shiftwidth=4 tabstop=4
	autocmd FileType cabal setlocal expandtab shiftwidth=4 tabstop=4
	" Javascript 2 spaces
	autocmd FileType javascript setlocal expandtab shiftwidth=2 tabstop=2
" }

" Font and Color {
	if has("gui_running")
		set guifont=DejaVu\ Sans\ Mono\ for\ Powerline:h13
		set antialias
		set linespace=3
		" Prevent mouse usage, trackpad makes it way too easy to resort to
		" clicking to move the cursor
		set mouse=c

		" Force MacVim to skip colors
		let macvim_skip_colorscheme=1

		set transparency=4
	else
		set t_Co=256
		" Do not use terminal background color when clearing screen
		set t_ut=
	endif
	
	syntax on
	
	" Function for fixing many problems with colorschemes
	function! CorrectColorScheme()
		" Fix the listchars style
		hi clear NonText
		hi clear SpecialKey
		hi NonText ctermfg=240 guifg=#585858
		hi SpecialKey ctermfg=240 guifg=#585858
		
		" Change vertical bar styling
		hi VertSplit ctermfg=238 guifg=#444444 ctermbg=238 guibg=#444444
		
		" Fix LineNr styling, so it matches with most themes
		hi clear LineNr
		hi LineNr ctermfg=240 guifg=#585858
		
		" Fix autocomplete, the standard is "OMG MY EYES ARE BLEEDING!"
		hi Pmenu ctermfg=245 ctermbg=0 guifg=#8a8a8a guibg=#000000
		hi PmenuSel ctermfg=15 ctermbg=0 guifg=#ffffff guibg=#000000
		
		" Fix todo highlight
		hi clear Todo
		hi Todo ctermfg=124 guifg=#af0000

		" Fix sign column where syntastic errors are displayed
		hi SignColumn ctermfg=238 guifg=#444444 ctermbg=238 guibg=#444444
	endfunction
	
	" autocmd ColorScheme * call CorrectColorScheme()

	colorscheme tomorrow-night
" }

" UI {
	set list
	set listchars=eol:¬,tab:▸\ ,trail:·
	" Display hidden unicode characters as hex
	set display+=uhex
	
	" Relative line numbers on, with current line showing current line number
	set relativenumber
	set number
	
	" Highlight all search matches
	set showmatch
	
	" Incremental search (ie. search while you type)
	set incsearch
	set hlsearch
	
	" Ignore case for search unless it contains uppercase characters
	set ignorecase
	set smartcase

	" After vertical split, select lower pane
	" (hozontal splitting, keep default: select left pane)
	set splitbelow
	
	" Always keep this many lines below the line currently being edited
	set scrolloff=5
	
	" Remove scrollbars
	set guioptions+=lrbRL
	set guioptions-=lrbRL
	
	" No audio bell
	set vb
" }

" Key Mappings {
	" Normal backspace
	set backspace=2
	
	" Avoid escape
	inoremap jj <Esc>
	
	" Don't allow arrow keys in insert mode
	inoremap <Left>  <NOP>
	inoremap <Right> <NOP>
	inoremap <Up>    <NOP>
	inoremap <Down>  <NOP>

	" Make so that J and K moves up and down a line while keeping the caret in the
	" same column
	nmap j gj
	nmap k gk
	vmap j gj
	vmap k gk
	
	" easier cursor navigation between split windows using CTRL and h,j,k, or l
	noremap <C-h> <C-w>h
	noremap <C-j> <C-w>j
	noremap <C-k> <C-w>k
	noremap <C-l> <C-w>l

	nnoremap <F3> :set hlsearch!<CR>

	" Allow saving of files as sudo when vim is not running under sudo
	" NOTE: Does not work in gvim
	cmap w!! w !sudo tee > /dev/null %

	map <C-Tab> :bnext<CR>
	map <C-S-Tab> :bprevious<CR>

	map <Leader>w :bp\|bd #<CR>

	map <Leader>= <C-w>=

	map <Leader><Tab> :NERDTreeToggle<CR>

	" Remap CMD + F to fullscreen mode
	if has("gui_running")
		set fuopt+=maxhorz
		macmenu &Edit.Find.Find\.\.\. key=<nop>
		map <D-f> :set invfu<CR>
	endif
" }

" Include local settings {
	if filereadable(glob("~/dotfiles/projects.vim"))
		source ~/dotfiles/projects.vim
	endif
" }