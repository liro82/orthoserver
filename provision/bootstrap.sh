#!/bin/bash

# config
app_to_install="git yum-updateonboot httpd mariadb-server mariadb php php-mysql php-gd"
grp_to_install=("")
svc_to_enable="httpd mariadb"

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

# enable required services
systemctl enable $svc_to_enable --now

# setup database
mysql -u root < /vagrant/provision/db_setup.sql

# install backup / restore scripts
mkdir -p /opt/ortholabor/system
cat << EOF > /opt/ortholabor/system/backup_data.sh
#!/bin/bash
#
# backup of data
#

set -e

# variables
dbuser=root
dbname=ortho
sourcedir=/var/www/html
destdir=/vagrant/data/backup
timestring=`date +"%Y%m%d"`

# clean old backups
find \$destdir -type f -mtime +7 -delete

# backup of database data
mysqldump -u \$dbuser --databases \$dbname > \$destdir/dbbackup
gzip \$destdir/dbbackup
mv -f \$destdir/dbbackup.gz \$destdir/dbbackup-\$timestring.sql.gz
logger -t ortho "saved db backup to \$destdir/dbbackup-\$timestring.sql.gz"

# backup of application data
cd \$sourcedir
rm -f \$destdir/appbackup-\$timestring.tgz
tar -zcf \$destdir/appbackup-\$timestring.tgz *
logger -t ortho "saved app backup to \$destdir/appbackup-\$timestring.tgz"
EOF
cat << EOF > /opt/ortholabor/system/restore_data.sh
#!/bin/bash
#
# backup of data
#

set -e

# variables
dbuser=root
dbname=ortho
appdir=/var/www/html
sourcedir=/vagrant/data/restore
timestring=`date +"%Y%m%d"`

# check if appbackup to restore
if ls \$sourcedir/appbackup-* 1> /dev/null 2>&1; then
  rm -rf \$appdir
  mkdir -p \$appdir
  tar -zxf \$sourcedir/appbackup-* -C \$appdir
  mv -f \$sourcedir/appbackup-* /opt/ortholabor
  logger -t ortho "restored app backup"
fi

# check if dbbackup to restore
if ls \$sourcedir/dbbackup-* 1> /dev/null 2>&1; then
  zcat \$sourcedir/dbbackup-* | mysql -u root
  mv -f \$sourcedir/dbbackup-* /opt/ortholabor
  logger -t ortho "restored db backup"
fi
EOF
chmod +x /opt/ortholabor/system/*.sh

# install bootup tasks
cat << EOF > /etc/systemd/system/orthotasks.service
[Unit]
Description=Ortho Tasks
After=mariadb.service vagrant.mount
Before=shutdown.target
RequiresMountsFor=/vagrant

[Service]
ExecStart=/opt/ortholabor/system/restore_data.sh
ExecStop=/opt/ortholabor/system/backup_data.sh
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable orthotasks.service --now