#!/bin/bash
#
# GOST 一键部署管理脚本
# OneKey GOST Deployment Script
# 
# 项目地址: https://github.com/ginuerzh/gost
# 脚本版本: 1.0.0
# 支持系统: CentOS 7+, Debian 9+, Ubuntu 18.04+
#

# ==================== 全局变量 ====================
SCRIPT_VERSION="1.0.0"
GOST_VERSION="2.12.0"
GOST_INSTALL_PATH="/usr/local/bin/gost"
GOST_CONFIG_DIR="/etc/gost"
GOST_CONFIG_FILE="${GOST_CONFIG_DIR}/config.json"
GOST_RAW_CONFIG="${GOST_CONFIG_DIR}/rawconf"
GOST_SERVICE_FILE="/etc/systemd/system/gost.service"
GOST_CERT_DIR="${HOME}/gost_cert"
GOST_GITHUB_REPO="ginuerzh/gost"
GOST_DOWNLOAD_URL="https://github.com/${GOST_GITHUB_REPO}/releases/download"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ==================== 工具函数 ====================

print_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_line() {
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
}

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║          GOST 一键部署管理脚本 v${SCRIPT_VERSION}                  ║"
    echo "║          OneKey GOST Deployment Script                   ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local answer
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -r -p "$prompt" answer
    answer=${answer:-$default}
    
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ==================== 系统检测 ====================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行"
        print_info "请使用 sudo ./gost.sh 或切换到 root 用户"
        exit 1
    fi
}

check_system() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        PM="yum"
    elif grep -qi "debian" /etc/os-release 2>/dev/null; then
        OS="debian"
        PM="apt-get"
    elif grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        OS="ubuntu"
        PM="apt-get"
    else
        print_error "不支持的操作系统"
        print_info "支持的系统: CentOS 7+, Debian 9+, Ubuntu 18.04+"
        exit 1
    fi
    print_info "检测到系统: ${OS}"
}

check_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        armv6l)
            ARCH="armv6"
            ;;
        armv5*)
            ARCH="armv5"
            ;;
        i386|i686)
            ARCH="386"
            ;;
        *)
            print_error "不支持的 CPU 架构: $ARCH"
            print_info "支持的架构: amd64, arm64, armv7, armv6, armv5, 386"
            exit 1
            ;;
    esac
    print_info "检测到架构: ${ARCH}"
}

install_dependencies() {
    print_info "安装依赖..."
    if [[ "$PM" == "apt-get" ]]; then
        apt-get update -qq
        apt-get install -y -qq wget curl gzip jq > /dev/null 2>&1
    else
        yum install -y -q wget curl gzip jq > /dev/null 2>&1
    fi
    print_success "依赖安装完成"
}

# ==================== 版本管理 ====================

get_latest_version() {
    local latest
    latest=$(curl -s "https://api.github.com/repos/${GOST_GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [[ -z "$latest" ]]; then
        latest="$GOST_VERSION"
        print_warn "无法获取最新版本，使用默认版本: v${latest}"
    fi
    echo "$latest"
}

get_installed_version() {
    if [[ -f "$GOST_INSTALL_PATH" ]]; then
        $GOST_INSTALL_PATH -V 2>&1 | awk '{print $2}'
    else
        echo ""
    fi
}

# ==================== 安装功能 ====================

download_gost() {
    local version="$1"
    local use_mirror="$2"
    local download_url
    local filename="gost_${version}_linux_${ARCH}.tar.gz"
    
    if [[ "$use_mirror" == "y" ]]; then
        # 国内镜像
        download_url="https://ghproxy.com/https://github.com/${GOST_GITHUB_REPO}/releases/download/v${version}/${filename}"
    else
        download_url="${GOST_DOWNLOAD_URL}/v${version}/${filename}"
    fi
    
    print_info "下载地址: ${download_url}"
    print_info "正在下载 GOST v${version}..."
    
    cd /tmp
    rm -f gost_*.tar.gz gost gost-linux-* 2>/dev/null
    
    if wget -q --show-progress -O "$filename" "$download_url" 2>/dev/null; then
        tar -xzf "$filename"
        if [[ -f "gost" ]]; then
            chmod +x gost
            print_success "下载完成"
            return 0
        fi
    fi
    
    # 尝试旧版本格式 (gost-linux-amd64-x.x.x.gz)
    print_warn "尝试旧版本格式..."
    local old_filename="gost-linux-${ARCH}-${version}.gz"
    if [[ "$use_mirror" == "y" ]]; then
        download_url="https://ghproxy.com/https://github.com/${GOST_GITHUB_REPO}/releases/download/v${version}/${old_filename}"
    else
        download_url="${GOST_DOWNLOAD_URL}/v${version}/${old_filename}"
    fi
    
    if wget -q --show-progress -O "$old_filename" "$download_url" 2>/dev/null; then
        gunzip -f "$old_filename"
        mv "gost-linux-${ARCH}-${version}" gost
        chmod +x gost
        print_success "下载完成"
        return 0
    fi
    
    print_error "下载失败"
    return 1
}

install_gost() {
    print_header
    print_line
    echo -e "${BOLD}安装 GOST${NC}"
    print_line
    
    # 检查是否已安装
    local installed_ver
    installed_ver=$(get_installed_version)
    if [[ -n "$installed_ver" ]]; then
        print_warn "检测到已安装 GOST v${installed_ver}"
        if ! confirm "是否覆盖安装?"; then
            return
        fi
    fi
    
    check_system
    check_arch
    install_dependencies
    
    # 获取版本
    echo ""
    print_info "正在获取最新版本信息..."
    local latest_ver
    latest_ver=$(get_latest_version)
    
    echo ""
    echo -e "可用版本:"
    echo -e "  [1] 最新版本 v${latest_ver} ${GREEN}(推荐)${NC}"
    echo -e "  [2] 稳定版本 v2.11.5"
    echo -e "  [3] 自定义版本"
    echo ""
    read -r -p "请选择 [1-3] (默认: 1): " ver_choice
    ver_choice=${ver_choice:-1}
    
    local install_ver
    case $ver_choice in
        1) install_ver="$latest_ver" ;;
        2) install_ver="2.11.5" ;;
        3)
            read -r -p "请输入版本号 (如 2.11.2): " install_ver
            ;;
        *) install_ver="$latest_ver" ;;
    esac
    
    # 下载源选择
    echo ""
    local use_mirror="n"
    if confirm "是否使用国内镜像加速下载? (国内服务器推荐)"; then
        use_mirror="y"
    fi
    
    # 下载
    echo ""
    if ! download_gost "$install_ver" "$use_mirror"; then
        print_error "安装失败"
        return 1
    fi
    
    # 安装
    print_info "安装 GOST..."
    mv /tmp/gost "$GOST_INSTALL_PATH"
    chmod +x "$GOST_INSTALL_PATH"
    
    # 创建配置目录
    mkdir -p "$GOST_CONFIG_DIR"
    
    # 创建默认配置文件
    if [[ ! -f "$GOST_CONFIG_FILE" ]]; then
        cat > "$GOST_CONFIG_FILE" << 'EOF'
{
    "Debug": false,
    "Retries": 3,
    "ServeNodes": [],
    "ChainNodes": [],
    "Routes": []
}
EOF
    fi
    
    # 创建原始配置文件
    touch "$GOST_RAW_CONFIG"
    
    # 创建 systemd 服务
    create_service
    
    # 启用服务
    systemctl daemon-reload
    systemctl enable gost > /dev/null 2>&1
    
    echo ""
    print_line
    print_success "GOST v${install_ver} 安装成功!"
    print_line
    echo -e "  安装路径: ${GOST_INSTALL_PATH}"
    echo -e "  配置目录: ${GOST_CONFIG_DIR}"
    echo -e "  配置文件: ${GOST_CONFIG_FILE}"
    echo -e "  服务文件: ${GOST_SERVICE_FILE}"
    print_line
    echo ""
    print_info "使用 './gost.sh' 管理 GOST 服务和配置"
}

