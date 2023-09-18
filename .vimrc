" File: .vimrc
"
"
" Gotta be first
set nocompatible

" Leader - ( Spacebar )
let mapleader = " "

filetype off

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'

" ----- Making Vim look good ------------------------------------------
Plugin 'tomasr/molokai'
Plugin 'vim-airline/vim-airline'

" ----- Vim as a programmer's text editor -----------------------------
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'tiagofumo/vim-nerdtree-syntax-highlight'
Plugin 'xolox/vim-misc'
Plugin 'xolox/vim-easytags'
Plugin 'junegunn/vim-easy-align'
Plugin 'mbbill/undotree', { 'on': 'UndotreeToggle' }
Plugin 'jiangmiao/auto-pairs'
Plugin 'ervandew/supertab'
Plugin 'christoomey/vim-system-copy'
Plugin 'vim/killersheep'
" Reads any .editorconfig files and sets spacing etc automatically
Plugin 'editorconfig/editorconfig-vim'

" ----- Working with Git ----------------------------------------------
Plugin 'tpope/vim-fugitive'

" ----- Other text editing features -----------------------------------
Plugin 'scrooloose/nerdcommenter' 
Plugin 'Chiel92/vim-autoformat'
Plugin 'Yggdroot/indentLine'
Plugin 'sickill/vim-pasta'

" ----- Syntax plugins ------------------------------------------------
Plugin 'dense-analysis/ale'
Plugin 'pangloss/vim-javascript'
Plugin 'leafgarland/typescript-vim'
"Plugin 'rust-lang/rust.vim'

" ---- Extras/Advanced plugins ----------------------------------------
" Rainbow match parenthesis  get different colors, to help track
" mis mathed parens
" Plugin 'luochen1990/rainbow'
Plugin 'vim-scripts/Rainbow-parenthesis'
Plugin 'tpope/vim-dispatch'
" Plugin 'thaerkh/vim-workspace'


"Highlight and strip trailing whitespace
Plugin 'ntpeters/vim-better-whitespace'

" Easily surround chunks of text
Plugin 'tpope/vim-surround'

" Easily do a search using ag
Plugin 'wincent/ferret'

" Dev icons for nerdtreeFancy start screen
Plugin 'ryanoasis/vim-devicons' 

" Fancy start screen
Plugin 'mhinz/vim-startify'

" React code snippets
" lugin 'epilande/vim-react-snippets'

" Ultisnips
" Plugin 'SirVer/ultisnips'

call vundle#end()

filetype plugin indent on

" --- General settings ---
set gdefault      " Never have to type /g at the end of search / replace again
set ignorecase    " case insensitive searching (unless specified)
set smartcase
set hlsearch
set noequalalways winminheight=0 winheight=9999 helpheight=9999


