#! /bin/bash

#############################################################################
#                                                                           #
# Author:       Martin Boller                                               #
#                                                                           #
# Email:        martin@bollers.dk                                           #
# Last Update:  2022-01-09                                                  #
# Version:      1.00                                                        #
#                                                                           #
# Changes:      Initial Version (1.00)                                      #
#                                                                           #
# Info:         Installing Snipe-IT on Debian 11                            #
#               Most of the work done by the install                        #
#                  Script created by Mike Tucker                            #
#                   mtucker6784@gmail.com                                   #
#                                                                           #
# Instruction:  Run this script as root on a fully updated                  #
#               Debian 10 (Buster) or Debian 11 (Bullseye)                  #
#                                                                           #
#############################################################################


install_prerequisites() {
    /usr/bin/logger 'install_prerequisites' -t 'snipeit-2022-01-05';
    echo -e "\e[1;32m - install_prerequisites"
    echo -e "\e[1;36m ... installing Prerequisite packages\e[0m";
    tzone=$(cat /etc/timezone)
    export DEBIAN_FRONTEND=noninteractive;
    /usr/bin/logger "Operating System: $OS Version: $VER" -t 'snipeit-2022-01-05';
    echo -e "\e[1;36m ... Operating System: $OS Version: $VER\e[0m";
    # Install prerequisites
    echo -e "\e[1;36m ... Adding PHP repository.\e[0m"
    apt-get -qq -y install apt-transport-https lsb-release ca-certificates > /dev/null 2>&1
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg > /dev/null 2>&1
    echo "deb https://packages.sury.org/php/ $codename main" > /etc/apt/sources.list.d/php.list
    echo -e "\e[1;36m ... updating all packages\e[0m";
    apt-get -qq update > /dev/null 2>&1;
    # Install some basic tools on a Debian net install
    /usr/bin/logger '..Install some basic tools on a Debian net install' -t 'snipeit-2022-01-05';
    echo -e "\e[1;36m ... installing packages missing from Debian net-install\e[0m";
    apt-get -qq -y install --fix-policy > /dev/null 2>&1;
    apt-get -qq -y install adduser wget whois unzip curl gnupg2 software-properties-common dnsutils python3 python3-pip > /dev/null 2>&1;

    echo -e "\e[1;36m ... Installing Apache httpd, PHP, MariaDB\e[0m" 
    apt-get -qq -y install mariadb-server mariadb-client apache2 libapache2-mod-php7.4 php7.4 php7.4-mcrypt \
        php7.4-curl php7.4-mysql php7.4-gd php7.4-ldap php7.4-zip php7.4-mbstring php7.4-xml php7.4-bcmath curl git unzip > /dev/null 2>&1
    # Set locale
    # Install other preferences and clean up APT
    echo -e "\e[1;36m ... installing some preferences on Debian and cleaning up apt\e[0m";
    /usr/bin/logger '....installing some preferences on Debian and cleaning up apt' -t 'snipeit-2022-01-05';
    apt-get -qq -y install bash-completion > /dev/null 2>&1;
    # Install SUDO
    apt-get -qq -y install sudo > /dev/null 2>&1;
    # A little apt 
    apt-get -qq -y install --fix-missing > /dev/null 2>&1;
    apt-get -qq update > /dev/null 2>&1;
    apt-get -qq -y full-upgrade > /dev/null 2>&1;
    apt-get -qq -y autoremove --purge > /dev/null 2>&1;
    apt-get -qq -y autoclean > /dev/null 2>&1;
    apt-get -qq -y clean > /dev/null 2>&1;
    # Python pip packages
    echo -e "\e[1;36m ... installing python3-pip\e[0m";
    apt-get -qq -y python3-pip > /dev/null 2>&1;
    python3 -m pip install --upgrade pip > /dev/null 2>&1;
    echo -e "\e[1;32m - install_prerequisites finished"
    /usr/bin/logger 'install_prerequisites finished' -t 'snipeit-2022-01-05';
}

