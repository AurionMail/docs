sudo mkdir aurion-core

cd aurion-core/

sudo wget https://github.com/AurionMail/core-api/releases/download/0.0.2/aurion-api

sudo nano .env

sudo -u postgres psql

postgres=# CREATE DATABASE aurionapidb OWNER aurionuser;
CREATE DATABASE
postgres=# CREATE USER aurioapinuser WITH PASSWORD 'pass';
CREATE ROLE
postgres=# CREATE DATABASE aurionapi OWNER aurioapinuser;
CREATE DATABASE
postgres=# \c aurionapi
You are now connected to database "aurionapi" as user "postgres".
aurionapi=# GRANT ALL ON SCHEMA public TO aurioapinuser;
GRANT
aurionapi=# ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO aurioapinuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO aurioapinuser;
ALTER DEFAULT PRIVILEGES
ALTER DEFAULT PRIVILEGES
aurionapi=# exit

sudo wget https://raw.githubusercontent.com/AurionMail/core-api/refs/heads/main/migrations/init.sql


psql -h localhost -U aurionuser -d auriondb -f migrations/init.sql

sudo chmod -R 750 ./aurion-core
sudo chown -R www-data:www-data ./aurion-core
sudo chmod +x ./aurion-api


Create the file /etc/systemd/system/aurion.service:

[Unit]
Description=Aurion Core Server
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/aurion
ExecStart=/var/www/aurion/aurion-api
Restart=always
RestartSec=5
EnvironmentFile=/var/www/aurion/.env

[Install]
WantedBy=multi-user.target

Enable and start the service:

sudo systemctl daemon-reload
sudo systemctl enable aurion
sudo systemctl start aurion
