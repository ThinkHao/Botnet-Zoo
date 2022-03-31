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

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  print_message
#   DESCRIPTION:  Prints a message all fancy like
#    PARAMETERS:  $1 = Message to print
#                 $2 = Severity. info, ok, error, warn
#       RETURNS:  Formatted Message to stdout
#-------------------------------------------------------------------------------
print_message() {
  local message
  local severity
  local red
  local green
  local yellow
  local nc

  message="${1}"
  severity="${2}"
  red='\e[0;31m'
  green='\e[0;32m'
  yellow='\e[1;33m'
  nc='\e[0m'

  case "${severity}" in
    "info" ) echo -e "${nc}${message}${nc}";;
      "ok" ) echo -e "${green}${message}${nc}";;
   "error" ) echo -e "${red}${message}${nc}";;
    "warn" ) echo -e "${yellow}${message}${nc}";;
  esac


}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  kill_file()
#   DESCRIPTION:  文件清除函数
#    PARAMETERS:  $1 = File to delete
#       RETURNS:  0 = File deleted
#                 20 = Could not find command cp
#                 21 = Could not find command chattr
#                 22 = Could not find command rm
#-------------------------------------------------------------------------------
kill_file()
{
    local rcode

    file="${1}"

    if [ -f "${file}" ]
    then
        if command -v cp > /dev/null 2>&1;then
            cp -n $file $log_dir/file
            if command -v chattr > /dev/null 2>&1;then
                chattr -ia $file
                if command -v rm > /dev/null 2>&1;then
                # print_message "[+] clean file --> $1" "info" | tee -a $log_file
                    rm -rf $file
                    rcode= "${?}"
                else
                    rcode="22"
                fi
            else
                rcode="21"
            fi
        else
            rcode="20"
        fi
    fi
    return "${rcode}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  kill_dir()
#   DESCRIPTION:  目录清除函数
#    PARAMETERS:  $1 = Diractory to delete
#       RETURNS:  0 = Diractory deleted
#                 20 = Could not find command cp
#                 21 = Could not find command chattr
#                 22 = Could not find command rm
#-------------------------------------------------------------------------------
kill_dir()
{
    local rcode

    dir="${1}"

    if [[ -d ${dir} ]]
    then
        if command -v cp > /dev/null 2>&1;then
            cp -r $dir $log_dir/file
            if command -v chattr > /dev/null 2>&1;then
                chattr -ia $dir
                if command -v rm > /dev/null 2>&1;then
                    rm -rf $dir
                    # echo "[+] clean dir --> $1" | tee -a $log_file
                    rcode="${?}"
                else
                    rcode="22"
                fi
            else
                rcode="21"
            fi
        else
            rcode="20"
        fi
    fi
    return "${rcode}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  kill_proc()
#   DESCRIPTION:  进程清除函数
#    PARAMETERS:  $1 = Process to delete
#       RETURNS:  0 = Process deleted
#                 20 = Could not find command ps
#                 21 = Could not find command awk
#                 22 = Could not find command basename
#                 23 = Could not find command kill
#-------------------------------------------------------------------------------
kill_proc()
{
    local rcode

    proc="${1}"

    if [[ -n "${proc}" ]]
    then
        if command -v ps > /dev/null 2>&1;then
            if command -v awk > /dev/null 2>&1;then
                if command -v basename > /dev/null 2>&1;then
                    proc_name=$(basename $(ps -fp $proc | awk 'NR>=2 {print $8}'))
                    if command -v cat > /dev/null 2>&1;then
                        cat /proc/$proc/exe >> $log_dir/process/$proc-$proc_name.dump
                        # echo "[+] clean process --> $(ps -fp $1 | awk 'NR>=2 {print $2,$8}')" | tee -a $log_file
                        if command -v kill > /dev/null 2>&1;then
                            kill -9 $proc
                            rcode="${?}"
                        fi
                    else
                        rcode="23"
                    fi
                else
                    rcode="22"
                fi
            else
                rcode="21"
            fi
        else
            rcode="20"
        fi    
    fi
    return "$rcode"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  kill_cron()
#   DESCRIPTION:  计划任务清除函数
#    PARAMETERS:  $1 = Process key word
#       RETURNS:  0 = Cron file deleted
#                 20 = Could not find command grep
#                 21 = Could not find command awk
#                 22 = Could not find command cat
#                 23 = Could not find command cut
#                 24 = Could not find command uniq
#                 25 = Could not find command cp
#                 26 = Could not find command chattr
#                 27 = Could not find command sed
#-------------------------------------------------------------------------------
kill_cron()
{
    local cron_dirs
    local rcode

    proc_keyword="${1}"

    cron_dirs=("/var/spool/cron/" "/etc/cron.d/" "/etc/cron.hourly/")
    for cron_dir in ${cron_dirs[@]}
    do
        if command -v grep > /dev/null 2>&1;then
            if command -v awk > /dev/null 2>&1;then
                if command -v cat > /dev/null 2>&1;then
                    if command -v cut > /dev/null 2>&1;then
                        if command -v uniq > /dev/null 2>&1;then
                            if command -v cp > /dev/null 2>&1;then
                                if command -v chattr > /dev/null 2>&1;then
                                    if command -v sed > /dev/null 2>&1;then
                                        if [ -n "$(grep -Er $proc_keyword $cron_dir)" ]
                                        then
                                            crontab=$(grep -Er $proc_keyword $cron_dir)
                                            cron_file=$(grep -Er $proc_keyword $cron_dir | awk '{print $1}' | cat | cut -d : -f 1 | uniq)
                                            cp -n $cron_file $log_dir/crontab
                                            chattr -ia $cron_file
                                            sed -i "/$proc_keyword/d" $cron_file > /dev/null 2>&1
                                            if [ $? != 0 ]
                                            then
                                                echo '' > $cron_file
                                                rcode="${?}"
                                            fi
                                            # echo "[+] clean crontab --> $crontab" | tee -a $log_file
                                        fi
                                    else
                                        rcode="27"
                                    fi
                                else
                                    rcode="26"
                                fi
                            else
                                rcode="25"
                            fi
                        else
                            rcode="24"
                        fi
                    else
                        rcode="23"
                    fi
                else
                    rcode="22"
                fi
            else
                rcode="21"
            fi
        else
            rcode="20"
        fi
    done
    return "$rcode"
}

# --------------------------------------------------
# 恢复系统程序
recover_sysfile()
{
    local rcode
    local binfiles

    binfiles=("netstat" "lsof" "ps" "ss")

    for binfile in ${binfiles[@]}
    do
        if [[ -f /bin/$binfile ]];then
            $busybox chattr -ai /bin/$binfile
            rm -f /bin/$binfile
        fi
        if [[ -f /usr/bin/$binfile ]];then
            $busybox chattr -ai /usr/bin/$binfile
            rm -f /usr/bin/$binfile
        fi
    done
    yum reinstall net-tools lsof procps iproute -y
    rcode="${?}"
    return "${rcode}"
}

# # 恢复系统文件netstat
# if [ -f "/usr/bin/dpkgd/netstat" ]
# then
# 	$busybox chattr -ai /bin/netstat
# 	rm -f /bin/netstat
	
# 	$busybox chattr -ai /usr/bin/netstat
# 	rm -f /usr/bin/netstat
    
#     yum reinstall net-tools -y

#     echo "[+] recover file --> netstat" | tee -a $log_file
# fi

# # 恢复系统文件lsof
# if [ -f "/usr/bin/dpkgd/lsof" ]
# then
# 	$busybox chattr -ai /bin/lsof
# 	rm -f /bin/lsof
	
# 	$busybox chattr -ai /usr/bin/lsof 
# 	rm -f /usr/bin/lsof

#     yum reinstall lsof -y

#     echo "[+] recover file --> lsof" | tee -a $log_file
# fi

# # 恢复系统文件ps
# if [ -f "/usr/bin/dpkgd/ps" ]
# then
# 	$busybox chattr -ai /bin/ps
# 	rm -f /bin/ps
	
# 	$busybox chattr -ai /usr/bin/ps
# 	rm -f /usr/bin/ps

#     yum reinstall procps -y

#     echo "[+] recover file --> ps" | tee -a $log_file
# fi

# # 恢复系统文件ss
# if [ -f "/usr/bin/dpkgd/ss" ]
# then
# 	$busybox chattr -ai /bin/ss
# 	rm -f /bin/ss
	
# 	$busybox chattr -ai /usr/bin/ss
# 	rm -f /usr/bin/ss

#     yum reinstall iproute -y

#     echo "[+] recover file --> ss" | tee -a $log_file
# fi

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
            echo "[+] clean process .sshd --> $proc_id", | tee -a $log_file
            kill -9 $proc_id
            if [[ ${?} = 0 ]];then
                print_message "Success" "ok"
            else
                print_message "Fail" "error"
                exit 127 
            fi
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
            echo "[+] clean process getty --> $proc_id", | tee -a $log_file
            kill -9 $proc_id
            if [[ ${?} = 0 ]];then
                print_message "Success" "ok"
            else
                print_message "Fail" "error"
                exit 127
            fi
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
            echo "[+] clean process getty.lock --> $proc_id", | tee -a $log_file
            kill -9 $proc_id
            if [[ ${?} = 0 ]];then
                print_message "Success" "ok"
            else
                print_message "Fail" "error"
                exit 127
            fi
        fi
    fi
fi

# 清除病毒进程(进程名称通常是随机的，因此从文件中获取)
if [ -f "/etc/init.d/DbSecuritySpt" ]
then
    proc_name=$(cat /etc/init.d/DbSecuritySpt | grep -v ^#)
    pids="$(ps -elf | grep "${proc_name}" | grep -v grep | awk '{print $4}')"
    if [ -n "$pids" ]
    then
        for pid in $pids
        do 
            kill_proc $pid
            if [[ ${?} = 0 ]];then
                print_message "Success to kill processes ${pid}" "ok"
            else
                print_message "Fail to kill processes. Error code is ${?}." "error"
                exit ${?}
            fi
        done
    fi
fi

if [ -f "/usr/bin/bsd-port/getty" ]
then
    pids="$(ps -elf | grep '/usr/bin/bsd-port/getty' | grep -v grep | awk '{print $4}')"
    if [ -n "$pids" ]
    then
        for pid in $pids
        do
            kill_proc $pid
            if [[ ${?} = 0 ]];then
                print_message "Success to kill processes ${pid}" "ok"
            else
                print_message "Fail to kill processes. Error code is ${?}." "error"
                exit ${?}
            fi
        done
    fi
fi

if [ -f "/usr/bin/.sshd" ]
then
    pids="$(ps -elf | grep '/usr/bin/.sshd' | grep -v grep | awk '{print $4}')"
    if [ -n "$pids" ]
    then
        for pid in $pids
        do
            kill_proc $pid
            if [[ ${?} = 0 ]];then
                print_message "Success to kill processes ${pid}" "ok"
            else
                print_message "Fail to kill processes. Error code is ${?}." "error"
                exit ${?}
            fi
        done
    fi
fi

# --------------------------------------------------
# 清除billgates病毒文件
if [ -f "/etc/init.d/DbSecuritySpt" ]
then
    proc_name=$(cat /etc/init.d/DbSecuritySpt | grep -v ^#)
    if [ -f ${proc_name} ]
    then
        kill_file ${proc_name}
        if [[ ${?} = 0 ]];then
            print_message "Success to kill file ${proc_name}" "ok"
        else
            print_message "Fail to kill file. Error code is ${?}." "error"
            exit ${?}
        fi
    fi
fi

# 删除病毒程序文件
if [ -f "/usr/bin/.sshd" ]
then
    kill_file /usr/bin/.sshd
    if [[ ${?} = 0 ]];then
        print_message "Success to kill file /usr/bin/.sshd" "ok"
    else
        print_message "Fail to kill file. Error code is ${?}." "error"
        exit ${?}
    fi
fi

# 删除病毒目录
if [ -d "/usr/bin/bsd-port" ]
then
    kill_dir /usr/bin/bsd-port
    if [[ ${?} = 0 ]];then
        print_message "Success to kill dir /usr/bin/bsd-port" "ok"
    else
        print_message "Fail to kill dir. Error code is ${?}." "error"
        exit ${?}
    fi
fi

# 删除垃圾文件
if [ -f "/tmp/moni.lod" ]
then
    kill_file /tmp/moni.lod
    if [[ ${?} = 0 ]];then
        print_message "Success to kill file /tmp/moni.lod" "ok"
    else
        print_message "Fail to kill file. Error code is ${?}." "error"
        exit ${?}
    fi
fi

if [ -f "/tmp/gates.lod" ]
then
    kill_file /tmp/gates.lod
    if [[ ${?} = 0 ]];then
        print_message "Success to kill file /tmp/gates.lod" "ok"
    else
        print_message "Fail to kill file. Error code is ${?}." "error"
        exit ${?}
    fi
fi

# 删除自启动文件
if [ -f "/etc/init.d/selinux" ]
then
    kill_file /etc/init.d/selinux
    if [[ ${?} = 0 ]];then
        print_message "Success to kill file /etc/init.d/selinux" "ok"
    else
        print_message "Fail to kill file. Error code is ${?}." "error"
        exit ${?}
    fi
fi

if [ -f "/etc/init.d/DbSecuritySpt" ]
then
    kill_file $(sed -n '$p' /etc/init.d/DbSecuritySpt)
    kill_file /etc/init.d/DbSecuritySpt
    if [[ ${?} = 0 ]];then
        print_message "Success to kill file /etc/init.d/DbSecuritySpt" "ok"
    else
        print_message "Fail to kill file. Error code is ${?}." "error"
        exit ${?}
    fi
fi

if [[ -f "/etc/rc1.d/S97DbSecuritySpt" || -f "/etc/rc2.d/S97DbSecuritySpt" || -f "/etc/rc3.d/S97DbSecuritySpt" || -f "/etc/rc4.d/S97DbSecuritySpt" || -f "/etc/rc5.d/S97DbSecuritySpt" || -f "/etc/rc1.d/S99selinux" || -f "/etc/rc2.d/S99selinux" || -f "/etc/rc3.d/S99selinux" || -f "/etc/rc4.d/S99selinux" || -f "/etc/rc5.d/S99selinux" ]]
then
    echo "[+] clean file --> /etc/rc[1-5].d", | tee -a $log_file
    rm -f /etc/rc[1-5].d/S97DbSecuritySpt && rm -f /etc/rc[1-5].d/S99selinux
    if [[ ${?} = 0 ]];then
        print_message "Success" "ok"
    else
        print_message "Fail" "error"
        exit 127
    fi
fi


echo "[+] end clean --> $(date)" | tee -a $log_file
# --------------------------------------------------
# 安装rkhunter验证查杀结果
pkg=rkhunter
echo "[+] install package --> $pkg" | tee -a $log_file
yum install epel-release rkhunter -y
echo "[+] start system scan --> rkhunter -c --skip-keypress" | tee -a $log_file
rkhunter -c --skip-keypress | grep Bill
if [[ ${?} = 0 ]];then
    print_message "Something wrong. For more detail, check /var/log/rkhunter/rkhunter.log." "error"
else
    print_message "All Done." "ok"
fi