generate_certificates() {
    /usr/bin/logger 'generate_certificates()' -t 'snipeit-2022-01-05';
    echo -e "\e[1;32m - generate_certificates"
    mkdir -p $APACHE_CERTS_DIR > /dev/null 2>&1;
    echo -e "\e[1;36m ... generating openssl.cnf file\e[0m";
    cat << __EOF__ > ./openssl.cnf
## Request for $fqdn
[ req ]
default_bits = 2048
default_md = sha256
prompt = no
encrypt_key = no
distinguished_name = dn
req_extensions = req_ext

[ dn ]
countryName         = $ISOCOUNTRY
stateOrProvinceName = $PROVINCE
localityName        = $LOCALITY
organizationName    = $ORGNAME
CN = $fqdn

[ req_ext ]
subjectAltName = $ALTNAMES
__EOF__
    sync;
    # generate Certificate Signing Request to send to corp PKI
    echo -e "\e[1;36m ... generating csr and private key\e[0m";
    openssl req -new -config openssl.cnf -keyout $APACHE_CERTS_DIR/$HOSTNAME.key -out $APACHE_CERTS_DIR/$HOSTNAME.csr > /dev/null 2>&1
    # generate self-signed certificate (remove when CSR can be sent to Corp PKI)
    echo -e "\e[1;36m ... generating self signed certificate\e[0m";
    openssl x509 -in $APACHE_CERTS_DIR/$HOSTNAME.csr -out $APACHE_CERTS_DIR/$HOSTNAME.crt -req -signkey $APACHE_CERTS_DIR/$HOSTNAME.key -days 365 > /dev/null 2>&1
    chmod 600 $APACHE_CERTS_DIR/$HOSTNAME.key > /dev/null 2>&1
    echo -e "\e[1;32m - generate_certificates finished"
    /usr/bin/logger 'generate_certificates() finished' -t 'snipeit-2022-01-05';
}

prepare_nix() {
    /usr/bin/logger 'prepare_nix()' -t 'gse-21.4';
    echo -e "\e[1;32m - prepare_nix"
    echo -e "\e[1;36m ... generating motd file\e[0m";    
    # Configure MOTD
    BUILDDATE=$(date +%Y-%m-%d)
    cat << __EOF__ >> /etc/motd
           
        $HOSTNAME

*****************************************************        
*      _____       _                  __________    *
*     / ___/____  (_)___  ___        /  _/_  __/    *
*     \__ \/ __ \/ / __ \/ _ \______ / /  / /       *
*    ___/ / / / / / /_/ /  __/_____// /  / /        *
*   /____/_/ /_/_/ .___/\___/     /___/ /_/         *
*               /_/                                 *
*                                                   *
********************||*******************************
             (\__/) ||
             (•ㅅ•) ||
            /  　  づ
     Automated install v  1.0
            2022-01-04

__EOF__
    echo -e "\e[1;36m ... configuring motd display\e[0m";
    # do not show motd twice
    sed -ie 's/session    optional     pam_motd.so  motd=\/etc\/motd/#session    optional     pam_motd.so  motd=\/etc\/motd/' /etc/pam.d/sshd > /dev/null 2>&1
    sync;
    echo -e "\e[1;32m - prepare_nix() finished"
    /usr/bin/logger 'prepare_nix() finished' -t 'snipeit-2022-01-05';
}

