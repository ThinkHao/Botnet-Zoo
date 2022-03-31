#!/bin/bash

# 上次修改时间 --> 2022-3-31
# --------------------------------------------------
# 创建备份目录，以清除时间命名

time=$(date | awk '{print $5}')
log_dir="/tmp/botgank/billgates-$time"
log_file="$log_dir/log"
if [ ! -d "/tmp/botgank/billgates-$time/" ]
then
    # 创建定时任务、文件、进程备份目录
    mkdir -p $log_dir
    mkdir -p $log_dir/crontab
    mkdir -p $log_dir/file
    mkdir -p $log_dir/process
    touch $log_file
fi

echo "[+] start clean --> $(date)" | tee -a $log_file


# --------------------------------------------------
# 函数定义

# 文件清除函数
kill_file()
{
    if [ -f "$1" ]
    then
        cp -n $1 $log_dir/file
        chattr -ia $1
        rm -rf $1
        echo "[+] clean file --> $1" | tee -a $log_file
    fi
}

# 目录清除函数
kill_dir()
{
    cp -r $1 $log_dir/file
    chattr -ia $1
    rm -rf $1
    echo "[+] clean dir --> $1" | tee -a $log_file
}

# 进程清除函数
kill_proc()
{
    if [ -n "$1" ]
    then
        proc_name=$(basename $(ps -fp $1 | awk 'NR>=2 {print $8}'))
        cat /proc/$1/exe >> $log_dir/process/$1-$proc_name.dump
        echo "[+] clean process --> $(ps -fp $1 | awk 'NR>=2 {print $2,$8}')" | tee -a $log_file
        kill -9 $1
    fi
}

cron_dirs=("/var/spool/cron/" "/etc/cron.d/" "/etc/cron.hourly/")

# 定时任务清除函数
kill_cron()
{
    cron_dirs=("/var/spool/cron/" "/etc/cron.d/" "/etc/cron.hourly/")
    for cron_dir in ${cron_dirs[@]}
    do
        if [ -n "$(grep -Er $1 $cron_dir)" ]
        then
            crontab=$(grep -Er $1 $cron_dir)
            cron_file=$(grep -Er $1 $cron_dir | awk '{print $1}' | cat | cut -d : -f 1 | uniq)
            cp -n $cron_file $log_dir/crontab
            chattr -ia $cron_file
            sed -i "/$1/d" $cron_file > /dev/null 2>&1
            if [ $? != 0 ]
            then
                echo '' > $cron_file
            fi
            echo "[+] clean crontab --> $crontab" | tee -a $log_file
        fi
    done
}

# --------------------------------------------------
# 恢复系统程序

# 恢复系统文件netstat
if [ -f "/usr/bin/dpkgd/netstat" ]
then
	$busybox chattr -ai /bin/netstat
	rm -f /bin/netstat
	
	$busybox chattr -ai /usr/bin/netstat
	rm -f /usr/bin/netstat
    
    yum reinstall net-tools -y

    echo "[+] recover file --> netstat" | tee -a $log_file
fi

# 恢复系统文件lsof
if [ -f "/usr/bin/dpkgd/lsof" ]
then
	$busybox chattr -ai /bin/lsof
	rm -f /bin/lsof
	
	$busybox chattr -ai /usr/bin/lsof 
	rm -f /usr/bin/lsof

    yum reinstall lsof -y

    echo "[+] recover file --> lsof" | tee -a $log_file
fi

# 恢复系统文件ps
if [ -f "/usr/bin/dpkgd/ps" ]
then
	$busybox chattr -ai /bin/ps
	rm -f /bin/ps
	
	$busybox chattr -ai /usr/bin/ps
	rm -f /usr/bin/ps

    yum reinstall procps -y

    echo "[+] recover file --> ps" | tee -a $log_file
fi

# 恢复系统文件ss
if [ -f "/usr/bin/dpkgd/ss" ]
then
	$busybox chattr -ai /bin/ss
	rm -f /bin/ss
	
	$busybox chattr -ai /usr/bin/ss
	rm -f /usr/bin/ss

    yum reinstall iproute -y

    echo "[+] recover file --> ss" | tee -a $log_file
fi

# --------------------------------------------------
# 下载busybox工具
busybox='/tmp/busybox'

if [ ! -f "$busybox" ]
then
    echo "[+] downloading busybox..."
    wget -q --timeout=5 http://www.busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-$(uname -m) -O $busybox
    echo "[+] download busybox success --> /tmp/busybox" | tee -a $log_file
    chmod a+x $busybox
