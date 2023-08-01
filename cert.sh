#!/bin/bash

# 字体高亮 大绿色
echo -e "\033[1;32m开始安装所需工具\033[0m" 

# 检查acme.sh是否安装
if ! command -v acme.sh >/dev/null 2>&1; then
  echo -e "\033[1;33macme.sh未安装,开始安装acme.sh\033[0m"
  curl https://get.acme.sh | sh  
fi

# 检查socat是否安装
if ! command -v socat >/dev/null 2>&1; then
  echo -e "\033[1;33msocat未安装,开始安装socat\033[0m"
  git clone https://github.com/socat-1.7.3.2/socat.git
  cd socat && ./configure && make && make install
fi

echo -e "\033[1;32m所需工具安装完成\033[0m"

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

# 输入要申请的证书类型
echo -e "\033[1;32m请选择要申请的证书类型:\033[0m"
echo -e "\033[1;32m1. 单域名证书\033[0m"
echo -e "\033[1;32m2. 主域名+泛域名证书\033[0m"
echo -e "\033[1;32m3. 不申请证书\033[0m"
read -p "请输入(1/2/3):" cert_type

if [ $cert_type = 1 ]; then
  read -p "请输入单域名:" domain
  acme_args="-d $domain"
elif [ $cert_type = 2 ]; then
  read -p "请输入主域名:" main_domain
  read -p "请输入泛域名:" sans_domain
  acme_args="-d $main_domain -d $sans_domain" 
elif [ $cert_type = 3 ]; then
  echo -e "\033[1;32m已选择不申请证书,脚本退出\033[0m"
  exit 0
else
  echo -e "\033[1;31m输入错误,退出脚本\033[0m" 
  exit 1
fi

# 申请证书
if ! acme.sh --issue --dns dns_cf $acme_args --keylength ec-256 --force; then
  echo -e "\033[1;31m证书申请失败\033[0m"
  exit 1 
fi

echo -e "\033[1;32m证书申请成功\033[0m" 

# 检查证书目录
if [ ! -d "/root/cert" ]; then
  mkdir /root/cert
fi

# 拷贝证书
acme.sh --install-cert -d $domain --key-file /root/cert/private.key --fullchain-file /root/cert/fullchain.cer --ecc

echo -e "\033[1;32m证书已保存到/root/cert目录\033[0m"
