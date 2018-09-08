#!/bin/bash
config=/etc/seccubus/config.xml
dbserver=$(sed -n -e '/<host>/ s/.*<host>\(.*\)<\/host>/\1/p' $config)
dbname=$(sed -n -e '/<database>/ s/.*<database>\(.*\)<\/database>/\1/p' $config)
dbuser=$(sed -n -e '/<user>/ s/.*<user>\(.*\)<\/user>/\1/p' $config)
password=$(sed -n -e '/<password>/ s/.*<password>\(.*\)<\/password>/\1/p' $config)
mysql -h $dbserver -u $dbuser -p$password $dbname < <(cat /opt/seccubus/db/structure_v11.mysql /opt/seccubus/db/data_v11.mysql)
test $? -ne 0 && { echo "Error loading database information."; exit 1; }
echo "Please set the password for account: admin"
seccubus_passwd -u admin
