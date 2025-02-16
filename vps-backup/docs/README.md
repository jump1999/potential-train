# VPS备份工具

这是一个简单但功能完整的VPS备份工具，专门为命令行环境设计，支持WebDAV远程备份，具有交互式操作界面。

## 特性

- 简单的命令行交互界面
- 支持完整备份和增量备份
- WebDAV远程备份支持
  - 自动上传到网盘
  - 带宽限制选项
  - 断点续传
  - 自动重试机制
- 分别配置本地和远程备份保留策略
- 可调节的压缩级别
- 显示备份和上传进度
- 最小化系统依赖
- 自动检查系统环境

## 安装

1. 将脚本复制到您的VPS：
```bash
wget https://your-script-url/backup.sh
chmod +x backup.sh
```

2. 安装依赖（如果需要）：
```bash
# Debian/Ubuntu
apt-get update
apt-get install tar rsync curl

# CentOS/RHEL
yum install tar rsync curl
```

## 从GitHub安装

1. **克隆仓库**：
   ```bash
   git clone https://github.com/你的用户名/vps-backup.git
   cd vps-backup
   ```

2. **运行安装脚本**：
   ```bash
   sudo chmod +x install.sh
   sudo ./install.sh
   ```

3. **验证安装**：
   ```bash
   vps-backup --version
   ```

## 一键安装

复制以下命令到终端运行即可完成安装：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/你的用户名/vps-backup/main/quick_install.sh)"
```

脚本会自动：
- 检查系统环境
- 安装必要的依赖
- 下载并安装备份工具
- 配置系统服务
- 显示使用说明

支持的系统：
- Ubuntu 18.04+
- Debian 10+
- CentOS 7+

## 快速开始

1. **首次配置**：
   ```bash
   sudo vps-backup
   ```
   - 进入"配置管理"
   - 设置备份目录
   - 配置WebDAV（如需要）
   - 设置定时备份（如需要）

2. **手动备份**：
   ```bash
   # 完整备份
   sudo vps-backup --backup full
   
   # 增量备份
   sudo vps-backup --backup incremental
   ```

3. **查看备份状态**：
   ```bash
   sudo vps-backup --status
   ```

## 使用方法

1. 运行脚本：
```bash
./backup.sh
```

2. 首次运行时，请先进入"配置管理"：
   - 设置需要备份的目录
   - 配置WebDAV连接信息
   - 设置本地和远程备份保留天数
   - 配置压缩级别和带宽限制（可选）

3. WebDAV配置说明：
   - URL格式：https://your-webdav-server.com/path/
   - 支持主流网盘的WebDAV协议
   - 可以设置上传带宽限制
   - 支持连接测试功能

4. 进入"备份操作"执行备份：
   - 可以选择完整备份或增量备份
   - 自动上传到WebDAV服务器
   - 查看备份历史
   - 清理旧备份

## 备份保留策略

本脚本采用智能的备份保留策略：

1. **最小备份数量**：
   - 默认保留最少3个备份文件
   - 可通过配置菜单自定义最小保留数量
   - 只有当备份数量超过最小值时才会执行清理

2. **保留天数**：
   - 本地备份默认保留7天
   - 远程备份默认保留30天
   - 仅当备份数量超过最小保留数量时才会根据时间清理

3. **清理规则**：
   - 按时间顺序清理最早的备份
   - 确保系统始终保留指定数量的最新备份
   - 本地和远程备份分别独立计算和清理

## 定时备份配置

脚本支持灵活的定时备份配置：

1. **备份频率选项**：
   - 每天备份
   - 每周备份（可选择周几）
   - 每月备份（可选择日期）

2. **备份时间设置**：
   - 可自定义具体时间（小时:分钟）
   - 默认凌晨2:00

3. **备份类型**：
   - 完整备份
   - 增量备份

4. **配置步骤**：
   1. 进入"配置管理" -> "定时备份设置"
   2. 启用定时备份
   3. 选择备份频率和时间
   4. 选择备份类型
   5. 应用定时任务

注意：定时任务的清理操作会在每天凌晨3点自动执行，确保及时清理过期备份。

## 配置说明

配置文件位置：`/etc/vps_backup/config`

配置项说明：
- BACKUP_DIRS：备份目录列表，多个目录用空格分隔
- LOCAL_RETENTION_DAYS：本地备份文件保留天数
- REMOTE_RETENTION_DAYS：远程备份文件保留天数
- COMPRESSION_LEVEL：压缩级别（1-9，默认6）
- BANDWIDTH_LIMIT：上传带宽限制（KB/s，0表示不限制）
- WEBDAV_URL：WebDAV服务器地址
- WEBDAV_USERNAME：WebDAV用户名
- WEBDAV_PASSWORD：WebDAV密码
- NOTIFICATION_METHOD：通知方式
- RETRY_COUNT：上传失败重试次数

## 日志

日志文件位置：`/var/log/vps_backup.log`

## 注意事项

1. 确保有足够的磁盘空间（至少1GB可用空间）
2. WebDAV配置信息会被安全存储（600权限）
3. 大文件上传时建议设置带宽限制，避免影响服务器正常运行
4. 增量备份需要之前有完整备份作为基准
5. 建议定期检查备份文件的完整性

## 常见问题

1. WebDAV连接失败
   - 检查URL格式是否正确
   - 确认用户名和密码
   - 使用测试连接功能验证配置

2. 上传速度过慢
   - 检查网络连接
   - 调整压缩级别
   - 考虑设置合适的带宽限制

3. 备份失败
   - 检查磁盘空间
   - 检查目录权限
   - 查看日志文件获取详细错误信息

## 文件说明

- `backup.sh`：主程序脚本，包含所有备份功能
- `backup.cron`：定时任务配置模板
- `install.sh`：安装脚本
- `README.md`：使用说明文档

## 目录结构

安装后的文件位置：
- 主程序：`/usr/local/vps-backup/backup.sh`
- 配置文件：`/etc/vps_backup/config`
- 日志文件：`/var/log/vps_backup/backup.log`
- 临时文件：`/tmp/vps_backup/`
- 定时任务：`/etc/cron.d/vps_backup`
