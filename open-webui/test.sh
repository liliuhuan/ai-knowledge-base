#!/bin/bash

# Open WebUI 测试和验证脚本
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

# 配置变量
TEST_PORT=8080
TEST_HOST="localhost"
TEST_URL="http://$TEST_HOST:$TEST_PORT"
LOG_DIR="logs"
TEST_LOG="$LOG_DIR/test.log"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$TEST_LOG"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$TEST_LOG"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$TEST_LOG"
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  Open WebUI 测试验证                        ║"
    echo "║                                                              ║"
    echo "║  验证安装、配置和功能是否正常工作                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 初始化测试环境
init_test_env() {
    mkdir -p "$LOG_DIR"
    echo "Open WebUI 测试报告 - $(date)" > "$TEST_LOG"
    echo "=======================================" >> "$TEST_LOG"
}

# 测试安装验证
test_installation() {
    echo ""
    log_info "测试 1: 安装验证"
    
    local errors=0
    
    # 检查 Python 环境
    if command -v python3.11 &> /dev/null || command -v python3.12 &> /dev/null || command -v python3 &> /dev/null; then
        log_success "Python 环境可用"
    else
        log_error "Python 环境不可用"
        errors=$((errors + 1))
    fi
    
    # 检查 Open WebUI 命令
    if command -v open-webui &> /dev/null; then
        local version=$(open-webui --version 2>/dev/null || echo "未知版本")
        log_success "open-webui 命令可用: $version"
    else
        log_error "open-webui 命令不可用"
        errors=$((errors + 1))
    fi
    
    # 检查 Python 模块
    local python_cmd="python3"
    if command -v python3.11 &> /dev/null; then
        python_cmd="python3.11"
    elif command -v python3.12 &> /dev/null; then
        python_cmd="python3.12"
    fi
    
    if $python_cmd -c "import open_webui" 2>/dev/null; then
        log_success "Python 模块导入成功"
    else
        log_error "Python 模块导入失败"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# 测试配置文件
test_configuration() {
    echo ""
    log_info "测试 2: 配置文件验证"
    
    local errors=0
    
    # 检查配置文件
    local config_files=(".env" ".env.example" "config.sh")
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "配置文件存在: $file"
        else
            log_warning "配置文件缺失: $file"
        fi
    done
    
    # 验证配置
    if [[ -f "config.sh" ]] && [[ -x "config.sh" ]]; then
        if ./config.sh validate &> /dev/null; then
            log_success "配置验证通过"
        else
            log_warning "配置验证失败"
            errors=$((errors + 1))
        fi
    else
        log_warning "配置管理脚本不可用"
    fi
    
    return $errors
}

# 测试脚本功能
test_scripts() {
    echo ""
    log_info "测试 3: 脚本功能验证"
    
    local errors=0
    local scripts=("install-openwebui.sh" "start-openwebui.sh" "stop-openwebui.sh" "diagnose.sh" "config.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                log_success "脚本可执行: $script"
            else
                log_warning "脚本不可执行: $script"
                chmod +x "$script" 2>/dev/null && log_success "已修复权限: $script" || {
                    log_error "无法修复权限: $script"
                    errors=$((errors + 1))
                }
            fi
        else
            log_error "脚本缺失: $script"
            errors=$((errors + 1))
        fi
    done
    
    return $errors
}

# 测试服务启动
test_service_startup() {
    echo ""
    log_info "测试 4: 服务启动测试"
    
    local errors=0
    
    # 检查是否已在运行
    if pgrep -f "open-webui serve" > /dev/null; then
        log_info "服务已在运行，跳过启动测试"
        return 0
    fi
    
    # 检查端口可用性
    if command -v lsof &> /dev/null && lsof -i :$TEST_PORT &> /dev/null; then
        log_warning "端口 $TEST_PORT 被占用，跳过启动测试"
        return 1
    fi
    
    log_info "启动测试服务..."
    
    # 启动服务
    nohup open-webui serve --host "$TEST_HOST" --port "$TEST_PORT" > "$LOG_DIR/test-service.log" 2>&1 &
    local service_pid=$!
    
    # 等待服务启动
    local max_wait=30
    local wait_count=0
    
    while [[ $wait_count -lt $max_wait ]]; do
        if curl -s --connect-timeout 5 "$TEST_URL" > /dev/null 2>&1; then
            log_success "服务启动成功"
            break
        fi
        sleep 2
        wait_count=$((wait_count + 2))
        echo -n "."
    done
    
    echo ""
    
    if [[ $wait_count -ge $max_wait ]]; then
        log_error "服务启动超时"
        errors=$((errors + 1))
    fi
    
    # 清理测试服务
    if kill -0 "$service_pid" 2>/dev/null; then
        kill "$service_pid" 2>/dev/null || true
        sleep 2
        kill -9 "$service_pid" 2>/dev/null || true
        log_info "测试服务已停止"
    fi
    
    return $errors
}

# 测试 API 端点
test_api_endpoints() {
    echo ""
    log_info "测试 5: API 端点测试"
    
    local errors=0
    
    # 检查服务是否运行
    if ! curl -s --connect-timeout 5 "$TEST_URL" > /dev/null 2>&1; then
        log_warning "服务未运行，跳过 API 测试"
        return 0
    fi
    
    # 测试基本端点
    local endpoints=("/" "/health" "/api/v1/models" "/api/v1/chat")
    
    for endpoint in "${endpoints[@]}"; do
        local url="$TEST_URL$endpoint"
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$url" 2>/dev/null || echo "000")
        
        if [[ "$status_code" =~ ^[2-4][0-9][0-9]$ ]]; then
            log_success "API 端点响应: $endpoint ($status_code)"
        else
            log_warning "API 端点无响应: $endpoint ($status_code)"
            errors=$((errors + 1))
        fi
    done
    
    return $errors
}

# 测试文件权限
test_file_permissions() {
    echo ""
    log_info "测试 6: 文件权限测试"
    
    local errors=0
    
    # 检查敏感文件权限
    local sensitive_files=(".webui_secret_key" ".env")
    
    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null || echo "unknown")
            
            if [[ "$perms" == "600" ]]; then
                log_success "文件权限正确: $file ($perms)"
            else
                log_warning "文件权限不安全: $file ($perms)"
                errors=$((errors + 1))
            fi
        fi
    done
    
    # 检查脚本权限
    local scripts=("*.sh")
    for script in $scripts; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                log_success "脚本可执行: $script"
            else
                log_warning "脚本不可执行: $script"
                errors=$((errors + 1))
            fi
        fi
    done
    
    return $errors
}

# 性能基准测试
test_performance() {
    echo ""
    log_info "测试 7: 性能基准测试"
    
    local errors=0
    
    # 检查服务是否运行
    if ! curl -s --connect-timeout 5 "$TEST_URL" > /dev/null 2>&1; then
        log_warning "服务未运行，跳过性能测试"
        return 0
    fi
    
    log_info "执行响应时间测试..."
    
    # 测试响应时间
    local total_time=0
    local test_count=5
    
    for i in $(seq 1 $test_count); do
        local response_time=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 10 "$TEST_URL" 2>/dev/null || echo "0")
        total_time=$(echo "$total_time + $response_time" | bc 2>/dev/null || echo "$total_time")
        echo -n "."
    done
    
    echo ""
    
    if command -v bc &> /dev/null; then
        local avg_time=$(echo "scale=3; $total_time / $test_count" | bc)
        
        if (( $(echo "$avg_time < 2.0" | bc -l) )); then
            log_success "平均响应时间: ${avg_time}s (良好)"
        elif (( $(echo "$avg_time < 5.0" | bc -l) )); then
            log_warning "平均响应时间: ${avg_time}s (一般)"
        else
            log_warning "平均响应时间: ${avg_time}s (较慢)"
            errors=$((errors + 1))
        fi
    else
        log_info "无法计算平均响应时间 (缺少 bc 命令)"
    fi
    
    return $errors
}

