#!/bin/bash
echo "Openpbx installation started... Please Wait..."
exec 1>/var/log/openpbx-setup.log 2>&1
yum update -y
yum install -y http://files.freeswitch.org/freeswitch-release-1-6.noarch.rpm epel-release
yum install -y git alsa-lib-devel autoconf automake bison broadvoice-devel bzip2 curl-devel libdb4-devel e2fsprogs-devel erlang flite-devel g722_1-devel gcc-c++ gdbm-devel gnutls-devel ilbc2-devel ldns-devel libcodec2-devel libcurl-devel libedit-devel libidn-devel libjpeg-devel libmemcached-devel libogg-devel libsilk-devel libsndfile-devel libtheora-devel libtiff-devel libtool libuuid-devel libvorbis-devel libxml2-devel lua-devel lzo-devel mongo-c-driver-devel ncurses-devel net-snmp-devel openssl-devel opus-devel pcre-devel perl perl-ExtUtils-Embed pkgconfig portaudio-devel postgresql-devel python-devel python-devel soundtouch-devel speex-devel sqlite-devel unbound-devel unixODBC-devel wget which yasm zlib-devel libshout-devel libmpg123-devel lame-devel

#Additional Packages for Openpbx

yum -y install libjpeg-devel make ncurses-devel unixODBC-devel gnutls-devel libogg-devel libvorbis-devel curl-devel libtiff-devel kernel kernel-devel-$(uname -r) subversion libgcc libICE libSM libstdc++ bison patch git gcc gcc-c++ autoconf* automake* libtool* wget python zlib-devel libjpeg-devel openssl-devel e2fsprogs-devel sqlite sqlite-devel pcre pcre-devel speex-devel ldns-devel libedit-devel libxml2-devel opus-devel libvpx-devel libidn-devel unbound-devel libuuid-devel lua-devel libsndfile-devel nasm yasm ldns ldns-devel httpd mysql mysql-connector-odbc mariadb-server mariadb-libs mpg123 mpg123-devel flex flex-devel libtermcap-devel cmake perl memcached memcached-devel libmemcached-devel lame-devel libmpg123-devel libvpx2* nano httpd mariadb-server mysql-connector-odbc memcached ghostscript libtiff-devel libtiff-tools at telnet tcpdump lame zip unzip


yum install -y ntp
yum install -y httpd
systemctl enable httpd
systemctl start mariadb
systemctl enable mariadb

INTALK_CODE_FILE=openpbx.io
INTALK_VERSION=19Feb2019
HTTPD_CONF=/etc/httpd/conf/httpd.conf
HTML_FOLDER=/var/www/html
OPENCC_FOLDER=/var/www/html/openpbx
DB_DB=openpbx

php_version=`php -v | grep "PHP 5.6" | cut -d ' ' -f 2`
if [ "$php_version" == "" ]; then
    yum -y remove php*
fi
systemctl restart httpd

yum install -y mysql redis unixODBC lua http
yum install -y  mysql-connector-odbc
yum install -y dos2unix net-tools vim

#install php5.6
yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum -y install yum-utils
yum-config-manager --enable remi-php56
yum -y install php php-mysql php-xml php-mcrypt php-soap php-devel

#install memcached
yum -y install memcached libevent libevent-devel php-pecl-memcache
systemctl restart memcached
systemctl enable memcached

#install Redis
yum -y install epel-release
yum -y install redis php-redis
systemctl restart redis
systemctl enable redis


#install nodejs
curl -sL https://rpm.nodesource.com/setup_8.x | sudo -E bash -
yum install -y nodejs

#enable HTTPS
yum -y install mod_ssl
yum -y install perl-Redis perl-DBI
yum -y install perl-DBD-mysql

#install perl modules
yum -y install perl-ExtUtils*
yum -y install perl-Redis

#install tftp server for Auto config/provision of IP phones
yum -y install tftp
yum -y install tftp-server
yum -y install tftp tftp-server* xinetd*
systemctl enable xinetd
systemctl enable tftp
systemctl restart tftp
systemctl restart xinetd
chmod -R 777 /var/lib/tftpboot/

#Install fsw
cp freeswitch*.tgz /
cd /
tar -xvzf freeswitch*.tgz
cd -
# as source is already copied no need to git clone
# git clone -b v1.8 https://freeswitch.org/stash/scm/fs/freeswitch.git freeswitch
cd /usr/local/src/freeswitch
./bootstrap.sh -j
./configure --enable-portable-binary \
            --with-gnu-ld --with-python --with-erlang --with-openssl \
            --enable-core-odbc-support --enable-zrtp \
            --enable-static-v8 --disable-parallel-build-v8
make
make install
cd -
cd /usr/local/src/freeswitch/libs/esl/
make perlmod-install

