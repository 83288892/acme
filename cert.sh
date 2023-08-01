#!/bin/bash

# 设置颜色变量
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# 证书保存路径
CERT_PATH="/root/cert"

# 函数：安装依赖 acme.sh 和 socat
install_dependencies() {
    echo -e "${GREEN}正在安装 acme.sh 和 socat，请稍等...${NC}"
    apt-get update
    apt-get install -y socat
    curl https://get.acme.sh | sh
}

# 函数：卸载 acme.sh 和 socat
uninstall_acme() {
    echo -e "${GREEN}正在卸载 acme.sh 和 socat，请稍等...${NC}"
    acme.sh --uninstall
    apt-get purge -y socat
}

# 函数：输入 Cloudflare API 密钥和邮箱
input_cloudflare_api() {
    echo -e "${GREEN}请输入 Cloudflare API 密钥和电子邮件：${NC}"
    read -p "Cloudflare API 密钥: " CF_API_KEY
    read -p "Cloudflare 邮箱: " CF_EMAIL

    if [ -z "$CF_API_KEY" ] || [ -z "$CF_EMAIL" ]; then
        echo -e "${RED}API 密钥和邮箱不能为空，请重新输入。${NC}"
        return 1
    fi
}

# 函数：验证 Cloudflare API 密钥和邮箱
verify_cloudflare_api() {
    echo -e "${GREEN}验证 Cloudflare API 密钥和邮箱，请稍等...${NC}"
    acme.sh --set-default-ca --server letsencrypt --dns dns_cf --accountemail "$CF_EMAIL" --accountkey "$CF_API_KEY" --test

    # 验证密钥和电子邮件的有效性
    if [ $? -ne 0 ]; then
        echo -e "${RED}API 密钥或电子邮件验证失败，请检查输入的信息。返回主菜单。${NC}"
        return 1
    else
        echo -e "${GREEN}API 密钥和电子邮件验证成功。${NC}"
        return 0
    fi
}

# 函数：验证域名格式
validate_domain_format() {
    domain=$1
    if ! [[ "$domain" =~ ^([a-zA-Z0-9.-]+\.)+[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}无效的域名格式，请重新输入。${NC}"
        return 1
    fi
    return 0
}

# 函数：检查证书路径并创建
create_cert_directory() {
    if [ ! -d "$CERT_PATH" ]; then
        mkdir -p "$CERT_PATH"
    fi
}

# 函数：复制证书到指定目录
copy_certificate() {
    domain_name="${main_domain:-${single_domain:-$wildcard_domain}}"
    cp "$HOME/.acme.sh/${domain_name}_ecc"/*.cer "$CERT_PATH/"
    cp "$HOME/.acme.sh/${domain_name}_ecc"/*.key "$CERT_PATH/"
}

# 函数：显示简介
display_intro() {
    echo -e "${GREEN}脚本简介：${NC}"
    echo -e "${GREEN}本脚本可用于一键申请证书并将证书复制到指定目录。${NC}"
    echo -e "${GREEN}在开始执行脚本之前，请确保已获取 Cloudflare API 密钥和电子邮件。${NC}"
}

# 函数：显示帮助信息
display_help() {
    echo -e "${GREEN}用法: $0 [选项]${NC}"
    echo -e "${GREEN}选项："
    echo -e "  -h, --help  显示帮助信息"
    echo -e "  -p, --path  指定证书保存路径，默认为 /root/cert${NC}"
}

# 自动加载 acme.sh 路径
export PATH="$HOME/.acme.sh:$PATH"

# 函数：选择并申请证书
apply_certificate() {
    while true; do
        echo -e "${GREEN}请选择需要申请的域名类型：${NC}"
        echo -e "  [1]主域名"
        echo -e "  [2]单域名"
        echo -e "  [3]泛域名"
        echo -e "  [4]返回主菜单"

        read -p "请输入选项编号: " domain_type

        case $domain_type in
            1)
                read -p "请输入主域名: " main_domain
                validate_domain_format "$main_domain" || continue
                ;;
            2)
                read -p "请输入单域名: " single_domain
                validate_domain_format "$single_domain" || continue
                ;;
            3)
                read -p "请输入泛域名: " wildcard_domain
                validate_domain_format "$wildcard_domain" || continue
                ;;
            4)
                echo -e "${GREEN}返回主菜单。${NC}"
                return
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入。${NC}"
                ;;
        esac

        # 申请证书
        acme.sh --issue --dns dns_cf -d ${main_domain:-${single_domain:-$wildcard_domain}} --key-file "$CERT_PATH/${main_domain:-${single_domain:-$wildcard_domain}}.key" --fullchain-file "$CERT_PATH/${main_domain:-${single_domain:-$wildcard_domain}}.cer" --keylength ec-256 --force

        if [ $? -eq 0 ]; then
            copy_certificate
            echo -e "${GREEN}证书申请成功并已复制到目录 $CERT_PATH${NC}"
            break
        else
            echo -e "${RED}证书申请失败，请检查错误信息。脚本将重新开始申请。${NC}"
        fi
    done
}

# 函数：卸载脚本并删除证书
uninstall_script() {
    echo -e "${GREEN}正在卸载脚本并删除证书，请稍等...${NC}"
    uninstall_acme
    rm -rf "$CERT_PATH"
    echo -e "${GREEN}脚本卸载完成，已删除证书。${NC}"
}

# 主菜单
while true; do
    echo -e "${GREEN}请选择操作：${NC}"
    echo -e "  [1]申请证书"
    echo -e "  [2]卸载 acme.sh 和 socat"
    echo -e "  [3]卸载脚本并删除证书"
    echo -e "  [4]配置 CF_Api 和 CF_Email"
    echo -e "  [5]显示帮助"
    echo -e "  [6]退出脚本"

    read -p "请输入选项编号: " option

    case $option in
        1)
            apply_certificate
            ;;
        2)
            uninstall_acme
            ;;
        3)
            uninstall_script
            ;;
        4)
            input_cloudflare_api
            verify_cloudflare_api
            ;;
        5)
            display_help
            ;;
        6)
            echo -e "${GREEN}退出脚本。${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择，请重新输入。${NC}"
            ;;
    esac
done
