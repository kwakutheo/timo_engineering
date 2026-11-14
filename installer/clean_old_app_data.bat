@echo off
setlocal
title Timo's Engineering - Clean Old App Data
color 0F

echo ======================================================================
echo           TIMO'S ENGINEERING SERVICES - APP DATA CLEANER
echo ======================================================================
echo.
echo  This tool will safely remove old database files, cached records,
echo  and settings from previous versions of Timo's Engineering.
echo.
echo  Closing any running instances of the app...
taskkill /F /IM "timo_enginerring.exe" /T >nul 2>&1
taskkill /F /IM "Timo Invoice.exe" /T >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1

echo.
echo  Removing old application folders and database records...

:: 1. %LOCALAPPDATA%\Timo Invoice
if exist "%LOCALAPPDATA%\Timo Invoice" (
    echo   - Cleaning: %%LOCALAPPDATA%%\Timo Invoice
    rd /s /q "%LOCALAPPDATA%\Timo Invoice" >nul 2>&1
)

:: 2. %LOCALAPPDATA%\timo_enginerring
if exist "%LOCALAPPDATA%\timo_enginerring" (
    echo   - Cleaning: %%LOCALAPPDATA%%\timo_enginerring
    rd /s /q "%LOCALAPPDATA%\timo_enginerring" >nul 2>&1
)

:: 3. %APPDATA%\timo_enginerring
if exist "%APPDATA%\timo_enginerring" (
    echo   - Cleaning: %%APPDATA%%\timo_enginerring
    rd /s /q "%APPDATA%\timo_enginerring" >nul 2>&1
)

:: 4. %APPDATA%\com.example\timo_enginerring
if exist "%APPDATA%\com.example\timo_enginerring" (
    echo   - Cleaning: %%APPDATA%%\com.example\timo_enginerring
    rd /s /q "%APPDATA%\com.example\timo_enginerring" >nul 2>&1
)

:: Secondary sweep via PowerShell to ensure all locked/hidden sub-items are removed
powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -Recurse -Force \"$env:LOCALAPPDATA\Timo Invoice\", \"$env:LOCALAPPDATA\timo_enginerring\", \"$env:APPDATA\timo_enginerring\", \"$env:APPDATA\com.example\timo_enginerring\" -ErrorAction SilentlyContinue" >nul 2>&1

:: Clean up saved app credentials (PIN, salt, security keys) from Windows Credential Manager
echo   - Cleaning stored app passwords and security PINs...
powershell -NoProfile -ExecutionPolicy Bypass -Command "cmdkey /list | Select-String 'Target:' | ForEach-Object { $t = $_.Line.Substring($_.Line.IndexOf('Target:') + 7).Trim(); if ($t -match 'flutter_secure_storage|pin_|timo') { cmdkey /delete:$t >$null 2>&1 } }" >nul 2>&1

echo.
echo ======================================================================
echo  [SUCCESS] All old app data has been completely cleared!
echo ======================================================================
echo.
echo  You can now run the new installer to install the updated app.
echo.
echo  Press any key to close this window...
pause >nul