create_service() {
    cat > "$GOST_SERVICE_FILE" << EOF
[Unit]
Description=GOST Proxy Service
Documentation=https://v2.gost.run
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=${GOST_INSTALL_PATH} -C ${GOST_CONFIG_FILE}
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    print_success "systemd 服务创建完成"
}

# ==================== 卸载功能 ====================

uninstall_gost() {
    print_header
    print_line
    echo -e "${BOLD}卸载 GOST${NC}"
    print_line
    
    if [[ ! -f "$GOST_INSTALL_PATH" ]]; then
        print_warn "GOST 未安装"
        return
    fi
    
    echo ""
    print_warn "此操作将删除 GOST 及其所有配置文件"
    if ! confirm "确定要卸载吗?"; then
        print_info "取消卸载"
        return
    fi
    
    # 停止服务
    systemctl stop gost 2>/dev/null || true
    systemctl disable gost 2>/dev/null || true
    
    # 删除文件
    rm -f "$GOST_INSTALL_PATH"
    rm -f "$GOST_SERVICE_FILE"
    
    # 询问是否删除配置
    echo ""
    if confirm "是否同时删除配置文件?"; then
        rm -rf "$GOST_CONFIG_DIR"
        print_info "配置文件已删除"
    else
        print_info "配置文件已保留在 ${GOST_CONFIG_DIR}"
    fi
    
    # 询问是否删除证书
    if [[ -d "$GOST_CERT_DIR" ]]; then
        if confirm "是否删除证书文件?"; then
            rm -rf "$GOST_CERT_DIR"
            print_info "证书文件已删除"
        fi
    fi
    
    systemctl daemon-reload
    
    echo ""
    print_success "GOST 已成功卸载"
}

# ==================== 服务管理 ====================

start_gost() {
    if [[ ! -f "$GOST_INSTALL_PATH" ]]; then
        print_error "GOST 未安装，请先安装"
        return 1
    fi
    
    systemctl start gost
    sleep 1
    
    if systemctl is-active --quiet gost; then
        print_success "GOST 已启动"
    else
        print_error "GOST 启动失败"
        print_info "查看日志: journalctl -u gost -n 20"
    fi
}

stop_gost() {
    systemctl stop gost
    print_success "GOST 已停止"
}

restart_gost() {
    if [[ ! -f "$GOST_INSTALL_PATH" ]]; then
        print_error "GOST 未安装，请先安装"
        return 1
    fi
    
    # 重新生成配置文件
    generate_config
    
    systemctl restart gost
    sleep 1
    
    if systemctl is-active --quiet gost; then
        print_success "GOST 已重启"
    else
        print_error "GOST 重启失败"
        print_info "查看日志: journalctl -u gost -n 20"
    fi
}

