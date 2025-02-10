#!/bin/bash

# 配置文件路径
CONFIG_FILE="/etc/vps_backup/config"
LOG_FILE="/var/log/vps_backup.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 确保必要的目录存在
init_directories() {
    mkdir -p /etc/vps_backup
    mkdir -p /var/log/vps_backup
    mkdir -p /tmp/vps_backup
    touch $LOG_FILE
    
    # 如果配置文件不存在，创建默认配置
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "BACKUP_DIRS=" > $CONFIG_FILE
        echo "LOCAL_RETENTION_DAYS=7" >> $CONFIG_FILE
        echo "REMOTE_RETENTION_DAYS=30" >> $CONFIG_FILE
        echo "MIN_BACKUP_COUNT=3" >> $CONFIG_FILE
        echo "COMPRESSION_LEVEL=6" >> $CONFIG_FILE
        echo "BANDWIDTH_LIMIT=0" >> $CONFIG_FILE
        echo "WEBDAV_URL=" >> $CONFIG_FILE
        echo "WEBDAV_USERNAME=" >> $CONFIG_FILE
        echo "WEBDAV_PASSWORD=" >> $CONFIG_FILE
        echo "NOTIFICATION_METHOD=none" >> $CONFIG_FILE
        echo "RETRY_COUNT=3" >> $CONFIG_FILE
        echo "SCHEDULE_ENABLED=false" >> $CONFIG_FILE
        echo "SCHEDULE_TYPE=daily" >> $CONFIG_FILE
        echo "SCHEDULE_TIME=02:00" >> $CONFIG_FILE
        echo "SCHEDULE_DAY=*" >> $CONFIG_FILE
        echo "BACKUP_TYPE=full" >> $CONFIG_FILE
        chmod 600 $CONFIG_FILE
    fi
}

# 日志函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] $message" >> $LOG_FILE
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# 检查系统依赖
check_dependencies() {
    local deps=("tar" "rsync" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            missing+=($dep)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "ERROR" "缺少必要的依赖: ${missing[*]}"
        log "INFO" "请使用包管理器安装缺失的依赖"
        exit 1
    fi
}

# 检查磁盘空间
check_disk_space() {
    local min_space=1048576 # 1GB in KB
    local available=$(df -k /tmp | awk 'NR==2 {print $4}')
    
    if [ $available -lt $min_space ]; then
        log "ERROR" "磁盘空间不足，至少需要1GB可用空间"
        return 1
    fi
    return 0
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    printf "\r进度: ["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%%" $percentage
}

# WebDAV配置菜单
webdav_config_menu() {
    while true; do
        echo -e "\n=== WebDAV配置 ==="
        echo "1. 设置WebDAV URL"
        echo "2. 设置用户名"
        echo "3. 设置密码"
        echo "4. 测试连接"
        echo "5. 设置带宽限制 (KB/s, 0表示不限制)"
        echo "6. 返回上级菜单"
        
        read -p "请选择操作 (1-6): " choice
        
        case $choice in
            1)
                read -p "请输入WebDAV URL: " url
                sed -i "s|^WEBDAV_URL=.*|WEBDAV_URL=\"$url\"|" $CONFIG_FILE
                log "INFO" "WebDAV URL已更新"
                ;;
            2)
                read -p "请输入用户名: " username
                sed -i "s|^WEBDAV_USERNAME=.*|WEBDAV_USERNAME=\"$username\"|" $CONFIG_FILE
                log "INFO" "WebDAV用户名已更新"
                ;;
            3)
                read -s -p "请输入密码: " password
                echo
                sed -i "s|^WEBDAV_PASSWORD=.*|WEBDAV_PASSWORD=\"$password\"|" $CONFIG_FILE
                log "INFO" "WebDAV密码已更新"
                ;;
            4)
                test_webdav_connection
                ;;
            5)
                read -p "请输入带宽限制 (KB/s): " bandwidth
                sed -i "s|^BANDWIDTH_LIMIT=.*|BANDWIDTH_LIMIT=$bandwidth|" $CONFIG_FILE
                log "INFO" "带宽限制已更新"
                ;;
            6)
                return
                ;;
            *)
                log "ERROR" "无效的选择"
                ;;
        esac
    done
}

