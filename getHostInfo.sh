#!/bin/bash
export PATH=$PATH:/usr/sbin/:/sbin/:/bin
function getHostname()
{
    echo `hostname`
}

#获取主IP
#不是虚拟IP
function getHostIP()
{
    #ifconfig | grep -E "^eth|^bond|^em|^ens" 
    local activeNic=($(ifconfig | grep -E "^eth|^bond|^em|^ens"|awk '{print $1}'|awk -F':' '{print $1}'|sort|uniq))
    local mainIP
    local tmpIP
    for nic in ${activeNic[*]}
    do
        tmpIP=`ip addr show dev $nic | grep inet| grep -vE "inet6|secondary"|awk '{print $2}'|awk -F'/' '{print $1}'`
        [ ! -z "$tmpIP" ] && mainIP="${tmpIP}" && break
        #[ -z "$tmpIP" ] && break || mainIP="${tmpIP}"
        #echo ${nic}:${mainIP}
    done
    echo ${mainIP}
}
function getHostIPAndMac()
{
    local activeNic=($(ifconfig | grep -E "^eth|^bond|^em|^ens"|awk '{print $1}'|awk -F':' '{print $1}'|sort|uniq))
    local IP
    local ethName
    local macAddr

    local tmpIP
    for nic in ${activeNic[*]}
    do
        tmpIP=`ip addr show dev $nic | grep inet| grep -vE "inet6|secondary"|awk '{print $2}'|awk -F'/' '{print $1}'`
        #拿到了IP地址之后获取IP对应的网卡名称和MAC地址
        #否则，忽略；继续下一次循环
        #[ ! -z "$tmpIP" ] && IP="${tmpIP}" && break
        if [ ! -z "$tmpIP" ]
        then
            IP="$tmpIP"
            ethName=${nic}
            macAddr=$(ip addr show dev $nic | grep "link/ether"|awk '{print $2}')
            break
        fi
    done
    local netInfo=("$IP" "$ethName" "$macAddr")
    echo ${netInfo[*]}
    
}

#返回对象数组
function getHostMacInfo()
{
    local activeNic=($(ifconfig | grep -E "^eth|^bond|^em|^ens"|awk '{print $1}'|awk -F':' '{print $1}'|sort|uniq))
    local mac
    local i=`expr ${#activeNic[*]} - 1`
    local j=0
    echo '['
    for nic in ${activeNic[*]}
    do
        mac=$([ -f /sys/class/net/${nic}/bonding_slave/perm_hwaddr ] 2>/dev/null && \
           cat /sys/class/net/${nic}/bonding_slave/perm_hwaddr                   || \
           cat /sys/class/net/${nic}/address)  
        echo "{\"name\":\"$nic\",\"mac\":\"$mac\"}"
        if [ $j -ne $i ]
        then
            echo ","
        fi
        j=`expr $j + 1`
    done
    echo ']'
}
function getHostIPList()
{
    local ipList
    local i=0
    ipList=($(ip addr show | grep inet| grep -vE "inet6|127.0.0.1"|awk '{print $2}'|awk -F'/' '{print $1}'))
    #echo ${ipList[*]}
    #echo "i=$i"
    i=`expr ${#ipList[*]} - 1`
    echo -n "["
    local j=0
    for ip in ${ipList[*]}
    do
        echo -n "\"${ip}\""
        if [ $i -ne $j ]
        then
            echo ","
        fi
        j=`expr $j + 1`
    done
    echo -n "]"
}

function getOSRelease()
{
    local osRelease
    local isCentOS=`cat /etc/redhat-release | grep -i centos|wc -l`
    local isRedHat=`cat /etc/redhat-release | grep -iE "red.*hat.*"|wc -l`
    if [ ${isCentOS} -gt 0 ]
    then
        osRelease='CentOS'
    elif [ ${isRedHat} -gt 0 ]
    then
        osRelease='RHEL'
    else
        osRelease='UNKNWON'
    fi
    echo ${osRelease}
}
function getOSVersion()
{
    local versionDetail=`awk '{print $(NF-1)}' /etc/redhat-release`
    local majorVersion=$(echo ${versionDetail}|awk -F. '{print $1}')
    local minorVersion=$(echo ${versionDetail}|awk -F. '{print $2}')
    local versionList=(${majorVersion} ${minorVersion} ${versionDetail})
    echo ${versionList[*]}
}

