#!/bin/bash
# cret.sh: 一键申请证书的脚本
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
    echo -e "${GREEN}用法: ./cret.sh [选项]${RESET}"
    echo -e "${GREEN}选项:${RESET}"
    echo -e "${GREEN}  -h, --help     显示帮助信息${RESET}"
    echo -e "${GREEN}  -v, --version  显示脚本版本${RESET}"
}

# 定义一个函数，用于输出脚本版本
version() {
    echo -e "${GREEN}cret.sh: 一键申请证书的脚本 v1.0${RESET}"
}

# 定义一个函数，用于检查域名是否合法
check_domain() {
    # 使用正则表达式验证域名格式
    if [[ ! $1 =~ ^[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,6}$ ]]; then
        error "域名格式不正确，请重新输入"
    fi
}

# 定义一个函数，用于安装依赖
install_deps() {
    # 检查本地环境是否有curl socat，如果没有执行apt update sudo && apt install curl socat -y安装curl socat
    echo -e "${GREEN}正在检查依赖...${RESET}"
    if ! command -v curl &> /dev/null; then
        echo -e "${GREEN}正在安装curl...${RESET}"
        apt update sudo && apt install curl -y || error "安装curl失败，请检查网络连接"
    fi

    if ! command -v socat &> /dev/null; then
        echo -e "${GREEN}正在安装socat...${RESET}"
        apt update sudo && apt install socat -y || error "安装socat失败，请检查网络连接"
    fi

    # 安装acme脚本 执行https://get.acme.sh | sh 完成后添加acme.sh到系统变量 
    echo -e "${GREEN}正在安装acme.sh...${RESET}"
    curl https://get.acme.sh | sh || error "安装acme.sh失败，请检查网络连接"
    export PATH=$PATH:~/.acme.sh || error "添加acme.sh到系统变量失败，请检查环境配置"
}

# 定义一个函数，用于申请单域名证书
apply_single_cert() {
    # 提示输入单域名 等待输入单域名后执行~/.acme.sh/acme.sh --register-account -m xxxx@gmail.com 
    # ~/.acme.sh/acme.sh --issue -d 域名 --standalone 申请成功后创建/root/cert/对应域名的目录/ 复制所有证书文件到/root/cert/对应域名的目录/
    echo -e "${GREEN}请输入单域名:${RESET}"
    read domain
    check_domain $domain # 调用check_domain函数验证域名合法性

    # 设置邮箱地址为xxxx@gmail.com
    email="xxxx@gmail.com"

    # 注册账号并申请证书
    echo -e "${GREEN}正在注册账号并申请证书...${RESET}"
    ~/.acme.sh/acme.sh --register-account -m $email || error "注册账号失败，请检查网络连接"
    ~/.acme.sh/acme.sh --issue -d $domain --standalone || error "申请证书失败，请检查域名解析"

    # 创建证书目录并复制证书文件
    echo -e "${GREEN}正在创建证书目录并复制证书文件...${RESET}"
    mkdir -p /root/cert/$domain || error "创建证书目录失败，请检查权限"
    cp ~/.acme.sh/$domain/* /root/cert/$domain/ || error "复制证书文件失败，请检查权限"

    # 输出成功提示
    echo -e "${GREEN}申请单域名证书成功，证书文件保存在/root/cert/$domain/目录下${RESET}"
}

# 定义一个函数，用于申请多域名证书
apply_multi_cert() {
    # 选择此项后 首先输入域名数量 然后根据域名数量 填写对应数量的域名 域名输入完成后 执行~/.acme.sh/acme.sh --register-account -m xxxx@gmail.com 
    # --issue -d 域名1 -d 域名 -d 域名 --standalone 申请成功后创建/root/cert/对应域名的目录/ 复制所有证书文件到/root/cert/对应域名的目录/
    echo -e "${GREEN}请输入域名数量:${RESET}"
    read num
    # 使用正则表达式验证域名数量为正整数
    if [[ ! $num =~ ^[1-9][0-9]*$ ]]; then
        error "域名数量不正确，请重新输入"
    fi

    # 定义一个空数组，用于存储输入的域名
    domains=()

    # 根据域名数量，循环读取输入的域名，并调用check_domain函数验证域名合法性
    for ((i=1; i<=$num; i++)); do
        echo -e "${GREEN}请输入第$i个域名:${RESET}"
        read domain
        check_domain $domain
        domains+=($domain) # 将域名添加到数组中
    done

    # 设置邮箱地址为xxxx@gmail.com
    email="xxxx@gmail.com"

    # 注册账号并申请证书
    echo -e "${GREEN}正在注册账号并申请证书...${RESET}"
    ~/.acme.sh/acme.sh --register-account -m $email || error "注册账号失败，请检查网络连接"
    
    # 构造acme.sh命令的参数，根据数组中的域名添加-d选项
    params=""
    for domain in ${domains[@]}; do
        params="$params -d $domain"
    done

    # 执行acme.sh命令，传入参数申请多域名证书
    ~/.acme.sh/acme.sh --issue $params --standalone || error "申请证书失败，请检查域名解析"

    # 创建证书目录并复制证书文件
    echo -e "${GREEN}正在创建证书目录并复制证书文件...${RESET}"
    
    # 遍历数组中的域名，为每个域名创建目录并复制文件
    for domain in ${domains[@]}; do
        mkdir -p /root/cert/$domain || error "创建证书目录失败，请检查权限"
        cp ~/.acme.sh/$domain/* /root/cert/$domain/ || error "复制证书文件失败，请检查权限"
        echo -e "${GREEN}申请$domain的证书成功，证书文件保存在/root/cert/$domain/目录下${RESET}"
    done

}

# 定义一个函数，用于弹出主菜单选项
show_menu() {
    echo -e "${GREEN}请选择操作:${RESET}"
    echo -e "${GREEN}[1] 申请单域名证书${RESET}"
    echo -e "${GREEN}[2] 申请多域名证书${RESET}"
    echo -e "${GREEN}[3] 返回${RESET}"
    echo -e "${GREEN}[4] 退出${RESET}"
}

# 定义一个函数，用于处理用户输入的选项
handle_choice() {
    
    case $1 in
        1)  # 调用apply_single_cert函数申请单域名证书
            apply_single_cert
            ;;
        2)  # 调用apply_multi_cert函数申请多域名证书
            apply_multi_cert
            ;;
        3)  # 返回主菜单，重新调调用show_menu函数显示主菜单







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

# 安装依赖
install_deps

# 解析命令行参数，如果有-h或--help选项，调用help函数输出帮助信息并退出
# 如果有-v或--version选项，调用version函数输出版本信息并退出
# 如果没有参数，继续执行后续逻辑
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            help
            exit 0
            ;;
        -v|--version)
            version
            exit 0
            ;;
        *)
            error "无效的参数，请使用-h或--help查看帮助信息"
            ;;
    esac
    shift # 移动参数位置，处理下一个参数
done

# 循环显示主菜单，并读取用户输入的选项，调用handle_choice函数处理选项
while true; do
    show_menu # 调用show_menu函数显示主菜单
    read choice # 读取用户输入的选项
    handle_choice $choice # 调用handle_choice函数处理选项
done

        
