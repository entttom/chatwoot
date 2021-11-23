#!/usr/bin/env bash

# Description: MaaS installation script
# OS: Ubuntu 20.04 LTS / Ubuntu 20.10
# Script Version: 0.6
# Run this script as root

read -p 'Would you like to configure a domain and SSL for MaaS?(yes or no): ' configure_webserver

if [ $configure_webserver == "yes" ]
then
read -p 'Enter your sub-domain to be used for MaaS (maas.domain.com for example) : ' domain_name
echo -e "\nThis script will try to generate SSL certificates via LetsEncrypt and serve maas at
"https://$domain_name". Proceed further once you have pointed your DNS to the IP of the instance.\n"
read -p 'Do you wish to proceed? (yes or no): ' exit_true
if [ $exit_true == "no" ]
then
exit 1
fi
fi

apt update && apt upgrade -y
apt install -y curl
curl -sL https://deb.nodesource.com/setup_12.x | bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt update

apt install -y \
	git software-properties-common imagemagick libpq-dev \
    libxml2-dev libxslt1-dev file g++ gcc autoconf build-essential \
    libssl-dev libyaml-dev libreadline-dev gnupg2 nginx redis-server \
    redis-tools postgresql postgresql-contrib certbot \
    python3-certbot-nginx nodejs yarn patch ruby-dev zlib1g-dev liblzma-dev \
    libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev nginx-full

adduser --disabled-login --gecos "" maas

gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
gpg2 --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable
adduser maas rvm

pg_pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15 ; echo '')
sudo -i -u postgres psql << EOF
\set pass `echo $pg_pass`
CREATE USER maas CREATEDB;
ALTER USER maas PASSWORD :'pass';
ALTER ROLE maas SUPERUSER;
UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';
DROP DATABASE template1;
CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UNICODE';
UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';
\c template1
VACUUM FREEZE;
EOF

systemctl enable redis-server.service
systemctl enable postgresql

secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 63 ; echo '')
RAILS_ENV=production

sudo -i -u maas << EOF
rvm --version
rvm autolibs disable
rvm install "ruby-3.0.2"
rvm use 3.0.2 --default

git clone https://github.com/entttom/chatwoot/chatwoot.git
cd chatwoot
if [[ -z "$1" ]]; then
git checkout master;
else
git checkout $1;
fi
bundle
yarn

cp .env.example .env
sed -i -e "/SECRET_KEY_BASE/ s/=.*/=$secret/" .env
sed -i -e '/REDIS_URL/ s/=.*/=redis:\/\/localhost:6379/' .env
sed -i -e '/POSTGRES_HOST/ s/=.*/=localhost/' .env
sed -i -e '/POSTGRES_USERNAME/ s/=.*/=maas/' .env
sed -i -e "/POSTGRES_PASSWORD/ s/=.*/=$pg_pass/" .env
sed -i -e '/RAILS_ENV/ s/=.*/=$RAILS_ENV/' .env
echo -en "\nINSTALLATION_ENV=linux_script" >> ".env"

RAILS_ENV=production bundle exec rake db:create
RAILS_ENV=production bundle exec rake db:reset
rake assets:precompile RAILS_ENV=production
EOF

cp /home/maas/maas/deployment/maas-web.1.service /etc/systemd/system/maas-web.1.service
cp /home/maas/maas/deployment/maas-worker.1.service /etc/systemd/system/maas-worker.1.service
cp /home/maas/maas/deployment/maas.target /etc/systemd/system/maas.target

systemctl enable maas.target
systemctl start maas.target

if [ $configure_webserver != "yes" ]
then
echo "Woot! Woot!! MaaS server installation is complete"
echo "The server will be accessible at http://<server-ip>:3000"
echo "To configure a domain and SSL certificate, follow the guide at https://www.maas.work/docs/deployment/deploy-maas-in-linux-vm"
else

curl https://ssl-config.mozilla.org/ffdhe4096.txt >> /etc/ssl/dhparam
wget https://raw.githubusercontent.com/maas/maas/develop/deployment/nginx_maas.conf
cp nginx_maas.conf /etc/nginx/sites-available/nginx_maas.conf
certbot certonly --nginx -d $domain_name
sed -i "s/maas.domain.com/$domain_name/g" /etc/nginx/sites-available/nginx_maas.conf
ln -s /etc/nginx/sites-available/nginx_maas.conf /etc/nginx/sites-enabled/nginx_maas.conf
systemctl restart nginx
sudo -i -u maas << EOF
cd maas
sed -i "s/http:\/\/0.0.0.0:3000/https:\/\/$domain_name/g" .env
EOF
systemctl restart maas.target
echo "Woot! Woot!! MaaS server installation is complete"
echo "The server will be accessible at https://$domain_name"
fi
