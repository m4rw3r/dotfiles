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

	let mapleader="§"
	
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
	
	call plug#begin('~/.vim/plugged')
	
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

	" Clojure
	Plug 'guns/vim-clojure-highlight'
	Plug 'guns/vim-clojure-static'
	Plug 'tpope/vim-fireplace'

	" Tools
	Plug 'airblade/vim-rooter'
	Plug 'christoomey/vim-tmux-navigator'
	Plug 'dense-analysis/ale'
	Plug 'godlygeek/tabular'
	Plug 'kien/ctrlp.vim'
	Plug 'jgdavey/tslime.vim'
	Plug 'vim-scripts/L9'
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'
	Plug 'mileszs/ack.vim'
	Plug 'scrooloose/nerdtree'
	Plug 'scrooloose/syntastic'
	Plug 'tpope/vim-fugitive'
	Plug 'vim-scripts/Smart-Tabs'
	Plug 'vim-scripts/bufkill.vim'
	Plug 'luochen1990/rainbow'

	" Colorschemes
	Plug 'junegunn/seoul256.vim'
	Plug 'Lokaltog/vim-distinguished'
	Plug 'whatyouhide/vim-gotham'
	
	call plug#end()
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

	" Turn off signs in syntastic, syntastic garbles the editor window with
	" these
	let g:syntastic_enable_signs=0
	let g:syntastic_full_redraws=1

	" Ignore angularjs stupidity
	let g:syntastic_html_tidy_ignore_errors=['proprietary attribute "ng-']
" }

" ALE {
	" Gutter off
	let g:ale_set_signs=0
" }

" airline {
	set laststatus=2
	let g:airline_powerline_fonts=1
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
" }

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

	colorscheme Tomorrow-Night
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

	if has("gui_running")
		" No visual bell in GUI
		set t_vb=
		" Remove toolbar, menubar, scrollbar
		:set guioptions-=T
		:set guioptions-=m
		:set guioptions-=s
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
	map <Tab>   :bnext<CR>
	map <C-Tab> :bprevious<CR>

	map <Leader>w :bp\|bd #<CR>

	map <Leader>= <C-w>=

	map <Leader><Tab> :NERDTreeToggle<CR>

	" Remap CMD + F to fullscreen mode
	if has("gui_running")
		macmenu &Edit.Find.Find\.\.\. key=<nop>
		map <D-f> :set invfu<CR>
	endif
" }

" Include local settings {
	if filereadable(glob($HOME . "/dotfiles/projects.vim"))
		source $HOME/dotfiles/projects.vim
	endif
" }