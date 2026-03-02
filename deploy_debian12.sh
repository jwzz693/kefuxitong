#!/usr/bin/env bash
# ============================================================================
# 客服系统 - Debian 12 智能部署脚本 v2.0
#
# 功能特性：
#   - 多种运行模式：install(安装)/update(更新)/repair(修复)/status(状态)/uninstall(卸载)
#   - 智能检测现有部署，自动选择安装或更新
#   - 自动检测并选择可用端口
#   - 断点续传：失败可从上次进度继续
#   - 智能更新：保留数据库和配置
#   - 部署后健康检查
#   - 自动回滚支持
#
# 用法：
#   bash deploy.sh [MODE] [OPTIONS]
#
# 模式：
#   --install, -i      全新安装（默认，如检测到已安装则提示更新）
#   --update,  -u      智能更新（仅更新代码，保留数据库和配置）
#   --repair,  -r      修复模式（修复服务、权限、配置）
#   --status,  -s      查看当前部署状态
#   --uninstall        完全卸载
#   --resume           从上次断点继续
#   --force            强制全新安装（不检测）
#
# 环境变量（均可选，未设置用默认值）：
#   DOMAIN=kf.example.com    域名或IP
#   WS_PORT=7272             WebSocket端口
#   API_PORT=2080            API端口
#   DB_NAME=kefuxitong       数据库名
#   DB_USER=kefuxitong       数据库用户
#   DB_PASS=MyPassword       数据库密码（自动生成）
#   ENABLE_SSL=y             启用SSL
#   INSTALL_DIR=/www/kefuxitong  安装路径
#
# ============================================================================

set -u

# ======================== 全局常量 ========================
VERSION="2.0.0"
SCRIPT_NAME="客服系统智能部署脚本"
PROGRESS_FILE="/tmp/.kefuxitong_deploy_progress"
ROLLBACK_DIR="/tmp/.kefuxitong_rollback"
DEPLOY_LOG="${DEPLOY_LOG:-/tmp/kefuxitong_deploy_$(date +%Y%m%d_%H%M%S).log}"

mkdir -p "$(dirname "$DEPLOY_LOG")" >/dev/null 2>&1 || true
mkdir -p "$ROLLBACK_DIR" >/dev/null 2>&1 || true
touch "$DEPLOY_LOG" >/dev/null 2>&1 || true
exec > >(tee -a "$DEPLOY_LOG") 2>&1

# ======================== 颜色输出 ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()     { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
debug()   { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${MAGENTA}[DEBUG]${NC} $*"; }
step()    { echo -e "\n${GREEN}━━━ 步骤 $1/${TOTAL_STEPS}: $2 ━━━${NC}"; }
header()  { echo -e "\n${BLUE}${BOLD}▶ $*${NC}"; }

TOTAL_STEPS=12

# ======================== 运行模式 ========================
MODE="auto"
FORCE_INSTALL=false
START_STEP=1

# ======================== 解析命令行参数 ========================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install|-i)   MODE="install"; shift ;;
            --update|-u)    MODE="update"; shift ;;
            --repair|-r)    MODE="repair"; shift ;;
            --status|-s)    MODE="status"; shift ;;
            --uninstall)    MODE="uninstall"; shift ;;
            --resume)       MODE="resume"; shift ;;
            --force|-f)     FORCE_INSTALL=true; shift ;;
            --debug)        DEBUG=1; shift ;;
            --help|-h)      show_help; exit 0 ;;
            --version|-v)   echo "${SCRIPT_NAME} v${VERSION}"; exit 0 ;;
            *)              warn "未知参数: $1"; shift ;;
        esac
    done
}

show_help() {
    cat << 'HELPEOF'
客服系统智能部署脚本 v2.0

用法: bash deploy.sh [MODE] [OPTIONS]

运行模式:
  --install,  -i     全新安装（默认）
  --update,   -u     智能更新（仅更新代码，保留数据库）
  --repair,   -r     修复模式（修复服务与权限）
  --status,   -s     查看当前部署状态
  --uninstall        完全卸载
  --resume           从上次断点继续
  --force,    -f     强制全新安装（跳过检测）

选项:
  --debug            显示调试信息
  --help,     -h     显示帮助
  --version,  -v     显示版本

环境变量:
  DOMAIN             域名或IP（自动检测公网IP）
  WS_PORT            WebSocket端口（默认7272）
  API_PORT           API端口（默认2080）
  DB_NAME            数据库名（默认kefuxitong）
  DB_USER            数据库用户（默认kefuxitong）
  DB_PASS            数据库密码（自动生成）
  ENABLE_SSL         启用SSL（y/n，默认n）
  INSTALL_DIR        安装路径（默认/www/kefuxitong）

示例:
  # 全自动安装
  bash deploy.sh

  # 指定域名安装
  DOMAIN=kf.example.com bash deploy.sh

  # 智能更新（保留数据）
  bash deploy.sh --update

  # 强制全新安装
  bash deploy.sh --force

  # 从断点继续
  bash deploy.sh --resume
HELPEOF
}

# ======================== 工具函数 ========================
retry_cmd() {
    local max_attempts="${1:-3}"
    local sleep_seconds="${2:-2}"
    shift 2
    local attempt=1
    until "$@"; do
        if [[ "$attempt" -ge "$max_attempts" ]]; then
            return 1
        fi
        warn "命令失败，${sleep_seconds}s 后重试 (${attempt}/${max_attempts}): $*"
        sleep "$sleep_seconds"
        attempt=$((attempt + 1))
    done
    return 0
}

wait_for_apt_lock() {
    local timeout=120 waited=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        if [[ "$waited" -ge "$timeout" ]]; then
            warn "apt 锁等待超时"
            return 0
        fi
        info "等待 apt 锁释放..."
        sleep 3
        waited=$((waited + 3))
    done
    return 0
}

# 检测可用端口
detect_available_port() {
    local start_port="${1:-7272}"
    local port=$start_port
    local max_port=$((start_port + 100))
    
    while [[ $port -lt $max_port ]]; do
        if ! ss -tuln 2>/dev/null | grep -q ":${port} " && \
           ! lsof -i ":${port}" >/dev/null 2>&1; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
    done
    echo "$start_port"
}

is_port_in_use() {
    local port="$1"
    if ss -tuln 2>/dev/null | grep -q ":${port} "; then
        return 0
    fi
    if lsof -i ":${port}" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# ======================== 进度管理（断点续传）========================
save_progress() {
    local step="$1"
    echo "$step" > "$PROGRESS_FILE"
    debug "进度保存: 步骤 $step"
}

load_progress() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        cat "$PROGRESS_FILE"
    else
        echo "0"
    fi
}

