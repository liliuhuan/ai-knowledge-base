#!/bin/bash

# Open WebUI 配置管理脚本
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

# 配置文件路径
ENV_FILE=".env"
ENV_EXAMPLE=".env.example"
CONFIG_DIR="config"

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

# 显示帮助信息
show_help() {
    echo "Open WebUI 配置管理工具"
    echo ""
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  init          初始化配置文件"
    echo "  show          显示当前配置"
    echo "  set KEY VALUE 设置配置项"
    echo "  get KEY       获取配置项"
    echo "  validate      验证配置"
    echo "  backup        备份配置"
    echo "  restore FILE  恢复配置"
    echo "  reset         重置为默认配置"
    echo ""
    echo "选项:"
    echo "  -h, --help    显示此帮助信息"
    echo "  -v, --verbose 详细输出"
    echo ""
    echo "示例:"
    echo "  $0 init                    # 初始化配置"
    echo "  $0 set OPENWEBUI_PORT 8081 # 设置端口"
    echo "  $0 get OPENWEBUI_PORT      # 获取端口"
    echo "  $0 validate                # 验证配置"
}

# 初始化配置
init_config() {
    log_info "初始化配置文件..."
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    # 如果 .env 文件不存在，从示例文件复制
    if [[ ! -f "$ENV_FILE" ]]; then
        if [[ -f "$ENV_EXAMPLE" ]]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            log_success "从示例文件创建配置: $ENV_FILE"
        else
            log_error "示例配置文件不存在: $ENV_EXAMPLE"
            return 1
        fi
    else
        log_warning "配置文件已存在: $ENV_FILE"
    fi
    
    # 生成密钥
    generate_secret_key
    
    # 设置权限
    chmod 600 "$ENV_FILE"
    log_success "设置配置文件权限: 600"
    
    log_success "配置初始化完成"
}

# 生成密钥
generate_secret_key() {
    local secret_key_file=".webui_secret_key"
    
    if [[ ! -f "$secret_key_file" ]]; then
        log_info "生成密钥文件..."
        
        # 生成随机密钥
        if command -v openssl &> /dev/null; then
            openssl rand -hex 32 > "$secret_key_file"
        elif command -v python3 &> /dev/null; then
            python3 -c "import secrets; print(secrets.token_hex(32))" > "$secret_key_file"
        else
            # 备用方法
            date +%s | sha256sum | base64 | head -c 64 > "$secret_key_file"
        fi
        
        chmod 600 "$secret_key_file"
        log_success "密钥文件已生成: $secret_key_file"
    else
        log_info "密钥文件已存在: $secret_key_file"
    fi
}

# 显示配置
show_config() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "配置文件不存在: $ENV_FILE"
        echo "请先运行: $0 init"
        return 1
    fi
    
    log_info "当前配置:"
    echo ""
    
    # 按类别显示配置
    local categories=("服务器配置" "日志配置" "功能配置" "安全配置" "AI 提供商配置")
    local patterns=("OPENWEBUI_\|WORKERS" "LOG_" "ENABLE_\|AUTO_" "SECRET\|JWT\|MAX_FILE" "API_KEY\|OLLAMA\|ANTHROPIC")
    
    for i in "${!categories[@]}"; do
        echo -e "${BLUE}${categories[$i]}:${NC}"
        grep -E "^[^#]*${patterns[$i]}" "$ENV_FILE" | while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local key=$(echo "$line" | cut -d'=' -f1)
                local value=$(echo "$line" | cut -d'=' -f2-)
                
                # 隐藏敏感信息
                if [[ "$key" =~ (SECRET|KEY|PASSWORD) ]]; then
                    value="***隐藏***"
                fi
                
                echo "  $key = $value"
            fi
        done
        echo ""
    done
}

# 设置配置项
set_config() {
    local key="$1"
    local value="$2"
    
    if [[ -z "$key" ]] || [[ -z "$value" ]]; then
        log_error "用法: $0 set KEY VALUE"
        return 1
    fi
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "配置文件不存在: $ENV_FILE"
        echo "请先运行: $0 init"
        return 1
    fi
    
    # 检查键是否已存在
    if grep -q "^$key=" "$ENV_FILE"; then
        # 更新现有配置
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^$key=.*/$key=$value/" "$ENV_FILE"
        else
            sed -i "s/^$key=.*/$key=$value/" "$ENV_FILE"
        fi
        log_success "更新配置: $key = $value"
    else
        # 添加新配置
        echo "$key=$value" >> "$ENV_FILE"
        log_success "添加配置: $key = $value"
    fi
}

