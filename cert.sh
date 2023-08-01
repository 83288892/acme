#!/bin/bash

# 安装依赖函数
install_dependencies() {
    echo -e "\e[1;32m正在安装依赖...\e[0m"
    sudo apt update
    sudo apt install curl socat -y
}

# 安装 acme.sh 脚本函数
install_acme_script() {
    echo -e "\e[1;32m正在安装 acme.sh 脚本...\e[0m"
    curl https://get.acme.sh | sh
    # 添加 acme.sh 到系统变量
    echo 'export PATH="$HOME/.acme.sh:$PATH"' >> ~/.bashrc
    source ~/.bashrc
}

# 申请单域名证书函数
apply_single_domain_certificate() {
    read -p "请输入邮箱地址: " email
    read -p "请输入单域名: " domain

    if [ -z "$email" ] || [ -z "$domain" ]; then
        echo -e "\e[1;31m错误：邮箱地址和单域名不能为空\e[0m"
        exit 1
    fi

    echo -e "\e[1;32m正在申请单域名证书，请稍等...\e[0m"
    acme.sh --register-account -m "$email"
    acme.sh --issue -d "$domain" --standalone

    if [ $? -eq 0 ]; then
        mkdir -p "/root/cert/$domain"
        acme.sh --install-cert -d "$domain" \
            --key-file "/root/cert/$domain/private.key" \
            --fullchain-file "/root/cert/$domain/fullchain.crt"
        echo -e "\e[1;32m证书申请成功，已保存到 /root/cert/$domain 目录\e[0m"
    else
        echo -e "\e[1;31m证书申请失败，请检查错误信息\e[0m"
    fi
}

# 申请多域名证书函数
apply_multiple_domain_certificate() {
    read -p "请输入邮箱地址: " email
    read -p "请输入域名数量: " num_domains

    if [ -z "$email" ] || [ -z "$num_domains" ] || ! [[ "$num_domains" =~ ^[0-9]+$ ]]; then
        echo -e "\e[1;31m错误：邮箱地址和域名数量不能为空且必须为数字\e[0m"
        exit 1
    fi

    domains=()
    for ((i=1; i<=num_domains; i++)); do
        read -p "请输入第 $i 个域名: " domain
        if [ -z "$domain" ]; then
            echo -e "\e[1;31m错误：域名不能为空\e[0m"
            exit 1
        fi
        domains+=("-d $domain")
    done

    echo -e "\e[1;32m正在申请多域名证书，请稍等...\e[0m"
    acme.sh --register-account -m "$email"
    acme.sh --issue "${domains[@]}" --standalone

    if [ $? -eq 0 ]; then
        for domain in "${domains[@]}"; do
            domain=$(echo "$domain" | cut -d' ' -f2) # Extract domain name from '-d domain' format
            mkdir -p "/root/cert/$domain"
            acme.sh --install-cert "$domain" \
                --key-file "/root/cert/$domain/private.key" \
                --fullchain-file "/root/cert/$domain/fullchain.crt"
            echo -e "\e[1;32m证书申请成功，已保存到 /root/cert/$domain 目录\e[0m"
        done
    else
        echo -e "\e[1;31m证书申请失败，请检查错误信息\e[0m"
    fi
}

# 主菜单函数
main_menu() {
    echo "欢迎使用证书申请脚本"
    echo "[1] 申请单域名证书"
    echo "[2] 申请多域名证书"
    echo "[3] 返回主菜单"
    echo "[4] 退出脚本"

    read -p "请选择操作： " choice

    case "$choice" in
        1) apply_single_domain_certificate ;;
        2) apply_multiple_domain_certificate ;;
        3) main_menu ;;
        4) exit ;;
        *) echo -e "\e[1;31m错误：无效的选择\e[0m" ;;
    esac
}

# 帮助信息函数
show_help() {
    echo "cret.sh 一键申请证书脚本"
    echo "用法: ./cret.sh [选项]"
    echo "选项:"
    echo "    -h, --help       显示帮助信息"
}

# 主函数
main() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_help
        exit 0
    fi

    # 检查依赖并安装
    if ! command -v curl &> /dev/null || ! command -v socat &> /dev/null; then
        install_dependencies
    fi

    # 安装 acme.sh 脚本
    if ! command -v acme.sh &> /dev/null; then
        install_acme_script
    fi

    # 运行主菜单
    main_menu
}

# 调用主函数
main "$@"
