#!/bin/bash

# Open WebUI 自动安装脚本
# 作者: AI Assistant
# 版本: 1.0.0
# 日期: 2025-01-01

set -e  # 遇到错误立即退出

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Open WebUI 安装器                        ║"
    echo "║                                                              ║"
    echo "║  自动化安装 Open WebUI 及其所有依赖                         ║"
    echo "║  支持 macOS、Linux 和 Windows                                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macOS"
            ;;
        Linux*)
            OS="Linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            OS="Windows"
            ;;
        *)
            OS="Unknown"
            ;;
    esac
    log_info "检测到操作系统: $OS"
}

# 检查 Python 版本
check_python() {
    log_info "检查 Python 环境..."
    
    # 尝试不同的 Python 命令
    local python_candidates=("python3.11" "python3.12" "python3" "python")
    local python_cmd=""
    local python_version=""
    
    for cmd in "${python_candidates[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            python_version=$($cmd --version 2>&1 | cut -d' ' -f2)
            local major_minor=$(echo "$python_version" | cut -d'.' -f1-2)
            
            # 检查版本是否符合要求 (3.11 或 3.12)
            if [[ "$major_minor" == "3.11" ]] || [[ "$major_minor" == "3.12" ]]; then
                python_cmd="$cmd"
                break
            elif [[ "$major_minor" > "3.12" ]]; then
                log_warning "Python $python_version 未经测试，可能存在兼容性问题"
                python_cmd="$cmd"
                break
            fi
        fi
    done
    
    if [[ -z "$python_cmd" ]]; then
        log_error "未找到兼容的 Python 版本 (需要 3.11 或 3.12)"
        echo ""
        echo "请安装 Python 3.11 或 3.12:"
        echo ""
        case "$OS" in
            "macOS")
                echo "  brew install python@3.11"
                ;;
            "Linux")
                echo "  # Ubuntu/Debian:"
                echo "  sudo apt update"
                echo "  sudo apt install python3.11 python3.11-venv python3.11-pip"
                echo ""
                echo "  # CentOS/RHEL:"
                echo "  sudo yum install python3.11"
                ;;
            "Windows")
                echo "  从 https://www.python.org/downloads/ 下载并安装 Python 3.11"
                ;;
        esac
        exit 1
    fi
    
    export PYTHON_CMD="$python_cmd"
    log_success "Python 检查通过: $python_cmd ($python_version)"
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 10 https://pypi.org > /dev/null; then
            log_success "网络连接正常"
        else
            log_warning "无法连接到 PyPI，可能需要配置代理或使用镜像源"
        fi
    elif command -v wget &> /dev/null; then
        if wget -q --timeout=10 --spider https://pypi.org; then
            log_success "网络连接正常"
        else
            log_warning "无法连接到 PyPI，可能需要配置代理或使用镜像源"
        fi
    else
        log_warning "无法检查网络连接 (curl 和 wget 都不可用)"
    fi
}

# 检查磁盘空间
check_disk_space() {
    log_info "检查磁盘空间..."
    
    local required_space=2048  # 2GB in MB
    local available_space
    
    case "$OS" in
        "macOS"|"Linux")
            available_space=$(df . | tail -1 | awk '{print int($4/1024)}')
            ;;
        "Windows")
            # Windows 下的磁盘空间检查
            available_space=$(df . | tail -1 | awk '{print int($4/1024)}')
            ;;
    esac
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "磁盘空间不足: 需要 ${required_space}MB，可用 ${available_space}MB"
        exit 1
    else
        log_success "磁盘空间充足: ${available_space}MB 可用"
    fi
}

# 检查端口占用
check_port() {
    local port=${1:-8080}
    log_info "检查端口 $port 是否可用..."
    
    if command -v lsof &> /dev/null; then
        if lsof -i :$port &> /dev/null; then
            log_warning "端口 $port 已被占用"
            echo "占用进程:"
            lsof -i :$port
            echo ""
            read -p "是否终止占用进程并继续? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "终止占用进程..."
                kill -9 $(lsof -t -i:$port) 2>/dev/null || true
                log_success "端口 $port 已释放"
            else
                log_info "您可以稍后使用不同端口启动: PORT=8081 open-webui serve"
            fi
        else
            log_success "端口 $port 可用"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -ln | grep ":$port " &> /dev/null; then
            log_warning "端口 $port 可能已被占用"
        else
            log_success "端口 $port 可用"
        fi
    else
        log_warning "无法检查端口占用状态"
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    local dirs=("logs" "data" "config")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "创建目录: $dir"
        fi
    done
}

