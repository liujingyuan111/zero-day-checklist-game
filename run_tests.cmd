@echo off
setlocal
set "ZD_GODOT=%~1"
if not defined ZD_GODOT set "ZD_GODOT=godot"
set "ZD_ROOT=%~dp0."
"%ZD_GODOT%" --headless --path "%ZD_ROOT%" --editor --import --quit > "%ZD_ROOT%\tests\import.log" 2>&1
if errorlevel 1 goto failed
"%ZD_GODOT%" --headless --path "%ZD_ROOT%" --script tests/run_tests.gd > "%ZD_ROOT%\tests\engine.log" 2>&1
if errorlevel 1 goto failed
type "%ZD_ROOT%\tests\engine.log"
echo Report: tests\latest_report.json
exit /b 0
:failed
echo Test command failed. Check tests\import.log and tests\engine.log.
echo Usage: run_tests.cmd "C:\Path\To\Godot.exe"
exit /b 1
