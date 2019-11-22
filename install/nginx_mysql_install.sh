#!/bin/sh
base_dir=/data/app
mysql_base_dir=${base_dir}/mysql
soft_dir="/usr/local/src"
PROCESS=$(cat /proc/cpuinfo |grep processor|wc -l)


install_mysql_pre ()
{
    yum -y install wget cmake make library* g++ kdelibs5-dev libncurses5-dev gcc perl gzip tar ncurses-devel zlib-devel libxml2-devel zlib-devel pcre-devel libaio-devel openssl-devel gcc-c++ bison git
}

MKDIR ()
{
    fname=${1}
    if [ ! -d "$fname" ];then
        mkdir -p $fname
    fi
}


mk_mysql_dir ()
{
    MKDIR ${mysql_base_dir}
    MKDIR ${log_dir}/mysql/
    MKDIR ${mysql_base_dir}/data
    MKDIR ${backup_dir}/mysql
}


down_mysql_soft()
{
    wget $PASS -NP ${soft_dir} https://github.com/percona/percona-server/archive/Percona-Server-5.7.28-31.zip
    git clone https://github.com/arrow2012/ops-config.git ${soft_dir}/ops-config
}


check_exists () {
    fname=$1
    if [ ! -f ${soft_dir}/$fname ]; then
        echo  "$fname not found in ${soft_dir}."
        exit 2
    fi
}

tar_media () {
    fname=$1
    check_exists $fname
    tar -xf ${soft_dir}/$fname -C ${soft_dir}
}


install_mysql()
{
    echo "Ready to install mysql server ......"
    install_date_def
    install_mysql_pre
    cd ${soft_dir}
    /usr/bin/unzip Percona-Server-5.7.28-31.zip
    cd percona-server-Percona-Server-5.7.28-31/
    echo "Start to cmake mysql server ......"
    cmake -DCMAKE_INSTALL_PREFIX=${mysql_base_dir} \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_CONFIG=mysql_release \
    -DWITH_EMBEDDED_SERVER=OFF \
    -DWITH_PAM=ON \
    -DMYSQL_UNIX_ADDR=${mysql_base_dir}/mysql.sock\
    -DDEFAULT_CHARSET=utf8mb4 \
    -DDEFAULT_COLLATION=utf8mb4_general_ci \
    -DWITH_EXTRA_CHARSETS=all \
    -DWITH_MYISAM_STORAGE_ENGINE=1 \
    -DWITH_INNOBASE_STORAGE_ENGINE=1 \
    -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
    -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
    -DWITH_MEMORY_STORAGE_ENGINE=1 \
    -DWITH_READLINE=1 \
    -DENABLED_LOCAL_INFILE=1 \
    -DWITH_ZLIB=system \
    -DWITH_SSL=system >  /tmp/install_cmake_mysql_${install_date}.log 2>&1
    if [ $? -ne 0 ];then
        echo "cmake mysql with error ,see log  /tmp/install_cmake_mysql_${install_date}.log"
        exit $?
    else
        echo "cmake successs ......"
        echo "start to make install mysql server ......"
        make -j${PROCESS} > /tmp/install_make_mysql_${install_date}.log 2>&1
        if [ $? -ne 0 ];then
            echo "make with error ,see log /tmp/install_make_mysql_${install_date}.log"
            exit $?
        fi
        make install > /tmp/install_makeinstall_mysql_${install_date}.log 2>&1
        if [ $? -ne 0 ];then
            echo "make install with error ,see log /tmp/install_makeinstall_mysql_${install_date}.log"
            exit $?
        fi
    fi
    \cp ${soft_dir}/ops-config/mysql/my.cnf /etc/
    \cp -fr ${soft_dir}/ops-config/mysql/my.cnf ${mysql_base_dir}/etc/
    groupadd mysql
    useradd -M -s /sbin/nologin -r -g mysql mysql
    cd ${mysql_base_dir}/
    chown -R mysql.mysql ../mysql
    scripts/mysql_install_db --user=mysql --defaults-file=/etc/my.cnf  > /tmp/mysql_install_db_${install_date}.log 2>&1
    if [ $? -ne 0 ];then
        echo "mysql_install_db with error ,see log /tmp/mysql_install_db_${install_date}.log"
        exit $?
    fi
    \cp -fr support-files/mysql.server /etc/init.d/mysqld
    chmod +x /etc/init.d/mysqld
    cat > /lib/systemd/system/mysqld.service < EOF
    [Unit]
    Description=MySQL Server
    After=network.target
    After=syslog.target
    [Install]
    WantedBy=multi-user.target
    [Service]
    User=root
    Group=root
    Type=forking
    TimeoutSec=0
    PermissionsStartOnly=true
    ExecStart=/etc/init.d/mysqld start
    ExecStop=/etc/init.d/mysqld stop
    LimitNOFILE=1048576
    Restart=on-failure
    RestartPreventExitStatus=1
    PrivateTmp=false
    EOF
    systemctl daemon-reload
    systemctl enable mysqld
    echo "Susscess to install mysql server "
    systemctl start mysqld
    echo "Begin to change mysql server password for root ,default password is " mysql ".... "
    ${app_dir}/mysql/bin/mysqladmin -u root password "mysql"
}

export PATH=/usr/bin:$PATH
case "$1" in
    'mysql')
        mk_mysql_dir
        down_mysql_soft
        install_mysql_pre
        install_mysql
        exit $?
    ;;
    *)
        echo  "Usage: $0 {mysq}"
        exit 2
    ;;
esac
