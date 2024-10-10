#!/bin/bash
echo "\$nrconf{kernelhints} = 0;" >> /etc/needrestart/needrestart.conf
echo "\$nrconf{restart} = 'l';" >> /etc/needrestart/needrestart.conf

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 检查并安装Docker
function check_and_install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "未检测到 Docker，正在安装..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        echo "Docker 已安装。"
    else
        echo "Docker 已安装。"
    fi
}

# 检查并安装curl
function check_and_install_curl() {
    if ! command -v curl &> /dev/null; then
        echo "未检测到 curl，正在安装..."
        sudo apt update && sudo apt install -y curl
        echo "curl 已安装。"
    else
        echo "curl 已安装。"
    fi
}

# 节点安装功能
function install_node() {
    check_and_install_curl
    check_and_install_docker

    mkdir -p tora && cd tora

    # 创建docker-compose.yml文件
    cat <<EOF > docker-compose.yml
services:
  confirm:
    image: oraprotocol/tora:confirm
    container_name: ora-tora
    depends_on:
      - redis
      - openlm
    command: 
      - "--confirm"
    env_file:
      - .env
    environment:
      REDIS_HOST: 'redis'
      REDIS_PORT: 6379
      CONFIRM_MODEL_SERVER_13: 'http://openlm:5000/'
    networks:
      - private_network
  redis:
    image: oraprotocol/redis:latest
    container_name: ora-redis
    restart: always
    networks:
      - private_network
  openlm:
    image: oraprotocol/openlm:latest
    container_name: ora-openlm
    restart: always
    networks:
      - private_network
  diun:
    image: crazymax/diun:latest
    container_name: diun
    command: serve
    volumes:
      - "./data:/data"
      - "/var/run/docker.sock:/var/run/docker.sock"
    environment:
      - "TZ=Asia/Shanghai"
      - "LOG_LEVEL=info"
      - "LOG_JSON=false"
      - "DIUN_WATCH_WORKERS=5"
      - "DIUN_WATCH_JITTER=30"
      - "DIUN_WATCH_SCHEDULE=0 0 * * *"
      - "DIUN_PROVIDERS_DOCKER=true"
      - "DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=true"
    restart: always

networks:
  private_network:
    driver: bridge
EOF

    # 提示用户输入环境变量的值
    # read -p "请输入您的私钥，需要0X，对应钱包需要有Sepolia 测试网ETH代币: " PRIV_KEY
    # read -p "请输入您的以太坊主网Alchemy WSS URL: " MAINNET_WSS
    # read -p "请输入您的以太坊主网Alchemy HTTP URL: " MAINNET_HTTP
    # read -p "请输入您的Sepolia以太坊Alchemy WSS URL: " SEPOLIA_WSS
    # read -p "请输入您的Sepolia以太坊Alchemy HTTP URL: " SEPOLIA_HTTP

    # 创建.env文件
    cat <<EOF > .env
############### Sensitive config ###############

PRIV_KEY="$PRIV_KEY"

############### General config ###############

TORA_ENV=production

MAINNET_WSS="$MAINNET_WSS"
MAINNET_HTTP="$MAINNET_HTTP"
SEPOLIA_WSS="$SEPOLIA_WSS"
SEPOLIA_HTTP="$SEPOLIA_HTTP"

REDIS_TTL=86400000

############### App specific config ###############
# sepolia Mainnet
CONFIRM_CHAINS='["$main_or_test"]'
CONFIRM_MODELS='[13]'

CONFIRM_USE_CROSSCHECK=true
CONFIRM_CC_POLLING_INTERVAL=3000
CONFIRM_CC_BATCH_BLOCKS_COUNT=300

CONFIRM_TASK_TTL=2592000000
CONFIRM_TASK_DONE_TTL=2592000000
CONFIRM_CC_TTL=2592000000
EOF

    sudo sysctl vm.overcommit_memory=1
    echo "正在启动Docker容器（可能需要5-10分钟）..."
    sudo docker compose up -d
}
install_node
