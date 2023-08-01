#!/bin/bash

# 设置提示文字样式
GREEN="\033[1;32m"
RESET="\033[0m"

# 安装 acme 和 socat
echo -e "${GREEN}开始安装 acme 和 socat...${RESET}"
apt-get update
apt-get install -y acme socat

# 输入密钥和邮箱
read -p "请输入您的密钥: " KEY
read -p "请输入您的邮箱: " EMAIL

# 验证密钥和邮箱
echo -e "${GREEN}开始验证密钥和邮箱...${RESET}"
# 这里省略验证的步骤，你可以根据具体的流程和工具来验证密钥和邮箱

# Cloudflare API相关信息
CLOUDFLARE_API_KEY="YOUR_CLOUDFLARE_API_KEY"
CLOUDFLARE_EMAIL="YOUR_CLOUDFLARE_EMAIL"

# 提示输入域名和泛域名
read -p "请输入域名: " DOMAIN
read -p "请输入泛域名(如果没有可留空): " WILDCARD

# 使用Cloudflare API验证域名所有权
echo -e "${GREEN}使用Cloudflare API验证域名所有权...${RESET}"
if [ -n "$WILDCARD" ]; then
  # 如果有泛域名，使用通配符验证
  acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$WILDCARD" --keypath "/root/.acme.sh/$DOMAIN/$DOMAIN.key" --fullchainpath "/root/.acme.sh/$DOMAIN/fullchain.cer"
else
  # 没有泛域名，只验证单个域名
  acme.sh --issue --dns dns_cf -d "$DOMAIN" --keypath "/root/.acme.sh/$DOMAIN/$DOMAIN.key" --fullchainpath "/root/.acme.sh/$DOMAIN/fullchain.cer"
fi

# 检查证书路径，如果不存在就创建
CERT_DIR="/root/cert"
if [ ! -d "$CERT_DIR" ]; then
  echo -e "${GREEN}创建证书路径：${CERT_DIR}...${RESET}"
  mkdir -p "$CERT_DIR"
fi

# 复制证书到指定目录
echo -e "${GREEN}复制证书到${CERT_DIR}目录...${RESET}"
cp "/root/.acme.sh/$DOMAIN/$DOMAIN.key" "$CERT_DIR/"
cp "/root/.acme.sh/$DOMAIN/fullchain.cer" "$CERT_DIR/"

echo -e "${GREEN}证书申请和复制过程已完成！${RESET}"