# 获取配置项
get_config() {
    local key="$1"
    
    if [[ -z "$key" ]]; then
        log_error "用法: $0 get KEY"
        return 1
    fi
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "配置文件不存在: $ENV_FILE"
        return 1
    fi
    
    local value=$(grep "^$key=" "$ENV_FILE" | cut -d'=' -f2-)
    
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        log_warning "配置项不存在: $key"
        return 1
    fi
}

# 验证配置
validate_config() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "配置文件不存在: $ENV_FILE"
        return 1
    fi
    
    log_info "验证配置文件..."
    
    local errors=0
    
    # 检查必需的配置项
    local required_keys=("OPENWEBUI_PORT" "OPENWEBUI_HOST" "LOG_LEVEL")
    
    for key in "${required_keys[@]}"; do
        if ! grep -q "^$key=" "$ENV_FILE"; then
            log_error "缺少必需配置: $key"
            errors=$((errors + 1))
        fi
    done
    
    # 验证端口号
    local port=$(get_config "OPENWEBUI_PORT" 2>/dev/null || echo "")
    if [[ -n "$port" ]]; then
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
            log_error "无效的端口号: $port"
            errors=$((errors + 1))
        fi
    fi
    
    # 验证日志级别
    local log_level=$(get_config "LOG_LEVEL" 2>/dev/null || echo "")
    if [[ -n "$log_level" ]]; then
        local valid_levels=("DEBUG" "INFO" "WARNING" "ERROR" "CRITICAL")
        if [[ ! " ${valid_levels[@]} " =~ " ${log_level} " ]]; then
            log_error "无效的日志级别: $log_level"
            errors=$((errors + 1))
        fi
    fi
    
    # 检查文件权限
    local perms=$(stat -c "%a" "$ENV_FILE" 2>/dev/null || stat -f "%A" "$ENV_FILE" 2>/dev/null || echo "unknown")
    if [[ "$perms" != "600" ]]; then
        log_warning "配置文件权限不安全: $perms (建议 600)"
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "配置验证通过"
        return 0
    else
        log_error "发现 $errors 个配置错误"
        return 1
    fi
}

# 备份配置
backup_config() {
    local backup_dir="$CONFIG_DIR/backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$backup_dir/config-backup-$timestamp.tar.gz"
    
    mkdir -p "$backup_dir"
    
    log_info "备份配置文件..."
    
    # 创建备份
    tar -czf "$backup_file" "$ENV_FILE" .webui_secret_key 2>/dev/null || {
        log_error "备份失败"
        return 1
    }
    
    log_success "配置已备份到: $backup_file"
    
    # 清理旧备份 (保留最近 10 个)
    local backup_count=$(ls -1 "$backup_dir"/config-backup-*.tar.gz 2>/dev/null | wc -l)
    if [[ $backup_count -gt 10 ]]; then
        log_info "清理旧备份文件..."
        ls -1t "$backup_dir"/config-backup-*.tar.gz | tail -n +11 | xargs rm -f
    fi
}

# 恢复配置
restore_config() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        log_error "用法: $0 restore BACKUP_FILE"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "备份文件不存在: $backup_file"
        return 1
    fi
    
    log_info "恢复配置文件..."
    
    # 备份当前配置
    if [[ -f "$ENV_FILE" ]]; then
        cp "$ENV_FILE" "$ENV_FILE.bak"
        log_info "当前配置已备份为: $ENV_FILE.bak"
    fi
    
    # 恢复配置
    if tar -xzf "$backup_file" 2>/dev/null; then
        log_success "配置已从备份恢复: $backup_file"
    else
        log_error "恢复失败"
        
        # 恢复备份
        if [[ -f "$ENV_FILE.bak" ]]; then
            mv "$ENV_FILE.bak" "$ENV_FILE"
            log_info "已恢复原配置"
        fi
        
        return 1
    fi
}

# 重置配置
reset_config() {
    log_warning "这将重置所有配置为默认值"
    read -p "确定要继续吗? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        return 0
    fi
    
    # 备份当前配置
    if [[ -f "$ENV_FILE" ]]; then
        backup_config
    fi
    
    # 重置配置
    if [[ -f "$ENV_EXAMPLE" ]]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        log_success "配置已重置为默认值"
    else
        log_error "示例配置文件不存在: $ENV_EXAMPLE"
        return 1
    fi
}

# 主函数
main() {
    local command="$1"
    
    case "$command" in
        "init")
            init_config
            ;;
        "show")
            show_config
            ;;
        "set")
            set_config "$2" "$3"
            ;;
        "get")
            get_config "$2"
            ;;
        "validate")
            validate_config
            ;;
        "backup")
            backup_config
            ;;
        "restore")
            restore_config "$2"
            ;;
        "reset")
            reset_config
            ;;
        "-h"|"--help"|"help"|"")
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"