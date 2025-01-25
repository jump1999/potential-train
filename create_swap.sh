#!/bin/bash

# 默认 Swap 大小（GB）
DEFAULT_SWAP_SIZE=1

# 提示用户输入 Swap 大小
read -p "请输入 Swap 大小（GB），默认值为 ${DEFAULT_SWAP_SIZE}G: " SWAP_SIZE

# 如果用户没有输入，则使用默认值
SWAP_SIZE=${SWAP_SIZE:-$DEFAULT_SWAP_SIZE}

# 检查是否具有 root 权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本。"
  exit 1
fi

# 创建 Swap 文件
SWAP_FILE=/swapfile

echo "正在创建 ${SWAP_SIZE}G 的 Swap 文件..."
fallocate -l ${SWAP_SIZE}G $SWAP_FILE

# 设置正确的权限
chmod 600 $SWAP_FILE

# 设置为 Swap 区域
mkswap $SWAP_FILE

# 启用 Swap
swapon $SWAP_FILE

# 将 Swap 添加到 /etc/fstab 以便开机自动挂载
echo "$SWAP_FILE none swap sw 0 0" | tee -a /etc/fstab

echo "Swap 创建并启用成功！"
swapon --show
