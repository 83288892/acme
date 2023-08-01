#!/bin/bash

# 设置颜色变量
GREEN='\033[1;32m'
NC='\033[0m' # No Color

# 加载 acme.sh 路径
export PATH="$HOME/.acme.sh:$PATH"

# 检查是否安装 acme 和 socat
if ! command -v acme.sh &> /dev/null || ! command -v socat &> /dev/null; then
    echo -e "${GREEN}正在安装 acme.sh 和 socat...${NC}"
    apt-get update
    apt-get install -y socat
    curl https://get.acme.sh | sh
fi

# 输入 Cloudflare API 密钥和邮箱
echo -e "${GREEN}请输入 Cloudflare API 密钥和电子邮件：${NC}"
read -p "Cloudflare API 密钥: " CF_API_KEY
read -p "Cloudflare 邮箱: " CF_EMAIL

# 配置 Cloudflare 的 API 密钥和电子邮件
echo -e "${GREEN}配置 Cloudflare 的 API 密钥和电子邮件...${NC}"
acme.sh --set-default-ca --server letsencrypt --dns dns_cf --accountemail $CF_EMAIL --accountkey $CF_API_KEY

# 验证密钥和电子邮件的有效性
if [ $? -ne 0 ]; then
    echo -e "${GREEN}API 密钥或电子邮件验证失败，请检查输入的信息。脚本将退出。${NC}"
    exit 1
fi

# 输入需要申请的域名
echo -e "${GREEN}请输入需要申请的域名类型：${NC}"
select domain_type in "主域名" "单域名" "泛域名"; do
    case $domain_type in
        "主域名")
            read -p "请输入主域名: " main_domain
            acme.sh --issue --dns dns_cf -d $main_domain --key-file /root/cert/$main_domain.key --fullchain-file /root/cert/$main_domain.cer --keylength ec-256 --force
            ;;
        "单域名")
            read -p "请输入单域名: " single_domain
            acme.sh --issue --dns dns_cf -d $single_domain --key-file /root/cert/$single_domain.key --fullchain-file /root/cert/$single_domain.cer --keylength ec-256 --force
            ;;
        "泛域名")
            read -p "请输入泛域名: " wildcard_domain
            acme.sh --issue --dns dns_cf -d "*.$wildcard_domain" --key-file /root/cert/$wildcard_domain.key --fullchain-file /root/cert/$wildcard_domain.cer --keylength ec-256 --force
            ;;
        *)
            echo -e "${GREEN}无效的选择。脚本将退出。${NC}"
            exit 1
            ;;
    esac
    break
done

# 检查证书路径并创建
cert_path="/root/cert"
if [ ! -d $cert_path ]; then
    mkdir -p $cert_path
fi

# 复制证书到证书目录
cp /root/.acme.sh/*.cer $cert_path/
cp /root/.acme.sh/*.key $cert_path/

echo -e "${GREEN}证书申请成功并已复制到目录 $cert_path${NC}"
