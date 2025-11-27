#!/bin/bash

# Ollama 云模型配置脚本
# 帮助用户快速配置 Ollama 云大模型

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Ollama 云模型配置助手                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查 Ollama 是否安装
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}错误: 未找到 Ollama${NC}"
    echo "请先安装 Ollama: https://ollama.com"
    exit 1
fi

echo -e "${GREEN}✓${NC} 已检测到 Ollama"
echo ""

# 选择配置方式
echo "请选择配置方式："
echo "1) 通过本地 Ollama CLI（推荐）- 需要先登录 ollama.com"
echo "2) 直接连接 Ollama 云 API - 需要 API Key"
echo ""
read -p "请输入选项 (1 或 2): " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}方式一：通过本地 Ollama CLI${NC}"
        echo ""
        echo "步骤 1: 登录 Ollama 账户"
        echo "如果你还没有账户，请访问 https://ollama.com 注册"
        echo ""
        read -p "按 Enter 继续登录..."
        
        ollama signin
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✓${NC} 登录成功！"
            echo ""
            echo "步骤 2: 拉取云模型"
            echo "可用的云模型示例："
            echo "  - gpt-oss:120b-cloud"
            echo "  更多模型请访问: https://ollama.com/search?c=cloud"
            echo ""
            read -p "请输入要拉取的云模型名称（直接按 Enter 跳过）: " model_name
            
            if [ -n "$model_name" ]; then
                echo ""
                echo "正在拉取模型: $model_name"
                ollama pull "$model_name"
                
                if [ $? -eq 0 ]; then
                    echo ""
                    echo -e "${GREEN}✓${NC} 模型拉取成功！"
                fi
            fi
            
            echo ""
            echo -e "${GREEN}配置完成！${NC}"
            echo ""
            echo "现在你可以："
            echo "1. 启动 Open WebUI: ./start-openwebui.sh"
            echo "2. 在 Web UI 中选择云模型使用"
        else
            echo -e "${RED}登录失败，请检查网络连接或账户信息${NC}"
            exit 1
        fi
        ;;
        
    2)
        echo ""
        echo -e "${BLUE}方式二：直接连接 Ollama 云 API${NC}"
        echo ""
        echo "步骤 1: 获取 API Key"
        echo "1. 访问 https://ollama.com/settings/keys"
        echo "2. 创建新的 API Key"
        echo "3. 复制 API Key"
        echo ""
        read -p "请输入你的 Ollama API Key: " api_key
        
        if [ -z "$api_key" ]; then
            echo -e "${RED}错误: API Key 不能为空${NC}"
            exit 1
        fi
        
        echo ""
        echo "步骤 2: 配置环境变量"
        
        # 检查 .env 文件是否存在
        if [ ! -f ".env" ]; then
            echo "创建 .env 文件..."
            touch .env
        fi
        
        # 检查是否已存在 OLLAMA_API_KEY
        if grep -q "OLLAMA_API_KEY" .env; then
            echo "更新现有的 OLLAMA_API_KEY..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s|OLLAMA_API_KEY=.*|OLLAMA_API_KEY=$api_key|" .env
            else
                # Linux
                sed -i "s|OLLAMA_API_KEY=.*|OLLAMA_API_KEY=$api_key|" .env
            fi
        else
            echo "添加 OLLAMA_API_KEY 到 .env 文件..."
            echo "" >> .env
            echo "# Ollama 云 API 配置" >> .env
            echo "OLLAMA_API_KEY=$api_key" >> .env
        fi
        
        # 配置 OLLAMA_BASE_URLS
        if grep -q "OLLAMA_BASE_URLS" .env; then
            # 检查是否已包含 https://ollama.com
            if ! grep -q "https://ollama.com" .env; then
                echo "更新 OLLAMA_BASE_URLS 以包含云服务器..."
                current_urls=$(grep "OLLAMA_BASE_URLS" .env | cut -d'=' -f2)
                if [ -z "$current_urls" ] || [ "$current_urls" = "http://localhost:11434" ]; then
                    new_urls="http://localhost:11434;https://ollama.com"
                else
                    new_urls="${current_urls};https://ollama.com"
                fi
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "s|OLLAMA_BASE_URLS=.*|OLLAMA_BASE_URLS=$new_urls|" .env
                else
                    sed -i "s|OLLAMA_BASE_URLS=.*|OLLAMA_BASE_URLS=$new_urls|" .env
                fi
            fi
        else
            echo "添加 OLLAMA_BASE_URLS 到 .env 文件..."
            echo "OLLAMA_BASE_URLS=http://localhost:11434;https://ollama.com" >> .env
        fi
        
        echo ""
        echo -e "${GREEN}✓${NC} 配置已保存到 .env 文件"
        echo ""
        echo "步骤 3: 测试连接"
        echo "正在测试 Ollama 云 API 连接..."
        
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer $api_key" \
            https://ollama.com/api/tags)
        
        if [ "$response" = "200" ]; then
            echo -e "${GREEN}✓${NC} 连接成功！"
        else
            echo -e "${YELLOW}⚠${NC}  连接测试返回状态码: $response"
            echo "请检查 API Key 是否正确"
        fi
        
        echo ""
        echo -e "${GREEN}配置完成！${NC}"
        echo ""
        echo "现在你可以："
        echo "1. 启动 Open WebUI: ./start-openwebui.sh"
        echo "2. 在 Web UI 中拉取和使用云模型"
        echo ""
        echo "提示: 你也可以通过 Web UI 配置："
        echo "  设置 → Connections → Ollama → 添加连接"
        echo "  Base URL: https://ollama.com"
        echo "  API Key: $api_key"
        ;;
        
    *)
        echo -e "${RED}无效的选项${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}相关文档:${NC}"
echo "  - 详细配置说明: ./OLLAMA_CLOUD_CONFIG.md"
echo "  - Ollama 云模型文档: https://docs.ollama.com/cloud"
echo "  - 可用云模型列表: https://ollama.com/search?c=cloud"
echo ""

