#!/usr/bin/env bash
# ============================================================================
# 客服系统 - Debian 12 一键全自动部署脚本
#
# 全自动：零交互，自动检测IP、生成密码、创建数据库、部署代码并启动服务
#
# 用法（三种方式均可）：
#
#   1) 纯自动（用服务器公网IP）：
#      bash <(curl -sL https://raw.githubusercontent.com/jwzz693/kefuxitong/main/deploy_debian12.sh)
#
#   2) 指定域名：
#      DOMAIN=kf.example.com bash <(curl -sL https://raw.githubusercontent.com/jwzz693/kefuxitong/main/deploy_debian12.sh)
#
#   3) 完整自定义（均可选，未设置的用默认值）：
#      DOMAIN=kf.example.com \
#      WS_PORT=7272 \
#      API_PORT=2080 \
#      DB_NAME=kefuxitong \
#      DB_USER=kefuxitong \
#      DB_PASS=MyPassword123 \
#      ENABLE_SSL=y \
#      SSL_EMAIL=admin@example.com \
#      INSTALL_DIR=/www/kefuxitong \
#      bash <(curl -sL https://raw.githubusercontent.com/jwzz693/kefuxitong/main/deploy_debian12.sh)
#
# 支持：Debian 12 (Bookworm) / Debian 11
# ============================================================================

set -euo pipefail

# ======================== 颜色输出 ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
step()  { echo -e "\n${GREEN}━━━ 步骤 $1/$TOTAL_STEPS: $2 ━━━${NC}"; }

TOTAL_STEPS=12

# ======================== 前置检查 ========================
[[ $(id -u) -ne 0 ]] && err "请以 root 用户运行此脚本: sudo $0"

if [[ -f /etc/debian_version ]]; then
    DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)
    [[ "$DEBIAN_VERSION" -lt 11 ]] && warn "当前 Debian $(cat /etc/debian_version)，推荐 Debian 12+"
elif [[ -f /etc/lsb-release ]] && grep -qi ubuntu /etc/lsb-release; then
    info "检测到 Ubuntu 系统，兼容模式运行"
else
    err "此脚本仅支持 Debian / Ubuntu 系统"
fi

