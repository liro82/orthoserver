#!/bin/bash

# config
app_to_install="git yum-updateonboot httpd mariadb-server mariadb php php-mysql php-gd"
grp_to_install=("")

# update
yum -y install epel-release
yum update -y

# ensure software groups are installed
for ((i=0; i < ${#grp_to_install[@]}; i++)); do
  yum -y groupinstall "${grp_to_install[$i]}"
done

# ensure applications are installed
yum -y install $app_to_install

# configure firewall
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload
