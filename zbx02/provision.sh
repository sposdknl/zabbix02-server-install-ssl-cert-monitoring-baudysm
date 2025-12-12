#!/bin/bash

set -e

DB_PASSWORD="StrongPassword"
ZBX_HOSTNAME="$(hostname)"
ZBX_SERVER_IP="127.0.0.1"

echo "🔄 Aktualizuji systém..."
apt update && apt upgrade -y

echo "📦 Instalace Apache + PHP..."
apt install -y apache2 php libapache2-mod-php php-mysql php-xml php-bcmath php-mbstring

echo "🗄️ Instalace MariaDB..."
apt install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb

echo "🛠️ Vytvářím databázi Zabbix..."
mysql -uroot <<EOF
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "📥 Stahuji Zabbix repozitář..."
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1+debian12_all.deb
dpkg -i zabbix-release_7.0-1+debian12_all.deb
apt update

echo "📦 Instalace Zabbix serveru, frontend a agenta2..."
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent2

echo "📄 Importuji databázové schéma..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p${DB_PASSWORD} zabbix

echo "⚙️ Nastavuji Zabbix server..."
sed -i "s/# DBPassword=/DBPassword=${DB_PASSWORD}/" /etc/zabbix/zabbix_server.conf

echo "🌐 Vytvářím konfigurační soubor pro webové rozhraní..."
cat <<EOF > /etc/zabbix/web/zabbix.conf.php
<?php
global \$DB;
\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = 'zabbix';
\$DB['PASSWORD'] = '${DB_PASSWORD}';
\$ZBX_SERVER     = '${ZBX_SERVER_IP}';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'Zabbix Server';
\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
?>
EOF

echo "🔁 Restartuji služby..."
systemctl restart zabbix-server zabbix-agent2 apache2
systemctl enable zabbix-server zabbix-agent2 apache2

echo "✅ Instalace dokončena. Webové rozhraní je dostupné na: http://$(hostname -I | awk '{print $1}')/zabbix"
echo "🔐 Přihlašovací údaje: Admin / zabbix"
