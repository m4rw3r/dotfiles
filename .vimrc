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

	filetype plugin indent on

	let mapleader=" "
	
	if has("win32")
		" Ensure .vim is in path, gvim in Windows does not use this by default
		set rtp+=~/.vim
	endif
" }

" Vim Plug {
	" Automatic installation of Vim Plug
	" Use $HOME to account for windows
	if empty(glob($HOME . "/.vim/autoload/plug.vim"))
		if has("win32")
			silent ! powershell (md "$env:HOMEPATH\.vim\autoload")
			silent ! powershell (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim', $env:HOMEPATH + '\.vim\autoload\plug.vim')
		else
			silent !curl -fLo $HOME/.vim/autoload/plug.vim --create-dirs
				\ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
		endif
		autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
	endif
	
	silent call plug#begin($HOME . "/.vim/plugged")
	
	" Vim Plug itself
	Plug 'junegunn/vim-plug'
	
	" Syntax
	Plug 'cespare/vim-toml'
	Plug 'ekalinin/Dockerfile.vim'
	Plug 'groenewege/vim-less'
	Plug 'kchmck/vim-coffee-script'
	Plug 'lukerandall/haskellmode-vim'
	Plug 'tpope/vim-markdown'
	Plug 'google/vim-ft-go'
	Plug 'vim-scripts/haskell.vim'
	Plug 'vim-scripts/nginx.vim'
	Plug 'rust-lang/rust.vim'
	Plug 'pangloss/vim-javascript'
	Plug 'mxw/vim-jsx'
	Plug 'StanAngeloff/php.vim'
	Plug 'vim-scripts/HTML-AutoCloseTag'

	" Clojure
	Plug 'guns/vim-clojure-highlight'
	Plug 'guns/vim-clojure-static'
	Plug 'tpope/vim-fireplace'

	" Tools
	Plug 'airblade/vim-rooter'
	Plug 'ap/vim-css-color'
	Plug 'christoomey/vim-tmux-navigator'
	Plug 'dense-analysis/ale'
	Plug 'godlygeek/tabular'
	Plug 'jgdavey/tslime.vim'
	Plug 'kien/ctrlp.vim'
	Plug 'luochen1990/rainbow'
	Plug 'mileszs/ack.vim'
	Plug 'scrooloose/nerdtree'
	Plug 'tpope/vim-fugitive'
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'
	Plug 'vim-scripts/L9'
	Plug 'vim-scripts/bufkill.vim'
	Plug 'xolox/vim-misc'

	" Colorschemes
	Plug 'xolox/vim-colorscheme-switcher'
	Plug 'junegunn/seoul256.vim'
	Plug 'Lokaltog/vim-distinguished'
	Plug 'whatyouhide/vim-gotham'
	
	call plug#end()
" }

" ALE {
	" Gutter off
	let g:ale_set_signs=0

	" Enable Airline integration
	let g:airline#extensions#ale#enabled = 1

	let g:ale_linters={'javascript':['flow-language-server','xo']}
" }

" airline {
	set laststatus=2
	let g:airline_powerline_fonts=0
	let g:airline_theme='distinguished'
	let g:airline#extensions#whitespace#enabled=1
	let g:airline#extensions#whitespace#mixed_indent_algo=2
	" Skip trailing checks:
	let g:airline#extensions#whitespace#checks=['indent', 'long', 'mixed-indent-file']
" }

" Rooter {
	let g:rooter_use_lcd=1
	" Prevent Rooter from printing the directory every time it changes
	let g:rooter_silent_chdir=1
" }

" Bufkill {
	let g:BufKillCreateMappings=0
" }

" Nerdtree {
	let NERDTreeShowHidden=1
" }

" Ack.vim {
	" Use The Silver Searcher
	let g:ackprg='ag --nogroup --nocolor --column'
" }

" lukerandall/haskellmode-vim {
	let g:haddock_browser="open"
	let g:haddock_browser_callformat="%s %s"
" }

" luochen1990/rainbow {
	let g:rainbow_active=1
	let g:rainbow_conf={'separately': { 'html': 0 }}
" }

" Javascript {
	" I use Flow
	let g:javascript_plugin_flow = 1

	" mxw/vim-jsx: Fixes issue with closing parenthesis in "React-like components"
	let g:jsx_ext_required = 0
" }

" PHP {
	" Slow syntax highlighting
	let php_html_load=0
	let php_html_in_heredoc=0
	let php_html_in_nowdoc=0
	let php_sql_query=0
	let php_sql_heredoc=0
	let php_sql_nowdoc=0
" }

" Backup, Swap and View Files {
	" Create dirs, $HOME to ensure it works on windos, need to check to avoid
	" lots of command windows in Windows when running gvim
	if !isdirectory($HOME . "/.vim/.backup")
		if has("win32")
			silent ! powershell (md "$env:HOMEPATH\.vim\.backup")
			silent ! powershell (md "$env:HOMEPATH\.vim\.swap")
			silent ! powershell (md "$env:HOMEPATH\.vim\.views")
			silent ! powershell (md "$env:HOMEPATH\.vim\.undo")
		else
			silent execute '!mkdir -p $HOME/.vim/.backup'
			silent execute '!mkdir -p $HOME/.vim/.swap'
			silent execute '!mkdir -p $HOME/.vim/.views'
			silent execute '!mkdir -p $HOME/.vim/.undo'
		endif
	endif

	" Store backups in $HOME to keep the directory trees clean
	set backup
	set undofile
	set backupdir=$HOME/.vim/.backup//
	set directory=$HOME/.vim/.swap//
	set viewdir=$HOME/.vim/.views//
	set undodir=$HOME/.vim/.undo//
" }

" Tabs and Indentation {
	set noexpandtab
	set autoindent
	
	set tabstop=4
	set shiftwidth=4

	" Disable code folding
	set nofoldenable
	" disable PIV's folding
	let g:DisableAutoPHPFolding = 1

	fun! <SID>StripTrailingWhitespaces()
		let l=line(".")
		let c=col(".")
		%s/\s\+$//e
		call cursor(l, c)
	endfun
	
	" Different tab-width on YAML and Ruby files
	autocmd FileType yaml setlocal expandtab shiftwidth=2 tabstop=2
	autocmd FileType ruby setlocal expandtab shiftwidth=2 tabstop=2
	autocmd FileType coffee setlocal expandtab shiftwidth=2 tabstop=2
	" PHP indent is 4 spaces and remove trailing spaces
	autocmd FileType php setlocal expandtab
	autocmd FileType php autocmd BufWritePre <buffer> :call <SID>StripTrailingWhitespaces()
	" Python should be indented with spaces preferrably
	autocmd FileType python setlocal expandtab shiftwidth=4 tabstop=4
	" Haskell should be indented with spaces preferrably
	autocmd FileType haskell setlocal expandtab shiftwidth=4 tabstop=4
	autocmd FileType cabal setlocal expandtab shiftwidth=4 tabstop=4
	" Javascript 2 spaces and automatically remove trailing spaces
	autocmd FileType javascript setlocal expandtab shiftwidth=2 tabstop=2
	autocmd FileType javascript autocmd BufWritePre <buffer> :call <SID>StripTrailingWhitespaces()
	" Rust automatically remove trailing spaces
	autocmd FileType rust autocmd BufWritePre <buffer> :call <SID>StripTrailingWhitespaces()
	" XML should be indented with spaces preferrably
	autocmd FileType xml setlocal expandtab shiftwidth=2 tabstop=2
	autocmd FileType json setlocal expandtab shiftwidth=2 tabstop=2

	au FileType html,htmldjango,sql,javascript setlocal indentexpr=
" }
" 

" Font and Color {
	if has("gui_running")
		if has("win32")
			set guifont=Consolas:h12
		else
			set guifont=DejaVu\ Sans\ Mono\ for\ Powerline:h13
		endif

		set antialias
		set linespace=3
		" Prevent mouse usage, trackpad makes it way too easy to resort to
		" clicking to move the cursor
		set mouse=c
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

	function EnableBackgroundTransparency()
		hi Normal guibg=NONE ctermbg=NONE
	endfunction
	
	" autocmd ColorScheme * call CorrectColorScheme()
	autocmd ColorScheme * call EnableBackgroundTransparency()

	colorscheme Tomorrow-Night

	" Use underline on language server errors
	highlight ALEError cterm=underline
	highlight ALEWarning cterm=underline
" }

" UI {
	" Shorter timeouts after keypresses before updating UI
	set timeoutlen=500 ttimeoutlen=500

	set list
	set listchars=eol:¬,nbsp:¬,tab:▸\ ,trail:·,precedes:«,extends:»
	" Display hidden unicode characters as hex
	set display+=uhex
	
	" Relative line numbers on, with current line showing current line number
	set relativenumber
	set number
	set cursorline
	
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
	" No visual bell either
	set t_vb=

	if has("gui_running")
		" Remove toolbar, menubar, scrollbar, dialogs
		set guioptions-=T
		set guioptions-=m
		set guioptions-=s
		set guioptions+=c

		" Ensure we always re-run t_vb when gui is loaded since it resets it
		autocmd! GUIEnter * set vb t_vb=
	endif
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

	nnoremap <F3> :noh<CR>

	" Allow saving of files as sudo when vim is not running under sudo
	" NOTE: Does not work in gvim
	cmap w!! w !sudo tee > /dev/null %

	map <Leader>j :bnext<CR>
	map <Leader>k :bprevious<CR>

	map <Leader>w :bp\|bd #<CR>

	map <Leader>= <C-w>=

	map <Leader><Tab> :NERDTreeToggle<CR>
	map <leader>r :NERDTreeFind<cr>

	" Remap CMD + F to fullscreen mode
	if has("gui_running")
		if !has("win32")
			macmenu &Edit.Find.Find\.\.\. key=<nop>
			map <D-f> :set invfu<CR>
		endif
	endif
" }

" Include local settings {
	if filereadable(glob($HOME . "/dotfiles/projects.vim"))
		source $HOME/dotfiles/projects.vim
	endif
" }