""" SYSTEM CLIPBOARD COPY & PASTE SUPPORT
set pastetoggle=<F2> "F2 before pasting to preserve indentation

"Copy paste to/from clipboard
map <silent><Leader>p :set paste<CR>o<esc>"*]p:set nopaste<cr>"
map <silent><Leader><S-p> :set paste<CR>O<esc>"*]p:set nopaste<cr>"

" Use Ctrl+C for clipboard copy in normal and visual mode
nnoremap <C-C> "+y
vnoremap <C-C> "+y

" Use Ctrl+V for clipboard paste in normal and insert mode
nnoremap <C-V> "+p
inoremap <C-V> <C-O>"+p

" Stop highlight after searching
nnoremap <silent> <leader>, :noh<cr> 
set incsearch
set showmatch

" ----- Plugin-Specific Settings --------------------------------------

" ----- altercation/monokai settings -----
" Toggle this to "light" for light colorscheme
set background=dark

" Since the colorscheme is in a plugin, it may not always be there at first, so
" we put it into a try-catch
try
    " A nice dark color scheme that's easy on the eyes
    colorscheme molokai
catch
    " Don't do anything, just supress the 'colorscheme doesn't exist' error.
endtry

" line numbering
set nu

" set spacing to use spaces, not tabs, 2 spaces per indent
set tabstop=2 softtabstop=2 shiftwidth=2 expandtab shiftround

" 256 terminal colors to be supa pretty
set t_Co=256

" put a line at column 81
" set cc=81

" syntax hilighting
syntax enable

" mice are cool
if has('mouse')
    set mouse=a
endif

" removes modelines (because who knows what's in a file)
set modelines=0

" keeps a buffer above and below line when scrolling
set scrolloff=3

" smarter indenting
set autoindent
set smartindent

" load filetype specific indentation
filetype indent on

" show (partial) command in the last line of the screen
set showcmd

" improved command autocompletion
set wildmenu
set wildmode=list:longest

" instead of dinging, flash cursor
set visualbell

" hilight or underline cursor line, depending on your scheme
set cursorline

" smoother performance since we use modern terminals
set ttyfast

" show cursor location in the bottom
set ruler

" make backspace act more sanely with tabs
set backspace=indent,eol,start

" always show file status
set laststatus=2

" change line numbering to be relative to current line, to make commands easier
set relativenumber
augroup beziRelative
    au!
    au WinEnter * :set relativenumber
    au WinLeave * :set relativenumber!
augroup END

" text-wrapping
set wrap
set textwidth=80
set colorcolumn=+1

" Auto resize Vim splits to active split
set winwidth=104
set winheight=5
set winminheight=5
set winheight=999

"HTML Editing
set matchpairs+=<:>

" These are really nice options for handling text wrapping in comments
" see :help fo-table for what exactly they do
set formatoptions=qrn2tcoj

" ================ Scrolling ========================

set scrolloff=8         "Start scrolling when we're 8 lines away from margins
set sidescrolloff=15
set sidescroll=1

"Toggle relative numbering, and set to absolute on loss of focus or insert mode
set rnu
function! ToggleNumbersOn()
    set nu!
    set rnu
endfunction
function! ToggleRelativeOn()
    set rnu!
    set nu
endfunction
autocmd FocusLost * call ToggleRelativeOn()
autocmd FocusGained * call ToggleRelativeOn()
autocmd InsertEnter * call ToggleRelativeOn()
autocmd InsertLeave * call ToggleRelativeOn()

"Use enter to create new lines w/o entering insert mode
nnoremap <CR> o<Esc>

"Below is to fix issues with the ABOVE mappings in quickfix window
autocmd CmdwinEnter * nnoremap <CR> <CR>
autocmd BufReadPost quickfix nnoremap <CR> <CR>

" Use tab to jump between blocks, because it's easier
nnoremap <tab> %
vnoremap <tab> %

" save whenever you lose focus
augroup beziAutoSave
    au!
    au FocusLost * :wa
augroup END

" remap jj to escape for easier times
inoremap jj <ESC>

" split by default to the right
set splitright

" Turn off extra back up files.  I find them to be annoying and I save enough
" that they're more of a nuisance when recovering from a crash than anything
" else

" don't use swap files
"set noswapfile

" remove  useless  backup files (a.c~)
"set nobackup
"set nowritebackup
"
" backup/swap/info/undo settings
set backup
set backupext     =-vimbackup
set backupskip    =
set undofile
set updatecount   =100
set backupdir   =~/.vim/tmp/backup
set undodir     =~/.vim/tmp/undo
set history       =1000
set lazyredraw
set directory   =~/.vim/tmp/swap/
set more

" remap 0 to first non-empty character
map 0 ^

" Automatically :write before running commands
set autowrite

" Reload files changed outside vim
set autoread

" Trigger autoread when changing buffers or coming back to vim in terminal.
au FocusGained,BufEnter * :silent! !

" ----- The ripgrep -----
if executable('rg')
  set grepprg=rg\ --color=never
  let g:ctrlp_user_command = 'rg %s --files --color=never --glob ""'
  let g:ctrlp_use_caching = 0
  " the nearest ancestor that contains one of these directories or
  " files: .git .hg .svn .bzr _darc
  let g:ctrlp_working_path_mode = 'ra'
endif

" Fancy arrow symbols, requires a patched font
" To install a patched font, run over to
"     https://github.com/abertsch/Menlo-for-Powerline
" download all the .ttf files, double-click on them and click Install
" Finally, uncomment the next line
let g:typescript_indent_disable = 1
let g:typescript_ignore_browserwords = 1

let g:airline_powerline_fonts = 1

" Show PASTE if in paste mode
let g:airline_detect_paste=1

" Show airline for tabs too
let g:airline#extensions#tabline#enabled = 1

" ----- tiagofumo/vim-nerdtree-syntax-highlight -----
let g:WebDevIconsOS = 'Linux'
let g:WebDevIconsUnicodeDecorateFolderNodes = 1
let g:DevIconsEnableFoldersOpenClose = 1
let g:DevIconsEnableFolderExtensionPatternMatching = 1
let NERDTreeDirArrowExpandable = "\u00a0" " make arrows invisible
let NERDTreeDirArrowCollapsible = "\u00a0" " make arrows invisible
let NERDTreeNodeDelimiter = "\u263a" " smiley face
augroup nerdtree
   autocmd!
   autocmd FileType nerdtree setlocal nolist " turn off whitespace characters
   autocmd FileType nerdtree setlocal nocursorline " turn off line highlighting for performance
augroup END

" Toggle NERDTree
function! ToggleNerdTree()
   if @% != "" && @% !~ "Startify" && (!exists("g:NERDTree") || (g:NERDTree.ExistsForTab() && !g:NERDTree.IsOpen()))
    :NERDTreeFind
   else
    :NERDTreeToggle
   endif
endfunction
" toggle nerd tree
nmap <silent> <leader>k :call ToggleNerdTree()<cr>
" find the current file in nerdtree without needing to reload the drawer
nmap <silent> <leader>y :NERDTreeFind<cr>

let NERDTreeShowHidden=1
let g:NERDTreeIgnore=['\.rbc$', '\~$', '\.pyc$', '\.db$', '\.sqlite$', '__pycache__']
let g:NERDTreeSortOrder=['^__\.py$', '\/$', '*', '\.swp$', '\.bak$', '\~$']
let g:NERDTreeChDirMode=2
let g:NERDTreeIndicatorMapCustom = {
  \ "Modified"  : "✹",
  \ "Staged"    : "✚",
  \ "Untracked" : "✭",
  \ "Renamed"   : "➜",
  \ "Unmerged"  : "═",
  \ "Deleted"   : "✖",
  \ "Dirty"     : "✗",
  \ "Clean"     : "✔︎",
  \ 'Ignored'   : '☒',
  \ "Unknown"   : "?"
  \ }


" ----- thaerkh/vim-workspace -----
" nnoremap <leader>s :ToggleWorkspace<CR>
" let g:workspace_autocreate =1
" let g:workspace_session_name = 'Session.vim'
" let g:workspace_session_disable_on_args = 1
" let g:workspace_autosave_ignore = ['gitcommit']


" ALE {{{
" ALE doesn't format and show the results ASAP. or atleast when do C-S
  let g:ale_set_highlights = 0
  let g:ale_change_sign_column_color = 0
  let g:ale_sign_column_always = 1
  let g:ale_sign_error = '✖'
  let g:ale_sign_warning = '⚠'
  let g:ale_echo_msg_error_str = '✖'
  let g:ale_echo_msg_warning_str = '⚠'
  let g:ale_echo_msg_format = '%severity% %s% [%linter%% code%]'

  let g:opamshare = substitute(system('opam config var share'),'\n$','','''')
  execute "set rtp+=" . g:opamshare . "/merlin/vim"

   let g:ale_linters = {
  \   'javascript': ['eslint'],
  \   'typescript': ['tsserver', 'tslint'],
  \   'typescriptreact': ['tsserver', 'tslint'],
  \   'ocaml': ['merlin'],
  \   'sh': ['shfmt', 'shellcheck'],
  \   'perl': ['perltidy', 'perlcritic'],
  \   'html': ['prettier']
  \}
  let g:ale_fixers = {}
  let g:ale_fixers['javascript'] = ['prettier']
  let g:ale_fixers['typescript'] = ['prettier']
  let g:ale_fixers['typescriptreact'] = ['prettier']
  let g:ale_fixers['json'] = ['prettier']
  let g:ale_fixers['perl'] = ['perltidy']
  let g:ale_fixers['css'] = ['prettier']
  let g:ale_fixers['rust'] = ['rustfmt']
  let g:ale_fixers['sh'] = ['shfmt']
  let g:ale_rust_cargo_use_clippy = executable('cargo-clippy')

  let g:ale_javascript_prettier_use_local_config = 1
  let g:ale_fix_on_save = 1
  
" augroup SyntaxSettings
"    autocmd BufNewFile,BufRead *.tsx set filetype=typescript
" augroup END

  " Write this in your vimrc file
  " let g:ale_lint_on_text_changed = 'never'
 " }}}

" ---------------------------- sirver/utilsnips -----------
" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
let g:UltiSnipsExpandTrigger="<C-l>"
let g:UltiSnipsJumpForwardTrigger="<C-b>"
let g:UltiSnipsJumpBackwardTrigger="<C-z>"


" ----- editorconfig/editorconfig.vim  settings -----
"set up path to editorconfig"
let g:EditorConfig_exec_path = findfile('.editorconfig', '.;')

" ----- xolox/vim-easytags settings -----
" Where to look for tags files
set tags=./.tags;,~/.vimtags
" Sensible defaults
let g:easytags_events = ['BufReadPost', 'BufWritePost']
let g:easytags_async = 1
let g:easytags_dynamic_files = 2
let g:easytags_resolve_links = 1
let g:easytags_suppress_ctags_warning = 1


"-----  luochen1990/rainbow -----
" turn on rainbow parens by default
let g:rainbow_active = 1

" disable in html (it messes up the syntax hilighting) and CSS, and fix the
" parens in SML (where the (* comments *) freak out).
let g:rainbow_conf = {
\   'ctermfgs': ['lightblue', 'lightyellow', 'lightcyan', 'lightmagenta'],
\   'operators': '_,_',
\   'parentheses': ['start=/(/ end=/)/ fold', 'start=/\[/ end=/\]/ fold', 'start=/{/ end=/}/ fold'],
\   'separately': {
\       '*': {},
\       'html': 0,
\       'css': 0,
\       'sml': {
\           'parentheses': ['start=/(\(\*\)\@!/ end=/\(\*\)\@<!)/', 'start=/\[/ end=/\]/ fold']
\       }
\   }
\}

" ----- ctrlpvim/ctrlp.vim settings -----
"
set wildignore+=*.a,*.o,*.so
set wildignore+=*.bmp,*.gif,*.jpg,*.png,*.ico
set wildignore+=.git,.hg,.svn
set wildignore+=*~,*.swp,*.tmp
set wildignore+=*/tmp/*,*/node_modules/*,*/vendor*,*/dist/* 

" ---- save file key bindings
"
" Ctrl + s to save,
" Ctrl + d to save and exit,
" Ctrl + q to exit discarding changes.
" Ctrl + a
"
" save files
inoremap <C-s> <esc>:w<cr>
nnoremap <C-s> :w<cr>
" save and exit
inoremap <C-d> <esc>:wq!<cr>
nnoremap <C-d> :wq!<cr>
"quit discarding changes
inoremap <C-q> <esc>:qa!<cr>
nnoremap <C-q> :qa!<cr>

" ---- selection  file key bindings
"  Ctrl + a to select all
map <C-a> <esc>ggVG<CR>

" CTRL-X and SHIFT-Del are Cut
vnoremap <C-X> "+x
vnoremap <S-Del> "+x

" ----- buffer settings -----
:nnoremap <F6> :buffers<CR>:buffer<Space>

""" MORE AWESOME HOTKEYS
"
"
" Run the q macro
nnoremap <leader>q @q

