@echo off
rem gdUnit4 CLI runner (D-032). GODOT_BIN is pinned to the winget install;
rem update this line when the pinned engine version changes (worklog D-003).
set "GODOT_BIN=C:\Users\j\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
rem %* passes through e.g. -a tests/combat for a single suite directory.
rem -c runs the complete set instead of aborting at the first failure.
call "%~dp0..\..\addons\gdUnit4\runtest.cmd" --ignoreHeadlessMode -c -a tests %*