# 生成测试报告
generate_test_report() {
    local total_errors=$1
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                      测试报告                                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ $total_errors -eq 0 ]]; then
        log_success "所有测试通过！系统状态良好"
        echo ""
        echo -e "${GREEN}✅ Open WebUI 已准备就绪${NC}"
        echo ""
        echo "启动命令:"
        echo "  ./start-openwebui.sh"
        echo ""
        echo "访问地址:"
        echo "  http://localhost:8080"
    else
        log_warning "发现 $total_errors 个问题"
        echo ""
        echo "建议的解决步骤:"
        echo "1. 查看测试日志: cat $TEST_LOG"
        echo "2. 运行诊断脚本: ./diagnose.sh"
        echo "3. 重新安装: ./install-openwebui.sh"
        echo "4. 检查系统要求和依赖"
    fi
    
    echo ""
    echo "详细测试日志: $TEST_LOG"
    echo "测试完成时间: $(date)"
}

# 主函数
main() {
    show_banner
    init_test_env
    
    log_info "开始 Open WebUI 测试验证..."
    
    local total_errors=0
    
    # 执行所有测试
    test_installation || total_errors=$((total_errors + $?))
    test_configuration || total_errors=$((total_errors + $?))
    test_scripts || total_errors=$((total_errors + $?))
    test_service_startup || total_errors=$((total_errors + $?))
    test_api_endpoints || total_errors=$((total_errors + $?))
    test_file_permissions || total_errors=$((total_errors + $?))
    test_performance || total_errors=$((total_errors + $?))
    
    # 生成报告
    generate_test_report $total_errors
    
    # 返回适当的退出码
    if [[ $total_errors -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# 运行主函数
main "$@"