# 测试WebDAV连接
test_webdav_connection() {
    local url=$(grep '^WEBDAV_URL=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    local username=$(grep '^WEBDAV_USERNAME=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    local password=$(grep '^WEBDAV_PASSWORD=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    
    if [ -z "$url" ] || [ -z "$username" ] || [ -z "$password" ]; then
        log "ERROR" "WebDAV配置不完整"
        return 1
    fi
    
    log "INFO" "正在测试WebDAV连接..."
    
    # 创建测试文件
    echo "test" > /tmp/webdav_test
    
    # 尝试上传测试文件
    if curl -s -T /tmp/webdav_test -u "$username:$password" "$url/webdav_test" > /dev/null; then
        log "INFO" "WebDAV连接测试成功"
        # 删除远程测试文件
        curl -s -X DELETE -u "$username:$password" "$url/webdav_test" > /dev/null
        rm -f /tmp/webdav_test
        return 0
    else
        log "ERROR" "WebDAV连接测试失败"
        rm -f /tmp/webdav_test
        return 1
    fi
}

# 上传到WebDAV
upload_to_webdav() {
    local file=$1
    local retry_count=$(grep '^RETRY_COUNT=' $CONFIG_FILE | cut -d'=' -f2-)
    local bandwidth_limit=$(grep '^BANDWIDTH_LIMIT=' $CONFIG_FILE | cut -d'=' -f2-)
    local url=$(grep '^WEBDAV_URL=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    local username=$(grep '^WEBDAV_USERNAME=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    local password=$(grep '^WEBDAV_PASSWORD=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    
    if [ -z "$url" ] || [ -z "$username" ] || [ -z "$password" ]; then
        log "ERROR" "WebDAV配置不完整"
        return 1
    fi
    
    local filename=$(basename "$file")
    local remote_path="$url/$filename"
    local attempt=1
    
    while [ $attempt -le $retry_count ]; do
        log "INFO" "正在上传到WebDAV (尝试 $attempt/$retry_count)..."
        
        # 构建curl命令
        local curl_cmd="curl -s -T \"$file\" -u \"$username:$password\" \"$remote_path\""
        if [ "$bandwidth_limit" -gt 0 ]; then
            curl_cmd="$curl_cmd --limit-rate ${bandwidth_limit}k"
        fi
        
        # 显示上传进度
        if eval $curl_cmd; then
            log "INFO" "文件上传成功: $filename"
            return 0
        else
            log "WARNING" "上传失败，等待重试..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    log "ERROR" "上传失败，已达到最大重试次数"
    return 1
}

# 配置管理菜单
config_menu() {
    while true; do
        echo -e "\n=== 配置管理 ==="
        echo "1. 查看当前配置"
        echo "2. 设置备份目录"
        echo "3. 设置本地保留天数"
        echo "4. 设置远程保留天数"
        echo "5. 设置最小保留备份数"
        echo "6. 设置压缩级别 (1-9)"
        echo "7. WebDAV配置"
        echo "8. 配置通知方式"
        echo "9. 定时备份设置"
        echo "10. 返回主菜单"
        
        read -p "请选择操作 (1-10): " choice
        
        case $choice in
            1)
                echo -e "\n当前配置："
                grep -v "PASSWORD" $CONFIG_FILE
                ;;
            2)
                read -p "请输入备份目录（多个目录用空格分隔）: " dirs
                sed -i "s|^BACKUP_DIRS=.*|BACKUP_DIRS=\"$dirs\"|" $CONFIG_FILE
                log "INFO" "备份目录已更新"
                ;;
            3)
                read -p "请输入本地备份保留天数: " days
                sed -i "s/^LOCAL_RETENTION_DAYS=.*/LOCAL_RETENTION_DAYS=$days/" $CONFIG_FILE
                log "INFO" "本地保留天数已更新"
                ;;
            4)
                read -p "请输入远程备份保留天数: " days
                sed -i "s/^REMOTE_RETENTION_DAYS=.*/REMOTE_RETENTION_DAYS=$days/" $CONFIG_FILE
                log "INFO" "远程保留天数已更新"
                ;;
            5)
                read -p "请输入最小保留备份数量 (建议不少于3个): " count
                if [ "$count" -ge 1 ]; then
                    sed -i "s/^MIN_BACKUP_COUNT=.*/MIN_BACKUP_COUNT=$count/" $CONFIG_FILE
                    log "INFO" "最小保留备份数量已更新为 $count"
                else
                    log "ERROR" "无效的数量，必须大于等于1"
                fi
                ;;
            6)
                read -p "请输入压缩级别 (1-9): " level
                if [ "$level" -ge 1 ] && [ "$level" -le 9 ]; then
                    sed -i "s/^COMPRESSION_LEVEL=.*/COMPRESSION_LEVEL=$level/" $CONFIG_FILE
                    log "INFO" "压缩级别已更新"
                else
                    log "ERROR" "无效的压缩级别"
                fi
                ;;
            7)
                webdav_config_menu
                ;;
            8)
                configure_notification
                ;;
            9)
                schedule_config_menu
                ;;
            10)
                return
                ;;
            *)
                log "ERROR" "无效的选择"
                ;;
        esac
    done
}

