
#!/bin/bash

apt update -y
apt upgrade -y
apt install -y apache
apt install -y php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip 
apt-get install -y redis-tools



wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cd wordpress
cp wp-config-sample.php wp-config.php


DB_NAME="wordpress"
DB_USER="wordpres"
PASS="wordpres"
RDS_ENDPOINT="terraform-20241108135040719500000004.cfkumqm66tqo.eu-central-1.rds.amazonaws.com"

sed -i "s/define( 'DB_NAME', 'database_name_here' );/define( 'DB_NAME', '$DB_NAME' );/" wp-config.php
sed -i "s/define( 'DB_USER', 'username_here' );/define( 'DB_USER', '$DB_USER' );/" wp-config.php
sed -i "s/define( 'DB_PASSWORD', 'password_here' );/define( 'DB_PASSWORD', '$PASS' );/" wp-config.php
sed -i "s/define( 'DB_HOST', 'localhost' );/define( 'DB_HOST', '$RDS_ENDPOINT' );/" wp-config.php


cp -r /home/ubuntu/wordpress /var/www/html/
chown -R www-data:www-data /var/www/html/wordpress

touch nano /etc/apache2/sites-available/wordpress.conf

cat <<EOL > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
ServerAdmin webmaster@localhost
ServerName 35.159.17.174
ServerAlias www.your_domain.com
DocumentRoot /var/www/html/wordpress
ErrorLog ${APACHE_LOG_DIR}/error.log
CustomLog ${APACHE_LOG_DIR}/access.log combined

<Directory /var/www/html/wordpress/>
AllowOverride All
</Directory>
</VirtualHost>
EOL

a2dissite 000-default.conf
a2ensite wordpress.conf
a2enmod rewrite
systemctl restart apache2
