#!/usr/bin/env bash
# ============================================
# 自动升级+自动重启监听服务 (Linux)
# 建议加入 crontab 定时执行，例如每小时检测一次：
#   0 * * * * sh /path/to/auto_upgrade.sh >/dev/null 2>&1
# ============================================

basepath=$(cd `dirname $0`; pwd)
LOGFILE="$basepath/runtime/log/auto_upgrade_cron.log"

echo "========================================" >> "$LOGFILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始自动升级检测..." >> "$LOGFILE"

# 检测 PHP 是否可用
if ! command -v php &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 错误: PHP 未安装或不在 PATH 中" >> "$LOGFILE"
    exit 1
fi

# 检测升级脚本是否存在
if [ ! -f "$basepath/auto_upgrade.php" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 错误: auto_upgrade.php 不存在" >> "$LOGFILE"
    exit 1
fi

# 执行自动升级
php "$basepath/auto_upgrade.php" upgrade >> "$LOGFILE" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 自动升级检测完成" >> "$LOGFILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 自动升级检测异常，退出码: $EXIT_CODE" >> "$LOGFILE"
fi

# 同时确保 Workerman 监听服务在运行中
result=$(ps -ef | grep -i workerman | grep -v grep)
if [ ! -n "$result" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检测到 Workerman 未运行，正在自动启动..." >> "$LOGFILE"
    nohup php "$basepath/service/start.php" start -d > /dev/null 2>&1 &
    sleep 2
    result2=$(ps -ef | grep -i workerman | grep -v grep)
    if [ -n "$result2" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Workerman 监听服务启动成功" >> "$LOGFILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Workerman 监听服务启动失败" >> "$LOGFILE"
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Workerman 监听服务运行正常" >> "$LOGFILE"
fi

echo "========================================" >> "$LOGFILE"