" bind CTRL-A to open a new tab and start searching
" nmap <leader>a :tab split<CR>:Ack ""<Left>

" Immediately search  for the word under the cursor  in a new tab.
" nmap <leader>A :tab split<CR>:Ack <C-r><C-w><CR>

" Paste  experience - (vim pasta)
nnoremap <leader>p p`[v`]=

" bind \ (backward slash) to grep shortcut
command! -nargs=+ -complete=file -bar Ag silent! grep! <args>|cwindow|redraw!
nnoremap \ :Ag<SPACE>
" Ag will search from project root
let g:ag_working_path_mode="r"

au BufAdd * "cd" fnameescape(getcwd())


" Quickly close windows
nnoremap <leader>x :x<cr>
nnoremap <leader>X :q!<cr>

" Delete current file
function! DeleteFile(...)
  if(exists('a:1'))
    let theFile=a:1
  elseif ( &ft == 'help' )
    echohl Error
    echo "Cannot delete a help buffer!"
    echohl None
    return -1
  else
    let theFile=expand('%:p')
  endif
  let delStatus=delete(theFile)
  if(delStatus == 0)
    echo "Deleted " . theFile
  else
    echohl WarningMsg
    echo "Failed to delete " . theFile
    echohl None
  endif
  return delStatus
endfunction
"delete the current file
com! Rm call DeleteFile()
"delete the file and quit the buffer (quits vim if this was the last file)
com! RM call DeleteFile() <Bar> q!

