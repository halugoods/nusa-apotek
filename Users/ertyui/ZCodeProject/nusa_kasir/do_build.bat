@echo off
setlocal
set "PROJECT_DIR=C:\Users\ertyui\ZCodeProject\nusa_kasir"
set "FLUTTER=C:\Users\ertyui\flutter\bin\flutter.bat"
set "APK_SRC=%PROJECT_DIR%\build\app\outputs\flutter-apk\app-release.apk"
set "APK_DST=%PROJECT_DIR%\release_apk.apk"
set "LOG=%PROJECT_DIR%\build_apk_log.txt"
set "DONE=%PROJECT_DIR%\build_done.txt"

cd /d "%PROJECT_DIR%" || exit /b 1
del /q "%APK_DST%" "%DONE%" 2>nul
call "%FLUTTER%" clean >> "%LOG%" 2>&1
if errorlevel 1 goto :failed
call "%FLUTTER%" pub get >> "%LOG%" 2>&1
if errorlevel 1 goto :failed
call "%FLUTTER%" build apk --release >> "%LOG%" 2>&1
if errorlevel 1 goto :failed
if not exist "%APK_SRC%" goto :failed
for %%F in ("%APK_SRC%") do if %%~zF LEQ 0 goto :failed
copy /Y "%APK_SRC%" "%APK_DST%" >nul
if errorlevel 1 goto :failed
echo BUILD_DONE> "%DONE%"
endlocal & exit /b 0

:failed
set "STATUS=%ERRORLEVEL%"
if "%STATUS%"=="0" set "STATUS=1"
del /q "%APK_DST%" "%DONE%" 2>nul
endlocal & exit /b %STATUS%
