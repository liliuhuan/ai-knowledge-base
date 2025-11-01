#!/bin/bash

# Open WebUI 停止脚本
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
LOG_DIR="logs"
STARTUP_LOG="$LOG_DIR/startup.log"
PID_FILE="$LOG_DIR/openwebui.pid"
GRACEFUL_TIMEOUT=10
FORCE_TIMEOUT=5

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
    echo "║                    Open WebUI 停止器                        ║"
    echo "║                                                              ║"
    echo "║  优雅停止 Open WebUI 服务并清理相关进程                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 创建日志目录
create_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
    fi
}

# 查找进程
find_processes() {
    local pids=()
    
    # 从 PID 文件查找
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            pids+=("$pid")
        fi
    fi
    
    # 通过进程名查找
    local process_pids=$(pgrep -f "open-webui serve" 2>/dev/null || true)
    if [[ -n "$process_pids" ]]; then
        while IFS= read -r pid; do
            if [[ ! " ${pids[@]} " =~ " ${pid} " ]]; then
                pids+=("$pid")
            fi
        done <<< "$process_pids"
    fi
    
    echo "${pids[@]}"
}

# 获取进程信息
get_process_info() {
    local pid=$1
    local info=""
    
    if command -v ps &> /dev/null; then
        info=$(ps -p "$pid" -o pid,ppid,user,comm,args --no-headers 2>/dev/null || echo "")
    fi
    
    echo "$info"
}

# 优雅停止进程
graceful_stop() {
    local pid=$1
    local timeout=${2:-$GRACEFUL_TIMEOUT}
    
    log_info "发送 SIGTERM 信号到进程 $pid..."
    
    if kill -TERM "$pid" 2>/dev/null; then
        local count=0
        while [[ $count -lt $timeout ]]; do
            if ! kill -0 "$pid" 2>/dev/null; then
                log_success "进程 $pid 已优雅停止"
                return 0
            fi
            sleep 1
            count=$((count + 1))
            echo -n "."
        done
        echo ""
        log_warning "进程 $pid 在 ${timeout}s 内未响应 SIGTERM"
        return 1
    else
        log_warning "无法发送 SIGTERM 信号到进程 $pid"
        return 1
    fi
}

# 强制停止进程
force_stop() {
    local pid=$1
    local timeout=${2:-$FORCE_TIMEOUT}
    
    log_warning "强制停止进程 $pid..."
    
    if kill -KILL "$pid" 2>/dev/null; then
        local count=0
        while [[ $count -lt $timeout ]]; do
            if ! kill -0 "$pid" 2>/dev/null; then
                log_success "进程 $pid 已强制停止"
                return 0
            fi
            sleep 1
            count=$((count + 1))
        done
        log_error "无法强制停止进程 $pid"
        return 1
    else
        log_warning "无法发送 SIGKILL 信号到进程 $pid"
        return 1
    fi
}

# 清理子进程
cleanup_children() {
    local parent_pid=$1
    
    if command -v pgrep &> /dev/null; then
        local children=$(pgrep -P "$parent_pid" 2>/dev/null || true)
        if [[ -n "$children" ]]; then
            log_info "清理子进程..."
            while IFS= read -r child_pid; do
                if kill -0 "$child_pid" 2>/dev/null; then
                    log_info "停止子进程: $child_pid"
                    kill -TERM "$child_pid" 2>/dev/null || true
                    sleep 1
                    if kill -0 "$child_pid" 2>/dev/null; then
                        kill -KILL "$child_pid" 2>/dev/null || true
                    fi
                fi
            done <<< "$children"
        fi
    fi
}

