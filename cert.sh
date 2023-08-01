#!/bin/bash

# 设置颜色常量
GREEN='\033[1;32m'
NC='\033[0m'

# 检查是否已经安装 acme 和 socat，如果没有则安装
if ! command -v acme.sh &>/dev/null || ! command -v socat &>/dev/null; then
    echo -e "${GREEN}正在安装 acme.sh 和 socat...${NC}"
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update
        sudo apt-get install -y acme.sh socat
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y epel-release
        sudo yum install -y acme.sh socat
    else
        echo -e "${GREEN}错误：无法找到适合的包管理器来安装 acme.sh 和 socat。请手动安装后再试。${NC}"
        exit 1
    fi
fi

# 获取 Cloudflare API 密钥和邮箱
echo -e "${GREEN}请输入 Cloudflare API 密钥和邮箱：${NC}"
read -p "Cloudflare API 密钥: " CF_KEY
read -p "Cloudflare 邮箱: " CF_EMAIL

# 配置 Cloudflare API 密钥和邮箱
acme.sh --set-default-ca --server letsencrypt
acme.sh --update-account-info --accountemail "$CF_EMAIL" --accountkey "$CF_KEY"

# 验证 Cloudflare API 密钥和邮箱是否有效
if ! acme.sh --register-account --accountemail "$CF_EMAIL" --accountkey "$CF_KEY"; then
    echo -e "${GREEN}错误：Cloudflare API 密钥和邮箱验证失败。请确认信息后重试。${NC}"
    exit 1
fi

# 输入域名和泛域名，申请证书
echo -e "${GREEN}请输入域名和泛域名（如果没有泛域名，直接按回车跳过）：${NC}"
read -p "域名: " DOMAIN
read -p "泛域名（如果没有直接按回车跳过）: " WILDCARD_DOMAIN

# 申请证书
if [ -n "$WILDCARD_DOMAIN" ]; then
    acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$WILDCARD_DOMAIN"
else
    acme.sh --issue --dns dns_cf -d "$DOMAIN"
fi

# 检查证书路径并创建目录
CERT_DIR="/root/cert"
if [ ! -d "$CERT_DIR" ]; then
    mkdir "$CERT_DIR"
fi

# 复制证书到 CERT_DIR 目录
acme.sh --installcert -d "$DOMAIN" --key-file "$CERT_DIR/private.key" --fullchain-file "$CERT_DIR/fullchain.crt"

echo -e "${GREEN}证书申请成功，已保存至 $CERT_DIR 目录。${NC}"
