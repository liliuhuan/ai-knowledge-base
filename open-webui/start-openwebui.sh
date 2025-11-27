#!/bin/bash

# Open WebUI 启动脚本
# 作者: AI Assistant
# 版本: 2.0.0
# 日期: 2025-01-01

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
DEFAULT_PORT=8080
DEFAULT_HOST="0.0.0.0"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/openwebui.log"
STARTUP_LOG="$LOG_DIR/startup.log"
PID_FILE="$LOG_DIR/openwebui.pid"
MAX_WAIT_TIME=60
HEALTH_CHECK_INTERVAL=2

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$STARTUP_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$STARTUP_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$STARTUP_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$STARTUP_LOG"
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Open WebUI 启动器                          ║"
    echo "║                                                              ║"
    echo "║  智能启动 Open WebUI 服务并自动打开浏览器                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 加载配置
load_config() {
    # 从环境变量或配置文件加载设置
    if [[ -f ".env" ]]; then
        log_info "加载配置文件: .env"
        # 使用 set -a 自动导出所有变量，并安全地加载 .env 文件
        set -a
        # 逐行读取 .env 文件，处理包含特殊字符的值
        while IFS= read -r line || [ -n "$line" ]; do
            # 跳过注释和空行
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue
            # 如果行包含 =，则导出变量
            if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]// /}"
                local value="${BASH_REMATCH[2]}"
                # 移除值首尾的引号（如果存在）
                value="${value#\"}"
                value="${value%\"}"
                value="${value#\'}"
                value="${value%\'}"
                # 导出变量
                export "$key=$value"
            fi
        done < .env
        set +a
    fi
    
    # 设置默认值
    export PORT=${PORT:-${OPENWEBUI_PORT:-$DEFAULT_PORT}}
    export HOST=${HOST:-${OPENWEBUI_HOST:-$DEFAULT_HOST}}
    export AUTO_OPEN_BROWSER=${AUTO_OPEN_BROWSER:-true}
    export LOG_LEVEL=${LOG_LEVEL:-INFO}
    
    # 配置 Ollama（支持本地和云模型）
    if [[ -z "$OLLAMA_BASE_URLS" ]]; then
        # 默认连接到本地 Ollama
        export OLLAMA_BASE_URLS=${OLLAMA_BASE_URL:-"http://localhost:11434"}
        
        # 如果设置了 Ollama 云 API Key，添加云服务器
        if [[ -n "$OLLAMA_API_KEY" ]]; then
            export OLLAMA_BASE_URLS="${OLLAMA_BASE_URLS};https://ollama.com"
            log_info "已配置 Ollama 云模型支持（需要 API Key）"
        fi
    fi
    
    # 配置 API Keys (如果没有在 .env 中设置)
    if [[ -z "$OPENAI_API_KEYS" ]]; then
        # 从环境变量或使用占位符
        QWEN_KEY=${QWEN_API_KEY:-"YOUR_QWEN_API_KEY"}
        GROQ_KEY=${GROQ_API_KEY:-"YOUR_GROQ_API_KEY"}
        
        # Qwen API Key 和 Groq API Key (用分号分隔)
        export OPENAI_API_KEYS="${QWEN_KEY};${GROQ_KEY}"
        # Qwen API Base URL 和 Groq API Base URL (用分号分隔)
        export OPENAI_API_BASE_URLS="https://dashscope.aliyuncs.com/compatible-mode/v1;https://api.groq.com/openai/v1"
        # 启用 OpenAI API
        export ENABLE_OPENAI_API=${ENABLE_OPENAI_API:-True}
        
        if [[ "$QWEN_KEY" != "YOUR_QWEN_API_KEY" ]] || [[ "$GROQ_KEY" != "YOUR_GROQ_API_KEY" ]]; then
            log_info "已配置 Qwen 和 Groq API Keys"
        else
            log_info "请设置 QWEN_API_KEY 和 GROQ_API_KEY 环境变量，或通过 Web UI 配置"
        fi
    fi
    
    log_info "配置加载完成: 端口=$PORT, 主机=$HOST"
    log_info "Ollama 服务器: $OLLAMA_BASE_URLS"
}

