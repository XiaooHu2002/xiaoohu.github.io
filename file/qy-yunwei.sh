#!/bin/bash

#菜单
menu(){
    color "============================欢迎来到千屹运维脚本============================"
    color blue "作者：严千屹"
    echo ""
    color blue "1.SSH免密  2.DNS配置正反解析"
    
    color "============================================================================"
    read -p "请输入菜单里选项的数字：" menu_num
    case $menu_num in 
        1)SSH-Password-free;;
        2)install_Dns;;
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
        local nl=$'\n'   # 默认换行
        case $1 in
            -n) nl=""; shift ;;  # -n 表示不换行
        esac
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

        printf '\033[%sm%s\033[0m%s' "$col" "$text" "$nl"
    
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
                dpkg -s sshpass &> /dev/null || { apt update -y &> /dev/null; apt -y install sshpass &> /dev/null; }|| { color red "安装sshpass失败，请检查yum源"; exit 1; }
            #rocky|centos|rhel系统
            elif [[ $ID =~ rocky|centos|rhel|openEuler ]];then
                #安装sshpass工具
                rpm -q sshpass &>/dev/null || yum -y install sshpass &> /dev/null || { color red "安装sshpass失败，请检查yum源"; exit 1; }
            else
                echo "不支持当前操作系统"
                exit
            fi 
        }
        Single_SSH(){
            #安装sshpass
            install_sshpass
            #本机进行备份
            read -p "是否需要备份密钥对到tmp？(y/n)："
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                [ -d /root/.ssh.bak ] && (mv /root/.ssh.bak /tmp/.ssh.bak-$(date +%Y%m%d-%H%M%S);color green '检测到存在 .ssh.bak，正在移动到 /tmp')
                [ -d /root/.ssh ] && (mv /root/.ssh /tmp/.ssh.bak;color green '已将 .ssh 备份到 /tmp/.ssh.bak')
            fi
            read -p "请输入对端ip：" Single_ip
            read -p "请输入对端密码：" SSH_PASSWD
            
            # 把函数体用引号包起来，通过 ssh 直接在远端执行
            sshpass -p "$SSH_PASSWD" ssh -o StrictHostKeyChecking=no "$Single_ip" \
                '#远端备份
                [ -d /root/.ssh.bak ] && (mv /root/.ssh.bak /tmp/.ssh.bak-$(date +%Y%m%d-%H%M%S);echo '[INFO] 对端检测到存在 .ssh.bak，正在移动到 /tmp')
                [ -d /root/.ssh ] && (mv /root/.ssh /root/.ssh.bak;echo '[INFO] 对端已将 .ssh 备份为 .ssh.bak')
                #远端生成密钥
                mkdir -p /root/.ssh
                if [ -f ~/.ssh/id_rsa ]; then
                    echo "对端密钥已存在，无需创建"
                else
                    echo "正在对端创建密钥"
                    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa &> /dev/null
                    echo "创建对端密钥成功"
                fi'
            createKey #自己生成密钥对
            #将自身公钥拷贝给对端
            sshpass -p "$SSH_PASSWD" ssh-copy-id -o StrictHostKeyChecking=no "$Single_ip" &> /dev/null
            # 获取远端公钥
            remote_key=$(sshpass -p "$SSH_PASSWD" ssh -o StrictHostKeyChecking=no "$Single_ip" \
                'cat ~/.ssh/id_rsa.pub')&> /dev/null

            # 追加到本机 authorized_keys
            echo "$remote_key" >> ~/.ssh/authorized_keys
            ssh -o StrictHostKeyChecking=no "$Single_ip" \
                "ssh -o StrictHostKeyChecking=no $local_ip 'echo 测试远端回本机--免密成功'" && \
                color green "$local_ip 和 $Single_ip 互相免密成功" || \
                color red "$local_ip 和 $Single_ip 互相免密失败"
        }
        for_net_list() {
            install_sshpass
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
                            [ -d /root/.ssh.bak ] && (mv /root/.ssh.bak /tmp/.ssh.bak-$(date +%Y%m%d-%H%M%S); echo "[INFO] 检测到存在 .ssh.bak，已移动到 /tmp")
                            [ -d /root/.ssh ] && (mv /root/.ssh /root/.ssh.bak; echo "[INFO] 已将 .ssh 备份为 .ssh.bak")
                            mkdir -p /root/.ssh
                            chmod 700 /root/.ssh
                        ' &> /dev/null
                    fi
                ) &
            done
            wait
            
            createKey
            sshpass -p "$local_passwd" ssh-copy-id -o StrictHostKeyChecking=no "127.0.0.1" &> /dev/null || { color red "系统可能禁止root用户登入，自行解决";exit 1; }
            
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

    #DNS配置正反解析
    install_Dns(){
        #安装dns
        install_dns_app() {
            . /etc/os-release

            # ubuntu
            if [[ $ID =~ ubuntu ]]; then
                dpkg -l bind9 bind9-utils bind9-host &>/dev/null \
                    && color green "DNS已安装" \
                    || { apt update -y &>/dev/null; apt -y install bind9 bind9-utils bind9-host &>/dev/null; } \
                    || { color red "安装dns失败，请检查源"; exit 1; }
            # rocky/centos/rhel/openEuler
            elif [[ $ID =~ rocky|centos|rhel|openEuler ]]; then
                rpm -q bind bind-utils &>/dev/null \
                    && color green "DNS已安装" \
                    || yum -y install bind bind-utils &>/dev/null \
                    || { color red "安装bind bind-utils失败，请检查源"; exit 1; }
            else
                color red "不支持当前操作系统"
                exit 1
            fi
        }
        
        init(){
            color -n red "是否有从节点[Y/N]：" 
            read -p "" if_have_slave
            if_have_slave1=$(echo $if_have_slave | tr 'A-Z' 'a-z')
            case $if_have_slave1 in
                y|yes)have_slave;;
                n|no)no_slave;;
                *)color -n red "请输入正确的[Y/N]";exit 1;;
            esac
            
        }
        restart_server(){
            systemctl restart named
            echo "✅ DNS 记录已添加并重新加载 Bind 服务"
        }
        

        #获取基本的解析信息
        init_info(){
            color -n cyan "请输入需要配置的ip:"; read IP
            color -n cyan "请输入需要配置的三级域名:" ; read DOMAIN
            color -n green "本机ip:" ; echo $local_ip

            #获取二级域名
            BASE_DOMAIN=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
            #设置最低级的域名，一般是三级如：www.qianyios.top → www
            SHORT_NAME=$(echo "$DOMAIN" | awk -F. '{print $1}')
            #设置正向区域文件的路径
            ZONE_FILE="/var/named/$BASE_DOMAIN.zone"
            #获取正向区域文件的文件名
            ZONE_FILE_name=$(echo $ZONE_FILE | awk -F'/' '{print $4}') 
            #设置反向数据文件的路径
            REV_ZONE_FILE="/var/named/$(echo $IP | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}').zone"
            #获取反向数据文件路径中的文件名
            REV_ZONE_FILE_name=$(echo $REV_ZONE_FILE | awk -F'/' '{print $4}')
            #主区域配置文件路径
            ZONE_CONFIG="/etc/named.rfc1912.zones"
            # 设置反向前三位的ip
            REV_IP=$(echo $IP | awk -F. '{print $3"."$2"."$1}')
            #设置主机位
            REV_HOST=$(echo $IP | awk -F. '{print $4}')
            


            # 确保 /var/named 目录存在
            mkdir -p /var/named/
            #创建根据域名和ip的正向区域文件和反向区域文件
            touch "$ZONE_FILE" "$REV_ZONE_FILE"
            #赋予权限
            chown named:named "$ZONE_FILE" "$REV_ZONE_FILE"
            chmod 640 "$ZONE_FILE" "$REV_ZONE_FILE"

            # 检查正向区域文件是否已存在相同的解析记录
            if grep -qE "^\s*$SHORT_NAME\s+A" "$ZONE_FILE"; then
                echo "记录 $DOMAIN 已存在，无需添加"
                exit 0
            fi

            # 检查反向区域文件是否已存在相同的解析记录
            if grep -qE "^\s*$REV_HOST\s+PTR" "$REV_ZONE_FILE"; then
                echo "反向解析记录 $REV_HOST 已存在，无需添加"
                exit 0
            fi

            # 递增 serial 号
            increment_serial() {
                # 提取当前 serial 值
                current_serial=$(awk '/serial/{print $1}' "$1")
                
                if [[ -z "$current_serial" ]]; then
                    # 如果没有找到 serial（空），初始化为 1
                    current_serial=1
                fi

                # 递增 serial
                new_serial=$((current_serial + 1))

                # 替换 serial 行，保留前导空格和注释
                sed -i "s/\([[:space:]]*\)\([0-9]\+\)\([[:space:]]*; serial\)/\1$new_serial\3/" "$1"
            }

            #注释掉named.conf的两行注释
            sed -i -e '/listen-on/s/127.0.0.1/localhost/' -e '/allow-query/s/localhost/any/' -e 's/dnssec-enable yes/dnssec-enable no/' -e 's/dnssec-validation yes/dnssec-validation no/'  /etc/named.conf
            
            # 添加正向解析区域配置（如果不存在）
            if ! grep -q "zone \"$BASE_DOMAIN\" IN" "$ZONE_CONFIG"; then
            cat >> "$ZONE_CONFIG" << EOF1
zone "$BASE_DOMAIN" IN {
        type master;
        file "$ZONE_FILE";
        allow-update { none; };
};
EOF1
            fi
            # 添加反向解析区域配置（如果不存在）
            if ! grep -q "zone \"$REV_IP.in-addr.arpa\" IN" "$ZONE_CONFIG"; then
            cat >> "$ZONE_CONFIG" <<EOF3
zone "$REV_IP.in-addr.arpa" IN {
        type master;
        file "$REV_ZONE_FILE";
        allow-update { none; };
};
EOF3
            fi

            # 初始化 Zone 文件（正向解析）
            if [ ! -s "$ZONE_FILE" ]; then
            cat > "$ZONE_FILE" <<EOF4
\$TTL 1D
@       IN SOA  $BASE_DOMAIN. rname.invalid. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS      master
master     A   $local_ip

EOF4
            increment_serial "$ZONE_FILE"  # 初始化时递增 serial
            fi

            # 追加 A 记录（使用短名）
            if ! grep -q "^$SHORT_NAME[[:space:]]*A[[:space:]]*$IP" "$ZONE_FILE"; then
                echo "$SHORT_NAME    A       $IP" >> "$ZONE_FILE"
                increment_serial "$ZONE_FILE"  # 追加记录后递增 serial
            fi

            # **初始化 Zone 文件（反向解析）**
            if [ ! -s "$REV_ZONE_FILE" ]; then
            cat > "$REV_ZONE_FILE" <<EOF5
\$TTL 1D
@       IN SOA  $BASE_DOMAIN. rname.invalid. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS      master.$BASE_DOMAIN.

EOF5
                increment_serial "$REV_ZONE_FILE"  # 初始化时递增 serial
            fi

            # **追加 PTR 记录**
            if ! grep -q "^$REV_HOST[[:space:]]*PTR[[:space:]]*$SHORT_NAME.$BASE_DOMAIN." "$REV_ZONE_FILE"; then
                echo "$REV_HOST     PTR     $SHORT_NAME.$BASE_DOMAIN." >> "$REV_ZONE_FILE"
                increment_serial "$REV_ZONE_FILE"  # 追加记录后递增 serial
            fi

            
        }
        
        have_slave(){
            color red "再次提醒您，如果你没做好互相免密，请你不要进行此步骤"
            color -n cyan "请输入从节点ip:" ; read SLAVE_IP
            color cyan "远程安装dns"
            ssh -T root@"$SLAVE_IP" "$(declare -f color install_dns_app); install_dns_app"
            init_info
            # 初始化 Zone 文件（正向解析）
            if [ ! -s "$ZONE_FILE" ]; then
            cat > "$ZONE_FILE" <<EOF4
\$TTL 1D
@       IN SOA  $BASE_DOMAIN. rname.invalid. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS      master
        NS      slave
master     A   $local_ip
slave      A   $SLAVE_IP
EOF4
            else
                # 文件已存在，但没有 NS slave 行，则插入
                grep -qE '^\s+NS\s+slave\b' "$ZONE_FILE" \
                    || sed -i '/^\s*NS\s\+master\b/a\        NS      slave' "$ZONE_FILE"
                grep -qE '^\s*slave\s+A\s+'"${SLAVE_IP}"'$' "$ZONE_FILE" \
                    || sed -i -E '/^\s*master\s+A\s+'"${local_ip}"'$/a\slave      A   '"${SLAVE_IP}" "$ZONE_FILE"
            increment_serial "$ZONE_FILE"  # 初始化时递增 serial
            fi

            # 追加 A 记录（使用短名）
            if ! grep -q "^$SHORT_NAME[[:space:]]*A[[:space:]]*$IP" "$ZONE_FILE"; then
                echo "$SHORT_NAME    A       $IP" >> "$ZONE_FILE"
                increment_serial "$ZONE_FILE"  # 追加记录后递增 serial
            fi


            # 初始化 Zone 文件（反向解析）
            if [ ! -s "$REV_ZONE_FILE" ]; then
            cat > "$REV_ZONE_FILE" <<EOF5
\$TTL 1D
@       IN SOA  $BASE_DOMAIN. rname.invalid. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS      master.$BASE_DOMAIN.
        NS      slave.$BASE_DOMAIN.

EOF5
            else
                # 文件已存在，但没有 NS slave 行，则插入
                grep -qE '^[[:space:]]+NS[[:space:]]+slave\."$BASE_DOMAIN"\.' "$REV_ZONE_FILE" || \
                    sed -i '/^\s*NS\s\+master\.zx\.com\./a\        NS      slave."$BASE_DOMAIN"\.' "$REV_ZONE_FILE"
            
                increment_serial "$REV_ZONE_FILE"  # 初始化时递增 serial
            fi

            # **追加 PTR 记录**
            if ! grep -q "^$REV_HOST[[:space:]]*PTR[[:space:]]*$SHORT_NAME.$BASE_DOMAIN." "$REV_ZONE_FILE"; then
                echo "$REV_HOST     PTR     $SHORT_NAME.$BASE_DOMAIN." >> "$REV_ZONE_FILE"
                increment_serial "$REV_ZONE_FILE"  # 追加记录后递增 serial
            fi

            # 在从服务器上追加主从同步配置
            ssh -T root@$SLAVE_IP <<EOFSSH
            # 检查从服务器配置文件是否已存在主从同步区域
            if ! grep -q "zone \"$BASE_DOMAIN\" IN" "$ZONE_CONFIG"; then
cat >> "$ZONE_CONFIG" <<EOT
zone "$BASE_DOMAIN" IN { 
    type slave;
    file "slaves/$BASE_DOMAIN.zone"; 
    allow-transfer { $SLAVE_IP;};
    masters { $local_ip; }; # 主服务器的IP
};
EOT
            fi

            # 检查反向解析的从服务器配置
            if ! grep -q "zone \"$REV_IP.in-addr.arpa\" IN" "$ZONE_CONFIG"; then
cat >> "$ZONE_CONFIG" <<EOT
zone "$REV_IP.in-addr.arpa" IN { 
    type slave;
    allow-transfer { $SLAVE_IP;};
    file "slaves/$REV_IP.loopback";
    masters { $local_ip; }; # 主服务器的IP
};
EOT
            fi
EOFSSH

            #重启服务
            restart_server
            ssh -T root@"$SLAVE_IP" "
            # 注释掉 named.conf 的两行注释
            sed -i -e '/listen-on/s/127.0.0.1/localhost/' -e '/allow-query/s/localhost/any/' -e 's/dnssec-enable yes/dnssec-enable no/' -e 's/dnssec-validation yes/dnssec-validation no/'  /etc/named.conf \
            && systemctl restart named && echo '✅ 从服务器 '$SLAVE_IP' 配置已更新并重新加载 Bind 服务' \
            && echo '✅ 主从同步配置已成功添加到从服务器 $SLAVE_IP' && rndc reload "$REV_IP.in-addr.arpa"
            "

            systemctl restart named
            echo ""
        }
        
        no_slave(){
            init_info
            echo ""
            #重启服务
            restart_server
        }

        ubuntu_dns(){
            install_dns_app
            color -n cyan "请输入需要配置的ip:"; read IP
            color -n cyan "请输入需要配置的三级域名:" ; read DOMAIN
            color -n green "本机ip:" ; echo $local_ip

            #获取二级域名
            BASE_DOMAIN=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
            #设置最低级的域名，一般是三级如：www.qianyios.top → www
            SHORT_NAME=$(echo "$DOMAIN" | awk -F. '{print $1}')
            # 提取网段：假设IP是标准IPv4
            REVERSE_IP=$(echo "$IP" | awk -F. '{print $3"."$2"."$1}')
            LAST_OCTET=$(echo "$IP" | awk -F. '{print $4}')
            REVERSE_ZONE="${REVERSE_IP}.in-addr.arpa"
            config_dns () {
                sed -i 's/dnssec-validation auto/dnssec-validation no/' /etc/bind/named.conf.options
                cat >> 	/etc/bind/named.conf.default-zones <<EOF
zone "$BASE_DOMAIN" IN {
    type master;
    file  "/etc/bind/$BASE_DOMAIN.zone";
};
zone "$REVERSE_ZONE" IN {
    type master;
    file "/etc/bind/db.$REVERSE_IP";
};
EOF
        #正向解析文件
        cat > /etc/bind/$BASE_DOMAIN.zone <<EOF
\$TTL 1D
@	IN SOA	master admin (
					1	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
	        NS	 master
master      A    ${local_ip}         
$SHORT_NAME    	A    $IP
EOF
        #反向解析区域文件
        cat > /etc/bind/db.$REVERSE_IP <<EOF
\$TTL 1D
@	IN SOA	master admin (
				1	; serial
				1D	; refresh
				1H	; retry
				1W	; expire
				3H )	; minimum
	NS	master
$LAST_OCTET	IN PTR	$DOMAIN.
EOF

        chgrp bind /etc/bind/$BASE_DOMAIN.zone
        chgrp bind /etc/bind/db.$REVERSE_IP       
            }
            config_dns
        }
        
        menu(){
            color "============================现在正在进行DNS配置============================"
            color blue "作者：严千屹"
            echo ""
            color green "此操作必须在主节点上运行"
            color blue "此操作输入ip 和需要配置的正反解析的域名即可"
            color red "如果有从节点，请自行将主从节点做好互相免密操作，并且自行把dns1设置为主节点的ip，不然后果自负"
            color red "一旦输入，就会自动配置正向和反向一一对应的解析，只支持A记录"
            color red "只适用三级域名"
            color blue "以上是针对centos，rocky，openeuler系统做的功能，ubuntu暂时支持简单的dns安装"

            color "============================================================================"
            
            if [[ $ID =~ ubuntu ]]; then
                ubuntu_dns
                restart_server
            # rocky/centos/rhel/openEuler
            elif [[ $ID =~ rocky|centos|rhel|openEuler ]]; then
                install_dns_app
                init
            else
                color red "不支持当前操作系统"
                exit 1
            fi

        }
        menu
        

        
    }

}

main(){
    function_list
    menu
    }
main