# 执行备份
perform_backup() {
    local type=$1
    local source_dirs=$(grep '^BACKUP_DIRS=' $CONFIG_FILE | cut -d'=' -f2-)
    local compression_level=$(grep '^COMPRESSION_LEVEL=' $CONFIG_FILE | cut -d'=' -f2-)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="/tmp/vps_backup/backup_${type}_${timestamp}.tar.gz"
    
    # 检查备份目录是否为空
    if [ -z "$source_dirs" ]; then
        log "ERROR" "未配置备份目录"
        return 1
    fi
    
    # 检查磁盘空间
    check_disk_space || return 1
    
    log "INFO" "开始${type}备份..."
    
    # 创建备份
    case $type in
        "完整")
            tar -cz --level=$compression_level -f "$backup_file" $source_dirs 2>/dev/null &
            ;;
        "增量")
            # 查找最近的完整备份作为基准
            local base_backup=$(ls -t /tmp/vps_backup/backup_完整_*.tar.gz 2>/dev/null | head -n1)
            if [ -n "$base_backup" ]; then
                tar -cz --level=$compression_level \
                    --newer-mtime="$base_backup" \
                    -f "$backup_file" $source_dirs 2>/dev/null &
            else
                log "WARNING" "未找到完整备份，将执行完整备份"
                tar -cz --level=$compression_level -f "$backup_file" $source_dirs 2>/dev/null &
            fi
            ;;
    esac
    
    # 获取PID并显示进度
    local pid=$!
    while kill -0 $pid 2>/dev/null; do
        local size=$(stat -f %z "$backup_file" 2>/dev/null || echo 0)
        show_progress $size 1000000000
        sleep 1
    done
    
    wait $pid
    if [ $? -eq 0 ]; then
        echo -e "\n"
        log "INFO" "备份完成: $backup_file"
        
        # 上传到WebDAV
        if upload_to_webdav "$backup_file"; then
            # 清理本地和远程旧备份
            clean_old_backups
            log "INFO" "备份流程完成"
        else
            log "ERROR" "备份上传失败"
            return 1
        fi
    else
        echo -e "\n"
        log "ERROR" "备份失败"
        rm -f "$backup_file"
        return 1
    fi
}