configure_apache() {
    /usr/bin/logger 'configure_apache()' -t 'snipeit-2022-01-05';
    echo -e "\e[1;32m - configure_apache()"
    # Change ROOTCA to point to correct cert when/if not using self signed cert.
    export ROOTCA=$HOSTNAME
    # Enable Apache modules required
    echo -e "\e[1;36m ... adding additional apache modules\e[0m";
    a2enmod rewrite ssl headers > /dev/null 2>&1;
    echo -e "\e[1;36m ... enabling $APP_NAME site\e[0m";
    # TLS
    echo -e "\e[1;36m ... generating site configuration file with TLS support\e[0m";
    cat << __EOF__ > $APACHE_DIR/sites-available/snipeit.conf;
    <VirtualHost *:80>
        ServerName $HOSTNAME
        RewriteEngine On
        RewriteCond %{REQUEST_URI} !^/\.well\-known/acme\-challenge/
        RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
    </VirtualHost>

    <VirtualHost *:443>
        <Directory $APP_PATH/public>
            Allow From All
            AllowOverride All
            Options -Indexes
        </Directory>

        ServerName $HOSTNAME
        DocumentRoot $APP_PATH/public
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
    
        SSLCertificateFile "$APACHE_CERTS_DIR/$fqdn.crt"
        SSLCertificateKeyFile "$APACHE_CERTS_DIR/$fqdn.key"
        SSLCertificateChainFile "$APACHE_CERTS_DIR/$ROOTCA.crt"

        # enable HTTP/2, if available
        Protocols h2 http/1.1

        # HTTP Strict Transport Security (mod_headers is required)
        Header always set Strict-Transport-Security "max-age=63072000"
    </VirtualHost>

    # modern configuration
    SSLProtocol             all -SSLv3 -TLSv1 -TLSv1.1 -TLSv1.2
    SSLHonorCipherOrder     off
    SSLSessionTickets       off
    # Cert Stapling
    SSLUseStapling On
    SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"
__EOF__
   a2ensite $APP_NAME.conf > /dev/null 2>&1
 
    echo -e "\e[1;36m ... turning of some apache specific header information\e[0m";
    # Turn off detail Header information
    cat << __EOF__ >> $APACHE_DIR/apache2.conf;
ServerTokens Prod
ServerSignature Off
FileETag None
__EOF__
    sync;
        echo -e "\e[1;36m ... setting $APP_NAME permissions\e[0m";
    for chmod_dir in "$APP_PATH/storage" "$APP_PATH/public/uploads"; do
        chmod -R 775 "$chmod_dir" > /dev/null 2>&1
    done
    chown -R snipeitapp:www-data $APP_PATH/
    echo -e "\e[1;36m ... restarting apache with new configuration\e[0m";
    systemctl restart apache2.service > /dev/null 2>&1;
    echo -e "\e[1;32m - configure_apache() finished"
    /usr/bin/logger 'configure_apache() finished' -t 'snipeit-2022-01-05';
}

