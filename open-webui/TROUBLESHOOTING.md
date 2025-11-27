# Open WebUI 故障排除指南

## 问题：用户身份下没有模型可选择

### 可能的原因和解决方法

#### 1. 检查 Ollama 连接

**检查本地 Ollama 是否运行：**
```bash
curl http://localhost:11434/api/tags
```

**检查 Open WebUI 是否能连接到 Ollama：**
```bash
curl http://localhost:8080/ollama/api/tags
```

#### 2. 检查用户角色和权限

**问题**：普通用户可能没有权限查看所有模型。

**解决方法**：
1. 使用管理员账户登录
2. 或者将用户提升为管理员：
   - 管理员登录后，进入 **设置 → 用户管理**
   - 找到对应用户，修改角色为 **管理员** 或 **用户**

#### 3. 检查模型列表 API

**直接访问模型列表 API：**
```bash
# 需要先登录获取 token
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8080/api/models
```

#### 4. 检查 Open WebUI 配置

**检查 .env 文件中的配置：**
```bash
# 确保 Ollama 连接配置正确
OLLAMA_BASE_URL=http://localhost:11434
```

**检查连接配置：**
1. 登录 Open WebUI
2. 进入 **设置 → Connections → Ollama**
3. 确保有配置的连接，且状态正常

#### 5. 重启服务

```bash
cd open-webui
./stop-openwebui.sh
./start-openwebui.sh
```

#### 6. 检查日志

```bash
tail -f logs/openwebui.log | grep -i "model\|ollama\|error"
```

---

## 常见问题

### Q: 为什么管理员能看到模型，但普通用户看不到？

**A:** 可能是权限设置问题。检查：
1. 用户角色是否正确
2. 是否有模型访问限制
3. 检查设置 → 用户管理中的权限配置

### Q: 本地有模型，但 Open WebUI 显示为空？

**A:** 检查：
1. Ollama 服务是否运行：`ollama list`
2. Open WebUI 是否能连接 Ollama：`curl http://localhost:11434/api/tags`
3. 检查 Open WebUI 的连接配置

### Q: 如何查看当前可用的模型？

**方法 1：通过命令行**
```bash
ollama list
```

**方法 2：通过 API**
```bash
curl http://localhost:11434/api/tags
```

**方法 3：在 Open WebUI 中**
- 设置 → Connections → Ollama
- 查看连接状态和可用模型

---

## 快速诊断命令

```bash
# 1. 检查 Ollama 服务
ollama list

# 2. 检查 Ollama API
curl http://localhost:11434/api/tags

# 3. 检查 Open WebUI 服务
curl http://localhost:8080/api/config

# 4. 检查 Open WebUI 的 Ollama 连接
curl http://localhost:8080/ollama/api/tags

# 5. 查看日志
tail -50 logs/openwebui.log
```

---

## 联系支持

如果以上方法都无法解决问题，请：
1. 查看完整日志：`tail -100 logs/openwebui.log`
2. 检查 Open WebUI 版本：`open-webui --version`
3. 查看官方文档：https://docs.openwebui.com/
