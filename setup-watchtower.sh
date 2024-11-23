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
    mkdir -p "$WATCHTOWER_DIR"
  fi
  cd "$WATCHTOWER_DIR" || exit
}

# 创建 Docker Compose 文件
create_compose_file() {
  if [[ ! -f "$COMPOSE_FILE" ]]; then
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
  fi
}

# 列出当前所有容器
list_all_containers() {
  docker ps -a --format "table {{.Names}}\t{{.Status}}"
}

# 验证容器名称是否存在
validate_container_names() {
  local invalid_containers=()
  for container in $1; do
    if ! docker ps -a --format "{{.Names}}" | grep -wq "$container"; then
      invalid_containers+=("$container")
    fi
  done
  echo "${invalid_containers[@]}"
}

# 检测并移除同名容器（首次执行时）
remove_existing_container() {
  if docker ps -a --format "{{.Names}}" | grep -qw "$SERVICE_NAME"; then
    # 检查容器是否由 docker-compose 管理
    is_compose_managed=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$SERVICE_NAME" 2>/dev/null)

    if [[ -z "$is_compose_managed" ]]; then
      docker stop "$SERVICE_NAME" &>/dev/null
      docker rm "$SERVICE_NAME" &>/dev/null
    fi
  fi
}

# 更新或新增监控容器
update_or_add_containers() {
  echo "请选择操作："
  echo "1) 新增监控容器（保留现有配置）"
  echo "2) 覆盖监控容器（重新定义配置）"
  echo "3) 恢复监控所有容器（需要用户确认）"
  read -r choice

  case $choice in
  1)
    list_all_containers
    echo "请输入要新增监控的容器名称，多个容器用空格分隔："
    read -r new_containers

    invalid_containers=$(validate_container_names "$new_containers")
    if [[ -n "$invalid_containers" ]]; then
      echo "以下容器名称无效或不存在：$invalid_containers"
      return
    fi

    if [[ -n "$new_containers" ]]; then
      updated_command=$(grep "^    command:" "$COMPOSE_FILE" | awk '{$1=""; print $0}')
      for container in $new_containers; do
        updated_command="$updated_command $container"
      done
      sed -i "/^    command:/c\    command: $updated_command" "$COMPOSE_FILE"
    fi
    ;;
  2)
    list_all_containers
    echo "请输入要监控的容器名称，多个容器用空格分隔（留空表示监控所有容器）："
    read -r containers

    invalid_containers=$(validate_container_names "$containers")
    if [[ -n "$invalid_containers" ]]; then
      echo "以下容器名称无效或不存在：$invalid_containers"
      return
    fi

    specific_command="$DEFAULT_COMMAND"
    for container in $containers; do
      specific_command="$specific_command $container"
    done
    sed -i "/^    command:/c\    command: $specific_command" "$COMPOSE_FILE"
    ;;
  3)
    echo "确认恢复为监控所有容器？[y/N]"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      sed -i "/^    command:/c\    command: $DEFAULT_COMMAND" "$COMPOSE_FILE"
    fi
    ;;
  *)
    echo "无效选择，退出操作。"
    ;;
  esac
}

# 启动或重启 Watchtower 容器
start_or_restart_watchtower() {
  remove_existing_container
  docker-compose -f "$COMPOSE_FILE" up -d &>/dev/null
}

# 主流程
main() {
  install_docker
  install_docker_compose
  create_watchtower_dir
  create_compose_file
  start_or_restart_watchtower
}

# 执行主流程
main