# ======================== 自动检测公网 IP ========================
get_public_ip() {
    local ip=""
    for url in "https://ifconfig.me" "https://api.ipify.org" "https://icanhazip.com" "https://ipecho.net/plain"; do
        ip=$(curl -s --connect-timeout 3 --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return
        fi
    done
    # 回退：取第一个非 lo 接口的 IP
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "${ip:-127.0.0.1}"
}

# ======================== 全自动参数（零交互）========================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   客服系统 Debian 12 全自动部署${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# 自动检测或使用环境变量
DOMAIN="${DOMAIN:-$(get_public_ip)}"
WS_PORT="${WS_PORT:-7272}"
API_PORT="${API_PORT:-2080}"
DB_NAME="${DB_NAME:-kefuxitong}"
DB_USER="${DB_USER:-kefuxitong}"
DB_PASS="${DB_PASS:-$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)}"
DB_ROOT_PASS="${DB_ROOT_PASS:-$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)}"
ENABLE_SSL="${ENABLE_SSL:-n}"
SSL_EMAIL="${SSL_EMAIL:-}"
INSTALL_DIR="${INSTALL_DIR:-/www/kefuxitong}"

if [[ "$ENABLE_SSL" == "y" || "$ENABLE_SSL" == "Y" ]]; then
    PROTOCOL="https"
    WS_PROTOCOL="wss"
    [[ -z "$SSL_EMAIL" ]] && SSL_EMAIL="admin@${DOMAIN}"
else
    PROTOCOL="http"
    WS_PROTOCOL="ws"
fi

# 自动生成 Pusher 密钥
APP_KEY=$(openssl rand -hex 8)
APP_SECRET=$(openssl rand -hex 16)
APP_ID=$((RANDOM % 900 + 100))
REGIST_TOKEN=$(head -c 32 /dev/urandom | od -An -tu4 | tr -dc '0-9' | head -c 9)
REGIST_TOKEN=${REGIST_TOKEN:-123456789}
AIKF_SALT=$(openssl rand -hex 10)

info "部署参数（全自动生成）:"
info "  域名/IP:       $DOMAIN"
info "  协议:          $PROTOCOL"
info "  WebSocket:     $WS_PROTOCOL://\$DOMAIN:$WS_PORT"
info "  API 端口:      $API_PORT"
info "  数据库:        $DB_NAME (用户: $DB_USER)"
info "  安装路径:      $INSTALL_DIR"
echo ""

# ======================== 步骤 1: 系统更新 ========================
step 1 "更新系统软件包"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>&1 | tail -1
apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 2>&1 | tail -1
ok "系统更新完成"

# ======================== 步骤 2: 安装基础工具 ========================
step 2 "安装基础工具"
apt-get install -y -qq \
    curl wget git unzip zip lsof net-tools \
    software-properties-common apt-transport-https \
    ca-certificates gnupg2 cron procps 2>&1 | tail -1
ok "基础工具安装完成"

# ======================== 步骤 3: 安装 PHP 7.4 ========================
step 3 "安装 PHP 7.4 + 扩展"

# 添加 sury.org PHP 仓库 (Debian 12 默认没有 PHP 7.4)
if ! dpkg -l php7.4-fpm 2>/dev/null | grep -q '^ii'; then
    if [[ ! -f /etc/apt/sources.list.d/php.list ]]; then
        info "添加 PHP sury.org 仓库..."
        curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb 2>/dev/null
        dpkg -i /tmp/debsuryorg-archive-keyring.deb >/dev/null 2>&1
        echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list
        apt-get update -qq 2>&1 | tail -1
    fi
fi

apt-get install -y -qq \
    php7.4 php7.4-fpm php7.4-cli php7.4-common \
    php7.4-mysql php7.4-curl php7.4-gd php7.4-mbstring \
    php7.4-xml php7.4-zip php7.4-json php7.4-opcache \
    php7.4-bcmath php7.4-intl php7.4-readline \
    php7.4-tokenizer php7.4-fileinfo 2>&1 | tail -1

# 配置 PHP（FPM + CLI）
for ini in /etc/php/7.4/fpm/php.ini /etc/php/7.4/cli/php.ini; do
    [[ ! -f "$ini" ]] && continue
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 50M/' "$ini"
    sed -i 's/post_max_size = .*/post_max_size = 50M/' "$ini"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$ini"
    sed -i 's/max_input_time = .*/max_input_time = 300/' "$ini"
    sed -i 's/memory_limit = .*/memory_limit = 256M/' "$ini"
    sed -i "s|;date.timezone =.*|date.timezone = Asia/Shanghai|" "$ini"
    sed -i 's/disable_functions = .*/disable_functions = /' "$ini"
done

# php-fpm 用户
FPM_POOL="/etc/php/7.4/fpm/pool.d/www.conf"
if [[ -f "$FPM_POOL" ]]; then
    sed -i 's/^user = .*/user = www-data/' "$FPM_POOL"
    sed -i 's/^group = .*/group = www-data/' "$FPM_POOL"
fi

systemctl restart php7.4-fpm
systemctl enable php7.4-fpm 2>/dev/null
ok "PHP 7.4 安装并配置完成 ($(php -v 2>/dev/null | head -1 | awk '{print $2}'))"

# ======================== 步骤 4: 安装 MariaDB ========================
step 4 "安装并配置数据库"

DB_INSTALLED=false
DB_SERVICE=""

# 检测已有的数据库
if command -v mysql &>/dev/null; then
    info "检测到已安装 MySQL/MariaDB"
    DB_INSTALLED=true
elif command -v mariadb &>/dev/null; then
    info "检测到已安装 MariaDB"
    DB_INSTALLED=true
fi

# 未安装则自动安装
if [[ "$DB_INSTALLED" == "false" ]]; then
    info "未检测到数据库，正在自动安装 MariaDB..."
    apt-get install -y -qq mariadb-server mariadb-client 2>&1 | tail -1
    ok "MariaDB 安装完成"
fi

# 识别数据库服务名
if systemctl list-unit-files mariadb.service &>/dev/null 2>&1; then
    DB_SERVICE="mariadb"
elif systemctl list-unit-files mysql.service &>/dev/null 2>&1; then
    DB_SERVICE="mysql"
elif systemctl list-unit-files mysqld.service &>/dev/null 2>&1; then
    DB_SERVICE="mysqld"
fi

# 确保数据库服务已启动
if [[ -n "$DB_SERVICE" ]]; then
    systemctl start "$DB_SERVICE" 2>/dev/null || true
    systemctl enable "$DB_SERVICE" 2>/dev/null || true
else
    # 尝试全部启动
    systemctl start mariadb 2>/dev/null || systemctl start mysql 2>/dev/null || systemctl start mysqld 2>/dev/null || true
fi

# 等待数据库就绪（最多30秒）
info "等待数据库服务就绪..."
DB_READY=false
for i in {1..30}; do
    if mysqladmin ping &>/dev/null 2>&1; then
        DB_READY=true
        break
    fi
    sleep 1
done

if [[ "$DB_READY" != "true" ]]; then
    # 数据库完全无法启动，尝试重装
    warn "数据库服务无法启动，尝试重新安装..."
    apt-get remove -y --purge mariadb-server mariadb-client 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    rm -rf /var/lib/mysql 2>/dev/null || true
    apt-get install -y -qq mariadb-server mariadb-client 2>&1 | tail -1
    systemctl start mariadb
    systemctl enable mariadb 2>/dev/null || true
    sleep 3
    mysqladmin ping &>/dev/null || err "数据库多次安装失败，请手动检查系统环境"
    ok "数据库重装成功"
fi

# ---- 尝试确定 root 连接方式 ----
# MariaDB/MySQL 在 Debian 上 root 默认用 unix_socket 或空密码
MYSQL_ROOT_CMD=""

# 尝试1: 无密码直连 (unix_socket 认证)
if mysql -uroot -e "SELECT 1;" &>/dev/null 2>&1; then
    MYSQL_ROOT_CMD="mysql -uroot"
    info "数据库 root 使用 unix_socket 认证"
# 尝试2: 空密码
elif mysql -uroot -p'' -e "SELECT 1;" &>/dev/null 2>&1; then
    MYSQL_ROOT_CMD="mysql -uroot -p''"
    info "数据库 root 使用空密码"
# 尝试3: 环境变量中指定的密码
elif [[ -n "${DB_ROOT_PASS:-}" ]] && mysql -uroot -p"${DB_ROOT_PASS}" -e "SELECT 1;" &>/dev/null 2>&1; then
    MYSQL_ROOT_CMD="mysql -uroot -p${DB_ROOT_PASS}"
    info "数据库 root 使用已有密码"
else
    # 最后手段：尝试跳过权限修复
    warn "无法连接数据库 root，尝试重置..."
    systemctl stop mariadb 2>/dev/null || systemctl stop mysql 2>/dev/null || true
    # 用 --skip-grant-tables 启动
    mysqld_safe --skip-grant-tables --skip-networking &>/dev/null &
    sleep 3
    if mysql -uroot -e "SELECT 1;" &>/dev/null 2>&1; then
        mysql -uroot -e "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';" 2>/dev/null || \
        mysql -uroot -e "FLUSH PRIVILEGES; SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${DB_ROOT_PASS}');" 2>/dev/null || true
        # 杀掉 skip-grant 进程并正常重启
        killall mysqld 2>/dev/null || true
        sleep 2
        systemctl start mariadb 2>/dev/null || systemctl start mysql 2>/dev/null || true
        sleep 2
        MYSQL_ROOT_CMD="mysql -uroot -p${DB_ROOT_PASS}"
    else
        err "无法连接数据库 root 用户，请手动修复后重试"
    fi
fi

# ---- 安全初始化 ----
info "安全初始化数据库..."

# 设置 root 密码（如果当前是无密码/socket方式，可选设密码）
if [[ "$MYSQL_ROOT_CMD" == "mysql -uroot" ]] || [[ "$MYSQL_ROOT_CMD" == "mysql -uroot -p''" ]]; then
    # 为 root 设置密码
    $MYSQL_ROOT_CMD -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';" 2>/dev/null || \
    $MYSQL_ROOT_CMD -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${DB_ROOT_PASS}');" 2>/dev/null || true
    # 更新连接命令
    if mysql -uroot -p"${DB_ROOT_PASS}" -e "SELECT 1;" &>/dev/null 2>&1; then
        MYSQL_ROOT_CMD="mysql -uroot -p${DB_ROOT_PASS}"
    fi
    # 如果设密码后反而连不上了（某些版本 socket 认证优先），回退
    if ! $MYSQL_ROOT_CMD -e "SELECT 1;" &>/dev/null 2>&1; then
        if mysql -uroot -e "SELECT 1;" &>/dev/null 2>&1; then
            MYSQL_ROOT_CMD="mysql -uroot"
        fi
    fi
