#!/bin/bash

# 检查 API 配置脚本

echo "========================================="
echo "检查 Open WebUI API 配置"
echo "========================================="
echo ""

# 检查环境变量
echo "1. 检查环境变量:"
echo "   OPENAI_API_KEYS: ${OPENAI_API_KEYS:0:50}..."
echo "   OPENAI_API_BASE_URLS: $OPENAI_API_BASE_URLS"
echo "   ENABLE_OPENAI_API: $ENABLE_OPENAI_API"
echo ""

# 检查进程环境变量
PID=$(pgrep -f "open-webui serve" | head -1)
if [ -n "$PID" ]; then
    echo "2. 检查运行中的进程 (PID: $PID) 的环境变量:"
    if command -v ps &> /dev/null; then
        echo "   OPENAI_API_KEYS: $(ps eww -p $PID | grep -o 'OPENAI_API_KEYS=[^[:space:]]*' | head -1 | cut -d'=' -f2 | cut -c1-50)..."
        echo "   OPENAI_API_BASE_URLS: $(ps eww -p $PID | grep -o 'OPENAI_API_BASE_URLS=[^[:space:]]*' | head -1 | cut -d'=' -f2)"
    fi
else
    echo "2. Open WebUI 进程未运行"
fi
echo ""

# 检查 API 端点
echo "3. 测试 API 端点连接:"
if command -v curl &> /dev/null; then
    echo "   测试 Qwen API..."
    if [[ -n "$QWEN_API_KEY" ]]; then
        curl -s -o /dev/null -w "   Qwen: HTTP %{http_code}\n" \
            -H "Authorization: Bearer $QWEN_API_KEY" \
            "https://dashscope.aliyuncs.com/compatible-mode/v1/models" || echo "   Qwen: 连接失败"
    else
        echo "   Qwen: API Key 未设置，跳过测试"
    fi
    
    echo "   测试 Groq API..."
    if [[ -n "$GROQ_API_KEY" ]]; then
        curl -s -o /dev/null -w "   Groq: HTTP %{http_code}\n" \
            -H "Authorization: Bearer $GROQ_API_KEY" \
            "https://api.groq.com/openai/v1/models" || echo "   Groq: 连接失败"
    else
        echo "   Groq: API Key 未设置，跳过测试"
    fi
else
    echo "   curl 未安装，跳过连接测试"
fi
echo ""

echo "========================================="
echo "建议："
echo "1. 如果环境变量未设置，请确保使用 ./start-openwebui.sh 启动"
echo "2. 或通过 Web UI 手动添加连接:"
echo "   - 访问 http://localhost:8080"
echo "   - 设置 -> 连接 -> OpenAI -> 管理 -> 添加新连接"
echo "========================================="

