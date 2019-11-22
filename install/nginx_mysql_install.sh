#!/bin/sh
base_dir=/data/app
mysql_base_dir=${base_dir}/mysql
soft_dir="/usr/local/src"
PROCESS=$(cat /proc/cpuinfo |grep processor|wc -l)

install_nginx_pre ()
{
    yum -y install jemalloc g++ yasm yasm-devel libXpm-devel libXpm libvpx libvpx-devel pcre-devel openssl-devel zlib-devel tcl git wget library* gcc perl gzip tar gcc-c++
}

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

mk_nginx_dir ()
{
    MKDIR ${app_dir}/nginx/lock/
    MKDIR ${app_dir}/nginx/conf/vhost/
    MKDIR ${log_dir}/app/
    MKDIR ${www_dir}
    MKDIR ${script_dir}
    MKDIR ${backup_dir}/nginx/
    MKDIR ${soft_dir}
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


install_nginx()
{
    echo "INSTALL nginx ................................................"
    install_date_def
    groupadd -r www
    useradd -r -g www -s /bin/false -M www
    tar_media nginx-1.7.10.tar.gz
    cd ${soft_dir}/nginx-1.7.10
    ./configure \
    --prefix=${app_dir}/nginx \
    --sbin-path=${app_dir}/nginx/sbin/nginx \
    --conf-path=${app_dir}/nginx/conf/nginx.conf \
    --error-log-path=${log_dir}/nginx/error.log \
    --http-log-path=${log_dir}/nginx/access.log \
    --pid-path=${app_dir}/nginx/run/nginx.pid \
    --lock-path=${app_dir}/nginx/lock/nginx.lock \
    --user=www \
    --group=www \
    --with-http_ssl_module \
    --with-http_flv_module \
    --with-http_stub_status_module \
    --with-http_gzip_static_module \
    --with-google_perftools_module \
    --http-client-body-temp-path=/var/tmp/nginx/client/ \
    --http-proxy-temp-path=/var/tmp/nginx/proxy/ \
    --http-fastcgi-temp-path=/var/tmp/nginx/fcgi/ \
    --http-uwsgi-temp-path=/var/tmp/nginx/uwsgi \
    --http-scgi-temp-path=/var/tmp/nginx/scgi \
    --with-pcre  > /tmp/install_nginx_${install_date}.log 2>&1
    if [ $? -ne 0 ];then
        echo "configure with error ,see log  /tmp/install_nginx_${install_date}.log"
        exit $?
    else
        make > /tmp/install_make_nginx_${install_date}.log 2>&1
        make install > /tmp/install_makeinstall_nginx_${install_date}.log 2>&1
        if [ $? -ne 0 ];then
            echo "make or make install with error ,see log /tmp/install_makeinstall_nginx_${install_date}.log"
            exit $?
        fi
    fi
    MKDIR ${app_dir}/nginx/tmp/tcmalloc
    chmod 0777 ${app_dir}/nginx/tmp/
    chmod 0777 ${app_dir}/nginx/tmp/tcmalloc
    \cp ${soft_dir}/nginx.conf ${app_dir}/nginx/conf/
    \cp ${soft_dir}/demo.conf.default ${app_dir}/nginx/conf/vhost/
    \cp ${soft_dir}/nginx /etc/init.d/
    \cp ${soft_dir}/nginx_cut_log.sh ${script_dir}/
    ln -s  ${app_dir}/nginx/sbin/nginx  /usr/sbin/
    nginx_cut=`grep "nginx_cut_log.sh" /var/spool/cron/root |wc -l`
    if [ $nginx_cut -eq 0 ];then
        echo "0 0 * * *  /bin/bash  ${script_dir}/nginx_cut_log.sh" >> /var/spool/cron/root
    fi
    #    chown -R www.www /caimiao/www
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
    'nginx')
        mk_nginx_dir
        install_nginx_pre
        down_nginx_soft
        install_gpertools
        install_nginx
        exit $?
    ;;
    *)
        echo  "Usage: $0 {mysq|nginx}"
        exit 2
    ;;
esac
