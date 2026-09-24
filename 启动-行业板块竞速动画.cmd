@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

rem ============================================================
rem  Sector Race Animation Studio  launcher
rem
rem  Opens the local HTML app in Edge/Chrome "app mode":
rem  a standalone window with no address bar and no tabs.
rem  MP4 export uses the browser's built-in H.264 encoder,
rem  so no ffmpeg and no extra install is required.
rem
rem  NOTE: Chromium refuses a file:// URL that contains raw
rem  non-ASCII characters, so the path must be percent-encoded.
rem  Batch cannot do UTF-8 percent-encoding, so that one step is
rem  delegated to PowerShell. The folder path is handed over via
rem  an environment variable (UTF-16, so nothing gets mangled).
rem ============================================================

set "APPDIR=%~dp0"
set "APPFILE=%APPDIR%sector_race_studio.html"
if not exist "%APPFILE%" (
  echo [ERROR] sector_race_studio.html not found next to this launcher.
  echo         Keep both files in the same folder.
  pause
  exit /b 1
)

set "PROFILE=%LOCALAPPDATA%\SectorRaceStudio\profile"
set "OUTDIR=%USERPROFILE%\Desktop\sector-race-videos"
if not exist "%PROFILE%" mkdir "%PROFILE%" >nul 2>&1
if not exist "%OUTDIR%" mkdir "%OUTDIR%" >nul 2>&1

set "BROWSER="
for %%P in (
  "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
  "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
  "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
  "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
  "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
) do (
  if not defined BROWSER if exist %%P set "BROWSER=%%~P"
)

if not defined BROWSER (
  echo [ERROR] Microsoft Edge / Google Chrome not found.
  echo         One of them is required to provide the H.264 video encoder.
  pause
  exit /b 1
)

rem --- first run: send downloads straight to the output folder ---
set "PREFS=%PROFILE%\Default\Preferences"
if not exist "%PREFS%" (
  if not exist "%PROFILE%\Default" mkdir "%PROFILE%\Default" >nul 2>&1
  set "ESC=%OUTDIR:\=\\%"
  > "%PREFS%" echo {"download":{"default_directory":"!ESC!","prompt_for_download":false},"savefile":{"default_directory":"!ESC!"},"profile":{"exit_type":"Normal","exited_cleanly":true}}
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$f = $env:APPFILE;" ^
  "$u = 'file:///' + [uri]::EscapeUriString(($f -replace '\\','/'));" ^
  "Start-Process -FilePath $env:BROWSER -ArgumentList @('--app=' + $u, '--user-data-dir=' + $env:PROFILE, '--window-size=1420,950', '--no-first-run', '--no-default-browser-check', '--disable-sync', '--disable-features=Translate,TranslateUI')"

exit /b 0