clear_progress() {
    rm -f "$PROGRESS_FILE" 2>/dev/null || true
}

# ======================== 回滚支持 ========================
backup_for_rollback() {
    local target="$1"
    local backup_name="$2"
    if [[ -e "$target" ]]; then
        cp -a "$target" "${ROLLBACK_DIR}/${backup_name}" 2>/dev/null || true
        debug "已备份: $target -> ${ROLLBACK_DIR}/${backup_name}"
    fi
}

rollback_file() {
    local backup_name="$1"
    local target="$2"
    if [[ -f "${ROLLBACK_DIR}/${backup_name}" ]]; then
        cp -a "${ROLLBACK_DIR}/${backup_name}" "$target" 2>/dev/null || true
        info "已回滚: $target"
    fi
}

clear_rollback() {
    rm -rf "$ROLLBACK_DIR"/* 2>/dev/null || true
}

# ======================== 随机字符串生成 ========================
rand_alnum() {
    local len="${1:-16}"
    local raw
    raw=$(openssl rand -base64 48 2>/dev/null) || raw=$(head -c 48 /dev/urandom | base64 2>/dev/null) || raw="fallback$(date +%s%N)"
    echo "$raw" | tr -dc 'a-zA-Z0-9' | head -c "$len"
}

rand_hex() {
    local len="${1:-16}"
    openssl rand -hex "$len" 2>/dev/null || head -c "$len" /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c "$((len * 2))"
}

rand_digits() {
    local len="${1:-9}"
    local raw
    raw=$(od -An -tu4 -N16 /dev/urandom 2>/dev/null | tr -dc '0-9')
    while [[ ${#raw} -lt $len ]]; do
        raw="${raw}$(od -An -tu4 -N8 /dev/urandom 2>/dev/null | tr -dc '0-9')"
    done
    echo "${raw:0:$len}"
}

# ======================== IP 检测 ========================
get_public_ip() {
    local ip=""
    for url in "https://ifconfig.me" "https://api.ipify.org" "https://icanhazip.com" "https://ipecho.net/plain"; do
        ip=$(curl -s --connect-timeout 3 --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return
        fi
    done
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "${ip:-127.0.0.1}"
}

# ======================== MySQL Socket 检测 ========================
detect_mysql_socket() {
    local s
    for s in \
        /run/mysqld/mysqld.sock \
        /var/run/mysqld/mysqld.sock \
        /tmp/mysql.sock \
        /tmp/mysqld.sock \
        /www/server/mysql/mysql.sock \
        /www/server/mysql/mysqld.sock; do
        if [[ -S "$s" ]]; then
            echo "$s"
            return 0
        fi
    done
    return 1
}

mysqladmin_ping() {
    local sock
    sock=$(detect_mysql_socket 2>/dev/null || true)
    if [[ -n "$sock" ]]; then
        mysqladmin --protocol=socket -S "$sock" ping >/dev/null 2>&1
    else
        mysqladmin ping >/dev/null 2>&1
    fi
}

# ======================== MySQL 命令封装 ========================
MYSQL_AUTH_MODE="socket"
MYSQL_ROOT_ACTUAL_PASS=""

mysql_root_exec() {
    local sock
    sock=$(detect_mysql_socket 2>/dev/null || true)

    if [[ "$MYSQL_AUTH_MODE" == "socket" ]]; then
        if [[ -n "$sock" ]]; then
            mysql --protocol=socket -S "$sock" -uroot "$@"
        else
            mysql -h 127.0.0.1 -uroot "$@"
        fi
    elif [[ "$MYSQL_AUTH_MODE" == "password" ]]; then
        if [[ -n "$sock" ]]; then
            mysql --protocol=socket -S "$sock" -uroot -p"${MYSQL_ROOT_ACTUAL_PASS}" "$@"
        else
            mysql -h 127.0.0.1 -uroot -p"${MYSQL_ROOT_ACTUAL_PASS}" "$@"
        fi
    else
        if [[ -n "$sock" ]]; then
            mysql --protocol=socket -S "$sock" -uroot "$@"
        else
            mysql -h 127.0.0.1 -uroot "$@"
        fi
    fi
}

mysql_app_exec() {
    local sock
    sock=$(detect_mysql_socket 2>/dev/null || true)
    if [[ -n "$sock" ]]; then
        mysql --protocol=socket -S "$sock" -u"${DB_USER}" -p"${DB_PASS}" "$@"
    else
        mysql -h 127.0.0.1 -u"${DB_USER}" -p"${DB_PASS}" "$@"
    fi
}

# ======================== MariaDB 配置自愈 ========================
sanitize_mariadb_config() {
    local changed=0
    local cfg
    for cfg in \
        /etc/my.cnf \
        /etc/mysql/my.cnf \
        /etc/mysql/mariadb.conf.d/*.cnf \
        /etc/mysql/conf.d/*.cnf \
        /www/server/mysql/my.cnf \
        /www/server/mysql/*.cnf; do
        [[ -f "$cfg" ]] || continue

        if grep -qiE '^\s*early-plugin-load\s*=' "$cfg" 2>/dev/null; then
            cp -a "$cfg" "${cfg}.bak.$(date +%s)" 2>/dev/null || true
            sed -i -E '/^\s*early-plugin-load\s*=.*/Id' "$cfg"
            changed=1
        fi
    done

    local unknown_vars raw_var
    unknown_vars=$(journalctl -u mariadb.service -n 120 --no-pager 2>/dev/null | sed -n "s/.*unknown variable '\([^']*\)'.*/\1/p" | sort -u)
    if [[ -n "$unknown_vars" ]]; then
        for raw_var in $unknown_vars; do
            local opt_name
            opt_name="${raw_var%%=*}"
            [[ -z "$opt_name" ]] && continue
            for cfg in \
                /etc/my.cnf \
                /etc/mysql/my.cnf \
                /etc/mysql/mariadb.conf.d/*.cnf \
                /etc/mysql/conf.d/*.cnf \
                /www/server/mysql/my.cnf \
                /www/server/mysql/*.cnf; do
                [[ -f "$cfg" ]] || continue
                if grep -qiE "^\s*${opt_name}\s*=" "$cfg" 2>/dev/null; then
                    cp -a "$cfg" "${cfg}.bak.$(date +%s)" 2>/dev/null || true
                    sed -i -E "/^\s*${opt_name}\s*=.*/Id" "$cfg"
                    changed=1
                fi
            done
        done
    fi

    if [[ "$changed" -eq 1 ]]; then
        warn "已自动清理 MariaDB 非法参数"
    fi
}

