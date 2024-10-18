!/bin/bash

GLPI_VERSION="10.0.16"
DOMAIN_IP=""
SLQROOTPWD="pmvzVT453"
SQLGLPIPWD="mvzVT453"
PHP_VERSION="8.1"
# Update and upgrade packages
apt update && apt upgrade -y
apt install apache2


sudo apt install -y apache2 \
    php \
    php-{apcu,cli,common,curl,gd,imap,ldap,mysql,xmlrpc,xml,mbstring,bcmath,intl,zip,redis,bz2} \
    libapache2-mod-php \
    php-soap \
    php-cas \
    mariadb-server


# Configure MySQL timezone info
#mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p'mvzVT453'   >>>>>>>> !!!!!!!!!!!!!!!

# Secure MySQL installation
mysql_secure_installation

# Create GLPI database and user
# Set the root password
mysql -e "UPDATE mysql.user SET Password = PASSWORD('$SLQROOTPWD') WHERE User = 'root'"
# Remove anonymous user accounts
mysql -e "DELETE FROM mysql.user WHERE User = ''"
# Disable remote root login
mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
# Remove the test database
mysql -e "DROP DATABASE test"
# Reload privileges
mysql -e "FLUSH PRIVILEGES"
# Create a new database
mysql -e "CREATE DATABASE glpi"
# Create a new user
mysql -e "CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD'"
# Grant privileges to the new user for the new database
mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost'"
# Reload privileges
mysql -e "FLUSH PRIVILEGES"

# Initialize time zones datas
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p'$SLQROOTPWD' mysql
#Ask tz
dpkg-reconfigure tzdata
systemctl restart mariadb

sleep 1
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi_user'@'localhost'"


# Download and prepare GLPI files
cd /var/www/html
wget https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz



tar -xvzf glpi-${GLPI_VERSION}.tgz

# Configure downstream.php for GLPI
cat <<EOL > /var/www/html/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
?>
EOL

# Move GLPI directories
mv /var/www/html/glpi/config /etc/glpi
mv /var/www/html/glpi/files /var/lib/glpi
mv /var/lib/glpi/_log /var/log/glpi

# Create local_define.php configuration
cat <<EOL > /etc/glpi/local_define.php
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_DOC_DIR', GLPI_VAR_DIR);
define('GLPI_CRON_DIR', GLPI_VAR_DIR . '/_cron');
define('GLPI_DUMP_DIR', GLPI_VAR_DIR . '/_dumps');
define('GLPI_GRAPH_DIR', GLPI_VAR_DIR . '/_graphs');
define('GLPI_LOCK_DIR', GLPI_VAR_DIR . '/_lock');
define('GLPI_PICTURE_DIR', GLPI_VAR_DIR . '/_pictures');
define('GLPI_PLUGIN_DOC_DIR', GLPI_VAR_DIR . '/_plugins');
define('GLPI_RSS_DIR', GLPI_VAR_DIR . '/_rss');
define('GLPI_SESSION_DIR', GLPI_VAR_DIR . '/_sessions');
define('GLPI_TMP_DIR', GLPI_VAR_DIR . '/_tmp');
define('GLPI_UPLOAD_DIR', GLPI_VAR_DIR . '/_uploads');
define('GLPI_CACHE_DIR', GLPI_VAR_DIR . '/_cache');
define('GLPI_LOG_DIR', '/var/log/glpi');
?>
EOL

# Set folder and file permissions
chown root:root /var/www/html/glpi/ -R
chown www-data:www-data /etc/glpi -R
chown www-data:www-data /var/lib/glpi -R
chown www-data:www-data /var/log/glpi -R
chown www-data:www-data /var/www/html/glpi/marketplace -Rf
find /var/www/html/glpi/ -type f -exec chmod 0644 {} \;
find /var/www/html/glpi/ -type d -exec chmod 0755 {} \;
find /etc/glpi -type f -exec chmod 0644 {} \;
find /etc/glpi -type d -exec chmod 0755 {} \;
find /var/lib/glpi -type f -exec chmod 0644 {} \;
find /var/lib/glpi -type d -exec chmod 0755 {} \;
find /var/log/glpi -type f -exec chmod 0644 {} \;
find /var/log/glpi -type d -exec chmod 0755 {} \;

# Restart Apache2
systemctl restart apache2

# Create Apache virtual host for GLPI
cat <<EOL > /etc/apache2/sites-available/glpi.conf
<VirtualHost *:80>
    ServerName ${DOMAIN_IP}
    DocumentRoot /var/www/html/glpi/public
    <Directory /var/www/html/glpi/public>
        Require all granted
        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOL

# Enable GLPI site
a2enmod rewrite   
a2ensite glpi.conf
systemctl restart apache2

# Set up PHP.ini configurations
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 20M/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/post_max_size = .*/post_max_size = 20M/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/max_execution_time = .*/max_execution_time = 60/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/max_input_vars = .*/max_input_vars = 5000/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s|;session.cookie_httponly =.*|session.cookie_httponly = On|" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s|;date.timezone =.*|date.timezone = America/Sao_Paulo|" /etc/php/${PHP_VERSION}/apache2/php.ini

# Restart Apache to apply changes
systemctl restart apache2

echo "LAMP stack and GLPI installed and configured successfully."
