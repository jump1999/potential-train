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
    
    # 运行安装脚本
    print_info "正在安装..."
    chmod +x install.sh
    ./install.sh
    
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
    print_info "详细说明请查看：https://github.com/jump1999/potential-train"
}

main() {
    echo "================================================"
    echo "              VPS备份工具一键安装脚本"
    echo "================================================"
    echo ""
    
    # 执行安装步骤
    check_system
    install_dependencies
    install_backup_tool
    show_usage
}

main
