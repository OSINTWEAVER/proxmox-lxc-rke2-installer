@echo off
setlocal enabledelayedexpansion

REM fetch_kubeconfig.bat - Windows wrapper for fetch_kubeconfig_wsl.sh
REM Usage: fetch_kubeconfig.bat <inventory-file>
REM Example: fetch_kubeconfig.bat inventories\hosts-iris.ini

if "%~1"=="" (
    echo Usage: %~nx0 ^<inventory-file^>
    echo Example: %~nx0 inventories\hosts-iris.ini
    echo.
    echo Available inventories:
    if exist inventories\ (
        dir /b inventories\hosts-*.ini 2>nul
    )
    exit /b 1
)

set "INVENTORY_FILE=%~1"

REM Check if inventory file exists
if not exist "%INVENTORY_FILE%" (
    echo Error: Inventory file not found: %INVENTORY_FILE%
    exit /b 2
)

REM Convert Windows path to WSL path
set "WSL_PATH=%INVENTORY_FILE:\=/%"
set "WSL_PATH=!WSL_PATH::=/mnt/c!"

echo 🚀 Running kubeconfig fetch for: %INVENTORY_FILE%
echo.

REM Run the WSL script
wsl bash -c "cd /mnt/d/dev/proxmox-lxc-rke2-installer && chmod +x ./scripts/fetch_kubeconfig_wsl.sh && ./scripts/fetch_kubeconfig_wsl.sh '%WSL_PATH%'"

set "EXIT_CODE=%ERRORLEVEL%"

echo.
if %EXIT_CODE% equ 0 (
    echo ✅ Kubeconfig fetch completed successfully!
    echo.
    echo 💡 You can now use kubectl from both Windows and WSL:
    echo    Windows: kubectl get nodes
    echo    WSL:     kubectl get nodes
    echo.
    echo 📁 Kubeconfig locations:
    echo    Windows: %USERPROFILE%\.kube\config
    echo    WSL:     ~/.kube/config
) else (
    echo ❌ Kubeconfig fetch failed with exit code: %EXIT_CODE%
)

exit /b %EXIT_CODE%
