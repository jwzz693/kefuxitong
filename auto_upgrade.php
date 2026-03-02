<?php
/**
 * 自动升级独立入口脚本
 * 可通过 cron 定时任务或 Windows 计划任务调用
 * 
 * 用法:
 *   php auto_upgrade.php           -- 执行自动升级（检测+下载+安装+重启）
 *   php auto_upgrade.php check     -- 仅检测是否有新版本
 *   php auto_upgrade.php restart   -- 仅重启 Workerman 监听服务
 *   php auto_upgrade.php log       -- 查看升级日志
 */

// 设置运行环境
ini_set('display_errors', 'on');
error_reporting(E_ALL);
set_time_limit(600);

// 定义基础路径常量（与 ThinkPHP base.php 兼容，使用 DIRECTORY_SEPARATOR）
define('APP_PATH', __DIR__ . DIRECTORY_SEPARATOR . 'application' . DIRECTORY_SEPARATOR);
define('CONF_PATH', __DIR__ . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR);

// 加载 AKF_VERSION (从 public/index.php 提取)
if (!defined('AKF_VERSION')) {
    $indexFile = __DIR__ . DIRECTORY_SEPARATOR . 'public' . DIRECTORY_SEPARATOR . 'index.php';
    if (file_exists($indexFile)) {
        $content = file_get_contents($indexFile);
        if (preg_match("/define\s*\(\s*'AKF_VERSION'\s*,\s*'([^']+)'\s*\)/", $content, $m)) {
            define('AKF_VERSION', $m[1]);
        } else {
            define('AKF_VERSION', 'unknown');
        }
    } else {
        define('AKF_VERSION', 'unknown');
    }
}

// 加载框架引导（注册自动加载、错误处理等）
require __DIR__ . '/thinkphp/base.php';

// 初始化应用（注册 app 命名空间、加载配置等）
\think\App::initCommon();

use app\common\lib\cloud\AutoUpgrade;

// 解析命令行参数
$action = isset($argv[1]) ? strtolower($argv[1]) : 'upgrade';

echo "======================================" . PHP_EOL;
echo " 自动升级监听系统 v1.0" . PHP_EOL;
echo " 当前时间: " . date('Y-m-d H:i:s') . PHP_EOL;
echo " 当前版本: " . AKF_VERSION . PHP_EOL;
echo "======================================" . PHP_EOL;

$autoUpgrade = new AutoUpgrade();

switch ($action) {
    case 'check':
        echo "[检测模式] 正在检测新版本..." . PHP_EOL;
        $info = $autoUpgrade->check();
        if ($info['has_update']) {
            echo "✓ 发现新版本: {$info['new_version']['version']}" . PHP_EOL;
            echo "  下载地址: {$info['new_version']['src_file']}" . PHP_EOL;
        } else {
            echo "✓ 当前已是最新版本" . PHP_EOL;
        }
        break;

    case 'restart':
        echo "[重启模式] 正在重启 Workerman 监听服务..." . PHP_EOL;
        $ok = $autoUpgrade->restartWorkerService();
        if ($ok) {
            echo "✓ Workerman 监听服务重启成功" . PHP_EOL;
        } else {
            echo "✗ Workerman 监听服务重启失败，请手动检查" . PHP_EOL;
            exit(1);
        }
        break;

    case 'log':
        $lines = isset($argv[2]) ? (int)$argv[2] : 100;
        echo "[日志模式] 最近 {$lines} 行升级日志:" . PHP_EOL;
        echo "--------------------------------------" . PHP_EOL;
        echo $autoUpgrade->getUpgradeLog($lines);
        break;

    case 'upgrade':
    default:
        echo "[升级模式] 开始执行自动升级流程..." . PHP_EOL;
        $result = $autoUpgrade->run();
        echo "--------------------------------------" . PHP_EOL;
        if ($result['success']) {
            echo "✓ " . $result['message'] . PHP_EOL;
            if ($result['restarted']) {
                echo "✓ Workerman 监听服务已自动重启" . PHP_EOL;
            }
        } else {
            echo "→ " . $result['message'] . PHP_EOL;
        }
        break;
}

echo "======================================" . PHP_EOL;