# ======================== 环境预检 ========================
print_preflight() {
    local mem_mb disk_gb cpu_arch kernel cpu_cores
    mem_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo "0")
    disk_gb=$(df -BG / 2>/dev/null | awk 'NR==2{gsub("G","",$4); print $4+0}' || echo "0")
    cpu_arch=$(uname -m 2>/dev/null || echo "unknown")
    kernel=$(uname -r 2>/dev/null || echo "unknown")
    cpu_cores=$(nproc 2>/dev/null || echo "1")

    header "环境预检"
    echo -e "  CPU架构:         ${cpu_arch} (${cpu_cores} 核)"
    echo -e "  内核版本:        ${kernel}"
    echo -e "  内存:            ${mem_mb} MB"
    echo -e "  根分区剩余:      ${disk_gb} GB"
    echo -e "  当前时间:        $(date '+%Y-%m-%d %H:%M:%S')"
    
    local issues=0
    if [[ "$mem_mb" -lt 512 ]]; then
        warn "  ⚠ 内存不足 512MB，可能影响稳定性"
        issues=$((issues + 1))
    fi
    if [[ "$disk_gb" -lt 3 ]]; then
        err "  ✗ 磁盘空间不足 3GB"
    fi
    
    if [[ $issues -eq 0 ]]; then
        ok "  ✓ 环境检查通过"
    fi
    echo ""
}

# ======================== 智能检测现有部署 ========================
detect_existing_deployment() {
    header "检测现有部署"
    
    local found_install=false
    local found_db=false
    local found_nginx=false
    local found_workerman=false
    
    # 检测安装目录
    if [[ -d "${INSTALL_DIR:-/www/kefuxitong}" ]]; then
        if [[ -f "${INSTALL_DIR:-/www/kefuxitong}/public/index.php" ]]; then
            found_install=true
            echo -e "  ${GREEN}✓${NC} 检测到代码目录: ${INSTALL_DIR:-/www/kefuxitong}"
        fi
    fi
    
    # 检测数据库
    if mysqladmin_ping 2>/dev/null; then
        local db_exists
        db_exists=$(mysql_root_exec -N -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME:-kefuxitong}';" 2>/dev/null || true)
        if [[ -n "$db_exists" ]]; then
            found_db=true
            local table_count
            table_count=$(mysql_root_exec -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME:-kefuxitong}';" 2>/dev/null || echo "0")
            echo -e "  ${GREEN}✓${NC} 检测到数据库: ${DB_NAME:-kefuxitong} (${table_count} 张表)"
        fi
    fi
    
    # 检测 Nginx 配置
    if [[ -f "/etc/nginx/sites-available/kefuxitong" ]] || [[ -f "/etc/nginx/sites-enabled/kefuxitong" ]]; then
        found_nginx=true
        echo -e "  ${GREEN}✓${NC} 检测到 Nginx 配置"
    fi
    
    # 检测 Workerman
    if ps -ef | grep -E "workerman|Pusher|start\.php" | grep -v grep >/dev/null 2>&1; then
        found_workerman=true
        echo -e "  ${GREEN}✓${NC} 检测到 Workerman 运行中"
    fi
    
    # 综合判断
    if [[ "$found_install" == "true" ]] || [[ "$found_db" == "true" ]]; then
        EXISTING_DEPLOYMENT=true
        echo ""
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            warn "已检测到部署，--force 模式将覆盖安装"
            return 1
        else
            info "已检测到现有部署"
            if [[ "$MODE" == "auto" ]]; then
                info "自动切换为更新模式（保留数据库）"
                MODE="update"
            fi
            return 0
        fi
    else
        echo -e "  ${YELLOW}○${NC} 未检测到现有部署"
        EXISTING_DEPLOYMENT=false
        if [[ "$MODE" == "auto" ]]; then
            MODE="install"
        fi
        return 1
    fi
}

