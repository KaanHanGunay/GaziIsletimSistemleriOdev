#!/bin/bash

# Hata alındığında komutları işletmeyi durdurur
set -e

# Sistemi güncelleme
sudo apt-get update

# Kurulumların interaktif olmaması ayarı
export DEBIAN_FRONTEND=noninteractive

# Timezone ayarı
echo "Europe/Istanbul" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# syslog-ng kurulumu ve başlatılması
apt-get install -y syslog-ng-core
service syslog-ng start

# Postgresql yükleme
curl -sS -k https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/postgresql.gpg > /dev/null
apt-get update
apt-get -y install postgresql

# Postgresql servisini başlatma
service postgresql start

# Postgresql'e kullanıcı ve tablo oluşturulması. Gerekli yetkilerin tanımlanması
sudo -u postgres psql -c "CREATE USER admin WITH PASSWORD 'admin';"
sudo -u postgres psql -d postgres -c "create table log(id serial primary key, username varchar(50), login_time timestamp);"
sudo -u postgres psql -d postgres -c "GRANT ALL PRIVILEGES ON TABLE log TO admin;"
sudo -u postgres psql -d postgres -c "GRANT ALL PRIVILEGES ON SEQUENCE log_id_seq TO admin;"

# LDAP yüklenmesi
sudo apt-get install -y debconf-utils
echo "slapd slapd/internal/generated_adminpw password password" | sudo debconf-set-selections
echo "slapd slapd/internal/adminpw password password" | sudo debconf-set-selections
echo "slapd slapd/password2 password password" | sudo debconf-set-selections
echo "slapd slapd/password1 password password" | sudo debconf-set-selections
echo "slapd slapd/domain string gazi.edu.tr" | sudo debconf-set-selections
echo "slapd shared/organization string Gazi" | sudo debconf-set-selections
echo "slapd slapd/backend string MDB" | sudo debconf-set-selections
echo "slapd slapd/purge_database boolean true" | sudo debconf-set-selections
echo "slapd slapd/move_old_database boolean true" | sudo debconf-set-selections
echo "slapd slapd/allow_ldap_v2 boolean false" | sudo debconf-set-selections
echo "slapd slapd/no_configuration boolean false" | sudo debconf-set-selections
sudo apt-get install -y slapd ldap-utils

# LDAP ayarlanması
sudo service slapd start

ADMIN_DN="cn=admin,dc=gazi,dc=edu,dc=tr"
ADMIN_GROUP_DN="cn=admin,ou=groups,dc=gazi,dc=edu,dc=tr"
ADMIN_PASSWORD="password"

# LDAP yönetici hesabının eklenmesi
echo -e "dn: $ADMIN_DN\n\
objectClass: organizationalRole\n\
cn: admin\n\
description: LDAP administrator\n" | sudo ldapadd -x -D $ADMIN_DN -w $ADMIN_PASSWORD

# LDAP kullanıcılarının eklenmesi
USERS=("kaan" "ahmet" "melih" "tarik")
for USER in "${USERS[@]}"; do
 USER_DN="cn=$USER,dc=gazi,dc=edu,dc=tr"
 echo -e "dn: $USER_DN\n\
objectClass: inetOrgPerson\n\
objectClass: posixAccount\n\
cn: $USER\n\
sn: $USER\n\
uid: $USER\n\
uidNumber: 1001\n\
gidNumber: 1001\n\
userPassword: $(slappasswd -s $USER)\n\
homeDirectory: /home/$USER\n" | sudo ldapadd -x -D $ADMIN_DN -w $ADMIN_PASSWORD
done

# LDAP organizationalUnit nesnesini oluşturun
echo -e "dn: ou=groups,dc=gazi,dc=edu,dc=tr\n\
objectClass: top\n\
objectClass: organizationalUnit\n\
ou: groups\n" | sudo ldapadd -x -D $ADMIN_DN -w $ADMIN_PASSWORD

# LDAP groupOfNames nesnesini oluşturun
echo -e "dn: $ADMIN_GROUP_DN\n\
objectClass: top\n\
objectClass: groupOfNames\n\
cn: admin\n\
member: $ADMIN_DN\n" | sudo ldapadd -x -D $ADMIN_DN -w $ADMIN_PASSWORD