configure_iptables() {
    /usr/bin/logger 'configure_iptables() started' -t 'bSIEM Step2';
    echo -e "\e[32m - configure_iptables()\e[0m";
    echo -e "\e[36m ... creating iptables rules file for IPv4\e[0m";
    cat << __EOF__  >> /etc/network/iptables.rules
##
## Ruleset for snipeit Server
##
## IPTABLES Ruleset Author: Martin Boller 2021-11-11 v1

*filter
## Dropping anything not explicitly allowed
##
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:LOG_DROPS - [0:0]

## DROP IP fragments
-A INPUT -f -j LOG_DROPS
-A INPUT -m ttl --ttl-lt 4 -j LOG_DROPS

## DROP bad TCP/UDP combinations
-A INPUT -p tcp --dport 0 -j LOG_DROPS
-A INPUT -p udp --dport 0 -j LOG_DROPS
-A INPUT -p tcp --tcp-flags ALL NONE -j LOG_DROPS
-A INPUT -p tcp --tcp-flags ALL ALL -j LOG_DROPS

## Allow everything on loopback
-A INPUT -i lo -j ACCEPT

## SSH, DNS, WHOIS, DHCP ICMP - Add anything else here needed for ntp, monitoring, dhcp, icmp, updates, and ssh
##
## SSH
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
## HTTP(S)
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
## NTP
-A INPUT -p udp -m udp --dport 123 -j ACCEPT
## ICMP
-A INPUT -p icmp -j ACCEPT
## Already established sessions
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

## Logging
-A INPUT -j LOG_DROPS
## get rid of broadcast noise
-A LOG_DROPS -d 255.255.255.255 -j DROP
# Drop Broadcast to internal networks
-A LOG_DROPS -m pkttype --pkt-type broadcast -d 192.168.0.0/16 -j DROP
-A LOG_DROPS -p ip -m limit --limit 60/sec -j --log-prefix "iptables:" --log-level 7
-A LOG_DROPS -j DROP

## Commit everything
COMMIT
__EOF__

    echo -e "\e[36m ... creating iptables rules file for IPv6\e[0m";
# ipv6 rules
    cat << __EOF__  >> /etc/network/ip6tables.rules
##
## Ruleset for spiderfoot Server
##
## IP6TABLES Ruleset Author: Martin Boller 2021-11-11 v1

*filter
## Dropping anything not explicitly allowed
##
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:LOG_DROPS - [0:0]

## DROP bad TCP/UDP combinations
-A INPUT -p tcp --dport 0 -j LOG_DROPS
-A INPUT -p udp --dport 0 -j LOG_DROPS
-A INPUT -p tcp --tcp-flags ALL NONE -j LOG_DROPS
-A INPUT -p tcp --tcp-flags ALL ALL -j LOG_DROPS

## Allow everything on loopback
-A INPUT -i lo -j ACCEPT

## Allow access to port 5001
-A OUTPUT -p tcp -m tcp --dport 5001 -j ACCEPT
## SSH, DNS, WHOIS, DHCP ICMP - Add anything else here needed for ntp, monitoring, dhcp, icmp, updates, and ssh
## SSH
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
## HTTP(S)
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
## NTP
-A INPUT -p udp -m udp --dport 123 -j ACCEPT
## ICMP
-A INPUT -p icmp -j ACCEPT
## Already established sessions
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

## Logging
-A INPUT -j LOG_DROPS
-A LOG_DROPS -p ip -m limit --limit 60/sec -j --log-prefix "iptables:" --log-level 7
-A LOG_DROPS -j DROP

## Commit everything
COMMIT
__EOF__

    # Configure separate file for iptables logging
    echo -e "\e[36m ... configuring separate file for iptables\e[0m";
    cat << __EOF__  >> /etc/rsyslog.d/30-iptables-syslog.conf
:msg,contains,"iptables:" /var/log/iptables.log
& stop
__EOF__
    sync;
    systemctl restart rsyslog.service> /dev/null 2>&1;

    # Configure daily logrotation (forward this to mgmt)
    echo -e "\e[36m ... configuring daily logrotation for iptables log\e[0m";
    cat << __EOF__  >> /etc/logrotate.d/iptables
/var/log/iptables.{
  rotate 5
  daily
  compress
  create 640 root root
  notifempty
  postrotate
    /usr/lib/rsyslog/rsyslog-rotate
  endscript
}
__EOF__

# Apply iptables at boot
    echo -e "\e[36m ... creating if-up script to apply iptables rules at every startup\e[0m";
    echo -e "\e[36m-Script applying iptables rules\e[0m";
    cat << __EOF__  >> /etc/network/if-up.d/firewallrules
#! /bin/bash
iptables-restore < /etc/network/iptables.rules
ip6tables-restore < /etc/network/ip6tables.rules
exit 0
__EOF__
    sync;
    ## make the script executable
    chmod +x /etc/network/if-up.d/firewallrules> /dev/null 2>&1;
    # Apply firewall rules for the first time
    #/etc/network/if-up.d/firewallrules;
    /usr/bin/logger 'configure_iptables() done' -t 'Firewall setup';
}

show_databases() {
    echo -e ""
    echo -e "\e[1;32m------------------------------\e[0m"
    echo -e ""
    echo -e "\e[1;32mShowing databases....."
    mysql -e "show databases;"
    echo -e "\e[1;32m------------------------------\e[0m"
    /usr/bin/logger ''Databases $(mysql -e "show databases;")'' -t 'snipeit-2022-01-05';
}

check_services() {
    /usr/bin/logger 'check_services' -t 'snipeit-2022-01-05';
    echo -e "\e[1;32m - check_services()"
    # Check status of critical services
    # Apache
    echo -e "\e[1;32m-----------------------------------------------------------------\e[0m";
    echo -e "\e[1;32m - Checking core daemons for Snipe-IT......\e[0m";
    if systemctl is-active --quiet apache2.service;
        then
            echo -e "\e[1;32m ... apache webserver started successfully";
            /usr/bin/logger 'apache webserver started successfully' -t 'snipeit-2022-01-05';
        else
            echo -e "\e[1;31m ... apache webserver FAILED!\e[0m";
            /usr/bin/logger 'apache webserver FAILED' -t 'snipeit-2022-01-05';
    fi
    # mariadb.service
    if systemctl is-active --quiet mariadb.service;
        then
            echo -e "\e[1;32m ... mariadb.service started successfully";
            /usr/bin/logger 'mariadb.service started successfully' -t 'snipeit-2022-01-05';
        else
            echo -e "\e[1;31m ... mariadb.service FAILED!\e[0m";
            /usr/bin/logger "mariadb.service FAILED!" -t 'snipeit-2022-01-05';
    fi
    echo -e "\e[1;32m - check_services() finished"
    /usr/bin/logger 'check_services finished' -t 'snipeit-2022-01-05';
}

