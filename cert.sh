#!/bin/bash

# 检查终端是否支持 ANSI 转义序列
if [ -t 1 ]; then
    green='\033[32m'
    reset='\033[0m'
else
    green=''
    reset=''
fi

# 检查是否已安装 acme.sh 和 socat
if command -v acme.sh &> /dev/null && command -v socat &> /dev/null; then
    echo -e "${green}acme.sh 和 socat 工具已安装。${reset}"
else
    echo -e "${green}acme.sh 或 socat 未安装，请先安装这些工具。${reset}"
    echo "请安装 acme.sh 和 socat 后再继续操作。"
    exit 1
fi

# 获取 Cloudflare API 密钥和邮箱
read -p "${green}请输入 Cloudflare API 密钥: ${reset}" cf_api_key
read -p "${green}请输入 Cloudflare 邮箱: ${reset}" cf_email

# 验证密钥和邮箱
echo -e "${green}正在验证密钥和邮箱...${reset}"
if ~/.acme.sh/acme.sh --dns dns_cf --accountemail "$cf_email" --registeraccount; then
    echo -e "${green}密钥和邮箱验证成功！${reset}"
else
    echo -e "${green}密钥和邮箱验证失败，请检查您的密钥和邮箱是否正确。${reset}"
    exit 1
fi

# 获取申请证书的域名列表
read -p "${green}请输入申请证书的域名列表，用空格分隔（支持单域名和泛域名，例如 example.com *.example.com）: ${reset}" domains

# 将域名列表转换为数组
IFS=' ' read -ra domain_array <<< "$domains"

# 执行申请证书命令
echo -e "${green}正在申请证书，请稍候...${reset}"
for domain in "${domain_array[@]}"; do
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain" --debug 2> /dev/null
done

# 输出结果
success_count=0
for domain in "${domain_array[@]}"; do
    if [ $? -eq 0 ]; then
        echo -e "${green}证书申请成功！域名：$domain${reset}"
        ((success_count++))

        # 检查 /root/cert 目录是否存在，如不存在则创建
        cert_dir="/root/cert"
        if [ ! -d "$cert_dir" ]; then
            mkdir "$cert_dir"
        fi

        # 复制证书文件到 /root/cert 目录
        echo -e "${green}正在复制证书文件到 $cert_dir 目录...${reset}"
        ~/.acme.sh/acme.sh --install-cert -d "$domain" --cert-file "$cert_dir/$domain.cer" --key-file "$cert_dir/$domain.key" --fullchain-file "$cert_dir/fullchain.cer" --reloadcmd "echo 证书复制成功，存放路径：$cert_dir"
    else
        echo -e "${green}证书申请失败，请检查您的域名是否正确，并确保您的 DNS 设置已经生效。域名：$domain${reset}"
    fi
done

# 检查是否所有证书申请都成功
if [ $success_count -eq ${#domain_array[@]} ]; then
    echo -e "${green}所有证书申请成功！您现在可以使用您的证书进行 HTTPS 配置。${reset}"
else
    echo -e "${green}部分证书申请失败，请检查相应域名的设置。${reset}"
fi
