#!/bin/bash

### Bash Exit if a command exits with a non-zero status ###
set -e

### Include Global Configs ###
TMP_BF=$(dirname "$BASH_SOURCE");
if [[ -f $TMP_BF/system.cnf ]]; then
	source $TMP_BF/system.cnf;
else
	printf "$(date +"%Y-%m-%d_%M:%S") [ERROR]: Please make sure the configuration file system.cnf is set.\n" | tee -a $TMP_BF/logs/error.log; exit 1;
fi

if [[ -f $TMP_BF/config.cnf ]]; then
	source $TMP_BF/config.cnf;
else
	printf "$(date +"%Y-%m-%d_%M:%S") [ERROR]: Please make sure the configuration file config.cnf is set.\n" | tee -a $TMP_BF/logs/error.log; exit 1;
fi

### Include Libraries ###
source $LIB_PATH/functions.sh

### Check System Requirements ###
if [[ $EUID != 0 ]]; then
	syslogger "ERROR" "Please run this script as root.";
fi

if ! hash plesk 2>/dev/null; then
	syslogger "ERROR" "Plesk is not installed on your System.";
fi

printf "\n###################################\n#     Deployment in Progress      #\n###################################\n";
printf "Deployment Init..\n";

printf "\n###################################\n#    Additional Linux Packages    #\n###################################\n";
if [[ "${#LINUX_DISTRO}" > 0 && $LINUX_DISTRO != 0 ]]; then
	if [[ $LINUX_DISTRO =~ "Ubuntu" || $LINUX_DISTRO =~ "Debian" ]]; then
		apt-get -y install $LINUX_PACKAGES
		LINUX_INSTALL_PCKGS=1
	elif [[ $LINUX_DISTRO =~ "centos" ]]; then
		yum -y install epel-release
		yum -y install $LINUX_PACKAGES
		LINUX_INSTALL_PCKGS=1
	else
		syslogger "WARNING" "Wasn't able to determine your Distro Type (e.g. CentOS, Debian or Ubuntu), therefore no linux packages have been installed.";
	fi
fi

if [[ $LINUX_INSTALL_PCKGS == 1 ]]; then
	syslogger "DONE" "Installed the additional linux packages $LINUX_PACKAGES (please see the install process above to check if everything has been installed successfully)";
else
	syslogger "INFO" "No Linux Packages Selected / Installed, skip..";
fi

printf "\n###################################\n#    Custom Bash Profiles Init    #\n###################################\n";
if [[ -f ~/.bash_profile ]]; then
	sed -i -e '/### PLESK_DEPLOYER ###/,/### PLESK_DEPLOYER ###/d' ~/.bash_profile
	syslogger "INFO" "Old bash_profile Deployments have been removed (if any available).";
else
	syslogger "WARNING" "File ~/.bash_profile wasn't found on your system. A new ~/.bash_profile will be created from your config (as long as CONFIGS_DEFAULT or CONFIGS_CUSTOM is set).";
fi

if [[ $CONFIGS_DEFAULT == 1 || $CONFIGS_CUSTOM == 1 ]]; then
	cat $(getConfig bash_profile.cnf) >> ~/.bash_profile;

	syslogger "DONE" "The bash profiles have been successfully applied / added to ~/.bash_profile.";
else
	syslogger "INFO" "No Bash Profile Configuration in your config.cnf selected, skip..";
fi

printf "\n###################################\n#       Plesk Nginx Package       #\n###################################\n";
if [[ $NGINX_INSTALL == 1 ]]; then
	# plesk installer --select-product-id plesk --select-release-current --reinstall-patch --install-component nginx
	plesk installer --select-product-id plesk --select-release-current --install-component nginx
fi

printf "\n###################################\n#        Plesk Nginx Conf's       #\n###################################\n";
getConfig nginx_gzip.cnf; # Return exit 1 if the check fails
echo;

if [[ $NGINX_GZIP == 1 ]]; then
	rm -f /etc/nginx/conf.d/gzip.conf
	cp $(getConfig nginx_gzip.cnf) /etc/nginx/conf.d/gzip.conf
	syslogger "DONE" "Copied $(getConfig nginx_gzip.cnf) to /etc/nginx/conf.d/gzip.conf";
