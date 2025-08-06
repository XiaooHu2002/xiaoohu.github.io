#!/bin/bash
ubuntu_libaio1_url="https://mirrors.aliyun.com/ubuntu/pool/main/liba/libaio/libaio1_0.3.112-13build1_amd64.deb"
menu(){
    color "=========================欢迎来到Mysql二进制安装脚本=========================="
    color blue "作者：严千屹"
    echo ""
    color green "请选择安装的版本"
    color blue "1. <5.7.38>  2. <8.0.28>"
    color red "卸载二进制安装的mysql,请输入 3 ："
    
    color "============================================================================"
    read -p "请输入菜单里选项的数字：" menu_num
    
    case $menu_num in
        1|2) install-mysql ;;
        3) uninstall_mysql;;
        *) color red "请输入菜单里的数字";exit 1;;
    esac
}
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
        if [ $UID -ne 0 ]; then
            color red "当前用户不是root,安装失败"
            exit 1
        fi
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
    install-mysql(){
        read -p "请输入你要设置的mysql密码：" MYSQL_PASSWD

        
        # 安装基础库
        if [[ "$ID" =~ ubuntu ]]; then
            if (dpkg -l wget tar libaio-dev numactl libnuma-dev libncurses6 libncurses-dev &> /dev/null); then
                color green "已安装基础软件"
            else
                apt update -y &> /dev/null
                apt install -y wget tar libaio-dev numactl libnuma-dev libncurses6 libncurses-dev &> /dev/null
                if [ $? -eq 0 ]; then
                    color green "成功安装基础软件"
                else
                    color red "安装基础软件失败，请检查/etc/apt/sources.list"
                    exit 1
                fi
            fi

            # 创建软链接
            ln -s /usr/lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.5 &>/dev/null
            ln -s /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5 &>/dev/null

            # 检查并安装 libaio1
            if dpkg -l libaio1 &> /dev/null; then
                color green "已安装libaio1软件"
            else
                apt update -y &> /dev/null
                apt install -y libaio1 &> /dev/null
                if [ $? -ne 0 ]; then
                    mkdir test && cd test
                    wget $ubuntu_libaio1_url &> /dev/null
                    dpkg -i libaio1_*.deb &> /dev/null
                    if [ $? -ne 0 ]; then
                        color red "安装libaio1失败，请检查/test下的包，是否支持当前版本，不支持请寻找合适的链接替换脚本中的内容"
                        exit 1
                    else
                        color green "成功安装libaio1软件"
                    fi
                else
                    color green "成功安装libaio1软件"
                fi
            fi
        elif [[ "$ID" =~ rocky|Rocky && "$VERSION_ID" =~ "10.0" ]]; then
        
            if (rpm -q wget tar chkconfig libaio numactl-libs &>/dev/null); then
                color green "已安装基础软件"
            else
                yum -y install wget tar chkconfig libaio numactl-libs &> /dev/null
                if [ $? -eq 0 ]; then
                    color green "成功安装基础软件"
                else
                    color red "安装基础软件失败，请检查yum源"
                    exit 1
                fi
            fi
            dnf --enablerepo=devel install libxcrypt-compat -y &>/dev/null
            [[ -e /lib64/libcrypt.so.1 ]] ||  ln -s /lib64/libcrypt.so.[0-2].[0-2].[0-2] /lib64/libcrypt.so.1 &>/dev/null
            [[ -e /lib64/libncurses.so.5 ]] ||  ln -s /lib64/libncurses.so.6.[0-9] /lib64/libncurses.so.5 &>/dev/null
            [[ -e /lib64/libtinfo.so.5 ]] || ln -s /lib64/libtinfo.so.6.[0-9] /lib64/libtinfo.so.5 &>/dev/null
            

        elif [[ "$ID" =~ centos|rhel|rocky|Rocky|openEuler ]]; then
            if (rpm -q wget tar chkconfig libaio numactl-libs ncurses-compat-libs &>/dev/null); then
                color green "已安装基础软件"
            else
                yum -y install wget tar chkconfig libaio numactl-libs ncurses-compat-libs &> /dev/null
                if [ $? -eq 0 ]; then
                    color green "成功安装基础软件"
                else
                    color red "安装基础软件失败，请检查yum源"
                    exit 1
                fi
            fi
            [[ -e /lib64/libcrypt.so.1 ]] ||  ln -s /lib64/libcrypt.so.[0-2].[0-2].[0-2] /lib64/libcrypt.so.1 &>/dev/null
            [[ -e /lib64/libncurses.so.5 ]] ||  ln -s /lib64/libncurses.so.6.[0-9] /lib64/libncurses.so.5 &>/dev/null
            [[ -e /lib64/libtinfo.so.5 ]] || ln -s /lib64/libtinfo.so.6.[0-9] /lib64/libtinfo.so.5 &>/dev/null
            
        else
            color red "不支持的操作系统"
            exit 1
        fi

    
        #下载二进制文件
        SOURCE_DIR=$(pwd)
        if [ "$menu_num" -eq 1 ];then
            MYSQL_VERSION="5.7.38"
            URL="https://mirrors.aliyun.com/mysql/MySQL-5.7/mysql-5.7.38-linux-glibc2.12-x86_64.tar.gz"
            MYSQL_NAME=$(echo $URL | awk -F'/' '{print $NF}')
            gzip -t $SOURCE_DIR/$MYSQL_NAME &> /dev/null \
            && color green "二进制文件存在且完整" || (color red "二进制文件损坏或者不存在，正在进行下载";rm -rf $SOURCE_DIR/$MYSQL_NAME;wget $URL)
            wait
            tar xf $SOURCE_DIR/$MYSQL_NAME -C /usr/local && color green "解压二进制文件成功" || { color red "解压失败";exit 1; }
            mv /usr/local/$(echo $MYSQL_NAME | awk -F'.tar' '{print $1}') /usr/local/mysql

        elif [ "$menu_num" -eq 2 ];then
            MYSQL_VERSION="8.0.28"
            URL="https://mirrors.aliyun.com/mysql/MySQL-8.0/mysql-8.0.28-linux-glibc2.12-x86_64.tar.xz"
            MYSQL_NAME=$(echo $URL | awk -F'/' '{print $NF}')
            xz -t $SOURCE_DIR/$MYSQL_NAME &> /dev/null \
            && color green "二进制文件存在且完整" || (color red "二进制文件损坏或者不存在，正在进行下载";rm -rf $SOURCE_DIR/$MYSQL_NAME;wget $URL)
            wait
            tar xf $SOURCE_DIR/$MYSQL_NAME -C /usr/local && color green "解压二进制文件成功" || { color red "解压失败";exit 1; }
            mv /usr/local/$(echo $MYSQL_NAME | awk -F'.tar' '{print $1}') /usr/local/mysql

        fi
        wait
        #创建用户和组
        (groupadd mysql &> /dev/null && useradd -r -g mysql -s /bin/false mysql &> /dev/null) \
            && color green "已创建mysql用户和mysql组"
        chown -R mysql:mysql /usr/local/mysql
        

        #准备环境变量
        # 定义要检查的路径
        path_to_check="export PATH=/usr/local/mysql/bin:\$PATH"

        # 检查 /etc/profile 文件中是否存在该路径
        if grep -- "${path_to_check}" /etc/profile; then
            echo "环境变量已存在，无需追加。"
        else
            # 如果不存在，则追加到文件末尾
            echo "${path_to_check}" >> /etc/profile
            echo "环境变量已成功追加到 /etc/profile 文件。"
        fi
        sleep 2
        source /etc/profile


        #准备配置文件
        mkdir -p /data &> /dev/null
        cp /etc/my.cnf{,.bak} &> /dev/null 
cat > /etc/my.cnf <<"EOF2"
[mysqld]
datadir=/data/mysql
socket=/data/mysql/mysql.sock    
log-error=/data/mysql/mysql.log
pid-file=/data/mysql/mysql.pid
character-set-server=utf8mb4
#开启二进制选项
#log-bin=mysql-bin  #后续会在/data/mysql生成mysql-bin.000001的二进制文件，你可以自定义路径和文件名不用加后缀
#二进制日志记录的格式，mariadb5.5默认STATEMENT
#binlog_format=STATEMENT|ROW|MIXED
[client]
socket=/data/mysql/mysql.sock
[mysql]
prompt=(\\u@\\h) [\\d]>\\_
EOF2
        color green "已准备好配置文件"



        #初始化数据库文件并提取root密码
    mkdir -p /data/mysql
    cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
    mysqld --initialize --user=mysql --datadir=/data/mysql
    if [[ "$ID" =~ ubuntu ]]; then
        sudo chmod +x /etc/init.d/mysqld
        sudo update-rc.d mysqld defaults
    elif [[ "$ID" =~ centos|rhel|rocky|Rocky|openEuler ]]; then
        chkconfig --add mysqld &>/dev/null
        chkconfig mysqld on &>/dev/null
    fi

    systemctl start mysqld && color green "启动mysql成功" || { color red "mysql启动失败，请检查配置文件等因素";exit 1; }
    systemctl enable mysqld
    sleep 5

    MYSQL_OLD_PASSWD=$(awk '/temporary password/{print $NF}' /data/mysql/mysql.log)
    sleep 5
    mysqladmin -uroot -p$MYSQL_OLD_PASSWD password $MYSQL_PASSWD &>/dev/null
    color green "数据库安装成功"
    echo ""
    color -n "数据库版本是：";color green "$MYSQL_VERSION"
    color -n "你的数据库用户为root，密码是：";color green "$MYSQL_PASSWD"
    color -n "数据库的数据目录：";color green "/data/mysql"
    color -n "数据库的根目录是：";color green "/usr/local/mysql"
    

    }
    uninstall_mysql(){
        SOURCE_DIR=$(pwd)
        rm -rf $SOURCE_DIR/test
        # 停止 MySQL 服务
        if systemctl is-active --quiet mysqld; then
            sudo systemctl stop mysqld
            color green "MySQL 服务已停止"
        else
            color yellow "MySQL 服务未运行"
        fi

        # 禁用 MySQL 服务
        if systemctl is-enabled --quiet mysqld; then
            sudo systemctl disable --now mysqld
            color green "MySQL 服务已禁用"
        else
            color yellow "MySQL 服务未启用"
        fi

        # 删除 MySQL 数据目录
        if [ -d "/data/mysql" ]; then
            sudo rm -rf /data/mysql
            color green "/data/mysql 数据目录已删除"
        else
            color yellow "/data/mysql 数据目录不存在"
        fi

        # 删除 MySQL 安装目录
        if [ -d "/usr/local/mysql" ]; then
            sudo rm -rf /usr/local/mysql
            color green "/usr/local/mysql 安装目录已删除"
        else
            color yellow "/usr/local/mysql 安装目录不存在"
        fi

        # 删除 MySQL 用户和组
        if id -u mysql &>/dev/null; then
            sudo userdel -r mysql
            sudo groupdel mysql
            color green "MySQL 用户和组已删除"
        else
            color yellow "MySQL 用户和组不存在"
        fi

        # 删除配置文件
        if [ -f "/etc/my.cnf" ]; then
            sudo rm -f /etc/my.cnf
            color green "/etc/my.cnf 配置文件已删除"
        else
            color yellow "/etc/my.cnf 配置文件不存在"
        fi

        if [ -f "/etc/my.cnf.bak" ]; then
            sudo rm -f /etc/my.cnf.bak
            color green "/etc/my.cnf.bak 备份文件已删除"
        else
            color yellow "/etc/my.cnf.bak 备份文件不存在"
        fi

        # 删除环境变量配置
        # 定义要检查的路径
        path_to_check="export PATH=/usr/local/mysql/bin:\$PATH"
        # 检查 /etc/profile 文件中是否存在该路径
        if grep -q -- "${path_to_check}" /etc/profile; then
            # 使用 sed 删除匹配的行
            sed -i "/${path_to_check//\//\\/}/d" /etc/profile
            color green "环境变量已成功从 /etc/profile 文件中删除。"
        else
            color green  "环境变量不存在，无需删除。"
        fi

        # 重新加载 /etc/profile 文件
        source /etc/profile

        color green "MySQL 卸载完成"
    }    
}

main(){
    function_list
    menu
    
}
main