" automatically rebalance windows on vim resize
autocmd VimResized * :wincmd =

"update dir to current file
autocmd BufEnter * silent! cd %:p:h

augroup vimrcEx
  autocmd!

  " When editing a file, always jump to the last known cursor position.
  " Don't do it for commit messages, when the position is invalid, or when
  " inside an event handler (happens when dropping a file on gvim).
  autocmd BufReadPost *
    \ if &ft != 'gitcommit' && line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif

  " Set syntax highlighting for specific file types
  autocmd BufRead,BufNewFile *.md set filetype=markdown

  " autocmd BufRead *.jsx set ft=jsx.html
  " autocmd BufNewFile *.jsx set ft=jsx.html

  " Enable spellchecking for Markdown
  autocmd FileType markdown setlocal spell

  " Automatically wrap at 100 characters for Markdown
  autocmd BufRead,BufNewFile *.md setlocal textwidth=100

  " Automatically wrap at 100 characters and spell check git commit messages
  autocmd FileType gitcommit setlocal textwidth=100
  autocmd FileType gitcommit setlocal spell

  " Allow stylesheets to autocomplete hyphenated words
  autocmd FileType css,scss,sass,less setlocal iskeyword+=-
augroup END

" ## added by OPAM user-setup for vim / base ## 93ee63e278bdfc07d1139a748ed3fff2 ## you can edit, but keep this line
let s:opam_share_dir = system("opam config var share")
let s:opam_share_dir = substitute(s:opam_share_dir, '[\r\n]*$', '', '')