# 清理旧备份
clean_old_backups() {
    local local_retention_days=$(grep '^LOCAL_RETENTION_DAYS=' $CONFIG_FILE | cut -d'=' -f2-)
    local remote_retention_days=$(grep '^REMOTE_RETENTION_DAYS=' $CONFIG_FILE | cut -d'=' -f2-)
    local min_backup_count=$(grep '^MIN_BACKUP_COUNT=' $CONFIG_FILE | cut -d'=' -f2-)
    
    # 清理本地旧备份
    log "INFO" "开始清理本地旧备份..."
    
    # 获取所有备份文件列表（按时间排序，最老的在前）
    local backup_files=($(find /tmp/vps_backup -name "backup_*.tar.gz" -type f -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-))
    local total_backups=${#backup_files[@]}
    
    if [ $total_backups -gt $min_backup_count ]; then
        # 计算可以删除的文件数量
        local files_to_delete=()
        for file in "${backup_files[@]}"; do
            local file_age=$(( ($(date +%s) - $(date -r "$file" +%s)) / 86400 ))
            if [ $file_age -gt $local_retention_days ] && [ $total_backups -gt $min_backup_count ]; then
                files_to_delete+=("$file")
                total_backups=$((total_backups - 1))
            fi
        done
        
        # 删除过期文件
        for file in "${files_to_delete[@]}"; do
            log "INFO" "删除过期本地备份: $(basename "$file")"
            rm -f "$file"
        done
    else
        log "INFO" "本地备份文件数量（$total_backups）未超过最小保留数量（$min_backup_count），跳过清理"
    fi
    
    # 清理远程旧备份
    log "INFO" "开始清理远程旧备份..."
    local url=$(grep '^WEBDAV_URL=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    local username=$(grep '^WEBDAV_USERNAME=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    local password=$(grep '^WEBDAV_PASSWORD=' $CONFIG_FILE | cut -d'=' -f2- | tr -d '"')
    
    if [ -n "$url" ] && [ -n "$username" ] && [ -n "$password" ]; then
        # 获取远程文件列表
        local temp_list="/tmp/vps_backup/remote_files.txt"
        curl -s -u "$username:$password" "$url" | grep -oE 'backup_[^<>"]+\.tar\.gz' > "$temp_list"
        
        # 获取所有远程文件的时间戳
        declare -A remote_files
        local remote_total=0
        while read -r filename; do
            if [ -n "$filename" ]; then
                local file_info=$(curl -s -I -u "$username:$password" "$url/$filename")
                local mtime=$(echo "$file_info" | grep -i "last-modified:" | sed 's/[Ll]ast-[Mm]odified: //')
                if [ -n "$mtime" ]; then
                    local file_date=$(date -d "$mtime" +%s 2>/dev/null)
                    remote_files["$filename"]=$file_date
                    remote_total=$((remote_total + 1))
                fi
            fi
        done < "$temp_list"
        
        if [ $remote_total -gt $min_backup_count ]; then
            # 按时间排序处理文件（最老的在前）
            for filename in $(for k in "${!remote_files[@]}"; do echo "${remote_files[$k]} $k"; done | sort -n | cut -d' ' -f2-); do
                local file_date=${remote_files["$filename"]}
                local days_old=$(( ($(date +%s) - $file_date) / 86400 ))
                
                if [ $days_old -gt $remote_retention_days ] && [ $remote_total -gt $min_backup_count ]; then
                    log "INFO" "删除过期远程文件: $filename"
                    curl -s -X DELETE -u "$username:$password" "$url/$filename" > /dev/null
                    if [ $? -eq 0 ]; then
                        log "INFO" "成功删除远程文件: $filename"
                        remote_total=$((remote_total - 1))
                    else
                        log "ERROR" "删除远程文件失败: $filename"
                    fi
                fi
            done
        else
            log "INFO" "远程备份文件数量（$remote_total）未超过最小保留数量（$min_backup_count），跳过清理"
        fi
        
        rm -f "$temp_list"
    else
        log "WARNING" "WebDAV配置不完整，跳过远程清理"
    fi
}

# 备份管理菜单
backup_menu() {
    while true; do
        echo -e "\n=== 备份管理 ==="
        echo "1. 执行完整备份"
        echo "2. 执行增量备份"
        echo "3. 查看备份历史"
        echo "4. 清理旧备份"
        echo "5. 返回主菜单"
        
        read -p "请选择操作 (1-5): " choice
        
        case $choice in
            1)
                perform_backup "完整"
                ;;
            2)
                perform_backup "增量"
                ;;
            3)
                echo "最近的备份文件："
                ls -lh /tmp/vps_backup/backup_*.tar.gz 2>/dev/null || echo "没有找到备份文件"
                ;;
            4)
                clean_old_backups
                ;;
            5)
                return
                ;;
            *)
                log "ERROR" "无效的选择"
                ;;
        esac
    done
}

