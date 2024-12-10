#!/bin/bash

function log_I {
    echo -e "\e[32m[+] $1\e[0m"
}

function log_W {
    echo -e "\e[33m[!] $1\e[0m"
}

function log_E {
    echo -e "\e[31m[-] $1\e[0m"
}

function ask_for_creds {
    read -e -p "请输入 SakuraFrp 的 访问密钥: " api_key
    if [[ ${#api_key} -lt 16 ]]; then
        log_E "访问密钥至少需要 16 字符, 请从管理面板直接复制粘贴"
        exit 1
    fi

    read -e -p "请输入您希望使用的远程管理密码 (至少八个字符): " remote_pass
    if [[ ${#remote_pass} -lt 8 ]]; then
        log_E "远程管理密码至少需要 8 字符"
        exit 1
    fi

    read -e -p "请再次输入远程管理密码: " remote_pass_confirm
    if [[ $remote_pass != $remote_pass_confirm ]]; then
        log_E "两次输入的远程管理密码不一致, 请确认知晓自己正在输入的内容"
        exit 1
    fi
}

function check_executable {
    version=$($1 -v 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_E "无法正常执行二进制文件 $1"
        exit 1
    fi
    log_I "$1 版本: $version"
}

set -e

# 定义安装目录为 Kaggle 工作目录
install_dir="/kaggle/working/natfrp"

log_I "正在设置安装目录为 $install_dir"
mkdir -p "$install_dir" || log_W "无法创建 $install_dir 文件夹, 请检查权限"

# 下载二进制文件
log_I "正在下载启动器..."
curl -Lo - "https://nya.globalslb.net/natfrp/client/launcher-unix/latest/natfrp-service_linux_amd64.tar.zst" |
    tar -xI zstd -C "$install_dir" --overwrite
chmod +x "$install_dir/frpc" "$install_dir/natfrp-service"

# 确认二进制文件是否可执行
check_executable "$install_dir/frpc"
check_executable "$install_dir/natfrp-service"

# 创建配置文件
config_file="$install_dir/config.json"
log_I "正在生成配置文件 $config_file"
if [[ -f $config_file ]]; then
    log_W "已存在配置文件"
    read -p " - 是否覆盖配置文件? [y/N] " -r choice
    if [[ $choice =~ ^[Yy]$ ]]; then
        rm -f $config_file
    fi
fi

if [[ ! -f $config_file ]]; then
    echo '{}' >"$config_file"
fi

jq ". + {
    \"token\": $(echo $api_key | jq -R),
    \"remote_management\": true,
    \"remote_management_key\": $("$install_dir/natfrp-service" remote-kdf "$remote_pass" | jq -R),
    \"log_stdout\": true
}" "$config_file" >"$config_file.tmp"
mv "$config_file.tmp" "$config_file"

# 启动服务
log_I "正在启动 SakuraFrp 服务"
"$install_dir/natfrp-service" --daemon &
pid=$!
log_I "服务启动成功, PID: $pid"

log_I "启动器日志:"
tail -f "$install_dir/logs.txt"
