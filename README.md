# renamer.vim
Git repo for http://www.vim.org/scripts/script.php?script_id=1721

https://github.com/qpkorr/vim-renamer is the official github repo for the renamer.vim script on vim.org, and supercedes the above location.

The repo contains the files suitable for a vim pathogen "bundle" directory (google is your friend).

From renamer.txt, the help file:

## INTRODUCTION
Show a list of file names in a directory, rename then in the vim buffer
using vim editing commands, then have vim rename them on disk

## DESCRIPTION
Renaming a single file is easily done via an operating system file explorer,
the vim file explorer (netrw.vim), or the command line.  When you want to
rename a bunch of files, especially when you want to do a common text
manipulation to those file names, this plugin may help.  It shows you all
the files in the current directory (and optionally in those below it),
and lets you edit their names in the vim buffer.  When you're ready,
issue the command ":Ren" to perform the mass rename.  Relative paths
can be given, and new directories will be created, with 755 permissions,
as required.

## USAGE
Use the Renamer command invoke the functionality and set the User
Configurable Variables defined in plugin/renamer.vim as desired.

## INSTALL DETAILS
The usual pathogen setup - add renamer directory to $HOME/.vim/bundle
directory.

[ Snip ]

More details in the full renamer.txt file.
