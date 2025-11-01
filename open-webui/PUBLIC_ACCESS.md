# Open WebUI 公网访问配置指南

## 🌐 当前网络信息

- **公网 IP**: 61.149.89.99
- **内网 IP**: 192.168.1.100（从之前的配置）
- **服务端口**: 8080

## ⚠️ 安全提醒

**重要**: 将服务暴露到公网需要采取适当的安全措施：

1. ✅ **使用强密码** - 确保管理员账户使用强密码
2. ✅ **启用 HTTPS** - 强烈建议配置 SSL 证书
3. ✅ **限制访问** - 如果可能，限制特定 IP 访问
4. ✅ **定期更新** - 保持 Open WebUI 最新版本
5. ✅ **启用防火墙** - 只开放必要的端口

## 📋 配置步骤

### 方案一：直接端口转发（快速，但不够安全）

适合临时使用或测试。

#### 1. 配置路由器端口转发

1. **登录路由器管理界面**
   - 通常在浏览器访问：`http://192.168.1.1` 或 `http://192.168.0.1`
   - 查看路由器标签上的默认网关地址

2. **找到端口转发设置**
   - 可能在：高级设置 → NAT转发 → 端口转发
   - 或：防火墙 → 端口转发
   - 不同路由器界面可能不同

3. **添加端口转发规则**
   ```
   名称: Open WebUI
   外部端口: 8080 (或使用其他端口，如 8088)
   内部 IP: 192.168.1.100
   内部端口: 8080
   协议: TCP
   启用: ✓
   ```

4. **保存并重启路由器**

#### 2. 测试访问

从手机移动网络或外网电脑访问：
```
http://61.149.89.99:8080
```

### 方案二：使用反向代理 + HTTPS（推荐）

使用 Nginx 作为反向代理，并配置 SSL 证书（Let's Encrypt）。

#### 前提条件

- 有一个域名（可选，但强烈推荐）
- 服务器有 root 或 sudo 权限
- 域名 DNS 已解析到您的公网 IP

#### 安装和配置 Nginx

**macOS**:
```bash
brew install nginx
```

**Linux (Ubuntu/Debian)**:
```bash
sudo apt-get update
sudo apt-get install -y nginx
```

**Linux (CentOS/RHEL)**:
```bash
sudo yum install -y nginx
```

#### 配置 Nginx 反向代理

创建配置文件 `/etc/nginx/sites-available/open-webui` (Linux) 或 `/opt/homebrew/etc/nginx/servers/open-webui` (macOS):

```nginx
server {
    listen 80;
    server_name your-domain.com;  # 替换为您的域名或使用 IP

    # 如果需要访问日志
    access_log /var/log/nginx/open-webui-access.log;
    error_log /var/log/nginx/open-webui-error.log;

    # 客户端最大上传大小
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        
        # WebSocket 支持
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 传递真实 IP
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时设置
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
```

**启用配置**:

Linux:
```bash
sudo ln -s /etc/nginx/sites-available/open-webui /etc/nginx/sites-enabled/
sudo nginx -t  # 测试配置
sudo systemctl restart nginx
```

macOS:
```bash
sudo nginx -t  # 测试配置
sudo nginx -s reload
```

#### 配置 SSL 证书（Let's Encrypt）

**安装 Certbot**:

macOS:
```bash
brew install certbot
```

Linux:
```bash
sudo apt-get install -y certbot python3-certbot-nginx
# 或
sudo yum install -y certbot python3-certbot-nginx
```

**获取证书**（需要域名）:

```bash
sudo certbot --nginx -d your-domain.com
```

Certbot 会自动配置 HTTPS。

**如果没有域名，可以使用自签名证书**（浏览器会显示警告）:

```bash
# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/open-webui.key \
    -out /etc/ssl/certs/open-webui.crt
```

然后修改 Nginx 配置添加 SSL：

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/ssl/certs/open-webui.crt;
    ssl_certificate_key /etc/ssl/private/open-webui.key;

    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # ... 其他配置同上 ...
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

### 方案三：使用 Cloudflare Tunnel（最简单，推荐）

Cloudflare Tunnel 不需要端口转发，通过 Cloudflare 的网络提供服务。

1. **注册 Cloudflare 账户**（免费）
2. **添加域名到 Cloudflare**
3. **安装 cloudflared**:

macOS:
```bash
brew install cloudflared
```

Linux:
```bash
# 下载安装
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

4. **登录并创建隧道**:
```bash
cloudflared tunnel login
cloudflared tunnel create open-webui
```

5. **配置隧道**:
创建 `~/.cloudflared/config.yml`:
```yaml
tunnel: <tunnel-id>
credentials-file: /Users/your-username/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: your-domain.com
    service: http://localhost:8080
  - service: http_status:404