else
	syslogger "INFO" "Skipped nginx gzip configuration..";
fi

printf "\n###################################\n#        Plesk PHP Packages       #\n###################################\n";
# PHP Deployment Variables
PHP_VERSIONS_ALL=( "7.0" "5.6" "5.5" "5.4" "5.3" "5.2" )
PHP_VERSIONS_DIFF=($(arrayDiff PHP_VERSIONS_ALL[@] PHP_VERSIONS[@]))
TMP_PHP_DEPLOYMENT=0

# PHP Deployment Installation
if [[ $PHP_VERSIONS && ${#PHP_VERSIONS[@]} -ne 0 ]]; then
	for phpv in "${PHP_VERSIONS[@]}"
	do
		if [[ ! -f /opt/plesk/php/${phpv}/etc/php.ini ]]; then
			syslogger "INFO" "Installation of PHP ${phpv}:";
			plesk installer --select-product-id plesk --select-release-current --install-component php${phpv};
			syslogger "DONE" "Installation of PHP ${phpv} is finished (please check if there are any possible errors above).";
			TMP_PHP_DEPLOYMENT=1;
		fi
	done
fi

# PHP Deployment Uninstallation
if [[ $PHP_VERSIONS_DIFF && ${#PHP_VERSIONS_DIFF[@]} -ne 0 ]]; then
	for phpv_delete in "${PHP_VERSIONS_DIFF[@]}"
	do
		if [[ -f /opt/plesk/php/${phpv_delete}/etc/php.ini ]]; then
			syslogger "INFO" "Uninstallation of PHP ${phpv_delete}:";
			plesk installer --select-product-id plesk --select-release-current --remove-component php${phpv_delete};
			syslogger "DONE" "Uninstallation of PHP ${phpv_delete} is finished (please check if there are any possible errors above).";
			TMP_PHP_DEPLOYMENT=1;
		fi
	done
fi

# PHP Deployment Satus Message
if [[ $TMP_PHP_DEPLOYMENT == 0 ]]; then
	syslogger "INFO" "No PHP Versions to Deploy. Your chosen PHP Versions are (if any): ${PHP_VERSIONS[@]}. Skip..";
fi

printf "\n###################################\n#        Plesk PHP Ioncube        #\n###################################\n";
# PHP 7.0 Ioncube Deployment
if [[ $PHP70_IONCUBE == 1 && -f /opt/plesk/php/7.0/etc/php.ini ]]; then
	if [[ $LINUX_MACHINE_TYPE == "i686" || $LINUX_MACHINE_TYPE == "x86" ]]; then
		# Linux x86 Systems
		if [[ ! -d /opt/plesk/php/7.0/lib ]]; then syslogger "ERROR" "The Ioncube Installation failed. The folder /opt/plesk/php/7.0/lib/ does not exist."; fi
		cp $SCRIPTPATH/files/ioncube_loaders_lin_x86-32/ioncube_loader_lin_7.0.so /opt/plesk/php/7.0/lib/php/modules/ioncube_loader.so
		printf "zend_extension=/opt/plesk/php/7.0/lib/php/modules/ioncube_loader.so" > /opt/plesk/php/7.0/etc/php.d/00-ioncube-loader.ini
		chmod 755 /opt/plesk/php/7.0/lib/php/modules/ioncube_loader.so
		plesk bin php_handler --reread
		syslogger "DONE" "The Installation of the PHP 7.0 Ioncube Loader was successful (please check if there are any possible errors above).";

	elif [[ $LINUX_MACHINE_TYPE == "x86_64" ]]; then
		# Linux x86_64 Systems
		if [[ ! -d /opt/plesk/php/7.0/lib64 ]]; then syslogger "ERROR" "The Ioncube Installation failed. The folder /opt/plesk/php/7.0/lib64/ does not exist."; fi
		cp $SCRIPTPATH/files/ioncube_loaders_lin_x86-64/ioncube_loader_lin_7.0.so /opt/plesk/php/7.0/lib64/php/modules/ioncube_loader.so
		printf "zend_extension=/opt/plesk/php/7.0/lib64/php/modules/ioncube_loader.so" > /opt/plesk/php/7.0/etc/php.d/00-ioncube-loader.ini
		chmod 755 /opt/plesk/php/7.0/lib64/php/modules/ioncube_loader.so
		plesk bin php_handler --reread
		syslogger "DONE" "The Installation of the PHP 7.0 Ioncube Loader was successful (please check if there are any possible errors above).";
	else
		# Linux System Type not found
		syslogger "ERROR" "The Installation of the PHP 7.0 Ioncube Loader failed. The System was not able to determine your Linux Machine Type (x86 or x86_64).";
	fi
elif [[ ! -f /opt/plesk/php/7.0/etc/php.ini ]]; then
	# PHP 7.0 not installed on this system
	syslogger "WARNING" "PHP7 is not installed on this system, therefore a Ioncube Deployment for PHP7 is not possible.";
elif [[ $PHP70_IONCUBE == 0 && -f /opt/plesk/php/7.0/etc/php.d/00-ioncube-loader.ini ]]; then
	# Uninstall the PHP 7.0 Ioncube Loader
	rm -f /opt/plesk/php/7.0/etc/php.d/00-ioncube-loader.ini
	plesk bin php_handler --reread
	syslogger "DONE" "The Uninstallation of the PHP 7.0 Ioncube Loader was successful.";
else
	# No PHP 7.0 Deploymet specified
	syslogger "INFO" "No Deployment for the PHP 7.0 Ioncube Loader specified, skip..";
fi

printf "\n###################################\n# Export Default / Custom Scripts #\n###################################\n";
if [[ ! -d $SCRIPTS_EXPORT_PATH ]]; then mkdir $SCRIPTS_EXPORT_PATH; fi

if [[ $SCRIPTS_DEFAULT == 1 || $SCRIPTS_CUSTOM == 1 ]]; then
	find $SCRIPTS_EXPORT_PATH -type f -exec rm -f {} \;

	if [[ $SCRIPTS_DEFAULT == 1 ]]; then
		find "$SCRIPTPATH/scripts/default/" -type f -exec /bin/cp -f {} $SCRIPTS_EXPORT_PATH \;
	fi

	if [[ $SCRIPTS_CUSTOM == 1 ]]; then
		find "$SCRIPTPATH/scripts/custom/" -type f -exec /bin/cp -f {} $SCRIPTS_EXPORT_PATH \;
	fi

	find $SCRIPTS_EXPORT_PATH -type f -exec chmod 700 {} \;
	syslogger "DONE" "All configured scripts have been copied to $SCRIPTS_EXPORT_PATH, you can call a script with yourscript.sh from anywhere.";
else
	syslogger "INFO" "Skipped Import of Scripts (scripts/)..";
fi

printf "\n###################################\n# Plesk Interface & System Prefs  #\n###################################\n";
# Plesk Localization
if [[ $PLESK_LOCALE != 0 ]]; then
	printf "Deploy Plesk Localization.. "; plesk bin server_pref --set-default -locale $PLESK_LOCALE; echo;
fi
# Plesk AutoUpdates
if [[ $PLESK_AUTOUPDATES == 1 ]]; then
	printf "Activate Plesk AutoUpdates.. "; plesk bin server_pref -u -autoupdates true; echo;
else
	printf "Deactivate Plesk AutoUpdates.. "; plesk bin server_pref -u -autoupdates false; echo;
fi
# Plesk AutoUpdates Third Party
fi [[ $PLESK_AUTOUPDATES_THIRD_PARTY == 1 ]]; then
	printf "Activate Plesk AutoUpdates Third Party.. "; plesk bin server_pref -u -autoupdates-third-party true; echo;
else
	printf "Deactivate Plesk AutoUpdates Third Party..  "; plesk bin server_pref -u -autoupdates-third-party false; echo;
fi
# Plesk Min Password Strength
if [[ $PLESK_MIN_PW_STRENGTH != 0 ]]; then
	printf "Deploy Plesk Min Password Strength.. "; plesk bin server_pref -u -min_password_strength $PLESK_MIN_PW_STRENGTH; echo;
fi
# Plesk Force DB Prefix
if [[ $PLESK_DB_FORCE_PREFIX == 1 ]]; then
	printf "Activate Force DB Prefix.. "; plesk bin server_pref -u -force-db-prefix true; echo;
else
	printf "Deactivate Force DB Prefix.. "; plesk bin server_pref -u -force-db-prefix false; echo;
fi

syslogger "DONE" "Finished Deployment of Plesk Interface & System Preferences.";

printf "\n###################################\n#    Plesk ModSecurity Firewall   #\n###################################\n";
if[[ $PLESK_MODSECURITY_FIREWALL == 1 ]]; then
	printf "Activate Web Application Firewall (ModSecurity) with Ruleset.. ";
	plesk bin server_pref --update-web-app-firewall -waf-rule-engine on -waf-rule-set $PLESK_MODSECURITY_FIREWALL_RULESET
else
	printf "Deactivate Web Application Firewall (ModSecurity).. ";
	plesk bin server_pref -waf-rule-engine off
fi

printf "\n###################################\n#         Plesk Firewall          #\n###################################\n";


printf "\n###################################\n#         Plesk Fail2Ban          #\n###################################\n";
if [[ $PLESK_FAIL2BAN == 1 ]]; then
	printf "Activating Fail2Ban:\n";
	plesk bin ip_ban --enable; echo;
	printf "Applying Ban Settings:\n";
	plesk bin ip_ban --update -ban_period $PLESK_FAIL2BAN_BAN_PERIOD -ban_time_window $PLESK_FAIL2BAN_BAN_TIME_WINDOW -max_retries $PLESK_FAIL2BAN_BAN_MAX_ENTRIES; echo;
	printf "Applying Jails:\n";
	printf "plesk-apache.. ";        plesk bin ip_ban --enable-jails plesk-apache; echo;
	printf "plesk-apache-badbot.. "; plesk bin ip_ban --enable-jails plesk-apache-badbot; echo;
	printf "plesk-courierimap.. ";   plesk bin ip_ban --enable-jails plesk-courierimap; echo;
	printf "plesk-horde.. ";         plesk bin ip_ban --enable-jails plesk-horde; echo;
	if[[ $PLESK_MODSECURITY_FIREWALL == 1 ]]; then
		printf "plesk-modsecurity.. ";   plesk bin ip_ban --enable-jails plesk-modsecurity; echo;
	fi
	printf "plesk-panel.. ";         plesk bin ip_ban --enable-jails plesk-panel; echo;
	printf "plesk-postfix.. ";       plesk bin ip_ban --enable-jails plesk-postfix; echo;
	printf "plesk-proftpd.. ";       plesk bin ip_ban --enable-jails plesk-proftpd; echo;
	printf "plesk-wordpress.. ";     plesk bin ip_ban --enable-jails plesk-wordpress; echo;
	printf "recidive.. ";            plesk bin ip_ban --enable-jails recidive; echo;
	printf "ssh.. ";                 plesk bin ip_ban --enable-jails ssh; echo;
	syslogger "DONE" "Finished Deployment of Plesk Fail2Ban (=>installed/activated).";
else
	printf "Deactivating Fail2Ban:\n";
	plesk bin ip_ban --disable
	syslogger "DONE" "Finished Deployment of Plesk Fail2Ban (=>deactivated).";
fi

printf "\n###################################\n#         Plesk Extensions        #\n###################################\n";
if [[ $PLESK_EXTENSIONS_DEPLOYMENT == 1 && ${#PLESK_EXTENSIONS[@]} -ne 0 ]]; then
  for ext in "${PLESK_EXTENSIONS[@]}"
  do
    printf "Deployment of ${ext}:\n";
    if [[ $ext =~ ".zip" ]]; then
      plesk bin extension --upgrade $ext; echo;
    elif [[ $ext =~ "http://" || $ext =~ "https://" ]]; then
      plesk bin extension --upgrade-url $ext; echo;
    fi
  done
	syslogger "DONE" "The Installation of the Plesk Extensions is finished (please check if there are any possible errors above).";
	printf "(please keep in mind that the Deployment isn't able to remove extensions)\n";
else
  syslogger "INFO" "No Plesk Extension Deployment specified or is deactivated, skip..";
	printf "(please keep in mind that the Deployment isn't able to remove extensions)\n";
fi

printf "\n###################################\n#       Deployment Finished       #\n###################################\n";
syslogger "DONE" "The Plesk Deployer has finished your Deployment. Please check the output from above to be sure that everything went fine. Enjoy your newly and freshly configured Server :)";
