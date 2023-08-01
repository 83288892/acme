#!/bin/bash

# 设置高亮大绿色字体
echo -e "\033[1;32m" 

# 检查 acme.sh 和 socat 是否已安装
if [ ! -f "/root/.acme.sh/acme.sh" ] || [ ! -f "/usr/bin/socat" ]; then
  echo -e "\033[1;32macme.sh 或 socat 未安装,开始安装...\033[0m"
  apt install socat -y
  curl https://get.acme.sh | sh
else
  echo -e "\033[1;32macme.sh 和 socat 已安装,开始申请证书\033[0m"
fi

# 输入 API 密钥和邮箱,并验证
while : 
do
  read -p "请输入 Cloudflare API 密钥:" CF_Key
  read -p "请输入 Cloudflare 邮箱:" CF_Email
  CF_Key="${CF_Key//[[:space:]]/}" # 去除空格
  CF_Email="${CF_Email//[[:space:]]/}"
  
  if [ -z "$CF_Key" ] || [ -z "$CF_Email" ]; then
    echo -e "\033[1;31m密钥或邮箱不能为空!\033[0m"
  else
    break
  fi  
done

# 配置 Cloudflare API 和验证可用性
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
if ~/.acme.sh/acme.sh  --register-account  -m $CF_Email --server letsencrypt --accountemail $CF_Email --accountkey $CF_Key; then
  echo -e "\033[1;32mCloudflare API 验证成功!\033[0m" 
else
  echo -e "\033[1;31mCloudflare API 验证失败,请检查后重试!\033[0m"
  exit 1
fi

# 输入域名并申请证书
read -p "请输入要申请证书的域名:" domain
if ~/.acme.sh/acme.sh --issue --dns dns_cf -d $domain --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "systemctl restart nginx"; then
  echo -e "\033[1;32m证书申请成功!\033[0m"
else
  echo -e "\033[1;31m证书申请失败,请重试!\033[0m"
  exit 1 
fi

# 检查证书目录并复制证书
cert_path="/root/cert"
if [ ! -d "$cert_path" ]; then
  mkdir "$cert_path"
fi
~/.acme.sh/acme.sh --install-cert -d $domain --cert-file $cert_path/cert.pem --key-file $cert_path/key.pem --fullchain-file $cert_path/fullchain.pem --reloadcmd "systemctl restart nginx"
echo -e "\033[1;32m证书已复制到 $cert_path 目录!\033[0m"
