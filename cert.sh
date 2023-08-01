#!/bin/bash

# 一键申请证书脚本
# 本脚本可以帮助您快速申请单域名或多域名的SSL证书，使用acme.sh工具和Cloudflare API
# 本脚本需要root权限运行，否则会提示并退出
# 本脚本需要curl、socat和acme.sh三个依赖工具，如果没有安装，会提示用户选择手动安装或自动安装
# 本脚本支持两种申请方式：standalone模式和dns模式
# standalone模式需要80端口没有被占用，否则会申请失败
# dns模式需要用户提供Cloudflare的API密钥和邮箱地址，否则会提示并退出
# 本脚本会将申请成功的证书文件保存在/root/cert/对应域名的目录下，如果目录不存在，会自动创建
# 本脚本提供了完全卸载的选项，可以删除所有证书文件和依赖工具
# 本脚本提供了帮助信息，可以查看脚本用法和参数说明

# 定义一些常用变量
GREEN="\033[32m" # 绿色字体
RED="\033[31m" # 红色字体
END="\033[0m" # 结束颜色

# 定义一些函数

# 检查是否root权限
check_root(){
    if [ $(id -u) != "0" ]; then # 如果不是root用户
        echo -e "${RED}错误：${END}本脚本需要root权限运行，请使用sudo或su命令切换到root用户再执行本脚本。"
        exit 1 # 退出脚本
    fi
}

# 检查依赖是否安装
check_dep(){
    echo -e "${GREEN}正在检查依赖...${END}"
    curl --version > /dev/null 2>&1 # 检查curl是否安装
    if [ $? -ne 0 ]; then # 如果没有安装curl
        echo -e "${RED}错误：${END}curl工具没有安装，无法继续执行。"
        echo -e "您可以选择以下两种方式之一安装curl："
        echo -e "1. 手动安装：请根据您的操作系统类型选择合适的包管理器（如apt、yum等）安装curl。"
        echo -e "2. 自动安装：输入y并回车，让本脚本自动为您安装curl（仅支持Debian/Ubuntu和CentOS/RedHat系统）。"
        read -p "请输入您的选择（y/n）：" choice # 读取用户输入
        if [ "$choice" == "y" ]; then # 如果用户选择自动安装
            install_curl # 调用install_curl函数
        else # 如果用户选择手动安装或其他输入
            exit 1 # 退出脚本
        fi
    fi

    socat -V > /dev/null 2>&1 # 检查socat是否安装
    if [ $? -ne 0 ]; then # 如果没有安装socat
        echo -e "${RED}错误：${END}socat工具没有安装，无法继续执行。"
        echo -e "您可以选择以下两种方式之一安装socat："
        echo -e "1. 手动安装：请根据您的操作系统类型选择合适的包管理器（如apt、yum等）安装socat。"
        echo -e "2. 自动安装：输入y并回车，让本脚本自动为您安装socat（仅支持Debian/Ubuntu和CentOS/RedHat系统）。"
        read -p "请输入您的选择（y/n）：" choice # 读取用户输入
        if [ "$choice" == "y" ]; then # 如果用户选择自动安装
            install_socat # 调用install_socat函数
        else # 如果用户选择手动安装或其他输入
            exit 1 # 退出脚本
        fi
    fi

    acme.sh --version > /dev/null 2>&1 # 检查acme.sh是否安装
    if [ $? -ne 0 ]; then # 如果没有安装acme.sh
        echo -e "${RED}错误：${END}acme.sh工具没有安装，无法继续执行。"
        echo -e "您可以选择以下两种方式之一安装acme.sh："
        echo -e "1. 手动安装：请访问[acme.sh官网]查看安装说明。"
        echo -e "2. 自动安装：输入y并回车，让本脚本自动为您安装acme.sh。"
        read -p "请输入您的选择（y/n）：" choice # 读取用户输入
        if [ "$choice" == "y" ]; then # 如果用户选择自动安装
            install_acme # 调用install_acme函数
        else # 如果用户选择手动安装或其他输入
            exit 1 # 退出脚本
        fi
    fi

    echo -e "${GREEN}依赖检查完毕，所有依赖正常。${END}"
}

