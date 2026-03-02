#!/usr/bin/env bash
basepath=$(cd `dirname $0`; pwd)
[ $(id -u) != "0" ] && echo "Error: You must be root to run this script" && exit 1

# 注册 Workerman 监听服务守护
result=$(crontab -l|grep -i "* * * * * sh $basepath/run.sh"|grep -v grep)
if [ ! -n "$result" ]
then
crontab -l > conf && echo "* * * * * sh $basepath/run.sh >/dev/null 2>&1" >> conf && crontab conf && rm -f conf
echo -e "\033[32m[OK] Workerman 守护已注册\033[0m"
else
echo "Workerman 守护已存在"
fi

# 注册自动升级检测（每小时检测一次）
result2=$(crontab -l|grep -i "auto_upgrade.sh"|grep -v grep)
if [ ! -n "$result2" ]
then
crontab -l > conf && echo "0 * * * * sh $basepath/auto_upgrade.sh >/dev/null 2>&1" >> conf && crontab conf && rm -f conf
echo -e "\033[32m[OK] 自动升级监听已注册\033[0m"
else
echo "自动升级监听已存在"
fi
