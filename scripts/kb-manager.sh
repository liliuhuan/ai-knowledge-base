#!/bin/bash
# AI 知识库管理脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "ℹ️  $1"; }

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 检查 Python 环境
check_python() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python 未安装"
        exit 1
    fi
    
    if [ ! -d "venv" ]; then
        print_info "创建虚拟环境..."
        python3 -m venv venv
    fi
    
    print_success "Python 环境就绪"
}

# 安装依赖
install() {
    print_header "安装依赖"
    check_python
    
    print_info "安装 Python 包..."
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    
    print_success "依赖安装完成"
}

# 启动服务
start() {
    print_header "启动服务"
    
    if [ ! -d "venv" ]; then
        print_warning "虚拟环境不存在，正在安装..."
        install
    fi
    
    print_info "启动 Web UI..."
    source venv/bin/activate
    python web_ui.py
}

# 停止服务
stop() {
    print_header "停止服务"
    
    PID=$(pgrep -f "python.*web_ui.py" || true)
    if [ -n "$PID" ]; then
        kill $PID
        print_success "Web UI 已停止"
    else
        print_info "Web UI 未运行"
    fi
}

# 重启服务
restart() {
    stop
    sleep 2
    start
}

# 查看状态
status() {
    print_header "系统状态"
    
    # 检查 Python
    if command -v python3 &> /dev/null; then
        VERSION=$(python3 --version | awk '{print $2}')
        print_success "Python: $VERSION"
    else
        print_error "Python 未安装"
    fi
    
    # 检查 Ollama
    if command -v ollama &> /dev/null; then
        print_success "Ollama 已安装"
        if curl -s http://localhost:11434 > /dev/null 2>&1; then
            print_success "Ollama 服务运行中"
        else
            print_warning "Ollama 服务未启动"
        fi
    else
        print_error "Ollama 未安装"
    fi
    
    # 检查虚拟环境
    if [ -d "venv" ]; then
        print_success "虚拟环境已创建"
    else
        print_warning "虚拟环境不存在"
    fi
    
    # 检查知识库
    if [ -d "../data/chroma_local" ] && [ "$(ls -A ../data/chroma_local 2>/dev/null)" ]; then
        print_success "知识库: 已构建"
    else
        print_info "知识库: 未构建"
    fi
    
    # 检查文档
    if [ -d "../docs" ]; then
        COUNT=$(find ../docs -type f \( -name "*.txt" -o -name "*.md" -o -name "*.pdf" -o -name "*.docx" \) 2>/dev/null | wc -l)
        print_info "文档: $COUNT 个文件"
    fi
}

# 显示帮助
help() {
    echo "AI 知识库管理工具"
    echo ""
    echo "使用: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  install   - 安装依赖"
    echo "  start     - 启动服务"
    echo "  stop      - 停止服务"
    echo "  restart   - 重启服务"
    echo "  status    - 查看状态"
    echo "  help      - 显示帮助"
    echo ""
}

# 主逻辑
case "${1:-help}" in
    install)
        install
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    help|--help|-h)
        help
        ;;
    *)
        print_error "未知命令: $1"
        help
        exit 1
        ;;
esac