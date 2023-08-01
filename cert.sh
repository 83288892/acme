#!/bin/bash

# ANSI颜色代码
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 恢复默认颜色

# 函数：检查命令是否存在
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# 函数：安装acme.sh（如果尚未安装）
install_acme_sh() {
  if ! command_exists acme.sh; then
    echo "正在安装acme.sh..."
    curl https://get.acme.sh | sh
    if [ "$?" -ne 0 ]; then
      echo -e "${RED}acme.sh安装失败。${NC}"
      exit 1
    fi
  fi
}

# 函数：自动安装所有依赖工具
auto_install_dependencies() {
  echo "正在安装依赖工具：curl、sudo、socat..."
  if ! command_exists curl; then
    if command_exists apt-get; then
      sudo apt-get update
      sudo apt-get install -y curl
    elif command_exists yum; then
      sudo yum install -y curl
    else
      echo -e "${RED}无法自动安装依赖工具。请手动安装：curl、sudo、socat。${NC}"
      exit 1
    fi
  fi

  if ! command_exists sudo || ! command_exists socat; then
    if command_exists apt-get; then
      sudo apt-get update
      sudo apt-get install -y sudo socat
    elif command_exists yum; then
      sudo yum install -y sudo socat
    else
      echo -e "${RED}无法自动安装依赖工具。请手动安装：sudo、socat。${NC}"
      exit 1
    fi
  fi

  install_acme_sh
}

# 函数：检查是否安装了所有依赖
check_dependencies() {
  echo "检查依赖..."
  if ! command_exists curl || ! command_exists sudo || ! command_exists socat || ! command_exists acme.sh; then
    echo -e "${RED}有一些依赖项未安装。${NC}"
    read -p "是否自动安装所有依赖工具？（y/n）: " auto_install_choice
    if [ "$auto_install_choice" = "y" ]; then
      auto_install_dependencies
    else
      exit 1
    fi
  fi
}

# 函数：验证域名格式
validate_domain() {
  # 域名格式验证的正则表达式
  domain_pattern="^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
  if [[ ! "$1" =~ $domain_pattern ]]; then
    echo -e "${RED}无效的域名格式。请输入有效的域名。${NC}"
    return 1
  fi
}

# 函数：注册单域名证书
register_single_domain_cert() {
  read -p "请输入您的电子邮件地址： " email
  read -p "请输入域名： " domain
  validate_domain "$domain" || return 1
  
  echo "正在注册账户..."
  ~/.acme.sh/acme.sh --register-account -m "$email"

  echo "正在为$domain发放证书..."
  ~/.acme.sh/acme.sh --issue -d "$domain" --standalone
  if [ "$?" -eq 0 ]; then
    echo "证书颁发成功。"
    create_cert_dir "$domain"
    copy_cert_files "$domain"
  else
    echo -e "${RED}无法为$domain颁发证书。${NC}"
  fi
}

# 函数：注册多域名证书
register_multi_domain_cert() {
  read -p "请输入您的电子邮件地址： " email
  read -p "请输入域名数量： " num_domains

  domains=()
  for ((i = 1; i <= num_domains; i++)); do
    read -p "请输入域名$i： " domain
    validate_domain "$domain" || return 1
    domains+=("-d" "$domain")
  done

  echo "正在注册账户..."
  ~/.acme.sh/acme.sh --register-account -m "$email"

  echo "正在发放多域名证书..."
  ~/.acme.sh/acme.sh --issue "${domains[@]}" --standalone
  if [ "$?" -eq 0 ]; then
    echo "证书颁发成功。"
    for domain in "${domains[@]:2}"; do
      create_cert_dir "$domain"
      copy_cert_files "$domain"
    done
  else
    echo -e "${RED}无法颁发多域名证书。${NC}"
  fi
}

# 函数：创建证书目录
create_cert_dir() {
  domain="$1"
  cert_dir="/root/cert/$domain"
  mkdir -p "$cert_dir"
  echo "证书目录已创建：$cert_dir"
}

# 函数：复制证书文件到证书目录
copy_cert_files() {
  domain="$1"
  cert_dir="/root/cert/$domain"
  ~/.acme.sh/acme.sh --install-cert -d "$domain" --cert-file "$cert_dir/cert.pem" \
    --key-file "$cert_dir/key.pem" --fullchain-file "$cert_dir/fullchain.pem" \
    --ca-file "$cert_dir/ca.pem"
  echo "证书文件已复制到$cert_dir"
}

