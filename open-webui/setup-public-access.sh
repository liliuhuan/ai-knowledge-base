#!/bin/bash

# Open WebUI 公网访问配置脚本
# 自动配置反向代理和 SSL 证书

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Open WebUI 公网访问配置工具${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检测操作系统
OS="$(uname -s)"
case "$OS" in
    Linux*)     OS_TYPE="linux";;
    Darwin*)    OS_TYPE="macos";;
    *)          OS_TYPE="unknown";;
esac

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取公网 IP
get_public_ip() {
    curl -s ifconfig.me || curl -s ip.sb || curl -s icanhazip.com || echo "unknown"
}

# 获取内网 IP
get_local_ip() {
    if [ "$OS_TYPE" = "macos" ]; then
        ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo ""
    else
        hostname -I | awk '{print $1}' 2>/dev/null || echo ""
    fi
}

PUBLIC_IP=$(get_public_ip)
LOCAL_IP=$(get_local_ip)
WEBUI_PORT=8080

echo -e "${BLUE}检测到的网络信息:${NC}"
echo "  公网 IP: $PUBLIC_IP"
echo "  内网 IP: $LOCAL_IP"
echo "  服务端口: $WEBUI_PORT"
echo ""

# 选择配置方案
echo "请选择配置方案:"
echo "  1) 端口转发配置指南（手动配置路由器）"
echo "  2) Nginx 反向代理 + SSL（推荐）"
echo "  3) 查看当前配置状态"
echo ""
read -p "请选择 [1-3]: " choice

case $choice in
    1)
        echo ""
        log_info "端口转发配置指南"
        echo ""
        echo "请按照以下步骤配置路由器:"
        echo ""
        echo "1. 登录路由器管理界面"
        echo "   通常访问: http://192.168.1.1 或 http://192.168.0.1"
        echo ""
        echo "2. 找到端口转发设置"
        echo "   位置可能在: 高级设置 → NAT转发 → 端口转发"
        echo ""
        echo "3. 添加以下规则:"
        echo "   名称: Open WebUI"
        echo "   外部端口: $WEBUI_PORT (或使用其他端口如 8088)"
        echo "   内部 IP: $LOCAL_IP"
        echo "   内部端口: $WEBUI_PORT"
        echo "   协议: TCP"
        echo ""
        echo "4. 保存配置"
        echo ""
        echo "5. 从外网访问:"
        if [ "$PUBLIC_IP" != "unknown" ]; then
            echo -e "   ${GREEN}http://$PUBLIC_IP:$WEBUI_PORT${NC}"
        else
            echo "   http://YOUR_PUBLIC_IP:$WEBUI_PORT"
        fi
        echo ""
        log_warning "安全提示: 建议配置 SSL 证书或使用反向代理"
        ;;
    
    2)
        log_info "配置 Nginx 反向代理"
        echo ""
        
        # 检查 Nginx
        if ! command -v nginx &> /dev/null; then
            log_warning "Nginx 未安装，正在安装..."
            if [ "$OS_TYPE" = "macos" ]; then
                if command -v brew &> /dev/null; then
                    brew install nginx
                else
                    log_error "未找到 Homebrew，请先安装: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                    exit 1
                fi
            else
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update
                    sudo apt-get install -y nginx
                elif command -v yum &> /dev/null; then
                    sudo yum install -y nginx
                else
                    log_error "未找到包管理器，请手动安装 Nginx"
                    exit 1
                fi
            fi
            log_success "Nginx 安装完成"
        else
            log_success "Nginx 已安装"
        fi
        
        # 获取域名
        echo ""
        read -p "请输入您的域名（留空则使用 IP 访问）: " domain
        
        if [ -z "$domain" ]; then
            domain=$PUBLIC_IP
            log_warning "未提供域名，将使用 IP 地址"
            log_warning "注意: 使用 IP 无法配置 Let's Encrypt SSL 证书"
        fi
        
        # 确定 Nginx 配置路径
        if [ "$OS_TYPE" = "macos" ]; then
            NGINX_CONF_DIR="/opt/homebrew/etc/nginx/servers"
            NGINX_CONF_FILE="$NGINX_CONF_DIR/open-webui.conf"
        else
            NGINX_CONF_DIR="/etc/nginx/sites-available"
            NGINX_CONF_FILE="$NGINX_CONF_DIR/open-webui"
            NGINX_ENABLED="/etc/nginx/sites-enabled/open-webui"
        fi
        
        # 创建配置目录
        sudo mkdir -p "$NGINX_CONF_DIR"
        
        # 生成 Nginx 配置
        log_info "生成 Nginx 配置文件..."
        
        cat > /tmp/open-webui-nginx.conf <<EOF
