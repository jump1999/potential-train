#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用root权限运行此脚本"
    print_info "使用方法: sudo bash quick_install.sh"
    exit 1
fi

# 检查系统要求
check_system() {
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "无法确定操作系统类型"
        exit 1
    fi
    
    print_info "检测到操作系统: $OS $VER"
}

# 安装依赖
install_dependencies() {
    print_info "正在安装必要的依赖..."
    
    if command -v apt-get >/dev/null; then
        # Debian/Ubuntu系统
        apt-get update
        apt-get install -y git curl tar rsync
    elif command -v yum >/dev/null; then
        # CentOS/RHEL系统
        yum install -y git curl tar rsync
    else
        print_error "不支持的包管理器"
        exit 1
    fi
}

# 下载和安装
install_backup_tool() {
    print_info "开始安装VPS备份工具..."
    
    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    cd $TMP_DIR
    
    # 下载代码
    print_info "正在下载代码..."
    git clone https://github.com/jump1999/potential-train.git
    if [ $? -ne 0 ]; then
        print_error "下载失败，请检查网络连接"
        exit 1
    fi
    
    cd potential-train/vps-backup
    
    # 创建必要的目录
    mkdir -p /usr/local/vps-backup
    mkdir -p /etc/vps_backup
    mkdir -p /var/log/vps_backup
    mkdir -p /tmp/vps_backup
    
    # 复制文件到指定位置
    cp src/backup.sh /usr/local/vps-backup/
    chmod +x /usr/local/vps-backup/backup.sh
    
    # 创建软链接使脚本全局可用
    ln -sf /usr/local/vps-backup/backup.sh /usr/local/bin/vps-backup
    
    # 如果cron.d目录不存在则创建
    mkdir -p /etc/cron.d
    
    # 复制cron配置文件（如果存在）
    if [ -f "src/backup.cron" ]; then
        cp src/backup.cron /etc/cron.d/vps_backup
        chmod 644 /etc/cron.d/vps_backup
    fi
    
    # 清理临时文件
    cd /
    rm -rf $TMP_DIR
}

# 显示使用说明
show_usage() {
    print_info "安装完成！"
    echo ""
    print_info "使用方法："
    echo "1. 运行配置向导："
    echo "   sudo vps-backup"
    echo ""
    echo "2. 执行备份："
    echo "   sudo vps-backup --backup full    # 完整备份"
    echo "   sudo vps-backup --backup incremental    # 增量备份"
    echo ""
    echo "3. 查看状态："
    echo "   sudo vps-backup --status"
    echo ""
    echo "4. 备份日志位置："
    echo "   /var/log/vps_backup/"
}

# 主函数
main() {
    check_system
    install_dependencies
    install_backup_tool
    show_usage
}

# 执行主函数
main