fi

# 清理匿名用户和测试库
$MYSQL_ROOT_CMD -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
$MYSQL_ROOT_CMD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
$MYSQL_ROOT_CMD -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
$MYSQL_ROOT_CMD -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
$MYSQL_ROOT_CMD -e "FLUSH PRIVILEGES;" 2>/dev/null || true

# ---- 创建项目数据库和用户 ----
info "创建数据库: ${DB_NAME}  用户: ${DB_USER}..."
$MYSQL_ROOT_CMD -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" || err "创建数据库失败"
$MYSQL_ROOT_CMD -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null || true
$MYSQL_ROOT_CMD -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" || err "创建数据库用户失败"
$MYSQL_ROOT_CMD -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
$MYSQL_ROOT_CMD -e "FLUSH PRIVILEGES;"

# 验证项目账号连接
if mysql -u"${DB_USER}" -p"${DB_PASS}" -e "SELECT 1;" "${DB_NAME}" &>/dev/null 2>&1; then
    ok "数据库创建并验证成功: ${DB_NAME} (用户: ${DB_USER})"
else
    warn "数据库用户验证失败，尝试用 root 继续（后续导入将使用 root）"
fi

# ======================== 步骤 5: 安装 Nginx ========================
step 5 "安装 Nginx"
if ! command -v nginx &>/dev/null; then
    apt-get install -y -qq nginx 2>&1 | tail -1
