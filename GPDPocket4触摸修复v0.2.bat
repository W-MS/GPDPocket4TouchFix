@echo off
:: =============================================
:: author: W-MS
:: email: i@pluto.wang
:: description: GPD Pocket4 触摸屏失效修复工具
:: version: 0.2
:: =============================================

setlocal enabledelayedexpansion

:: 全局安全目录设置
set "safeDir=%ProgramData%\GPDTouchFix"
set "psFile=%safeDir%\reloadTouchScreen.ps1"
set "silentPsFile=%safeDir%\reloadTouchScreen_silent.ps1"
set "xmlFile=%safeDir%\TouchScreenAutoFix.xml"

:: 初始化参数
if "%~1"=="/repair" goto repair
if "%~1"=="/add_service" goto add_service
if "%~1"=="/del_service" goto del_service

:: 主菜单界面
:menu
cls
echo =========== GPD Pocket4 触摸失效修复 ============
echo 1. 立即修复触摸屏
echo 2. 添加自动修复服务
echo 3. 删除自动修复服务
echo ===========================================
set /p choice=请选择操作 (1-3)：
if "%choice%"=="1" goto check_admin_repair
if "%choice%"=="2" goto check_admin_add
if "%choice%"=="3" goto check_admin_del
echo 无效输入，请按任意键重新选择...
pause >nul
goto menu

:: 立即修复 - 权限检查
:check_admin_repair
openfiles >nul 2>nul
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c, %0 /repair' -Verb RunAs"
    exit /b
)
goto repair

:: 添加服务 - 权限检查
:check_admin_add
openfiles >nul 2>nul
if %errorlevel% neq 0 (
    echo 当前没有管理员权限，正在尝试提升权限...
    powershell -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','""%~f0""','/add_service' -Verb RunAs"
    exit /b
)
goto add_service

:: 删除服务 - 权限检查
:check_admin_del
openfiles >nul 2>nul
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c, %0 /del_service' -Verb RunAs"
    exit /b
)
goto del_service

:: 立即修复操作
:repair
:: 创建安全目录
if not exist "%safeDir%" (
    mkdir "%safeDir%" >nul 2>&1
    attrib +h "%safeDir%" >nul 2>&1
)

echo 正在生成修复脚本...
if not exist "%psFile%" (
    (
    echo param([switch]^$v^)
    echo function Show-Notification {
    echo     param (
    echo         [string^]^$message,
    echo         [string^]^$title
    echo     ^)
    echo     ^$notification = New-Object -ComObject WScript.Shell
    echo     ^$notification.Popup(^$message, 3, ^$title, 0x0^)
    echo }
    echo ^$hardwareID = 'ACPI\VEN_NVTK^&DEV_0603'
    echo ^$device = Get-WmiObject -Class Win32_PnPEntity ^| Where-Object { ^$_.HardwareID -contains ^$hardwareID }
    echo if (^$device.Status -eq 'Error'^) {
    echo     if (^$v^) { Show-Notification -message '正在重置设备...' -title '设备修复' }
    echo     ^$deviceInstance = Get-WmiObject -Class Win32_PnPEntity ^| Where-Object { ^$_.DeviceID -eq ^$device.DeviceID }
    echo     try {
    echo         ^$deviceInstance.Disable(^)
    echo         Start-Sleep -Seconds 3
    echo         ^$deviceInstance.Enable(^)
    echo         if (^$v^) { Show-Notification -message '修复已完成' -title '设备修复' }
    echo     } catch {
    echo         if (^$v^) { Show-Notification -message "无法重置设备：^$_" -title '设备修复' }
    echo     }
    echo } else {
    echo     if (^$v^) { Show-Notification -message '设备正常' -title '设备状态' }
    echo }
    ) > "%psFile%"
)

powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope Process -Force"
powershell -ExecutionPolicy Bypass -File "%psFile%" -v
del "%psFile%" 2>nul
echo 修复操作已完成，按任意键继续...
pause >nul
goto menu

:: 创建自动服务
:add_service
:: 创建安全目录
if not exist "%safeDir%" (
    mkdir "%safeDir%" >nul 2>&1
    attrib +h "%safeDir%" >nul 2>&1
)

echo 正在创建静默修复脚本...
(
    echo ^$hardwareID = 'ACPI\VEN_NVTK^&DEV_0603'
    echo ^$device = Get-WmiObject -Class Win32_PnPEntity ^| Where-Object { ^$_.HardwareID -contains ^$hardwareID }
    echo if (^$device.Status -eq 'Error'^) {
    echo     ^$deviceInstance = Get-WmiObject -Class Win32_PnPEntity ^| Where-Object { ^$_.DeviceID -eq ^$device.DeviceID }
    echo     try {
    echo         ^$deviceInstance.Disable(^)
    echo         Start-Sleep -Seconds 3
    echo         ^$deviceInstance.Enable(^)
    echo     } catch {}
    echo }
) > "%silentPsFile%"


:: 确保 XML 文件创建成功
if not exist "%silentPsFile%" (
    echo 静默修复脚本创建失败。
    pause
    goto menu
)


:: 修改 XML 格式，确保 XML 签名符合规范
(
echo ^<?xml version="1.0" encoding="UTF-16"?^>
echo ^<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo   ^<Triggers^>
echo     ^<LogonTrigger^><Enabled^>true^</Enabled^></LogonTrigger^>
echo     ^<EventTrigger^>
echo       ^<Enabled^>true^</Enabled^>
echo       ^<Subscription^>^&lt;QueryList^&gt;^&lt;Query Id="0"^&gt;^&lt;Select Path="System"^&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]^&lt;/Select^&gt;^&lt;/Query^&gt;^&lt;/QueryList^&gt;^</Subscription^>
echo     ^</EventTrigger^>
echo   ^</Triggers^>
echo   ^<Principals^>
echo     ^<Principal id="Author"^>
echo       ^<UserId^>S-1-5-18^</UserId^>
echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
echo     ^</Principal^>
echo   ^</Principals^>
echo   ^<Settings^>
echo     ^<Hidden^>true^</Hidden^>
echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo   ^</Settings^>
echo   ^<Actions^>
echo     ^<Exec^>
echo       ^<Command^>powershell.exe^</Command^>
echo       ^<Arguments^>-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File "!silentPsFile!"^</Arguments^>
echo     ^</Exec^>
echo   ^</Actions^>
echo ^</Task^>
) > "!xmlFile!"


schtasks /create /tn "TouchScreenAutoFix" /xml "%xmlFile%" /f
del "%xmlFile%" 2>nul
echo 已创建双触发自动修复任务，按任意键返回...
pause >nul
goto menu


:: 删除自动服务
:del_service
schtasks /delete /tn "TouchScreenAutoFix" /f 2>nul
del "%silentPsFile%" 2>nul
echo 已删除自动修复服务，按任意键继续...
pause >nul
goto menu
