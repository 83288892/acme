#!/bin/bash

# 字体高亮 大绿色
echo -e "\033[1;32m"

# 检查工具依赖
if ! command -v acme.sh >/dev/null 2>&1; then
  curl https://get.acme.sh | sh
  export PATH=$PATH:~/.acme.sh 
fi

if ! command -v socat >/dev/null 2>&1; then
  sudo apt install -y socat
fi

# 输入API密钥和邮箱  
read -p "请输入Cloudflare API密钥:" CF_Key
read -p "请输入Cloudflare 邮箱:" CF_Email

# 配置并验证Cloudflare API
export CF_Key="$CF_Key"
export CF_Email="$CF_Email"


# 输入域名
read -p "请输入要申请证书的主域名:" main_domain
read -p "请输入要申请证书的泛域名:" sans_domain

# 申请证书
if ! acme.sh --issue --dns dns_cf -d $main_domain -d "*.$sans_domain" --keylength ec-256 --force; then
  echo -e "\033[1;31m证书申请失败\033[0m"
  exit 1
fi

echo -e "\033[1;32m证书申请成功\033[0m"

# 检查证书目录是否存在
if [ ! -d "/root/cert" ]; then
  mkdir /root/cert
fi

# 拷贝证书并替换私钥文件名
acme.sh --install-cert -d $main_domain --key-file "/root/cert/${main_domain}_.key" --fullchain-file /root/cert/fullchain.cer --ecc

echo -e "\033[1;32m证书已保存到/root/cert目录\033[0m"