fi
systemctl enable nginx 2>/dev/null
ok "Nginx 安装完成"

# ======================== 步骤 6: 部署项目代码 ========================
step 6 "从 GitHub 克隆部署代码"

if [[ -d "$INSTALL_DIR" ]]; then
    BACKUP_DIR="${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    warn "安装目录已存在，备份为 $BACKUP_DIR"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
fi

git clone --depth 1 https://github.com/jwzz693/kefuxitong.git "$INSTALL_DIR" 2>&1 | tail -2
ok "代码克隆完成"

# 创建必要目录
mkdir -p "$INSTALL_DIR/runtime/cache" \
         "$INSTALL_DIR/runtime/log" \
         "$INSTALL_DIR/runtime/temp" \
         "$INSTALL_DIR/public/upload"

# ======================== 步骤 7: 导入数据库 ========================
step 7 "导入数据库结构和数据"

SQL_FILE="$INSTALL_DIR/dkewl.sql"
if [[ -f "$SQL_FILE" ]]; then
    info "正在导入 $(du -h "$SQL_FILE" | awk '{print $1}') SQL 数据..."
    # 优先用项目用户导入，失败则用 root
    if mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < "$SQL_FILE" 2>&1; then
        :
    else
        warn "项目用户导入失败，使用 root 重试..."
        $MYSQL_ROOT_CMD "${DB_NAME}" < "$SQL_FILE" 2>&1 || warn "SQL 导入出现警告（可能部分已存在）"
    fi
    TABLE_COUNT=$(mysql -u"${DB_USER}" -p"${DB_PASS}" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" 2>/dev/null || \
                  $MYSQL_ROOT_CMD -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" 2>/dev/null || echo "0")
    ok "数据库导入完成，共 ${TABLE_COUNT:-0} 张表"
