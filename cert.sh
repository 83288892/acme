#!/bin/bash

# 设置绿色高亮字体
echo -e "\033[1;32m"

# 检查 acme.sh 是否已安装
if [ ! -f "/root/.acme.sh/acme.sh" ]; then
  echo -e "\033[1;32macme.sh 未安装,开始安装...\033[0m"

  # 使用官方安装脚本安装 acme.sh
  curl https://get.acme.sh | sh

  if [ ! -f "/root/.acme.sh/acme.sh" ]; then
    echo -e "\033[1;31macme.sh 安装失败,请重试!\033[0m"
    exit 1
  fi

else
  echo -e "\033[1;32macme.sh 已安装,开始申请证书...\033[0m"
fi

# 检查 socat 是否已安装
if [ ! -f "/usr/bin/socat" ]; then
  echo -e "\033[1;32msocat 未安装,开始安装...\033[0m"
  
  apt install socat -y
  
  if [ $? -ne 0 ]; then
    echo -e "\033[1;31msocat 安装失败,请重试!\033[0m"
    exit 1
  fi

else
  echo -e "\033[1;32msocat 已安装,继续...\033[0m"
fi

# 输入 API 信息并验证
while :
do 
  # 读取并处理输入
  echo -e "\033[1;32m请输入 Cloudflare API Key:\033[0m"
  read -p "" CF_Key
  echo -e "\033[1;32m请输入 Cloudflare 邮箱:\033[0m"
  read -p "" CF_Email  

  # 去除空格
  CF_Key="${CF_Key//[[:space:]]/}"
  CF_Email="${CF_Email//[[:space:]]/}"

  if [ -z "$CF_Key" ] || [ -z "$CF_Email" ]; then
    echo -e "\033[1;31mKey 或 Email 不能为空!\033[0m"
  else
    break
  fi
done

# 配置并验证 API 可用性
echo -e "\033[1;32m正在验证 Cloudflare API...\033[0m"
if ! ~/.acme.sh/acme.sh --register-account -m $CF_Email --server letsencrypt --accountemail $CF_Email --accountkey $CF_Key; then
  echo -e "\033[1;31mAPI 验证失败,请检查后重试!\033[0m"
  exit 1
else
  echo -e "\033[1;32mAPI 验证成功!\033[0m"
fi

# 读取并申请证书 
echo -e "\033[1;32m请输入要申请证书的域名:\033[0m"
read -p "" domain
if ! ~/.acme.sh/acme.sh --issue --dns dns_cf -d $domain --keylength ec-256; then
  echo -e "\033[1;31m证书申请失败,请重试!\033[0m"
  exit 1 
else
  echo -e "\033[1;32m证书申请成功!\033[0m"  
fi

# 复制证书到目录
cert_path="/root/cert"
if [ ! -d "$cert_path" ]; then
  mkdir "$cert_path"
fi 
~/.acme.sh/acme.sh --install-cert -d $domain --key-file $cert_path/$domain.key --cert-file $cert_path/fullchain.cer
echo -e "\033[1;32m证书已复制到 $cert_path 目录!\033[0m"