status_gost() {
    print_header
    print_line
    echo -e "${BOLD}GOST 状态${NC}"
    print_line
    
    # 版本信息
    local installed_ver
    installed_ver=$(get_installed_version)
    if [[ -n "$installed_ver" ]]; then
        echo -e "  版本: ${GREEN}v${installed_ver}${NC}"
    else
        echo -e "  版本: ${RED}未安装${NC}"
        return
    fi
    
    # 服务状态
    if systemctl is-active --quiet gost; then
        echo -e "  状态: ${GREEN}运行中${NC}"
    else
        echo -e "  状态: ${RED}已停止${NC}"
    fi
    
    # 开机自启
    if systemctl is-enabled --quiet gost 2>/dev/null; then
        echo -e "  开机自启: ${GREEN}已启用${NC}"
    else
        echo -e "  开机自启: ${YELLOW}未启用${NC}"
    fi
    
    # 配置数量
    local config_count=0
    if [[ -f "$GOST_RAW_CONFIG" ]]; then
        config_count=$(grep -c . "$GOST_RAW_CONFIG" 2>/dev/null || echo "0")
    fi
    echo -e "  转发规则: ${config_count} 条"
    
    print_line
    echo ""
    
    # 显示详细状态
    systemctl status gost --no-pager 2>/dev/null || true
}

show_logs() {
    print_header
    print_line
    echo -e "${BOLD}GOST 日志${NC}"
    print_line
    echo ""
    
    echo -e "显示最近 50 条日志 (按 Ctrl+C 退出实时查看)"
    echo ""
    
    journalctl -u gost -n 50 --no-pager
    
    echo ""
    if confirm "是否实时查看日志?"; then
        journalctl -u gost -f
    fi
}

# ==================== 配置管理 ====================

add_config() {
    print_header
    print_line
    echo -e "${BOLD}添加转发规则${NC}"
    print_line
    echo ""
    echo -e "请选择配置类型:"
    echo ""
    echo -e "  ${GREEN}[1]${NC} TCP/UDP 端口转发 (不加密)"
    echo -e "      ${CYAN}说明: 将本机端口流量转发到目标地址${NC}"
    echo ""
    echo -e "  ${GREEN}[2]${NC} 加密隧道转发 (中转机)"
    echo -e "      ${CYAN}说明: 加密流量后转发到落地机，支持 TLS/WS/WSS${NC}"
    echo ""
    echo -e "  ${GREEN}[3]${NC} 解密隧道接收 (落地机)"
    echo -e "      ${CYAN}说明: 接收并解密来自中转机的流量${NC}"
    echo ""
    echo -e "  ${GREEN}[4]${NC} HTTP/SOCKS5 代理服务"
    echo -e "      ${CYAN}说明: 在本机启动代理服务器${NC}"
    echo ""
    echo -e "  ${GREEN}[5]${NC} Shadowsocks 代理"
    echo -e "      ${CYAN}说明: 启动 Shadowsocks 服务${NC}"
    echo ""
    echo -e "  ${GREEN}[6]${NC} 负载均衡"
    echo -e "      ${CYAN}说明: 将流量分发到多个后端服务器${NC}"
    echo ""
    echo -e "  ${GREEN}[0]${NC} 返回主菜单"
    echo ""
    print_line
    
    read -r -p "请选择 [0-6]: " config_type
    
    case $config_type in
        1) add_forward_config ;;
        2) add_encrypt_config ;;
        3) add_decrypt_config ;;
        4) add_proxy_config ;;
        5) add_ss_config ;;
        6) add_loadbalance_config ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

