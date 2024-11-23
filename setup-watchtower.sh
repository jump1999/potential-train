#!/bin/bash

# 定义变量
ROOT_DIR="/root"
WATCHTOWER_DIR="$ROOT_DIR/watchtower"
COMPOSE_FILE="$WATCHTOWER_DIR/docker-compose.yml"
SERVICE_NAME="watchtower"
DEFAULT_COMMAND="--interval 300" # 默认监控所有容器
DOCKER_INSTALL_SCRIPT="https://get.docker.com/"
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# 检查 Docker 是否安装
install_docker() {
  if ! command -v docker &>/dev/null; then
    echo "Docker 未安装，正在从官方源安装..."
    curl -fsSL "$DOCKER_INSTALL_SCRIPT" | bash
    systemctl start docker
    systemctl enable docker
    echo "Docker 已成功安装。"
  fi
}

# 检查 Docker Compose 是否安装
install_docker_compose() {
  if ! command -v docker-compose &>/dev/null; then
    echo "Docker Compose 未安装，正在从官方源安装..."
    curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose $DOCKER_COMPOSE_VERSION 已成功安装。"
  fi
}

# 创建 Watchtower 目录
create_watchtower_dir() {
  if [[ ! -d "$WATCHTOWER_DIR" ]]; then
    echo "正在创建 Watchtower 文件夹：$WATCHTOWER_DIR"
    mkdir -p "$WATCHTOWER_DIR"
  fi
  cd "$WATCHTOWER_DIR" || exit
}

# 创建 Docker Compose 文件
create_compose_file() {
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "正在创建默认 Docker Compose 配置文件..."
    cat <<EOF >"$COMPOSE_FILE"
services:
  $SERVICE_NAME:
    image: containrrr/watchtower
    container_name: $SERVICE_NAME
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
    command: $DEFAULT_COMMAND
    restart: unless-stopped
EOF
    echo "默认配置已保存到：$COMPOSE_FILE"
  fi
}

# 检测并移除同名容器
remove_existing_container() {
  if docker ps -a --format "{{.Names}}" | grep -qw "$SERVICE_NAME"; then
    is_compose_managed=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$SERVICE_NAME" 2>/dev/null)

    if [[ -z "$is_compose_managed" ]]; then
      echo "检测到同名容器 $SERVICE_NAME（非 docker-compose 管理），正在停止并移除..."
      docker stop "$SERVICE_NAME" >/dev/null 2>&1 && echo "容器 $SERVICE_NAME 已停止。"
      docker rm "$SERVICE_NAME" >/dev/null 2>&1 && echo "容器 $SERVICE_NAME 已移除。"
    fi
  fi
}

# 启动或重启 Watchtower 容器
start_or_restart_watchtower() {
  echo "启动或重启 Watchtower 容器..."
  remove_existing_container
  docker-compose -f "$COMPOSE_FILE" up -d >/dev/null 2>&1 && echo "Watchtower 容器已成功启动。"
}

# 主流程
main() {
  echo "检查 Docker 是否安装..."
  install_docker

  echo "检查 Docker Compose 是否安装..."
  install_docker_compose

  echo "检查 Watchtower 配置目录..."
  create_watchtower_dir

  echo "检查 Docker Compose 配置文件..."
  create_compose_file

  start_or_restart_watchtower
}

# 执行主流程
main
