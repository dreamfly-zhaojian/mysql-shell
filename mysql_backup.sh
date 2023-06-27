#!/bin/bash
export PATH=$PATH:/usr/lib64/qt-3.3/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/app/mysql/bin/

#MySQL Backup Script
#
#周一进行全量备份、其余为基于前一天的增量备份，其中周四是基于周一全备的增量备份
#%w   day of week (0..6); 0 is Sunday
#create user `backup`@`localhost` identified by 'password';
#grant backup_admin,process,reload,select on *.* to `backup`@`localhost`;


BASE_DIR="/data/backup"

MySQL_USER="backup"
MySQL_PASSWORD="password"
MySQL_HOST="localhost"
MySQL_PORT="3307"


APP_NAME=$(basename $0)
APP_DIR=$(dirname $0)
APP_VER="2.2"
version() {
    echo "${APP_NAME} ${APP_VER}"
    exit 1
}

  
#xtrabackup --backup --target-dir=/data/backup/20230525
#xtrabackup --backup --target-dir=$targetDir >> mysql_backup_log_`date "+%Y%m%d%H%M%S"`.log
#xtrabackup --user=xxx --password=xxx --host=xxxx --port=xxx --backup --target-dir=xxxx [--incremental-basedir=xxx]

function full_backup()
{
    log info "开始进行全量备份"
    log info "备份目的地为：$1"
    local targetDir="$1"
    local xtrabackupProcessLog="${targetDir}/xtrabackup_process_log.log"
    xtrabackup --user=${MySQL_USER} --password=${MySQL_PASSWORD} --host=${MySQL_HOST} --port=${MySQL_PORT} \
               --backup --target-dir=$targetDir 2> ${xtrabackupProcessLog}
    log info "全量备份完成"
}

function incr_backup()
{
    log info "开始进行增量备份"
    log info "备份目的地为：$1,基础备份为：$2"
    #xtrabackup --backup --target-dir=/data/backup/20230526 --incremental-basedir=/data/backup/20230525_full
    local targetDir="$1"
    local incrementalBaseDir="$2"
    local xtrabackupProcessLog="${targetDir}/xtrabackup_process_log.log"
    xtrabackup --user=${MySQL_USER} --password=${MySQL_PASSWORD} --host=${MySQL_HOST} --port=${MySQL_PORT} \
               --backup --target-dir=$targetDir --incremental-basedir=$incrementalBaseDir 2> ${xtrabackupProcessLog}
    log info "增量备份完成"
}

function check_backup()
{
    local targetDir="$1"
    local xtrabackupProcessLog="${targetDir}/xtrabackup_process_log.log"
    #local isOK=`cat ${xtrabackupProcessLog} | grep "completed OK!"| wc -l`
    local count=`cat ${xtrabackupProcessLog}| \
                grep -E '[[:digit:]]+[[:space:]][[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}[[:space:]]completed OK!'| \
                wc -l`
    echo "$count"
}

#not used
function calculateBackupLevel()
{
    local backupLevel=$1

    #最近的全量备份和备份
    local latestFullBackup=$(ls -lt ${BASE_DIR}| grep -E "full$" | head -n1 | awk '{print $9}')
    local latestBackup=$(ls -lt ${BASE_DIR}| grep -E "incr$|full$" | head -n1 | awk '{print $9}')

    #Only full backup or no any bakcup
    #[ $latestFullBackup = $latestBackup ] && 

    [ ! -z $latestFullBackup ] && latestFullBackup=${BASE_DIR}/${latestFullBackup}
    [ ! -z $latestBackup ] && latestBackup=${BASE_DIR}/${latestBackup}


    if [ ${backupLevel} -eq 0 ]
    then
        backupLevel=0
    elif [ ${backupLevel} -eq 1 ]
    then
        if ! check_directory $latestFullBackup
        then
            #最近没有备份，执行全量备份
            backupLevel=0
        fi
    elif [ ${backupLevel} -eq 2 ]
    then
        if ! check_directory $latestBackup
        then
            #最近没有备份，执行全量备份
            backupLevel=0
        fi
    fi
    echo "${backupLevel}"
}

# backup_databas ${BACKUP_LEVEL} 
function backup_database
{
    log info "开始进行备份"
    local backupLevel=$1
    local currentTimestamp=$2

    #最近的全量备份和备份
    local latestFullBackup=$(ls -lt ${BASE_DIR}| grep -E "full$" | head -n1 | awk '{print $9}')
    local latestBackup=$(ls -lt ${BASE_DIR}| grep -E "incr$|full$" | head -n1 | awk '{print $9}')

    #Only full backup or no any bakcup
    #[ $latestFullBackup = $latestBackup ] && 

    [ ! -z $latestFullBackup ] && latestFullBackup=${BASE_DIR}/${latestFullBackup}
    [ ! -z $latestBackup ] && latestBackup=${BASE_DIR}/${latestBackup}


    if [ ${backupLevel} -eq 0 ]
    then
        backupLevel=0
    elif [ ${backupLevel} -eq 1 ]
    then
        if ! check_directory $latestFullBackup
        then
            #最近没有备份，执行全量备份
            backupLevel=0
        fi
    elif [ ${backupLevel} -eq 2 ]
    then
        if ! check_directory $latestBackup
        then
            #最近没有备份，执行全量备份
            backupLevel=0
        fi
    fi

    local backupDir=$(mkBackupDir ${BASE_DIR} ${currentTimestamp} ${backupLevel})

    if ! check_directory $backupDir
    then
        log error "备份目录存在问题。备份目的地为:$backupDir"
        exit 1
    fi

    if [ ${backupLevel} -eq 0 ]
    then
        #全量备份
        full_backup $backupDir
    elif [ ${backupLevel} = 1 ]
    then
        if check_directory $latestFullBackup
        then
            #最近有全量备份，执行基于全量的增量备份
            incr_backup $backupDir $latestFullBackup
        else
            #没有全量被备份，执行全量备份
            full_backup $backupDir
        fi
    elif [ ${backupLevel} = 2 ]
    then
        if check_directory $latestBackup
        then
            #最近有备份，执行基于最近的备份，进行增量备份
            incr_backup $backupDir $latestBackup
        else
            #没有全量被备份，执行全量备份
            full_backup $backupDir
        fi
    fi
    local status=$(check_backup $backupDir)
    log info "备份结束" 
    [ $status -eq 1 ] && return 0 || return 1

}