#create user freeswitch:daemon
#useradd --system --home-dir /usr/local/freeswitch/ -g daemon freeswitch
#/usr/bin/echo agami@210 | passwd freeswitch --stdin
adduser --shell /sbin/nologin --system --home-dir /usr/local/freeswitch/ -g daemon freeswitch
/usr/bin/echo agami@210 | passwd freeswitch --stdin
chown -R freeswitch:daemon /usr/local/freeswitch/ 

cd -
if [ -f freeswitch.systemctl ]; then
   cp freeswitch.systemctl /etc/init.d/freeswitch
fi

chmod 755 /etc/init.d/freeswitch
systemctl enable freeswitch

sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
systemctl disable firewalld
ln -s /usr/local/freeswitch/bin/fs_cli /usr/bin/fs_cli

#Update HTTPD.Conf settings

sed -i.bak 's/User apache/User freeswitch/g'  $HTTPD_CONF
sed -i.bak 's/Group apache/Group daemon/g'  $HTTPD_CONF
lookafter=$(grep -n '<Directory "'$HTML_FOLDER'' $HTTPD_CONF | head -n 1 | cut -d: -f1)
looktill=$(tail -n +$lookafter $HTTPD_CONF | grep -n "</Directory>" | head -n 1 | cut -d: -f1)
looktill=$(echo `expr $lookafter + $looktill - 1 `)
sed -i ''$lookafter','$looktill's/AllowOverride None/AllowOverride All/g' $HTTPD_CONF
#set openpbx folder as root folder
#sed -i '/DocumentRoot "'$(echo $HTML_FOLDER | sed 's_/_\\/_g')'"/c DocumentRoot "'$(echo $OPENCC_FOLDER | sed 's_/_\\/_g')'"' $HTTPD_CONF
systemctl restart httpd

mysqladmin -u root password 'agami210'

#FreeSwitch Database
mysql -pagami210 -e "CREATE DATABASE freeswitch"
mysql -pagami210 -e "GRANT ALL PRIVILEGES ON freeswitch.* TO openpbx@localhost IDENTIFIED BY 'somepassword'"
mysql -pagami210 -e "flush privileges"

#Update file /etc/odbc.ini to point to App Server DB
cat <<EOF >/etc/odbc.ini
[freeswitch]
Driver   = MySQL
SERVER   = 127.0.0.1
PORT    = 3306
DATABASE = freeswitch
OPTION  = 67108864
Socket   = /var/lib/mysql/mysql.sock
threading=0
MaxLongVarcharSize=65536

[openpbx]
Driver   = MySQL
SERVER   = 127.0.0.1
PORT    = 3306
DATABASE = $DB_DB
OPTION  = 67108864
Socket   = /var/lib/mysql/mysql.sock
threading=0
EOF

date_suffix=`date +%Y%b%d`
if [ -d $OPENCC_FOLDER ]; then
    mv $OPENCC_FOLDER $OPENCC_FOLDER""_$date_suffix -rf
fi
#get OpenPBX code
if [ -f "$INTALK_CODE_FILE""_v""$INTALK_VERSION"".tar.gz" ]; then
    tar -xzf $INTALK_CODE_FILE""_v""$INTALK_VERSION"".tar.gz
    mv Openpbx_Agami $OPENCC_FOLDER -f
fi
#else
    #cd $HTML_FOLDER
    #git clone http://159.65.153.10/PHPProjects/OpenCC.git
    #mv OpenCC openpbx -f
   # cd -

#change permission of freeswitch code
chown freeswitch:daemon /usr/local/freeswitch -R
chmod g+w /usr/local/freeswitch -R

#change permission of OpenCC code
chown freeswitch:daemon $OPENCC_FOLDER -R
chmod g+w $OPENCC_FOLDER -R

#change ownership of php session folder
chown root:daemon /var/lib/php/session /var/lib/php/wsdlcache -R

#update PHP config file to have timezone
sed -i.bak 's/\[PHP]/&\ndate.timezone=Asia\/Brunei/' /etc/php.ini
#if php-shadow extension file available install it
if [ -f phpshadow-extension*.tar ]; then
   tar -xvf phpshadow-extension*.tar
   rm -f /usr/lib64/php/modules/phpshadow.so
   cp phpshadow.so /usr/lib64/php/modules/
   echo "" >> /etc/php.ini
   echo "extension=phpshadow.so" >> /etc/php.ini
fi

#remove default license files and configuration
cd $OPENCC_FOLDER
rm -f core/install/*.text
rm -f resources/config.php
rm -f tools
cd -

if [ -f $OPENCC_FOLDER/format_cdr.conf.xml ]; then
    cp -f $OPENCC_FOLDER/format_cdr.conf.xml /usr/local/freeswitch/conf/autoload_configs/
    chown freeswitch:daemon /usr/local/freeswitch/conf/autoload_configs/format_cdr.conf.xml
fi

echo "OpenPBX installation done successfully......"
