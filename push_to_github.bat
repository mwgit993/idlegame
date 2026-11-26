@echo off
set "PATH=C:\Program Files\Git\cmd;%PATH%"
cd /d "%~dp0"
echo Pushing updates to https://github.com/mwgit993/idlegame ...
echo.
git push -u origin main
echo.
if %ERRORLEVEL% EQU 0 (
    echo SUCCESS! Everything is now live on https://github.com/mwgit993/idlegame
) else (
    echo Push did not complete. Check the message above and run push_to_github.bat again.
)
pause
