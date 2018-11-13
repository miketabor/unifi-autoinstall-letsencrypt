# Ubiquiti Unifi Auto-install with Let's Encrypt
Script that automates upgrading and securing of a Debian 9 host then deploys the latest Ubiquiti UniFi Controller.

## What it does

* Updates all packages on the system.
* Configures an iptables firewall to only allow required Unifi, SSH, and web ports of Let's Encrypt.
* Adds the Ubiquiti repo and installs the latest STABLE version of UniFi controller.
* Installs Let's Encrypt and adds a cron job add a valid SSL cert.
* Installs and configures Nginx to redirect HTTP to HTTPS requests
* Finally, installs Fail2ban then adds a custom definition and fail regex to monitor failed Unifi logins.

### How to use
Simply run the following command from terminal to download the script:
```
wget https://raw.githubusercontent.com/miketabor/unifi-autoinstall-letsencrypt/master/unifi-autoinstall-letsencrypt.sh
```
Then type the following to give it execute permissions.
```
chmod +x unifi-autoinstall-letsencrypt.sh
```
Edit the script to change HOSTNAME and EMAIL variables to your own hostname and email address.
```
nano unifi-autoinstall-letsencrypt.sh
```
Finally, run the script and sit back while it does the rest.
```
./unifi-autoinstall-letsencrypt.sh
```
