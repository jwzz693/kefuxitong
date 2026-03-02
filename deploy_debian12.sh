#!/usr/bin/env bash
# ============================================================================
# 客服系统 - Debian 12 一键全自动部署脚本
# 
# 功能：自动安装 Nginx + PHP 7.4 + MySQL 8.0 + Workerman，
#       部署客服系统代码并配置好 Nginx 反向代理、SSL（可选）、
#       数据库导入、Workerman 守护进程。
#
# 用法：
#   chmod +x deploy_debian12.sh
#   sudo ./deploy_debian12.sh
#
# 也可以直接从 GitHub 一键运行：
#   bash <(curl -sL https://raw.githubusercontent.com/jwzz693/kefuxitong/main/deploy_debian12.sh)
#
# 支持：Debian 12 (Bookworm)
# ============================================================================

set -euo pipefail

# ======================== 颜色输出 ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ======================== 前置检查 ========================
[[ $(id -u) -ne 0 ]] && err "请以 root 用户运行此脚本: sudo $0"
[[ ! -f /etc/debian_version ]] && err "此脚本仅支持 Debian 系统"

DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)
if [[ "$DEBIAN_VERSION" -lt 12 ]]; then
    warn "当前 Debian 版本: $(cat /etc/debian_version)，推荐使用 Debian 12+"
fi

# ======================== 配置参数 ========================
echo ""
echo "============================================"
echo "   客服系统 Debian 12 一键部署"
echo "============================================"
echo ""

# 域名
read -rp "$(echo -e ${CYAN})请输入您的域名 (例: kf.example.com): $(echo -e ${NC})" DOMAIN
[[ -z "$DOMAIN" ]] && err "域名不能为空"

# WebSocket 端口
read -rp "$(echo -e ${CYAN})WebSocket 端口 [默认 7272]: $(echo -e ${NC})" WS_PORT
WS_PORT=${WS_PORT:-7272}

# API 端口
read -rp "$(echo -e ${CYAN})Workerman API 端口 [默认 2080]: $(echo -e ${NC})" API_PORT
API_PORT=${API_PORT:-2080}

# 数据库配置
read -rp "$(echo -e ${CYAN})数据库名称 [默认 kefuxitong]: $(echo -e ${NC})" DB_NAME
DB_NAME=${DB_NAME:-kefuxitong}

read -rp "$(echo -e ${CYAN})数据库用户名 [默认 kefuxitong]: $(echo -e ${NC})" DB_USER
DB_USER=${DB_USER:-kefuxitong}

# 生成随机数据库密码
DEFAULT_DB_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
read -rp "$(echo -e ${CYAN})数据库密码 [默认 随机生成: ${DEFAULT_DB_PASS}]: $(echo -e ${NC})" DB_PASS
DB_PASS=${DB_PASS:-$DEFAULT_DB_PASS}

# 是否启用 SSL
read -rp "$(echo -e ${CYAN})是否配置 Let's Encrypt SSL 证书? (y/n) [默认 n]: $(echo -e ${NC})" ENABLE_SSL
ENABLE_SSL=${ENABLE_SSL:-n}

if [[ "$ENABLE_SSL" == "y" || "$ENABLE_SSL" == "Y" ]]; then
    read -rp "$(echo -e ${CYAN})SSL 证书邮箱: $(echo -e ${NC})" SSL_EMAIL
    [[ -z "$SSL_EMAIL" ]] && err "启用 SSL 时邮箱不能为空"
    PROTOCOL="https"
    WS_PROTOCOL="wss"
else
    PROTOCOL="http"
    WS_PROTOCOL="ws"
fi

# 安装路径
INSTALL_DIR="/www/kefuxitong"

echo ""
info "=============== 部署参数确认 ==============="
info "域名:          $DOMAIN"
info "协议:          $PROTOCOL"
info "WebSocket:     $WS_PROTOCOL://$DOMAIN:$WS_PORT"
info "API 端口:      $API_PORT"
info "数据库:        $DB_NAME / $DB_USER"
info "安装路径:      $INSTALL_DIR"
info "============================================"
echo ""
read -rp "确认以上配置开始部署? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && err "已取消部署"

# ======================== 系统更新 ========================
info "正在更新系统包..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
ok "系统更新完成"

# ======================== 安装基础工具 ========================
info "安装基础工具..."
apt-get install -y -qq \
    curl wget git unzip zip lsof net-tools \
    software-properties-common apt-transport-https \
    ca-certificates gnupg2 cron
ok "基础工具安装完成"

# ======================== 安装 PHP 7.4 ========================
info "安装 PHP 7.4..."

# 添加 sury.org PHP 仓库 (Debian 12 默认没有 PHP 7.4)
if [[ ! -f /etc/apt/sources.list.d/php.list ]]; then
    curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
    dpkg -i /tmp/debsuryorg-archive-keyring.deb
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list
    apt-get update -qq
fi

apt-get install -y -qq \
    php7.4 php7.4-fpm php7.4-cli php7.4-common \
    php7.4-mysql php7.4-curl php7.4-gd php7.4-mbstring \
    php7.4-xml php7.4-zip php7.4-json php7.4-opcache \
    php7.4-bcmath php7.4-intl php7.4-readline \
    php7.4-tokenizer php7.4-fileinfo

# 配置 PHP
PHP_INI="/etc/php/7.4/fpm/php.ini"
PHP_CLI_INI="/etc/php/7.4/cli/php.ini"

for ini in "$PHP_INI" "$PHP_CLI_INI"; do
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 50M/' "$ini"
    sed -i 's/post_max_size = .*/post_max_size = 50M/' "$ini"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$ini"
    sed -i 's/max_input_time = .*/max_input_time = 300/' "$ini"
    sed -i 's/memory_limit = .*/memory_limit = 256M/' "$ini"
    sed -i "s/;date.timezone =.*/date.timezone = Asia\/Shanghai/" "$ini"
    sed -i 's/disable_functions = .*/disable_functions = /' "$ini"
done

# 修改 php-fpm 运行用户
FPM_POOL="/etc/php/7.4/fpm/pool.d/www.conf"
sed -i 's/^user = .*/user = www-data/' "$FPM_POOL"
sed -i 's/^group = .*/group = www-data/' "$FPM_POOL"

systemctl restart php7.4-fpm
systemctl enable php7.4-fpm
ok "PHP 7.4 安装并配置完成"

# ======================== 安装 MySQL 8.0 ========================
info "安装 MySQL..."

# Debian 12 默认 MariaDB，安装 MySQL 8.0
if ! command -v mysql &>/dev/null; then
    # 使用 MariaDB 作为替代（Debian 12 原生支持，性能兼容）
    apt-get install -y -qq mariadb-server mariadb-client
fi

systemctl start mariadb 2>/dev/null || systemctl start mysql 2>/dev/null || true
systemctl enable mariadb 2>/dev/null || systemctl enable mysql 2>/dev/null || true

# 创建数据库和用户
info "配置数据库..."
mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
ok "数据库创建完成: ${DB_NAME}"

# ======================== 安装 Nginx ========================
info "安装 Nginx..."
apt-get install -y -qq nginx
systemctl enable nginx
ok "Nginx 安装完成"

# ======================== 部署项目代码 ========================
info "部署项目代码..."

if [[ -d "$INSTALL_DIR" ]]; then
    warn "安装目录已存在，备份为 ${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$INSTALL_DIR" "${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
fi

git clone https://github.com/jwzz693/kefuxitong.git "$INSTALL_DIR"
ok "代码克隆完成"

# 设置目录权限
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 777 "$INSTALL_DIR/runtime"
chmod -R 777 "$INSTALL_DIR/public/upload" 2>/dev/null || true

# 创建 runtime 子目录
mkdir -p "$INSTALL_DIR/runtime/cache" "$INSTALL_DIR/runtime/log" "$INSTALL_DIR/runtime/temp"
chmod -R 777 "$INSTALL_DIR/runtime"

# ======================== 导入数据库 ========================
info "导入数据库..."
SQL_FILE="$INSTALL_DIR/dkewl.sql"
if [[ -f "$SQL_FILE" ]]; then
    mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < "$SQL_FILE"
    ok "数据库导入完成"
else
    warn "SQL 文件不存在，跳过导入: $SQL_FILE"
fi

# ======================== 配置项目 ========================
info "生成项目配置文件..."

