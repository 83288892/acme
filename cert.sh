#!/bin/bash

# 字体高亮 大绿色
echo -e "\033[1;32m"  

# 检查acme.sh和socat是否安装
if ! command -v acme.sh >/dev/null 2>&1 || ! command -v socat >/dev/null 2>&1; then
  # 如果没有安装,提示并安装
  echo -e "\033[1;33macme.sh或socat未安装,正在安装...\033[0m"
  apt install -y acme.sh socat 
fi

# 输入API密钥和邮箱  
read -p "请输入Cloudflare API密钥:" CF_Key
read -p "请输入Cloudflare 邮箱:" CF_Email

# 配置并验证Cloudflare API
export CF_Key="$CF_Key"
export CF_Email="$CF_Email"
if ! acme.sh --issue --dns dns_cf -d example.com -k ec-256 --force; then
  echo -e "\033[1;31mCloudflare API验证失败,请检查密钥和邮箱是否正确\033[0m"
  exit 1
fi  

# 选择证书类型
read -p "请选择证书类型 (1: 单域名, 2: 泛域名): " cert_type

# 输入域名
read -p "请输入要申请证书的主域名:" main_domain

if [ $cert_type -eq 2 ]; then
  read -p "请输入要申请证书的泛域名:" sans_domain
fi

# 申请证书
if [ $cert_type -eq 1 ]; then
  if ! acme.sh --issue --dns dns_cf -d $main_domain --keylength ec-256 --force; then
    echo -e "\033[1;31m证书申请失败\033[0m"
    exit 1
  fi
else
  if ! acme.sh --issue --dns dns_cf -d $main_domain -d "*.$main_domain" --keylength ec-256 --force; then
    echo -e "\033[1;31m证书申请失败\033[0m"
    exit 1
  fi
fi

echo -e "\033[1;32m证书申请成功\033[0m"

# 检查证书目录是否存在
if [ ! -d "/root/cert" ]; then
  mkdir /root/cert
fi

# 拷贝证书
acme.sh --install-cert -d $main_domain --key-file /root/cert/private.key --fullchain-file /root/cert/fullchain.cer --ecc

echo -e "\033[1;32m证书已保存到/root/cert目录\033[0m"
