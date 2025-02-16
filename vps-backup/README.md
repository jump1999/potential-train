# VPS 自动备份工具

一个简单但功能强大的 VPS 备份工具，支持完整备份和增量备份。

## 一键安装

```bash
# 方法1：使用curl直接安装
curl -fsSL https://raw.githubusercontent.com/jump1999/potential-train/main/vps-backup/scripts/quick_install.sh | sudo bash

# 方法2：手动下载并安装
git clone https://github.com/jump1999/potential-train.git
cd potential-train/vps-backup/scripts
sudo bash quick_install.sh
```

## 使用方法

安装完成后，备份工具会被安装到系统中，您可以使用以下命令：

1. 运行配置向导：
```bash
sudo vps-backup
```

2. 执行备份：
```bash
# 完整备份
sudo vps-backup --backup full

# 增量备份
sudo vps-backup --backup incremental
```

3. 查看状态：
```bash
sudo vps-backup --status
```

## 自动备份计划

安装后，系统会自动设置以下备份计划：
- 每天凌晨 2 点执行完整备份
- 每 6 小时执行一次增量备份

备份日志保存在 `/var/log/vps_backup/` 目录下。

## 系统要求

- 支持的操作系统：Ubuntu、Debian、CentOS
- 需要 root 权限
- 需要安装的依赖：git、curl、tar、rsync（安装脚本会自动安装）

## 文件位置说明

- 主程序：`/usr/local/vps-backup/backup.sh`
- 配置文件：`/etc/vps_backup/config`
- 日志文件：`/var/log/vps_backup/`
- 临时文件：`/tmp/vps_backup/`
- 定时任务配置：`/etc/cron.d/vps_backup`