server {
    listen 80;
    server_name $domain;

    access_log /var/log/nginx/open-webui-access.log;
    error_log /var/log/nginx/open-webui-error.log;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:$WEBUI_PORT;
        proxy_http_version 1.1;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF
        
        sudo cp /tmp/open-webui-nginx.conf "$NGINX_CONF_FILE"
        
        # Linux: 创建符号链接
        if [ "$OS_TYPE" = "linux" ] && [ -d "/etc/nginx/sites-enabled" ]; then
            sudo ln -sf "$NGINX_CONF_FILE" "$NGINX_ENABLED"
        fi
        
        log_success "Nginx 配置已创建: $NGINX_CONF_FILE"
        
        # 测试配置
        log_info "测试 Nginx 配置..."
        if sudo nginx -t; then
            log_success "Nginx 配置测试通过"
        else
            log_error "Nginx 配置测试失败"
            exit 1
        fi
        
        # 启动/重启 Nginx
        if [ "$OS_TYPE" = "macos" ]; then
            if brew services list | grep -q nginx; then
                brew services restart nginx
            else
                brew services start nginx
            fi
        else
            sudo systemctl enable nginx
            sudo systemctl restart nginx
        fi
        
        log_success "Nginx 已启动"
        
        # SSL 配置
        if [ "$domain" != "$PUBLIC_IP" ]; then
            echo ""
            read -p "是否配置 SSL 证书 (Let's Encrypt)? [y/N]: " ssl_choice
            if [[ $ssl_choice =~ ^[Yy]$ ]]; then
                log_info "配置 SSL 证书..."
                
                # 检查 certbot
                if ! command -v certbot &> /dev/null; then
                    log_warning "Certbot 未安装，正在安装..."
                    if [ "$OS_TYPE" = "macos" ]; then
                        brew install certbot
                    else
                        sudo apt-get install -y certbot python3-certbot-nginx || \
                        sudo yum install -y certbot python3-certbot-nginx
                    fi
                fi
                
                log_info "运行 Certbot..."
                log_warning "请确保域名 $domain 的 DNS 已解析到 $PUBLIC_IP"
                echo ""
                read -p "DNS 已配置完成? [y/N]: " dns_confirm
                
                if [[ $dns_confirm =~ ^[Yy]$ ]]; then
                    sudo certbot --nginx -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email || \
                    sudo certbot --nginx -d "$domain"
                    log_success "SSL 证书配置完成"
                    echo ""
                    echo -e "${GREEN}访问地址: https://$domain${NC}"
                else
                    log_warning "请先配置 DNS，然后运行: sudo certbot --nginx -d $domain"
                fi
            else
                log_info "跳过 SSL 配置"
                echo ""
                echo -e "${GREEN}HTTP 访问地址: http://$domain${NC}"
            fi
        else
            log_warning "使用 IP 地址无法配置 Let's Encrypt SSL"
            log_info "如需 HTTPS，可以使用自签名证书或 Cloudflare Tunnel"
        fi
        
        # 端口转发提示
        echo ""
        log_info "请确保路由器已配置端口转发:"
        echo "  外部端口: 80 (HTTP) 和 443 (HTTPS)"
        echo "  内部 IP: $LOCAL_IP"
        echo "  内部端口: 80"
        ;;
    
    3)
        log_info "检查当前配置状态..."
        echo ""
        
        # 检查服务
        if pgrep -f "open-webui serve" > /dev/null; then
            log_success "Open WebUI 服务正在运行"
        else
            log_warning "Open WebUI 服务未运行"
        fi
        
        # 检查端口
        if lsof -i :$WEBUI_PORT > /dev/null 2>&1; then
            log_success "端口 $WEBUI_PORT 正在监听"
        else
            log_warning "端口 $WEBUI_PORT 未监听"
        fi
        
        # 检查 Nginx
        if command -v nginx &> /dev/null; then
            log_success "Nginx 已安装"
            if [ "$OS_TYPE" = "macos" ]; then
                if brew services list | grep -q "nginx.*started"; then
                    log_success "Nginx 正在运行"
                else
                    log_warning "Nginx 未运行"
                fi
            else
                if systemctl is-active --quiet nginx; then
                    log_success "Nginx 正在运行"
                else
                    log_warning "Nginx 未运行"
                fi
            fi
        else
            log_warning "Nginx 未安装"
        fi
        
        echo ""
        echo "网络信息:"
        echo "  公网 IP: $PUBLIC_IP"
        echo "  内网 IP: $LOCAL_IP"
        echo "  服务端口: $WEBUI_PORT"
        echo ""
        echo "访问地址:"
        if [ "$PUBLIC_IP" != "unknown" ]; then
            echo "  局域网: http://$LOCAL_IP:$WEBUI_PORT"
            echo "  公网: http://$PUBLIC_IP:$WEBUI_PORT"
        fi
        ;;
    
    *)
        log_error "无效的选择"
        exit 1
        ;;
esac

echo ""
log_success "配置完成！"
echo ""
log_warning "安全提示:"
echo "  1. 使用强密码保护管理员账户"
echo "  2. 定期更新 Open WebUI"
echo "  3. 考虑启用防火墙规则"
echo "  4. 如果可能，限制特定 IP 访问"
echo ""

