#!/bin/bash
mkdir -p /data/ajenti
mkdir -p /data/mysqldump
mkdir -p /data/mysql
mkdir -p /data/sites
mkdir -p /data/nginx/sites-conf
mkdir -p /data/redis/db
mkdir -p /data/php/5.6/fpm/pool.d
mkdir -p /data/php/7.0/fpm/pool.d
mkdir -p /data/php/7.1/fpm/pool.d
chown -R www-data:www-data /data/sites

mv -n /etc/ajenti/** /data/ajenti
rm -rf /etc/ajenti
ln -sdf /data/ajenti /etc/ajenti 

rm -rf /etc/nginx
ln -sdf /data/nginx /etc/nginx

mv -n /etc/redis/** /data/redis
mv -n /etc/php/5.6/fpm/pool.d/*.conf /data/php/5.6/fpm/pool.d
mv -n /etc/php/7.0/fpm/pool.d/*.conf /data/php/7.0/fpm/pool.d
mv -n /etc/php/7.1/fpm/pool.d/*.conf /data/php/7.1/fpm/pool.d

# load php before supervisor start
service php5.6-fpm start
service php7.0-fpm start
service php7.1-fpm start

# make sure supervisor service is running
# so it start ajenti
service supervisor start
service ajenti start

echo $MYSQL_ADMIN_PASSWORD > /root/dbpass.txt

VOLUME_HOME="/data/mysql"
export TERM=linux
if [[ ! -d $VOLUME_HOME/mysql ]]; then
    
    echo "=> An empty or uninitialized MySQL volume is detected in $VOLUME_HOME"
    echo "=> Installing MySQL ..."
    mysql_install_db --user=mysql

    echo "=> Reconfiguring MySQL ..."
    TERM=linux dpkg-reconfigure mysql-server
    PASSWD="$(grep -m 1 --only-matching --perl-regex "(?<=password \= ).*" /etc/mysql/debian.cnf)"
    /usr/bin/mysqld_safe &
    sleep 5s
    echo "=>executing   GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$PASSWD';"
    echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$PASSWD';" | mysql

    /usr/bin/mysqladmin -u root password $MYSQL_ROOT_PASSWORD
    
    killall mysqld    
    sleep 5s
    
    echo "=> Done!"  
else
    echo "=> Using an existing volume of MySQL"
    echo "=> Updating root passwords"
    PASSWD="$(grep -m 1 --only-matching --perl-regex "(?<=password \= ).*" /etc/mysql/debian.cnf)"

    /usr/bin/mysqld_safe &
    sleep 5s

    /usr/bin/mysqladmin -u root password $MYSQL_ROOT_PASSWORD
    
    echo "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$PASSWD');" |mysql -u root --password=$MYSQL_ROOT_PASSWORD

    killall mysqld    
    sleep 5s
fi

# install phpMyAdmin if not exists
if [[ ! -d /data/sites/phpMyAdmin ]]; then
    echo "installing phpMyAdmin" 1>&2
    curl -s -o /tmp/phpMyAdmin-4.6.5.1-all-languages.tar.gz https://files.phpmyadmin.net/phpMyAdmin/4.6.5.1/phpMyAdmin-4.6.5.1-all-languages.tar.gz
    tar -zxvf /tmp/phpMyAdmin-4.6.5.1-all-languages.tar.gz -C /opt/
    mv /opt/phpMyAdmin-4.6.5.1-all-languages /data/sites/phpMyAdmin
fi

chown -R mysql:mysql "$VOLUME_HOME"

# start mysql
service mysql start

exec "$@"