mariadb_secure_installation() {
    ## This function is based on the mysql-secure-installation script
    ## Provided with MariaDB
    /usr/bin/logger 'mariadb_secure_installation()' -t 'snipeit-2022-01-05';
    echo -e "\e[1;32m - mariadb_secure_installation()"
    echo -e "\e[1;36m ... securing MariaDB\e[0m"
    # Remove anonymous users
    echo -e "\e[1;36m ... removing anonymous users...\e[0m"
    /usr/bin/mysql -e "DELETE FROM mysql.global_priv WHERE User='';" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32m ... Success: Anonymous users removed!\e[0m"
        /usr/bin/logger 'Success: Anonymous users removed' -t 'snipeit-2022-01-05';
    else
        echo -e "\e[1;31m ... Critical: Anonymous users could not be removed!\e[0m"
        /usr/bin/logger 'Critical: Anonymous users could not be removed' -t 'snipeit-2022-01-05';
    fi

    # Remove remote root 
    echo -e "\e[1;36m ... Removing remote root...\e[0m"
    /usr/bin/mysql -e "DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32m ... Success: Remote root successfully removed!\e[0m"
        /usr/bin/logger 'Success: Remote root removed' -t 'snipeit-2022-01-05';
    else
        echo -e "\e[1;31m ... Critical: Remote root could not be removed!\e[0m"
        /usr/bin/logger 'Critical: Remote root could not be removed' -t 'snipeit-2022-01-05';
    fi
    
    # Remove test database
    echo -e "\e[1;36m ... Dropping test database...\e[0m"
    /usr/bin/mysql -e "DROP DATABASE IF EXISTS test;" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32m ... Success: Test database removed!\e[0m"
        /usr/bin/logger 'Success: Test database removed' -t 'snipeit-2022-01-05';
    else
        echo -e "\e[1;31m ... Warning: Test database could not be removed! Not critical...\e[0m"
        /usr/bin/logger 'Warning: Test database could not be removed' -t 'snipeit-2022-01-05';
    fi

    echo -e "\e[1;36m ... Removing privileges on test database...\e[0m"
    /usr/bin/mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32m ... Success: privileges on test database removed!\e[0m"
        /usr/bin/logger 'Success: Privileges on test database removed' -t 'snipeit-2022-01-05';
    else
        echo -e "\e[1;35m ... Warning: privileges on test database not removed\e[0m"
        /usr/bin/logger 'Warning: Privileges on test database could not be removed' -t 'snipeit-2022-01-05';
    fi

    # Reload privilege tables
    echo -e "\e[1;36m ... Reloading privilege tables...\e[0m"
    /usr/bin/mysql -e "FLUSH PRIVILEGES;" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32m ... Success: privilege tables reloaded"
        return 0
    else
        echo -e "\e[1;35m ... Warning: privilege tables could not be reloaded"
        return 1
    fi
    /usr/bin/logger 'mariadb_secure_installation() finished' -t 'snipeit-2022-01-05';
    echo -e "\e[1;32m - securing MariaDB finished\e[0m"
}

configure_mail_server() {
    /usr/bin/logger 'configure_mail_server()' -t 'snipeit-2022-01-05';
    echo -e "\e[1;32m - configure_mail_server()\e[0m"
    # Setting up mail server config
    ######################################################
    #       Originally from the Snipe-It Install         #
    #          Script created by Mike Tucker             #
    #            mtucker6784@gmail.com                   #
    ######################################################
    
    setupmail=default
    until [[ $setupmail == "yes" ]] || [[ $setupmail == "no" ]]; do
    echo -n "  Q. Do you want to configure mail server settings? (y/n) "
    read -r setupmail

    case $setupmail in
    [yY] | [yY][Ee][Ss] )
        echo -e "\e[1;32m"
        echo -n " - Outgoing mailserver address: "
        read -r mailhost
        sed -i "s|^\\(MAIL_HOST=\\).*|\\1$mailhost|" "$APP_PATH/.env"

        echo -n " - Server port number: "
        read -r mailport
        sed -i "s|^\\(MAIL_PORT=\\).*|\\1$mailport|" "$APP_PATH/.env"

        echo -n "  Username: "
        read -r mailusername
        sed -i "s|^\\(MAIL_USERNAME=\\).*|\\1$mailusername|" "$APP_PATH/.env"

        echo -n " - Password: "
        read -rs mailpassword
        sed -i "s|^\\(MAIL_PASSWORD=\\).*|\\1$mailpassword|" "$APP_PATH/.env"
        echo ""

        echo -n " - Encryption(null/TLS/SSL): "
        read -r mailencryption
        sed -i "s|^\\(MAIL_ENCRYPTION=\\).*|\\1$mailencryption|" "$APP_PATH/.env"

        echo -n "  From address: "
        read -r mailfromaddr
        sed -i "s|^\\(MAIL_FROM_ADDR=\\).*|\\1$mailfromaddr|" "$APP_PATH/.env"

        echo -n " - From name: "
        read -r mailfromname
        sed -i "s|^\\(MAIL_FROM_NAME=\\).*|\\1$mailfromname|" "$APP_PATH/.env"

        echo -n " - Reply to address: "
        read -r mailreplytoaddr
        sed -i "s|^\\(MAIL_REPLYTO_ADDR=\\).*|\\1$mailreplytoaddr|" "$APP_PATH/.env"

        echo -n " - Reply to name: "
        read -r mailreplytoname
        sed -i "s|^\\(MAIL_REPLYTO_NAME=\\).*|\\1$mailreplytoname|" "$APP_PATH/.env"
        echo -e "\e[0m"
        setupmail="yes"
        ;;
    [nN] | [n|N][O|o] )
        setupmail="no"
        ;;
    *)  echo -e "\e[1;31m - Invalid answer. Please type y or n\e[0m"
        ;;
    esac
    done
    /usr/bin/logger 'configure_mail_server() finished' -t 'snipeit-2022-01-05';
    echo -e "\e[1;32m - configure_mail_server() finished\e[0m"
}