add_forward_config() {
    echo ""
    print_line
    echo -e "${BOLD}TCP/UDP 端口转发配置${NC}"
    print_line
    echo ""
    
    read -r -p "请输入本地监听端口: " local_port
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [[ "$local_port" -lt 1 ]] || [[ "$local_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    read -r -p "请输入目标 IP 或域名: " target_ip
    if [[ -z "$target_ip" ]]; then
        print_error "目标地址不能为空"
        return
    fi
    
    read -r -p "请输入目标端口: " target_port
    if ! [[ "$target_port" =~ ^[0-9]+$ ]] || [[ "$target_port" -lt 1 ]] || [[ "$target_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    # 保存配置
    echo "forward/${local_port}#${target_ip}#${target_port}" >> "$GOST_RAW_CONFIG"
    
    # 重新生成配置并重启
    generate_config
    restart_gost
    
    echo ""
    print_success "端口转发配置已添加"
    echo -e "  本地端口 ${local_port} → ${target_ip}:${target_port}"
}

add_encrypt_config() {
    echo ""
    print_line
    echo -e "${BOLD}加密隧道转发配置 (中转机)${NC}"
    print_line
    echo ""
    
    echo -e "请选择加密类型:"
    echo -e "  [1] TLS 隧道"
    echo -e "  [2] WebSocket (WS) 隧道"
    echo -e "  [3] WebSocket + TLS (WSS) 隧道"
    echo ""
    read -r -p "请选择 [1-3]: " encrypt_type
    
    local encrypt_name
    case $encrypt_type in
        1) encrypt_name="tls" ;;
        2) encrypt_name="ws" ;;
        3) encrypt_name="wss" ;;
        *) print_error "无效选择"; return ;;
    esac
    
    read -r -p "请输入本地监听端口: " local_port
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [[ "$local_port" -lt 1 ]] || [[ "$local_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    read -r -p "请输入落地机 IP 或域名: " target_ip
    if [[ -z "$target_ip" ]]; then
        print_error "目标地址不能为空"
        return
    fi
    
    read -r -p "请输入落地机端口: " target_port
    if ! [[ "$target_port" =~ ^[0-9]+$ ]] || [[ "$target_port" -lt 1 ]] || [[ "$target_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    local secure=""
    if [[ "$encrypt_type" == "1" ]] || [[ "$encrypt_type" == "3" ]]; then
        if confirm "落地机是否使用自定义证书? (启用证书校验)"; then
            secure="?secure=true"
        fi
    fi
    
    # 保存配置
    echo "encrypt_${encrypt_name}/${local_port}#${target_ip}#${target_port}${secure}" >> "$GOST_RAW_CONFIG"
    
    generate_config
    restart_gost
    
    echo ""
    print_success "加密隧道配置已添加"
    echo -e "  本地端口 ${local_port} → relay+${encrypt_name}://${target_ip}:${target_port}"
}

add_decrypt_config() {
    echo ""
    print_line
    echo -e "${BOLD}解密隧道接收配置 (落地机)${NC}"
    print_line
    echo ""
    
    echo -e "请选择解密类型 (需与中转机对应):"
    echo -e "  [1] TLS 解密"
    echo -e "  [2] WebSocket (WS) 解密"
    echo -e "  [3] WebSocket + TLS (WSS) 解密"
    echo ""
    read -r -p "请选择 [1-3]: " decrypt_type
    
    local decrypt_name
    case $decrypt_type in
        1) decrypt_name="tls" ;;
        2) decrypt_name="ws" ;;
        3) decrypt_name="wss" ;;
        *) print_error "无效选择"; return ;;
    esac
    
    read -r -p "请输入监听端口: " local_port
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [[ "$local_port" -lt 1 ]] || [[ "$local_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    read -r -p "请输入转发目标 IP (本机服务填 127.0.0.1): " target_ip
    if [[ -z "$target_ip" ]]; then
        print_error "目标地址不能为空"
        return
    fi
    
    read -r -p "请输入转发目标端口: " target_port
    if ! [[ "$target_port" =~ ^[0-9]+$ ]] || [[ "$target_port" -lt 1 ]] || [[ "$target_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    # 保存配置
    echo "decrypt_${decrypt_name}/${local_port}#${target_ip}#${target_port}" >> "$GOST_RAW_CONFIG"
    
    generate_config
    restart_gost
    
    echo ""
    print_success "解密隧道配置已添加"
    echo -e "  监听 relay+${decrypt_name}://:${local_port} → ${target_ip}:${target_port}"
}

add_proxy_config() {
    echo ""
    print_line
    echo -e "${BOLD}HTTP/SOCKS5 代理配置${NC}"
    print_line
    echo ""
    
    echo -e "请选择代理类型:"
    echo -e "  [1] HTTP 代理"
    echo -e "  [2] SOCKS5 代理"
    echo -e "  [3] HTTP + SOCKS5 (同端口)"
    echo ""
    read -r -p "请选择 [1-3]: " proxy_type
    
    local proxy_name
    case $proxy_type in
        1) proxy_name="http" ;;
        2) proxy_name="socks5" ;;
        3) proxy_name="auto" ;;
        *) print_error "无效选择"; return ;;
    esac
    
    read -r -p "请输入监听端口: " local_port
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [[ "$local_port" -lt 1 ]] || [[ "$local_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    local auth=""
    if confirm "是否设置认证?"; then
        read -r -p "请输入用户名: " username
        read -r -s -p "请输入密码: " password
        echo ""
        auth="${username}:${password}@"
    fi
    
    # 保存配置
    echo "proxy_${proxy_name}/${local_port}#${auth}#" >> "$GOST_RAW_CONFIG"
    
    generate_config
    restart_gost
    
    echo ""
    print_success "代理服务配置已添加"
    if [[ -n "$auth" ]]; then
        echo -e "  ${proxy_name}://${username}:****@:${local_port}"
    else
        echo -e "  ${proxy_name}://:${local_port}"
    fi
}

add_ss_config() {
    echo ""
    print_line
    echo -e "${BOLD}Shadowsocks 配置${NC}"
    print_line
    echo ""
    
    read -r -p "请输入监听端口: " local_port
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [[ "$local_port" -lt 1 ]] || [[ "$local_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    read -r -s -p "请输入密码: " password
    echo ""
    
    if [[ -z "$password" ]]; then
        print_error "密码不能为空"
        return
    fi
    
    echo ""
    echo -e "请选择加密方式:"
    echo -e "  [1] aes-256-gcm ${GREEN}(推荐)${NC}"
    echo -e "  [2] chacha20-ietf-poly1305 ${GREEN}(推荐)${NC}"
    echo -e "  [3] aes-128-gcm"
    echo -e "  [4] aes-256-cfb"
    echo -e "  [5] aes-128-cfb"
    echo -e "  [6] chacha20"
    echo ""
    read -r -p "请选择 [1-6] (默认: 1): " cipher_choice
    cipher_choice=${cipher_choice:-1}
    
    local cipher
    case $cipher_choice in
        1) cipher="aes-256-gcm" ;;
        2) cipher="chacha20-ietf-poly1305" ;;
        3) cipher="aes-128-gcm" ;;
        4) cipher="aes-256-cfb" ;;
        5) cipher="aes-128-cfb" ;;
        6) cipher="chacha20" ;;
        *) cipher="aes-256-gcm" ;;
    esac
    
    # 保存配置
    echo "ss/${local_port}#${cipher}#${password}" >> "$GOST_RAW_CONFIG"
    
    generate_config
    restart_gost
    
    echo ""
    print_success "Shadowsocks 配置已添加"
    echo -e "  ss://${cipher}:****@:${local_port}"
    
    # 获取公网 IP
    local public_ip
    public_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || echo "YOUR_IP")
    
    # 生成分享链接
    local ss_link
    ss_link=$(echo -n "${cipher}:${password}@${public_ip}:${local_port}" | base64 -w 0 2>/dev/null || echo -n "${cipher}:${password}@${public_ip}:${local_port}" | base64)
    echo ""
    echo -e "  分享链接: ss://${ss_link}"
}

