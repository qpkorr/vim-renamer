@echo off
SET exePath=c:\Program Files (x86)\Vim\vim80\gvim.exe
SET menuEntry=Rename with VimRenamer

rem add it for all file types
@reg add "HKEY_CLASSES_ROOT\*\shell\%menuEntry%"         /t REG_SZ /v "" /d "%menuEntry%" /f
@reg add "HKEY_CLASSES_ROOT\*\shell\%menuEntry%"         /t REG_EXPAND_SZ /v "Icon" /d "%exePath%,0" /f
@reg add "HKEY_CLASSES_ROOT\*\shell\%menuEntry%\command" /t REG_SZ /v "" /d "%exePath% -c \"silent cd %%2^|Renamer\"" /f

rem add it for folders
@reg add "HKEY_CLASSES_ROOT\Folder\shell\%menuEntry%"         /t REG_SZ /v "" /d "%menuEntry%" /f
@reg add "HKEY_CLASSES_ROOT\Folder\shell\%menuEntry%"         /t REG_EXPAND_SZ /v "Icon" /d "%exePath%,0" /f
@reg add "HKEY_CLASSES_ROOT\Folder\shell\%menuEntry%\command" /t REG_SZ /v "" /d "%exePath% -c \"silent cd %%1^|Renamer\"" /f
pause
