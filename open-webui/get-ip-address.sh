#!/bin/bash

# 获取本机 IP 地址脚本
# 用于帮助用户找到可以从其他设备访问的 IP 地址

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}查找本机 IP 地址${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检测操作系统
OS="$(uname -s)"
case "$OS" in
    Linux*)     OS_TYPE="linux";;
    Darwin*)    OS_TYPE="macos";;
    *)          OS_TYPE="unknown";;
esac

get_ip_macos() {
    # macOS 方法
    local ip=""
    
    # 尝试获取 Wi-Fi IP
    if command -v ipconfig &> /dev/null; then
        ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
    fi
    
    # 如果失败，使用 ifconfig
    if [ -z "$ip" ]; then
        ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    fi
    
    echo "$ip"
}

get_ip_linux() {
    # Linux 方法
    local ip=""
    
    # 方法 1: hostname -I
    if command -v hostname &> /dev/null; then
        ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")
    fi
    
    # 方法 2: ip 命令
    if [ -z "$ip" ] && command -v ip &> /dev/null; then
        ip=$(ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d'/' -f1 | head -1)
    fi
    
    # 方法 3: ifconfig
    if [ -z "$ip" ] && command -v ifconfig &> /dev/null; then
        ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    fi
    
    echo "$ip"
}

# 获取所有 IP 地址
get_all_ips() {
    if [ "$OS_TYPE" = "macos" ]; then
        ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
    elif [ "$OS_TYPE" = "linux" ]; then
        hostname -I 2>/dev/null || ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d'/' -f1
    fi
}

# 获取主 IP 地址
if [ "$OS_TYPE" = "macos" ]; then
    MAIN_IP=$(get_ip_macos)
elif [ "$OS_TYPE" = "linux" ]; then
    MAIN_IP=$(get_ip_linux)
else
    echo -e "${YELLOW}不支持的操作系统: $OS${NC}"
    echo "请手动查找 IP 地址"
    exit 1
fi

# 显示结果
if [ -n "$MAIN_IP" ]; then
    echo -e "${GREEN}✓ 找到 IP 地址${NC}"
    echo ""
    echo -e "${BLUE}主要 IP 地址 (推荐使用):${NC}"
    echo -e "  ${GREEN}$MAIN_IP${NC}"
    echo ""
    
    # 显示访问地址
    PORT=$(grep -E "^DEFAULT_PORT=" start-openwebui.sh 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "8080")
    echo -e "${BLUE}访问地址:${NC}"
    echo -e "  ${GREEN}http://$MAIN_IP:$PORT${NC}"
    echo ""
    
    # 显示所有 IP 地址
    echo -e "${BLUE}所有可用的 IP 地址:${NC}"
    ALL_IPS=$(get_all_ips)
    if [ -n "$ALL_IPS" ]; then
        echo "$ALL_IPS" | while read ip; do
            if [ -n "$ip" ]; then
                echo -e "  • ${GREEN}$ip${NC} → http://$ip:$PORT"
            fi
        done
    else
        echo -e "  ${YELLOW}无法获取其他 IP 地址${NC}"
    fi
else
    echo -e "${RED}✗ 无法找到 IP 地址${NC}"
    echo ""
    echo "请手动查找："
    if [ "$OS_TYPE" = "macos" ]; then
        echo "  ipconfig getifaddr en0"
        echo "  或"
        echo "  ifconfig | grep 'inet '"
    else
        echo "  hostname -I"
        echo "  或"
        echo "  ip addr show"
    fi
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}使用说明${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "1. 确保 Open WebUI 正在运行:"
echo -e "   ${YELLOW}./start-openwebui.sh${NC}"
echo ""
echo "2. 从手机或其他设备访问:"
echo -e "   ${GREEN}http://$MAIN_IP:$PORT${NC}"
echo ""
echo "3. 确保设备连接到相同的 Wi-Fi/网络"
echo ""
echo -e "${YELLOW}提示:${NC} 如果是首次访问，需要先创建管理员账户"
echo ""