let s:opam_configuration = {}

function! OpamConfOcpIndent()
  execute "set rtp^=" . s:opam_share_dir . "/ocp-indent/vim"
endfunction
let s:opam_configuration['ocp-indent'] = function('OpamConfOcpIndent')

function! OpamConfOcpIndex()
  execute "set rtp+=" . s:opam_share_dir . "/ocp-index/vim"
endfunction
let s:opam_configuration['ocp-index'] = function('OpamConfOcpIndex')

function! OpamConfMerlin()
  let l:dir = s:opam_share_dir . "/merlin/vim"
  execute "set rtp+=" . l:dir
endfunction
let s:opam_configuration['merlin'] = function('OpamConfMerlin')

let s:opam_packages = ["ocp-indent", "ocp-index", "merlin"]
let s:opam_check_cmdline = ["opam list --installed --short --safe --color=never"] + s:opam_packages
let s:opam_available_tools = split(system(join(s:opam_check_cmdline)))
for tool in s:opam_packages
  " Respect package order (merlin should be after ocp-index)
  if count(s:opam_available_tools, tool) > 0
    call s:opam_configuration[tool]()
  endif
endfor
" ## end of OPAM user-setup addition for vim / base ## keep this line
"
"Fix for  https://github.com/leafgarland/typescript-vim/issues/168
"au BufNewFile,BufRead *.ts set filetype=typescriptreact
