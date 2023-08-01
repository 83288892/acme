#!/bin/bash

# 安装 acme.sh 和 jq 工具
echo "正在安装 acme.sh 和 jq 工具..."
apt-get update
apt-get install -y socat
curl https://get.acme.sh | sh
source ~/.bashrc

# 获取 Cloudflare API 密钥和邮箱
read -p "请输入 Cloudflare API 密钥: " cf_api_key
read -p "请输入 Cloudflare 邮箱: " cf_email

# 验证密钥
echo "正在验证密钥..."
if ~/.acme.sh/acme.sh --dns dns_cf --accountemail "$cf_email" --registeraccount; then
    echo "密钥验证成功！"
else
    echo "密钥验证失败，请检查您的密钥和邮箱是否正确。"
    exit 1
fi

# 获取申请证书的域名
read -p "请输入申请证书的域名: " domain

# 执行申请证书命令
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain" -d "*.$domain" --dns dns_cf --debug 2> /dev/null

# 输出结果
if [ $? -eq 0 ]; then
    echo "证书申请成功！您现在可以使用您的证书进行 HTTPS 配置。"
else
    echo "证书申请失败，请检查您的域名是否正确，并确保您的 DNS 设置已经生效。"
fi
