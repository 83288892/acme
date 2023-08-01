#!/bin/bash

# 设置颜色变量
GREEN='\033[1;32m'
RED='\033[0;31m'
NC='\033[0m' 

# 加载acme.sh路径
export PATH="$HOME/.acme.sh:$PATH"  

# 定义函数安装依赖
install_dep() {
  if ! command -v $1 &> /dev/null; then
    echo -e "${GREEN}Installing $1${NC}"
    if [ $1 = "acme.sh" ]; then
      curl https://get.acme.sh | sh
    elif [ $1 = "socat" ]; then  
      apt-get install -y socat
    fi
  fi
}

# 检查并安装依赖
install_dep acme.sh
install_dep socat

# 输入API信息
echo -e "${GREEN}请输入Cloudflare API密钥和邮箱:${NC}"
read -p "API密钥:" CF_API_KEY
read -p "邮箱:" CF_EMAIL

# 验证API 
verify_api() {
  echo -e "${GREEN}正在验证API信息...${NC}" 
  if ! acme.sh --set-default-ca --server letsencrypt --dns dns_cf --accountemail $CF_EMAIL --accountkey $CF_API_KEY; then
    echo -e "${RED}API验证失败,请检查信息${NC}"
    exit 1
  fi
}

verify_api

# 定义证书保存路径  
CERT_PATH="/root/cert"

# 申请证书函数
issue_cert() {
  domain=$1
  echo -e "${GREEN}开始为$domain申请证书${NC}"
  
  if ! acme.sh --issue --dns dns_cf -d $domain --key-file $CERT_PATH/$domain.key --fullchain-file $CERT_PATH/$domain.cer --keylength ec-256 --force; then
    echo -e "${RED}申请证书失败,错误信息:${NC}" && acme.sh --issue --dns dns_cf -d $domain --key-file $CERT_PATH/$domain.key --fullchain-file $CERT_PATH/$domain.cer --keylength ec-256 --force --debug
  fi

  echo -e "${GREEN}证书申请成功${NC}"
}

# 输入域名信息
while :; do
  echo -e "${GREEN}请输入域名类型:${NC}"
  read -p "[1] 主域名 [2] 单域名 [3] 泛域名 [其他退出]" input
  
  case $input in
  1)
    read -p "请输入主域名:" main_domain
    issue_cert $main_domain
    break
    ;;
  2)
    read -p "请输入单域名:" single_domain  
    issue_cert $single_domain
    break
    ;;
  3)
    read -p "请输入泛域名:" wildcard_domain 
    issue_cert *.$wildcard_domain
    break
    ;;
  *)
    echo -e "${RED}输入有误,退出脚本${NC}"
    exit 1
    ;;
  esac
done

# 检查证书目录
if [ ! -d "$CERT_PATH" ]; then
  mkdir -p "$CERT_PATH" 
fi

# 完成提示
echo -e "${GREEN}证书申请完成,已保存到$CERT_PATH${NC}"