# 生成 Pusher 密钥
APP_KEY=$(openssl rand -hex 8)
APP_SECRET=$(openssl rand -hex 16)
APP_ID=$((RANDOM % 900 + 100))
REGIST_TOKEN=$(openssl rand -hex 5 | tr -dc '0-9' | head -c 9)
AIKF_SALT=$(openssl rand -hex 10)

# 写入 config/database.php
cat > "$INSTALL_DIR/config/database.php" << DBEOF
<?php
return [
    'debug'          => true,
    'fields_strict'  => true,
    'auto_timestamp' => false,
    'sql_explain'    => false,
    'type'           => 'mysql',
    'hostname'       => '127.0.0.1',
    'database'       => '${DB_NAME}',
    'username'       => '${DB_USER}',
    'password'       => '${DB_PASS}',
    'hostport'       => '3306',
    'prefix'         => '',
    'charset'        => 'utf8mb4',
    'params'         => [],
];
DBEOF

# 写入 public/index.php
cat > "$INSTALL_DIR/public/index.php" << 'IDXEOF'
<?php
ini_set('session.gc_maxlifetime', 432000);
ini_set('session.cookie_lifetime', 432000);
ini_set('session.gc_probability',1);
ini_set('session.gc_divisor',1000);

isset($_SESSION) or session_start();

define('APP_PATH', __DIR__ . '/../application/');
define('VENDOR',__DIR__.'/../vendor/');
define('CONF_PATH', __DIR__ . '/../config/');
function p($a){ var_dump($a); die; }

IDXEOF

# 追加动态配置到 public/index.php
cat >> "$INSTALL_DIR/public/index.php" << IDXEOF2
define('app_key','${APP_KEY}');
define('app_secret','${APP_SECRET}');
define('app_id',${APP_ID});
define('whost','${WS_PROTOCOL}://${DOMAIN}');
define('ahost','${PROTOCOL}://${DOMAIN}');
define('wport',${WS_PORT});
define('aport',${API_PORT});
define('registToken','${REGIST_TOKEN}');
define('AIKF_SALT','${AIKF_SALT}');
define('AKF_VERSION','AI_KF');

define('PUBLIC_PATH',__DIR__);
define('EXTEND_PATH','../extend/');

define('appid','');
define('appsecret','');
define('token','');
define('domain','${PROTOCOL}://${DOMAIN}');

require __DIR__ . '/../thinkphp/start.php';
IDXEOF2

# 写入 service/config.php
cat > "$INSTALL_DIR/service/config.php" << SVCEOF
<?php
\$domain = '${PROTOCOL}://${DOMAIN}';
\$app_key = '${APP_KEY}';
\$app_secret = '${APP_SECRET}';
\$app_id = ${APP_ID};
\$websocket_port = ${WS_PORT};
\$api_port = ${API_PORT};
\$auto_upgrade_interval = 3600;
SVCEOF

# 写入 domain.json
cat > "$INSTALL_DIR/domain.json" << DJEOF
{"domain":"${PROTOCOL}://${DOMAIN}"}
DJEOF

ok "项目配置文件生成完成"

# ======================== 配置 Nginx ========================
info "配置 Nginx..."

cat > "/etc/nginx/sites-available/kefuxitong" << NGXEOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${INSTALL_DIR}/public;
    index index.php index.html;

    charset utf-8;
    client_max_body_size 50m;

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
    }

    # Workerman WebSocket 反向代理
    location /wss {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }

    # PHP 处理
    location / {
        if (!-e \$request_filename) {
            rewrite ^(.*)$ /index.php?s=/\$1 last;
            break;
        }
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 7d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/kefuxitong_access.log;
    error_log  /var/log/nginx/kefuxitong_error.log;
}
NGXEOF

# 启用站点
ln -sf /etc/nginx/sites-available/kefuxitong /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# 测试并重载 Nginx
nginx -t && systemctl reload nginx
ok "Nginx 配置完成"

# ======================== SSL 证书（可选）========================
if [[ "$ENABLE_SSL" == "y" || "$ENABLE_SSL" == "Y" ]]; then
    info "安装 Certbot 并申请 SSL 证书..."
    apt-get install -y -qq certbot python3-certbot-nginx
    certbot --nginx -d "$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect
    ok "SSL 证书已配置"

    # 设置自动续期
    systemctl enable certbot.timer
    systemctl start certbot.timer
