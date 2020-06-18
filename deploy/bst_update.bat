@ECHO OFF
ECHO.
SETLOCAL



REM ===== REMOVE THIS BLOCK =====
ECHO Brainstorm update batch:
ECHO 1) Copy bst_update.bat where you want to download Brainstorm.
ECHO 2) Edit bst_update.bat and remove the block that is indicated.
ECHO 3) Double-click on bst_update.bat to run it.
ECHO 4) If you are not an admin: right-click, Run as administrator.
ECHO.
PAUSE
EXIT /B
REM =============================




ECHO Downloading updates...
powershell -Command "(New-Object Net.WebClient).DownloadFile('http://neuroimage.usc.edu/bst/getupdate.php?c=UbsM09', 'brainstorm3_update.zip')"

ECHO Deleting previous install...
RMDIR /S /Q brainstorm3

SET OutFolder=%CD%
SET ZipFile=%CD%\brainstorm3_update.zip

ECHO Unzipping...
set vbs="%temp%\_.vbs"
if exist %vbs% del /f /q %vbs%
>%vbs%  echo Set fso = CreateObject("Scripting.FileSystemObject")
>>%vbs% echo Set objShell = CreateObject("Shell.Application")
>>%vbs% echo Set objSource = objShell.NameSpace("%ZipFile%").Items()
>>%vbs% echo objShell.NameSpace("%OutFolder%").CopyHere(objSource)
>>%vbs% echo Set fso = Nothing
>>%vbs% echo Set objShell = Nothing
cscript //nologo %vbs%
if exist %vbs% del /f /q %vbs%

ECHO Deleting downloaded file...
DEL brainstorm3_update.zip

ECHO Done.
exit /b
