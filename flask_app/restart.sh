sudo chmod o+w /var/run
sudo service syslog-ng start
sudo service postgresql start
sudo service slapd start
sudo service ssh start
sudo service nagios start
sudo service apache2 start
gunicorn --daemon --workers 1 --bind unix:/var/run/gunicorn.sock -m 007 app:app
sudo chown www-data:www-data /var/run/gunicorn.sock
sudo chmod 660 /var/run/gunicorn.sock
sudo service nginx restart