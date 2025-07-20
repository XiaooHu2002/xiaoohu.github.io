tee SSH-Password-free.sh > /dev/null <<"EOF2"
#!/bin/bash

#菜单
menu(){
    color "============================欢迎来到千屹运维脚本============================"
    color blue "作者：严千屹"
    echo ""
    color blue "1.SSH免密"
    
    color "============================================================================"
    read -p "请输入菜单里选项的数字：" menu_num
    case $menu_num in 
        1)SSH-Password-free;;
        *)color red "请输入菜单里的数字";exit 1;;
    esac
}
#主体部分
function_list(){
	#系统的基本信息
    sysinit_info(){
        . /etc/os-release
        #获取网卡名
        Dev_name=$(ip a | sed -En 's#^2: ([^ ]+):.*$#\1#p')
        #获取当前机子的ip
        local_ip=$(ip route get 1 | awk '{print $7; exit}')
        #获取子网掩码
        IP_PREFIX=$(ip a | grep $Dev_name | sed -En '/inet/s#.*inet ([^ ]+)/([0-9]{0,2}) .*#\2#p')
        #获取前三位ip
        NET_NUM=${local_ip%.*}.
        #当前机子的root密码
        local_passwd=123456
    }
    sysinit_info
    #颜色代码
    color(){
        case $# in
            1)  # 只有文本，默认白色
                text=$1
                color_name=white
                ;;
            2)  # 同时给了颜色和文本
                color_name=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
                text=$2
                ;;
            *)  # 参数个数不对
                echo -e "用法：color [颜色] \"文本\""
                            echo "颜色列表：black、red、green、yellow、blue、purple、cyan（青色）"
                return 1
                ;;
        esac

        case $color_name in
            black)  col=30 ;;
            red)    col=31 ;;
            green)  col=32 ;;
            yellow) col=33 ;;
            blue)   col=34 ;;
            purple) col=35 ;;
            cyan)   col=36 ;;
            *)      col=37 ;;   # 默认白色
        esac

        printf '\033[%sm%s\033[0m\n' "$col" "$text"
    }
    #ssh免密
    SSH-Password-free(){
        
        #创建密钥
        createKey(){
            mkdir -p /root/.ssh
            if [ -f ~/.ssh/id_rsa ]; then
            color green "本机密钥已存在，无需创建"
            else
            color red "正在创建密钥" 
            ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa &> /dev/null
            color green "本机创建密钥成功"
            fi
        }
        install_sshpass(){
            #ubuntu系统
            if [[ $ID =~ ubuntu ]];then
                dpkg -l sshpass &> /dev/null || { apt update -y; apt -y install sshpass; }|| (olor red "安装sshpass失败，请检查yum源";exit 1)
                #单个ip
            #rocky|centos|rhel系统
            elif [[ $ID =~ rocky|centos|rhel|openEuler ]];then
                #安装sshpass工具
                rpm -q sshpass &>/dev/null || yum -y install sshpass || (color red "安装sshpass失败，请检查yum源";exit 1)
            else
                echo "不支持当前操作系统"
                exit
            fi 
        }
        Single_SSH(){
            install_sshpass
            createKey 
            read -p "请输入对端ip：" Single_ip
            read -p "请输入对端密码：" SSH_PASSWD
            sshpass -p "$SSH_PASSWD" ssh-copy-id -o StrictHostKeyChecking=no "$Single_ip" &> /dev/null
            # 把函数体用引号包起来，通过 ssh 直接在远端执行
            sshpass -p "$SSH_PASSWD" ssh -o StrictHostKeyChecking=no "$Single_ip" \
                'mkdir -p /root/.ssh
                if [ -f ~/.ssh/id_rsa ]; then
                    echo "对端密钥已存在，无需创建"
                else
                    echo "正在对端创建密钥"
                    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa &>/dev/null
                    echo "创建对端密钥成功"
                fi'
            # 获取远端公钥
            remote_key=$(sshpass -p "$SSH_PASSWD" ssh -o StrictHostKeyChecking=no "$Single_ip" \
                'cat ~/.ssh/id_rsa.pub')

            # 追加到本机 authorized_keys
            echo "$remote_key" >> ~/.ssh/authorized_keys
            ssh -o StrictHostKeyChecking=no "$Single_ip" \
                "ssh -o StrictHostKeyChecking=no $local_ip 'echo 测试远端回本机--免密成功'" && \
                color green "$local_ip 和 $Single_ip 互相免密成功" || \
                color red "$local_ip 和 $Single_ip 互相免密失败"
        }
        for_net_list() {
            install_sshpass
            if [ -d /root/.ssh ]; then
                color yellow "检测到存在 .ssh，现进行备份为 /root/.ssh.bak"

                # 如果 .ssh.bak 已存在，先移动到 /tmp 并加时间戳
                if [ -d /root/.ssh.bak ]; then
                    color yellow "检测到存在 .ssh.bak，正在移动到 /tmp"
                    mv /root/.ssh.bak "/tmp/.ssh.bak-$(date +%F)" &>/dev/null
                fi

                # 备份当前 .ssh 为 .ssh.bak
                mv /root/.ssh /root/.ssh.bak &>/dev/null
                color green "已将 .ssh 备份为 .ssh.bak"
            else
                color yellow "未检测到 /root/.ssh 目录，无需备份"
            fi

            read -p "请输入所有机子密码：" SSH_PASSWD
            read -p "请输入/24位子网掩码下的最大主机位数（<=254）：" host_ssh_num

            #删除存放ip的文件
            [ -e ./SCANIP.log ] && rm -f SCANIP.log
            # 循环检测存活 IP
            for i in $(seq 3 "$host_ssh_num"); do
                ip="${NET_NUM}${i}"
                # ping 检测 + 并发执行 ssh 操作
                (
                    if ping -c1 -W1 "$ip" &>/dev/null; then
                        echo "$ip" >> SCANIP.log
                        sshpass -p "$SSH_PASSWD" ssh -o StrictHostKeyChecking=no root@"$ip" '
                            set -e
                            [ -d /root/.ssh ] && mv /root/.ssh "/root/.ssh.bak-$(date +%Y%m%d-%H%M%S)"
                            mkdir -p /root/.ssh
                            chmod 700 /root/.ssh
                        ' &> /dev/null
                    fi
                ) &
            done
            wait
            
            createKey
            sshpass -p "$local_passwd" ssh-copy-id -o StrictHostKeyChecking=no "127.0.0.1" &> /dev/null || (color red "系统可能禁止root用户登入，自行解决";exit 1)
            
            AliveIP_list=$(cat SCANIP.log)
            for n in ${AliveIP_list[*]};do
                
                sshpass -p $SSH_PASSWD scp -o StrictHostKeyChecking=no -r /root/.ssh root@${n}: &>/dev/null \
                && color green "${n}已完成免密" 
            done
            wait

            #把.ssh/known_hosts拷贝到所有主机，使它们第一次互相访问时不需要输入回车
            for n in ${AliveIP_list[*]};do
                scp -o StrictHostKeyChecking=no /root/.ssh/known_hosts ${n}:.ssh/ &>/dev/null
            done

        }

        echo -e "\n \n \n"
            color blue "=====================现在正在进行SSH免密操作===================="
            #用了 $'...'，\n 被解析成真正的换行符，输出就换行了。
            color green $'1.单个ip的互相免密\n2.循环当前机子的网段下的所有机子进行免密(要确保所有机子的密码都一样)'

            echo ""
            color blue "=============================================================="
            read -p "$(color red "请选择免密方式: ")" SSH_MENU_NUM
        
        if [[ ${SSH_MENU_NUM:-0} -eq 1 ]]; then
                #调用ssh免密函数
                Single_SSH
            elif [[ ${SSH_MENU_NUM:-0} -eq 2 ]]; then
                for_net_list
            else
                color red "请输入菜单里的数字"
                exit 
            fi
    }
}

main(){
    function_list
    menu
    }
main
EOF2
bash SSH-Password-free.sh