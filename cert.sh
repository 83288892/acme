#!/bin/bash

# 设置文本颜色
GREEN="\033[1;32m"
NC="\033[0m"

# 检查是否安装了acme和socat，如果没有则安装它们
check_install_dependencies() {
  echo -e "${GREEN}检查并安装依赖项...${NC}"
  
  if ! command -v acme.sh &> /dev/null; then
    echo -e "${GREEN}正在安装acme.sh...${NC}"
    curl https://get.acme.sh | sh
    echo -e "${GREEN}acme.sh 安装成功.${NC}"
  fi

  if ! command -v socat &> /dev/null; then
    echo -e "${GREEN}正在安装socat...${NC}"
    # 根据你的包管理器更改安装命令，比如 apt, yum 等。
    # 示例：Ubuntu/Debian的安装命令为：
    sudo apt update
    sudo apt install -y socat
    echo -e "${GREEN}socat 安装成功.${NC}"
  fi
}

# 配置Cloudflare API密钥和邮箱
configure_cloudflare_credentials() {
  echo -e "${GREEN}配置Cloudflare API密钥和邮箱...${NC}"
  
  read -p "请输入你的Cloudflare API密钥（可见）: " api_key
  read -p "请输入你的Cloudflare邮箱（可见）: " email

  # 设置Cloudflare API密钥和邮箱
  echo "export CF_Key=\"$api_key\"" >> ~/.bashrc
  echo "export CF_Email=\"$email\"" >> ~/.bashrc
  
  # 重新加载 .bashrc 以应用更改
  source ~/.bashrc

  # 验证Cloudflare API密钥和邮箱的有效性
  if ! acme.sh --issue --dns dns_cf -d example.com -d '*.example.com'; then
    echo -e "${GREEN}Cloudflare API密钥或邮箱验证失败。请检查你的凭据是否正确。${NC}"
    exit 1
  fi

  echo -e "${GREEN}Cloudflare API密钥和邮箱配置成功.${NC}"
}

# 颁发证书
issue_certificate() {
  echo -e "${GREEN}颁发证书...${NC}"
  
  read -p "请输入你的域名: " domain
  read -p "请输入1获取泛域名证书，或输入0获取单域名证书: " is_wildcard

  if [ "$is_wildcard" -eq "1" ]; then
    acme.sh --issue --dns dns_cf -d "$domain" -d "*.$domain"
  else
    acme.sh --issue --dns dns_cf -d "$domain"
  fi

  if [ "$?" -ne "0" ]; then
    echo -e "${GREEN}证书颁发失败。退出脚本...${NC}"
    exit 1
  fi

  echo -e "${GREEN}证书颁发成功.${NC}"
}

# 复制证书到 /root/cert 目录
copy_certificate() {
  echo -e "${GREEN}复制证书到 /root/cert 目录...${NC}"
  
  if [ ! -d "/root/cert" ]; then
    mkdir /root/cert
  fi
  
  acme.sh --install-cert -d "$domain" --cert-file /root/cert/cert.pem --key-file /root/cert/key.pem --ca-file /root/cert/ca.pem --fullchain-file /root/cert/fullchain.pem
  
  echo -e "${GREEN}证书已成功复制到 /root/cert 目录.${NC}"
}

# 主要脚本
echo -e "${GREEN}=== 一键DNS证书颁发工具 ===${NC}"

check_install_dependencies
configure_cloudflare_credentials
issue_certificate
copy_certificate

echo -e "${GREEN}=== 证书颁发完成 ===${NC}"
