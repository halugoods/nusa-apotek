@echo off
setlocal
set "PROJECT_DIR=C:\Users\ertyui\ZCodeProject\nusa_kasir"
set "PYTHON=%PYTHON%"
if not defined PYTHON set "PYTHON=python"
cd /d "%PROJECT_DIR%" || exit /b 1
"%PYTHON%" "%PROJECT_DIR%\_build_all.py" %*
set "STATUS=%ERRORLEVEL%"
endlocal & exit /b %STATUS%
