" renamer.vim
" Maintainer:   John Orr (john undersc0re orr yah00 c0m)
" Version:      2.0
" Last Change:  08 Jul 2012

" 'compatible' handling {{{1
let s:save_cpo = &cpo
set cpo&vim

" Script variables {{{1
let s:hashes = '### '
let s:linksTo = 'LinksTo: '
let s:linkPrefix = ' '.s:hashes.s:linksTo
let s:header = [
      \ "Renamer: change names then give command :Ren" . (g:RenamerSupportColonWToRename ? " (or :w)" : '') . "\n" ,
      \ "ENTER=chdir, T=toggle original files, F5=refresh, Ctrl-Del=delete\n" ,
      \ ">=one more level, <=one less level\n" ,
      \ "Do not change the number of files listed (unless deleting)\n"
      \ ]
let s:headerLineCount = len(s:header) + 2 " + 2 because of extra lines added later
let b:renamerSavedDirectoryLocations = {}

if has('dos16')||has('dos32')||has('win16')||has('win32')||has('win64')||has('win32unix')||has('win95')
  " With info from http://support.grouplogic.com/?p=1607 and
  " http://en.wikipedia.org/wiki/Filename
  " let s:validChars = '[-\[\]a-zA-Z0-9`~!@#$%^&()_+={};'',. ]'
  let s:validChars = '[^<>:"/\\|?*]' " Handle non-english characters as well - be relaxed about what is allowed. Thanks dobogo.
  let s:separator = '[\\/]'
  let s:fileIllegalPatterns =  '\v( $)|(\.$)|(.{256})|^(com[1-9]|lpt[1-9]|con|nul|prn)$'
  let s:fileIllegalPatternsGuide = [ 'a space at the end of the filename', 'a period at the end of the filename', 'more than 255 characters', 'a prohibited filename for DOS/Windows']
  let s:filePathIllegalPatterns =  '\v(.{261})'
  let s:filePathIllegalPatternsGuide = [ 'more than 260 characters']

elseif has('macunix') " May well have 'mac' as well, but this one is more permissive
  let s:validChars = '[^:]'
  let s:separator = '[/]'
  let s:fileIllegalPatterns =  '\v(^\.)|(.{256})'
  let s:fileIllegalPatternsGuide = [ 'a period as the first character', 'more than 255 characters']
  let s:filePathIllegalPatterns =  'There are no illegal filepath patterns for OS X on macs:'
  let s:filePathIllegalPatternsGuide = []

elseif has('unix')
  let s:validChars = '.'  " No illegal characters
  let s:separator = '[/]'
  let s:fileIllegalPatterns =  '\v(.{256})'
  let s:fileIllegalPatternsGuide = [ 'more than 255 characters']
  let s:filePathIllegalPatterns =  'There are no illegal filepath patterns on unix'
  let s:filePathIllegalPatternsGuide = []

elseif has('mac')
  let s:validChars = '[^:]'
  let s:separator = '[/]'
  let s:fileIllegalPatterns =  '\v(.{32})'
  let s:fileIllegalPatternsGuide = ['more then 31 characters']
  let s:filePathIllegalPatterns =  'There are no illegal filepath patterns for OS 9 on macs:'
  let s:filePathIllegalPatternsGuide = []

else
  " POSIX defaults
  let s:validChars = '[A-Za-z0-9._-]'
  let s:separator = '[/]'
  let s:fileIllegalPatterns =  '\v(.{256})'
  let s:fileIllegalPatternsGuide = [ 'more than 255 characters']
  let s:filePathIllegalPatterns =  'There are no illegal filepath patterns for the default charset'
  let s:filePathIllegalPatternsGuide = []
endif


" Main Functions

