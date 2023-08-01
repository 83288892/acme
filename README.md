一键运行证书申请脚本
这个脚本用于快速申请 SSL 证书，并将证书文件复制到指定目录。

使用方法
第一次使用，在服务器上运行以下命令，下载脚本并一键执行：

```bash
curl -o cert.sh https://raw.githubusercontent.com/83288892/acme/main/cert.sh && chmod +x cert.sh && ./cert.sh

再次运行脚本申请证书并复制到指定目录：

`./cert.sh`


按照提示输入 Cloudflare API 密钥、邮箱和申请证书的域名，然后等待脚本执行完成。

如果证书申请成功，脚本会将证书文件复制到 /root/cert/ 目录下，并在控制台显示证书存放路径。

如果证书申请失败，请检查您的域名是否正确，并确保您的 DNS 设置已经生效。

注意事项
确保您在服务器上具有足够的权限来执行脚本和安装相关的软件。
脚本会在 /root/cert/ 目录下存储申请的证书文件，请确保该目录不存在敏感信息。
该脚本使用 Cloudflare API 实现 DNS 验证，需要输入有效的 Cloudflare API 密钥和邮箱。
此脚本仅用于申请测试证书或个人使用，请勿将其用于生产环境。
© 完美

希望这个示例能帮助到您，如果您有其他问题或需要进一步的帮助，请随时告诉我。
