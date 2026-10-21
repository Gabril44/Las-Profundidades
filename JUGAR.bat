@echo off
setlocal
set "LOVE_EXE=%ProgramFiles%\LOVE\love.exe"
if exist "%LOVE_EXE%" goto run
set "LOVE_EXE=%ProgramFiles(x86)%\LOVE\love.exe"
if exist "%LOVE_EXE%" goto run
where love.exe >nul 2>nul
if not errorlevel 1 (
  set "LOVE_EXE=love.exe"
  goto run
)
echo No se encontro LÖVE2D.
echo Instalalo desde https://love2d.org/ y volve a ejecutar este archivo.
pause
exit /b 1
:run
"%LOVE_EXE%" "%~dp0."
