#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 创建必要的目录
mkdir -p /usr/local/vps-backup
mkdir -p /etc/vps_backup
mkdir -p /var/log/vps_backup
mkdir -p /tmp/vps_backup

# 复制文件到指定位置
cp backup.sh /usr/local/vps-backup/
chmod +x /usr/local/vps-backup/backup.sh

# 创建软链接使脚本全局可用
ln -sf /usr/local/vps-backup/backup.sh /usr/local/bin/vps-backup

# 如果cron.d目录不存在则创建
mkdir -p /etc/cron.d

# 复制cron配置文件（如果存在）
if [ -f "backup.cron" ]; then
    cp backup.cron /etc/cron.d/vps_backup
    chmod 644 /etc/cron.d/vps_backup
fi

echo "安装完成！"
echo "您可以通过以下命令使用备份工具："
echo "vps-backup"
echo ""
echo "首次运行时，请先配置备份目录和其他设置。"
