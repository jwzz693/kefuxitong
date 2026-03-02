<?php
namespace app\common\lib\cloud;

/**
 * 自动升级类
 * 负责检测云端新版本、下载更新包、安装升级并重启 Workerman 服务
 */
class AutoUpgrade
{
    /** @var string 项目根目录 */
    protected $basePath;

    /** @var string 升级日志文件路径 */
    protected $logFile;

    /** @var string 临时下载目录 */
    protected $tempDir;

    /** @var string version.json 路径 */
    protected $versionFile;

    /** @var string domain.json 路径 */
    protected $domainFile;

    /** @var int 请求超时秒数 */
    protected $timeout = 30;

    public function __construct()
    {
        $this->basePath    = dirname(dirname(dirname(dirname(__DIR__))));
        $this->logFile     = $this->basePath . DIRECTORY_SEPARATOR . 'runtime' . DIRECTORY_SEPARATOR . 'log' . DIRECTORY_SEPARATOR . 'auto_upgrade.log';
        $this->tempDir     = $this->basePath . DIRECTORY_SEPARATOR . 'runtime' . DIRECTORY_SEPARATOR . 'temp';
        $this->versionFile = $this->basePath . DIRECTORY_SEPARATOR . 'version.json';
        $this->domainFile  = $this->basePath . DIRECTORY_SEPARATOR . 'domain.json';

        if (!is_dir($this->tempDir)) {
            @mkdir($this->tempDir, 0755, true);
        }
    }

    /**
     * 执行完整升级流程: 检测 → 下载 → 安装 → 重启
     *
     * @return array ['success' => bool, 'message' => string, 'restarted' => bool]
     */
    public function run()
    {
        $this->log('开始执行自动升级流程');

        // 1. 检测新版本
        $info = $this->check();
        if (!$info['has_update']) {
            $this->log('当前已是最新版本，无需升级');
            return ['success' => true, 'message' => '当前已是最新版本，无需升级', 'restarted' => false];
        }

        $newVersion = $info['new_version'];
        $this->log("发现新版本: {$newVersion['version']}");

        // 2. 下载更新包
        $zipFile = $this->download($newVersion['src_file']);
        if (!$zipFile) {
            $this->log('下载更新包失败');
            return ['success' => false, 'message' => '下载更新包失败', 'restarted' => false];
        }
        $this->log("更新包已下载: {$zipFile}");

        // 3. 备份当前版本关键配置
        $this->backupConfigs();

        // 4. 安装更新（解压覆盖）
        $installed = $this->install($zipFile);
        if (!$installed) {
            $this->log('安装更新包失败');
            return ['success' => false, 'message' => '安装更新包失败', 'restarted' => false];
        }

        // 5. 还原配置文件
        $this->restoreConfigs();

        // 6. 更新本地版本号
        $this->updateLocalVersion($newVersion['version']);
        $this->log("版本已更新至: {$newVersion['version']}");

        // 7. 重启 Workerman 服务
        $restarted = $this->restartWorkerService();
        if ($restarted) {
            $this->log('Workerman 监听服务重启成功');
        } else {
            $this->log('Workerman 监听服务重启失败，请手动检查');
        }

        // 8. 清理临时文件
        @unlink($zipFile);

        $this->log('自动升级流程完成');
        return [
            'success'   => true,
            'message'   => "已成功升级到版本 {$newVersion['version']}",
            'restarted' => $restarted,
        ];
    }

    /**
     * 检测是否有新版本
     *
     * @return array ['has_update' => bool, 'current_version' => string, 'new_version' => array|null]
     */
    public function check()
    {
        $currentVersion = $this->getCurrentVersion();
        $result = [
            'has_update'      => false,
            'current_version' => $currentVersion,
            'new_version'     => null,
        ];

        $apiUrl = $this->getCloudApiUrl();
        if (!$apiUrl) {
            $this->log('无法获取云端 API 地址，跳过检测');
            return $result;
        }

        $checkUrl = rtrim($apiUrl, '/') . '/api/version/check';
        $postData = [
            'version'  => $currentVersion,
            'domain'   => $this->getDomain(),
            'platform' => PHP_OS,
        ];

        $response = $this->httpPost($checkUrl, $postData);
        if (!$response) {
            $this->log('云端版本检测请求失败');
            return $result;
        }

        $data = json_decode($response, true);
        if (!$data || !isset($data['code'])) {
            $this->log('云端返回数据格式异常');
            return $result;
        }

        if ($data['code'] === 0 && !empty($data['data']['has_update'])) {
            $result['has_update']  = true;
            $result['new_version'] = [
                'version'  => $data['data']['version'] ?? '',
                'src_file' => $data['data']['src_file'] ?? '',
                'desc'     => $data['data']['desc'] ?? '',
                'md5'      => $data['data']['md5'] ?? '',
            ];
        }

        return $result;
    }

    /**
     * 下载更新包
     *
     * @param string $url 下载地址
     * @return string|false 下载后的本地文件路径，失败返回 false
     */
    protected function download($url)
    {
        if (empty($url)) {
            return false;
        }

        $fileName = 'upgrade_' . date('YmdHis') . '.zip';
        $filePath = $this->tempDir . DIRECTORY_SEPARATOR . $fileName;

        $ch = curl_init($url);
        $fp = fopen($filePath, 'wb');
        if (!$fp) {
            return false;
        }

        curl_setopt_array($ch, [
            CURLOPT_FILE            => $fp,
            CURLOPT_FOLLOWLOCATION  => true,
            CURLOPT_TIMEOUT         => 300,
            CURLOPT_SSL_VERIFYPEER  => false,
            CURLOPT_SSL_VERIFYHOST  => false,
        ]);

        $success = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        fclose($fp);

        if (!$success || $httpCode !== 200 || !file_exists($filePath) || filesize($filePath) < 1024) {
            @unlink($filePath);
            return false;
        }

        return $filePath;
    }

    /**
     * 安装更新（解压覆盖到项目根目录）
     *
     * @param string $zipFile ZIP 更新包路径
     * @return bool
     */
    protected function install($zipFile)
    {
        if (!class_exists('ZipArchive')) {
            $this->log('错误: PHP ZipArchive 扩展未安装');
            return false;
        }

        $zip = new \ZipArchive();
        $res = $zip->open($zipFile);
        if ($res !== true) {
            $this->log("打开 ZIP 文件失败，错误码: {$res}");
            return false;
        }

        $extractPath = $this->basePath;
        $ok = $zip->extractTo($extractPath);
        $zip->close();

        if (!$ok) {
            $this->log('解压更新包失败');
            return false;
        }

        return true;
    }

    /**
     * 备份关键配置文件
     */
    protected function backupConfigs()
    {
        $backupDir = $this->tempDir . DIRECTORY_SEPARATOR . 'config_backup';
        if (!is_dir($backupDir)) {
            @mkdir($backupDir, 0755, true);
        }

        $files = [
            'config/database.php',
            'public/index.php',
            'service/config.php',
            'domain.json',
        ];

        foreach ($files as $file) {
            $src = $this->basePath . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $file);
            if (file_exists($src)) {
                $dest = $backupDir . DIRECTORY_SEPARATOR . basename($file);
                @copy($src, $dest);
            }
        }
    }

    /**
     * 还原关键配置文件
     */
    protected function restoreConfigs()
    {
        $backupDir = $this->tempDir . DIRECTORY_SEPARATOR . 'config_backup';
        if (!is_dir($backupDir)) {
            return;
        }

        $mapping = [
            'database.php' => 'config/database.php',
            'index.php'    => 'public/index.php',
            'config.php'   => 'service/config.php',
            'domain.json'  => 'domain.json',
        ];

        foreach ($mapping as $backupName => $targetPath) {
            $src  = $backupDir . DIRECTORY_SEPARATOR . $backupName;
            $dest = $this->basePath . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $targetPath);
            if (file_exists($src)) {
                @copy($src, $dest);
                @unlink($src);
            }
        }

        @rmdir($backupDir);
    }

    /**
     * 更新本地 version.json 版本号
     *
     * @param string $version 新版本号
     */
    protected function updateLocalVersion($version)
    {
        $data = ['version' => $version];
        @file_put_contents($this->versionFile, json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    }

    /**
     * 重启 Workerman 监听服务
     *
     * @return bool
     */
    public function restartWorkerService()
    {
        $isWindows = strtoupper(substr(PHP_OS, 0, 3)) === 'WIN';
        $startScript = $this->basePath . DIRECTORY_SEPARATOR . 'service' . DIRECTORY_SEPARATOR . 'start.php';

        if (!file_exists($startScript)) {
            $this->log('Workerman 启动脚本不存在: ' . $startScript);
            return false;
        }

        if ($isWindows) {
            // Windows: 先终止旧进程，再启动
            @pclose(@popen('taskkill /F /IM php.exe 2>NUL', 'r'));
            sleep(1);
            @pclose(@popen("start /B php \"{$startScript}\" start", 'r'));
        } else {
            // Linux: 平滑重启
            $pidFile = $this->basePath . DIRECTORY_SEPARATOR . 'service' . DIRECTORY_SEPARATOR . 'workerman.pid';
            if (file_exists($pidFile)) {
                $pid = trim(file_get_contents($pidFile));
                if ($pid && posix_kill((int)$pid, 0)) {
                    // 发送 USR1 信号平滑重启
                    exec("php \"{$startScript}\" restart -d 2>&1", $output, $code);
                    return $code === 0;
                }
            }
            // PID 文件不存在或进程已停止，直接启动
            exec("php \"{$startScript}\" start -d 2>&1", $output, $code);
            return $code === 0;
        }

        // Windows 启动后等待并检测
        sleep(2);
        return true;
    }

    /**
     * 获取升级日志
     *
     * @param int $lines 行数
     * @return string
     */
    public function getUpgradeLog($lines = 100)
    {
        if (!file_exists($this->logFile)) {
            return '暂无升级日志';
        }

        $content = file_get_contents($this->logFile);
        $allLines = explode("\n", trim($content));
        $total = count($allLines);

        if ($total <= $lines) {
            return $content;
        }

        return implode("\n", array_slice($allLines, -$lines));
    }

    /**
     * 获取当前版本号
     *
     * @return string
     */
    protected function getCurrentVersion()
    {
        // 优先从 AKF_VERSION 常量获取
        if (defined('AKF_VERSION') && AKF_VERSION !== 'unknown') {
            return AKF_VERSION;
        }

        // 其次从 version.json 读取
        if (file_exists($this->versionFile)) {
            $data = json_decode(file_get_contents($this->versionFile), true);
            if (!empty($data['version'])) {
                return $data['version'];
            }
        }

        return 'unknown';
    }

    /**
     * 获取云端 API 地址
     *
     * @return string|false
     */
    protected function getCloudApiUrl()
    {
        // 从 domain.json 获取
        if (file_exists($this->domainFile)) {
            $data = json_decode(file_get_contents($this->domainFile), true);
            if (!empty($data['domain'])) {
                return rtrim($data['domain'], '/');
            }
        }

        return false;
    }

    /**
     * 获取当前站点域名
     *
     * @return string
     */
    protected function getDomain()
    {
        if (file_exists($this->domainFile)) {
            $data = json_decode(file_get_contents($this->domainFile), true);
            if (!empty($data['domain'])) {
                return $data['domain'];
            }
        }
        return '';
    }

    /**
     * 发送 HTTP POST 请求
     *
     * @param string $url
     * @param array  $data
     * @return string|false
     */
    protected function httpPost($url, $data = [])
    {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => http_build_query($data),
            CURLOPT_TIMEOUT        => $this->timeout,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_SSL_VERIFYHOST => false,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/x-www-form-urlencoded'],
        ]);

        $response = curl_exec($ch);
        $errno = curl_errno($ch);
        curl_close($ch);

        if ($errno) {
            return false;
        }

        return $response;
    }

    /**
     * 写入升级日志
     *
     * @param string $message
     */
    protected function log($message)
    {
        $dir = dirname($this->logFile);
        if (!is_dir($dir)) {
            @mkdir($dir, 0755, true);
        }

        $line = '[' . date('Y-m-d H:i:s') . '] ' . $message . PHP_EOL;
        @file_put_contents($this->logFile, $line, FILE_APPEND | LOCK_EX);
    }
}