else
    warn "SQL 文件不存在，跳过导入"
fi

# ======================== 步骤 8: 生成配置文件 ========================
step 8 "自动生成项目配置文件"

# config/database.php
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
info "  → config/database.php"

# public/index.php
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
info "  → public/index.php"

# service/config.php
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
info "  → service/config.php"

# domain.json
cat > "$INSTALL_DIR/domain.json" << DJEOF
{"domain":"${PROTOCOL}://${DOMAIN}"}
DJEOF
info "  → domain.json"

ok "全部配置文件已自动生成"

# ======================== 步骤 9: 配置 Nginx ========================
step 9 "配置 Nginx 反向代理"

cat > "/etc/nginx/sites-available/kefuxitong" << NGXEOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${INSTALL_DIR}/public;
    index index.php index.html;

    charset utf-8;
    client_max_body_size 50m;

    location ~ /\. {
        deny all;
    }

    # WebSocket 反向代理
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

    # ThinkPHP URL 重写
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

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 7d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/kefuxitong_access.log;
    error_log  /var/log/nginx/kefuxitong_error.log;
}
NGXEOF

ln -sf /etc/nginx/sites-available/kefuxitong /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

nginx -t 2>&1 && systemctl reload nginx
ok "Nginx 配置完成"

# ======================== 步骤 10: SSL 证书（可选）========================
step 10 "SSL 证书配置"

if [[ "$ENABLE_SSL" == "y" || "$ENABLE_SSL" == "Y" ]]; then
    info "安装 Certbot 并自动申请 SSL..."
    apt-get install -y -qq certbot python3-certbot-nginx 2>&1 | tail -1
    certbot --nginx -d "$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect 2>&1 | tail -3
    systemctl enable certbot.timer 2>/dev/null
    systemctl start certbot.timer 2>/dev/null
    ok "SSL 证书已配置并启用自动续期"
else
    ok "跳过（未启用 SSL，可后续用 ENABLE_SSL=y 重新部署）"
fi

# ======================== 步骤 11: 启动 Workerman ========================
step 11 "启动 Workerman 服务 + 配置守护"

cd "$INSTALL_DIR"

# 先停止可能残留的旧进程
php service/start.php stop 2>/dev/null || true
sleep 1

# 启动 Workerman（守护模式）
php service/start.php start -d 2>&1 || true
sleep 3

# 验证 Workerman 是否启动
if ps -ef | grep -i "workerman\|Pusher\|start\.php" | grep -v grep > /dev/null 2>&1; then
    ok "Workerman 监听服务启动成功"
else
    warn "Workerman 可能未正常启动，部署完成后请手动运行:"
    warn "  cd ${INSTALL_DIR} && php service/start.php start -d"
fi

# 配置 crontab 守护
CRON_RUN="* * * * * sh ${INSTALL_DIR}/run.sh >/dev/null 2>&1"
CRON_UPGRADE="0 * * * * sh ${INSTALL_DIR}/auto_upgrade.sh >/dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "run.sh" | grep -v "auto_upgrade.sh"; echo "$CRON_RUN"; echo "$CRON_UPGRADE") | crontab -
ok "Crontab 守护已配置（每分钟检测 Workerman + 每小时自动升级）"

# ======================== 步骤 12: 防火墙 + 权限 ========================
step 12 "防火墙与最终权限"

