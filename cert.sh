#!/bin/bash

# ANSI 转义码，用于设置蓝色文本颜色
BLUE="\033[0;34m"
NC="\033[0m"  # 重置文本颜色

# 安装 acme.sh 和 jq 工具
echo "正在安装 acme.sh 和 jq 工具..."
apt-get update
apt-get install -y socat
curl https://get.acme.sh | sh
source ~/.bashrc

# 获取 Cloudflare API 密钥和邮箱
read -p "请输入 ${BLUE}Cloudflare API 密钥${NC}: " cf_api_key
read -p "请输入 ${BLUE}Cloudflare 邮箱${NC}: " cf_email

# 验证密钥
echo "正在验证密钥..."
if ~/.acme.sh/acme.sh --dns dns_cf --accountemail "$cf_email" --registeraccount; then
    echo "密钥验证成功！"
else
    echo "密钥验证失败，请检查您的密钥和邮箱是否正确。"
    exit 1
fi

# 获取申请证书的域名
read -p "请输入 ${BLUE}申请证书的域名${NC}: " domain

# 执行申请证书命令
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain" -d "*.$domain" --dns dns_cf --debug 2> /dev/null

# 输出结果
if [ $? -eq 0 ]; then
    echo "证书申请成功！您现在可以使用您的证书进行 HTTPS 配置。"

    # 检查 /root/cert 目录是否存在，如不存在则创建
    cert_dir="/root/cert"
    if [ ! -d "$cert_dir" ]; then
        mkdir "$cert_dir"
    fi

    # 复制证书文件到 /root/cert 目录
    echo "正在复制证书文件到 $cert_dir 目录..."
    ~/.acme.sh/acme.sh --install-cert -d "$domain" --cert-file "$cert_dir/$domain.cer" --key-file "$cert_dir/$domain.key" --fullchain-file "$cert_dir/fullchain.cer" --reloadcmd "echo 证书复制成功，存放路径：$cert_dir"

else
    echo "证书申请失败，请检查您的域名是否正确，并确保您的 DNS 设置已经生效。"
fi
