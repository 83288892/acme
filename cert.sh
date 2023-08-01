#!/bin/bash

# 设置颜色变量
GREEN='\033[1;32m'
NC='\033[0m'

# 检查是否为root用户运行脚本
if [[ $EUID -ne 0 ]]; then
    echo -e "${GREEN}请使用root权限运行该脚本.${NC}"
    exit 1
fi

# 检查acme是否已安装
if ! command -v acme.sh &> /dev/null; then
    echo -e "${GREEN}acme未安装，开始安装 acme.${NC}"
    apt-get update
    apt-get install -y acme
fi

# 检查socat是否已安装
if ! command -v socat &> /dev/null; then
    echo -e "${GREEN}socat未安装，开始安装 socat.${NC}"
    apt-get update
    apt-get install -y socat
fi

# 获取Cloudflare密钥和邮箱
echo -e "${GREEN}请输入Cloudflare邮箱和密钥.${NC}"
read -p "邮箱: " CF_EMAIL
read -p "密钥: " CF_KEY

# 验证Cloudflare密钥和邮箱
echo -e "${GREEN}验证Cloudflare密钥和邮箱.${NC}"
if ! acme.sh --issue --dns dns_cf -d example.com -d '*.example.com' --keypath /root/.acme.sh/account.key --email "${CF_EMAIL}" --dns_cf_key "${CF_KEY}"; then
    echo -e "${GREEN}Cloudflare密钥或邮箱验证失败，请检查输入是否正确.${NC}"
    exit 1
fi

# 输入域名和泛域名
echo -e "${GREEN}请输入要申请证书的域名和泛域名（多个域名用空格分隔）.${NC}"
read -p "域名: " DOMAIN
read -p "泛域名: " WILDCARD_DOMAIN

# 申请证书
echo -e "${GREEN}开始申请证书.${NC}"
if ! acme.sh --issue --dns dns_cf -d "${DOMAIN}" -d "*.${WILDCARD_DOMAIN}" --keypath /root/.acme.sh/account.key --email "${CF_EMAIL}" --dns_cf_key "${CF_KEY}"; then
    echo -e "${GREEN}证书申请失败，请检查输入是否正确.${NC}"
    exit 1
fi

# 检查证书目录是否存在，如果不存在则创建
CERT_DIR="/root/cert"
if [ ! -d "$CERT_DIR" ]; then
    echo -e "${GREEN}创建证书目录: $CERT_DIR.${NC}"
    mkdir -p "$CERT_DIR"
fi

# 复制证书到证书目录
echo -e "${GREEN}复制证书到 $CERT_DIR 目录.${NC}"
acme.sh --install-cert -d "${DOMAIN}" -d "*.${WILDCARD_DOMAIN}" --cert-file "$CERT_DIR/cert.pem" --key-file "$CERT_DIR/private.key" --fullchain-file "$CERT_DIR/fullchain.pem"

echo -e "${GREEN}证书申请成功！证书已保存在 $CERT_DIR 目录.${NC}"
