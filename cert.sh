#!/bin/bash

# 设置提示信息颜色
GREEN='\033[1;32m'
NC='\033[0m'

# 检查是否以root权限运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${GREEN}请使用root权限运行此脚本.${NC}"
    exit 1
fi

# 安装所需软件包
echo -e "${GREEN}正在安装所需软件包（acme, socat）...${NC}"
apt-get update
apt-get install -y acme socat

# 输入Cloudflare密钥和邮箱
echo -e "${GREEN}请输入您的Cloudflare API密钥:${NC}"
read -s CF_API_KEY
echo -e "${GREEN}请输入您的Cloudflare邮箱:${NC}"
read CF_EMAIL

# 验证Cloudflare密钥和邮箱
echo -e "${GREEN}正在验证Cloudflare密钥和邮箱...${NC}"
if ! acme.sh --issue --dns dns_cf -d example.com -d '*.example.com' --accountemail "${CF_EMAIL}" --dns_cf_key "${CF_API_KEY}"; then
    echo -e "${GREEN}验证Cloudflare密钥和邮箱失败，请检查您的API密钥和邮箱.${NC}"
    exit 1
fi

# 输入域名并申请证书
echo -e "${GREEN}请输入您的域名（例如，example.com）:${NC}"
read DOMAIN
echo -e "${GREEN}是否申请泛域名证书？（是/否）:${NC}"
read WILDCARD

if [ "$WILDCARD" = "是" ]; then
    acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN" --accountemail "${CF_EMAIL}" --dns_cf_key "${CF_API_KEY}"
else
    acme.sh --issue --dns dns_cf -d "$DOMAIN" --accountemail "${CF_EMAIL}" --dns_cf_key "${CF_API_KEY}"
fi

# 检查证书目录是否存在，不存在则创建
CERT_DIR="/root/cert"
if [ ! -d "$CERT_DIR" ]; then
    mkdir -p "$CERT_DIR"
fi

# 将证书文件复制到证书目录
if [ "$WILDCARD" = "是" ]; then
    acme.sh --install-cert -d "$DOMAIN" --key-file "$CERT_DIR/$DOMAIN.key" --fullchain-file "$CERT_DIR/fullchain.cer"
else
    acme.sh --install-cert -d "$DOMAIN" --key-file "$CERT_DIR/$DOMAIN.key" --cert-file "$CERT_DIR/$DOMAIN.cer" --ca-file "$CERT_DIR/ca.cer" --fullchain-file "$CERT_DIR/fullchain.cer"
fi

echo -e "${GREEN}证书申请成功，并已复制到$CERT_DIR目录.${NC}"
