#!/bin/bash

# Projenin bulunduğu dizin
cd flask_app

# Flask ve Gunicorn yükle
sudo apt-get update
sudo apt-get install -y python3-pip
pip3 install Flask gunicorn

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