# 防火墙
if command -v ufw &>/dev/null; then
    ufw --force enable 2>/dev/null || true
    ufw allow 22/tcp 2>/dev/null
    ufw allow 80/tcp 2>/dev/null
    ufw allow 443/tcp 2>/dev/null
    ufw allow "${WS_PORT}/tcp" 2>/dev/null
    ufw allow "${API_PORT}/tcp" 2>/dev/null
    ok "UFW 防火墙规则已添加"
elif command -v iptables &>/dev/null; then
    for port in 80 443 "${WS_PORT}" "${API_PORT}"; do
        iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
    done
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save 2>/dev/null
    elif command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables.rules 2>/dev/null
    fi
    ok "iptables 防火墙规则已添加"
else
    ok "未检测到防火墙工具，跳过"
fi

# 最终权限
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 777 "$INSTALL_DIR/runtime"
chmod -R 777 "$INSTALL_DIR/public/upload" 2>/dev/null || true
ok "目录权限设置完成"

# ======================== 保存部署信息 ========================
DEPLOY_INFO="$INSTALL_DIR/deploy_info.txt"
cat > "$DEPLOY_INFO" << INFOEOF
===================================================
  客服系统部署信息（请妥善保管）
===================================================
部署时间:      $(date '+%Y-%m-%d %H:%M:%S')
系统版本:      $(cat /etc/debian_version 2>/dev/null || echo "unknown")
─────────────────────────────────────────
访问地址:      ${PROTOCOL}://${DOMAIN}
WebSocket:     ${WS_PROTOCOL}://${DOMAIN}:${WS_PORT}
API 端口:      ${API_PORT}
安装路径:      ${INSTALL_DIR}
─────────────────────────────────────────
数据库名:      ${DB_NAME}
数据库用户:    ${DB_USER}
数据库密码:    ${DB_PASS}
数据库Root密码:${DB_ROOT_PASS}
─────────────────────────────────────────
Pusher Key:    ${APP_KEY}
Pusher Secret: ${APP_SECRET}
App ID:        ${APP_ID}
Regist Token:  ${REGIST_TOKEN}
AIKF Salt:     ${AIKF_SALT}
===================================================
INFOEOF
chmod 600 "$DEPLOY_INFO"

# ======================== 部署完成 ========================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✓  全自动部署完成！                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  访问地址:      ${CYAN}${PROTOCOL}://${DOMAIN}${NC}"
echo -e "  WebSocket:     ${CYAN}${WS_PROTOCOL}://${DOMAIN}:${WS_PORT}${NC}"
echo -e "  安装路径:      ${INSTALL_DIR}"
echo ""
echo -e "  数据库名:      ${DB_NAME}"
echo -e "  数据库用户:    ${DB_USER}"
echo -e "  数据库密码:    ${YELLOW}${DB_PASS}${NC}"
echo -e "  Root密码:      ${YELLOW}${DB_ROOT_PASS}${NC}"
echo ""
echo -e "  Pusher Key:    ${APP_KEY}"
echo -e "  Pusher Secret: ${APP_SECRET}"
echo ""
echo "  ---- 管理命令 ----"
echo "  启动 Workerman:  php ${INSTALL_DIR}/service/start.php start -d"
echo "  停止 Workerman:  php ${INSTALL_DIR}/service/start.php stop"
echo "  重启 Workerman:  php ${INSTALL_DIR}/service/start.php restart -d"
echo "  查看状态:        php ${INSTALL_DIR}/service/start.php status"
echo "  手动升级:        php ${INSTALL_DIR}/auto_upgrade.php upgrade"
echo "  检测新版本:      php ${INSTALL_DIR}/auto_upgrade.php check"
echo ""
echo -e "  部署信息已保存: ${CYAN}${DEPLOY_INFO}${NC}"
echo -e "  ${YELLOW}请务必保存以上密码信息！${NC}"
echo ""