# ======================== 状态报告 ========================
show_status() {
    echo ""
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}             客服系统部署状态报告${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    local install_dir="${INSTALL_DIR:-/www/kefuxitong}"
    
    # 代码状态
    header "代码部署"
    if [[ -d "$install_dir" ]] && [[ -f "$install_dir/public/index.php" ]]; then
        echo -e "  状态:     ${GREEN}已部署${NC}"
        echo -e "  路径:     $install_dir"
        if [[ -d "$install_dir/.git" ]]; then
            local git_branch git_commit
            git_branch=$(cd "$install_dir" && git branch --show-current 2>/dev/null || echo "unknown")
            git_commit=$(cd "$install_dir" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            echo -e "  Git分支:  $git_branch"
            echo -e "  Git提交:  $git_commit"
        fi
    else
        echo -e "  状态:     ${RED}未部署${NC}"
    fi
    
    # 数据库状态
    header "数据库"
    if mysqladmin_ping 2>/dev/null; then
        echo -e "  MariaDB:  ${GREEN}运行中${NC}"
        local db_name="${DB_NAME:-kefuxitong}"
        local db_exists
        db_exists=$(mysql_root_exec -N -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${db_name}';" 2>/dev/null || true)
        if [[ -n "$db_exists" ]]; then
            local table_count
            table_count=$(mysql_root_exec -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db_name}';" 2>/dev/null || echo "?")
            echo -e "  数据库:   ${GREEN}${db_name}${NC} (${table_count} 张表)"
        else
            echo -e "  数据库:   ${YELLOW}未创建${NC}"
        fi
    else
        echo -e "  MariaDB:  ${RED}未运行${NC}"
    fi
    
    # PHP 状态
    header "PHP"
    if systemctl is-active php7.4-fpm >/dev/null 2>&1; then
        local php_ver
        php_ver=$(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
        echo -e "  PHP-FPM:  ${GREEN}运行中${NC} (${php_ver})"
    else
        echo -e "  PHP-FPM:  ${RED}未运行${NC}"
    fi
    
    # Nginx 状态
    header "Nginx"
    if systemctl is-active nginx >/dev/null 2>&1; then
        echo -e "  Nginx:    ${GREEN}运行中${NC}"
        if [[ -f "/etc/nginx/sites-enabled/kefuxitong" ]]; then
            echo -e "  站点配置: ${GREEN}已启用${NC}"
        else
            echo -e "  站点配置: ${YELLOW}未配置${NC}"
        fi
    else
        echo -e "  Nginx:    ${RED}未运行${NC}"
    fi
    
    # Workerman 状态
    header "Workerman"
    if ps -ef | grep -E "workerman|Pusher|start\.php" | grep -v grep >/dev/null 2>&1; then
        local ws_pid
        ws_pid=$(ps -ef | grep -E "start\.php.*master" | grep -v grep | awk '{print $2}' | head -1)
        echo -e "  状态:     ${GREEN}运行中${NC} (PID: ${ws_pid:-?})"
    else
        echo -e "  状态:     ${RED}未运行${NC}"
    fi
    
    # 端口状态
    header "端口监听"
    local ws_port="${WS_PORT:-7272}"
    local api_port="${API_PORT:-2080}"
    for port in 80 443 "$ws_port" "$api_port"; do
        if ss -tuln 2>/dev/null | grep -q ":${port} "; then
            echo -e "  端口 ${port}:  ${GREEN}监听中${NC}"
        else
            echo -e "  端口 ${port}:  ${YELLOW}未监听${NC}"
        fi
    done
    
    # 部署信息文件
    if [[ -f "$install_dir/deploy_info.txt" ]]; then
        header "部署信息"
        grep -E "^访问地址:|^WebSocket:|^数据库名:" "$install_dir/deploy_info.txt" 2>/dev/null | head -5 || true
    fi
    
    echo ""
}

# ======================== 健康检查 ========================
health_check() {
    header "部署健康检查"
    local passed=0
    local total=5
    
    # 1. HTTP 检查
    echo -n "  HTTP 访问检查:       "
    local http_response
    http_response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://127.0.0.1/" 2>/dev/null || echo "000")
    if [[ "$http_response" =~ ^(200|301|302|304)$ ]]; then
        echo -e "${GREEN}✓ 通过${NC} (HTTP $http_response)"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ 失败${NC} (HTTP $http_response)"
    fi
    
    # 2. PHP-FPM 检查
    echo -n "  PHP-FPM 服务:        "
    if systemctl is-active php7.4-fpm >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 运行中${NC}"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ 未运行${NC}"
    fi
    
    # 3. 数据库连接检查
    echo -n "  数据库连接:          "
    if mysql_app_exec -e "SELECT 1;" "${DB_NAME}" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 连接成功${NC}"
        passed=$((passed + 1))
    elif mysql_root_exec -e "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Root可连接${NC}"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ 连接失败${NC}"
    fi
    
    # 4. Nginx 检查
    echo -n "  Nginx 服务:          "
    if systemctl is-active nginx >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 运行中${NC}"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ 未运行${NC}"
    fi
    
    # 5. Workerman 检查
    echo -n "  Workerman 服务:      "
    if ps -ef | grep -E "workerman|Pusher|start\.php" | grep -v grep >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 运行中${NC}"
        passed=$((passed + 1))
    else
        echo -e "${YELLOW}⚠ 未运行${NC}"
    fi
    
    echo ""
    if [[ $passed -eq $total ]]; then
        echo -e "  ${GREEN}${BOLD}健康状态: 全部通过 ($passed/$total)${NC}"
    elif [[ $passed -ge 3 ]]; then
        echo -e "  ${YELLOW}${BOLD}健康状态: 基本正常 ($passed/$total)${NC}"
    else
        echo -e "  ${RED}${BOLD}健康状态: 需要修复 ($passed/$total)${NC}"
    fi
    echo ""
}

# ======================== 修复模式 ========================
repair_services() {
    header "修复服务"
    
    local install_dir="${INSTALL_DIR:-/www/kefuxitong}"
    
    # 修复 PHP-FPM
    info "检查 PHP-FPM..."
    if ! systemctl is-active php7.4-fpm >/dev/null 2>&1; then
        systemctl restart php7.4-fpm 2>/dev/null && ok "PHP-FPM 已重启" || warn "PHP-FPM 重启失败"
    else
        ok "PHP-FPM 正常"
    fi
    
    # 修复 MariaDB
    info "检查数据库..."
    if ! mysqladmin_ping 2>/dev/null; then
        sanitize_mariadb_config
        systemctl restart mariadb 2>/dev/null || systemctl restart mysql 2>/dev/null
        sleep 2
        if mysqladmin_ping 2>/dev/null; then
            ok "数据库已重启"
        else
            warn "数据库修复失败"
        fi
    else
        ok "数据库正常"
    fi
    
    # 修复 Nginx
    info "检查 Nginx..."
    if nginx -t 2>&1 | grep -q "successful"; then
        if ! systemctl is-active nginx >/dev/null 2>&1; then
            systemctl restart nginx && ok "Nginx 已重启" || warn "Nginx 重启失败"
        else
            ok "Nginx 正常"
        fi
    else
        warn "Nginx 配置有误"
    fi
    
    # 修复 Workerman
    info "检查 Workerman..."
    if ! ps -ef | grep -E "workerman|Pusher|start\.php" | grep -v grep >/dev/null 2>&1; then
        if [[ -f "$install_dir/service/start.php" ]]; then
            cd "$install_dir"
            php service/start.php start -d 2>&1 >/dev/null
            sleep 2
            if ps -ef | grep -E "workerman|Pusher|start\.php" | grep -v grep >/dev/null 2>&1; then
                ok "Workerman 已启动"
            else
                warn "Workerman 启动失败"
            fi
        fi
    else
        ok "Workerman 正常"
    fi
    
    # 修复权限
    info "修复目录权限..."
    if [[ -d "$install_dir" ]]; then
        chown -R www-data:www-data "$install_dir" 2>/dev/null || true
        chmod -R 755 "$install_dir" 2>/dev/null || true
        chmod -R 777 "$install_dir/runtime" 2>/dev/null || true
        chmod -R 777 "$install_dir/public/upload" 2>/dev/null || true
        ok "权限已修复"
    fi
    
    echo ""
    health_check
}

# ======================== 卸载功能 ========================
uninstall() {
    header "卸载客服系统"
    
    local install_dir="${INSTALL_DIR:-/www/kefuxitong}"
    
    echo -e "${YELLOW}警告: 此操作将删除所有数据${NC}"
    echo ""
    
    # 停止 Workerman
    if [[ -f "$install_dir/service/start.php" ]]; then
        info "停止 Workerman..."
        cd "$install_dir" 2>/dev/null && php service/start.php stop 2>/dev/null || true
    fi
    
    # 删除 Nginx 配置
    info "清理 Nginx 配置..."
    rm -f /etc/nginx/sites-enabled/kefuxitong 2>/dev/null || true
    rm -f /etc/nginx/sites-available/kefuxitong 2>/dev/null || true
    systemctl reload nginx 2>/dev/null || true
    
    # 删除数据库
    info "删除数据库..."
    mysql_root_exec -e "DROP DATABASE IF EXISTS \`${DB_NAME:-kefuxitong}\`;" 2>/dev/null || true
    mysql_root_exec -e "DROP USER IF EXISTS '${DB_USER:-kefuxitong}'@'localhost';" 2>/dev/null || true
    
    # 删除代码目录
    info "删除代码目录..."
    if [[ -d "$install_dir" ]]; then
        rm -rf "$install_dir"
    fi
    
    # 清理 crontab
    info "清理定时任务..."
    (crontab -l 2>/dev/null | grep -v "run\.sh" | grep -v "auto_upgrade\.sh" || true) | crontab -
    
    clear_progress
    clear_rollback
    
    ok "卸载完成"
    echo ""
}

# ======================== 前置检查 ========================
if [[ $(id -u) -ne 0 ]]; then
    err "请以 root 用户运行: sudo bash $0"
fi

if [[ -f /etc/debian_version ]]; then
    DEBIAN_VERSION=$(cut -d. -f1 < /etc/debian_version 2>/dev/null || echo "0")
    if [[ "$DEBIAN_VERSION" -lt 11 ]]; then
        warn "当前 Debian $(cat /etc/debian_version)，推荐 Debian 12+"
    fi
elif [[ -f /etc/lsb-release ]] && grep -qi ubuntu /etc/lsb-release 2>/dev/null; then
    info "检测到 Ubuntu 系统"
else
    err "仅支持 Debian / Ubuntu 系统"
fi

# ======================== 解析参数 ========================
parse_args "$@"

# ======================== 默认参数 ========================
DOMAIN="${DOMAIN:-$(get_public_ip)}"
WS_PORT="${WS_PORT:-7272}"
API_PORT="${API_PORT:-2080}"
DB_NAME="${DB_NAME:-kefuxitong}"
DB_USER="${DB_USER:-kefuxitong}"
DB_PASS="${DB_PASS:-$(rand_alnum 16)}"
DB_ROOT_PASS="${DB_ROOT_PASS:-$(rand_alnum 20)}"
ENABLE_SSL="${ENABLE_SSL:-n}"
SSL_EMAIL="${SSL_EMAIL:-}"
INSTALL_DIR="${INSTALL_DIR:-/www/kefuxitong}"
EXISTING_DEPLOYMENT=false

if [[ "$ENABLE_SSL" == "y" || "$ENABLE_SSL" == "Y" ]]; then
    PROTOCOL="https"
    WS_PROTOCOL="wss"
    [[ -z "$SSL_EMAIL" ]] && SSL_EMAIL="admin@${DOMAIN}"
else
    PROTOCOL="http"
    WS_PROTOCOL="ws"
fi

# ======================== 显示启动信息 ========================
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}      ${SCRIPT_NAME} v${VERSION}${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
info "部署日志: ${DEPLOY_LOG}"
echo ""

# ======================== 处理不同模式 ========================
case "$MODE" in
    status)
        show_status
        exit 0
        ;;
    repair)
        repair_services
        exit 0
        ;;
    uninstall)
        uninstall
        exit 0
        ;;
    resume)
        START_STEP=$(load_progress)
        if [[ "$START_STEP" -gt 0 ]]; then
            info "从步骤 ${START_STEP} 继续部署"
        else
            warn "未找到部署进度，从头开始"
            START_STEP=1
        fi
        ;;