# 定时备份配置菜单
schedule_config_menu() {
    while true; do
        echo -e "\n=== 定时备份配置 ==="
        
        # 显示当前配置
        local enabled=$(grep '^SCHEDULE_ENABLED=' $CONFIG_FILE | cut -d'=' -f2-)
        local type=$(grep '^SCHEDULE_TYPE=' $CONFIG_FILE | cut -d'=' -f2-)
        local time=$(grep '^SCHEDULE_TIME=' $CONFIG_FILE | cut -d'=' -f2-)
        local day=$(grep '^SCHEDULE_DAY=' $CONFIG_FILE | cut -d'=' -f2-)
        local backup_type=$(grep '^BACKUP_TYPE=' $CONFIG_FILE | cut -d'=' -f2-)
        
        echo "当前配置："
        echo "启用状态: ${enabled}"
        echo "备份频率: ${type}"
        echo "备份时间: ${time}"
        [ "$type" != "daily" ] && echo "备份日期: ${day}"
        echo "备份类型: ${backup_type}"
        
        echo -e "\n1. 启用/禁用定时备份"
        echo "2. 设置备份频率（每天/每周/每月）"
        echo "3. 设置备份时间"
        echo "4. 设置备份类型（完整/增量）"
        echo "5. 应用定时任务"
        echo "6. 返回上级菜单"
        
        read -p "请选择操作 (1-6): " choice
        
        case $choice in
            1)
                if [ "$enabled" = "true" ]; then
                    sed -i "s/^SCHEDULE_ENABLED=.*/SCHEDULE_ENABLED=false/" $CONFIG_FILE
                    log "INFO" "已禁用定时备份"
                else
                    sed -i "s/^SCHEDULE_ENABLED=.*/SCHEDULE_ENABLED=true/" $CONFIG_FILE
                    log "INFO" "已启用定时备份"
                fi
                ;;
            2)
                echo "请选择备份频率："
                echo "1. 每天"
                echo "2. 每周"
                echo "3. 每月"
                read -p "请选择 (1-3): " freq
                case $freq in
                    1)
                        sed -i "s/^SCHEDULE_TYPE=.*/SCHEDULE_TYPE=daily/" $CONFIG_FILE
                        sed -i "s/^SCHEDULE_DAY=.*/SCHEDULE_DAY=*/" $CONFIG_FILE
                        ;;
                    2)
                        sed -i "s/^SCHEDULE_TYPE=.*/SCHEDULE_TYPE=weekly/" $CONFIG_FILE
                        echo "请选择每周几备份(0-6，0表示周日)："
                        read -p "请输入数字: " weekday
                        if [ "$weekday" -ge 0 ] && [ "$weekday" -le 6 ]; then
                            sed -i "s/^SCHEDULE_DAY=.*/SCHEDULE_DAY=$weekday/" $CONFIG_FILE
                        else
                            log "ERROR" "无效的星期数"
                            continue
                        fi
                        ;;
                    3)
                        sed -i "s/^SCHEDULE_TYPE=.*/SCHEDULE_TYPE=monthly/" $CONFIG_FILE
                        echo "请选择每月几号备份(1-28)："
                        read -p "请输入数字: " monthday
                        if [ "$monthday" -ge 1 ] && [ "$monthday" -le 28 ]; then
                            sed -i "s/^SCHEDULE_DAY=.*/SCHEDULE_DAY=$monthday/" $CONFIG_FILE
                        else
                            log "ERROR" "无效的日期"
                            continue
                        fi
                        ;;
                    *)
                        log "ERROR" "无效的选择"
                        continue
                        ;;
                esac
                log "INFO" "备份频率已更新"
                ;;
            3)
                read -p "请输入备份时间（格式 HH:MM，例如 02:30）: " backup_time
                if echo "$backup_time" | grep -qE '^([01]?[0-9]|2[0-3]):[0-5][0-9]$'; then
                    sed -i "s/^SCHEDULE_TIME=.*/SCHEDULE_TIME=$backup_time/" $CONFIG_FILE
                    log "INFO" "备份时间已更新"
                else
                    log "ERROR" "无效的时间格式"
                fi
                ;;
            4)
                echo "请选择备份类型："
                echo "1. 完整备份"
                echo "2. 增量备份"
                read -p "请选择 (1-2): " btype
                case $btype in
                    1)
                        sed -i "s/^BACKUP_TYPE=.*/BACKUP_TYPE=full/" $CONFIG_FILE
                        ;;
                    2)
                        sed -i "s/^BACKUP_TYPE=.*/BACKUP_TYPE=incremental/" $CONFIG_FILE
                        ;;
                    *)
                        log "ERROR" "无效的选择"
                        continue
                        ;;
                esac
                log "INFO" "备份类型已更新"
                ;;
            5)
                apply_schedule
                ;;
            6)
                return
                ;;
            *)
                log "ERROR" "无效的选择"
                ;;
        esac
    done
}

