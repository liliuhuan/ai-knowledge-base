#!/bin/bash

# Open WebUI API Keys 自动配置脚本
# 通过 API 自动配置 Qwen 和 Groq 的连接

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WEBUI_URL="http://localhost:8080"
ADMIN_EMAIL=""  # 留空则使用第一个用户
ADMIN_PASSWORD=""

echo -e "${BLUE}Open WebUI API Keys 自动配置脚本${NC}"
echo ""

# 检查服务是否运行
if ! curl -s "$WEBUI_URL" > /dev/null 2>&1; then
    echo -e "${RED}错误: Open WebUI 服务未运行在 $WEBUI_URL${NC}"
    echo "请先启动服务: ./start-openwebui.sh"
    exit 1
fi

echo -e "${GREEN}✓ Open WebUI 服务正在运行${NC}"

# 提示用户输入管理员凭据
if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo ""
    echo "需要管理员账户凭据来配置 API Keys"
    read -p "请输入管理员邮箱: " ADMIN_EMAIL
    read -sp "请输入管理员密码: " ADMIN_PASSWORD
    echo ""
fi

# 登录获取 token
echo ""
echo "正在登录..."
LOGIN_RESPONSE=$(curl -s -X POST "$WEBUI_URL/api/v1/auths/signin" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}错误: 登录失败${NC}"
    echo "响应: $LOGIN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ 登录成功${NC}"

# 获取当前配置
echo ""
echo "正在获取当前配置..."
CURRENT_CONFIG=$(curl -s -X GET "$WEBUI_URL/openai/config" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

echo "当前配置: $CURRENT_CONFIG"

# 准备新的配置
OPENAI_API_BASE_URLS='["https://dashscope.aliyuncs.com/compatible-mode/v1","https://api.groq.com/openai/v1"]'
OPENAI_API_KEYS='["sk-41eeab43564b4f6bb14686bfedb8b74a","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"]'
OPENAI_API_CONFIGS='{"0":{"enable":true,"name":"Qwen"},"1":{"enable":true,"name":"Groq"}}'

# 更新配置
echo ""
echo "正在更新配置..."
UPDATE_RESPONSE=$(curl -s -X POST "$WEBUI_URL/openai/config/update" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"ENABLE_OPENAI_API\": true,
        \"OPENAI_API_BASE_URLS\": $OPENAI_API_BASE_URLS,
        \"OPENAI_API_KEYS\": $OPENAI_API_KEYS,
        \"OPENAI_API_CONFIGS\": $OPENAI_API_CONFIGS
    }")

if echo "$UPDATE_RESPONSE" | grep -q "error"; then
    echo -e "${RED}错误: 配置更新失败${NC}"
    echo "响应: $UPDATE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ 配置更新成功${NC}"

# 刷新模型列表
echo ""
echo "正在刷新模型列表..."
curl -s -X GET "$WEBUI_URL/api/models?refresh=true" \
    -H "Authorization: Bearer $TOKEN" > /dev/null

echo -e "${GREEN}✓ 模型列表已刷新${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}配置完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "已配置的连接:"
echo "  1. Qwen - https://dashscope.aliyuncs.com/compatible-mode/v1"
echo "  2. Groq - https://api.groq.com/openai/v1"
echo ""
echo "现在您可以在 Web UI 中看到这些模型的列表了！"
echo "访问: $WEBUI_URL"