function check_directory()
{
    local directory
    if [ $# -eq 1 ]
    then
        directory=$1
        if [ -d $directory ] 
        then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
    return 1
}

function mkBackupDir()
{
    local baseDir="$1"
    local prefixDirName="$2"_`date -d @${2} +%Y%m%d`
    local backupLevel="$3"
    local fullPath
    if [ $backupLevel -eq 0 ]
    then
        fullPath="$baseDir/${prefixDirName}_full"
    elif  [ $backupLevel -eq 1 ]
    then
        fullPath="$baseDir/${prefixDirName}_incr"
    elif  [ $backupLevel -eq 2 ]
    then
        fullPath="$baseDir/${prefixDirName}_incr"
    else
        exit 1
    fi

    if [ -d ${fullPath} ]
    then
        #目录存在
        flag=$(ls -a $fullPath | wc -l)
        if [ $flag -gt 2 ];then  #
            #echo "${fullPath}目录内除了.和..外还有其他内容"
            exit 1
        fi
    else
        #目录不存在，则创建目录
        mkdir -p ${fullPath}
        #echo "创建目录${fullPath}"
    fi 
    echo ${fullPath}
}

function printCurrentTime()
{
    echo $(date "+%Y-%m-%d %H:%M:%S.%N")
}

usage() {
    echo "Usage: ${APP_NAME} <Options> [arguments]"
    echo ""
    echo "Options:"
    echo "  -h            查看帮助信息"
    echo "  -d ARG(str)   指定备份的目录，默认:/data/backup"
    echo "  -l ARG(str)   指定备份的级别，0：全备；1：基于全量的增量备份；2：基于前一次备份增量备份"
    echo "  -u ARG(str)   指定MySQL用户名，默认:backup"
    echo "  -p ARG(str)   指定MySQL用户的密码，默认：mysql"
    echo "  -P ARG(str)   指定MySQL端口，默认：3306"
    echo "  -s ARG(str)   指定MySQL Socket"
    echo "  -v            查看当前脚本程序版本信息"
    echo ""
    echo "如果遇到bug,请联系TOC"
    exit 1
}
function log() {
    case $1 in
        "info"|"INFO")
            echo -e `date '+%Y-%m-%d %H:%M:%S'`"\t[\e[32m INFO \e[0m] $2"
            ;;
        "error"|"ERROR")
            echo -e `date '+%Y-%m-%d %H:%M:%S'`"\t[\e[31m ERROR \e[0m] $2"
            ;;
        *)
            echo -e `date '+%Y-%m-%d %H:%M:%S'`"\t[\e[32m INFO \e[0m] $2"
    esac
}

function main()
{
    echo "main"
    CURRENT_DATE=$(date +%Y%m%d) 
    CURRENT_TS=`date +%s`
    CURRENT_DAY=`date +%w`

    #BACKUP_LEVEL="0"
    if [ -z "${BACKUP_LEVEL}" ] 
    then
        case ${CURRENT_DAY} in
          1)
            BACKUP_LEVEL="0"
            ;;
          4)
            BACKUP_LEVEL="1"
            ;;
          *)
            BACKUP_LEVEL="2"
            ;;
        esac
    fi

    #log info "当前备份级别为：$BACKUP_LEVEL 级"

    #backup_database ${BACKUP_LEVEL}
    backup_database ${BACKUP_LEVEL} ${CURRENT_TS}
    if [ $? -eq 0 ]
    then
        log info "备份成功"
    else
        log error "备份失败"
    fi
}


while getopts "d:hl::vu:p:P:" OPTION; do
    case ${OPTION} in
        h)
            usage
            ;;
        d)
            BASE_DIR=${OPTARG}
            ;;
        l)
            BACKUP_LEVEL=${OPTARG}
            ;;
        u)
            MySQL_USER=${OPTARG}
            ;;
        p)
            MySQL_PASSWORD=${OPTARG}
            ;;
        P)
            MySQL_PORT=${OPTARG}
            ;;
        v)
            version
            ;;
        \?)
            exit 1
            ;;
    esac
done
log info "备份基目录BASE_DIR=$BASE_DIR"

# call main function
main 


#check_directory ""
#echo $? 
#date -d @1685172808 +%Y%m%d

#Backup directoy demo
#1685172096_20230527_full
#1685172099_20230527_incr
#
#xtrabackup --user=xxx --password=xxx --host=xxxx --port=xxx --backup --target-dir=xxxx [--incremental-basedir=xxx]
# Usasge demo
#     backup.sh -d /data/backup -l 0
#     create incremental backup base on 1685172096_20230527_full
#     backup.sh -d /data/backup -l 0 -b /data/backup/1685172096_20230527_full
#

