#!/bin/bash
# cretcf.sh: 一键申请证书的脚本，使用Cloudflare API
# 作者: Bing
# 日期: 2023-08-01

# 设置所有提示输出文本颜色高亮绿色
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

# 定义一个函数，用于输出错误信息并退出脚本
error() {
    echo -e "${RED}$1${RESET}"
    exit 1
}

# 定义一个函数，用于输出帮助信息
help() {
    echo -e "${GREEN}用法: ./cretcf.sh [选项]${RESET}"
    echo -e "${GREEN}选项:${RESET}"
    echo -e "${GREEN}  -h, --help     显示帮助信息${RESET}"
    echo -e "${GREEN}  -v, --version  显示脚本版本${RESET}"
}

# 定义一个函数，用于输出脚本版本
version() {
    echo -e "${GREEN}cretcf.sh: 一键申请证书的脚本，使用Cloudflare API v1.0${RESET}"
}

# 定义一个函数，用于检查域名是否合法
check_domain() {
    # 使用正则表达式验证域名格式
    if [[ ! $1 =~ ^[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,6}$ ]]; then
        error "域名格式不正确，请重新输入"
    fi
}

# 定义一个函数，用于检查Cloudflare API密钥和邮箱是否有效
check_cf_api() {
    # 使用curl命令发送请求到Cloudflare API，获取用户信息
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
        -H "X-Auth-Key: $CF_Key" \
        -H "X-Auth-Email: $CF_Email" \
        -H "Content-Type: application/json")

    # 使用jq命令解析返回的JSON数据，获取success字段的值
    success=$(echo $response | jq -r '.success')

    # 如果success字段的值为true，说明API密钥和邮箱有效，返回0
    # 如果success字段的值为false，说明API密钥和邮箱无效，输出错误信息并返回1
    if [ "$success" = "true" ]; then
        return 0
    else
        echo -e "${RED}Cloudflare API密钥或邮箱无效，请检查输入${RESET}"
        return 1
    fi
}

# 定义一个函数，用于安装依赖
install_deps() {
    # 检查本地环境是否有curl socat jq，如果没有执行apt update sudo && apt install curl socat jq -y安装curl socat jq
    echo -e "${GREEN}正在检查依赖...${RESET}"
    if ! command -v curl &> /dev/null; then
        echo -e "${GREEN}正在安装curl...${RESET}"
        apt update sudo && apt install curl -y || error "安装curl失败，请检查网络连接"
    fi

    if ! command -v socat &> /dev/null; then
        echo -e "${GREEN}正在安装socat...${RESET}"
        apt update sudo && apt install socat -y || error "安装socat失败，请检查网络连接"
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${GREEN}正在安装jq...${RESET}"
        apt update sudo && apt install jq -y || error "安装jq失败，请检查网络连接"
    fi

    # 安装acme脚本 执行https://get.acme.sh | sh 完成后添加acme.sh到系统变量 
    echo -e "${GREEN}正在安装acme.sh...${RESET}"
    curl https://get.acme.sh | sh || error "安装acme.sh失败，请检查网络连接"
    export PATH=$PATH:~/.acme.sh || error "添加acme.sh到系统变量失败，请检查环境配置"
}

# 定义一个函数，用于设置Cloudflare API密钥和邮箱
set_cf_api() {
    # 要求输入CF密钥 CF邮箱 export CF_Key="您的_Cloudflare_API_密钥" 
    # export CF_Email="您的_email@example.com"
    echo -e "${GREEN}请输入Cloudflare API密钥:${RESET}"
    read CF_Key
    echo -e "${GREEN}请输入Cloudflare邮箱:${RESET}"
    read CF_Email

    # 输入完成后开始验证，验证通过后 进入菜单项[2]CF_API申请证书
    echo -e "${GREEN}正在验证Cloudflare API密钥和邮箱...${RESET}"
    check_cf_api # 调用check_cf_api函数验证API密钥和邮箱是否有效

    # 如果验证成功，输出提示信息并返回0
    # 如果验证失败，输出错误信息并返回1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}验证成功，您可以继续申请证书${RESET}"
        return 0
    else
        echo -e "${RED}验证失败，您需要重新设置Cloudflare API密钥和邮箱${RESET}"
        return 1
    fi
}

# 定义一个函数，用于申请证书
apply_cert() {
    # 提示输入域名还有泛域名 域名检查通过后 执行~/.acme.sh/acme.sh --issue --dns dns_cf -d 域名 -d 泛域名 
    echo -e "${GREEN}请输入域名:${RESET}"
    read domain
    check_domain $domain # 调用check_domain函数验证域名合法性

    echo -e "${GREEN}请输入泛域名:${RESET}"
    read wildcard
    check_domain $wildcard # 调用check_domain函数验证泛域名合法性

    # 申请证书
    echo -e "${GREEN}正在申请证书...${RESET}"
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d $domain -d $wildcard || error "申请证书失败，请检查域名解析"

    # 创建证书目录并复制证书文件
    echo -e "${GREEN}正在创建证书目录并复制证书文件...${RESET}"
    mkdir -p /root/cert/$domain || error "创建证书目录失败，请检查权限"
    cp ~/.acme.sh/$domain/* /root/cert/$domain/ || error "复制证书文件失败，请检查权限"

    # 输出成功提示
    echo -e "${GREEN}申请证书成功，证书文件保存在/root/cert/$domain/目录下${RESET}"
}

# 定义一个函数，用于弹出主菜单选项
show_menu() {
    echo -e "${GREEN}请选择操作:${RESET}"
    echo -e "${GREEN}[1] 设置Cloudflare API密钥和邮箱${RESET}"
    echo -e "${GREEN}[2] 申请证书${RESET}"
    echo -e "${GREEN}[3] 返回${RESET}"
    echo -e "${GREEN}[4] 退出${RESET}"
}

# 定义一个函数，用于处理用户输入的选项
handle_choice() {
    case $1 in
        1)  # 调用set_cf_api函数设置Cloudflare API密钥和邮箱
            set_cf_api
            ;;
        2)  # 调用apply_cert函数申请证书
            apply_cert
            ;;
        3)  # 返回主菜单，重新调用show_menu函数显示主菜单
            show_menu
            ;;
        4)  # 退出脚本
            echo -e "${GREEN}感谢使用，再见！${RESET}"
            exit 0
            ;;
        *)  # 输入无效选项，提示重新输入
            echo -e "${RED}无效的选项，请重新输入${RESET}"
            ;;
    esac
}
