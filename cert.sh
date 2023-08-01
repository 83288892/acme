#!/bin/bash

# 检查是否已安装 acme.sh 和 socat
if command -v acme.sh &> /dev/null && command -v socat &> /dev/null; then
    echo -e "\033[32macme.sh 和 socat 工具已安装。\033[0m"
else
    echo -e "\033[31macme.sh 或 socat 未安装，请先安装这些工具。\033[0m"
    read -p "请选择操作： \033[32m1 安装 acme.sh 和 socat\033[0m  \033[32m2 退出脚本\033[0m " option
    case $option in
        1)
            echo "正在安装 acme.sh 和 socat..."
            apt-get update
            apt-get install -y socat
            curl https://get.acme.sh | sh
            source ~/.bashrc
            ;;
        2)
            echo "已退出脚本。"
            exit 1
            ;;
        *)
            echo "无效的选项，请重新运行脚本。"
            exit 1
            ;;
    esac
fi

# 获取 Cloudflare API 密钥和邮箱
read -p "请输入 Cloudflare API 密钥: " cf_api_key
read -p "请输入 Cloudflare 邮箱: " cf_email

# 验证密钥
echo "正在验证密钥..."
if ~/.acme.sh/acme.sh --dns dns_cf --accountemail "$cf_email" --registeraccount; then
    echo -e "\033[32m密钥验证成功！\033[0m"
else
    echo -e "\033[31m密钥验证失败，请检查您的密钥和邮箱是否正确。\033[0m"
    exit 1
fi

# 获取申请证书的域名
read -p "请输入申请证书的域名: " domain

# 执行申请证书命令
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain" -d "*.$domain" --dns dns_cf --debug 2> /dev/null

# 输出结果
if [ $? -eq 0 ]; then
    echo -e "\033[32m证书申请成功！您现在可以使用您的证书进行 HTTPS 配置。\033[0m"

    # 检查 /root/cert 目录是否存在，如不存在则创建
    cert_dir="/root/cert"
    if [ ! -d "$cert_dir" ]; then
        mkdir "$cert_dir"
    fi

    # 复制证书文件到 /root/cert 目录
    echo "正在复制证书文件到 $cert_dir 目录..."
    ~/.acme.sh/acme.sh --install-cert -d "$domain" --cert-file "$cert_dir/$domain.cer" --key-file "$cert_dir/$domain.key" --fullchain-file "$cert_dir/fullchain.cer" --reloadcmd "echo -e \033[32m证书复制成功，存放路径：$cert_dir\033[0m"

else
    echo -e "\033[31m证书申请失败，请检查您的域名是否正确，并确保您的 DNS 设置已经生效。\033[0m"
fi