# LDAP kullanıcılarına admin yetkisi verilmesi
for USER in "${USERS[@]}"; do
 USER_DN="cn=$USER,dc=gazi,dc=edu,dc=tr"
 echo -e "dn: $ADMIN_GROUP_DN\n\
changetype: modify\n\
add: member\n\
member: $USER_DN\n" | sudo ldapmodify -x -D $ADMIN_DN -w $ADMIN_PASSWORD
done

# LDAP servisinin tekrar başlatılması
sudo service slapd restart

# Projenin bulunduğu dizin
cd flask_app

# Pip kurulması
sudo apt-get install -y python3-pip

# Python uygulaması için gerekli bağımlılıkların indirilmesi
sudo apt-get install -y libsasl2-dev libldap2-dev libssl-dev
pip3 install -r requirements.txt

# Gunicronu service olarak ekleme
FLASK_APP_DIR=$(pwd)/flask_app
sudo bash -c 'cat > /etc/systemd/system/gunicorn.service << EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory='$FLASK_APP_DIR'
ExecStart=/usr/local/bin/gunicorn --workers 1 --bind unix:/run/gunicorn.sock -m 007 app:app

[Install]
WantedBy=multi-user.target
EOF'

# systemd daemon'un yeniden yüklenmesi
sudo systemctl daemon-reload

# Gunicorn servisinin başlatılması
sudo systemctl start gunicorn

# Nginx yükle
sudo apt-get install -y nginx

# Nginx ayarları
sudo rm /etc/nginx/sites-enabled/default
echo "server {
    listen 80;
    server_name localhost;

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}" | sudo tee /etc/nginx/sites-available/flask_app
sudo ln -s /etc/nginx/sites-available/flask_app /etc/nginx/sites-enabled

# Nginx uygulamasının gunicorn uygualamsına ulaşması için gerekli ayarlar
sudo chown www-data:www-data /run/gunicorn.sock
sudo chmod 660 /run/gunicorn.sock
sudo service nginx restart

# SSH kurulu ve başlatılması
sudo apt-get install -y openssh-server
sudo service ssh start

# Nagios için gerekli araçları ve bağımlılıkları yükleme
sudo apt-get install -y autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php libgd-dev

# /tmp dizinine Nagios'u indirme
cd /tmp
wget --no-check-certificate https://github.com/NagiosEnterprises/nagioscore/releases/download/nagios-4.4.6/nagios-4.4.6.tar.gz
tar xzf nagios-4.4.6.tar.gz
cd /tmp/nagios-4.4.6/

# Nagios'u derleme ve yükleme
sudo ./configure --with-httpd-conf=/etc/apache2/sites-enabled
sudo make all
sudo make install-groups-users
sudo usermod -a -G nagios www-data
sudo make install
sudo make install-daemoninit
sudo make install-commandmode
sudo make install-config
sudo make install-webconf
sudo a2enmod rewrite
sudo a2enmod cgi

echo "AcceptFilter http none" | sudo tee -a /etc/apache2/apache2.conf
echo "AcceptFilter https none" | sudo tee -a /etc/apache2/apache2.conf

sudo sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf

# Apache'yi yeniden başlatma
sudo service apache2 restart 

# Nagios web arayüzü için kullanıcı oluşturma ve parolayı otomatik olarak ayarlama
echo "nagiosadmin:$(openssl passwd -apr1 password)" | sudo tee -a /usr/local/nagios/etc/htpasswd.users

# Nagios eklentilerini indirip ve yükleme
cd /tmp
wget --no-check-certificate https://nagios-plugins.org/download/nagios-plugins-2.3.3.tar.gz
tar xzf nagios-plugins-2.3.3.tar.gz
cd /tmp/nagios-plugins-2.3.3/
sudo ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl
sudo make
sudo make install

# Nagios'u başlatma
sudo service nagios start 

# Tüm service'lerim sistem tekrar başladığında çalışmasını sağlamak için eklenmiştir.
if command -v systemctl &> /dev/null
then
    sudo systemctl enable syslog-ng
    sudo systemctl enable postgresql
    sudo systemctl enable slapd
    sudo systemctl enable nginx
    sudo systemctl enable ssh
    sudo systemctl enable nagios
    sudo systemctl enable apache2
else
    echo "systemctl komutu bulunamadı. Servislerin otomatik başlatılması için başka bir yöntem kullanmalısınız."
fi
