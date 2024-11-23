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
  else
    echo "Docker 已安装。"
  fi
}

# 检查 Docker Compose 是否安装
install_docker_compose() {
  if ! command -v docker-compose &>/dev/null; then
    echo "Docker Compose 未安装，正在从官方源安装..."
    curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose $DOCKER_COMPOSE_VERSION 已成功安装。"
  else
    echo "Docker Compose 已安装。"
  fi
}

# 创建 Watchtower 目录
create_watchtower_dir() {
  if [[ ! -d "$WATCHTOWER_DIR" ]]; then
    echo "创建 Watchtower 文件夹：$WATCHTOWER_DIR"
    mkdir -p "$WATCHTOWER_DIR"
  fi
  cd "$WATCHTOWER_DIR" || exit
}

# 创建 Docker Compose 文件
create_compose_file() {
  echo "创建默认 Docker Compose 配置文件..."
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
}

# 列出当前所有容器
list_all_containers() {
  echo "当前 Docker 容器列表："
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

# 读取现有监控的配置
read_current_configuration() {
  if [[ -f "$COMPOSE_FILE" ]]; then
    current_command=$(grep "^    command:" "$COMPOSE_FILE" | awk '{$1=""; print $0}')
    echo "当前监控配置为：$current_command"
  else
    echo "未检测到现有配置。"
  fi
}

# 更新或新增监控容器
update_or_add_containers() {
  echo "请选择操作："
  echo "1) 新增监控容器（保留现有配置）"
  echo "2) 覆盖监控容器（重新定义配置）"
  read -r choice

  case $choice in
  1)
    # 新增容器
    list_all_containers
    echo "请输入要新增监控的容器名称，多个容器用空格分隔："
    read -r new_containers

    invalid_containers=$(validate_container_names "$new_containers")

    if [[ -n "$invalid_containers" ]]; then
      echo "以下容器名称无效或不存在：$invalid_containers"
      echo "请检查输入并重新运行脚本。"
      return
    fi

    if [[ -n "$new_containers" ]]; then
      updated_command=$(grep "^    command:" "$COMPOSE_FILE" | awk '{$1=""; print $0}')
      for container in $new_containers; do
        updated_command="$updated_command $container"
      done
      sed -i "/^    command:/c\    command: $updated_command" "$COMPOSE_FILE"
      echo "已新增监控的容器：$new_containers"
    else
      echo "未新增任何容器，保持现有配置。"
    fi
    ;;
  2)
    # 覆盖配置
    list_all_containers
    echo "请输入要监控的容器名称，多个容器用空格分隔（留空表示监控所有容器）："
    read -r containers

    invalid_containers=$(validate_container_names "$containers")

    if [[ -n "$invalid_containers" ]]; then
      echo "以下容器名称无效或不存在：$invalid_containers"
      echo "请检查输入并重新运行脚本。"
      return
    fi

    if [[ -n "$containers" ]]; then
      specific_command="containrrr/watchtower"
      for container in $containers; do
        specific_command="$specific_command $container"
      done
      sed -i "/^    command:/c\    command: $specific_command" "$COMPOSE_FILE"
      echo "已覆盖监控的容器配置为：$containers"
    else
      sed -i "/^    command:/c\    command: $DEFAULT_COMMAND" "$COMPOSE_FILE"
      echo "已恢复为默认监控所有容器。"
    fi
    ;;
  *)
    echo "无效选择，退出操作。"
    ;;
  esac
}

# 启动或重启 Watchtower 容器
start_or_restart_watchtower() {
  echo "启动或重启 Watchtower 容器..."
  docker-compose -f "$COMPOSE_FILE" up -d
  echo "Watchtower 已启动或更新配置生效。"
}

# 主流程
main() {
  install_docker
  install_docker_compose
  create_watchtower_dir

  if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "未检测到 Watchtower 配置文件，正在初始化默认配置..."
    create_compose_file
  else
    echo "检测到现有 Watchtower 配置文件。"
    read_current_configuration
    echo "是否需要修改当前配置？[y/N]"
    read -r modify
    if [[ "$modify" =~ ^[Yy]$ ]]; then
      update_or_add_containers
    fi
  fi

  start_or_restart_watchtower
}

# 执行主流程
main
