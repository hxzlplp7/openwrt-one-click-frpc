#!/bin/sh
# =========================================================
# OpenWrt/iStoreOS FRPC 一键安装脚本
# 快速安装 FRPC 管理脚本到系统
# =========================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
SCRIPT_URL="https://raw.githubusercontent.com/hxzlplp7/openwrt-one-click-frpc/main/frpc-manager.sh"
INSTALL_PATH="/usr/bin/frpc-manager"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       OpenWrt/iStoreOS FRPC 一键安装脚本          ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# 检测系统
echo -e "${YELLOW}[*] 检测系统环境...${NC}"
if [ -f /etc/openwrt_release ]; then
    . /etc/openwrt_release
    echo -e "${GREEN}[✓] 检测到 OpenWrt 系统${NC}"
    echo "    版本: $DISTRIB_DESCRIPTION"
elif [ -f /etc/istoreos-release ]; then
    echo -e "${GREEN}[✓] 检测到 iStoreOS 系统${NC}"
else
    echo -e "${YELLOW}[!] 未检测到 OpenWrt/iStoreOS 系统${NC}"
    echo "    脚本可能无法正常工作"
    echo -n "    是否继续安装? [y/N]: "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${RED}[!] 安装已取消${NC}"
        exit 1
    fi
fi

# 检测架构
arch=$(uname -m)
echo -e "${GREEN}[✓] 系统架构: $arch${NC}"

# 检测下载工具
echo -e "${YELLOW}[*] 检测下载工具...${NC}"
if command -v curl > /dev/null 2>&1; then
    DOWNLOADER="curl"
    echo -e "${GREEN}[✓] 找到 curl${NC}"
elif command -v wget > /dev/null 2>&1; then
    DOWNLOADER="wget"
    echo -e "${GREEN}[✓] 找到 wget${NC}"
else
    echo -e "${RED}[✗] 未找到 curl 或 wget${NC}"
    echo "    请先安装: opkg update && opkg install wget"
    exit 1
fi

# 下载脚本
echo ""
echo -e "${YELLOW}[*] 正在下载管理脚本...${NC}"

# 如果本地有脚本文件则优先使用
if [ -f "$(dirname $0)/frpc-manager.sh" ]; then
    echo -e "${GREEN}[✓] 使用本地脚本文件${NC}"
    cp "$(dirname $0)/frpc-manager.sh" "$INSTALL_PATH"
else
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -fsSL -o "$INSTALL_PATH" "$SCRIPT_URL"
    else
        wget -q -O "$INSTALL_PATH" "$SCRIPT_URL"
    fi
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}[✗] 下载失败${NC}"
    exit 1
fi

# 设置权限
chmod +x "$INSTALL_PATH"
echo -e "${GREEN}[✓] 脚本已安装到: $INSTALL_PATH${NC}"

# 创建快捷命令
if [ ! -L /usr/bin/frpc ]; then
    # 避免与 frpc 二进制文件冲突
    :
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              安装完成!                            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo "使用方法:"
echo "  frpc-manager          # 进入交互式菜单"
echo "  frpc-manager start    # 启动 FRPC"
echo "  frpc-manager stop     # 停止 FRPC"
echo "  frpc-manager status   # 查看状态"
echo "  frpc-manager help     # 显示帮助"
echo ""
echo -e "${CYAN}运行 'frpc-manager' 开始配置${NC}"
echo ""

# 询问是否立即运行
echo -n "是否立即运行管理脚本? [Y/n]: "
read run_now

if [ "$run_now" != "n" ] && [ "$run_now" != "N" ]; then
    exec "$INSTALL_PATH"
fi
