# Ollama 云大模型配置指南

本指南说明如何在 Open WebUI 中配置和使用 [Ollama 云大模型](https://docs.ollama.com/cloud)。

## 什么是 Ollama 云模型？

Ollama 云模型是一种无需强大 GPU 即可运行的大型模型。这些模型会自动卸载到 Ollama 的云服务，同时提供与本地模型相同的功能，让你可以在个人电脑上运行更大的模型。

## 配置方式

### 方式一：通过本地 Ollama CLI（推荐）

这种方式最简单，适合已经在使用本地 Ollama 的用户。

#### 步骤 1: 登录 Ollama 账户

首先需要在 [ollama.com](https://ollama.com) 创建账户，然后登录：

```bash
ollama signin
```

#### 步骤 2: 拉取云模型

拉取你想要的云模型（例如 `gpt-oss:120b-cloud`）：

```bash
ollama pull gpt-oss:120b-cloud
```

#### 步骤 3: 配置 Open WebUI

确保 Open WebUI 连接到本地 Ollama（默认配置即可）：

```bash
# 在 .env 文件中或启动脚本中设置
OLLAMA_BASE_URL=http://localhost:11434
```

或者使用默认配置（Open WebUI 默认连接到 `http://localhost:11434`）。

#### 步骤 4: 启动 Open WebUI

```bash
./start-openwebui.sh
```

现在你可以在 Open WebUI 中看到并使用云模型了！

---

### 方式二：直接连接到 Ollama 云 API

这种方式直接连接到 ollama.com 的 API，适合想要完全使用云端服务的用户。

#### 步骤 1: 创建 API Key

1. 访问 [ollama.com/settings/keys](https://ollama.com/settings/keys)
2. 创建一个新的 API Key
3. 复制 API Key（格式类似：`ollama_xxxxxxxxxxxxx`）

#### 步骤 2: 配置环境变量

在 Open WebUI 目录下创建或编辑 `.env` 文件：

```bash
# Ollama 云 API 配置
OLLAMA_BASE_URLS=https://ollama.com
OLLAMA_API_KEY=your_ollama_api_key_here
```

#### 步骤 3: 通过 Web UI 配置（推荐）

1. 启动 Open WebUI：
   ```bash
   ./start-openwebui.sh
   ```

2. 访问 `http://localhost:8080`

3. 进入设置：
   - 点击右上角设置图标 ⚙️
   - 进入 "Connections" 或 "连接" 页面
   - 找到 "Ollama" 部分

4. 配置 Ollama 连接：
   - **Base URL**: `https://ollama.com`
   - **API Key**: 输入你的 Ollama API Key
   - 点击 "保存"

#### 步骤 4: 拉取云模型

在 Open WebUI 中：
1. 进入模型管理页面
2. 点击 "Pull Model" 或 "拉取模型"
3. 输入云模型名称，例如：`gpt-oss:120b-cloud`
4. 点击拉取

或者通过命令行：

```bash
# 设置 API Key 环境变量
export OLLAMA_API_KEY=your_api_key

# 拉取云模型
curl https://ollama.com/api/pull \
  -H "Authorization: Bearer $OLLAMA_API_KEY" \
  -d '{"name": "gpt-oss:120b-cloud"}'
```

---

## 可用的云模型

查看所有可用的云模型，访问 [Ollama 模型库](https://ollama.com/search?c=cloud)。

一些推荐的云模型：
- `gpt-oss:120b-cloud` - 120B 参数的大型模型
- 更多模型请查看 [ollama.com](https://ollama.com)

---

## 配置多个 Ollama 服务器

Open WebUI 支持配置多个 Ollama 服务器（本地 + 云端）：

### 通过环境变量配置

在 `.env` 文件中：

```bash
# 多个 Ollama 服务器（用分号分隔）
OLLAMA_BASE_URLS=http://localhost:11434;https://ollama.com

# 对应的 API Keys（用分号分隔，顺序要对应）
# 本地 Ollama 不需要 Key，用空字符串占位
OLLAMA_API_KEYS=;your_ollama_cloud_api_key
```

### 通过 Web UI 配置

1. 进入设置 → Connections → Ollama
2. 可以添加多个 Ollama 服务器
3. 为每个服务器配置：
   - Base URL
   - API Key（如果需要）
   - 连接名称

---

## 验证配置

### 检查本地 Ollama 连接

```bash
# 检查本地 Ollama 是否运行
curl http://localhost:11434/api/tags

# 检查是否已登录
ollama list
```

### 检查云 API 连接

```bash
# 设置 API Key
export OLLAMA_API_KEY=your_api_key

# 测试连接
curl https://ollama.com/api/tags \
  -H "Authorization: Bearer $OLLAMA_API_KEY"
```

### 在 Open WebUI 中验证

1. 启动 Open WebUI
2. 进入聊天界面
3. 点击模型选择器
4. 你应该能看到：
   - 本地模型（如果配置了本地 Ollama）
   - 云模型（如果配置了云 API）

---

## 使用示例

### 在 Open WebUI 中使用云模型

1. 启动 Open WebUI
2. 创建新对话
3. 选择云模型（例如 `gpt-oss:120b-cloud`）
4. 开始对话

### 通过 API 使用云模型

```bash
# 设置 API Key
export OLLAMA_API_KEY=your_api_key

# 发送聊天请求
curl https://ollama.com/api/chat \
  -H "Authorization: Bearer $OLLAMA_API_KEY" \
  -d '{
    "model": "gpt-oss:120b-cloud",
    "messages": [{
      "role": "user",
      "content": "你好，请介绍一下自己"
    }],
    "stream": false
  }'
```

---

## 常见问题

### Q: 云模型需要付费吗？

A: Ollama 云服务目前处于预览阶段，请查看 [ollama.com](https://ollama.com) 了解最新的定价信息。

### Q: 云模型和本地模型有什么区别？

A: 
- **本地模型**：运行在你的电脑上，需要足够的 GPU/CPU 资源
- **云模型**：运行在 Ollama 的云端服务器，不需要本地 GPU，但需要网络连接

### Q: 可以同时使用本地和云模型吗？

A: 可以！Open WebUI 支持配置多个 Ollama 服务器，你可以同时使用本地模型和云模型。

### Q: 如何查看可用的云模型列表？

A: 
- 访问 [ollama.com/search?c=cloud](https://ollama.com/search?c=cloud)
- 或者在 Open WebUI 中尝试拉取模型时查看可用列表

### Q: API Key 在哪里获取？

A: 访问 [ollama.com/settings/keys](https://ollama.com/settings/keys) 创建和管理 API Keys。

---

## 安全注意事项

1. **保护 API Key**：
   - 不要将 API Key 提交到 Git 仓库
   - 使用 `.env` 文件或环境变量存储
   - 定期轮换 API Key

2. **使用环境变量**：
   ```bash
   # 推荐：使用环境变量
   export OLLAMA_API_KEY=your_api_key
   ```

3. **检查 `.gitignore`**：
   确保 `.env` 文件在 `.gitignore` 中：
   ```
   .env
   .env.local
   ```

---

## 相关链接

- [Ollama 云模型文档](https://docs.ollama.com/cloud)
- [Ollama 模型库](https://ollama.com/search?c=cloud)
- [Ollama API 文档](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Open WebUI 文档](https://docs.openwebui.com/)

---

## 更新日志

- 2025-11-14: 初始版本，添加 Ollama 云模型配置指南