function getCpuInfo2()
{
    local cpuCount=$(cat /proc/cpuinfo | grep "physical id"|sort|uniq|wc -l)
    local cpuCores=$(cat /proc/cpuinfo | grep "processor"| wc -l)
    local cpuModel=$(cat /proc/cpuinfo | grep "model name"|tail -n1|awk -F':' '{print $2}'|sed 's/^[ ]*//g')
    local cpuCacheSize=$(cat /proc/cpuinfo | grep "cache size"|tail -n1|awk -F':' '{print $2}'|sed 's/^[ ]*//g')
    local cpuInfo=(${cpuCount} ${cpuCores} "${cpuModel}" "${cpuCacheSize}")
    echo ${cpuInfo[*]}
}
function getCpuInfo()
{
    local cpuCount=$(cat /proc/cpuinfo | grep "physical id"|sort|uniq|wc -l)
    local cpuCores=$(cat /proc/cpuinfo | grep "processor"| wc -l)
    local cpuModel=$(cat /proc/cpuinfo | grep "model name"|tail -n1|awk -F':' '{print $2}'|sed 's/^[ ]*//g')
    local cpuCacheSize=$(cat /proc/cpuinfo | grep "cache size"|tail -n1|awk -F':' '{print $2}'|sed 's/^[ ]*//g')
    local cpuInfo="${cpuCount}|${cpuCores}|${cpuModel}|${cpuCacheSize}"
    echo ${cpuInfo}
}

#对容量进行计算
function formatSize()
{
    local n="$1"
    local res
    if [ "$n" -gt 0 ] 2> /dev/null
    then
       res="$n"  
    else
        res="$n"
    fi
    echo $res
}

function getMemoryInfo()
{
    local memoryTotal=$(cat /proc/meminfo | grep MemTotal|awk '{print $2}')
    local swapTotal=$(cat /proc/meminfo | grep SwapTotal|awk '{print $2}')
    local memoryInfo=(${memoryTotal} ${swapTotal})
    echo ${memoryInfo[*]}


#local sshPort=

}

function getPartitions()
{
    

    #local partition=`df -hTl | grep -vE "tmpfs|^Filesystem"|awk '{print $1}'`
    local partitions=($(df -hTlP | grep -E "xfs|ext4|ext3"|awk '{print $1}'))
    local i=0
    local j=`expr ${#partitions[*]} - 1`
    echo "["
    #for p in $(df -hTlP | grep -E "xfs|ext4|ext3"|awk '{print $1}')
    for p in ${partitions[*]}
    do
        x=($(df -hTlP | grep -E "^${p}"))
        echo "{\"partition\":\"${x[0]}\",\"fsType\":\"${x[1]}\",\"size\":\"${x[2]}\",\"mountPoint\":\"${x[6]}\"}"
        if [ $i -ne $j ]; then echo "," ;fi
        i=`expr $i + 1`
    done
    echo "]"
}

function getUpTime()
{
    #local t=`uptime|head -n1|awk '{print $3" " $4}'|sed  's/,//g'`
    local t=`uptime|awk -F',' '{print $1}'|awk -F'up' '{print $2}'|sed 's/^[ ]*//g'`
    echo $t
}
kernel=`uname -r`
os=`uname`

