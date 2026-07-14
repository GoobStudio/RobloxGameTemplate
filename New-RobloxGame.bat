@echo off
setlocal EnableDelayedExpansion
title New Roblox Game

echo.
echo  Creates a new game from GoobStudio/RobloxGameTemplate.
echo  Make sure you already created an EMPTY repo on GitHub (no README).
echo  The project folder will be created in: %CD%
echo.

set "REPO_URL="
set /p "REPO_URL=Paste new GitHub repo URL: "
if not defined REPO_URL (
    echo No URL entered, nothing to do.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/GoobStudio/RobloxGameTemplate/main/New-RobloxGame.ps1'))) -RepoUrl '!REPO_URL!'"

echo.
pause