# 函数：使用Cloudflare DNS API申请证书
apply_with_cf_api() {
  if [ -z "$CF_Key" ] || [ -z "$CF_Email" ]; then
    echo -e "${RED}尚未设置Cloudflare API密钥和电子邮件。请使用选项[3-1]设置它们。${NC}"
    return 1
  fi

  read -p "请输入您的域名： " domain
  read -p "请输入泛域名（可选，若无则留空）： " wildcard_domain

  if [ -n "$wildcard_domain" ]; then
    validate_domain "$wildcard_domain" || return 1
  fi
  validate_domain "$domain" || return 1

  domains=("-d" "$domain")
  if [ -n "$wildcard_domain" ]; then
    domains+=("-d" "*.$wildcard_domain")
  fi

  echo "正在使用Cloudflare DNS API颁发证书..."
  ~/.acme.sh/acme.sh --issue --dns dns_cf "${domains[@]}"
  if [ "$?" -eq 0 ]; then
    echo "证书颁发成功。"
    create_cert_dir "$domain"
    copy_cert_files "$domain"
    if [ -n "$wildcard_domain" ]; then
      create_cert_dir "$wildcard_domain"
      copy_cert_files "$wildcard_domain"
    fi
  else
    echo -e "${RED}无法使用Cloudflare DNS API颁发证书。${NC}"
  fi
}

# 函数：卸载脚本并删除证书
uninstall_script_and_certs() {
  echo "正在卸载脚本并删除证书..."
  rm -rf /root/cert
  rm /usr/local/bin/cert.sh
  echo "脚本和证书已成功卸载。"
}

# 函数：显示帮助信息
display_help() {
  echo "使用方法：cert.sh [选项]"
  echo "选项："
  echo "  [1] 检查依赖"
  echo "  [2] 一键申请"
  echo "    [2-1] 单域名证书"
  echo "    [2-2] 多域名证书"
  echo "  [3] CF_API申请"
  echo "    [3-1] 设置Cloudflare API密钥和电子邮件"
  echo "    [3-2] 使用CF_API申请证书"
  echo "  [4] 卸载脚本并删除证书"
  echo "  [5] 帮助"
  echo "  [6] 退出"
  echo "-------------------------------------"
}

# 函数：显示主菜单
display_main_menu() {
  echo "-------------------------------------"
  echo "欢迎使用Cert.sh - 一键申请证书脚本"
  echo "-------------------------------------"
  echo "主菜单："
  echo "[1] 检查依赖"
  echo "[2] 一键申请"
  echo "    [2-1] 单域名证书"
  echo "    [2-2] 多域名证书"
  echo "[3] CF_API申请"
  echo "    [3-1] 设置Cloudflare API密钥和电子邮件"
  echo "    [3-2] 使用CF_API申请证书"
  echo "[4] 卸载脚本并删除证书"
  echo "[5] 帮助"
  echo "[6] 退出"
  echo "-------------------------------------"
}

# 主脚本逻辑
main() {
  check_dependencies

  while true; do
    display_main_menu
    read -p "请输入您的选择： " choice

    case "$choice" in
      1)
        echo "正在检查依赖..."
        check_dependencies
        ;;
      2)
        while true; do
          echo "证书申请菜单："
          echo "[2-1] 单域名证书"
          echo "[2-2] 多域名证书"
          echo "[9] 返回主菜单"
          read -p "请输入您的选择： " cert_choice

          case "$cert_choice" in
            2-1)
              register_single_domain_cert
              ;;
            2-2)
              register_multi_domain_cert
              ;;
            9)
              break
              ;;
            *)
              echo -e "${RED}无效的选择。请重试。${NC}"
              ;;
          esac
        done
        ;;
      3)
        while true; do
          echo "CF_API申请菜单："
          echo "[3-1] 设置Cloudflare API密钥和电子邮件"
          echo "[3-2] 使用CF_API申请证书"
          echo "[9] 返回主菜单"
          read -p "请输入您的选择： " cf_choice

          case "$cf_choice" in
            3-1)
              read -p "请输入您的Cloudflare API密钥： " CF_Key
              read -p "请输入您的Cloudflare电子邮件： " CF_Email
              export CF_Key CF_Email
              echo "Cloudflare API密钥和电子邮件设置成功。"
              ;;
            3-2)
              apply_with_cf_api
              ;;
            9)
              break
              ;;
            *)
              echo -e "${RED}无效的选择。请重试。${NC}"
              ;;
          esac
        done
        ;;
      4)
        uninstall_script_and_certs
        exit 0
        ;;
      5)
        display_help
        ;;
      6)
        echo "正在退出Cert.sh..."
        exit 0
        ;;
      *)
        echo -e "${RED}无效的选择。请重试。${NC}"
        ;;
    esac
  done
}

main
