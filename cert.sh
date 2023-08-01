#!/bin/bash
# 脚本名称: cert.sh
# 脚本功能: 使用acme.sh工具申请SSL证书
# 脚本作者: Bing
# 脚本版本: 1.1
# 脚本日期: 2023-08-01

# 定义颜色变量
RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"

# 定义依赖变量
CURL=$(which curl)
SOCAT=$(which socat)
ACME=$(which acme.sh)

# 定义证书保存路径变量
CERT_PATH="/root/cert"

# 定义CF API信息变量
CF_KEY=""
CF_EMAIL=""

# 检查是否为root用户,如果不是则退出脚本
check_root() {
  if [ $UID -ne 0 ]; then
    echo -e "${RED}错误:请以root用户运行此脚本!${RESET}"
    exit 1
  fi
}

# 检查依赖是否完整,如果不是则提示用户选择安装方式
check_deps() {
  echo -e "${GREEN}正在检查依赖...${RESET}"
  if [ -z "$CURL" ] || [ -z "$SOCAT" ] || [ -z "$ACME" ]; then
    echo -e "${RED}错误:缺少必要的依赖!${RESET}"
    echo "您需要安装以下工具:"
    [ -z "$CURL" ] && echo "curl"
    [ -z "$SOCAT" ] && echo "socat"
    [ -z "$ACME" ] && echo "acme.sh"
    echo "请选择安装方式:"
    echo "[1] 自动安装(使用yum或apt-get命令)"
    echo "[2] 手动安装(自己下载并安装)"
    read -p "请输入您的选择(1或2):" choice
    case $choice in
      1)
        auto_install_deps
        ;;
      2)
        manual_install_deps
        ;;
      *)
        echo -e "${RED}错误:无效的输入!${RESET}"
        exit 1
        ;;
    esac
  else
    echo -e "${GREEN}恭喜:所有依赖都已安装!${RESET}"
  fi
}

# 自动安装依赖的函数
auto_install_deps() {
  if [ -f /etc/redhat-release ]; then
    yum install curl socat -y
  elif [ -f /etc/lsb-release ]; then
    apt-get install curl socat -y
  else
    echo -e "${RED}错误:无法识别您的系统类型,请手动安装依赖!${RESET}"
    exit 1
  fi

  if [ -z "$ACME" ]; then
    curl https://get.acme.sh | sh
    ACME=$(which acme.sh)
  fi

  check_deps
}

# 手动安装依赖的函数
manual_install_deps() {
  echo "请手动下载并安装以下工具:"
  [ -z "$CURL" ] && echo "curl: https://curl.se/download.html"
  [ -z "$SOCAT" ] && echo "socat: http://www.dest-unreach.org/socat/download/"
  [ -z "$ACME" ] && echo "acme.sh: https://github.com/acmesh-official/acme.sh"
  echo "安装完成后,请重新运行此脚本!"
  exit 1
}

# 检查域名格式的函数
check_domain() {
  local domain=$1
  local regex="^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$"
  if [[ ! $domain =~ $regex ]]; then
    echo -e "${RED}错误:无效的域名格式,请重新输入!${RESET}"
    return 1
  else
    return 0
  fi
}

