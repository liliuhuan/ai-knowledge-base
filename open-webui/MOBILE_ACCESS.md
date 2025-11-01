# 移动端和其他设备访问 Open WebUI 指南

## 📱 快速开始

Open WebUI 默认已配置为允许局域网访问。您只需要知道本机的 IP 地址即可。

## 🔍 查找本机 IP 地址

### macOS

**方法 1: 使用脚本（推荐）**
```bash
cd open-webui
./get-ip-address.sh
```

**方法 2: 手动查找**
```bash
# Wi-Fi 网络
ipconfig getifaddr en0

# 或显示所有网络接口
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### Linux

```bash
# 方法 1
hostname -I

# 方法 2
ip addr show | grep "inet " | grep -v 127.0.0.1

# 方法 3
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### Windows

```powershell
# PowerShell
ipconfig | findstr IPv4

# 或查看详细信息
ipconfig /all
```

## 🌐 从其他设备访问

### 1. 确保服务正在运行

```bash
./start-openwebui.sh
```

确认服务绑定到 `0.0.0.0:8080`（这是默认配置）。

### 2. 获取本机 IP 地址

例如，如果您的 IP 地址是 `192.168.1.100`。

### 3. 在手机或其他设备上访问

打开浏览器（Chrome、Safari、Firefox 等），访问：

```
http://YOUR_IP_ADDRESS:8080
```

例如：
```
http://192.168.1.100:8080
```

### 4. 确保设备在同一网络

- 📱 手机/平板：必须连接到与运行 Open WebUI 的电脑相同的 Wi-Fi 网络
- 💻 其他电脑：必须连接到相同的局域网

## 🔒 防火墙配置

### macOS

**检查防火墙状态**：
```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

**允许端口 8080**：
1. 系统设置 → 网络 → 防火墙 → 防火墙选项
2. 点击 "+" 添加应用程序
3. 选择 Python 或允许所有传入连接
4. 或使用命令行：

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/bin/python3
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/bin/python3
```

**临时禁用防火墙（不推荐，仅用于测试）**：
```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
```

### Linux

**UFW (Ubuntu/Debian)**:
```bash
# 允许端口 8080
sudo ufw allow 8080/tcp

# 检查状态
sudo ufw status
```

**firewalld (CentOS/RHEL/Fedora)**:
```bash
# 允许端口 8080
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### Windows

1. 打开"Windows Defender 防火墙"
2. 点击"高级设置"
3. 点击"入站规则" → "新建规则"
4. 选择"端口" → TCP → 特定本地端口：8080
5. 允许连接 → 应用到所有配置文件 → 命名规则

## 🔧 配置选项

### 修改端口

如果需要使用其他端口（例如 3000）：

```bash
PORT=3000 ./start-openwebui.sh
```

然后从手机访问：`http://YOUR_IP_ADDRESS:3000`

### 修改主机绑定

默认已绑定到 `0.0.0.0`（所有网络接口），这是正确的配置。

如果需要只绑定到特定 IP：

```bash
HOST=192.168.1.100 ./start-openwebui.sh
```

## 📱 移动端体验优化

### PWA（渐进式 Web 应用）

Open WebUI 支持 PWA，可以在手机上添加为应用：

1. 在手机浏览器中打开 Open WebUI
2. 点击浏览器的"添加到主屏幕"选项
3. 这样就会像原生应用一样使用

### 响应式设计

Open WebUI 已针对移动端进行了优化，支持：
- ✅ 触摸操作
- ✅ 响应式布局
- ✅ 移动端菜单

## 🌍 通过公网访问（可选）

如果您想从互联网访问（不在同一局域网），需要：

### 1. 路由器端口转发

1. 登录路由器管理界面
2. 找到"端口转发"或"NAT"设置
3. 添加规则：
   - 外部端口：8080（或其他）
   - 内部 IP：您的电脑 IP（如 192.168.1.100）
   - 内部端口：8080
   - 协议：TCP

### 2. 动态 DNS（可选）

如果您的公网 IP 经常变化，可以使用动态 DNS 服务：
- DuckDNS (免费)
- No-IP (免费)
- Dynu (免费)

### 3. 安全考虑

⚠️ **重要提示**：通过公网访问时，请确保：
- ✅ 使用强密码
- ✅ 启用 HTTPS（使用反向代理如 Nginx）
- ✅ 限制访问 IP（如果可以）
- ✅ 定期更新 Open WebUI

## 🧪 测试连接

### 从同一台电脑测试

```bash
# 替换为您的实际 IP
curl http://192.168.1.100:8080
```

### 从手机测试

在手机浏览器中访问，应该能看到 Open WebUI 登录界面。

### 检查端口是否开放

**从同一网络的其他设备**：
```bash
# Linux/macOS
nc -zv YOUR_IP_ADDRESS 8080

# 或使用 telnet
telnet YOUR_IP_ADDRESS 8080
```

## 🔍 故障排除

### 问题 1: 无法连接

**检查清单**：
1. ✅ 服务是否正在运行？ `./stop-openwebui.sh && ./start-openwebui.sh`
2. ✅ 是否使用了正确的 IP 地址？
3. ✅ 设备是否在同一网络？
4. ✅ 防火墙是否允许端口 8080？
5. ✅ 服务是否绑定到 `0.0.0.0`？（检查启动日志）

**查看日志**：
```bash
tail -f logs/openwebui.log
```

### 问题 2: 连接被拒绝

**可能原因**：
- 防火墙阻止了连接
- 服务未绑定到 `0.0.0.0`

**解决方案**：
```bash
# 检查防火墙
# macOS
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Linux
sudo ufw status

# 确保服务绑定正确
grep "host" logs/openwebui.log
```

### 问题 3: 页面加载缓慢

**优化建议**：
- 使用 5GHz Wi-Fi（如果可用）
- 确保网络连接稳定
- 检查服务器资源使用情况

### 问题 4: 只能在电脑上访问

**检查 HOST 配置**：
确保启动脚本中的 `DEFAULT_HOST="0.0.0.0"`，不是 `127.0.0.1` 或 `localhost`。

## 📝 快速参考

```bash
# 启动服务（默认端口 8080，绑定到所有接口）
./start-openwebui.sh

# 使用自定义端口启动
PORT=3000 ./start-openwebui.sh

# 查看本机 IP
./get-ip-address.sh

# 从手机访问
http://YOUR_IP_ADDRESS:8080
```

## 🎯 常见场景

### 场景 1: 家庭局域网访问

1. 电脑和手机连接到同一个 Wi-Fi
2. 启动 Open WebUI
3. 查找电脑 IP：`./get-ip-address.sh`
4. 手机访问：`http://电脑IP:8080`

### 场景 2: 办公室访问

1. 确保电脑和手机在同一内网
2. 可能需要 IT 部门开放端口 8080
3. 使用公司分配的内网 IP 访问

### 场景 3: 远程访问

1. 配置路由器端口转发
2. 获取公网 IP 或使用动态 DNS
3. 从任何地方访问：`http://公网IP:8080`

## 💡 提示

- 🔐 首次访问时，需要创建管理员账户
- 📱 推荐使用现代浏览器（Chrome、Safari、Firefox）
- 🌐 考虑使用 HTTPS（通过反向代理）提高安全性
- 📊 可以在设置中配置访问控制和用户管理

## 📚 相关文档

- [Open WebUI 官方文档](https://docs.openwebui.com/)
- [网络安全最佳实践](https://docs.openwebui.com/getting-started/advanced-topics/security)