add_loadbalance_config() {
    echo ""
    print_line
    echo -e "${BOLD}负载均衡配置${NC}"
    print_line
    echo ""
    
    read -r -p "请输入本地监听端口: " local_port
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [[ "$local_port" -lt 1 ]] || [[ "$local_port" -gt 65535 ]]; then
        print_error "无效的端口号"
        return
    fi
    
    echo ""
    echo -e "请选择负载均衡策略:"
    echo -e "  [1] round - 轮询"
    echo -e "  [2] random - 随机"
    echo -e "  [3] fifo - 顺序优先"
    echo ""
    read -r -p "请选择 [1-3] (默认: 1): " strategy_choice
    strategy_choice=${strategy_choice:-1}
    
    local strategy
    case $strategy_choice in
        1) strategy="round" ;;
        2) strategy="random" ;;
        3) strategy="fifo" ;;
        *) strategy="round" ;;
    esac
    
    echo ""
    echo -e "请输入后端服务器列表 (格式: IP:端口)"
    echo -e "输入空行结束"
    
    local servers=""
    local count=0
    while true; do
        read -r -p "服务器 $((count+1)): " server
        if [[ -z "$server" ]]; then
            if [[ $count -lt 2 ]]; then
                print_warn "至少需要 2 个后端服务器"
                continue
            fi
            break
        fi
        if [[ $count -gt 0 ]]; then
            servers="${servers},"
        fi
        servers="${servers}${server}"
        ((count++))
    done
    
    # 保存配置
    echo "lb_${strategy}/${local_port}#${servers}#" >> "$GOST_RAW_CONFIG"
    
    generate_config
    restart_gost
    
    echo ""
    print_success "负载均衡配置已添加"
    echo -e "  策略: ${strategy}"
    echo -e "  后端: ${servers}"
}

show_config() {
    print_header
    print_line
    echo -e "${BOLD}当前配置列表${NC}"
    print_line
    
    if [[ ! -f "$GOST_RAW_CONFIG" ]] || [[ ! -s "$GOST_RAW_CONFIG" ]]; then
        echo ""
        print_warn "暂无配置"
        return
    fi
    
    echo ""
    printf "%-4s %-20s %-12s %-30s\n" "序号" "类型" "本地端口" "目标地址"
    print_line
    
    local i=1
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local config_type="${line%%/*}"
        local rest="${line#*/}"
        local local_port="${rest%%#*}"
        rest="${rest#*#}"
        local target="${rest%%#*}"
        local extra="${rest#*#}"
        
        local type_display
        case $config_type in
            forward) type_display="端口转发" ;;
            encrypt_tls) type_display="TLS加密隧道" ;;
            encrypt_ws) type_display="WS加密隧道" ;;
            encrypt_wss) type_display="WSS加密隧道" ;;
            decrypt_tls) type_display="TLS解密" ;;
            decrypt_ws) type_display="WS解密" ;;
            decrypt_wss) type_display="WSS解密" ;;
            proxy_http) type_display="HTTP代理" ;;
            proxy_socks5) type_display="SOCKS5代理" ;;
            proxy_auto) type_display="HTTP/SOCKS5" ;;
            ss) type_display="Shadowsocks" ;;
            lb_*) type_display="负载均衡" ;;
            *) type_display="$config_type" ;;
        esac
        
        local target_display
        if [[ "$config_type" == "ss" ]]; then
            target_display="${target}:****"
        elif [[ "$config_type" == proxy_* ]]; then
            if [[ -n "$target" ]]; then
                target_display="认证: ${target%%:*}"
            else
                target_display="无认证"
            fi
        elif [[ "$config_type" == lb_* ]]; then
            target_display="${target}"
        else
            target_display="${target}:${extra%%\?*}"
        fi
        
        printf "%-4s %-20s %-12s %-30s\n" "[$i]" "$type_display" "$local_port" "$target_display"
        ((i++))
    done < "$GOST_RAW_CONFIG"
    
    print_line
    echo ""
}

delete_config() {
    show_config
    
    if [[ ! -f "$GOST_RAW_CONFIG" ]] || [[ ! -s "$GOST_RAW_CONFIG" ]]; then
        return
    fi
    
    local total
    total=$(grep -c . "$GOST_RAW_CONFIG" 2>/dev/null || echo "0")
    
    if [[ "$total" -eq 0 ]]; then
        return
    fi
    
    read -r -p "请输入要删除的配置序号 (1-${total}): " del_num
    
    if ! [[ "$del_num" =~ ^[0-9]+$ ]] || [[ "$del_num" -lt 1 ]] || [[ "$del_num" -gt "$total" ]]; then
        print_error "无效的序号"
        return
    fi
    
    sed -i "${del_num}d" "$GOST_RAW_CONFIG"
    
    generate_config
    restart_gost
    
    print_success "配置已删除"
}

# ==================== 配置生成 ====================