# 清理临时文件
cleanup_files() {
    log_info "清理临时文件..."
    
    # 清理 PID 文件
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
        log_success "清理 PID 文件: $PID_FILE"
    fi
    
    # 清理可能的锁文件
    local lock_files=(".webui.lock" "data/.lock" "logs/.lock")
    for lock_file in "${lock_files[@]}"; do
        if [[ -f "$lock_file" ]]; then
            rm -f "$lock_file"
            log_success "清理锁文件: $lock_file"
        fi
    done
    
    # 清理临时目录
    if [[ -d "/tmp/open-webui" ]]; then
        rm -rf "/tmp/open-webui"
        log_success "清理临时目录: /tmp/open-webui"
    fi
}

# 检查端口状态
check_port_status() {
    local port=${1:-8080}
    
    if command -v lsof &> /dev/null; then
        if lsof -i :$port &> /dev/null; then
            log_warning "端口 $port 仍被占用"
            lsof -i :$port
            return 1
        else
            log_success "端口 $port 已释放"
            return 0
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -ln | grep ":$port " &> /dev/null; then
            log_warning "端口 $port 可能仍被占用"
            return 1
        else
            log_success "端口 $port 已释放"
            return 0
        fi
    else
        log_info "无法检查端口状态 (缺少 lsof 或 netstat)"
        return 0
    fi
}

# 显示停止状态
show_stop_status() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    🛑 停止完成! 🛑                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}状态信息:${NC}"
    echo -e "  服务状态: ${GREEN}已停止${NC}"
    echo -e "  端口状态: ${GREEN}已释放${NC}"
    echo -e "  进程清理: ${GREEN}完成${NC}"
    echo ""
    echo -e "${BLUE}重新启动:${NC}"
    echo -e "  启动服务: ${YELLOW}./start-openwebui.sh${NC}"
    echo -e "  查看日志: ${YELLOW}tail -f logs/openwebui.log${NC}"
    echo ""
}

# 主函数
main() {
    show_banner
    create_log_dir
    
    log_info "开始停止 Open WebUI..."
    
    # 查找所有相关进程
    local pids=($(find_processes))
    
    if [[ ${#pids[@]} -eq 0 ]]; then
        log_info "未找到运行中的 Open WebUI 进程"
        cleanup_files
        check_port_status
        echo ""
        echo -e "${YELLOW}ℹ️  Open WebUI 未在运行${NC}"
        exit 0
    fi
    
    log_info "找到 ${#pids[@]} 个相关进程"
    
    # 显示进程信息
    for pid in "${pids[@]}"; do
        local info=$(get_process_info "$pid")
        if [[ -n "$info" ]]; then
            echo "  PID $pid: $info"
        else
            echo "  PID $pid: (无法获取详细信息)"
        fi
    done
    
    echo ""
    
    # 停止所有进程
    local stopped_count=0
    local failed_count=0
    
    for pid in "${pids[@]}"; do
        log_info "停止进程 $pid..."
        
        # 清理子进程
        cleanup_children "$pid"
        
        # 尝试优雅停止
        if graceful_stop "$pid"; then
            stopped_count=$((stopped_count + 1))
        else
            # 强制停止
            if force_stop "$pid"; then
                stopped_count=$((stopped_count + 1))
            else
                failed_count=$((failed_count + 1))
                log_error "无法停止进程 $pid"
            fi
        fi
    done
    
    # 清理文件和检查状态
    cleanup_files
    
    # 等待一下再检查端口
    sleep 2
    check_port_status
    
    # 显示结果
    echo ""
    if [[ $failed_count -eq 0 ]]; then
        log_success "所有进程已成功停止 ($stopped_count/$((stopped_count + failed_count)))"
        show_stop_status
    else
        log_warning "部分进程停止失败 ($stopped_count/$((stopped_count + failed_count)) 成功)"
        echo ""
        echo "故障排除建议:"
        echo "1. 检查是否有权限问题"
        echo "2. 手动查找残留进程: ps aux | grep open-webui"
        echo "3. 强制清理: sudo pkill -9 -f open-webui"
        echo "4. 重启系统以完全清理"
        exit 1
    fi
}

# 错误处理
trap 'log_error "停止过程中发生错误"; exit 1' ERR

# 运行主函数
main "$@"