```

6. **运行隧道**:
```bash
cloudflared tunnel run open-webui
```

7. **配置为系统服务**（可选，开机自启）:
```bash
sudo cloudflared service install
```

## 🔄 动态 DNS 配置（如果 IP 会变化）

如果您的公网 IP 会变化，需要配置动态 DNS。

### 使用 DuckDNS（免费）

1. **注册账户**: https://www.duckdns.org/
2. **创建域名**: 例如 `my-webui.duckdns.org`
3. **安装更新脚本**:

macOS:
```bash
brew install curl
```

4. **创建更新脚本** `/usr/local/bin/update-duckdns.sh`:
```bash
#!/bin/bash
DOMAIN="your-domain"
TOKEN="your-token"
URL="https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip="
curl "$URL"
```

5. **添加到 crontab**（每 5 分钟更新一次）:
```bash
crontab -e
# 添加：
*/5 * * * * /usr/local/bin/update-duckdns.sh
```

### 使用 No-IP（免费）

1. **注册**: https://www.noip.com/
2. **创建主机名**
3. **下载动态更新客户端**:
```bash
# macOS
brew install no-ip
```

## 🔐 安全加固建议

### 1. 启用访问控制

在 Open WebUI 设置中：
- 禁用公开注册（如果不需要）
- 设置强密码策略
- 启用双因素认证（如果支持）

### 2. 防火墙配置

**macOS**:
```bash
# 只允许特定 IP 访问（如果有固定 IP）
sudo ipfw add allow tcp from YOUR_IP to any 8080
```

**Linux (UFW)**:
```bash
# 只允许特定 IP
sudo ufw allow from YOUR_IP to any port 8080

# 或允许所有（不推荐）
sudo ufw allow 8080/tcp
```

### 3. 使用非标准端口

使用非常见端口可以避免自动扫描：

```bash
PORT=8888 ./start-openwebui.sh
```

### 4. 定期更新

```bash
pip install --upgrade open-webui
```

## 🧪 测试配置

### 测试端口转发

```bash
# 从外网测试（需要另一台机器或手机移动网络）
curl http://61.149.89.99:8080
```

### 测试 HTTPS

```bash
curl https://your-domain.com
```

### 检查 Nginx 状态

```bash
sudo nginx -t
sudo systemctl status nginx  # Linux
brew services list | grep nginx  # macOS
```

## 📱 访问方式总结

配置完成后，可以通过以下方式访问：

1. **HTTP**: `http://61.149.89.99:8080`（直接端口转发）
2. **HTTPS**: `https://your-domain.com`（使用反向代理）
3. **Cloudflare**: `https://your-domain.com`（通过 Cloudflare Tunnel）

## 🔍 故障排除

### 问题 1: 无法从外网访问

**检查清单**:
1. ✅ 路由器端口转发是否配置正确？
2. ✅ 防火墙是否允许端口 8080？
3. ✅ Open WebUI 是否绑定到 `0.0.0.0:8080`？
4. ✅ 路由器是否支持端口转发？
5. ✅ ISP 是否阻止了端口？（某些 ISP 会阻止常见端口）

### 问题 2: 连接超时

**可能原因**:
- 路由器端口转发配置错误
- 防火墙阻止
- Open WebUI 服务未运行

**解决方案**:
```bash
# 检查服务状态
./stop-openwebui.sh && ./start-openwebui.sh

# 检查端口
lsof -i :8080
```

### 问题 3: SSL 证书错误

**解决方案**:
- 使用 Let's Encrypt 自动续期
- 检查证书是否过期
- 确认域名 DNS 解析正确

## 📝 快速配置脚本

已创建自动化配置脚本，运行：

```bash
./setup-public-access.sh
```

该脚本会：
1. 检查当前配置
2. 安装 Nginx（如果需要）
3. 配置反向代理
4. 配置 SSL 证书
5. 提供配置说明

## 💡 推荐方案

1. **个人使用/测试**: 直接端口转发（方案一）
2. **长期使用**: Nginx 反向代理 + Let's Encrypt（方案二）
3. **最简单**: Cloudflare Tunnel（方案三）

## 📚 相关资源

- [Open WebUI 官方文档](https://docs.openwebui.com/)
- [Nginx 官方文档](https://nginx.org/en/docs/)
- [Let's Encrypt 文档](https://letsencrypt.org/docs/)
- [Cloudflare Tunnel 文档](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