# 创建必要目录
create_directories() {
    local dirs=("$LOG_DIR" "data" "config")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "创建目录: $dir"
        fi
    done
}

# 设置日志轮转
setup_log_rotation() {
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        local max_size=$((10 * 1024 * 1024))  # 10MB
        
        if [[ $log_size -gt $max_size ]]; then
            log_info "日志文件过大，执行轮转..."
            
            # 保留最近 5 个日志文件
            for i in {4..1}; do
                if [[ -f "$LOG_FILE.$i" ]]; then
                    mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
                fi
            done
            
            mv "$LOG_FILE" "$LOG_FILE.1"
            log_success "日志轮转完成"
        fi
    fi
}

# 检查进程状态
check_process_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        else
            # PID 文件存在但进程不存在，清理 PID 文件
            rm -f "$PID_FILE"
        fi
    fi
    
    # 通过进程名查找
    local pid=$(pgrep -f "open-webui serve" | head -1)
    if [[ -n "$pid" ]]; then
        echo "$pid" > "$PID_FILE"
        echo "$pid"
        return 0
    fi
    
    return 1
}

# 检查端口占用
check_port_availability() {
    local port=$1
    
    if command -v lsof &> /dev/null; then
        if lsof -i :$port &> /dev/null; then
            local pid=$(lsof -t -i:$port | head -1)
            local process=$(ps -p $pid -o comm= 2>/dev/null || echo "未知进程")
            log_warning "端口 $port 被进程占用: $process (PID: $pid)"
            return 1
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -ln | grep ":$port " &> /dev/null; then
            log_warning "端口 $port 可能被占用"
            return 1
        fi
    fi
    
    return 0
}

# 健康检查
health_check() {
    local url="http://localhost:$PORT"
    local max_attempts=$((MAX_WAIT_TIME / HEALTH_CHECK_INTERVAL))
    local attempt=0
    
    log_info "等待服务启动 (最多等待 ${MAX_WAIT_TIME}s)..."
    
    while [[ $attempt -lt $max_attempts ]]; do
        if command -v curl &> /dev/null; then
            if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
                return 0
            fi
        elif command -v wget &> /dev/null; then
            if wget -q --timeout=5 --spider "$url" 2>/dev/null; then
                return 0
            fi
        else
            # 如果没有 curl 或 wget，只检查进程
            if check_process_status > /dev/null; then
                sleep $HEALTH_CHECK_INTERVAL
                return 0
            fi
        fi
        
        sleep $HEALTH_CHECK_INTERVAL
        attempt=$((attempt + 1))
        echo -n "."
    done
    
    echo ""
    return 1
}

# 打开浏览器
open_browser() {
    if [[ "$AUTO_OPEN_BROWSER" != "true" ]]; then
        return 0
    fi
    
    local url="http://localhost:$PORT"
    log_info "正在打开浏览器: $url"
    
    # 等待一下确保服务完全启动
    sleep 2
    
    case "$(uname -s)" in
        Darwin*)
            open "$url" 2>/dev/null || log_warning "无法自动打开浏览器"
            ;;
        Linux*)
            if command -v xdg-open > /dev/null; then
                xdg-open "$url" 2>/dev/null || log_warning "无法自动打开浏览器"
            elif command -v gnome-open > /dev/null; then
                gnome-open "$url" 2>/dev/null || log_warning "无法自动打开浏览器"
            else
                log_warning "无法自动打开浏览器，请手动访问: $url"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)
            start "$url" 2>/dev/null || log_warning "无法自动打开浏览器"
            ;;
        *)
            log_warning "无法自动打开浏览器，请手动访问: $url"
            ;;
    esac
}

