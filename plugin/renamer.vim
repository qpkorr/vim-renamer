" renamer.vim
" Maintainer:   John Orr (john undersc0re orr yah00 c0m)
" Version:      2.1
" Last Change:  9 May 2015

" Introduction: {{{1
" Basic Usage:
" Show a list of file names in a directory, rename then in the vim buffer
" using vim editing commands, then have vim rename them on disk.

" Install Details:
" The usual pathogen setup - add renamer directory to $HOME/.vim/bundle
" directory.

" Reload guard and 'compatible' handling {{{1
let s:save_cpo = &cpo
set cpo&vim

if exists("loaded_renamer")
  finish
endif
if v:version < 700
  echoe "renamer.vim requires vim version 7.00 or greater (mainly because it uses list functionality)"
  finish
endif
let loaded_renamer = 1

" User configurable variables {{{1
" The following variables can be set in your .vimrc/_vimrc file to override
" those in this file, such that upgrades to the script won't require you to
" re-edit these variables.

" g:RenamerOriginalFileWindowEnabled {{{2
" Controls whether the window showing the original files is enabled or not
" It can be toggled with <Shift-T>
if !exists('g:RenamerOriginalFileWindowEnabled')
  let g:RenamerOriginalFileWindowEnabled = 0
endif

" g:RenamerInitialPathDepth {{{2
if !exists('g:RenamerInitialPathDepth')
  let g:RenamerInitialPathDepth = 1
endif

" g:RenamerShowLinkTargets {{{2
" Controls whether the resolved targets of any links will be shown as comments
if !exists('g:RenamerShowLinkTargets')
  let g:RenamerShowLinkTargets = 1
endif

" g:RenamerWildIgnoreSetting {{{2
if !exists('g:RenamerWildIgnoreSetting')
  let g:RenamerWildIgnoreSetting = 'VIM_WILDIGNORE_SETTING'
endif

" g:RenamerSupportColonWToRename {{{2
if !exists('g:RenamerSupportColonWToRename')
  let g:RenamerSupportColonWToRename = 0
endif




" Commands {{{1
" To run the script
if !exists(':Renamer')
  command -bang -nargs=? -complete=dir Renamer :call StartRenamer(1,-1,'<args>')
endif


" Keyboard mappings {{{1
"
" Mappings are defined only when the script starts, and are specific to the
" buffer.  Change them in the code if you want.
"
noremap <Plug>RenamerStart     :call StartRenamer(1,-1,getcwd())<CR>


function StartRenamer(needNewWindow, startLine, ...) "{{{1
    let startDirectory = ''
    if a:0 > 0
        let startDirectory = a:1
    endif
  call renamer#Start(a:needNewWindow, a:startLine, startDirectory)
endfunction

" Autocommands {{{1
"
" None at present
" augroup Renamer
" augroup END

" Cleanup and modelines {{{1
let &cpo = s:save_cpo

" vim:ft=vim:ts=2:sw=2:fdm=marker:fen:fmr={{{,}}}:
