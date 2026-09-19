@echo off
REM XENO RECLAIMER — RTX 3070 benchmark (decision M gate).
REM Usage: double-click, or  tools\bench_pc.bat "C:\path\to\Godot_v4.7.2-stable_win64.exe"
REM Result: docs\bench\bench_<stamp>_pc.md and .csv, then: git add docs\bench && git commit && git push
setlocal
cd /d "%~dp0\.."
set GODOT=%~1
if "%GODOT%"=="" set GODOT=%GODOT_BIN%
if "%GODOT%"=="" if exist "tools\.godot\Godot_v4.7.2-stable_win64.exe" set GODOT=tools\.godot\Godot_v4.7.2-stable_win64.exe
if "%GODOT%"=="" (
  echo Downloading Godot 4.7.2 ...
  mkdir tools\.godot 2>nul
  curl -L -o tools\.godot\godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip || goto :fail
  tar -xf tools\.godot\godot.zip -C tools\.godot || goto :fail
  set GODOT=tools\.godot\Godot_v4.7.2-stable_win64.exe
)
echo Using %GODOT%
"%GODOT%" --headless --path . --import
echo Running benchmark (about 4 minutes, do not touch the window)...
"%GODOT%" --path . --resolution 1600x900 res://levels/benchmark.tscn -- --bench-quit --bench-out=res://docs/bench --bench-label=pc
echo.
echo Done. Newest result:
dir /b /o-d docs\bench\bench_*_pc.md 2>nul | findstr /r "." >nul && for /f %%f in ('dir /b /o-d docs\bench\bench_*_pc.md') do (type "docs\bench\%%f" & goto :shown)
:shown
echo.
echo Next: git add docs/bench ^&^& git commit -m "bench: RTX 3070 gate run" ^&^& git push
pause
exit /b 0
:fail
echo Download failed. Pass the Godot 4.7.2 exe path as the first argument.
pause
exit /b 1