create_user () {
    echo -e "\e[1;32m - create_user()"
    echo -e "\e[1;36m ... Creating Snipe-IT user $APP_USER.\e[0m"
    adduser --quiet --disabled-password --gecos 'Snipe-IT User' "$APP_USER" > /dev/null 2>&1
    echo -e "\e[1;36m ... Adding Snipe-IT user to group $apache_group.\e[0m"
    usermod -a -G "$apache_group" "$APP_USER" > /dev/null 2>&1
    echo -e "\e[1;32m - create_user()"
}

install_composer () {
    
    ######################################################
    #       Originally from the Snipe-It Install         #
    #          Script created by Mike Tucker             #
    #            mtucker6784@gmail.com                   #
    ######################################################
    
    echo -e "\e[1;32m - install_composer()"
    echo -e "\e[1;36m ... getting composer signature.\e[0m"
    # https://getcomposer.org/doc/faqs/how-to-install-composer-programmatically.md
    EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)" > /dev/null 2>&1
    sudo -i -u $APP_USER php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" > /dev/null 2>&1
    ACTUAL_SIGNATURE="$(sudo -i -u $APP_USER php -r "echo hash_file('SHA384', 'composer-setup.php');")" > /dev/null 2>&1

    if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
    then
        >&2 echo -e "\e[1;31m ... ERROR: Invalid composer installer signature\e[0m"
        sudo -i -u $APP_USER rm composer-setup.php > /dev/null 2>&1
        exit 1
    fi

    echo -e "\e[1;36m ... setting up composer as $APP_USER.\e[0m"
    sudo -i -u $APP_USER php composer-setup.php > /dev/null 2>&1
    sudo -i -u $APP_USER rm composer-setup.php > /dev/null 2>&1

    mv "$(eval echo ~$APP_USER)"/composer.phar /usr/local/bin/composer > /dev/null 2>&1
    echo -e "\e[1;32m - install_composer() finished"
}

