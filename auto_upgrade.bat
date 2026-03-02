@echo off
REM ============================================
REM 自动升级+自动重启监听服务 (Windows)
REM 可通过 Windows 计划任务定时执行
REM ============================================

cd /d "%~dp0"

echo ======================================== >> runtime\log\auto_upgrade_cron.log
echo [%date% %time%] 开始自动升级检测... >> runtime\log\auto_upgrade_cron.log

REM 执行自动升级
php auto_upgrade.php upgrade >> runtime\log\auto_upgrade_cron.log 2>&1

REM 检查 Workerman 进程是否在运行
tasklist /FI "IMAGENAME eq php.exe" 2>NUL | find /I "php.exe" >NUL
if errorlevel 1 (
    echo [%date% %time%] 检测到 Workerman 未运行，正在自动启动... >> runtime\log\auto_upgrade_cron.log
    start /B php service\start.php start
    timeout /t 3 /nobreak >NUL
    echo [%date% %time%] Workerman 监听服务已尝试启动 >> runtime\log\auto_upgrade_cron.log
) else (
    echo [%date% %time%] Workerman 监听服务运行中 >> runtime\log\auto_upgrade_cron.log
)

echo ======================================== >> runtime\log\auto_upgrade_cron.log