generate_config() {
    # 如果原始配置文件不存在或为空，生成空配置
    if [[ ! -f "$GOST_RAW_CONFIG" ]] || [[ ! -s "$GOST_RAW_CONFIG" ]]; then
        cat > "$GOST_CONFIG_FILE" << 'EOF'
{
    "Debug": false,
    "Retries": 3,
    "ServeNodes": [],
    "ChainNodes": [],
    "Routes": []
}
EOF
        return
    fi
    
    # 临时文件
    local tmp_serve="/tmp/gost_serve_$$"
    local tmp_routes="/tmp/gost_routes_$$"
    
    > "$tmp_serve"
    > "$tmp_routes"
    
    local serve_count=0
    local route_count=0
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local config_type="${line%%/*}"
        local rest="${line#*/}"
        local local_port="${rest%%#*}"
        rest="${rest#*#}"
        local param1="${rest%%#*}"
        local param2="${rest#*#}"
        
        case $config_type in
            forward)
                # TCP/UDP 端口转发
                if [[ $serve_count -gt 0 ]]; then
                    echo "," >> "$tmp_serve"
                fi
                echo -n "        \"tcp://:${local_port}/${param1}:${param2}\"" >> "$tmp_serve"
                ((serve_count++))
                ;;
            
            encrypt_tls|encrypt_ws|encrypt_wss)
                # 加密隧道 - 需要使用 Routes
                local transport="${config_type#encrypt_}"
                local secure_param=""
                if [[ "$param2" == *"secure=true"* ]]; then
                    secure_param="?secure=true"
                    param2="${param2%%\?*}"
                fi
                
                if [[ $route_count -gt 0 ]]; then
                    echo "," >> "$tmp_routes"
                fi
                cat >> "$tmp_routes" << EOF
        {
            "Retries": 3,
            "ServeNodes": [
                "tcp://:${local_port}",
                "udp://:${local_port}"
            ],
            "ChainNodes": [
                "relay+${transport}://${param1}:${param2}${secure_param}"
            ]
        }
EOF
                ((route_count++))
                ;;
            
            decrypt_tls|decrypt_ws|decrypt_wss)
                # 解密隧道
                local transport="${config_type#decrypt_}"
                local cert_param=""
                if [[ -d "$GOST_CERT_DIR" ]] && [[ -f "${GOST_CERT_DIR}/cert.pem" ]]; then
                    cert_param="?cert=${GOST_CERT_DIR}/cert.pem&key=${GOST_CERT_DIR}/key.pem"
                fi
                
                if [[ $serve_count -gt 0 ]]; then
                    echo "," >> "$tmp_serve"
                fi
                echo -n "        \"relay+${transport}://:${local_port}/${param1}:${param2}${cert_param}\"" >> "$tmp_serve"
                ((serve_count++))
                ;;
            
            proxy_http)
                if [[ $serve_count -gt 0 ]]; then
                    echo "," >> "$tmp_serve"
                fi
                if [[ -n "$param1" ]]; then
                    echo -n "        \"http://${param1}:${local_port}\"" >> "$tmp_serve"
                else
                    echo -n "        \"http://:${local_port}\"" >> "$tmp_serve"
                fi
                ((serve_count++))
                ;;
            
            proxy_socks5)
                if [[ $serve_count -gt 0 ]]; then
                    echo "," >> "$tmp_serve"
                fi
                if [[ -n "$param1" ]]; then
                    echo -n "        \"socks5://${param1}:${local_port}\"" >> "$tmp_serve"
                else
                    echo -n "        \"socks5://:${local_port}\"" >> "$tmp_serve"
                fi
                ((serve_count++))
                ;;
            
            proxy_auto)
                if [[ $serve_count -gt 0 ]]; then
                    echo "," >> "$tmp_serve"
                fi
                if [[ -n "$param1" ]]; then
                    echo -n "        \"${param1}:${local_port}\"" >> "$tmp_serve"
                else
                    echo -n "        \":${local_port}\"" >> "$tmp_serve"
                fi
                ((serve_count++))
                ;;
            
            ss)
                if [[ $serve_count -gt 0 ]]; then
                    echo "," >> "$tmp_serve"
                fi
                echo -n "        \"ss://${param1}:${param2}@:${local_port}\"" >> "$tmp_serve"
                ((serve_count++))
                ;;
            
            lb_*)
                # 负载均衡
                local strategy="${config_type#lb_}"
                local servers="$param1"
                
                if [[ $route_count -gt 0 ]]; then
                    echo "," >> "$tmp_routes"
                fi
                
                cat >> "$tmp_routes" << EOF
        {
            "Retries": 3,
            "ServeNodes": [
                "tcp://:${local_port}?ip=${servers}&strategy=${strategy}",
                "udp://:${local_port}?ip=${servers}&strategy=${strategy}"
            ]
        }
EOF
                ((route_count++))
                ;;
        esac
        
    done < "$GOST_RAW_CONFIG"
    
    # 生成最终配置文件
    cat > "$GOST_CONFIG_FILE" << EOF
{
    "Debug": false,
    "Retries": 3,
    "ServeNodes": [
EOF
    
    if [[ -s "$tmp_serve" ]]; then
        cat "$tmp_serve" >> "$GOST_CONFIG_FILE"
        echo "" >> "$GOST_CONFIG_FILE"
    fi
    
    cat >> "$GOST_CONFIG_FILE" << EOF
    ],
    "ChainNodes": [],
    "Routes": [
EOF
    
    if [[ -s "$tmp_routes" ]]; then
        cat "$tmp_routes" >> "$GOST_CONFIG_FILE"
    fi
    
    cat >> "$GOST_CONFIG_FILE" << EOF
    ]
}
EOF
    
    # 清理临时文件
    rm -f "$tmp_serve" "$tmp_routes"
}

# ==================== 高级功能 ====================

manage_cert() {
    print_header
    print_line
    echo -e "${BOLD}TLS 证书管理${NC}"
    print_line
    echo ""
    echo -e "  [1] ACME 自动申请证书 (需要域名)"
    echo -e "  [2] 手动上传证书"
    echo -e "  [3] 查看当前证书"
    echo -e "  [4] 删除证书"
    echo -e "  [0] 返回"
    echo ""
    print_line
    
    read -r -p "请选择 [0-4]: " cert_choice
    
    case $cert_choice in
        1) acme_cert ;;
        2) manual_cert ;;
        3) show_cert ;;
        4) delete_cert ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

acme_cert() {
    echo ""
    print_info "ACME 证书申请"
    echo ""
    
    # 安装依赖
    if [[ "$PM" == "apt-get" ]]; then
        apt-get install -y -qq socat curl > /dev/null 2>&1
    else
        yum install -y -q socat curl > /dev/null 2>&1
    fi
    
    # 安装 acme.sh
    if [[ ! -f "${HOME}/.acme.sh/acme.sh" ]]; then
        print_info "安装 acme.sh..."
        curl -s https://get.acme.sh | sh -s email=admin@example.com > /dev/null 2>&1
    fi
    
    read -r -p "请输入域名: " domain
    if [[ -z "$domain" ]]; then
        print_error "域名不能为空"
        return
    fi
    
    read -r -p "请输入邮箱 (用于证书通知): " email
    
    echo ""
    echo -e "请选择验证方式:"
    echo -e "  [1] HTTP 验证 (需要 80 端口可用)"
    echo -e "  [2] Cloudflare DNS 验证"
    echo ""
    read -r -p "请选择 [1-2]: " verify_method
    
    mkdir -p "$GOST_CERT_DIR"
    
    case $verify_method in
        1)
            print_info "使用 HTTP 验证申请证书..."
            print_warn "请确保 80 端口未被占用"
            
            if "${HOME}/.acme.sh/acme.sh" --issue -d "$domain" --standalone \
                --keylength ec-256 --force 2>/dev/null; then
                
                "${HOME}/.acme.sh/acme.sh" --installcert -d "$domain" \
                    --cert-file "${GOST_CERT_DIR}/cert.pem" \
                    --key-file "${GOST_CERT_DIR}/key.pem" \
                    --fullchain-file "${GOST_CERT_DIR}/fullchain.pem" \
                    --ecc --force 2>/dev/null
                
                print_success "证书申请成功!"
                echo -e "  证书目录: ${GOST_CERT_DIR}"
            else
                print_error "证书申请失败"
                return
            fi
            ;;
        2)
            read -r -p "请输入 Cloudflare API Key: " cf_key
            read -r -p "请输入 Cloudflare Email: " cf_email
            
            export CF_Key="$cf_key"
            export CF_Email="$cf_email"
            
            print_info "使用 Cloudflare DNS 验证申请证书..."
            
            if "${HOME}/.acme.sh/acme.sh" --issue -d "$domain" --dns dns_cf \
                --keylength ec-256 --force 2>/dev/null; then
                
                "${HOME}/.acme.sh/acme.sh" --installcert -d "$domain" \
                    --cert-file "${GOST_CERT_DIR}/cert.pem" \
                    --key-file "${GOST_CERT_DIR}/key.pem" \
                    --fullchain-file "${GOST_CERT_DIR}/fullchain.pem" \
                    --ecc --force 2>/dev/null
                
                print_success "证书申请成功!"
                echo -e "  证书目录: ${GOST_CERT_DIR}"
            else
                print_error "证书申请失败"
                return
            fi
            ;;
        *)
            print_error "无效选择"
            return
            ;;
    esac
    
    if [[ -f "${GOST_CERT_DIR}/cert.pem" ]]; then
        print_info "重启 GOST 以应用证书..."
        generate_config
        restart_gost
    fi
}

manual_cert() {
    echo ""
    print_info "手动上传证书"
    echo ""
    
    mkdir -p "$GOST_CERT_DIR"
    
    echo -e "请将证书文件上传到以下位置:"
    echo -e "  证书文件: ${GOST_CERT_DIR}/cert.pem"
    echo -e "  私钥文件: ${GOST_CERT_DIR}/key.pem"
    echo ""
    print_info "上传完成后，重启 GOST 即可生效"
}

show_cert() {
    echo ""
    if [[ -f "${GOST_CERT_DIR}/cert.pem" ]]; then
        print_info "当前证书信息:"
        openssl x509 -in "${GOST_CERT_DIR}/cert.pem" -noout -subject -dates 2>/dev/null || echo "无法读取证书信息"
    else
        print_warn "未配置自定义证书"
    fi
}

delete_cert() {
    if [[ -d "$GOST_CERT_DIR" ]]; then
        if confirm "确定要删除证书吗?"; then
            rm -rf "$GOST_CERT_DIR"
            print_success "证书已删除"
            generate_config
            restart_gost
        fi
    else
        print_warn "未配置自定义证书"
    fi
}

manage_cron() {
    print_header
    print_line
    echo -e "${BOLD}定时重启设置${NC}"
    print_line
    echo ""
    echo -e "  [1] 添加定时重启任务"
    echo -e "  [2] 查看当前定时任务"
    echo -e "  [3] 删除定时重启任务"
    echo -e "  [0] 返回"
    echo ""
    print_line
    
    read -r -p "请选择 [0-3]: " cron_choice
    
    case $cron_choice in
        1)
            echo ""
            echo -e "请选择重启周期:"
            echo -e "  [1] 每 N 小时重启"
            echo -e "  [2] 每天固定时间重启"
            echo ""
            read -r -p "请选择 [1-2]: " period_type
            
            case $period_type in
                1)
                    read -r -p "每几小时重启一次: " hours
                    if [[ "$hours" =~ ^[0-9]+$ ]] && [[ "$hours" -ge 1 ]] && [[ "$hours" -le 23 ]]; then
                        (crontab -l 2>/dev/null | grep -v "gost"; echo "0 */${hours} * * * systemctl restart gost") | crontab -
                        print_success "已设置每 ${hours} 小时重启"
                    else
                        print_error "无效的小时数"
                    fi
                    ;;
                2)
                    read -r -p "每天几点重启 (0-23): " hour
                    if [[ "$hour" =~ ^[0-9]+$ ]] && [[ "$hour" -ge 0 ]] && [[ "$hour" -le 23 ]]; then
                        (crontab -l 2>/dev/null | grep -v "gost"; echo "0 ${hour} * * * systemctl restart gost") | crontab -
                        print_success "已设置每天 ${hour}:00 重启"
                    else
                        print_error "无效的小时数"
                    fi
                    ;;
                *)
                    print_error "无效选择"
                    ;;
            esac
            ;;
        2)
            echo ""
            print_info "当前 GOST 相关定时任务:"
            crontab -l 2>/dev/null | grep "gost" || echo "无定时任务"
            ;;
        3)
            crontab -l 2>/dev/null | grep -v "gost" | crontab -
            print_success "定时重启任务已删除"
            ;;
        0)
            return
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

# ==================== 更新功能 ====================

update_gost() {
    print_header
    print_line
    echo -e "${BOLD}更新 GOST${NC}"
    print_line
    
    local installed_ver
    installed_ver=$(get_installed_version)
    
    if [[ -z "$installed_ver" ]]; then
        print_error "GOST 未安装"
        return
    fi
    
    echo ""
    print_info "当前版本: v${installed_ver}"
    print_info "正在检查最新版本..."
    
    local latest_ver
    latest_ver=$(get_latest_version)
    
    echo -e "最新版本: v${latest_ver}"
    echo ""
    
    if [[ "$installed_ver" == "$latest_ver" ]]; then
        print_success "已是最新版本"
        return
    fi
    
    if confirm "是否更新到 v${latest_ver}?"; then
        # 备份配置
        local backup_dir="/tmp/gost_backup_$(date +%Y%m%d%H%M%S)"
        cp -r "$GOST_CONFIG_DIR" "$backup_dir"
        print_info "配置已备份到: ${backup_dir}"
        
        # 停止服务
        systemctl stop gost
        
        # 下载新版本
        check_arch
        local use_mirror="n"
        if confirm "是否使用国内镜像加速?"; then
            use_mirror="y"
        fi
        
        if download_gost "$latest_ver" "$use_mirror"; then
            # 安装
            mv /tmp/gost "$GOST_INSTALL_PATH"
            chmod +x "$GOST_INSTALL_PATH"
            
            # 重启服务
            systemctl start gost
            
            print_success "更新完成! 当前版本: v${latest_ver}"
        else
            print_error "更新失败"
            # 恢复服务
            systemctl start gost
        fi
    fi
}

# ==================== 主菜单 ====================

show_menu() {
    print_header
    
    # 显示状态摘要
    local installed_ver
    installed_ver=$(get_installed_version)
    
    if [[ -n "$installed_ver" ]]; then
        echo -e "  当前版本: ${GREEN}v${installed_ver}${NC}"
        if systemctl is-active --quiet gost 2>/dev/null; then
            echo -e "  运行状态: ${GREEN}运行中${NC}"
        else
            echo -e "  运行状态: ${RED}已停止${NC}"
        fi
    else
        echo -e "  状态: ${YELLOW}未安装${NC}"
    fi
    
    print_line
    echo ""
    echo -e "  ${BOLD}安装管理${NC}"
    echo -e "    ${GREEN}[1]${NC} 安装 GOST"
    echo -e "    ${GREEN}[2]${NC} 更新 GOST"
    echo -e "    ${GREEN}[3]${NC} 卸载 GOST"
    echo ""
    echo -e "  ${BOLD}服务控制${NC}"
    echo -e "    ${GREEN}[4]${NC} 启动    ${GREEN}[5]${NC} 停止    ${GREEN}[6]${NC} 重启"
    echo -e "    ${GREEN}[7]${NC} 状态    ${GREEN}[8]${NC} 日志"
    echo ""
    echo -e "  ${BOLD}配置管理${NC}"
    echo -e "    ${GREEN}[9]${NC}  添加转发规则"
    echo -e "    ${GREEN}[10]${NC} 查看当前配置"
    echo -e "    ${GREEN}[11]${NC} 删除转发规则"
    echo ""
    echo -e "  ${BOLD}高级功能${NC}"
    echo -e "    ${GREEN}[12]${NC} TLS 证书管理"
    echo -e "    ${GREEN}[13]${NC} 定时重启设置"
    echo ""
    echo -e "    ${GREEN}[0]${NC}  退出"
    echo ""
    print_line
}

main() {
    check_root
    
    # 检测系统 (静默)
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        PM="yum"
    elif grep -qi "debian" /etc/os-release 2>/dev/null; then
        OS="debian"
        PM="apt-get"
    elif grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        OS="ubuntu"
        PM="apt-get"
    fi
    
    while true; do
        show_menu
        read -r -p "请选择 [0-13]: " choice
        
        case $choice in
            1) install_gost ;;
            2) update_gost ;;
            3) uninstall_gost ;;
            4) start_gost ;;
            5) stop_gost ;;
            6) restart_gost ;;
            7) status_gost ;;
            8) show_logs ;;
            9) add_config ;;
            10) show_config ;;
            11) delete_config ;;
            12) manage_cert ;;
            13) manage_cron ;;
            0)
                echo ""
                print_info "感谢使用，再见!"
                exit 0
                ;;
            *)
                print_error "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -r -p "按 Enter 键继续..."
    done
}

# 运行主程序
main "$@"