" Launch Renamer
" Optional arg is the directory to start Renamer in.
function renamer#Start(needNewWindow, startLine, startDirectory) "{{{1
  " The main function that starts the app

  " Prevent a report of our actions from showing up
  let oldRep=&report
  let save_sc = &sc
  set report=10000 nosc

  " Get a blank window, either by
  if a:needNewWindow && !exists('b:renamerDirectory')
    " a) creating a window if non exists, or
    if bufname('') != '' || &mod
      new
    else
      silent %delete _
    endif
    let b:renamerSavedDirectoryLocations = {}
    let b:renamerPathDepth = g:RenamerInitialPathDepth
  else
    " b) deleting the existing window content if renamer is already running
    silent %delete _
  endif

  if g:RenamerOriginalFileWindowEnabled
    " Set scrollbinding in case the original files window is enabled so they
    " will scroll together.  Seems important to do it early in this function
    " to ensure it's processed for the correct buffer.
    setlocal scrollbind
  endif

  " Process optional parameters to this function and
  " set the directory to process
  if a:startDirectory != ''
    let b:renamerDirectory = renamer#Path(a:startDirectory)
  elseif !exists('b:renamerDirectory')
    let b:renamerDirectory = renamer#Path(getcwd())
  endif

  " Get an escaped version of b:renamerDirectory for later common use
  let b:renamerDirectoryEscaped = escape(b:renamerDirectory, '[]`~$*\')

  " Set the title, since the renamer window won't have one
  let &titlestring='Vim Renamer ('.b:renamerDirectory.') - '.v:servername
  set title

  " Get a list of all the files
  " Since glob follows 'wildignore' settings and this may well be undesirable,
  " we may ignore such directives
  if g:RenamerWildIgnoreSetting != 'VIM_WILDIGNORE_SETTING'
    let savedWildignoreSetting = &wildignore
    let &wildignore = g:RenamerWildIgnoreSetting
  endif

  " Unix and Windows need different things due to differences in possible filenames
  if has('unix')
    let basePath = b:renamerDirectoryEscaped
  else
    let basePath = b:renamerDirectory
  endif

  let globPath = basePath . "/*"
  let pathfiles = renamer#Path(glob(globPath))
  let i = 2
  while i <= b:renamerPathDepth
    let globPath = basePath . repeat("/*", i)
    let pathfilesToAdd = renamer#Path(glob(globPath))
    if len(pathfilesToAdd) > 0
      let pathfiles .= "\n" . pathfilesToAdd
    endif
    let i += 1
  endwhile

  if pathfiles != "" && pathfiles !~ "\n$"
    let pathfiles .= "\n"
  endif

  " Restore Wildignore settings
  if g:RenamerWildIgnoreSetting != 'VIM_WILDIGNORE_SETTING'
    let &wildignore = savedWildignoreSetting
  endif


  " Remove the directory from the filenames
  let filenames = substitute(pathfiles, b:renamerDirectoryEscaped . '/', '', 'g')

  " Calculate what to display on the screen and what to keep for when the
  " process is done
  " First declare some variables.  The list is long, due to differences
  " between
  " a) directories and files
  " b) writeable vs non-writeable items
  " c) symbolic links vs real files (hard links)
  " d) full paths needed for processing vs filename only for display
  " e) display text (eg including link resolutions) vs pure filenames
  " f) syntax highlighting issues, eg only applying a highlight to one
  "    specific line
  " ...however... some of these things could be rationalised using
  " multi-dimensional arrays.
  let pathfileList = sort(split(pathfiles, "\n"), 1) " List including full pathnames
  let filenameList = sort(split(filenames, "\n"), 1) " List of just filenames
  let numFiles = len(pathfileList)
  let writeableFilenames = []                        " The name only (no path) of all writeable files
  let writeableFilenamesEntryNums = []               " Used to calculate the final line number the name appears on
  let writeableFilenamesIsLink = []                  " Boolean, whether it's a link or not (affects syntax highlighting)
  let writeableFilenamesPath = []                    " Full path and name of each writeable file
  let writeableDirectories = []                      " Repeated for directories...
  let writeableDirectoriesEntryNums = []
  let writeableDirectoriesIsLink = []
  let writeableDirectoriesPath = []
  let b:renamerNonWriteableEntries = []

  let displayText  = s:hashes.join(s:header, s:hashes)   " Initialise the display text, start with the preset header
  let displayText .= s:hashes."Currently editing: "
  let displayText .= renamer#Path(b:renamerDirectory . repeat("/*", b:renamerPathDepth)) . "\n"
  let displayText .= "# ../\n"

  let directoryDisplayText = ''                      " Display text for the directory parts
  let fileDisplayText = ''                           " Display text for the file parts
  let b:renamerMaxWidth = 0                          " Max width of an entry, to help with original file names window sizing

  let i = 0                                          " Main loop variable over all files
  let fileEntryNumber = 0                            " Index for file entries (writeable or not)
  let dirEntryNumber = 0                             " Index for directory entries (writeable or not)

  " Main loop for each file
  while i < numFiles

    " Link handling - decide if we need to add link info
    let addLinkInfo = 0
    let resolved = resolve(pathfileList[i])
    if resolved != pathfileList[i] && g:RenamerShowLinkTargets
      let addLinkInfo = 1
      let resolved = substitute(resolved, '\\', '\/', 'g')
      if isdirectory(resolved)
        let resolved .= '/'
      endif
    endif

    " Now process as writeable/nonwriteable, files/directories, etc.
    "
    if filewritable(pathfileList[i])
      " Writeable entries
      let text = filenameList[i]
      if isdirectory(pathfileList[i])
        " Writeable directories
        let writeableDirectories += [ filenameList[i] ]
        let writeableDirectoriesEntryNums += [ dirEntryNumber ]
        let writeableDirectoriesPath += [ pathfileList[i] ]
        let text .= "/"
        if addLinkInfo
          let writeableDirectoriesIsLink += [ 1 ]
          let text .= s:linkPrefix.resolved
        else
          let writeableDirectoriesIsLink += [ 0 ]
        endif
        let directoryDisplayText .= text."\n"
        let dirEntryNumber += 1
      else
        " Writeable files
        let writeableFilenames += [ filenameList[i] ]
        let writeableFilenamesEntryNums += [ fileEntryNumber ]
        let writeableFilenamesPath += [ pathfileList[i] ]
        if addLinkInfo
          let writeableFilenamesIsLink += [ 1 ]
          let text .= s:linkPrefix.resolved
        else
          let writeableFilenamesIsLink += [ 0 ]
        endif
        let fileDisplayText .= text."\n"
        let fileEntryNumber += 1
      endif
    else
      " Readonly entries
      let b:renamerNonWriteableEntries += [ pathfileList[i] ]
      if isdirectory(pathfileList[i])
        " Readonly directories
        let text = '# '.filenameList[i].'/ '.s:hashes.'Not writeable '.s:hashes
        if addLinkInfo
          let text .= s:linkPrefix.resolved
        endif
        let directoryDisplayText .= text."\n"
        let dirEntryNumber += 1
      else
        " Readonly files
        let text = '# '.filenameList[i].' '.s:hashes.'Not writeable '.s:hashes
        if addLinkInfo
          let text .= s:linkPrefix.resolved
        endif
        let fileDisplayText .= text."\n"
        let fileEntryNumber += 1
      endif
    endif
    let b:renamerMaxWidth = max([b:renamerMaxWidth, (exists('*strdisplaywidth') ? strdisplaywidth(text) : len(text))])
    let i += 1
  endwhile

  " Save the original names in the order they appear on the screen
  let b:renamerOriginalPathfileList = copy(writeableDirectoriesPath)
  let b:renamerOriginalPathfileList += copy(writeableFilenamesPath)

  " Display the text to the user
  let b:renamerEntryDisplayText = directoryDisplayText . fileDisplayText
  put =displayText
  if b:renamerEntryDisplayText != ''
    put =b:renamerEntryDisplayText
  endif
  " Remove a blank line created by 'put'
  1delete _

  " Set the buffer type
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal bufhidden=delete

  " Set the buffer name if not already set
  if bufname('%') != 'VimRenamer'
    exec 'file VimRenamer "' . b:renamerDirectoryEscaped . '"'
  endif

  " Setup syntax
  if has("syntax")
    exec "syn match RenamerSecondaryInstructions '^\s*".s:hashes.".*'"
    exec "syn match RenamerPrimaryInstructions   '^\s*".s:hashes."Renamer.*'"
    exec "syn match RenamerLinkInfo '".s:linkPrefix.".*'"
    syn match RenamerNonwriteableEntries         '^# .*'
    syn match RenamerModifiedFilename            '^\s*[^#].*'

    " Highlighting for files
    let i = 0
    while i < len(writeableFilenames)
      " Escape some characters for use in regex's
      let escapedFile = escape(writeableFilenames[i], '*[]\~".')
      " Calculate the line number for this entry, for line-specific syntax highlighting
      let lineNumber = dirEntryNumber + writeableFilenamesEntryNums[i] + s:headerLineCount + 1 " Get the line number
      " Start the match command
      let cmd = 'syn match RenamerOriginalFilename   "^\%'.lineNumber.'l'.escapedFile
      if writeableFilenamesIsLink[i] && g:RenamerShowLinkTargets
        " match linkPrefix also, but then exclude if from the match
        let cmd .= s:linkPrefix.'"me=e-'.len(s:linkPrefix)
      else
        let cmd .= '$"'
      endif
      exec cmd
      let i += 1
    endwhile

    " Highlighting for directories - duplicates file handling above - rationalise?
    let i = 0
    while i < len(writeableDirectories)
      " Escape some characters for use in regex's
      let escapedDir = escape(writeableDirectories[i], '*[]\~/') . '\/*'
      " Calculate the line number for this entry, for line-specific syntax highlighting
      let lineNumber = writeableDirectoriesEntryNums[i] + s:headerLineCount + 1
      " Start the match command
      let cmd = 'syn match RenamerOriginalDirectoryName   "^\%'.lineNumber.'l'.escapedDir
      if writeableDirectoriesIsLink[i] && g:RenamerShowLinkTargets
        let cmd .= s:linkPrefix.'"me=e-'.len(s:linkPrefix)
      else
        let cmd .= '$"'
      endif
      exec cmd
      let i += 1
    endwhile

    " Presets for the highlights
    highlight def link RenamerPrimaryInstructions Title
    highlight def link RenamerSecondaryInstructions Comment
    highlight def link RenamerLinkInfo PreProc
    highlight def link RenamerModifiedFilename Statement
    highlight def link RenamerOriginalFilename Normal
    highlight def link RenamerNonwriteableEntries NonText
    highlight def link RenamerOriginalDirectoryName Directory
  endif

  " Define command to do the rename
  command! -buffer -bang -bar -nargs=0 Ren     call renamer#PerformRename(0)
  command! -buffer -bang -nargs=0      RenTest call renamer#PerformRename(1)

  if g:RenamerSupportColonWToRename
    " Enable :w<cr> and :wq<cr> to work as well
    cnoremap <buffer> <CR> <C-\>eRenamerCheckUserCommand()<CR><CR>
    function! RenamerCheckUserCommand()
      let cmd = getcmdline()
      if cmd == 'w'
        let cmd = 'Ren'
      elseif cmd == 'wq'
        let cmd = "Ren|quit"
      endif
      return cmd
    endfunction
  endif

  " Define the mapping to change directories
  nnoremap <buffer> <silent> <CR> :call renamer#ChangeDirectory()<CR>
  nnoremap <buffer> <silent> <C-Del> :call renamer#DeleteEntry()<CR>
  nnoremap <buffer> <silent> T :call renamer#ToggleOriginalFilesWindow()<CR>
  nnoremap <buffer> <silent> <F5> :call renamer#Refresh()<CR>
  nnoremap <buffer> <silent> > :call renamer#ChangeLevel(1)<CR>
  nnoremap <buffer> <silent> < :call renamer#ChangeLevel(-1)<CR>

  " Position the cursor
  if a:startLine > 0
    call cursor(a:startLine, 1)
  else
    " Position the cursor on the parent directory line
    call cursor(s:headerLineCount,1)
  endif

  " If the user wants the window with with original files, create it
  if g:RenamerOriginalFileWindowEnabled
    call renamer#CreateOriginalFileWindow(a:needNewWindow, b:renamerMaxWidth, b:renamerEntryDisplayText)
  endif

  " Restore things
  let &report=oldRep
  let &sc = save_sc
endfunction

function renamer#CreateOriginalFileWindow(needNewWindow, maxWidth, entryDisplayText) "{{{1
  let currentLine = line('.')
  call cursor(1,1)

  if a:needNewWindow || g:RenamerOriginalFileWindowEnabled == 2
    " Create a new window to the left
    " 14 is the minimum reasonable, so set initial width to that
    lefta 14vnew

    " and prevent vim shrinking it
    setlocal winwidth=14

    setlocal modifiable
    setlocal nonumber
    if exists('+relativenumber')
      setlocal norelativenumber
    endif
    setlocal foldcolumn=0

    " Set the header text
    let headerText = [ s:hashes.'ORIGINAL' ,
          \ s:hashes.' FILES' ,
          \ s:hashes.'  DO' ,
          \ s:hashes.' NOT' ,
          \ s:hashes.'MODIFY!' ]
    let i = 0
    while i < s:headerLineCount
      if i < len(headerText)
        call setline(i+1, headerText[i])
      else
        call setline(i+1, '')
      endif
      let i += 1
    endwhile
  else
    " Go to the existing window, make it modifiable, and
    " delete the existing file entries
    wincmd h
    setlocal modifiable
    exec (s:headerLineCount+1).',$d'
  endif

  " Put the list of files/dirs
  exec s:headerLineCount.'put =a:entryDisplayText'

  " Set the buffer type
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal nomodifiable
  setlocal scrollbind

  " Position the cursor on the same line as the main window
  call cursor(currentLine,1)

  " Setup syntax
  if has("syntax")
    exec "syn match RenamerSecondaryInstructions '^\s*".s:hashes.".*'"
    syn match RenamerOriginalDirectoryName       '^\s*[^#].*[/\\]$'
    syn match RenamerOriginalFilename            '^\s*[^#].*[/\\]\@<!$'
  endif

  " Set the width of the left hand window, as small as we can
  let width = max([winwidth(0), a:maxWidth+1])
  " But don't use more than half the width of vim
  exec 'vertical resize '.min([&columns/2, width])

  if a:needNewWindow
    " Setting the window width to the right size is tricky if renamer is
    " started via a command line option, since the gui doesn't seem to be fully sized
    " yet so we can't do "lefta <SIZE>vnew".
    " So register it to be done on the VIMEnter event.  Seems to work.
    augroup Renamer
      " In case user is changing the gui size via a startup command, delay the
      " resize as long as possible, until &columns will hopeuflly have its
      " final value
      exec 'autocmd VIMEnter <buffer> exec "vertical resize ".min([&columns/2, '.width.'])|wincmd l|cursor('.currentLine.',1)'
      " exec 'autocmd CursorHold <buffer> exec "vertical resize ".min([&columns/2, '.width.'])|wincmd l'
    augroup END
  else
    " Move back to the editable window since we have no autocmd to do it
    wincmd l
    call cursor(currentLine,1)
  endif

  " Reset g:RenamerOriginalFileWindowEnabled to 1 in case it was 2 to create a new window
  let g:RenamerOriginalFileWindowEnabled = 1
endfunction

function renamer#PerformRename(isTest) "{{{1
  " The function to do the renaming

  " Prevent a report of our actions from showing up
  let oldRep=&report
  let save_sc = &sc
  set report=100000 nosc

  " Save the current line number, to return to it after renaming
  let savedLineNumber = line('.')

  try
    " Get the current lines
    let splitBufferText = getline(1, '$')
    let modifiedFileList = []
    let lineNo = 0
    let invalidFileCount = 0
    for line in splitBufferText
      let lineNo += 1
      if line !~ '^#'
        let line = substitute(line, s:linkPrefix.'.*','','')
        let line = substitute(line, '\/$','','')
        let invalidFileCount += renamer#ValidatePathfile(b:renamerDirectory, line, lineNo)
        let modifiedFileList += [ b:renamerDirectory . '/' . line ]
      endif
    endfor

    if invalidFileCount
      call s:EchoErr(invalidFileCount." name(s) had errors. Resolve and retry...")
      return
    endif

    let numOriginalFiles = len(b:renamerOriginalPathfileList)
    let numModifiedFiles = len(modifiedFileList)

    if numModifiedFiles != numOriginalFiles
      call s:EchoErr('Dir contains '.numOriginalFiles.' writeable files, but there are '.numModifiedFiles.' listed in buffer.  These numbers should be equal')
      return
    endif

    " The actual renaming process is a hard one to do reliably.  Consider a few cases:
    " 1. a -> c
    "    b -> c
    "    => This should give an error, else a will be deleted.
    " 2. a -> b
    "    b -> c
    "    This should be okay, but basic sequential processing would give
    "    a -> c, and b is deleted - not at all what was asked for!
    " 3. a -> b
    "    b -> a
    "    This should be okay, but basic sequential processing would give
    "    a remains unchanged and b is deleted!!
    " So - first check that all destination files are unique.
    " If yes, then for all files that are changing, rename them to
    " <fileIndex>_GOING_TO_<newName>
    " Then finally rename them to <newName>.

    " Check for duplicates
    let sortedModifiedFileList = sort(copy(modifiedFileList))
    let lastFile = ''
    let duplicatesFound = []
    for thisFile in sortedModifiedFileList
      if thisFile == lastFile
        let duplicatesFound += [ thisFile ]
      end
      let lastFile = thisFile
    endfor
    if len(duplicatesFound)
      echom "Found the following duplicate files:"
      for f in duplicatesFound
        echom f
      endfor
      call s:EchoErr("Fix the duplicates and try again")
      return
    endif

    " Rename to unique intermediate names
    let uniqueIntermediateNames = []
    let i = 0
    while i < numOriginalFiles
      if b:renamerOriginalPathfileList[i] !=# modifiedFileList[i]
        if filewritable(b:renamerOriginalPathfileList[i])
          " let newName = substitute(modifiedFileList[i], escape(b:renamerDirectory.'/','/\'),'','')
          let newName = substitute(modifiedFileList[i], b:renamerDirectoryEscaped,'','')
          let newDir = fnamemodify(modifiedFileList[i], ':h')
          if !isdirectory(newDir) && exists('*mkdir')
            " Create the directory, or directories required
            if a:isTest
              echom printf('Create %s', newDir)
            else
              call mkdir(newDir, 'p')
            endif
          endif
          if a:isTest
            echom printf('Move   %s -> %s', b:renamerOriginalPathfileList[i], simplify(b:renamerDirectory . newName))
            let i += 1
            continue
          endif
          if !isdirectory(newDir)
            call s:EchoErr("Attempting to rename '".b:renamerOriginalPathfileList[i]."' to '".newName."' but directory ".newDir." couldn't be created!")
            " Continue anyway with the other files since we've already started renaming
          else
            " To allow moving files to other directories, slashes must be "escaped" in a special way
            let newName = substitute(newName, '\/', '_FORWSLASH_', 'g')
            let newName = substitute(newName, '\\', '_BACKSLASH_', 'g')
            let uniqueIntermediateName = b:renamerDirectory.'/'.i.'_GOING_TO_'.newName
            if rename(b:renamerOriginalPathfileList[i], uniqueIntermediateName) != 0
              call s:EchoErr("Unable to rename '".b:renamerOriginalPathfileList[i]."' to '".uniqueIntermediateName."'")
              " Continue anyway with the other files since we've already started renaming
            else
              let uniqueIntermediateNames += [ uniqueIntermediateName ]
            endif
          endif
        else
          echom "File '".b:renamerOriginalPathfileList[i]."' is not writable and won't be changed"
        endif
      endif
      let i += 1
    endwhile

    if a:isTest
      return
    endif

    " Do final renaming
    for intermediateName in uniqueIntermediateNames
      let newName = b:renamerDirectory.'/'.substitute(intermediateName, '.*_GOING_TO_', '', '')
      let newName = substitute(newName, '_FORWSLASH_', '/', 'g')
      let newName = substitute(newName, '_BACKSLASH_', '\', 'g')
      if filereadable(newName)
        call s:EchoErr("A file called '".newName."' already exists - cancelling rename!")
        " Continue anyway with the other files since we've already started renaming
      else
        if rename(intermediateName, newName) != 0
          call s:EchoErr("Unable to rename '".intermediateName."' to '".newName."'")
          " Continue anyway with the other files since we've already started renaming
        endif
      endif
    endfor

    call renamer#Start(0,savedLineNumber,b:renamerDirectory)
  finally
    let &report=oldRep
    let &sc = save_sc
  endtry
endfunction

function renamer#ChangeDirectory() "{{{1
  let line = getline('.')
  exec "let isLinkedDir = line =~ '" . s:linksTo . ".*\/$'"
  if isLinkedDir
    " Save the line for the directory being left
    exec "let b:renamerSavedDirectoryLocations['".b:renamerDirectory."'] = ".line('.')

    " Get link destination in the case of linked dirs
    let b:renamerDirectory = simplify(substitute(line, '.*'.s:linkPrefix, '', ''))
  else
    let line = substitute(line, ' *'.s:hashes.'.*', '', '')
    if line !~ '\/$'
      " Not a directory, ignore
      normal! j0
      return
    else
      " Save the line for the directory being left
      exec "let b:renamerSavedDirectoryLocations['".b:renamerDirectory."'] = ".line('.')
      if line =~ '^#'
        let b:renamerDirectory = simplify(b:renamerDirectory.'/'.substitute(line, '^#\{1,} *', '', ''))
      else
        let b:renamerDirectory = b:renamerDirectory.'/'.line
      endif
    endif
  endif

  " Tidy up the path (remove trailing slashes etc)
  let b:renamerDirectory = renamer#Path(b:renamerDirectory)

  let lineForNewBuffer = -1
  if exists("b:renamerSavedDirectoryLocations['".b:renamerDirectory."']")
    let lineForNewBuffer = b:renamerSavedDirectoryLocations[b:renamerDirectory]
    unlet b:renamerSavedDirectoryLocations[b:renamerDirectory]
  endif

  " We must also change the current directory, else it can happen
  " that we are trying to rename the directory we're currently in,
  " which is never going to work
  exec 'cd' fnameescape(b:renamerDirectory)

  " Now update the display for the new directory
  call renamer#Start(0,lineForNewBuffer,b:renamerDirectory)
endfunction

function renamer#DeleteEntry() "{{{1
  let lineNum = line('.')
  let entry = getline(lineNum)
  " Remove leading comment chars
  let entry = substitute(entry, '^# *', '', '')
  " Remove trailing comment chars
  let entry = substitute(entry, ' *'.s:hashes.'.*', '', '')
  " Remove trailing slash on dirs
  let entry = substitute(entry, '\/$', '', '')
  " Add path
  let entryPath = b:renamerDirectory.'/'.substitute(entry, '\/$', '', '')

  " Try to find the entry in the starting lists.  If not found there's been a mistake
  let i = 0
  let listIndex = -1
  while i < len(b:renamerOriginalPathfileList)
    if entryPath == b:renamerOriginalPathfileList[i]
      let listIndex = i
      let listName = 'b:renamerOriginalPathfileList'
      break
    endif
    let i += 1
  endwhile
  if listIndex == -1
    let i = 0
    while i < len(b:renamerNonWriteableEntries)
      if entryPath == b:renamerNonWriteableEntries[i]
        let listIndex = i
        let listName = 'b:renamerNonWriteableEntries'
        break
      endif
      let i += 1
    endwhile
    if listIndex == -1
      call s:EchoErr("Renamer: DeleteEntry couldn't find entry '".entry."'")
      return
    endif
  endif

  " Deletion code in netrw.vim can't easily be reused, so it's reproduced here.
  " Thanks to Bram, Chip Campbell etc!
  let type = 'file'
  if isdirectory(entryPath)
    let type = 'directory'
  endif
  echohl Statement
  call inputsave()
  let ok = input("Confirm deletion of ".type." '".entryPath."' ","[{y(es)},n(o)] ")
  call inputrestore()
  echohl NONE
  if ok == ''
    let ok = 'no'
  endif
  let ok= substitute(ok,'\[{y(es)},n(o)]\s*','','e')
  if ok == '' || ok =~ '[yY]'
    if type == 'directory'
      " Try deleting with rmdir
      call system('rmdir "'.entryPath.'"')
      if v:shell_error != 0
        " Failed, try vim's own function
        let errcode = delete(entryPath)
        if errcode != 0
          " Failed - error message
          call s:EchoErr("Unable to delete directory '".entryPath."' - this script is limited to only delete empty directories")
          return
        endif
      endif
    else
      " Try deleting the file
      let errcode = delete(entryPath)
      if errcode != 0
        " Failed - error message
        call s:EchoErr("Unable to delete file '".entryPath."'")
        return
      endif
    endif

    " Restart renamer to reset everything
    call renamer#Start(0,lineNum,b:renamerDirectory)

  endif
endfunction

function renamer#ToggleOriginalFilesWindow() "{{{1
  " Toggle the original files window
  if g:RenamerOriginalFileWindowEnabled == 0
    let g:RenamerOriginalFileWindowEnabled = 2 " 2 => create the window as well
    call renamer#CreateOriginalFileWindow(0, b:renamerMaxWidth, b:renamerEntryDisplayText)
  else
    wincmd h
    bdelete
    let g:RenamerOriginalFileWindowEnabled = 0
  endif
endfunction

function renamer#ChangeLevel(step) "{{{1
  " Show more or less levels of files/dirs
  let oldPathDepth = b:renamerPathDepth
  let b:renamerPathDepth += a:step
  if b:renamerPathDepth < 1
    let b:renamerPathDepth = 1
    echom "Already displaying minimum levels"
  endif
  if b:renamerPathDepth != oldPathDepth
    call renamer#Refresh()
  endif
endfunction

function renamer#Refresh() "{{{1
  " Update the display in case directory contents have changed outside vim
  call renamer#Start(0,line('.'),b:renamerDirectory)
endfunction

" Support functions        {{{1

function s:EchoErr( msg ) "{{{2
  let v:errmsg = a:msg
  echohl ErrorMsg
  echomsg v:errmsg
  echohl None
endfunction

function renamer#Path(p)       "{{{2
  " Make sure a path has proper form
  if has("dos16") || has("dos32") || has("win16") || has("win32") || has("os2")
    let returnPath=substitute(a:p,'\\','/','g')
  else
    let returnPath=a:p
  endif
  " Remove trailing slashes (note - only from end of list, not from the end of
  " lines followed by return characters within the list)
  let returnPath=substitute(returnPath, '^\(.\{-1,}\)/*$', '\1', '')
  " Remove double slashes
  let returnPath=substitute(returnPath, '//\+', '/', 'g')
  return returnPath
endfunction

function renamer#ValidatePathfile(dir, line, lineNo) "{{{2
  " Validate characters provided
  " In theory we could/should match against \f, which is controlled by the
  " option 'isfname' - but in reality - it's not an option.  For example,
  " by default on Windows, isfname includes colon - in order for 'gf' to work
  " on paths like c:\windows\file.txt - but colon is not a valid character in
  " an actual file name, so it's misleading.  Also, ampersand is a valid
  " character in a Windows filename - but I can't seem to set it easily.
  " The simpler option is to use s:validChars...
  " Test the whole string first
  if match(a:line, '^'.s:validChars.'\+$') == -1
    " Be specific about which char(s) is/are invalid
    let invalidName = 0
    for c in split(a:line, '\zs')
      " For now, don't check any multi-byte characters
      if char2nr(c) < 255
        let validChar = (match(c, s:validChars) != -1) || (match(c, s:separator) != -1)
        if !validChar
          echom "Invalid character '".c."' in name '".a:line."' on line ".a:lineNo." valid chars '".s:validChars."'"
          let invalidName = 1
        endif
      endif
    endfor
    if invalidName
      return 1
    endif
  endif

  " Validate filename
  let filename = fnamemodify(a:line, ':t')
  if ! renamer#IsValidPattern(filename, s:fileIllegalPatterns, s:fileIllegalPatternsGuide, a:lineNo)
    return 1
  endif

  " Validate pathfile
  let pathfile = a:dir . '/' . a:line
  if ! renamer#IsValidPattern(pathfile, s:filePathIllegalPatterns, s:filePathIllegalPatternsGuide, a:lineNo)
    return 1
  endif

  return 0
endfunction

function renamer#IsValidPattern(string, patterns, correspondingMsgs, lineNo) "{{{1
  " Given a regex with multiple OR'd sub-patterns, check which ones match a string,
  " and print the corresponding messages for each match
  " patterns should be of the form '\v(A)|(B)|(C)....'
  let i = 0
  let invalid = 0

  let matchlist = matchlist(a:string, a:patterns)
  let submatches = matchlist[1:] " Strip the full match and the one
  while i < len(submatches)
    if submatches[i] != ''
      echom "Error: the name '".a:string."' on line ".a:lineNo." contains ".a:correspondingMsgs[i]
      let invalid = 1
    endif
    let i += 1
  endwhile
  if invalid
    return 0
  endif
  return 1
endfunction

" Cleanup and modelines {{{1
let &cpo = s:save_cpo

" vim:ft=vim:ts=2:sw=2:fdm=marker:fen:fmr={{{,}}}:
