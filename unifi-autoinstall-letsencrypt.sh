#!/bin/bash

# =====================================================================================
# Author:       Michael Tabor
# Website:      https://miketabor.com
# Description:  Script to automate the updating and securing of a Debian 9 server
#                and installing the Ubiquiti UniFi controller software.
# =====================================================================================

# Enter the hostname of your controller.
HOSTNAME=unifi.yourdomain.com

# Enter your email address used for Let's Encrypt.
EMAIL=myaddress@email.com


# =====================================================================================
#   Nothing to edit below this line!!!
# =====================================================================================


# Check if running as root.
if [ "$EUID" -ne 0 ]
then
  clear
  echo "Please run this script as root."
  exit 1
fi

# update apt-get source list and upgrade all packages.
clear
echo "#############################"
echo "Updating your system"
echo "#############################"
sleep 2
apt-get update && apt-get upgrade -y
clear

# Create firewall rules
echo "#############################"
echo "Creating Firewall Rules"
echo "#############################"
sleep 2
iptables -t nat -I PREROUTING -p tcp --dport 443 -j REDIRECT --to-ports 8443
iptables -A INPUT -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 8443 -j ACCEPT
iptables -A INPUT -p udp --dport 3478 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 8843 -j ACCEPT
iptables -A INPUT -j DROP
iptables -A OUTPUT -o eth0 -j ACCEPT
clear

# Install Firewall persistence - source: https://gist.github.com/alonisser/a2c19f5362c2091ac1e7
echo "#############################"
echo "Configuring Firewall Persistence"
echo "#############################"
sleep 2
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
apt-get install iptables-persistent netfilter-persistent -y
clear

# Save firewall rules
echo "#############################"
echo "Saving Firewall rules"
echo "#############################"
sleep 2
netfilter-persistent save
clear

# Configure the hostname
echo "#############################"
echo "Setting system hostname"
echo "#############################"
sleep 2
hostname $HOSTNAME
hostnamectl set-hostname $HOSTNAME
clear

# Install Ubiquiti Unifi
echo "#############################"
echo "Installing Ubiquiti UniFi Controller"
echo "#############################"
sleep 2
wget -O /etc/apt/trusted.gpg.d/unifi-repo.gpg https://dl.ubnt.com/unifi/unifi-repo.gpg 
echo 'deb http://www.ubnt.com/downloads/unifi/debian stable ubiquiti' | tee /etc/apt/sources.list.d/100-ubnt-unifi.list
apt-get update && apt-get install unifi -y
clear

# Install Let's Encrypt
echo "#############################"
echo "Installing Let's Encrypt"
echo "#############################"
sleep 2
apt-get install letsencrypt -y
clear

# Setup LetsEncrypt certificate
echo "#############################"
echo "Setting up LetsEncrypt Certificate"
echo "#############################"
sleep 2
wget -O /opt/gen-unifi-cert.sh https://source.sosdg.org/brielle/lets-encrypt-scripts/raw/master/gen-unifi-cert.sh
sed -i 's/--agree-tos --standalone --preferred-challenges tls-sni/--agree-tos --standalone/g' /opt/gen-unifi-cert.sh
chmod +x /opt/gen-unifi-cert.sh
/opt/gen-unifi-cert.sh -e $EMAIL -d $HOSTNAME
clear

# Create crontab for LetsEncrypt
echo "#############################"
echo "Update LetsEncrypt Certificate on a schedule"
echo "#############################"
sleep 2
crontab -l > /tmp/letsencryptcron
echo "23 1,13 * * * /opt/gen-unifi-cert.sh -r -d $HOSTNAME" >> /tmp/letsencryptcron
crontab /tmp/letsencryptcron
rm /tmp/letsencryptcron
clear

# Install Nginx
echo "#############################"
echo "Installing Nginx"
echo "#############################"
sleep 2
apt-get install nginx-light -y
clear

# Configure Nginx to forward 80 to 443
echo "#############################"
echo "Configuring Nginx to forward HTTP to HTTPS"
echo "#############################"
sleep 2
echo "server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}" > /etc/nginx/sites-available/redirect
ln -s /etc/nginx/sites-available/redirect /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
clear

# Install fail2ban
echo "#############################"
echo "Installing and Configuring Fail2ban"
echo "#############################"
sleep 2
apt-get install fail2ban -y

# Copy config Fail2ban config files to preserve overwriting changes during Fail2ban upgrades.
cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Create ubiquiti Fail2ban definition and set fail regex. 
sudo echo -e '# Fail2Ban filter for Ubiquiti UniFi\n#\n#\n\n[Definition]\nfailregex =^.*Failed .* login .* <HOST>*\s*$
' | sudo tee -a /etc/fail2ban/filter.d/ubiquiti.conf

# Add ubiquiti JAIL to Fail2ban setting log path and blocking IPs after 3 failed logins within 15 minutes for 1 hour.
sudo echo -e '\n[ubiquiti]\nenabled  = true\nfilter   = ubiquiti\nlogpath  = /usr/lib/unifi/logs/server.log\nmaxretry = 3\nbantime = 3600\nfindtime = 900\nport = 8443\nbanaction = iptables[name=ubiquiti, port=8443, protocol=tcp]' | sudo tee -a /etc/fail2ban/jail.local

# Restart Fail2ban to apply changes above.
service fail2ban restart
clear

# Restart services
echo "#############################"
echo "Restarting Services"
echo "#############################"
sleep 2
systemctl restart nginx
systemctl restart unifi

echo -e "\n\n\n  Ubiquiti UniFi Controller Install Complete...! \n"
echo "  Access controller by going to https://$HOSTNAME"
