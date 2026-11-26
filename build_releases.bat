@echo off
setlocal
set "GODOT=C:\Users\matth\OneDrive\Documents\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%USERPROFILE%\Documents\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=C:\Users\Work9\Documents\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
    echo Edit build_releases.bat to point GODOT to your Godot 4.7+ executable.
    pause
    exit /b 1
)

if not exist "builds\windows" mkdir "builds\windows"
echo Packing UdderlyIdle.pck and building standalone Windows / Steam Deck Proton folder...
"%GODOT%" --headless --path "%~dp0." --export-pack "Windows" "builds\windows\UdderlyIdle.pck"
copy /Y "%GODOT%" "builds\windows\UdderlyIdle.exe" >nul

echo.
echo Build complete! Run builds\windows\UdderlyIdle.exe
pause
