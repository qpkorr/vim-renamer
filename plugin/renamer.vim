" renamer.vim
" Maintainer:   John Orr (john undersc0re orr yah00 c0m)
" Version:      1.4
" Last Change:  16 November 2011

" Introduction: {{{1
" Basic Usage:
" Show a list of file names in a directory, rename then in the vim
" buffer using vim editing commands, then have vim rename them on disk

" Description:
" Renaming a single file is easily done via an operating system file explorer,
" the vim file explorer (netrw.vim), or the command line.  When you want to
" rename a bunch of files, especially when you want to do a common text
" manipulation to those file names, this plugin may help.  It shows you all
" the files in the current directory, and lets you edit their names in the vim
" buffer.  When you're ready, issue the command ":Ren" to perform the mass
" rename.  Relative paths can be given, and new directories will be created,
" with 755 permissions, as required.

" Install Details:
" The usual - drop this file into your $HOME/.vim/plugin directory (unix)
" or $HOME/vimfiles/plugin directory (Windows), etc.
" Use the commands defined below to invoke the functionality (or redefine them
" elsewhere to what you want), and set the User Configurable Variables as
" desired.

" Installing As Windows XP Right Click Menu Option:
" To add running this script on a directory as a right click menu option,
" in Windows XP, if you are confident working with the registry, do as
" follows (NOTE - THESE INSTRUCTIONS CAME FROM THE WEB AND WORKED FOR
" ME, BUT I CAN'T GUARANTEE THEY ARE 100% SAFE):
" - Run the Registry Editor (REGEDIT.EXE).
" - Open My Computer\HKEY_CLASSES_ROOT\Directory and click on the
"   sub-item 'shell'.
" - Select New from the Edit menu, and then select Key.
" - Here, type VimRenamer and press Enter.
" - Double-click on the (default) value in the right pane, and type the name
"   to see in the meny, eg Rename Files with Vim Renamer, and press Enter.
" - Highlight the new key in the left pane, select New from the Edit menu,
"   and then select Key again.
" - Type the word Command for the name of this new key, and press Enter.
" - Double-click on the (default) value in the right pane, and type the full
"   path and filename to vim, along with the command as per the following
"   example line:
"   "C:\Program Files\vim\vim70\gvim.exe" -c "cd %1|Renamer"
"   Change the path as required, press Enter when done.
" - Close the Registry Editor when finished.

" Possible Improvements:
" - When starting renamer from an already running instance of vim, the cursor
"   begins in the original files window if that is enabled.  The reason for
"   this related to the fact that I couldn't get the window sizing to work
"   when renamer was invoked directly from the command line unless the cursor
"   stayed in the left window initially.  The way it is suits me, but if you
"   can help fix the problem, let me know.
" - Add different ways of sorting files, eg case insensitive, by date, size etc
" - Rationalise the code so directories and files use the same arrays indexed
"   by type of file.
" - Refactor to make functions smaller
" - Add installation instructions for Windows 7?  Or better still, updgrade
"   my Windows 7 box to XP :)
" - Make a suggestion!
"
" Changelog:   {{{1
" 1.0 - initial functionality
" 1.1 - added options to
"       a) support :w as substitute for :Ren, and
"       b) ignore wildignore settings when reading in files
"     - fixed highlighting after file deletion
"     - various other minor changes, eg naming the buffer.
" 1.2 - fix filename handling for linux - thanks Antonio Monizio
"     - improve :w support to avoid delay showing command line - thanks Sergey Bochenkov
"     - other minor improvements
" 1.3 - check that proposed filenames are valid before applying them
"     - add support for creating required directories - thanks to Glen Miner
"       for the request that made it finally happen.
"     - fix location of intermediate files to be the same as the source file.
"       (Particularly important for large files on slow-access media, as
"       they were being copied to and from local media.)
"       Thanks to Adam Courtemanche for finding and fixing the bug!
" 1.4 - fix permitted filenames problem on Mac OS - thanks Adam Courtemanche.
"     - fix bug when launching from within an existing buffer.

" Implementation Notes:

" Reload guard and 'compatible' handling {{{1
let s:save_cpo = &cpo
set cpo&vim

if exists("loaded_renamer")
  finish
endif
if v:version < 700
  echoe "renamer.vim requires vim version 7.00 or greater (mainly because it uses the new lists functionality)"
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

" Highlight links
" g:RenamerHighlightForPrimaryInstructions {{{2
if !exists('g:RenamerHighlightForPrimaryInstructions')
  let g:RenamerHighlightForPrimaryInstructions = 'Todo'
endif

" g:RenamerHighlightForSecondaryInstructions {{{2
if !exists('g:RenamerHighlightForSecondaryInstructions')
  let g:RenamerHighlightForSecondaryInstructions = 'comment'
endif

" g:RenamerHighlightForLinkInfo {{{2
if !exists('g:RenamerHighlightForLinkInfo')
  let g:RenamerHighlightForLinkInfo = 'comment'
endif

" g:RenamerHighlightForModifiedFilename {{{2
if !exists('g:RenamerHighlightForModifiedFilename')
  let g:RenamerHighlightForModifiedFilename = 'Constant'
endif

" g:RenamerHighlightForOriginalFilename {{{2
if !exists('g:RenamerHighlightForOriginalFilename')
  let g:RenamerHighlightForOriginalFilename = 'Keyword'
endif

" g:RenamerHighlightForNonWriteableEntries {{{2
if !exists('g:RenamerHighlightForNonWriteableEntries')
  let g:RenamerHighlightForNonWriteableEntries = 'NonText'
endif

" g:RenamerHighlightForOriginalDirectoryName {{{2
if !exists('g:RenamerHighlightForOriginalDirectoryName')
  let g:RenamerHighlightForOriginalDirectoryName = 'bold'
endif


" Commands {{{1
" To run the script
if !exists(':Renamer')
  command -bang -nargs=? -complete=dir Renamer :call StartRenamer(1,-1,'<args>')
endif


" Keyboard mappings {{{1
"
" All mappings are defined only when the script starts, and are
" specific to the buffer.  Change them in the code if you want.
"
" A template to defined a mapping to start this plugin is:
" noremap <Plug>RenamerStart     :call StartRenamer(1,-1,getcwd())<CR>
" if !hasmapto('<Plug>RenamerStart')
"   nmap <silent> <unique> <Leader>ren <Plug>RenamerStart
" endif


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

" vim:ft=vim:ts=2:sw=2:fdm=indent:fen:fmr={{{,}}}:
