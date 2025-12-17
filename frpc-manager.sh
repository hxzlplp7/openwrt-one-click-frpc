#!/bin/sh
# =========================================================
# OpenWrt/iStoreOS FRPC 一键管理脚本
# 用于反向代理到 FRPS 服务器
# Author: AI Assistant
# Version: 1.0.0
# =========================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 配置文件路径
FRPC_DIR="/etc/frpc"
FRPC_CONFIG="${FRPC_DIR}/frpc.toml"
FRPC_BIN="/usr/bin/frpc"
FRPC_SERVICE="/etc/init.d/frpc"
FRPC_LOG="/var/log/frpc.log"

# FRPC 版本
FRPC_VERSION="0.61.1"

# 显示 Logo
show_logo() {
    clear
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║                                                           ║"
    echo "  ║     ███████╗██████╗ ██████╗  ██████╗                      ║"
    echo "  ║     ██╔════╝██╔══██╗██╔══██╗██╔════╝                      ║"
    echo "  ║     █████╗  ██████╔╝██████╔╝██║                           ║"
    echo "  ║     ██╔══╝  ██╔══██╗██╔═══╝ ██║                           ║"
    echo "  ║     ██║     ██║  ██║██║     ╚██████╗                      ║"
    echo "  ║     ╚═╝     ╚═╝  ╚═╝╚═╝      ╚═════╝                      ║"
    echo "  ║                                                           ║"
    echo "  ║         OpenWrt/iStoreOS FRPC 一键管理脚本                ║"
    echo "  ║                   Version: 1.0.0                          ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 打印信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armv7)
            echo "arm"
            ;;
        mips)
            echo "mips"
            ;;
        mipsle|mipsel)
            echo "mipsle"
            ;;
        mips64)
            echo "mips64"
            ;;
        mips64le|mips64el)
            echo "mips64le"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 检查是否安装了 frpc
check_frpc_installed() {
    if [ -f "$FRPC_BIN" ]; then
        return 0
    else
        return 1
    fi
}

# 检查 frpc 运行状态
check_frpc_status() {
    # 兼容不同系统的检测方式
    if command -v pgrep > /dev/null 2>&1; then
        # 尝试使用 pgrep
        if pgrep -f "frpc" > /dev/null 2>&1; then
            return 0
        fi
    fi
    # 备用方案：使用 ps + grep
    if ps | grep -v grep | grep -q "frpc"; then
        return 0
    fi
    # 再次备用：检查 pidof
    if command -v pidof > /dev/null 2>&1; then
        if pidof frpc > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# 获取 frpc 版本
get_frpc_version() {
    if check_frpc_installed; then
        $FRPC_BIN -v 2>/dev/null | head -1
    else
        echo "未安装"
    fi
}

# 下载并安装 frpc
install_frpc() {
    local arch=$(detect_arch)
    
    if [ "$arch" = "unknown" ]; then
        print_error "不支持的系统架构: $(uname -m)"
        return 1
    fi
    
    print_info "检测到系统架构: $arch"
    print_info "正在下载 frpc v${FRPC_VERSION}..."
    
    local download_url="https://github.com/fatedier/frp/releases/download/v${FRPC_VERSION}/frp_${FRPC_VERSION}_linux_${arch}.tar.gz"
    local tmp_dir="/tmp/frpc_install"
    
    # 创建临时目录
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
    
    # 下载
    if command -v wget > /dev/null 2>&1; then
        wget -q --show-progress -O "${tmp_dir}/frpc.tar.gz" "$download_url"
    elif command -v curl > /dev/null 2>&1; then
        curl -fsSL -o "${tmp_dir}/frpc.tar.gz" "$download_url"
    else
        print_error "未找到 wget 或 curl，请先安装"
        return 1
    fi
    
    if [ $? -ne 0 ]; then
        print_error "下载失败，请检查网络连接"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # 解压
    print_info "正在解压..."
    cd "$tmp_dir"
    tar -xzf frpc.tar.gz
    
    if [ $? -ne 0 ]; then
        print_error "解压失败"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # 安装
    print_info "正在安装..."
    cp "frp_${FRPC_VERSION}_linux_${arch}/frpc" "$FRPC_BIN"
    chmod +x "$FRPC_BIN"
    
    # 创建配置目录
    mkdir -p "$FRPC_DIR"
    
    # 清理
    rm -rf "$tmp_dir"
    
    # 创建服务脚本
    create_service_script
    
    print_success "FRPC 安装成功!"
    print_info "版本: $(get_frpc_version)"
    
    return 0
}

# 创建 OpenWrt 服务脚本
create_service_script() {
    cat > "$FRPC_SERVICE" << 'EOF'
#!/bin/sh /etc/rc.common
# FRPC service script for OpenWrt/iStoreOS

START=99
STOP=10
USE_PROCD=1

FRPC_BIN="/usr/bin/frpc"
FRPC_CONFIG="/etc/frpc/frpc.toml"
FRPC_LOG="/var/log/frpc.log"

start_service() {
    if [ ! -f "$FRPC_CONFIG" ]; then
        echo "配置文件不存在: $FRPC_CONFIG"
        return 1
    fi
    
    procd_open_instance
    procd_set_param command "$FRPC_BIN" -c "$FRPC_CONFIG"
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param file "$FRPC_CONFIG"
    procd_close_instance
}

stop_service() {
    killall frpc 2>/dev/null
}

reload_service() {
    stop
    start
}

service_triggers() {
    procd_add_reload_trigger "frpc"
}
EOF
    chmod +x "$FRPC_SERVICE"
}

# 卸载 frpc
uninstall_frpc() {
    echo ""
    print_warning "确定要卸载 FRPC 吗？这将删除所有配置文件！"
    echo -n "请输入 [y/N]: "
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "已取消卸载"
        return 0
    fi
    
    # 停止服务
    if check_frpc_status; then
        print_info "正在停止 FRPC 服务..."
        $FRPC_SERVICE stop 2>/dev/null
        killall frpc 2>/dev/null
    fi
    
    # 禁用开机自启
    $FRPC_SERVICE disable 2>/dev/null
    
    # 删除文件
    rm -f "$FRPC_BIN"
    rm -f "$FRPC_SERVICE"
    rm -rf "$FRPC_DIR"
    rm -f "$FRPC_LOG"
    
    print_success "FRPC 已完全卸载!"
}

# 配置 FRPS 服务器连接
configure_server() {
    echo ""
    echo -e "${CYAN}========== 配置 FRPS 服务器连接 ==========${NC}"
    echo ""
    
    # 读取现有配置
    local current_server=""
    local current_port=""
    local current_token=""
    
    if [ -f "$FRPC_CONFIG" ]; then
        current_server=$(grep "serverAddr" "$FRPC_CONFIG" 2>/dev/null | cut -d'"' -f2)
        current_port=$(grep "serverPort" "$FRPC_CONFIG" 2>/dev/null | awk '{print $3}')
        current_token=$(grep "token" "$FRPC_CONFIG" 2>/dev/null | head -1 | cut -d'"' -f2)
    fi
    
    # 输入服务器地址
    while true; do
        if [ -n "$current_server" ] && [ "$current_server" != "0.0.0.0" ]; then
            echo -e "FRPS 服务器地址 [${GREEN}${current_server}${NC}]: \c"
        else
            echo -n "FRPS 服务器地址 (域名或IP): "
        fi
        read server_addr
        
        # 使用默认值
        if [ -z "$server_addr" ] && [ -n "$current_server" ] && [ "$current_server" != "0.0.0.0" ]; then
            server_addr="$current_server"
        fi
        
        # 验证地址
        if [ -z "$server_addr" ]; then
            print_error "服务器地址不能为空"
            continue
        fi
        
        # 检查无效地址
        case "$server_addr" in
            "0.0.0.0"|"127.0.0.1"|"localhost"|"")
                print_error "无效的服务器地址: $server_addr"
                print_info "请输入 FRPS 服务器的公网IP或域名"
                continue
                ;;
        esac
        
        break
    done
    
    # 输入服务器端口
    if [ -n "$current_port" ]; then
        echo -e "FRPS 服务器端口 [${GREEN}${current_port}${NC}]: \c"
    else
        echo -n "FRPS 服务器端口 [7000]: "
    fi
    read server_port
    [ -z "$server_port" ] && server_port="${current_port:-7000}"
    
    # 验证端口
    if ! echo "$server_port" | grep -qE '^[0-9]+$'; then
        print_error "无效的端口号"
        return 1
    fi
    
    # 输入认证令牌
    if [ -n "$current_token" ]; then
        echo -e "FRPS 认证令牌 [${GREEN}******${NC}]: \c"
    else
        echo -n "FRPS 认证令牌: "
    fi
    read auth_token
    [ -z "$auth_token" ] && auth_token="$current_token"
    
    if [ -z "$auth_token" ]; then
        print_warning "未设置认证令牌，如果FRPS服务器需要认证可能无法连接"
    fi
    
    # 输入日志级别
    echo -n "日志级别 [info/debug/warning/error] (默认: info): "
    read log_level
    [ -z "$log_level" ] && log_level="info"
    
    # 创建配置目录和日志文件
    mkdir -p "$FRPC_DIR"
    touch "$FRPC_LOG"
    
    # 保留现有的代理配置
    local proxies=""
    if [ -f "$FRPC_CONFIG" ]; then
        # 提取 [[proxies]] 部分
        proxies=$(awk '/^\[\[proxies\]\]/,0' "$FRPC_CONFIG")
    fi
    
    # 写入配置文件
    cat > "$FRPC_CONFIG" << EOF
# FRPC Configuration
# Auto-generated by frpc-manager

serverAddr = "${server_addr}"
serverPort = ${server_port}

# Auto retry on connection failure
loginFailExit = false

[auth]
method = "token"
token = "${auth_token}"

[log]
to = "${FRPC_LOG}"
level = "${log_level}"
maxDays = 7

# Transport settings
[transport]
heartbeatTimeout = 90
dialServerTimeout = 10
dialServerKeepAlive = 7200

[webServer]
addr = "0.0.0.0"
port = 7400
user = "admin"
password = "admin"

EOF
    
    # 追加代理配置
    if [ -n "$proxies" ]; then
        echo "$proxies" >> "$FRPC_CONFIG"
    fi
    
    print_success "服务器配置已保存!"
    echo ""
    echo -e "${CYAN}服务器: ${server_addr}:${server_port}${NC}"
    echo -e "${YELLOW}Web管理界面: http://路由器IP:7400${NC}"
    echo -e "${YELLOW}默认用户名: admin / 密码: admin${NC}"
    echo ""
    
    # 询问是否测试连接
    echo -n "是否测试连接到服务器? [Y/n]: "
    read test_conn
    if [ "$test_conn" != "n" ] && [ "$test_conn" != "N" ]; then
        print_info "正在测试连接..."
        # 使用 nc 或 timeout + echo 测试端口
        if command -v nc > /dev/null 2>&1; then
            if nc -z -w 3 "$server_addr" "$server_port" 2>/dev/null; then
                print_success "服务器 ${server_addr}:${server_port} 可达!"
            else
                print_warning "无法连接到 ${server_addr}:${server_port}"
                print_info "请检查: 1) 服务器地址是否正确 2) FRPS 是否运行 3) 防火墙是否开放端口"
            fi
        else
            print_info "跳过连接测试 (nc 命令不可用)"
        fi
    fi
}

# 添加代理规则
add_proxy() {
    echo ""
    echo -e "${CYAN}========== 添加代理规则 ==========${NC}"
    echo ""
    echo "请选择代理类型:"
    echo "  1. TCP 端口转发"
    echo "  2. UDP 端口转发"
    echo "  3. HTTP 网站代理"
    echo "  4. HTTPS 网站代理"
    echo "  5. SSH 隧道"
    echo "  6. STCP (安全TCP)"
    echo "  7. XTCP (P2P穿透)"
    echo "  0. 返回主菜单"
    echo ""
    echo -n "请选择 [0-7]: "
    read proxy_type
    
    case "$proxy_type" in
        1) add_tcp_proxy ;;
        2) add_udp_proxy ;;
        3) add_http_proxy ;;
        4) add_https_proxy ;;
        5) add_ssh_proxy ;;
        6) add_stcp_proxy ;;
        7) add_xtcp_proxy ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

# 添加 TCP 代理
add_tcp_proxy() {
    echo ""
    echo -e "${CYAN}=== 添加 TCP 端口转发 ===${NC}"
    echo ""
    
    echo -n "代理名称 (如: ssh, web): "
    read proxy_name
    [ -z "$proxy_name" ] && { print_error "名称不能为空"; return; }
    
    echo -n "本地IP地址 [127.0.0.1]: "
    read local_ip
    [ -z "$local_ip" ] && local_ip="127.0.0.1"
    
    echo -n "本地端口: "
    read local_port
    [ -z "$local_port" ] && { print_error "端口不能为空"; return; }
    
    echo -n "远程端口 (服务器端口): "
    read remote_port
    [ -z "$remote_port" ] && { print_error "端口不能为空"; return; }
    
    # 追加到配置文件
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "${proxy_name}"
type = "tcp"
localIP = "${local_ip}"
localPort = ${local_port}
remotePort = ${remote_port}
EOF
    
    print_success "TCP 代理 [${proxy_name}] 添加成功!"
    echo -e "${YELLOW}访问方式: 服务器IP:${remote_port} -> ${local_ip}:${local_port}${NC}"
    prompt_reload
}

# 添加 UDP 代理
add_udp_proxy() {
    echo ""
    echo -e "${CYAN}=== 添加 UDP 端口转发 ===${NC}"
    echo ""
    
    echo -n "代理名称: "
    read proxy_name
    [ -z "$proxy_name" ] && { print_error "名称不能为空"; return; }
    
    echo -n "本地IP地址 [127.0.0.1]: "
    read local_ip
    [ -z "$local_ip" ] && local_ip="127.0.0.1"
    
    echo -n "本地端口: "
    read local_port
    [ -z "$local_port" ] && { print_error "端口不能为空"; return; }
    
    echo -n "远程端口 (服务器端口): "
    read remote_port
    [ -z "$remote_port" ] && { print_error "端口不能为空"; return; }
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "${proxy_name}"
type = "udp"
localIP = "${local_ip}"
localPort = ${local_port}
remotePort = ${remote_port}
EOF
    
    print_success "UDP 代理 [${proxy_name}] 添加成功!"
    prompt_reload
}

# 添加 HTTP 代理
add_http_proxy() {
    echo ""
    echo -e "${CYAN}=== 添加 HTTP 网站代理 ===${NC}"
    echo ""
    
    echo -n "代理名称: "
    read proxy_name
    [ -z "$proxy_name" ] && { print_error "名称不能为空"; return; }
    
    echo -n "本地IP地址 [127.0.0.1]: "
    read local_ip
    [ -z "$local_ip" ] && local_ip="127.0.0.1"
    
    echo -n "本地端口 [80]: "
    read local_port
    [ -z "$local_port" ] && local_port="80"
    
    echo -n "自定义域名 (如: example.yourdomain.com): "
    read custom_domain
    
    echo -n "子域名 (如: web, 留空跳过): "
    read subdomain
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "${proxy_name}"
type = "http"
localIP = "${local_ip}"
localPort = ${local_port}
EOF
    
    [ -n "$custom_domain" ] && echo "customDomains = [\"${custom_domain}\"]" >> "$FRPC_CONFIG"
    [ -n "$subdomain" ] && echo "subdomain = \"${subdomain}\"" >> "$FRPC_CONFIG"
    
    print_success "HTTP 代理 [${proxy_name}] 添加成功!"
    prompt_reload
}

# 添加 HTTPS 代理
add_https_proxy() {
    echo ""
    echo -e "${CYAN}=== 添加 HTTPS 网站代理 ===${NC}"
    echo ""
    
    echo -n "代理名称: "
    read proxy_name
    [ -z "$proxy_name" ] && { print_error "名称不能为空"; return; }
    
    echo -n "本地IP地址 [127.0.0.1]: "
    read local_ip
    [ -z "$local_ip" ] && local_ip="127.0.0.1"
    
    echo -n "本地端口 [443]: "
    read local_port
    [ -z "$local_port" ] && local_port="443"
    
    echo -n "自定义域名: "
    read custom_domain
    [ -z "$custom_domain" ] && { print_error "域名不能为空"; return; }
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "${proxy_name}"
type = "https"
localIP = "${local_ip}"
localPort = ${local_port}
customDomains = ["${custom_domain}"]
EOF
    
    print_success "HTTPS 代理 [${proxy_name}] 添加成功!"
    prompt_reload
}

# 添加 SSH 代理
add_ssh_proxy() {
    echo ""
    echo -e "${CYAN}=== 添加 SSH 隧道 ===${NC}"
    echo ""
    
    echo -n "代理名称 [ssh]: "
    read proxy_name
    [ -z "$proxy_name" ] && proxy_name="ssh"
    
    echo -n "本地SSH端口 [22]: "
    read local_port
    [ -z "$local_port" ] && local_port="22"
    
    echo -n "远程端口: "
    read remote_port
    [ -z "$remote_port" ] && { print_error "端口不能为空"; return; }
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "${proxy_name}"
type = "tcp"
localIP = "127.0.0.1"
localPort = ${local_port}
remotePort = ${remote_port}
EOF
    
    print_success "SSH 隧道 [${proxy_name}] 添加成功!"
    echo -e "${YELLOW}SSH连接命令: ssh -p ${remote_port} user@服务器IP${NC}"
    prompt_reload
}

# 添加 STCP 代理
add_stcp_proxy() {
    echo ""
    echo -e "${CYAN}=== 添加 STCP (安全TCP) 代理 ===${NC}"
    echo ""
    
    echo -n "代理名称: "
    read proxy_name
    [ -z "$proxy_name" ] && { print_error "名称不能为空"; return; }
    
    echo -n "本地IP地址 [127.0.0.1]: "
    read local_ip
    [ -z "$local_ip" ] && local_ip="127.0.0.1"
    
    echo -n "本地端口: "
    read local_port
    [ -z "$local_port" ] && { print_error "端口不能为空"; return; }
    
    echo -n "访问密钥 (用于客户端连接): "
    read secret_key
    [ -z "$secret_key" ] && secret_key=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "${proxy_name}"
type = "stcp"
localIP = "${local_ip}"
localPort = ${local_port}
secretKey = "${secret_key}"
EOF
    
    print_success "STCP 代理 [${proxy_name}] 添加成功!"
    echo -e "${YELLOW}访问密钥: ${secret_key}${NC}"
    echo -e "${YELLOW}客户端需要使用此密钥连接${NC}"
    prompt_reload
}

# 添加 XTCP 代理
add_xtcp_proxy() {
    echo ""
    echo -e "${CYAN}=== 添加 XTCP (P2P穿透) 代理 ===${NC}"
    echo ""
    
    echo -n "代理名称: "
    read proxy_name
    [ -z "$proxy_name" ] && { print_error "名称不能为空"; return; }
    
    echo -n "本地IP地址 [127.0.0.1]: "
    read local_ip
    [ -z "$local_ip" ] && local_ip="127.0.0.1"
    
    echo -n "本地端口: "
    read local_port
    [ -z "$local_port" ] && { print_error "端口不能为空"; return; }
    
    echo -n "访问密钥: "
    read secret_key
    [ -z "$secret_key" ] && secret_key=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "${proxy_name}"
type = "xtcp"
localIP = "${local_ip}"
localPort = ${local_port}
secretKey = "${secret_key}"
EOF
    
    print_success "XTCP 代理 [${proxy_name}] 添加成功!"
    echo -e "${YELLOW}访问密钥: ${secret_key}${NC}"
    prompt_reload
}

# 查看代理规则
view_proxies() {
    echo ""
    echo -e "${CYAN}========== 当前代理规则 ==========${NC}"
    echo ""
    
    if [ ! -f "$FRPC_CONFIG" ]; then
        print_warning "配置文件不存在"
        return
    fi
    
    # 解析并显示代理规则
    local count=0
    local in_proxy=0
    local name="" type="" local_ip="" local_port="" remote_port="" domain=""
    
    while IFS= read -r line; do
        case "$line" in
            *"[[proxies]]"*)
                if [ $in_proxy -eq 1 ] && [ -n "$name" ]; then
                    count=$((count + 1))
                    printf "${GREEN}%2d.${NC} %-15s ${YELLOW}%-8s${NC} " "$count" "$name" "$type"
                    if [ -n "$remote_port" ]; then
                        printf "本地: ${CYAN}%s:%s${NC} -> 远程: ${PURPLE}%s${NC}" "$local_ip" "$local_port" "$remote_port"
                    elif [ -n "$domain" ]; then
                        printf "本地: ${CYAN}%s:%s${NC} -> 域名: ${PURPLE}%s${NC}" "$local_ip" "$local_port" "$domain"
                    else
                        printf "本地: ${CYAN}%s:%s${NC}" "$local_ip" "$local_port"
                    fi
                    echo ""
                fi
                in_proxy=1
                name="" type="" local_ip="" local_port="" remote_port="" domain=""
                ;;
            *"name ="*)
                name=$(echo "$line" | sed 's/.*= *"\([^"]*\)".*/\1/')
                ;;
            *"type ="*)
                type=$(echo "$line" | sed 's/.*= *"\([^"]*\)".*/\1/')
                ;;
            *"localIP ="*)
                local_ip=$(echo "$line" | sed 's/.*= *"\([^"]*\)".*/\1/')
                ;;
            *"localPort ="*)
                local_port=$(echo "$line" | sed 's/.*= *//' | tr -d ' ')
                ;;
            *"remotePort ="*)
                remote_port=$(echo "$line" | sed 's/.*= *//' | tr -d ' ')
                ;;
            *"customDomains ="*)
                domain=$(echo "$line" | sed 's/.*\["\([^"]*\)".*/\1/')
                ;;
        esac
    done < "$FRPC_CONFIG"
    
    # 输出最后一个代理
    if [ $in_proxy -eq 1 ] && [ -n "$name" ]; then
        count=$((count + 1))
        printf "${GREEN}%2d.${NC} %-15s ${YELLOW}%-8s${NC} " "$count" "$name" "$type"
        if [ -n "$remote_port" ]; then
            printf "本地: ${CYAN}%s:%s${NC} -> 远程: ${PURPLE}%s${NC}" "$local_ip" "$local_port" "$remote_port"
        elif [ -n "$domain" ]; then
            printf "本地: ${CYAN}%s:%s${NC} -> 域名: ${PURPLE}%s${NC}" "$local_ip" "$local_port" "$domain"
        else
            printf "本地: ${CYAN}%s:%s${NC}" "$local_ip" "$local_port"
        fi
        echo ""
    fi
    
    if [ $count -eq 0 ]; then
        print_warning "暂无代理规则"
    else
        echo ""
        echo -e "共 ${GREEN}${count}${NC} 条代理规则"
    fi
}

# 删除代理规则
delete_proxy() {
    echo ""
    view_proxies
    echo ""
    
    echo -n "请输入要删除的代理名称: "
    read proxy_name
    
    if [ -z "$proxy_name" ]; then
        print_error "名称不能为空"
        return
    fi
    
    # 检查代理是否存在
    if ! grep -q "name = \"${proxy_name}\"" "$FRPC_CONFIG" 2>/dev/null; then
        print_error "代理 [${proxy_name}] 不存在"
        return
    fi
    
    # 创建临时文件
    local tmp_file="/tmp/frpc_config_tmp"
    rm -f "$tmp_file"
    
    # 使用更简单的 awk 方法删除代理块
    # 思路：找到目标代理块（从 [[proxies]] 到下一个 [[proxies]] 或 EOF），删除它
    awk -v target="$proxy_name" '
    BEGIN { 
        skip = 0
        buffer = ""
        in_proxy_block = 0
    }
    
    # 遇到 [[proxies]]，开始收集代理块
    /^\[\[proxies\]\]/ {
        # 如果之前有缓冲区且不需要跳过，先输出
        if (buffer != "" && skip == 0) {
            printf "%s", buffer
        }
        # 重置状态，开始新块
        buffer = $0 "\n"
        in_proxy_block = 1
        skip = 0
        next
    }
    
    # 在代理块内
    in_proxy_block == 1 {
        # 检查是否是 name 行
        if (/^name = /) {
            # 检查是否是目标代理
            if (index($0, "\"" target "\"") > 0) {
                skip = 1  # 标记为跳过
            }
        }
        buffer = buffer $0 "\n"
        next
    }
    
    # 不在代理块内的内容直接输出
    {
        # 先输出之前的缓冲区（如果有且不需要跳过）
        if (buffer != "" && skip == 0) {
            printf "%s", buffer
            buffer = ""
        } else if (buffer != "" && skip == 1) {
            buffer = ""
            skip = 0
        }
        print
    }
    
    END {
        # 输出最后的缓冲区（如果有且不需要跳过）
        if (buffer != "" && skip == 0) {
            printf "%s", buffer
        }
    }
    ' "$FRPC_CONFIG" > "$tmp_file"
    
    # 验证临时文件
    if [ -s "$tmp_file" ]; then
        # 检查删除是否成功（通过比较行数或检查目标是否还存在）
        if grep -q "name = \"${proxy_name}\"" "$tmp_file" 2>/dev/null; then
            print_error "删除失败，请手动编辑配置文件"
            rm -f "$tmp_file"
            return
        fi
        mv "$tmp_file" "$FRPC_CONFIG"
        print_success "代理 [${proxy_name}] 已删除!"
    else
        print_error "删除失败，配置文件可能已损坏"
        rm -f "$tmp_file"
        return
    fi
    
    prompt_reload
}

# 提示重载配置
prompt_reload() {
    echo ""
    echo -n "是否立即重载配置? [Y/n]: "
    read confirm
    
    if [ "$confirm" != "n" ] && [ "$confirm" != "N" ]; then
        reload_frpc
    fi
}

# 启动 frpc
start_frpc() {
    if ! check_frpc_installed; then
        print_error "FRPC 未安装，请先安装"
        return 1
    fi
    
    if ! [ -f "$FRPC_CONFIG" ]; then
        print_error "配置文件不存在，请先配置服务器"
        return 1
    fi
    
    if check_frpc_status; then
        print_warning "FRPC 已在运行中"
        return 0
    fi
    
    print_info "正在启动 FRPC..."
    
    # 尝试使用服务脚本启动
    if [ -f "$FRPC_SERVICE" ]; then
        $FRPC_SERVICE start 2>/dev/null
    else
        # 直接启动
        nohup $FRPC_BIN -c "$FRPC_CONFIG" >> "$FRPC_LOG" 2>&1 &
    fi
    
    # 等待启动并检查多次
    local retry=0
    while [ $retry -lt 5 ]; do
        sleep 1
        if check_frpc_status; then
            print_success "FRPC 启动成功!"
            # 额外检查日志确认连接成功
            if [ -f "$FRPC_LOG" ]; then
                if tail -5 "$FRPC_LOG" 2>/dev/null | grep -q "login to server success"; then
                    print_info "已成功连接到 FRPS 服务器"
                fi
            fi
            return 0
        fi
        retry=$((retry + 1))
    done
    
    # 最后再检查一次日志
    if [ -f "$FRPC_LOG" ] && tail -10 "$FRPC_LOG" 2>/dev/null | grep -q "login to server success"; then
        print_success "FRPC 启动成功!"
        print_info "已成功连接到 FRPS 服务器"
        return 0
    fi
    
    print_error "FRPC 启动失败，请检查日志"
    print_info "使用菜单选项 15 查看详细日志"
}

# 停止 frpc
stop_frpc() {
    if ! check_frpc_status; then
        print_warning "FRPC 未在运行"
        return 0
    fi
    
    print_info "正在停止 FRPC..."
    
    # 方法1: 使用服务脚本停止
    if [ -f "$FRPC_SERVICE" ]; then
        $FRPC_SERVICE stop 2>/dev/null
    fi
    
    # 等待一下
    sleep 1
    
    # 方法2: 使用 killall
    if check_frpc_status; then
        killall frpc 2>/dev/null
        sleep 1
    fi
    
    # 方法3: 使用 pkill
    if check_frpc_status; then
        if command -v pkill > /dev/null 2>&1; then
            pkill -f "frpc" 2>/dev/null
            sleep 1
        fi
    fi
    
    # 方法4: 强制终止 (kill -9)
    if check_frpc_status; then
        print_info "尝试强制终止..."
        # 获取 PID 并强制终止
        local pids=""
        if command -v pgrep > /dev/null 2>&1; then
            pids=$(pgrep -f "frpc" 2>/dev/null)
        else
            pids=$(ps | grep "frpc" | grep -v grep | awk '{print $1}')
        fi
        
        for pid in $pids; do
            kill -9 "$pid" 2>/dev/null
        done
        sleep 1
    fi
    
    # 最终检查
    if ! check_frpc_status; then
        print_success "FRPC 已停止"
        return 0
    else
        print_error "停止失败，请手动终止进程"
        # 显示进程信息
        ps | grep frpc | grep -v grep
        return 1
    fi
}

# 重启 frpc
restart_frpc() {
    print_info "正在重启 FRPC..."
    
    # 先尝试停止（忽略返回值）
    if check_frpc_status; then
        stop_frpc
        sleep 2
    fi
    
    # 确保没有残留进程
    killall frpc 2>/dev/null
    sleep 1
    
    # 启动
    start_frpc
}

# 重载配置
reload_frpc() {
    if ! check_frpc_status; then
        print_warning "FRPC 未运行，正在启动..."
        start_frpc
        return
    fi
    
    print_info "正在重载配置..."
    
    # 验证配置文件
    if ! $FRPC_BIN verify -c "$FRPC_CONFIG" 2>/dev/null; then
        print_error "配置文件有误，请检查"
        return 1
    fi
    
    $FRPC_SERVICE reload 2>/dev/null || restart_frpc
    
    print_success "配置已重载"
}

# 查看状态
show_status() {
    echo ""
    echo -e "${CYAN}========== FRPC 运行状态 ==========${NC}"
    echo ""
    
    # 安装状态
    echo -n "安装状态: "
    if check_frpc_installed; then
        echo -e "${GREEN}已安装${NC}"
        echo -e "版本信息: ${CYAN}$(get_frpc_version)${NC}"
    else
        echo -e "${RED}未安装${NC}"
        return
    fi
    
    # 运行状态
    echo -n "运行状态: "
    if check_frpc_status; then
        echo -e "${GREEN}运行中${NC}"
        local pid=$(pgrep -x frpc)
        echo -e "进程 PID: ${CYAN}${pid}${NC}"
        
        # 内存使用
        if [ -n "$pid" ]; then
            local mem=$(cat /proc/$pid/status 2>/dev/null | grep VmRSS | awk '{print $2}')
            [ -n "$mem" ] && echo -e "内存使用: ${CYAN}${mem} KB${NC}"
        fi
    else
        echo -e "${RED}未运行${NC}"
    fi
    
    # 配置信息
    echo ""
    if [ -f "$FRPC_CONFIG" ]; then
        local server=$(grep "serverAddr" "$FRPC_CONFIG" | cut -d'"' -f2)
        local port=$(grep "serverPort" "$FRPC_CONFIG" | awk '{print $3}')
        echo -e "服务器地址: ${CYAN}${server}:${port}${NC}"
    fi
    
    # 开机自启状态
    echo -n "开机自启: "
    if [ -f /etc/rc.d/S99frpc ] || ls /etc/rc.d/S*frpc >/dev/null 2>&1; then
        echo -e "${GREEN}已启用${NC}"
    else
        echo -e "${YELLOW}未启用${NC}"
    fi
    
    # 显示代理数量
    if [ -f "$FRPC_CONFIG" ]; then
        local proxy_count=$(grep -c "\[\[proxies\]\]" "$FRPC_CONFIG")
        echo -e "代理规则: ${CYAN}${proxy_count} 条${NC}"
    fi
}

# 查看日志
view_log() {
    echo ""
    echo -e "${CYAN}========== FRPC 运行日志 ==========${NC}"
    echo ""
    
    if [ -f "$FRPC_LOG" ]; then
        echo -e "${YELLOW}显示最后 50 行日志:${NC}"
        echo ""
        tail -50 "$FRPC_LOG"
    else
        print_warning "日志文件不存在"
        
        # 尝试从 logread 获取
        echo ""
        echo -e "${YELLOW}从系统日志中获取:${NC}"
        logread 2>/dev/null | grep -i frpc | tail -30
    fi
}

# 清空日志
clear_log() {
    if [ -f "$FRPC_LOG" ]; then
        > "$FRPC_LOG"
        print_success "日志已清空"
    else
        print_warning "日志文件不存在"
    fi
}

# 启用开机自启
enable_autostart() {
    if [ -f "$FRPC_SERVICE" ]; then
        $FRPC_SERVICE enable
        print_success "已启用开机自启"
    else
        print_error "服务脚本不存在"
    fi
}

# 禁用开机自启
disable_autostart() {
    if [ -f "$FRPC_SERVICE" ]; then
        $FRPC_SERVICE disable
        print_success "已禁用开机自启"
    else
        print_error "服务脚本不存在"
    fi
}

# 编辑配置文件
edit_config() {
    if [ ! -f "$FRPC_CONFIG" ]; then
        print_warning "配置文件不存在，创建新配置..."
        configure_server
        return
    fi
    
    # 检查可用的编辑器
    if command -v nano > /dev/null 2>&1; then
        nano "$FRPC_CONFIG"
    elif command -v vi > /dev/null 2>&1; then
        vi "$FRPC_CONFIG"
    else
        print_error "未找到可用的编辑器"
        echo ""
        echo "配置文件路径: $FRPC_CONFIG"
        echo ""
        cat "$FRPC_CONFIG"
    fi
}

# 快速部署菜单
quick_deploy() {
    echo ""
    echo -e "${CYAN}========== 快速部署 ==========${NC}"
    echo ""
    echo "常用代理模板:"
    echo "  1. 路由器Web管理界面 (HTTP)"
    echo "  2. 路由器SSH访问"
    echo "  3. 内网设备远程桌面 (RDP)"
    echo "  4. NAS/文件服务器"
    echo "  5. 摄像头/监控"
    echo "  6. 自定义TCP端口"
    echo "  0. 返回主菜单"
    echo ""
    echo -n "请选择 [0-6]: "
    read choice
    
    case "$choice" in
        1) quick_deploy_http ;;
        2) quick_deploy_ssh ;;
        3) quick_deploy_rdp ;;
        4) quick_deploy_nas ;;
        5) quick_deploy_camera ;;
        6) add_tcp_proxy ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

quick_deploy_http() {
    echo ""
    echo -e "${CYAN}=== 路由器Web管理界面 ===${NC}"
    echo ""
    
    echo -n "远程访问端口 [8080]: "
    read remote_port
    [ -z "$remote_port" ] && remote_port="8080"
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "router-web"
type = "tcp"
localIP = "127.0.0.1"
localPort = 80
remotePort = ${remote_port}
EOF
    
    print_success "路由器Web管理代理已添加!"
    echo -e "${YELLOW}访问地址: http://服务器IP:${remote_port}${NC}"
    prompt_reload
}

quick_deploy_ssh() {
    echo ""
    echo -e "${CYAN}=== 路由器SSH访问 ===${NC}"
    echo ""
    
    echo -n "远程SSH端口 [2222]: "
    read remote_port
    [ -z "$remote_port" ] && remote_port="2222"
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "router-ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = ${remote_port}
EOF
    
    print_success "SSH访问代理已添加!"
    echo -e "${YELLOW}连接命令: ssh -p ${remote_port} root@服务器IP${NC}"
    prompt_reload
}

quick_deploy_rdp() {
    echo ""
    echo -e "${CYAN}=== 远程桌面 (RDP) ===${NC}"
    echo ""
    
    echo -n "内网电脑IP: "
    read local_ip
    [ -z "$local_ip" ] && { print_error "IP不能为空"; return; }
    
    echo -n "远程访问端口 [3389]: "
    read remote_port
    [ -z "$remote_port" ] && remote_port="3389"
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "rdp-${local_ip##*.}"
type = "tcp"
localIP = "${local_ip}"
localPort = 3389
remotePort = ${remote_port}
EOF
    
    print_success "远程桌面代理已添加!"
    echo -e "${YELLOW}连接地址: 服务器IP:${remote_port}${NC}"
    prompt_reload
}

quick_deploy_nas() {
    echo ""
    echo -e "${CYAN}=== NAS/文件服务器 ===${NC}"
    echo ""
    
    echo -n "NAS IP地址: "
    read local_ip
    [ -z "$local_ip" ] && { print_error "IP不能为空"; return; }
    
    echo -n "NAS Web端口 [5000]: "
    read local_port
    [ -z "$local_port" ] && local_port="5000"
    
    echo -n "远程访问端口 [5000]: "
    read remote_port
    [ -z "$remote_port" ] && remote_port="5000"
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "nas-web"
type = "tcp"
localIP = "${local_ip}"
localPort = ${local_port}
remotePort = ${remote_port}
EOF
    
    print_success "NAS代理已添加!"
    echo -e "${YELLOW}访问地址: http://服务器IP:${remote_port}${NC}"
    prompt_reload
}

quick_deploy_camera() {
    echo ""
    echo -e "${CYAN}=== 摄像头/监控 ===${NC}"
    echo ""
    
    echo -n "摄像头IP地址: "
    read local_ip
    [ -z "$local_ip" ] && { print_error "IP不能为空"; return; }
    
    echo -n "摄像头Web端口 [80]: "
    read local_port
    [ -z "$local_port" ] && local_port="80"
    
    echo -n "远程访问端口: "
    read remote_port
    [ -z "$remote_port" ] && { print_error "端口不能为空"; return; }
    
    cat >> "$FRPC_CONFIG" << EOF

[[proxies]]
name = "camera-${local_ip##*.}"
type = "tcp"
localIP = "${local_ip}"
localPort = ${local_port}
remotePort = ${remote_port}
EOF
    
    print_success "摄像头代理已添加!"
    echo -e "${YELLOW}访问地址: http://服务器IP:${remote_port}${NC}"
    prompt_reload
}

# 显示帮助
show_help() {
    echo ""
    echo -e "${CYAN}========== 使用帮助 ==========${NC}"
    echo ""
    echo "命令行参数:"
    echo "  $0                    # 进入交互式菜单"
    echo "  $0 start              # 启动 FRPC"
    echo "  $0 stop               # 停止 FRPC"
    echo "  $0 restart            # 重启 FRPC"
    echo "  $0 reload             # 重载配置"
    echo "  $0 status             # 查看状态"
    echo "  $0 log                # 查看日志"
    echo "  $0 install            # 安装 FRPC"
    echo "  $0 uninstall          # 卸载 FRPC"
    echo ""
    echo "配置文件: $FRPC_CONFIG"
    echo "日志文件: $FRPC_LOG"
    echo ""
}

# 主菜单
main_menu() {
    while true; do
        show_logo
        
        # 显示状态概览
        echo -n "  状态: "
        if check_frpc_installed; then
            echo -n -e "${GREEN}已安装${NC}"
            if check_frpc_status; then
                echo -e " | ${GREEN}运行中${NC}"
            else
                echo -e " | ${RED}未运行${NC}"
            fi
        else
            echo -e "${RED}未安装${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}==================== 主菜单 ====================${NC}"
        echo ""
        echo "  安装管理:"
        echo "    1. 安装 FRPC"
        echo "    2. 卸载 FRPC"
        echo "    3. 更新 FRPC"
        echo ""
        echo "  服务器配置:"
        echo "    4. 配置 FRPS 服务器连接"
        echo "    5. 编辑配置文件"
        echo ""
        echo "  代理管理:"
        echo "    6. 添加代理规则"
        echo "    7. 查看代理规则"
        echo "    8. 删除代理规则"
        echo "    9. 快速部署"
        echo ""
        echo "  服务控制:"
        echo "    10. 启动 FRPC"
        echo "    11. 停止 FRPC"
        echo "    12. 重启 FRPC"
        echo "    13. 重载配置"
        echo ""
        echo "  其他功能:"
        echo "    14. 查看运行状态"
        echo "    15. 查看日志"
        echo "    16. 清空日志"
        echo "    17. 启用开机自启"
        echo "    18. 禁用开机自启"
        echo ""
        echo "    0. 退出"
        echo ""
        echo -e "${CYAN}=================================================${NC}"
        echo ""
        echo -n "请选择 [0-18]: "
        read choice
        
        case "$choice" in
            1) install_frpc ;;
            2) uninstall_frpc ;;
            3) install_frpc ;;
            4) configure_server ;;
            5) edit_config ;;
            6) add_proxy ;;
            7) view_proxies ;;
            8) delete_proxy ;;
            9) quick_deploy ;;
            10) start_frpc ;;
            11) stop_frpc ;;
            12) restart_frpc ;;
            13) reload_frpc ;;
            14) show_status ;;
            15) view_log ;;
            16) clear_log ;;
            17) enable_autostart ;;
            18) disable_autostart ;;
            0) echo ""; print_info "再见!"; exit 0 ;;
            *) print_error "无效选择" ;;
        esac
        
        echo ""
        echo -n "按 Enter 键继续..."
        read dummy
    done
}

# 命令行参数处理
case "$1" in
    start)
        start_frpc
        ;;
    stop)
        stop_frpc
        ;;
    restart)
        restart_frpc
        ;;
    reload)
        reload_frpc
        ;;
    status)
        show_status
        ;;
    log)
        view_log
        ;;
    install)
        install_frpc
        ;;
    uninstall)
        uninstall_frpc
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        main_menu
        ;;
    *)
        print_error "未知命令: $1"
        show_help
        exit 1
        ;;
esac
