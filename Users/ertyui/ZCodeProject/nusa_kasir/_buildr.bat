@echo off
set PATH=C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Program Files\Git\bin;C:\Program Files\Git\cmd;C:\Users\ertyui\flutter\bin;%PATH%
cd /d C:\Users\ertyui\ZCodeProject\nusa_kasir
C:\Users\ertyui\flutter\bin\dart.bat run build_runner build --delete-conflicting-outputs 2>&1
echo BUILD_RUNNER_DONE