esac

# ======================== 环境预检 ========================
print_preflight
wait_for_apt_lock

# ======================== 智能检测 ========================
if [[ "$MODE" == "auto" ]] || [[ "$MODE" == "update" ]]; then
    detect_existing_deployment
fi

# ======================== 智能端口选择 ========================
header "端口检测"
if is_port_in_use "$WS_PORT"; then
    NEW_WS_PORT=$(detect_available_port "$WS_PORT")
    if [[ "$NEW_WS_PORT" != "$WS_PORT" ]]; then
        warn "WebSocket 端口 ${WS_PORT} 已占用，自动选择: ${NEW_WS_PORT}"
        WS_PORT="$NEW_WS_PORT"
    fi
else
    echo -e "  WebSocket 端口 ${WS_PORT}: ${GREEN}可用${NC}"
fi

if is_port_in_use "$API_PORT"; then
    NEW_API_PORT=$(detect_available_port "$API_PORT")
    if [[ "$NEW_API_PORT" != "$API_PORT" ]]; then
        warn "API 端口 ${API_PORT} 已占用，自动选择: ${NEW_API_PORT}"
        API_PORT="$NEW_API_PORT"
    fi
else
    echo -e "  API 端口 ${API_PORT}:       ${GREEN}可用${NC}"
fi
echo ""

# ======================== 生成密钥 ========================
APP_KEY=$(rand_hex 8)
APP_SECRET=$(rand_hex 16)
APP_ID=$((RANDOM % 900 + 100))
REGIST_TOKEN=$(rand_digits 9)
AIKF_SALT=$(rand_hex 10)

# ======================== 显示部署参数 ========================
header "部署参数"
echo -e "  运行模式:      ${BOLD}${MODE}${NC}"
echo -e "  域名/IP:       ${DOMAIN}"
echo -e "  WebSocket:     ${WS_PROTOCOL}://${DOMAIN}:${WS_PORT}"
echo -e "  API 端口:      ${API_PORT}"
echo -e "  数据库:        ${DB_NAME} (用户: ${DB_USER})"
echo -e "  安装路径:      ${INSTALL_DIR}"
if [[ "$MODE" == "update" ]]; then
    echo -e "  ${YELLOW}注意: 更新模式将保留数据库，仅更新代码${NC}"
fi
echo ""

# ======================== 开始部署 ========================
export DEBIAN_FRONTEND=noninteractive

# 步骤 1: 系统更新
if [[ $START_STEP -le 1 ]]; then
    step 1 "更新系统软件包"
    save_progress 1
    retry_cmd 3 3 apt-get update -qq >/dev/null 2>&1 || warn "apt-get update 有警告"
    retry_cmd 2 3 apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >/dev/null 2>&1 || true
    ok "系统更新完成"
fi

# 步骤 2: 安装基础工具
if [[ $START_STEP -le 2 ]]; then
    step 2 "安装基础工具"
    save_progress 2
    retry_cmd 3 3 apt-get install -y -qq \
        curl wget git unzip zip lsof net-tools \
        software-properties-common apt-transport-https \
        ca-certificates gnupg2 cron procps openssl >/dev/null 2>&1 || err "基础工具安装失败"
    ok "基础工具安装完成"
fi