# 应用定时任务
apply_schedule() {
    local enabled=$(grep '^SCHEDULE_ENABLED=' $CONFIG_FILE | cut -d'=' -f2-)
    if [ "$enabled" != "true" ]; then
        log "WARNING" "定时备份未启用，请先启用定时备份"
        return 1
    fi
    
    local script_path=$(readlink -f "$0")
    local cron_file="/etc/cron.d/vps_backup"
    local schedule_type=$(grep '^SCHEDULE_TYPE=' $CONFIG_FILE | cut -d'=' -f2-)
    local schedule_time=$(grep '^SCHEDULE_TIME=' $CONFIG_FILE | cut -d'=' -f2-)
    local schedule_day=$(grep '^SCHEDULE_DAY=' $CONFIG_FILE | cut -d'=' -f2-)
    local backup_type=$(grep '^BACKUP_TYPE=' $CONFIG_FILE | cut -d'=' -f2-)
    
    # 解析时间
    local hour=$(echo $schedule_time | cut -d':' -f1)
    local minute=$(echo $schedule_time | cut -d':' -f2)
    
    # 构建cron表达式
    local cron_expr=""
    case $schedule_type in
        daily)
            cron_expr="$minute $hour * * *"
            ;;
        weekly)
            cron_expr="$minute $hour * * $schedule_day"
            ;;
        monthly)
            cron_expr="$minute $hour $schedule_day * *"
            ;;
    esac
    
    # 创建cron配置
    cat > "$cron_file" << EOF
# VPS备份定时任务
$cron_expr root $script_path --auto-backup $backup_type
0 3 * * * root $script_path --clean-only
EOF
    
    chmod 644 "$cron_file"
    log "INFO" "定时任务已更新"
    
    # 显示下次执行时间
    echo "定时任务配置完成。备份将在以下时间执行："
    case $schedule_type in
        daily)
            echo "每天 $schedule_time"
            ;;
        weekly)
            local weekdays=("周日" "周一" "周二" "周三" "周四" "周五" "周六")
            echo "每周${weekdays[$schedule_day]} $schedule_time"
            ;;
        monthly)
            echo "每月${schedule_day}日 $schedule_time"
            ;;
    esac
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\n=== VPS备份工具 ==="
        echo "1. 配置管理"
        echo "2. 备份操作"
        echo "3. 退出"
        
        read -p "请选择操作 (1-3): " choice
        
        case $choice in
            1)
                config_menu
                ;;
            2)
                backup_menu
                ;;
            3)
                log "INFO" "程序退出"
                exit 0
                ;;
            *)
                log "ERROR" "无效的选择"
                ;;
        esac
    done
}

# 主程序入口
main() {
    init_directories
    check_dependencies

    # 处理命令行参数
    case "$1" in
        --auto-backup)
            if [ "$2" = "full" ]; then
                perform_backup "完整"
            elif [ "$2" = "incremental" ]; then
                perform_backup "增量"
            else
                log "ERROR" "无效的备份类型: $2"
                exit 1
            fi
            ;;
        --clean-only)
            clean_old_backups
            ;;
        *)
            main_menu
            ;;
    esac
}

# 启动程序
main "$@"
