#!/bin/bash

# Open WebUI 系统诊断脚本
# 作者: AI Assistant
# 版本: 1.0.0
# 日期: 2025-01-01

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  Open WebUI 系统诊断                        ║"
    echo "║                                                              ║"
    echo "║  检查系统环境、依赖和配置状态                                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查操作系统
check_os() {
    echo ""
    log_info "检查操作系统..."
    
    local os_name=$(uname -s)
    local os_version=""
    
    case "$os_name" in
        Darwin*)
            os_version=$(sw_vers -productVersion 2>/dev/null || echo "未知版本")
            log_success "macOS $os_version"
            ;;
        Linux*)
            if [[ -f /etc/os-release ]]; then
                os_version=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
            else
                os_version="Linux $(uname -r)"
            fi
            log_success "$os_version"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            os_version="Windows ($(uname -r))"
            log_success "$os_version"
            ;;
        *)
            log_warning "未知操作系统: $os_name"
            ;;
    esac
    
    # 检查架构
    local arch=$(uname -m)
    log_info "系统架构: $arch"
}

# 检查 Python 环境
check_python() {
    echo ""
    log_info "检查 Python 环境..."
    
    local python_found=false
    local python_candidates=("python3.11" "python3.12" "python3" "python")
    
    for cmd in "${python_candidates[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            local version=$($cmd --version 2>&1 | cut -d' ' -f2)
            local major_minor=$(echo "$version" | cut -d'.' -f1-2)
            
            if [[ "$major_minor" == "3.11" ]] || [[ "$major_minor" == "3.12" ]]; then
                log_success "$cmd: $version (兼容)"
                python_found=true
                export PYTHON_CMD="$cmd"
            elif [[ "$major_minor" > "3.12" ]]; then
                log_warning "$cmd: $version (未测试版本)"
                python_found=true
                export PYTHON_CMD="$cmd"
            else
                log_warning "$cmd: $version (版本过低)"
            fi
        fi
    done
    
    if [[ "$python_found" == "false" ]]; then
        log_error "未找到兼容的 Python 版本"
        echo "  需要 Python 3.11 或 3.12"
        echo "  安装建议:"
        echo "    macOS: brew install python@3.11"
        echo "    Ubuntu: sudo apt install python3.11"
        return 1
    fi
    
    # 检查 pip
    if $PYTHON_CMD -m pip --version &> /dev/null; then
        local pip_version=$($PYTHON_CMD -m pip --version | cut -d' ' -f2)
        log_success "pip: $pip_version"
    else
        log_error "pip 不可用"
        return 1
    fi
}

# 检查 Open WebUI 安装
check_openwebui() {
    echo ""
    log_info "检查 Open WebUI 安装..."
    
    # 检查命令可用性
    if command -v open-webui &> /dev/null; then
        local version=$(open-webui --version 2>/dev/null || echo "未知版本")
        log_success "open-webui 命令: $version"
    else
        log_warning "open-webui 命令不在 PATH 中"
    fi
    
    # 检查 Python 模块
    if $PYTHON_CMD -c "import open_webui; print('模块导入成功')" 2>/dev/null; then
        log_success "Python 模块导入成功"
    else
        log_error "Python 模块导入失败"
        echo "  请运行: $PYTHON_CMD -m pip install open-webui"
        return 1
    fi
}

