#!/bin/bash

# Sistemi güncelleme
sudo apt-get update

# Kurulumların interaktif olmaması ayarı
export DEBIAN_FRONTEND=noninteractive

# Timezone ayarı
echo "Europe/Istanbul" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Postgresql yükleme
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
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

echo -e "dn: $ACCESS_CONTROL_DN\n\
changetype: modify\n\
add: olcAccess\n\
olcAccess: {0}to * by dn.base=\"$ADMIN_GROUP_DN\" manage by * break\n" | sudo ldapmodify -Y EXTERNAL -H ldapi:///

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

# Gunicorn ile uygulananın çalıştırılması
gunicorn --daemon --workers 1 --bind unix:/run/gunicorn.sock -m 007 app:app

# Nginx uygulamasının gunicorn uygualamsına ulaşması için gerekli ayarlar
sudo chown www-data:www-data /run/gunicorn.sock
sudo chmod 660 /run/gunicorn.sock
sudo service nginx restart

# SSH kurulu ve başlatılması
sudo apt-get install -y openssh-server
sudo service ssh start
