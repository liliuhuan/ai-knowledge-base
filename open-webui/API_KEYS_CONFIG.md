# API Keys 配置说明

本文档说明如何配置 Open WebUI 中的各种 API Keys 和连接。

## 已配置的服务

- Qwen (阿里云 DashScope)
- Groq
- Ollama（支持本地和云模型）

## 配置方式

配置已添加到 `start-openwebui.sh` 启动脚本中，启动服务时会自动加载。

### 已配置的 API Keys

1. **Qwen (阿里云 DashScope)**

   - API Key: `YOUR_QWEN_API_KEY` (请替换为您的实际 API Key)
   - API Base URL: `https://dashscope.aliyuncs.com/compatible-mode/v1`
2. **Groq**

   - API Key: `YOUR_GROQ_API_KEY` (请替换为您的实际 API Key)
   - API Base URL: `https://api.groq.com/openai/v1`

## 使用方法

### 方法一：通过自动配置脚本（推荐）

运行自动配置脚本来设置 API Keys：

```bash
./setup-api-keys.sh
```

脚本会提示您输入管理员账户凭据，然后自动配置 Qwen 和 Groq 的连接。

### 方法二：直接启动（如果环境变量已生效）

直接运行启动脚本，API Keys 会通过环境变量加载：

```bash
./start-openwebui.sh
```

**注意**: 如果这是首次配置，环境变量应该会生效。如果之前已经配置过，建议使用方法一或方法三。

### 方法三：手动通过 Web UI 配置（最可靠）

如果上述方法无效，请通过 Web UI 手动配置（见下方说明）。

## 通过 .env 文件配置（可选）

如果您想通过 `.env` 文件来配置，可以在 `open-webui` 目录下创建 `.env` 文件：

```bash
# Qwen 和 Groq API Keys (用分号分隔)
OPENAI_API_KEYS=YOUR_QWEN_API_KEY;YOUR_GROQ_API_KEY

# API Base URLs (用分号分隔，顺序要与 API Keys 对应)
OPENAI_API_BASE_URLS=https://dashscope.aliyuncs.com/compatible-mode/v1;https://api.groq.com/openai/v1

# 启用 OpenAI API
ENABLE_OPENAI_API=True
```

注意：如果 `.env` 文件中已设置 `OPENAI_API_KEYS`，启动脚本中的默认配置将不会生效。

## 通过 Web UI 配置（推荐）

启动服务后，您也可以通过 Web UI 界面来管理 API 配置：

1. 访问 `http://localhost:8080`
2. 点击设置图标 ⚙️
3. 进入"连接"（Connections）页面
4. 在 "OpenAI" 部分，点击"管理"（扳手图标）
5. 点击"➕ 添加新连接"
6. 输入连接信息：
   - **API URL**: 输入相应服务的 API 基础 URL
   - **API 密钥**: 输入 API 密钥
   - **名称**（可选）: 为连接命名，如 "Qwen" 或 "Groq"
7. 点击"保存"

## 验证配置

启动服务后，在 Web UI 中：

1. 进入聊天界面
2. 点击模型选择器
3. 您应该能看到 Qwen 和 Groq 的模型列表

## Ollama 云模型配置

Open WebUI 支持配置 Ollama 云大模型。详细配置说明请参考 [OLLAMA_CLOUD_CONFIG.md](./OLLAMA_CLOUD_CONFIG.md)。

### 快速配置

#### 方式一：通过本地 Ollama CLI（推荐）

1. 登录 Ollama 账户：
   ```bash
   ollama signin
   ```

2. 拉取云模型：
   ```bash
   ollama pull gpt-oss:120b-cloud
   ```

3. Open WebUI 会自动连接到本地 Ollama，云模型会自动可用。

#### 方式二：直接连接 Ollama 云 API

1. 在 [ollama.com/settings/keys](https://ollama.com/settings/keys) 创建 API Key

2. 通过环境变量配置：
   ```bash
   # 在 .env 文件中
   OLLAMA_BASE_URLS=http://localhost:11434;https://ollama.com
   OLLAMA_API_KEY=your_ollama_api_key
   ```

3. 或通过 Web UI 配置：
   - 设置 → Connections → Ollama
   - 添加新连接：Base URL = `https://ollama.com`，API Key = 你的 API Key

## 注意事项

- API Keys 和 Base URLs 的索引必须对应
- 多个值使用分号（`;`）分隔
- 确保 API Keys 有效且有足够的配额
- 建议在生产环境中使用 `.env` 文件或环境变量来管理敏感信息
- Ollama 云模型需要网络连接，请确保网络畅通
