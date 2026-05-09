@echo off
setlocal enabledelayedexpansion

REM ==================================
REM CONFIG
REM ==================================

set MODULE_ID=lbm
set BUILD_DIR=build
set STAGING=%BUILD_DIR%\%MODULE_ID%
set ZIP_NAME=%MODULE_ID%.zip

echo ===============================
echo Building Magisk Module: %MODULE_ID%
echo ===============================

REM ==================================
REM CLEAN
REM ==================================

if exist %BUILD_DIR% (
    echo Cleaning previous build...
    rmdir /s /q %BUILD_DIR%
)

mkdir %BUILD_DIR%
mkdir %STAGING%

REM ==================================
REM COPY MODULE FILES
REM ==================================

echo Copying module.prop...
copy module.prop %STAGING%\ >nul

if errorlevel 1 (
    echo ERROR: Failed to copy module.prop
    exit /b 1
)

echo Copying scripts...

copy src\action.sh %STAGING%\ >nul
copy src\service.sh %STAGING%\ >nul
copy src\helpers.sh %STAGING%\ >nul
copy src\env.sh %STAGING%\ >nul

if errorlevel 1 (
    echo ERROR: Failed to copy scripts
    exit /b 1
)

REM ==================================
REM COPY EXTERNAL SKELETON
REM ==================================

echo Copying external skeleton...

xcopy skeleton\external %STAGING%\external /E /I /Y >nul

if errorlevel 1 (
    echo ERROR: Failed to copy external skeleton
    exit /b 1
)

REM ==================================
REM REMOVE VCS PLACEHOLDERS
REM ==================================

echo Removing .gitkeep files...

for /r %STAGING% %%f in (.gitkeep) do (
    del /f /q "%%f"
)

REM ==================================
REM CREATE ZIP
REM ==================================

echo Creating ZIP...

pushd %STAGING%

zip -r ..\%ZIP_NAME% . >nul

if errorlevel 1 (
    echo ERROR: Failed to create ZIP
    popd
    exit /b 1
)

popd

echo ZIP created at: %BUILD_DIR%\%ZIP_NAME%

REM ==================================
REM ADB PUSH
REM ==================================

echo.
echo Pushing to device...

adb get-state >nul 2>&1

if errorlevel 1 (
    echo ERROR: No device connected via adb
    exit /b 1
)

adb push %BUILD_DIR%\%ZIP_NAME% /sdcard/%ZIP_NAME%

if errorlevel 1 (
    echo ERROR: Failed to push module
    exit /b 1
)

echo Module pushed to /sdcard/%ZIP_NAME%

REM ==================================
REM MAGISK INSTALL
REM ==================================

echo.
echo Attempting install via Magisk...

adb shell su -c "magisk --install-module /sdcard/%ZIP_NAME%"

if errorlevel 1 (
    echo Magisk CLI install may not be available.
    echo Please install manually via Magisk app.
    exit /b 1
)

REM Cleanup uploaded ZIP
adb shell rm -f /sdcard/%ZIP_NAME%

echo Module installed successfully.
echo Rebooting device...

adb shell reboot

echo ===============================
echo DONE
echo ===============================

pause