# 安装 Open WebUI
install_openwebui() {
    log_info "开始安装 Open WebUI..."
    
    # 创建安装日志
    local install_log="logs/install.log"
    mkdir -p logs
    
    # 升级 pip
    log_info "升级 pip..."
    if ! $PYTHON_CMD -m pip install --upgrade pip >> "$install_log" 2>&1; then
        log_warning "pip 升级失败，继续安装..."
    fi
    
    # 安装 Open WebUI
    log_info "安装 Open WebUI (这可能需要几分钟)..."
    
    # 尝试不同的安装方法
    local install_success=false
    
    # 方法1: 直接安装
    if $PYTHON_CMD -m pip install open-webui >> "$install_log" 2>&1; then
        install_success=true
    else
        log_warning "标准安装失败，尝试使用镜像源..."
        
        # 方法2: 使用清华镜像源
        if $PYTHON_CMD -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple open-webui >> "$install_log" 2>&1; then
            install_success=true
        else
            log_warning "镜像源安装失败，尝试用户安装..."
            
            # 方法3: 用户安装
            if $PYTHON_CMD -m pip install --user open-webui >> "$install_log" 2>&1; then
                install_success=true
            fi
        fi
    fi
    
    if [[ "$install_success" == "true" ]]; then
        log_success "Open WebUI 安装成功!"
    else
        log_error "Open WebUI 安装失败"
        echo ""
        echo "请查看安装日志: $install_log"
        echo "常见解决方案:"
        echo "1. 检查网络连接"
        echo "2. 更新 pip: $PYTHON_CMD -m pip install --upgrade pip"
        echo "3. 使用虚拟环境: $PYTHON_CMD -m venv venv && source venv/bin/activate"
        echo "4. 手动安装: $PYTHON_CMD -m pip install --user open-webui"
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 检查命令是否可用
    if command -v open-webui &> /dev/null; then
        local version=$(open-webui --version 2>/dev/null || echo "未知版本")
        log_success "Open WebUI 命令可用: $version"
    else
        log_warning "open-webui 命令不在 PATH 中"
        echo "您可能需要:"
        echo "1. 重新加载 shell: source ~/.bashrc 或 source ~/.zshrc"
        echo "2. 添加到 PATH: export PATH=\$PATH:\$HOME/.local/bin"
        echo "3. 使用完整路径: $PYTHON_CMD -m open_webui serve"
    fi
    
    # 测试导入
    if $PYTHON_CMD -c "import open_webui; print('✅ 模块导入成功')" 2>/dev/null; then
        log_success "Python 模块验证通过"
    else
        log_error "Python 模块导入失败"
        exit 1
    fi
}

# 设置权限
setup_permissions() {
    log_info "设置文件权限..."
    
    # 设置脚本可执行权限
    local scripts=("start-openwebui.sh" "stop-openwebui.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log_success "设置 $script 可执行权限"
        fi
    done
    
    # 设置目录权限
    chmod 755 logs/ data/ config/ 2>/dev/null || true
    
    # 保护密钥文件
    if [[ -f ".webui_secret_key" ]]; then
        chmod 600 .webui_secret_key
        log_success "设置密钥文件权限"
    fi
}

# 创建配置文件
create_config() {
    log_info "创建默认配置..."
    
    # 创建环境变量配置文件
    if [[ ! -f ".env" ]]; then
        cat > .env << EOF
# Open WebUI 配置文件
# 服务配置
OPENWEBUI_PORT=8080
OPENWEBUI_HOST=0.0.0.0

# 日志配置
LOG_LEVEL=INFO
LOG_FILE=logs/openwebui.log

# 功能配置
AUTO_OPEN_BROWSER=true

# AI 提供商配置 (可选)
# OPENAI_API_KEY=your-openai-key
# OLLAMA_BASE_URL=http://localhost:11434

# 数据库配置 (可选)
# DATABASE_URL=sqlite:///data/webui.db
EOF
        log_success "创建配置文件: .env"
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    🎉 安装完成! 🎉                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}下一步操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 启动 Open WebUI:"
    echo -e "     ${YELLOW}./start-openwebui.sh${NC}"
    echo ""
    echo -e "  ${GREEN}2.${NC} 或者直接运行:"
    echo -e "     ${YELLOW}open-webui serve${NC}"
    echo ""
    echo -e "  ${GREEN}3.${NC} 访问地址:"
    echo -e "     ${BLUE}http://localhost:8080${NC}"
    echo ""
    echo -e "${BLUE}管理命令:${NC}"
    echo -e "  启动服务: ${YELLOW}./start-openwebui.sh${NC}"
    echo -e "  停止服务: ${YELLOW}./stop-openwebui.sh${NC}"
    echo -e "  查看日志: ${YELLOW}tail -f logs/openwebui.log${NC}"
    echo ""
    echo -e "${BLUE}配置文件:${NC}"
    echo -e "  环境配置: ${YELLOW}.env${NC}"
    echo -e "  日志目录: ${YELLOW}logs/${NC}"
    echo -e "  数据目录: ${YELLOW}data/${NC}"
    echo ""
    echo -e "${GREEN}🚀 准备好开始使用 Open WebUI 了!${NC}"
    echo ""
}

# 主函数
main() {
    show_banner
    
    log_info "开始 Open WebUI 安装过程..."
    echo ""
    
    # 环境检查
    detect_os
    check_python
    check_network
    check_disk_space
    check_port 8080
    
    echo ""
    log_info "环境检查完成，开始安装..."
    echo ""
    
    # 安装过程
    create_directories
    install_openwebui
    verify_installation
    setup_permissions
    create_config
    
    # 完成
    show_completion
    
    # 询问是否立即启动
    echo ""
    read -p "是否现在启动 Open WebUI? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "您可以稍后运行 ./start-openwebui.sh 来启动服务"
    else
        log_info "正在启动 Open WebUI..."
        if [[ -f "./start-openwebui.sh" ]]; then
            ./start-openwebui.sh
        else
            open-webui serve
        fi
    fi
}

# 错误处理
trap 'log_error "安装过程中发生错误，请查看日志文件"; exit 1' ERR

# 运行主函数
main "$@"