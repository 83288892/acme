# acme
# 使用 curl 下载脚本并保存为 acme_cert_apply.sh
curl -o acme_cert_apply.sh https://raw.githubusercontent.com/83288892/acme/main/acme_cert_apply.sh

# 赋予脚本执行权限
chmod +x acme_cert_apply.sh

# 执行脚本
./acme_cert_apply.sh
