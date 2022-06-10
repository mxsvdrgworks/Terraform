#!/bin/bash
yum -y update
yum -y install httpd
chmod 777 /var/www/html/index.html
cat <<EOF >> /var/www/html/index.html
  <html>
  <h2>Built by Terraform</h2>
  <html>
EOF
sudo service httpd start
chkconfig httpd on