# 步骤 3: 安装 PHP 7.4
if [[ $START_STEP -le 3 ]]; then
    step 3 "安装 PHP 7.4 + 扩展"
    save_progress 3
    
    if ! dpkg -l php7.4-fpm 2>/dev/null | grep -q '^ii'; then
        if [[ ! -f /etc/apt/sources.list.d/php.list ]]; then
            info "添加 PHP sury.org 仓库..."
            if curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb 2>/dev/null; then
                dpkg -i /tmp/debsuryorg-archive-keyring.deb >/dev/null 2>&1
                echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list
                apt-get update -qq >/dev/null 2>&1
            else
                err "无法下载 PHP 仓库密钥"
            fi
        fi
    fi
    
    apt-get install -y -qq \
        php7.4 php7.4-fpm php7.4-cli php7.4-common \
        php7.4-mysql php7.4-curl php7.4-gd php7.4-mbstring \
        php7.4-xml php7.4-zip php7.4-json php7.4-opcache \
        php7.4-bcmath php7.4-intl php7.4-readline \
        php7.4-tokenizer php7.4-fileinfo >/dev/null 2>&1 || err "PHP 7.4 安装失败"
    
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
    
    FPM_POOL="/etc/php/7.4/fpm/pool.d/www.conf"
    if [[ -f "$FPM_POOL" ]]; then
        sed -i 's/^user = .*/user = www-data/' "$FPM_POOL"
        sed -i 's/^group = .*/group = www-data/' "$FPM_POOL"
    fi
    
    systemctl restart php7.4-fpm || err "php7.4-fpm 启动失败"
    systemctl enable php7.4-fpm >/dev/null 2>&1
    PHP_VER=$(php -v 2>/dev/null | head -1 | awk '{print $2}') || PHP_VER="7.4.x"
    ok "PHP 7.4 安装完成 (${PHP_VER})"
fi

# 步骤 4: 安装 MariaDB
if [[ $START_STEP -le 4 ]]; then
    step 4 "安装并配置数据库"
    save_progress 4
    
    DB_NEED_INSTALL=false
    if command -v mysql &>/dev/null || command -v mariadb &>/dev/null; then
        if dpkg -l mariadb-server 2>/dev/null | grep -q '^ii' || dpkg -l mysql-server 2>/dev/null | grep -q '^ii'; then
            info "检测到已安装数据库"
        else
            DB_NEED_INSTALL=true
        fi
    else
        DB_NEED_INSTALL=true
    fi
    
    if [[ "$DB_NEED_INSTALL" == "true" ]]; then
        retry_cmd 3 3 apt-get install -y -qq mariadb-server mariadb-client >/dev/null 2>&1 || err "MariaDB 安装失败"
        ok "MariaDB 安装完成"
    fi
    
    DB_SERVICE=""
    for svc in mariadb mysql mysqld; do
        if systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "${svc}.service"; then
            DB_SERVICE="$svc"
            break
        fi
    done
    
    sanitize_mariadb_config
    
    if [[ -n "$DB_SERVICE" ]]; then
        systemctl start "$DB_SERVICE" 2>/dev/null || true
        systemctl enable "$DB_SERVICE" >/dev/null 2>&1 || true
    else
        systemctl start mariadb 2>/dev/null || systemctl start mysql 2>/dev/null || true
    fi
    
    info "等待数据库就绪..."
    DB_READY=false
    for _i in $(seq 1 30); do
        if mysqladmin_ping; then
            DB_READY=true
            break
        fi
        sleep 1
    done
    
    if [[ "$DB_READY" != "true" ]]; then
        warn "数据库启动失败，执行自愈..."
        
        systemctl stop mariadb mysql mysqld 2>/dev/null || true
        killall -9 mysqld mariadbd mysqld_safe 2>/dev/null || true
        sleep 1
        
        apt-get remove -y --purge mariadb-server mariadb-client mariadb-common mysql-server mysql-client galera-4 >/dev/null 2>&1 || true
        apt-get autoremove -y --purge >/dev/null 2>&1 || true
        
        rm -rf /var/lib/mysql /var/lib/mysql-* /etc/mysql /var/log/mysql /run/mysqld /var/run/mysqld 2>/dev/null || true
        rm -f /tmp/mysql.sock /tmp/mysqld.sock 2>/dev/null || true
        
        if ! id mysql >/dev/null 2>&1; then
            useradd -r -M -s /usr/sbin/nologin -d /nonexistent mysql 2>/dev/null || true
        fi
        mkdir -p /run/mysqld /var/lib/mysql
        chown -R mysql:mysql /run/mysqld /var/lib/mysql 2>/dev/null || true
        
        apt-get update -qq >/dev/null 2>&1 || true
        retry_cmd 3 3 apt-get install -y -qq mariadb-server mariadb-client >/dev/null 2>&1 || err "MariaDB 重装失败"
        dpkg --configure -a >/dev/null 2>&1 || true
        sanitize_mariadb_config
        
        if ! systemctl start mariadb 2>/dev/null; then
            mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || \
            mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || true
            chown -R mysql:mysql /var/lib/mysql /run/mysqld 2>/dev/null || true
            
            if ! systemctl start mariadb 2>/dev/null; then
                nohup mysqld_safe --user=mysql --datadir=/var/lib/mysql >/var/log/mysql_fallback.log 2>&1 &
                sleep 5
                mysqladmin_ping || err "MariaDB 启动失败"
            fi
        fi
        systemctl enable mariadb >/dev/null 2>&1 || true
        sleep 3
    fi
    
    MYSQL_AUTH_MODE=""
    MYSQL_ROOT_ACTUAL_PASS=""
    
    if mysql -uroot -e "SELECT 1;" >/dev/null 2>&1; then
        MYSQL_AUTH_MODE="socket"
    elif mysql -uroot -p'' -e "SELECT 1;" >/dev/null 2>&1; then
        MYSQL_AUTH_MODE="socket"
    elif mysql -uroot -p"${DB_ROOT_PASS}" -e "SELECT 1;" >/dev/null 2>&1; then
        MYSQL_AUTH_MODE="password"
        MYSQL_ROOT_ACTUAL_PASS="${DB_ROOT_PASS}"
    else
        warn "尝试重置数据库 root 密码..."
        if [[ -n "$DB_SERVICE" ]]; then
            systemctl stop "$DB_SERVICE" 2>/dev/null || true
        else
            systemctl stop mariadb mysql 2>/dev/null || true
        fi
        sleep 1
        mysqld_safe --skip-grant-tables --skip-networking >/dev/null 2>&1 &
        SAFE_PID=$!
        sleep 4
        if mysql -uroot -e "SELECT 1;" >/dev/null 2>&1; then
            mysql -uroot -e "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';" 2>/dev/null || \
            mysql -uroot -e "FLUSH PRIVILEGES; SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${DB_ROOT_PASS}');" 2>/dev/null || true
        fi
        kill "$SAFE_PID" 2>/dev/null || true
        killall -9 mysqld mariadbd 2>/dev/null || true
        sleep 2
        if [[ -n "$DB_SERVICE" ]]; then
            systemctl start "$DB_SERVICE" || err "数据库重启失败"
        else
            systemctl start mariadb 2>/dev/null || systemctl start mysql 2>/dev/null || err "数据库重启失败"
        fi
        sleep 2
        if mysql -uroot -p"${DB_ROOT_PASS}" -e "SELECT 1;" >/dev/null 2>&1; then
            MYSQL_AUTH_MODE="password"
            MYSQL_ROOT_ACTUAL_PASS="${DB_ROOT_PASS}"
        else
            err "无法连接数据库"
        fi
    fi
    
    mysql_root_exec -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    mysql_root_exec -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
    mysql_root_exec -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    mysql_root_exec -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    if [[ "$MODE" != "update" ]] || ! mysql_root_exec -N -e "SELECT 1 FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}';" 2>/dev/null | grep -q 1; then
        info "创建数据库: ${DB_NAME}..."
        mysql_root_exec -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" || err "创建数据库失败"
        mysql_root_exec -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null || true
        mysql_root_exec -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" || err "创建用户失败"
        mysql_root_exec -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" || err "授权失败"
        mysql_root_exec -e "FLUSH PRIVILEGES;"
        ok "数据库创建成功"
    else
        if [[ -f "${INSTALL_DIR}/config/database.php" ]]; then
            EXISTING_DB_PASS=$(grep -oP "(?<='password'\s*=>\s*')[^']+" "${INSTALL_DIR}/config/database.php" 2>/dev/null || true)
            if [[ -n "$EXISTING_DB_PASS" ]]; then
                DB_PASS="$EXISTING_DB_PASS"
                info "使用现有数据库密码"
            fi
        fi
        info "更新模式: 保留现有数据库"
    fi