install_snipeit () {
    
    ######################################################
    #       Originally from the Snipe-It Install         #
    #          Script created by Mike Tucker             #
    #            mtucker6784@gmail.com                   #
    ######################################################
    
    echo -e "\e[1;32m - install_snipeit()"
    echo -e "\e[1;36m ... create databases.\e[0m"
    mysql -u root --execute="CREATE DATABASE snipeit;GRANT ALL PRIVILEGES ON snipeit.* TO snipeit@localhost IDENTIFIED BY '$mysqluserpw';" > /dev/null 2>&1

    echo -e "\e[1;36m ... Cloning Snipe-IT from github to the web directory.\e[0m"
    git clone --quiet https://github.com/snipe/snipe-it $APP_PATH > /dev/null 2>&1

    echo -e "\e[1;36m ... Configuring $APP_NAME .env file.\e[0m"
    cp "$APP_PATH/.env.example" "$APP_PATH/.env" > /dev/null 2>&1

    #TODO escape SED delimiter in variables
    sed -i '1 i\#Created By Snipe-it Installer' "$APP_PATH/.env" > /dev/null 2>&1
    sed -i "s|^\\(APP_TIMEZONE=\\).*|\\1$tzone|" "$APP_PATH/.env" > /dev/null 2>&1
    sed -i "s|^\\(DB_HOST=\\).*|\\1localhost|" "$APP_PATH/.env" > /dev/null 2>&1
    sed -i "s|^\\(DB_DATABASE=\\).*|\\1snipeit|" "$APP_PATH/.env" > /dev/null 2>&1
    sed -i "s|^\\(DB_USERNAME=\\).*|\\1snipeit|" "$APP_PATH/.env" > /dev/null 2>&1
    sed -i "s|^\\(DB_PASSWORD=\\).*|\\1'$mysqluserpw'|" "$APP_PATH/.env" > /dev/null 2>&1
    sed -i "s|^\\(APP_URL=\\).*|\\1http://$fqdn|" "$APP_PATH/.env" > /dev/null 2>&1
    echo -e "\e[1;32m - install_snipeit() finished"
}

set_hosts () {
    echo -e "\e[1;32m - set_hosts()"
    echo -e "\e[1;36m ... Setting up hosts file.\e[0m"
    echo >> /etc/hosts "127.0.0.1 $(hostname) $fqdn"
    echo -e "\e[1;32m - set_hosts() finished"
}

rename_default_vhost() {
    echo -e "\e[1;32m - rename_default_vhost()"
    echo -e "\e[1;36m ... enabling $APP_NAME site.\e[0m"
    mv /etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/111-default.conf > /dev/null 2>&1
    mv /etc/apache2/sites-enabled/snipeit.conf /etc/apache2/sites-enabled/000-snipeit.conf > /dev/null 2>&1
    echo -e "\e[1;32m - rename_default_vhost() finished"
}

configure_permissions() {

    ######################################################
    #       Originally from the Snipe-It Install         #
    #          Script created by Mike Tucker             #
    #            mtucker6784@gmail.com                   #
    ######################################################
    
    echo -e "\e[1;32m - configure_permissions()"
    echo -e "\e[1;36m ... Setting permissions.\e[0m"
    for chmod_dir in "$APP_PATH/storage" "$APP_PATH/public/uploads"; do
        chmod -R 775 "$chmod_dir" > /dev/null 2>&1
    done
    chown -R "$APP_USER":"$apache_group" "$APP_PATH" > /dev/null 2>&1
    echo -e "\e[1;32m - configure_permissions()"
}

