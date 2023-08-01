#!/bin/bash

# 检查是否支持 ANSI 转义序列
if [ -t 1 ]; then
    red='\033[31m'
    green='\033[32m'
    reset='\033[0m'
else
    red=''
    green=''
    reset=''
fi

# 检查是否已安装 acme.sh 和 jq 工具
if command -v acme.sh &> /dev/null && command -v jq &> /dev/null; then
    echo -e "${green}acme.sh 和 jq 工具已经安装，开始申请证书...${reset}"
else
    echo -e "${red}acme.sh 或 jq 工具未安装。${reset}"

    # 提示用户选择是否安装缺少的工具
    PS3="请选择操作： "
    options=("安装 acme.sh 和 jq 工具" "退出脚本")
    select option in "${options[@]}"; do
        case $option in
            "安装 acme.sh 和 jq 工具")
                apt-get update
                apt-get install -y socat
                curl https://get.acme.sh | sh
                source ~/.bashrc
                break
                ;;
            "退出脚本")
                echo -e "${red}已退出脚本。${reset}"
                exit 1
                ;;
            *) echo -e "${red}无效的选项，请重新选择。${reset}" ;;
        esac
    done
fi

# 设置绿色高亮输出函数
function print_success() {
    echo -e "${green}$1${reset}"
}

# 获取 Cloudflare API 密钥和邮箱
read -p "请输入 Cloudflare API 密钥: " cf_api_key
read -p "请输入 Cloudflare 邮箱: " cf_email

# 验证密钥
print_success "正在验证密钥..."
if ~/.acme.sh/acme.sh --dns dns_cf --accountemail "$cf_email" --registeraccount; then
    print_success "密钥验证成功！"
else
    echo -e "${red}密钥验证失败，请检查您的密钥和邮箱是否正确。${reset}"
    exit 1
fi

# 获取申请证书的域名
read -p "请输入申请证书的域名: " domain

# 执行申请证书命令
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain" -d "*.$domain" --dns dns_cf --debug 2> /dev/null

# 输出结果
if [ $? -eq 0 ]; then
    print_success "证书申请成功！您现在可以使用您的证书进行 HTTPS 配置。"

    # 检查 /root/cert 目录是否存在，如不存在则创建
    cert_dir="/root/cert"
    if [ ! -d "$cert_dir" ]; then
        mkdir "$cert_dir"
    fi

    # 复制证书文件到 /root/cert 目录
    echo "正在复制证书文件到 $cert_dir 目录..."
    ~/.acme.sh/acme.sh --install-cert -d "$domain" --cert-file "$cert_dir/$domain.cer" --key-file "$cert_dir/$domain.key" --fullchain-file "$cert_dir/fullchain.cer" --reloadcmd "echo 证书复制成功，存放路径：$cert_dir"

else
    echo -e "${red}证书申请失败，请检查您的域名是否正确，并确保您的 DNS 设置已经生效。${reset}"
fi