fi

# 步骤 5: 安装 Nginx
if [[ $START_STEP -le 5 ]]; then
    step 5 "安装 Nginx"
    save_progress 5
    
    if ! command -v nginx &>/dev/null; then
        apt-get install -y -qq nginx >/dev/null 2>&1 || err "Nginx 安装失败"
    fi
    systemctl enable nginx >/dev/null 2>&1
    ok "Nginx 安装完成"
fi

# 步骤 6: 部署代码
if [[ $START_STEP -le 6 ]]; then
    step 6 "部署项目代码"
    save_progress 6
    
    if [[ "$MODE" == "update" ]] && [[ -d "$INSTALL_DIR/.git" ]]; then
        info "更新模式: 执行 git pull..."
        cd "$INSTALL_DIR"
        
        backup_for_rollback "$INSTALL_DIR/config/database.php" "database.php"
        backup_for_rollback "$INSTALL_DIR/public/index.php" "index.php"
        backup_for_rollback "$INSTALL_DIR/service/config.php" "service_config.php"
        backup_for_rollback "$INSTALL_DIR/domain.json" "domain.json"
        
        git stash 2>/dev/null || true
        
        if git pull origin main 2>&1; then
            ok "代码更新完成"
        else
            warn "git pull 失败，尝试强制更新..."
            git fetch --all
            git reset --hard origin/main
            ok "代码强制更新完成"
        fi
    else
        if [[ -d "$INSTALL_DIR" ]]; then
            BACKUP_DIR="${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
            warn "备份现有目录: ${BACKUP_DIR}"
            mv "$INSTALL_DIR" "$BACKUP_DIR"
        fi
        
        if ! git clone --depth 1 https://github.com/jwzz693/kefuxitong.git "$INSTALL_DIR" 2>&1; then
            if [[ -d "$BACKUP_DIR" ]]; then
                mv "$BACKUP_DIR" "$INSTALL_DIR"
            fi
            err "代码克隆失败"
        fi
        ok "代码克隆完成"
    fi
    
    mkdir -p "$INSTALL_DIR/runtime/cache" \
             "$INSTALL_DIR/runtime/log" \
             "$INSTALL_DIR/runtime/temp" \
             "$INSTALL_DIR/public/upload"
fi

# 步骤 7: 导入数据库
if [[ $START_STEP -le 7 ]]; then
    step 7 "导入数据库"
    save_progress 7
    
    if [[ "$MODE" == "update" ]]; then
        info "更新模式: 跳过数据库导入（保留现有数据）"
    else
        SQL_FILE="$INSTALL_DIR/dkewl.sql"
        if [[ -f "$SQL_FILE" ]]; then
            SQL_SIZE=$(du -h "$SQL_FILE" | awk '{print $1}')
            info "导入 ${SQL_SIZE} SQL 文件..."
            
            if mysql_app_exec "${DB_NAME}" < "$SQL_FILE" 2>/dev/null; then
                :
            elif mysql_root_exec "${DB_NAME}" < "$SQL_FILE" 2>/dev/null; then
                :
            else
                warn "SQL 导入有错误（可能部分表已存在）"
            fi
            
            TABLE_COUNT=$(mysql_app_exec -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" 2>/dev/null) || \
            TABLE_COUNT=$(mysql_root_exec -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" 2>/dev/null) || \
            TABLE_COUNT="?"
            ok "数据库导入完成，共 ${TABLE_COUNT} 张表"
        else
            warn "SQL 文件不存在"
        fi
    fi
fi

# 步骤 8: 生成配置
if [[ $START_STEP -le 8 ]]; then
    step 8 "生成配置文件"
    save_progress 8
    
    if [[ "$MODE" == "update" ]]; then
        info "更新模式: 保留现有配置文件"
    else
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
        
        cat > "$INSTALL_DIR/domain.json" << DJEOF
{"domain":"${PROTOCOL}://${DOMAIN}"}
DJEOF
        
        ok "配置文件已生成"
    fi
fi

# 步骤 9: 配置 Nginx
if [[ $START_STEP -le 9 ]]; then
    step 9 "配置 Nginx"
    save_progress 9
    
    backup_for_rollback "/etc/nginx/sites-available/kefuxitong" "nginx_kefuxitong"
    
    cat > "/etc/nginx/sites-available/kefuxitong" << 'NGXEOF'
