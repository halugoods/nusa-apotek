@echo off
set PATH=C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Program Files\Git\bin;C:\Program Files\Git\cmd;C:\Users\ertyui\flutter\bin;%PATH%
cd /d C:\Users\ertyui\ZCodeProject\nusa_kasir
C:\Users\ertyui\flutter\bin\flutter.bat analyze lib\features\promo\promo_screen.dart lib\features\online_orders\online_orders_screen.dart lib\features\reports\reports_screen.dart lib\features\dashboard\dashboard_screen.dart 2>&1
echo ANALYZE_DONE
