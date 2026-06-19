@echo off
setlocal

set ROOT=%~dp0
set SLN=%ROOT%Beyond\Beyond.sln
set LAUNCHER_PUBLISH=%ROOT%Beyond\Launcher\bin\Release\net10.0\win-x64\publish
set DEST=%ROOT:~0,-1%

echo ========================================================
echo  Building Infinity-Beyond Standalone Launcher and Mod
echo ========================================================
echo.

:: --- Resolve the game directory (needed to compile the mod against the game's
::     managed assemblies). Set AQWI_GAME_DIR to skip the prompt. -------------
set "GAME_DIR=%AQWI_GAME_DIR%"
if not defined GAME_DIR (
    echo Enter the path to your AdventureQuest Worlds Infinity install folder.
    echo ^(The folder that contains the game's .exe and its *_Data folder.^)
    set /p "GAME_DIR=Game directory: "
)
set "GAME_DIR=%GAME_DIR:"=%"

if not exist "%GAME_DIR%\" (
    echo.
    echo ERROR: Game directory not found: "%GAME_DIR%"
    pause
    exit /b 1
)

:: Discover the "<name>_Data\Managed" folder by pattern (release-name agnostic).
set "MANAGED_DIR="
for /d %%D in ("%GAME_DIR%\*_Data") do (
    if exist "%%D\Managed\Assembly-CSharp.dll" set "MANAGED_DIR=%%D\Managed"
)
if not defined MANAGED_DIR (
    echo.
    echo ERROR: Could not find "*_Data\Managed\Assembly-CSharp.dll" under:
    echo   "%GAME_DIR%"
    echo Point this at the game's install folder.
    pause
    exit /b 1
)

echo Game directory : %GAME_DIR%
echo Managed folder : %MANAGED_DIR%
echo.

dotnet build "%SLN%" -c Release -p:AqwiGameDir="%GAME_DIR%" -p:AqwiManagedDir="%MANAGED_DIR%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo BUILD FAILED. Check errors above.
    pause
    exit /b 1
)

echo.
echo Bundling launcher dependencies into single file...
echo.

dotnet publish "%ROOT%Beyond\Launcher\Launcher.csproj" -c Release -r win-x64 --self-contained false

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo PUBLISH FAILED. Check errors above.
    pause
    exit /b 1
)

echo.
echo Deploying launcher...
echo.

if not exist "%LAUNCHER_PUBLISH%\BeyondLauncher.exe" (
    echo WARNING: Published launcher executable not found at:
    echo %LAUNCHER_PUBLISH%\BeyondLauncher.exe
    pause
    exit /b 1
)

:: Clean up old dll/pdb/json clutter from root folder
del /Q "%DEST%\*.dll" >nul 2>&1
del /Q "%DEST%\*.pdb" >nul 2>&1
del /Q "%DEST%\*.json" >nul 2>&1
del /Q "%DEST%\Beyond.exe" >nul 2>&1
del /Q "%DEST%\BeyondLauncher.exe" >nul 2>&1
if exist "%DEST%\runtimes" rmdir /S /Q "%DEST%\runtimes"

:: Copy published files from publish dir
copy /Y "%LAUNCHER_PUBLISH%\BeyondLauncher.exe" "%DEST%\" >nul
if exist "%LAUNCHER_PUBLISH%\BeyondLauncher.pdb" copy /Y "%LAUNCHER_PUBLISH%\BeyondLauncher.pdb" "%DEST%\" >nul

:: Copy native dependencies directly to root
set NATIVE_SRC=%ROOT%Beyond\Launcher\bin\Release\net10.0\win-x64
if exist "%NATIVE_SRC%\libSkiaSharp.dll" (
    copy /Y "%NATIVE_SRC%\av_libglesv2.dll" "%DEST%\" >nul
    copy /Y "%NATIVE_SRC%\libHarfBuzzSharp.dll" "%DEST%\" >nul
    copy /Y "%NATIVE_SRC%\libSkiaSharp.dll" "%DEST%\" >nul
)

:: Copy agent and harmony mod files to root
set BUILD_DIR=%ROOT%Beyond\build
if exist "%BUILD_DIR%\BeyondAgent.dll" (
    copy /Y "%BUILD_DIR%\BeyondAgent.dll" "%DEST%\" >nul
)
if exist "%BUILD_DIR%\0Harmony.dll" (
    copy /Y "%BUILD_DIR%\0Harmony.dll" "%DEST%\" >nul
)

:: Create a zip package with date and time
echo.
echo Packaging build into a ZIP archive...
echo.

for /f "tokens=*" %%i in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'"') do set DATETIME=%%i
set "ZIP_NAME=BeyondLauncher_%DATETIME%.zip"
set "TEMP_ZIP_DIR=%DEST%\BeyondLauncher"

if exist "%TEMP_ZIP_DIR%" rmdir /S /Q "%TEMP_ZIP_DIR%"
mkdir "%TEMP_ZIP_DIR%"

copy /Y "%DEST%\BeyondLauncher.exe" "%TEMP_ZIP_DIR%\" >nul
if exist "%DEST%\av_libglesv2.dll" copy /Y "%DEST%\av_libglesv2.dll" "%TEMP_ZIP_DIR%\" >nul
if exist "%DEST%\libHarfBuzzSharp.dll" copy /Y "%DEST%\libHarfBuzzSharp.dll" "%TEMP_ZIP_DIR%\" >nul
if exist "%DEST%\libSkiaSharp.dll" copy /Y "%DEST%\libSkiaSharp.dll" "%TEMP_ZIP_DIR%\" >nul
if exist "%DEST%\BeyondAgent.dll" copy /Y "%DEST%\BeyondAgent.dll" "%TEMP_ZIP_DIR%\" >nul
if exist "%DEST%\0Harmony.dll" copy /Y "%DEST%\0Harmony.dll" "%TEMP_ZIP_DIR%\" >nul

powershell -NoProfile -Command "Compress-Archive -Path '%TEMP_ZIP_DIR%' -DestinationPath '%DEST%\%ZIP_NAME%' -Force"

rmdir /S /Q "%TEMP_ZIP_DIR%"

:: Clean up deployed binaries from root folder to leave only the ZIP
if exist "%DEST%\BeyondLauncher.exe" del /F /Q "%DEST%\BeyondLauncher.exe"
if exist "%DEST%\BeyondLauncher.pdb" del /F /Q "%DEST%\BeyondLauncher.pdb"
if exist "%DEST%\av_libglesv2.dll" del /F /Q "%DEST%\av_libglesv2.dll"
if exist "%DEST%\libHarfBuzzSharp.dll" del /F /Q "%DEST%\libHarfBuzzSharp.dll"
if exist "%DEST%\libSkiaSharp.dll" del /F /Q "%DEST%\libSkiaSharp.dll"
if exist "%DEST%\BeyondAgent.dll" del /F /Q "%DEST%\BeyondAgent.dll"
if exist "%DEST%\0Harmony.dll" del /F /Q "%DEST%\0Harmony.dll"

echo.
echo Standalone Launcher and Mod packaged successfully!
echo.
echo ZIP package location: %DEST%\%ZIP_NAME%
echo (Temporary deployment files in root folder have been cleaned up)
echo.
echo Closing in 3 seconds...
timeout /t 3 /nobreak
exit /b 0