function myPrint()
{
    if [ $# -ne 3 ]
    then
        "myPrint function parameter wrong."   
        exit 1
    fi
    local key="$1"
    local value="$2"
    local flag="$3"
    if [ $flag -eq 1 ]
    then
        [ ${value} -gt 0 ] 2>>/dev/null && echo "\"${key}\":${value}," ||echo "\"${key}\":\"${value}\","
    else
        [ ${value} -gt 0 ] 2>>/dev/null && echo "\"${key}\":${value}" ||echo "\"${key}\":\"${value}\""
    fi
}

function getHostFCAdapterInfo()
{
    local fcAdapterInfo
    local fcAdapterInfoDir="/sys/class/fc_host"
    if [ ! -d "${fcAdapterInfoDir}" ]
    then
        local fcAdapterInfo="[]"
        echo "${fcAdapterInfo}"
        exit
    fi
   
    local fcAdapterList=(`ls ${fcAdapterInfoDir}`)
    local wwid
    local portState
    local portSpeed
    local i="${#fcAdapterList[*]}"
    local j=1
    echo "["
    for adapter in ${fcAdapterList[*]}
    do
        wwid=$(cat "${fcAdapterInfoDir}/${adapter}/port_name")
        portState=$(cat "${fcAdapterInfoDir}/${adapter}/port_state")
        portSpeed=$(cat "${fcAdapterInfoDir}/${adapter}/speed")
        echo -n "{\"name\":\"${adapter}\",\"wwid\":\"${wwid}\",\"state\":\"${portState}\",\"speed\":\"${portSpeed}\"}"
        if [ $i -ne $j ];then echo ","; else echo ""; fi
        j=`expr $j + 1`
    done
    echo "]"

}

#myPrint "IP" `getHostIP`
function getHostInfo()
{
    echo "{"
    #local ipAddr=`getHostIP`
    #echo "\"IP\":\"$ipAddr\","
    #myPrint "IP" "$ipAddr" 1
    local netInfo=(`getHostIPAndMac`)
    myPrint "IP" "${netInfo[0]}" 1
    myPrint "ethName" "${netInfo[1]}" 1
    myPrint "macAddr" "${netInfo[2]}" 1
    local hostName=$(getHostname)
    #echo "\"hostname\":\"$hostName\","
    myPrint "hostname" "$hostName" 1
    #local cpuInfo=($(getCpuInfo2))
    #myPrint "cpuCount" "${cpuInfo[0]}" 1
    #myPrint "cpuCores" "${cpuInfo[1]}" 1
    #myPrint "cpuModel" "${cpuInfo[2]}" 1
    #myPrint "cpuCacheSize" "${cpuInfo[3]}" 1
    cpuInfo=$(getCpuInfo)
    cpuCount=$(echo $cpuInfo|awk -F'|' '{print $1}')
    cpuCores=$(echo $cpuInfo|awk -F'|' '{print $2}')
    cpuModel=$(echo $cpuInfo|awk -F'|' '{print $3}')
    cpuCacheSize=$(echo $cpuInfo|awk -F'|' '{print $4}')
    myPrint "cpuCount" "${cpuCount}" 1
    myPrint "cpuCores" "${cpuCores}" 1
    myPrint "cpuModel" "${cpuModel}" 1
    myPrint "cpuCacheSize" "${cpuCacheSize}" 1

    local memoryInfo=($(getMemoryInfo))
    myPrint "totalMemory" "${memoryInfo[0]}" 1
    myPrint "totalSwap" "${memoryInfo[1]}" 1
    local startupTime=`getUpTime`
    myPrint "startupTime" "${startupTime}" 1
    myPrint "kernel" "$kernel" 1
    myPrint "os" "$os" 1
    local osRelease=$(getOSRelease)
    myPrint "osRelease" "${osRelease}" 1
    local versionList=($(getOSVersion))
    myPrint "osMajorVersion" "${versionList[0]}" 1
    myPrint "osMinorVersion" "${versionList[1]}" 1
    myPrint "osVersionDetail" "${versionList[2]}" 1
    local ipList=$(getHostIPList)
    #myPrint "ipList" "${ipList}" 1
    echo "\"ipList\":${ipList},"
    local macList=`getHostMacInfo`
    echo "\"macList\":${macList},"
    local fcAdapter=$(getHostFCAdapterInfo)
    echo "\"fcAdapter\":${fcAdapter},"
    local partitionList=`getPartitions`
    #myPrint "partitions" "${partitionList}" 1
    echo "\"partitions\":${partitionList},"
    echo "\"timestamp\":\"$(date "+%Y-%m-%d %H:%M:%S")\""
    echo "}"
}

function main()
{
    local hostInfo=`getHostInfo`
    #local jsonStr="'"$hostInfo"'"
    local hostInfoJsonFile="/tmp/hostInfo_$(date +%Y%m%d%H%M%S)_$(date +%s).json"
    #local IP=$(echo $hostInfo | jq -r '.IP')
    local key="host/$(getHostIP)"
    echo $hostInfo | jq . 
    echo $hostInfo > $hostInfoJsonFile

    
   curl --request PUT --data @${hostInfoJsonFile} http://10.129.25.14:8500/v1/kv/${key}
   rm -f $hostInfoJsonFile

#getHostMacInfo
#getCpuInfo
#getHostFCAdapterInfo
}
main