# 申请单域名证书的函数
apply_single_cert() {
  echo "请输入您要申请证书的单个域名(例如:example.com):"
  read -p "域名:" domain
  check_domain $domain
  if [ $? -ne 0 ]; then
    apply_single_cert
    return
  fi

  echo -e "${GREEN}正在申请证书,请稍等...${RESET}"
  $ACME --register-account -m xxxx@gmail.com
  $ACME --issue -d $domain --standalone

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}恭喜:证书申请成功!${RESET}"
    mkdir -p $CERT_PATH/$domain
    cp ~/.acme.sh/$domain/* $CERT_PATH/$domain/
    echo "您的证书文件已保存在$CERT_PATH/$domain/目录下,请妥善保管!"
  else
    echo -e "${RED}错误:证书申请失败!${RESET}"
    exit 1
  fi

}

# 申请多域名证书的函数
apply_multi_cert() {
  echo "请输入您要申请证书的域名数量(最多支持100个):"
  read -p "数量:" num
  if [ $num -lt 1 ] || [ $num -gt 100 ]; then
    echo -e "${RED}错误:无效的数量,请重新输入!${RESET}"
    apply_multi_cert
    return
  fi

  domains=()
  for i in $(seq 1 $num); do
    echo "请输入第$i个域名(例如:example.com):"
    read -p "域名:" domain
    check_domain $domain
    if [ $? -ne 0 ]; then
      i=$((i-1))
      continue
    fi

    domains+=($domain)
  done

  echo -e "${GREEN}正在申请证书,请稍等...${RESET}"
  $ACME --register-account -m xxxx@gmail.com
  $ACME --issue ${domains[@]/#/-d } --standalone

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}恭喜:证书申请成功!${RESET}"
    for domain in ${domains[@]}; do
      mkdir -p $CERT_PATH/$domain
      cp ~/.acme.sh/$domain/* $CERT_PATH/$domain/
      echo "您的证书文件已保存在$CERT_PATH/$domain/目录下,请妥善保管!"
    done
  else
    echo -e "${RED}错误:证书申请失败!${RESET}"
    exit 1
  fi

}

# 申请CF API证书的函数
apply_cf_cert() {
  echo "请输入您的CF API密钥(可以在Cloudflare网站上获取):"
  read -p "密钥:" CF_KEY
  echo "请输入您的CF邮箱地址(用于注册Cloudflare账号):"
  read -p "邮箱:" CF_EMAIL

  export CF_Key="$CF_KEY"
  export CF_Email="$CF_EMAIL"

  echo "请输入您要申请证书的主域名(例如:example.com):"
  read -p "域名:" domain
  check_domain $domain
  if [ $? -ne 0 ]; then
    apply_cf_cert
    return
  fi

  echo "请输入您要申请证书的泛域名(例如:*.example.com):"
  read -p "泛域名:" wildcard
  check_domain $wildcard
  if [ $? -ne 0 ]; then
    apply_cf_cert
    return
  fi

  echo -e "${GREEN}正在申请证书,请稍等...${RESET}"
  $ACME --register-account -m xxxx@gmail.com
  $ACME --issue --dns dns_cf -d $domain -d $wildcard

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}恭喜:证书申请成功!${RESET}"
    mkdir -p $CERT_PATH/$domain
    cp ~/.acme.sh/$domain/* $CERT_PATH/$domain/
    echo "您的证书文件已保存在$CERT_PATH/$domain/目录下,请妥善保管!"
  else
    echo -e "${RED}错误:证书申请失败!${RESET}"
    exit 1
  fi

}

# 完全卸载脚本并删除证书的函数
uninstall() {
  echo "您确定要完全卸载脚本并删除证书吗?这将无法恢复!"
  read -p "请输入y或n:" choice
  case $choice in
    y|Y)
      echo -e "${GREEN}正在卸载脚本并删除证书,请稍等...${RESET}"
      rm -rf $ACME
      rm -rf ~/.acme.sh
      rm -rf $CERT_PATH
      rm -f $0
      echo -e "${GREEN}恭喜:脚本卸载成功,证书已删除!${RESET}"
      ;;
    n|N)
      echo "您已取消卸载操作,返回主菜单。"
      main_menu
      ;;
    *)
      echo -e "${RED}错误:无效的输入,请重新输入!${RESET}"
      uninstall
      ;;
  esac
}

# 显示帮助信息的函数
show_help() {
  echo "脚本简介:"
  echo "这是一个使用acme.sh工具申请SSL证书的脚本,支持三种申请方式:"
  echo "[1] 单域名证书:申请一个指定的域名的证书,例如:example.com"
  echo "[2] 多域名证书:申请多个指定的域名的证书,例如:example.com, www.example.com, blog.example.com等"
  echo "[3] CF API证书:使用Cloudflare API申请一个主域名和一个泛域名的证书,例如:example.com, *.example.com"
  echo "脚本用法:"
  echo "执行./cert.sh命令,根据提示选择申请方式,并输入相应的信息,等待申请完成。"
  echo "您可以在$CERT_PATH目录下找到您申请的证书文件。"
  echo "您可以执行./cert.sh --help命令查看帮助信息。"
  echo "您可以执行./cert.sh --uninstall命令完全卸载脚本并删除证书。"
}

# 显示主菜单的函数
main_menu() {
  clear
  echo "欢迎使用一键申请证书脚本!"
  echo "您可以选择以下三种申请方式:"
  echo "[1] 单域名证书"
  echo "[2] 多域名证书"
  echo "[3] CF API证书"
  echo "[4] 完全卸载脚本并删除证书"
  echo "[5] 帮助"
  echo "[6] 退出"
  read -p "请输入您的选择(1-6):" choice
  case $choice in
    1)
      apply_single_cert
      ;;
    2)
      apply_multi_cert
      ;;
    3)
      apply_cf_cert
      ;;
    4)
      uninstall
      ;;
    5)
      show_help
      ;;
    6)
      exit 0
      ;;
    *)
      echo -e "${RED}错误:无效的输入,请重新输入!${RESET}"
      main_menu
      ;;
  esac

}

# 处理命令行参数的函数
parse_args() {
  if [ $# -eq 0 ]; then
    main_menu
  elif [ "$1" == "--help" ]; then
    show_help
    exit 0
  elif [ "$1" == "--uninstall" ]; then
    uninstall
    exit 0
  else
    echo "无效的参数!"
    show_help
    exit 1
  fi
}

# 主函数，首先检查是否为root用户，然后检查依赖是否完整，并处理命令行参数
main() {
  check_root
  check_deps
  parse_args "$@"
}

main "$@"