run_composer() {
    
    ######################################################
    #       Originally from the Snipe-It Install         #
    #          Script created by Mike Tucker             #
    #            mtucker6784@gmail.com                   #
    ######################################################
    
    echo -e "\e[1;32m - run_composer()"
    echo -e "\e[1;36m ... Running composer."
    # We specify the path to composer because CentOS lacks /usr/local/bin in $PATH when using sudo
    sudo -i -u $APP_USER /usr/local/bin/composer install --no-dev --prefer-source --working-dir "$APP_PATH" > /dev/null 2>&1

    sudo chgrp -R "$apache_group" "$APP_PATH/vendor" > /dev/null 2>&1

    echo -e "\e[1;36m ... Generating the application key.\e[0m"
    php $APP_PATH/artisan key:generate --force > /dev/null 2>&1

    echo -e "\e[1;36m ... Artisan Migrate.\e[0m"
    php $APP_PATH/artisan migrate --force > /dev/null 2>&1

    echo -e "\e[1;36m ... Creating scheduler cron.\e[0m"
    (crontab -l ; echo "* * * * * /usr/bin/php $APP_PATH/artisan schedule:run >> /dev/null 2>&1") | crontab - > /dev/null 2>&1
    echo -e "\e[1;32m - run_composer() finished"
}

##################################################################################################################
## Main                                                                                                          #
##################################################################################################################

main() {
    /usr/bin/logger 'Installing snipeit.......' -t 'snipeit';
    # Setting global vars
    # OS Version
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    codename=$VERSION_CODENAME
    readonly installedFILE="/snipeit_Installed";

    # Snipe-IT App specific variables
    readonly APP_USER="snipeitapp"
    readonly APP_NAME="snipeit"
    readonly APP_PATH="/var/www/html/$APP_NAME"
    readonly mysqluserpw="$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16; echo)"

    # Apache settings
    readonly APACHE_LOG_DIR=/var/log/apache2;
    readonly APACHE_DIR=/etc/apache2
    readonly APACHE_CERTS_DIR=$APACHE_DIR/certs
    readonly apache_group=www-data

    if ! [ -f $installedFILE ];
    then
        # install all required elements and generate certificates for webserver
        install_prerequisites;
        prepare_nix;
        create_user;
        ## Variables required for certificate
        # organization name
        # (see also https://www.switch.ch/pki/participants/)
        readonly ORGNAME=snipeit_server
        # the fully qualified server (or service) name, change if other servicename than hostname
        readonly fqdn="$(hostname --fqdn)"
        # Local information
        readonly ISOCOUNTRY=DK;
        readonly PROVINCE=Denmark;
        readonly LOCALITY=Copenhagen
        # subjectAltName entries: to add DNS aliases to the CSR, delete
        # the '#' character in the ALTNAMES line, and change the subsequent
        # 'DNS:' entries accordingly. Please note: all DNS names must
        # resolve to the same IP address as the fqdn.
        readonly ALTNAMES=DNS:$HOSTNAME   # , DNS:bar.example.org , DNS:www.foo.example.org
        generate_certificates;
        install_snipeit;
        configure_permissions;
        install_composer;
        run_composer;
        configure_apache;
        rename_default_vhost;
        # Securing mariadb       
        mariadb_secure_installation;
        # Configuration of mail server require user input, so not working well with Vagrant
#        configure_mail_server;
        configure_permissions;
        show_databases;
        check_services;
        /usr/bin/logger 'snipeit Installation complete' -t 'snipeit-2022-01-05';
        echo -e;
        touch /snipeit_Installed;
        echo -e "\e[1;32msnipeit Installation complete\e[0m";
        echo -e "\e[1;32m  ***Open http://$fqdn to login to Snipe-IT.***\e[0m"
        echo -e "\e[1;32m* Cleaning up...\e[0m"
        rm -f snipeit.sh > /dev/null 2>&1
        rm -f install-snipe.sh > /dev/null 2>&1
        echo -e "\e[1;32m - Installation complete, now go to https://$HOSTNAME/\e[0m"
    else
        echo -e "\e[1;31m---------------------------------------------------------------------\e[0m";
        echo -e "\e[1;31m   It appears that snipeit Asset Server has already been installed\e[0m"
        echo -e "\e[1;31m   If this is in error, or you just want to install again, then\e[0m"
        echo -e "\e[1;31m   delete the file /snipeit_Installed and run the script again\e[0m"
        echo -e "\e[1;31m---------------------------------------------------------------------\e[0m";
    fi
}

main;

exit 0;