server {
    listen 80;
    server_name PLACEHOLDER_DOMAIN;
    root PLACEHOLDER_INSTALL_DIR/public;
    index index.php index.html;

    charset utf-8;
    client_max_body_size 50m;

    location ~ /\. {
        deny all;
    }

    location /wss {
        proxy_pass http://127.0.0.1:PLACEHOLDER_WS_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }

    location / {
        if (!-e $request_filename) {
            rewrite ^(.*)$ /index.php?s=/$1 last;
            break;
        }
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
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
    
    sed -i "s|PLACEHOLDER_DOMAIN|${DOMAIN}|g" /etc/nginx/sites-available/kefuxitong
    sed -i "s|PLACEHOLDER_INSTALL_DIR|${INSTALL_DIR}|g" /etc/nginx/sites-available/kefuxitong
    sed -i "s|PLACEHOLDER_WS_PORT|${WS_PORT}|g" /etc/nginx/sites-available/kefuxitong
    
    ln -sf /etc/nginx/sites-available/kefuxitong /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    if nginx -t 2>&1 | grep -q "successful"; then
        systemctl reload nginx
        ok "Nginx 配置完成"
    else
        rollback_file "nginx_kefuxitong" "/etc/nginx/sites-available/kefuxitong"
        err "Nginx 配置失败"
    fi
fi

# 步骤 10: SSL 证书
if [[ $START_STEP -le 10 ]]; then
    step 10 "SSL 证书"
    save_progress 10
    
    if [[ "$ENABLE_SSL" == "y" || "$ENABLE_SSL" == "Y" ]]; then
        apt-get install -y -qq certbot python3-certbot-nginx >/dev/null 2>&1 || warn "Certbot 安装失败"
        if command -v certbot &>/dev/null; then
            if certbot --nginx -d "$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect 2>&1; then
                systemctl enable certbot.timer >/dev/null 2>&1 || true
                ok "SSL 证书已配置"
            else
                warn "SSL 证书申请失败，HTTP 模式可用"
            fi
        fi
    else
        ok "跳过（未启用 SSL）"
    fi
fi

# 步骤 11: 启动 Workerman
if [[ $START_STEP -le 11 ]]; then
    step 11 "启动 Workerman"
    save_progress 11
    
    cd "$INSTALL_DIR"
    
    if [[ -f "service/start.php" ]]; then
        php service/start.php stop >/dev/null 2>&1 || true
        sleep 1
        php service/start.php start -d 2>&1 || true
        sleep 3
        
        if ps -ef | grep -E "workerman|Pusher|start\.php" | grep -v grep >/dev/null 2>&1; then
            ok "Workerman 启动成功"
        else
            warn "Workerman 可能未启动，请手动检查"
        fi
    fi
    
    CRON_RUN="* * * * * sh ${INSTALL_DIR}/run.sh >/dev/null 2>&1"
    CRON_UPGRADE="0 * * * * sh ${INSTALL_DIR}/auto_upgrade.sh >/dev/null 2>&1"
    {
        crontab -l 2>/dev/null | grep -v "run\.sh" | grep -v "auto_upgrade\.sh" || true
        echo "$CRON_RUN"
        echo "$CRON_UPGRADE"
    } | crontab -
    ok "定时任务已配置"
fi

# 步骤 12: 防火墙与权限
if [[ $START_STEP -le 12 ]]; then
    step 12 "防火墙与权限"
    save_progress 12
    
    if command -v ufw &>/dev/null; then
        ufw --force enable >/dev/null 2>&1 || true
        for port in 22 80 443 "${WS_PORT}" "${API_PORT}"; do
            ufw allow "${port}/tcp" >/dev/null 2>&1 || true
        done
        ok "UFW 防火墙已配置"
    elif command -v iptables &>/dev/null; then
        for port in 80 443 "${WS_PORT}" "${API_PORT}"; do
            iptables -C INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1 || \
            iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
        done
        ok "iptables 防火墙已配置"
    fi
    
    chown -R www-data:www-data "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    chmod -R 777 "$INSTALL_DIR/runtime"
    chmod -R 777 "$INSTALL_DIR/public/upload" 2>/dev/null || true
    ok "目录权限已设置"
fi

# ======================== 清理进度 ========================
clear_progress
clear_rollback

# ======================== 健康检查 ========================
health_check

# ======================== 保存部署信息 ========================
DEPLOY_INFO="$INSTALL_DIR/deploy_info.txt"
cat > "$DEPLOY_INFO" << INFOEOF
═══════════════════════════════════════════════════
  客服系统部署信息（请妥善保管）
═══════════════════════════════════════════════════
部署时间:       $(date '+%Y-%m-%d %H:%M:%S')
部署模式:       ${MODE}
系统版本:       $(cat /etc/debian_version 2>/dev/null || echo "unknown")
───────────────────────────────────────────────────
访问地址:       ${PROTOCOL}://${DOMAIN}
WebSocket:      ${WS_PROTOCOL}://${DOMAIN}:${WS_PORT}
API 端口:       ${API_PORT}
安装路径:       ${INSTALL_DIR}
───────────────────────────────────────────────────
数据库名:       ${DB_NAME}
数据库用户:     ${DB_USER}
数据库密码:     ${DB_PASS}
数据库Root密码: ${DB_ROOT_PASS}
───────────────────────────────────────────────────
Pusher Key:     ${APP_KEY}
Pusher Secret:  ${APP_SECRET}
App ID:         ${APP_ID}
Regist Token:   ${REGIST_TOKEN}
AIKF Salt:      ${AIKF_SALT}
═══════════════════════════════════════════════════
INFOEOF
chmod 600 "$DEPLOY_INFO"

# ======================== 完成输出 ========================
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    部署完成！${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  访问地址:    ${CYAN}${PROTOCOL}://${DOMAIN}${NC}"
echo -e "  WebSocket:   ${CYAN}${WS_PROTOCOL}://${DOMAIN}:${WS_PORT}${NC}"
echo -e "  安装路径:    ${INSTALL_DIR}"
echo ""
echo -e "  数据库:      ${DB_NAME} / ${DB_USER}"
echo -e "  数据库密码:  ${YELLOW}${DB_PASS}${NC}"
echo -e "  Root密码:    ${YELLOW}${DB_ROOT_PASS}${NC}"
echo ""
echo "  ── 管理命令 ──"
echo "  查看状态:    bash deploy_debian12.sh --status"
echo "  更新代码:    bash deploy_debian12.sh --update"
echo "  修复服务:    bash deploy_debian12.sh --repair"
echo "  启动WS:      php ${INSTALL_DIR}/service/start.php start -d"
echo "  停止WS:      php ${INSTALL_DIR}/service/start.php stop"
echo ""
echo -e "  部署信息:    ${CYAN}${DEPLOY_INFO}${NC}"
echo -e "  部署日志:    ${CYAN}${DEPLOY_LOG}${NC}"
echo ""
