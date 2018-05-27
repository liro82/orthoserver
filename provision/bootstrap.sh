#!/bin/bash

# config
app_to_install="git yum-updateonboot"
grp_to_install=("")
local_username="liro"

# update
yum -y install epel-release
yum update -y

# ensure software groups are installed
for ((i=0; i < ${#grp_to_install[@]}; i++)); do
  yum -y groupinstall "${grp_to_install[$i]}"
done

# ensure applications are installed
yum -y install $app_to_install

# setup chrome repo
if [ ! -e /opt/google/chrome ]; then
  yum -y localinstall https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
fi