# 自动安装curl
install_curl(){
    echo -e "${GREEN}正在自动安装curl...${END}"
    if [ -f /etc/redhat-release ]; then # 如果是CentOS/RedHat系统
        yum install curl -y > /dev/null 2>&1 # 使用yum命令安装curl
    elif [ -f /etc/lsb-release ]; then # 如果是Debian/Ubuntu系统
        apt-get install curl -y > /dev/null 2>&1 # 使用apt-get命令安装curl
    else # 如果是其他系统
        echo -e "${RED}错误：${END}本脚本不支持您的操作系统类型，请手动安装curl。"
        exit 1 # 退出脚本
    fi

    curl --version > /dev/null 2>&1 # 再次检查curl是否安装成功
    if [ $? -ne 0 ]; then # 如果没有安装成功
        echo -e "${RED}错误：${END}curl工具自动安装失败，请手动安装。"
        exit 1 # 退出脚本
    else # 如果安装成功
        echo -e "${GREEN}curl工具自动安装成功。${END}"
    fi
}

# 自动安装socat
install_socat(){
    echo -e "${GREEN}正在自动安装socat...${END}"
    if [ -f /etc/redhat-release ]; then # 如果是CentOS/RedHat系统
        yum install socat -y > /dev/null 2>&1 # 使用yum命令安装socat
    elif [ -f /etc/lsb-release ]; then # 如果是Debian/Ubuntu系统
        apt-get install socat -y > /dev/null 2>&1 # 使用apt-get命令安装socat
    else # 如果是其他系统
        echo -e "${RED}错误：${END}本脚本不支持您的操作系统类型，请手动安装socat。"
        exit 1 # 退出脚本
    fi

    socat -V > /dev/null 2>&1 # 再次检查socat是否安装成功
    if [ $? -ne 0 ]; then # 如果没有安装成功
        echo -e "${RED}错误：${END}socat工具自动安装失败，请手动安装。"
        exit 1 # 退出脚本
    else # 如果安装成功
        echo -e "${GREEN}socat工具自动安装成功。${END}"
    fi    
}

# 自动安装acme.sh
install_acme(){
    echo -e "${GREEN}正在自动安装acme.sh...${END}"
    curl https://get.acme.sh | sh > /dev/null 2>&1 # 使用curl命令下载并执行acme.sh安装脚本
    export PATH="$HOME/.acme.sh:$PATH" # 将acme.sh路径添加到环境变量中
    acme.sh --version > /dev/null 2>&1 # 再次检查acme.sh是否安装成功
    if [ $? -ne 0 ]; then # 如果没有安装成功
        echo -e "${RED}错误：${END}acme.sh工具自动安装失败，请手动安装。"
        exit 1 # 退出脚本
    else # 如果安装成功
        echo -e "${GREEN}acme.sh工具自动安装成功。${END}"
    fi    
}

# 申请单域名证书
apply_single_cert(){
    echo -e "${GREEN}正在申请单域名证书...${END}"
    read -p "请输入您要申请证书的域名（如example.com）：" domain # 读取用户输入的域名
    check_domain $domain # 调用check_domain函数检查域名格式是否正确
    if [ $? -ne 0 ]; then # 如果域名格式不正确
        echo -e "${RED}错误：${END}您输入的域名格式不正确，请重新输入。"
        apply_single_cert # 重新调用本函数
    else # 如果域名格式正确
        ~/.acme.sh/acme.sh --register-account -m xxxx@gmail.com > /dev/null 2>&1 # 使用acme.sh注册账号，邮箱地址可以自定义
        ~/.acme.sh/acme.sh --issue -d $domain --standalone > /dev/null 2>&1 # 使用acme.sh申请单域名证书，使用standalone模式
        if [ $? -ne 0 ]; then # 如果申请失败
            echo -e "${RED}错误：${END}申请单域名证书失败，请检查80端口是否被占用或者网络是否正常。"
            exit 1 # 退出脚本
        else # 如果申请成功
            echo -e "${GREEN}申请单域名证书成功。${END}"
            mkdir -p /root/cert/$domain # 创建对应域名的目录，如果已存在则忽略
            cp ~/.acme.sh/$domain/* /root/cert/$domain/ # 复制所有证书文件到对应目录
            echo -e "您的证书文件已经保存在/root/cert/$domain/目录下，请妥善保管。"
            echo -e "您可以使用以下命令查看您的证书文件："
            echo -e "ls /root/cert/$domain/"
        fi
    fi    
}
# 申请多域名证书
apply_multi_cert(){
    echo -e "${GREEN}正在申请多域名证书...${END}"
    read -p "请输入您要申请证书的域名数量（如2）：" num # 读取用户输入的域名数量
    if [ $num -lt 2 ]; then # 如果域名数量小于2
        echo -e "${RED}错误：${END}多域名证书至少需要两个域名，请重新输入。"
        apply_multi_cert # 重新调用本函数
    else # 如果域名数量大于等于2
        domains="" # 定义一个空字符串用于存储所有域名
        for ((i=1;i<=$num;i++)); do # 循环读取用户输入的每个域名
            read -p "请输入第$i个域名（如example.com）：" domain # 读取用户输入的域名
            check_domain $domain # 调用check_domain函数检查域名格式是否正确
            if [ $? -ne 0 ]; then # 如果域名格式不正确
                echo -e "${RED}错误：${END}您输入的第$i个域名格式不正确，请重新输入。"
                i=$((i-1)) # 将计数器减一，重新读取该域名
            else # 如果域名格式正确
                domains="$domains -d $domain" # 将该域名添加到domains字符串中，前面加上-d参数
            fi
        done
        ~/.acme.sh/acme.sh --register-account -m xxxx@gmail.com > /dev/null 2>&1 # 使用acme.sh注册账号，邮箱地址可以自定义
        ~/.acme.sh/acme.sh --issue $domains --standalone > /dev/null 2>&1 # 使用acme.sh申请多域名证书，使用standalone模式，传入domains字符串作为参数
        if [ $? -ne 0 ]; then # 如果申请失败
            echo -e "${RED}错误：${END}申请多域名证书失败，请检查80端口是否被占用或者网络是否正常。"
            exit 1 # 退出脚本
        else # 如果申请成功
            echo -e "${GREEN}申请多域名证书成功。${END}"
            for ((i=1;i<=$num;i++)); do # 循环处理每个域名的证书文件
                domain=$(echo $domains | cut -d " " -f $((i*2))) # 从domains字符串中提取第i个域名，使用空格作为分隔符，第i*2个字段就是对应的域名
                mkdir -p /root/cert/$domain # 创建对应域名的目录，如果已存在则忽略
                cp ~/.acme.sh/$domain/* /root/cert/$domain/ # 复制所有证书文件到对应目录
                echo -e "您的第$i个域名$domain的证书文件已经保存在/root/cert/$domain/目录下，请妥善保管。"
                echo -e "您可以使用以下命令查看您的第$i个域名$domain的证书文件："
                echo -e "ls /root/cert/$domain/"
            done            
        fi        
    fi    
}

# 设置Cloudflare API密钥和邮箱地址
set_cf_api(){
    echo -e "${GREEN}正在设置Cloudflare API密钥和邮箱地址...${END}"
    read -p "请输入您的Cloudflare API密钥（如xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx）：" CF_Key # 读取用户输入的Cloudflare API密钥
    check_cf_key $CF_Key # 调用check_cf_key函数检查Cloudflare API密钥格式是否正确
    if [ $? -ne 0 ]; then # 如果Cloudflare API密钥格式不正确
        echo -e "${RED}错误：${END}您输入的Cloudflare API密钥格式不正确，请重新输入。"
        set_cf_api # 重新调用本函数
    else # 如果Cloudflare API密钥格式正确
        read -p "请输入您的Cloudflare邮箱地址（如email@example.com）：" CF_Email # 读取用户输入的Cloudflare邮箱地址
        check_cf_email $CF_Email # 调用check_cf_email函数检查Cloudflare邮箱地址格式是否正确
        if [ $? -ne 0 ]; then # 如果Cloudflare邮箱地址格式不正确
            echo -e "${RED}错误：${END}您输入的Cloudflare邮箱地址格式不正确，请重新输入。"
            set_cf_api # 重新调用本函数
        else # 如果Cloudflare邮箱地址格式正确
            export CF_Key="$CF_Key" # 将Cloudflare API密钥设置为环境变量
            export CF_Email="$CF_Email" # 将Cloudflare邮箱地址设置为环境变量
            echo -e "${GREEN}设置Cloudflare API密钥和邮箱地址成功。${END}"
        fi        
    fi    
}
# 申请域名和泛域名证书
apply_wildcard_cert(){
    echo -e "${GREEN}正在申请域名和泛域名证书...${END}"
    read -p "请输入您要申请证书的域名（如example.com）：" domain # 读取用户输入的域名
    check_domain $domain # 调用check_domain函数检查域名格式是否正确
    if [ $? -ne 0 ]; then # 如果域名格式不正确
        echo -e "${RED}错误：${END}您输入的域名格式不正确，请重新输入。"
        apply_wildcard_cert # 重新调用本函数
    else # 如果域名格式正确
        wildcard="*.$domain" # 定义泛域名，即在域名前加上*
        check_cf_api # 调用check_cf_api函数检查Cloudflare API密钥和邮箱地址是否设置
        if [ $? -ne 0 ]; then # 如果Cloudflare API密钥和邮箱地址没有设置
            echo -e "${RED}错误：${END}您还没有设置Cloudflare API密钥和邮箱地址，请先设置。"
            set_cf_api # 调用set_cf_api函数设置Cloudflare API密钥和邮箱地址
        fi
        ~/.acme.sh/acme.sh --register-account -m xxxx@gmail.com > /dev/null 2>&1 # 使用acme.sh注册账号，邮箱地址可以自定义
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d $domain -d $wildcard > /dev/null 2>&1 # 使用acme.sh申请域名和泛域名证书，使用dns模式，传入Cloudflare API参数
        if [ $? -ne 0 ]; then # 如果申请失败
            echo -e "${RED}错误：${END}申请域名和泛域名证书失败，请检查您的Cloudflare API密钥和邮箱地址是否正确或者网络是否正常。"
            exit 1 # 退出脚本
        else # 如果申请成功
            echo -e "${GREEN}申请域名和泛域名证书成功。${END}"
            mkdir -p /root/cert/$domain # 创建对应域名的目录，如果已存在则忽略
            cp ~/.acme.sh/$domain/* /root/cert/$domain/ # 复制所有证书文件到对应目录
            echo -e "您的域名和泛域名$domain的证书文件已经保存在/root/cert/$domain/目录下，请妥善保管。"
            echo -e "您可以使用以下命令查看您的域名和泛域名$domain的证书文件："
            echo -e "ls /root/cert/$domain/"
        fi        
    fi    
}

# 完全卸载脚本和证书
uninstall_all(){
    echo -e "${GREEN}正在完全卸载脚本和证书...${END}"
    read -p "请输入y并回车确认完全卸载，或者输入n并回车取消操作（y/n）：" choice # 读取用户输入
    if [ "$choice" == "y" ]; then # 如果用户选择完全卸载
        rm -rf ~/.acme.sh/ # 删除acme.sh工具目录及其所有文件
        rm -rf /root/cert/ # 删除所有证书目录及其所有文件
        rm -f ./cert.sh # 删除本脚本文件
        echo -e "${GREEN}完全卸载成功，感谢您使用本脚本。${END}"
        exit 0 # 退出脚本
    elif [ "$choice" == "n" ]; then # 如果用户选择取消操作
        echo -e "${GREEN}您已取消完全卸载操作，返回主菜单。${END}"
        show_menu # 调用show_menu函数显示主菜单
    else # 如果用户输入其他内容
        echo -e "${RED}错误：${END}您输入的内容不正确，请重新输入。"
        uninstall_all # 重新调用本函数
    fi    
}
# 显示帮助信息
show_help(){
    echo -e "${GREEN}帮助信息：${END}"
    echo -e "本脚本是一个一键申请证书的脚本，可以帮助您快速申请单域名或多域名的SSL证书，使用acme.sh工具和Cloudflare API。"
    echo -e "本脚本需要root权限运行，否则会提示并退出。"
    echo -e "本脚本需要curl、socat和acme.sh三个依赖工具，如果没有安装，会提示用户选择手动安装或自动安装。"
    echo -e "本脚本支持两种申请方式：standalone模式和dns模式。"
    echo -e "standalone模式需要80端口没有被占用，否则会申请失败。"
    echo -e "dns模式需要用户提供Cloudflare的API密钥和邮箱地址，否则会提示并退出。"
    echo -e "本脚本会将申请成功的证书文件保存在/root/cert/对应域名的目录下，如果目录不存在，会自动创建。"
    echo -e "本脚本提供了完全卸载的选项，可以删除所有证书文件和依赖工具。"
    echo -e "本脚本提供了帮助信息，可以查看脚本用法和参数说明。"
    echo -e "本脚本的用法如下："
    echo -e "./cert.sh [参数]"
    echo -e "参数说明："
    echo -e "-h 或 --help：显示帮助信息并退出。"
    echo -e "-u 或 --uninstall：完全卸载脚本和证书并退出。"
    echo -e "-s 或 --single：申请单域名证书并退出。"
    echo -e "-m 或 --multi：申请多域名证书并退出。"
    echo -e "-w 或 --wildcard：申请域名和泛域名证书并退出。"
    echo -e "-c 或 --cf：设置Cloudflare API密钥和邮箱地址并退出。"
    echo -e "-p 或 --path：指定证书保存路径，默认为/root/cert/。"
}

# 显示主菜单
show_menu(){
    clear # 清屏
    echo -e "${GREEN}欢迎使用一键申请证书脚本！${END}"
    echo -e "${GREEN}简介：${END}本脚本可以帮助您快速申请单域名或多域名的SSL证书，使用acme.sh工具和Cloudflare API。"
    echo -e "${GREEN}依赖：${END}curl、socat、acme.sh（如果没有安装，会提示安装）。"
    echo -e "${GREEN}主菜单：${END}"
    echo -e "[1] 检查依赖：选中此菜单以最高权限执行检查curl、socat、acme.sh是否正常安装是否可以正常运行最重要的检查acme.sh命令是否可以正常执行如果不能执行则显示错误信息并退出。" 
    echo -e "[2] 一键申请：选中此菜单进入子菜单选择申请方式（standalone模式或dns模式）和证书类型（单域名、多域名或域名和泛域名）。" 
    echo -e "[3] CF_API申请：选中此菜单进入子菜单设置Cloudflare API密钥和邮箱地址或者申请域名和泛域名证书。" 
    echo -e "[4] 完全卸载：选中此菜单完全卸载脚本和证书，删除所有证书文件和依赖工具。" 
    echo -e "[5] 帮助：选中此菜单显示帮助信息，查看脚本用法和参数说明。" 
    echo -e "[6] 退出：选中此菜单退出脚本。" 
    read -p "请输入您的选择（1-6）：" choice # 读取用户输入
    case $choice in # 根据用户输入执行相应的函数
        1) check_dep;; # 调用check_dep函数检查依赖
        2) apply_cert;; # 调用apply_cert函数申请证书
        3) apply_cf;; # 调用apply_cf函数申请CF_API证书
        4) uninstall_all;; # 调用uninstall_all函数完全卸载
        5) show_help;; # 调用show_help函数显示帮助信息
        6) exit 0;; # 退出脚本
        *) echo -e "${RED}错误：${END}您输入的内容不正确，请重新输入。"; show_menu;; # 如果用户输入其他内容，重新调用本函数
    esac
}
# 申请证书的子菜单
apply_cert(){
    clear # 清屏
    echo -e "${GREEN}欢迎使用一键申请证书的功能！${END}"
    echo -e "${GREEN}子菜单：${END}"
    echo -e "[1] 选择申请方式：选中此菜单进入子子菜单选择申请方式（standalone模式或dns模式）。" 
    echo -e "[2] 选择证书类型：选中此菜单进入子子菜单选择证书类型（单域名、多域名或域名和泛域名）。" 
    echo -e "[3] 返回主菜单：选中此菜单返回主菜单。" 
    read -p "请输入您的选择（1-3）：" choice # 读取用户输入
    case $choice in # 根据用户输入执行相应的函数
        1) choose_mode;; # 调用choose_mode函数选择申请方式
        2) choose_type;; # 调用choose_type函数选择证书类型
        3) show_menu;; # 调用show_menu函数显示主菜单
        *) echo -e "${RED}错误：${END}您输入的内容不正确，请重新输入。"; apply_cert;; # 如果用户输入其他内容，重新调用本函数
    esac
}

# 申请CF_API证书的子菜单
apply_cf(){
    clear # 清屏
    echo -e "${GREEN}欢迎使用CF_API申请证书的功能！${END}"
    echo -e "${GREEN}子菜单：${END}"
    echo -e "[1] 设置CF密钥和邮箱：选中此菜单设置Cloudflare API密钥和邮箱地址。" 
    echo -e "[2] 申请证书：选中此菜单申请域名和泛域名证书，需要先设置Cloudflare API密钥和邮箱地址。" 
    echo -e "[3] 返回主菜单：选中此菜单返回主菜单。" 
    read -p "请输入您的选择（1-3）：" choice # 读取用户输入
    case $choice in # 根据用户输入执行相应的函数
        1) set_cf_api;; # 调用set_cf_api函数设置Cloudflare API密钥和邮箱地址
        2) apply_wildcard_cert;; # 调用apply_wildcard_cert函数申请域名和泛域名证书
        3) show_menu;; # 调用show_menu函数显示主菜单
        *) echo -e "${RED}错误：${END}您输入的内容不正确，请重新输入。"; apply_cf;; # 如果用户输入其他内容，重新调用本函数
    esac    
}
# 选择申请方式的子子菜单
choose_mode(){
    clear # 清屏
    echo -e "${GREEN}欢迎使用选择申请方式的功能！${END}"
    echo -e "${GREEN}子子菜单：${END}"
    echo -e "[1] standalone模式：选中此菜单使用standalone模式申请证书，需要80端口没有被占用。" 
    echo -e "[2] dns模式：选中此菜单使用dns模式申请证书，需要设置Cloudflare API密钥和邮箱地址。" 
    echo -e "[3] 返回子菜单：选中此菜单返回申请证书的子菜单。" 
    read -p "请输入您的选择（1-3）：" choice # 读取用户输入
    case $choice in # 根据用户输入执行相应的操作
        1) mode="standalone";; # 设置mode变量为standalone
        2) mode="dns";; # 设置mode变量为dns
        3) apply_cert;; # 调用apply_cert函数显示申请证书的子菜单
        *) echo -e "${RED}错误：${END}您输入的内容不正确，请重新输入。"; choose_mode;; # 如果用户输入其他内容，重新调用本函数
    esac
    echo -e "${GREEN}您已选择$mode模式申请证书。${END}"
}

# 选择证书类型的子子菜单
choose_type(){
    clear # 清屏
    echo -e "${GREEN}欢迎使用选择证书类型的功能！${END}"
    echo -e "${GREEN}子子菜单：${END}"
    echo -e "[1] 单域名证书：选中此菜单申请单域名证书，需要输入一个域名。" 
    echo -e "[2] 多域名证书：选中此菜单申请多域名证书，需要输入多个域名。" 
    echo -e "[3] 域名和泛域名证书：选中此菜单申请域名和泛域名证书，需要输入一个域名和一个泛域名。" 
    echo -e "[4] 返回子菜单：选中此菜单返回申请证书的子菜单。" 
    read -p "请输入您的选择（1-4）：" choice # 读取用户输入
    case $choice in # 根据用户输入执行相应的函数
        1) apply_single_cert;; # 调用apply_single_cert函数申请单域名证书
        2) apply_multi_cert;; # 调用apply_multi_cert函数申请多域名证书
        3) apply_wildcard_cert;; # 调用apply_wildcard_cert函数申请域名和泛域名证书
        4) apply_cert;; # 调用apply_cert函数显示申请证书的子菜单
        *) echo -e "${RED}错误：${END}您输入的内容不正确，请重新输入。"; choose_type;; # 如果用户输入其他内容，重新调用本函数
    esac    
}
# 检查域名格式是否正确
check_domain(){
    domain=$1 # 接收第一个参数作为域名
    if [[ $domain =~ ^[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,6}$ ]]; then # 如果域名符合正则表达式
        return 0 # 返回0表示正确
    else # 如果域名不符合正则表达式
        return 1 # 返回1表示错误
    fi
}

# 检查Cloudflare API密钥和邮箱地址是否设置
check_cf_api(){
    if [ -z "$CF_Key" ] || [ -z "$CF_Email" ]; then # 如果CF_Key或CF_Email为空
        return 1 # 返回1表示没有设置
    else # 如果CF_Key和CF_Email都不为空
        return 0 # 返回0表示已经设置
    fi    
}
# 检查Cloudflare API密钥格式是否正确
check_cf_key(){
    CF_Key=$1 # 接收第一个参数作为Cloudflare API密钥
    if [[ $CF_Key =~ ^[a-zA-Z0-9]{37}$ ]]; then # 如果Cloudflare API密钥符合正则表达式
        return 0 # 返回0表示正确
    else # 如果Cloudflare API密钥不符合正则表达式
        return 1 # 返回1表示错误
    fi
}

# 检查Cloudflare邮箱地址格式是否正确
check_cf_email(){
    CF_Email=$1 # 接收第一个参数作为Cloudflare邮箱地址
    if [[ $CF_Email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$ ]]; then # 如果Cloudflare邮箱地址符合正则表达式
        return 0 # 返回0表示正确
    else # 如果Cloudflare邮箱地址不符合正则表达式
        return 1 # 返回1表示错误
    fi    
}
# 脚本的主体部分

# 调用check_root函数检查是否root权限
check_root

# 处理命令行参数
while [ -n "$1" ]; do # 循环遍历所有参数
    case $1 in # 根据参数执行相应的操作
        -h|--help) show_help; exit 0;; # 如果参数是-h或--help，调用show_help函数显示帮助信息并退出
        -u|--uninstall) uninstall_all; exit 0;; # 如果参数是-u或--uninstall，调用uninstall_all函数完全卸载脚本和证书并退出
        -s|--single) apply_single_cert; exit 0;; # 如果参数是-s或--single，调用apply_single_cert函数申请单域名证书并退出
        -m|--multi) apply_multi_cert; exit 0;; # 如果参数是-m或--multi，调用apply_multi_cert函数申请多域名证书并退出
        -w|--wildcard) apply_wildcard_cert; exit 0;; # 如果参数是-w或--wildcard，调用apply_wildcard_cert函数申请域名和泛域名证书并退出
        -c|--cf) set_cf_api; exit 0;; # 如果参数是-c或--cf，调用set_cf_api函数设置Cloudflare API密钥和邮箱地址并退出
        -p|--path) cert_path=$2; shift;; # 如果参数是-p或--path，将第二个参数作为证书保存路径赋值给cert_path变量，并将参数指针后移一位
        *) echo -e "${RED}错误：${END}无效的参数，请使用-h或--help查看帮助信息。"; exit 1;; # 如果参数是其他内容，输出错误信息并退出
    esac
    shift # 将参数指针后移一位
done

# 如果没有指定证书保存路径，则使用默认路径/root/cert/
if [ -z "$cert_path" ]; then # 如果cert_path变量为空
    cert_path="/root/cert/" # 将默认路径赋值给cert_path变量
fi

# 调用show_menu函数显示主菜单
show_menu
