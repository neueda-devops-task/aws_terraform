#!/bin/bash

yum -y update
yum install -y php php-dom php-gd php-mysql
cd /tmp
wget https://wordpress.org/wordpress-5.1.1.tar.gz
mount -a
tar xzvf /tmp/wordpress-5.1.1.tar.gz --strip 1 -C /var/www/html
rm /tmp/latest.tar.gz
chown -R apache:apache /var/www/html
systemctl enable httpd
sed -i 's/#ServerName www.example.com:80/ServerName www.myblog.com:80/' /etc/httpd/conf/httpd.conf
sed -i 's/ServerAdmin root@localhost/ServerAdmin admin@myblog.com/' /etc/httpd/conf/httpd.conf
cd /var/www/html
chmod -R 755 wp-content
chown -R apache:apache wp-content
systemctl start httpd
chkconfig httpd on