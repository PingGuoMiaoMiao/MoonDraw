@echo off
rem Build the moondraw engine CLI (native, no browser).
setlocal
cd /d "%~dp0\.."
moon build src\cli --target native --release || exit /b 1
echo.
echo   exe: _build\native\release\build\cli\cli.exe
echo   try: cli.exe render examples\flow\ticket.mmd out.svg