fi

# ======================== 启动 Workerman ========================
info "启动 Workerman 监听服务..."
cd "$INSTALL_DIR"

# 启动 Workerman（后台守护模式）
nohup php service/start.php start -d > /dev/null 2>&1 &
sleep 3

# 检查是否启动成功
if ps -ef | grep -i workerman | grep -v grep > /dev/null 2>&1; then
    ok "Workerman 监听服务启动成功"
else
    warn "Workerman 可能未正常启动，请手动检查: php ${INSTALL_DIR}/service/start.php start"
fi

# ======================== 配置 Crontab 守护 ========================
info "配置定时任务..."

# Workerman 守护（每分钟检测）
CRON_RUN="* * * * * sh ${INSTALL_DIR}/run.sh >/dev/null 2>&1"
CRON_UPGRADE="0 * * * * sh ${INSTALL_DIR}/auto_upgrade.sh >/dev/null 2>&1"

(crontab -l 2>/dev/null | grep -v "run.sh" | grep -v "auto_upgrade.sh"; echo "$CRON_RUN"; echo "$CRON_UPGRADE") | crontab -
ok "定时任务配置完成"

# ======================== 防火墙配置 ========================
info "配置防火墙..."
if command -v ufw &>/dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow "${WS_PORT}/tcp"
    ufw allow "${API_PORT}/tcp"
    ok "UFW 防火墙规则已添加"
elif command -v iptables &>/dev/null; then
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT
    iptables -I INPUT -p tcp --dport "${WS_PORT}" -j ACCEPT
    iptables -I INPUT -p tcp --dport "${API_PORT}" -j ACCEPT

    # 持久化防火墙规则
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save
    elif command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables.rules
    fi
    ok "iptables 防火墙规则已添加"
fi

# ======================== 设置目录权限（最终）========================
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 777 "$INSTALL_DIR/runtime"

# ======================== 输出部署信息 ========================
echo ""
echo "============================================"
echo -e "${GREEN}   部署完成！${NC}"
echo "============================================"
echo ""
echo -e "  访问地址:     ${CYAN}${PROTOCOL}://${DOMAIN}${NC}"
echo -e "  WebSocket:    ${CYAN}${WS_PROTOCOL}://${DOMAIN}:${WS_PORT}${NC}"
echo -e "  安装路径:     ${INSTALL_DIR}"
echo ""
echo -e "  数据库名:     ${DB_NAME}"
echo -e "  数据库用户:   ${DB_USER}"
echo -e "  数据库密码:   ${YELLOW}${DB_PASS}${NC}"
echo ""
echo -e "  Pusher Key:   ${APP_KEY}"
echo -e "  Pusher Secret:${APP_SECRET}"
echo ""
echo "  ---- 管理命令 ----"
echo "  启动 Workerman:  php ${INSTALL_DIR}/service/start.php start -d"
echo "  停止 Workerman:  php ${INSTALL_DIR}/service/start.php stop"
echo "  重启 Workerman:  php ${INSTALL_DIR}/service/start.php restart -d"
echo "  查看状态:        php ${INSTALL_DIR}/service/start.php status"
echo "  手动升级:        php ${INSTALL_DIR}/auto_upgrade.php upgrade"
echo "  检测新版本:      php ${INSTALL_DIR}/auto_upgrade.php check"
echo ""
echo "============================================"

# 保存部署信息到文件
cat > "$INSTALL_DIR/deploy_info.txt" << INFOEOF
==== 客服系统部署信息 ====
部署时间:     $(date '+%Y-%m-%d %H:%M:%S')
域名:         ${DOMAIN}
协议:         ${PROTOCOL}
WebSocket:    ${WS_PROTOCOL}://${DOMAIN}:${WS_PORT}
API 端口:     ${API_PORT}
安装路径:     ${INSTALL_DIR}
数据库名:     ${DB_NAME}
数据库用户:   ${DB_USER}
数据库密码:   ${DB_PASS}
Pusher Key:   ${APP_KEY}
Pusher Secret:${APP_SECRET}
App ID:       ${APP_ID}
=============================
INFOEOF

chmod 600 "$INSTALL_DIR/deploy_info.txt"
ok "部署信息已保存到 ${INSTALL_DIR}/deploy_info.txt"
echo ""
