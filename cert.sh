#!/bin/bash

# 设置颜色常量
GREEN='\033[1;32m'
NC='\033[0m'

LOGD() {
    echo -e "${GREEN} $1 ${NC}"
}

LOGI() {
    echo -e "${GREEN} $1 ${NC}"
}

LOGE() {
    echo -e "${GREEN} $1 ${NC}"
}

# 检查acme脚本是否已安装，如果未安装，则进行安装
install_acme() {
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        cd ~
        LOGI "开始安装acme脚本..."
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "acme安装失败"
            return 1
        else
            LOGI "acme安装成功"
        fi
    else
        LOGI "检测到已安装acme脚本，跳过安装步骤"
    fi
    return 0
}

# 检查是否符合免费域名申请条件，比如域名是否为免费域名，是否已经存在相同域名的证书等
check_free_domain() {
    local domain="$1"
    local certInfo=$(~/.acme.sh/acme.sh --list | grep "${domain}" | wc -l)
    if [ ${certInfo} -ne 0 ]; then
        LOGE "域名合法性校验失败，当前环境已有对应域名证书，不可重复申请，当前证书详情:"
        LOGI "$(~/.acme.sh/acme.sh --list)"
        exit 1
    else
        LOGI "域名合法性校验通过..."
    fi
}

# 免费域名的证书签发
ssl_cert_issue_by_cloudflare() {
    echo -e ""
    LOGD "******使用说明******"
    LOGI "该脚本将使用Acme脚本申请证书，使用时需保证:"
    LOGI "1. 知晓Cloudflare注册邮箱"
    LOGI "2. 知晓Cloudflare全局API密钥"
    LOGI "3. 域名已通过Cloudflare进行解析到当前服务器"
    LOGI "4. 该脚本申请证书默认安装路径为/root/cert目录"
    LOGI "按下 y 继续，按下 n 退出"
    read -p "是否继续 [y/n]: " choice
    if [[ "${choice}" =~ ^[Yy]$ ]]; then
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "无法安装acme，请检查错误日志"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        fi
        LOGD "请设置域名:"
        read -p "输入你的域名: " CF_Domain
        LOGD "你的域名设置为:${CF_Domain}，正在进行域名合法性校验..."
        check_free_domain "${CF_Domain}"
        LOGD "请设置API密钥:"
        read -p "输入你的API密钥: " CF_GlobalKey
        LOGD "你的API密钥为:${CF_GlobalKey}"
        LOGD "请设置注册邮箱:"
        read -p "输入你的注册邮箱: " CF_AccountEmail
        LOGD "你的注册邮箱为:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "修改默认CA为Let's Encrypt失败，脚本退出"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "证书签发失败，脚本退出"
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            LOGI "证书签发成功，安装中..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
            --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
            --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "证书安装失败，脚本退出"
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            LOGI "证书安装成功，开启自动更新..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "自动更新设置失败，脚本退出"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "证书已安装且已开启自动更新，具体信息如下"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        LOGI "用户取消执行，脚本退出..."
    fi
}

# 入口函数
main() {
    ssl_cert_issue_by_cloudflare
}

# 执行脚本
main
