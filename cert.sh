#!/bin/bash

# 设置颜色变量
GREEN='\033[1;32m'
NC='\033[0m' # No Color

# 加载 acme.sh 路径
export PATH="$HOME/.acme.sh:$PATH"

# 函数：安装依赖 acme.sh 和 socat
install_dependencies() {
    echo -e "${GREEN}正在安装 acme.sh 和 socat...${NC}"
    apt-get update
    apt-get install -y socat
    curl https://get.acme.sh | sh
}

# 函数：输入 Cloudflare API 密钥和邮箱
input_cloudflare_api() {
    echo -e "${GREEN}请输入 Cloudflare API 密钥和电子邮件：${NC}"
    read -p "Cloudflare API 密钥: " CF_API_KEY
    read -p "Cloudflare 邮箱: " CF_EMAIL
}

# 函数：配置 Cloudflare 的 API 密钥和电子邮件
configure_cloudflare_api() {
    echo -e "${GREEN}配置 Cloudflare 的 API 密钥和电子邮件...${NC}"
    acme.sh --set-default-ca --server letsencrypt --dns dns_cf --accountemail $CF_EMAIL --accountkey $CF_API_KEY

    # 验证密钥和电子邮件的有效性
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}API 密钥或电子邮件验证失败，请检查输入的信息。脚本将退出。${NC}"
        exit 1
    fi
}

# 函数：选择并申请证书
apply_certificate() {
    case $domain_type in
        "主域名"
            read -p "请输入主域名: " main_domain
            ;;
        "单域名"
            read -p "请输入单域名: " single_domain
            ;;
        "泛域名"
            read -p "请输入泛域名: " wildcard_domain
            ;;
        *)
            echo -e "${GREEN}无效的选择。脚本将退出。${NC}"
            exit 1
            ;;
    esac

    # 申请证书
    acme.sh --issue --dns dns_cf -d ${main_domain:-${single_domain:-$wildcard_domain}} --key-file $cert_path/${main_domain:-${single_domain:-$wildcard_domain}}.key --fullchain-file $cert_path/${main_domain:-${single_domain:-$wildcard_domain}}.cer --keylength ec-256 --force
}

# 函数：检查证书路径并创建
create_cert_directory() {
    cert_path="/root/cert"
    if [ ! -d $cert_path ]; then
        mkdir -p $cert_path
    fi
}

# 函数：复制证书到指定目录
copy_certificate() {
    domain_name="${main_domain:-${single_domain:-$wildcard_domain}}"
    cp "$HOME/.acme.sh/$domain_name"_ecc/*.cer $cert_path/
    cp "$HOME/.acme.sh/$domain_name"_ecc/*.key $cert_path/
}

# 主函数
main() {
    install_dependencies

    input_cloudflare_api

    configure_cloudflare_api

    echo -e "${GREEN}请选择需要申请的域名类型：${NC}"
    select domain_type in "主域名" "单域名" "泛域名"; do
        echo -e "${GREEN}开始申请证书...${NC}"
        create_cert_directory

        apply_certificate

        if [ $? -eq 0 ]; then
            copy_certificate
            echo -e "${GREEN}证书申请成功并已复制到目录 $cert_path${NC}"
            break
        else
            echo -e "${GREEN}证书申请失败，请检查错误信息。脚本将退出。${NC}"
            exit 1
        fi
    done
}

main