# 检查网络连接
check_network() {
    echo ""
    log_info "检查网络连接..."
    
    local test_urls=("https://pypi.org" "https://github.com" "https://google.com")
    local success_count=0
    
    for url in "${test_urls[@]}"; do
        if command -v curl &> /dev/null; then
            if curl -s --connect-timeout 10 "$url" > /dev/null 2>&1; then
                log_success "连接 $url"
                success_count=$((success_count + 1))
            else
                log_warning "无法连接 $url"
            fi
        elif command -v wget &> /dev/null; then
            if wget -q --timeout=10 --spider "$url" 2>/dev/null; then
                log_success "连接 $url"
                success_count=$((success_count + 1))
            else
                log_warning "无法连接 $url"
            fi
        else
            log_warning "无法测试网络连接 (缺少 curl 或 wget)"
            break
        fi
    done
    
    if [[ $success_count -eq 0 ]]; then
        log_error "网络连接失败"
        echo "  请检查网络设置或代理配置"
        return 1
    elif [[ $success_count -lt ${#test_urls[@]} ]]; then
        log_warning "部分网络连接失败"
    else
        log_success "网络连接正常"
    fi
}

# 检查端口状态
check_ports() {
    echo ""
    log_info "检查端口状态..."
    
    local ports=(8080 8081 11434)  # Open WebUI 和 Ollama 常用端口
    
    for port in "${ports[@]}"; do
        if command -v lsof &> /dev/null; then
            if lsof -i :$port &> /dev/null; then
                local process=$(lsof -i :$port | tail -1 | awk '{print $1}')
                log_warning "端口 $port 被占用 ($process)"
            else
                log_success "端口 $port 可用"
            fi
        elif command -v netstat &> /dev/null; then
            if netstat -ln | grep ":$port " &> /dev/null; then
                log_warning "端口 $port 可能被占用"
            else
                log_success "端口 $port 可用"
            fi
        else
            log_warning "无法检查端口状态 (缺少 lsof 或 netstat)"
            break
        fi
    done
}

# 检查磁盘空间
check_disk_space() {
    echo ""
    log_info "检查磁盘空间..."
    
    local current_dir=$(pwd)
    local available_mb
    
    if command -v df &> /dev/null; then
        available_mb=$(df "$current_dir" | tail -1 | awk '{print int($4/1024)}')
        
        if [[ $available_mb -gt 2048 ]]; then
            log_success "可用空间: ${available_mb}MB"
        elif [[ $available_mb -gt 1024 ]]; then
            log_warning "可用空间: ${available_mb}MB (建议至少 2GB)"
        else
            log_error "可用空间不足: ${available_mb}MB (需要至少 2GB)"
            return 1
        fi
    else
        log_warning "无法检查磁盘空间"
    fi
}

# 检查进程状态
check_processes() {
    echo ""
    log_info "检查 Open WebUI 进程..."
    
    local pids=$(pgrep -f "open-webui serve" 2>/dev/null || true)
    
    if [[ -n "$pids" ]]; then
        log_success "找到运行中的进程:"
        while IFS= read -r pid; do
            if command -v ps &> /dev/null; then
                local info=$(ps -p "$pid" -o pid,user,comm,args --no-headers 2>/dev/null || echo "PID $pid")
                echo "    $info"
            else
                echo "    PID: $pid"
            fi
        done <<< "$pids"
    else
        log_info "未找到运行中的 Open WebUI 进程"
    fi
    
    # 检查 PID 文件
    if [[ -f "logs/openwebui.pid" ]]; then
        local stored_pid=$(cat logs/openwebui.pid)
        if kill -0 "$stored_pid" 2>/dev/null; then
            log_success "PID 文件有效: $stored_pid"
        else
            log_warning "PID 文件存在但进程不存在: $stored_pid"
        fi
    fi
}

# 检查配置文件
check_config() {
    echo ""
    log_info "检查配置文件..."
    
    local config_files=(".env" "config.yaml" ".webui_secret_key")
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "配置文件存在: $file"
            
            # 检查文件权限
            if [[ "$file" == ".webui_secret_key" ]]; then
                local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null || echo "unknown")
                if [[ "$perms" == "600" ]]; then
                    log_success "密钥文件权限正确: $perms"
                else
                    log_warning "密钥文件权限不安全: $perms (建议 600)"
                fi
            fi
        else
            log_info "配置文件不存在: $file"
        fi
    done
}

# 主函数
main() {
    show_banner
    
    log_info "开始系统诊断..."
    
    local failed_checks=0
    
    # 执行所有检查
    check_os || failed_checks=$((failed_checks + 1))
    check_python || failed_checks=$((failed_checks + 1))
    check_openwebui || failed_checks=$((failed_checks + 1))
    check_network || failed_checks=$((failed_checks + 1))
    check_ports || failed_checks=$((failed_checks + 1))
    check_disk_space || failed_checks=$((failed_checks + 1))
    check_processes || failed_checks=$((failed_checks + 1))
    check_config || failed_checks=$((failed_checks + 1))
    
    # 显示结果
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                      诊断完成                                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ $failed_checks -eq 0 ]]; then
        log_success "所有检查通过！系统状态良好"
        echo ""
        echo "您可以运行以下命令启动 Open WebUI:"
        echo "  ./start-openwebui.sh"
    else
        log_warning "发现 $failed_checks 个问题"
        echo ""
        echo "建议的解决步骤:"
        echo "1. 查看上述错误信息"
        echo "2. 运行安装脚本: ./install-openwebui.sh"
        echo "3. 检查网络连接和防火墙设置"
        echo "4. 查看日志文件: tail -f logs/openwebui.log"
    fi
    
    echo ""
    echo "如需更多帮助，请查看 README.md 或运行:"
    echo "  ./install-openwebui.sh --help"
}

# 运行主函数
main "$@"