fi

busybox_size=$(ls -l $busybox | awk '{print $5}')
if [ $busybox_size -eq 0 ]
then
    busybox=''
fi

# --------------------------------------------------
# 清除billgates病毒进程

# 结束守护进程sshd
if [ -f "/tmp/moni.lod" ]
then
    proc_id="$(cat /tmp/moni.lod)"
    if [ -n "$(echo $proc_id | egrep '[0-9]{3,6}')" ]
    then
        if [ -n "$($busybox ps -elf | grep $proc_id | grep -v grep)" ]
        then
            cat /proc/$proc_id/exe >> $log_dir/process/$proc_id-sshd.dump
            echo "[+] clean process .sshd --> $proc_id" | tee -a $log_file
            kill -9 $proc_id
        fi
    fi
fi

# 结束母体进程getty
if [ -f "/tmp/gates.lod" ]
then
    proc_id="$(cat /tmp/gates.lod)"
    if [ -n "$(echo $proc_id | egrep '[0-9]{3,6}')" ]
    then
        if [ -n "$($busybox ps -elf | grep $proc_id | grep -v grep)" ]
        then
            cat /proc/$proc_id/exe >> $log_dir/process/$proc_id-getty.dump
            echo "[+] clean process getty --> $proc_id" | tee -a $log_file
            kill -9 $proc_id
        fi
    fi
fi

if [ -f "/usr/bin/bsd-port/getty.lock" ]
then
    proc_id="$(cat /usr/bin/bsd-port/getty.lock)"
    if [ -n "$(echo $proc_id | egrep '[0-9]{3,6}')" ]
    then
        if [ -n "$($busybox ps -elf | grep $proc_id | grep -v grep)" ]
        then
            cat /proc/$proc_id/exe >> $log_dir/process/$proc_id-getty2.dump
            echo "[+] clean process getty.lock --> $proc_id" | tee -a $log_file
            kill -9 $proc_id
        fi
    fi
fi

# 清除病毒进程(进程名称通常是随机的，因此从文件中获取)
proc_name=$(cat /etc/init.d/DbSecuritySpt | grep -v ^#)
pids="$(ps -elf | grep "${proc_name}" | grep -v grep | awk '{print $4}')"
if [ -n "$pids" ]
then
    for pid in $pids; do kill_proc $pid; done
fi

pids="$(ps -elf | grep '/usr/bin/bsd-port/getty' | grep -v grep | awk '{print $4}')"
if [ -n "$pids" ]
then
    for pid in $pids; do kill_proc $pid; done
fi

pids="$(ps -elf | grep '/usr/bin/.sshd' | grep -v grep | awk '{print $4}')"
if [ -n "$pids" ]
then
    for pid in $pids; do kill_proc $pid; done
fi

# --------------------------------------------------
# 清除billgates病毒文件

if [ -f ${proc_name} ]
then
    kill_file ${proc_name}
fi

# 删除病毒程序文件
if [ -f "/usr/bin/.sshd" ]
then
    kill_file /usr/bin/.sshd
fi

# 删除病毒目录
if [ -d "/usr/bin/bsd-port" ]
then
    kill_dir /usr/bin/bsd-port
fi

# 删除垃圾文件
if [ -f "/tmp/moni.lod" ]
then
    kill_file /tmp/moni.lod
fi

if [ -f "/tmp/gates.lod" ]
then
    kill_file /tmp/gates.lod
fi

# 删除自启动文件
if [ -f "/etc/init.d/selinux" ]
then
    kill_file /etc/init.d/selinux
fi

if [ -f "/etc/init.d/DbSecuritySpt" ]
then
    kill_file $(sed -n '$p' /etc/init.d/DbSecuritySpt)
    kill_file /etc/init.d/DbSecuritySpt
fi

rm -f /etc/rc[1-5].d/S97DbSecuritySpt
rm -f /etc/rc[1-5].d/S99selinux
echo "[+] clean file --> /etc/rc[1-5].d" | tee -a $log_file

echo "[+] end clean --> $(date)" | tee -a $log_file
# --------------------------------------------------
# 安装rkhunter验证查杀结果
pkg=rkhunter
echo "[+] install package --> $pkg" | tee -a $log_file
yum install epel-release rkhunter -y
echo "[+] start system scan --> rkhunter -c --skip-keypress" | tee -a $log_file
rkhunter -c --skip-keypress
echo "[+] end scan --> rkhunter -c --skip-keypress" | tee -a $log_file