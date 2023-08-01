#!/bin/bash

# 设置脚本全部提示显示字体为高亮大绿色
echo -e "\e[1;32m"

# 检查本地是否安装有acme和socat
if ! command -v acme.sh &>/dev/null; then
  echo "acme.sh 未安装，正在安装..."
  apt-get install acme.sh
fi

if ! command -v socat &>/dev/null; then
  echo "socat 未安装，正在安装..."
  apt-get install socat
fi

# 输入cloudflareAPI密钥和cloudflare邮箱
echo "请输入cloudflareAPI密钥："
read CF_API_KEY
echo "请输入cloudflare邮箱："
read CF_EMAIL

# 在系统中配置Cloudflare的API密钥和电子邮件
echo "CLOUDFLARE_API_KEY=\"$CF_API_KEY\" > /etc/cloudflare.conf"
echo "CLOUDFLARE_EMAIL=\"$CF_EMAIL\" >> /etc/cloudflare.conf"

# 验证密钥和电子邮件的有效性
cf api -a $CF_API_KEY -u $CF_EMAIL

# 提示输入域名和泛域名
echo "请输入域名："
read DOMAIN
echo "请输入泛域名："
read WILDCARD_DOMAIN

# 申请证书
echo "正在申请证书..."
acme.sh --issue --dns cloudflare -d $DOMAIN -d $WILDCARD_DOMAIN

# 申请成功后检测本地是否有证书路径/root/cert
if [[ ! -d /root/cert ]]; then
  echo "证书路径/root/cert不存在，正在创建..."
  mkdir /root/cert
fi

# 最后复制证书到/root/cert目录
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /root/cert
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /root/cert

# 申请失败提示失败信息并退出脚本
if [[ $? -ne 0 ]]; then
  echo "证书申请失败，请检查您的域名和cloudflareAPI密钥"
  exit 1
fi

# 提示证书申请成功
echo "证书申请成功！证书已保存在/root/cert目录下"