# 启动服务
start_service() {
    log_info "启动 Open WebUI 服务..."
    
    # 检查命令是否可用
    if ! command -v open-webui &> /dev/null; then
        log_error "open-webui 命令未找到"
        echo ""
        echo "请确保 Open WebUI 已正确安装:"
        echo "1. 运行安装脚本: ./install-openwebui.sh"
        echo "2. 或手动安装: pip install open-webui"
        echo "3. 检查 PATH 环境变量"
        exit 1
    fi
    
    # 设置环境变量
    export PORT HOST LOG_LEVEL
    # 导出 API Keys 配置 (如果已设置)
    [[ -n "$OPENAI_API_KEYS" ]] && export OPENAI_API_KEYS
    [[ -n "$OPENAI_API_BASE_URLS" ]] && export OPENAI_API_BASE_URLS
    [[ -n "$ENABLE_OPENAI_API" ]] && export ENABLE_OPENAI_API
    # 导出 Ollama 配置 (如果已设置)
    [[ -n "$OLLAMA_BASE_URL" ]] && export OLLAMA_BASE_URL
    [[ -n "$OLLAMA_BASE_URLS" ]] && export OLLAMA_BASE_URLS
    [[ -n "$OLLAMA_API_KEY" ]] && export OLLAMA_API_KEY
    
    # 启动服务
    nohup open-webui serve \
        --host "$HOST" \
        --port "$PORT" \
        > "$LOG_FILE" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    log_success "服务已启动 (PID: $pid)"
    
    # 健康检查
    if health_check; then
        log_success "服务健康检查通过"
        return 0
    else
        log_error "服务启动失败或健康检查超时"
        
        # 显示最近的错误日志
        if [[ -f "$LOG_FILE" ]]; then
            echo ""
            echo "最近的错误日志:"
            tail -10 "$LOG_FILE"
        fi
        
        return 1
    fi
}

# 显示状态信息
show_status() {
    local pid
    if pid=$(check_process_status); then
        log_success "Open WebUI 正在运行 (PID: $pid)"
        echo ""
        echo -e "${BLUE}服务信息:${NC}"
        echo -e "  访问地址: ${GREEN}http://localhost:$PORT${NC}"
        echo -e "  进程 ID:  ${GREEN}$pid${NC}"
        echo -e "  日志文件: ${YELLOW}$LOG_FILE${NC}"
        echo -e "  配置文件: ${YELLOW}.env${NC}"
        echo ""
        echo -e "${BLUE}管理命令:${NC}"
        echo -e "  查看日志: ${YELLOW}tail -f $LOG_FILE${NC}"
        echo -e "  停止服务: ${YELLOW}./stop-openwebui.sh${NC}"
        echo -e "  重启服务: ${YELLOW}./stop-openwebui.sh && ./start-openwebui.sh${NC}"
        
        # 自动打开浏览器
        open_browser
        
        return 0
    else
        return 1
    fi
}

# 主函数
main() {
    show_banner
    
    # 初始化
    load_config
    create_directories
    setup_log_rotation
    
    log_info "开始启动 Open WebUI..."
    
    # 检查是否已在运行
    if show_status; then
        log_info "服务已在运行，无需重复启动"
        exit 0
    fi
    
    # 检查端口可用性
    if ! check_port_availability "$PORT"; then
        echo ""
        read -p "端口 $PORT 被占用，是否尝试终止占用进程? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command -v lsof &> /dev/null; then
                local pids=$(lsof -t -i:$PORT)
                if [[ -n "$pids" ]]; then
                    log_info "终止占用进程..."
                    echo "$pids" | xargs kill -9 2>/dev/null || true
                    sleep 2
                    
                    if check_port_availability "$PORT"; then
                        log_success "端口 $PORT 已释放"
                    else
                        log_error "无法释放端口 $PORT"
                        exit 1
                    fi
                fi
            fi
        else
            log_info "您可以使用不同端口启动: PORT=8081 ./start-openwebui.sh"
            exit 1
        fi
    fi
    
    # 启动服务
    if start_service; then
        echo ""
        show_status
        log_success "Open WebUI 启动完成!"
    else
        log_error "Open WebUI 启动失败"
        echo ""
        echo "故障排除建议:"
        echo "1. 检查日志文件: tail -f $LOG_FILE"
        echo "2. 检查端口占用: lsof -i :$PORT"
        echo "3. 检查 Python 环境: python3 --version"
        echo "4. 重新安装: ./install-openwebui.sh"
        exit 1
    fi
}

# 错误处理
trap 'log_error "启动过程中发生错误"; exit 1' ERR

# 运行主函数
main "$@"