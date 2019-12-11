#!/bin/bash
# shellcheck source=/dev/null

### Bash Exit if a command exits with a non-zero status ###
set -e

### Include Global Configs ###
TMP_BF=$(dirname "$BASH_SOURCE");
if [[ -f $TMP_BF/system.cnf ]]; then
	source $TMP_BF/system.cnf;
else
	printf "$(date +"%Y-%m-%d_%M:%S") [ERROR]: Please make sure the configuration file system.cnf is set.\n" | tee -a $TMP_BF/logs/error.log;
	exit 1;
fi

if [[ -f $TMP_BF/config.cnf ]]; then
	source $TMP_BF/config.cnf;
else
	printf "$(date +"%Y-%m-%d_%M:%S") [ERROR]: Please make sure the configuration file config.cnf is set.\n" | tee -a $TMP_BF/logs/error.log;
	exit 1;
fi

### Debug Mode ###
if [[ $PD_DEBUG_MODE == 1 ]]; then
	set -x; # Turn off with set +x; again
fi

### Include Libraries ###
source $LIB_PATH/functions.sh

### Check System Requirements ###
if [[ $EUID != 0 ]]; then
	sysLogger "ERROR" "Please run this script as root.";
fi

if ! hash plesk 2>/dev/null; then
	sysLogger "ERROR" "Plesk is not installed on your System.";
fi

sysLogger "TEXT" "\n###################################\n#    Initialize Pre-Deployment    #\n###################################\n";
if [[ $PD_PRE_DEPLOYMENT != 0 && -f $PD_PRE_DEPLOYMENT ]]; then
	$PD_PRE_DEPLOYMENT | tee -a $LOG_DEPLOYMENT;
else
	sysLogger "INFO" "No Pre-Deployment set (skip).";
fi

sysLogger "TEXT" "\n################################\n#       Plesk Default/Custom Theme       #\n################################\n";
# PLESK CUSTOM THEME DEPLOYMENT
if [[ $PLESK_THEME_CUSTOM != 0 ]]; then
	if [[ -d "$PLESK_THEME_CUSTOM" ]]; then
		if [[ -f "$PLESK_THEME_CUSTOM/meta.xml" ]]; then
			rm -f "$TMP_PATH/plesk-theme.zip";
			zip "$TMP_PATH/plesk-theme.zip" "$PLESK_THEME_CUSTOM/*"
			plesk bin branding_theme -i -vendor admin -source $TMP_PATH/plesk-theme.zip
			sysLogger "DONE" "Finished Deployment of the Plesk Custom Theme ($PLESK_THEME_CUSTOM).";
		else
			sysLogger "INFO" "No custom theme deployment / meta.xml in $PLESK_THEME_CUSTOM found (skip).";
		fi
	elif [[ -f "$PLESK_THEME_CUSTOM" && "$PLESK_THEME_CUSTOM" = *".zip"* ]]; then
		plesk bin branding_theme -i -vendor admin -source $PLESK_THEME_CUSTOM
		sysLogger "DONE" "Finished Deployment of the Plesk Custom Theme ($PLESK_THEME_CUSTOM).";
	else
		sysLogger "WARNING" "Your plesk theme is neither a valid zip file nor a folder (skip).";
	fi
else
	sysLogger "INFO" "The Deployment of the Plesk Custom Theme is deactivated (skip).";
fi

# PLESK DEFAULT THEME DEPLOYMENT
# (Runs only if no CUSTOM PLESK THEME is set / available)
if [[ $PLESK_THEME_DEFAULT != 0 && ! $PLESK_THEME_CUSTOM = *".zip"* && ! -f $PLESK_THEME_CUSTOM/meta.xml ]]; then
	if [[ -d "$PLESK_THEME_DEFAULT" ]]; then
		if [[ -f "$PLESK_THEME_DEFAULT/meta.xml" ]]; then
			rm -f "$TMP_PATH/plesk-theme.zip";
			zip "$TMP_PATH/plesk-theme.zip" "$PLESK_THEME_DEFAULT/*" |& tee -a $LOG_DEPLOYMENT;
			plesk bin branding_theme -i -vendor admin -source $TMP_PATH/plesk-theme.zip
			sysLogger "DONE" "Finished Deployment of the Plesk DEFAULT Theme ($PLESK_THEME_DEFAULT).";
		else
			sysLogger "INFO" "No meta.xml in $PLESK_THEME_DEFAULT found (skip).";
		fi
	elif [[ -f "$PLESK_THEME_DEFAULT" && "$PLESK_THEME_DEFAULT" = *".zip"* ]]; then
		plesk bin branding_theme -i -vendor admin -source $PLESK_THEME_DEFAULT
		sysLogger "DONE" "Finished Deployment of the Plesk DEFAULT Theme ($PLESK_THEME_DEFAULT).";
	else
		sysLogger "WARNING" "Your Plesk DEFAULT Theme is neither a valid zip file nor a folder (skip).";
	fi
else
	sysLogger "INFO" "The Deployment of the Plesk DEFAULT Theme is deactivated (skip).";
fi

sysLogger "TEXT" "\n###################################\n#    Additional Linux Packages    #\n###################################\n";
if [[ "${#LINUX_DISTRO}" -gt 0 ]]; then
	if [[ $LINUX_DISTRO = *"Ubuntu"* || $LINUX_DISTRO = *"Debian"* ]]; then
		apt-get -y install $LINUX_PACKAGES | tee -a $LOG_DEPLOYMENT;
		LINUX_INSTALL_PCKGS=1
	elif [[ $LINUX_DISTRO = *"centos"* ]]; then
		yum -y install epel-release | tee -a $LOG_DEPLOYMENT;
		yum -y install $LINUX_PACKAGES | tee -a $LOG_DEPLOYMENT;
		LINUX_INSTALL_PCKGS=1
	else
		sysLogger "ERROR" "Wasn't able to determine your Distro Type (e.g. CentOS, Debian or Ubuntu), therefore no linux packages have been installed.";
	fi
fi

if [[ $LINUX_INSTALL_PCKGS == 1 ]]; then
	sysLogger "DONE" "The Deployment of the linux packages has finished (selected packages (config): $LINUX_PACKAGES), please see the install process above to check if everything has been installed successfully.";
else
	sysLogger "INFO" "No Linux Packages Selected / Installed (skip).";
fi

sysLogger "TEXT" "\n###################################\n#    Custom Bash Profiles Init    #\n###################################\n";
if [[ -f ~/.bash_profile ]]; then
	sed -i -e '/### PLESK_DEPLOYER ###/,/### PLESK_DEPLOYER ###/d' ~/.bash_profile | tee -a $LOG_DEPLOYMENT;
	sysLogger "INFO" "Old bash_profile Deployments have been removed (if any available).";
else
	sysLogger "WARNING" "File ~/.bash_profile wasn't found on your system. A new ~/.bash_profile will be created from your config (as long as CONFIGS_DEFAULT or CONFIGS_CUSTOM is set).";
fi

if [[ $CONFIGS_DEFAULT == 1 || $CONFIGS_CUSTOM == 1 ]]; then
	cat "$(getConfigFile bash_profile.cnf)" | tee -a ~/.bash_profile $LOG_DEPLOYMENT;

	sysLogger "DONE" "The bash profiles have been successfully applied / added to ~/.bash_profile.";
else
	sysLogger "INFO" "No Bash Profile Configuration possible due to your config.cnf configuration (skip).";
fi

sysLogger "TEXT" "\n###################################\n#       Plesk Nginx Package       #\n###################################\n";
if [[ $NGINX_DEPLOYMENT == 1 ]]; then
	# Install Nginx
	# plesk installer --select-product-id plesk --select-release-current --reinstall-patch --install-component nginx
	plesk installer --select-product-id plesk --select-release-current --install-component nginx | tee -a $LOG_DEPLOYMENT;
	if [[ -f /etc/nginx/nginx.conf ]]; then nginx -t -c /etc/nginx/nginx.conf | tee -a $LOG_DEPLOYMENT; fi
	sysLogger "DONE" "Plesk Nginx Package was installed successfully.";

	if [[ -f /usr/local/psa/admin/sbin/nginxmng ]]; then
		/usr/local/psa/admin/sbin/nginxmng --enable # or plesk sbin nginxmng --enable
		sysLogger "DONE" "Enabled nginx through the nginx plesk manager (/usr/local/psa/admin/sbin/nginxmng --enable).";
	fi

	if hash systemctl 2>/dev/null; then
		if [[ "$(systemctl enable nginx.service 2>/dev/null)" ]]; then
			systemctl enable nginx.service

			if [[ "$(systemctl status nginx)" =~ "Active: failed" || "$(systemctl status nginx)" =~ "Loaded: failed" ]]; then
				sysLogger "WARNING" "Due to the current nginx service systemctl configurations nginx won't start until you activate it, please make sure that the service in plesk is in active use (e.g. activate nginx in plesk on a domain).";
			else
				systemctl restart nginx.service
			fi

			sysLogger "DONE" "Enabled nginx Autostart (systemctl).";
		else
			sysLogger "WARNING" "No systemctl service nginx found or failed to execute (skip, see also: https://www.nginx.com/resources/wiki/start/topics/examples/systemd/)";
		fi
	elif hash chkconfig 2>/dev/null; then
		chkconfig nginx on # Does not work if on IPv6 (count's for systemctl as well of course), see the fix: https://kb.plesk.com/en/128261
		sysLogger "DONE" "Enabled nginx Autostart (chkconfig).";
	else
		sysLogger "WARNING" "Wasn't able to enable Nginx Autostart (no systemctl or chkconfig on your system detected).";
	fi

	# Bugfix - Nginx does not start automatically after reboot: 99: Cannot assign requested address
	# (See also: https://support.plesk.com/hc/en-us/articles/213908925-Nginx-does-not-start-automatically-after-reboot-99-Cannot-assign-requested-address)
	# (See also: https://www.hosteurope.de/faq/server/server-allgemeines/aenderung-hostname/)
	if [[ $NGINX_REQ_ADDR_99_FIX == 1 ]]; then
		sed -ie 's/network.target/network-online.target/g' /etc/systemd/system/multi-user.target.wants/nginx.service

		if [[ -f /etc/init.d/named ]]; then
			/etc/init.d/named restart # Restart DNS / Named / BIND
		fi
	fi

	sysLogger "DONE" "Finished Deployment of Plesk Nginx (please check if there are any possible errors above).";
elif [[ $NGINX_DEPLOYMENT == -1 ]]; then # Disable Nginx
	if [[ -f /usr/local/psa/admin/sbin/nginxmng ]]; then
		/usr/local/psa/admin/sbin/nginxmng --disable # or plesk sbin nginxmng --disable
		sysLogger "DONE" "Disabled nginx through the nginx plesk manager (/usr/local/psa/admin/sbin/nginxmng).";
	else
		sysLogger "INFO" "Nginx Deactivation skipped (skip). The plesk nginx manager hasn't been found (/usr/local/psa/admin/sbin/nginxmng).";
	fi
else # Skip Nginx Deployment
	sysLogger "INFO" "The Nginx Deployment is deactivated (skip).";
fi

sysLogger "TEXT" "\n###################################\n#        Plesk Nginx Conf's       #\n###################################\n";
getConfigFile nginx_gzip.cnf; # Return exit 1 if the check fails
echo;

if [[ $NGINX_GZIP == 1 ]]; then
	rm -f /etc/nginx/conf.d/gzip.conf
	cp "$(getConfigFile nginx_gzip.cnf)" /etc/nginx/conf.d/gzip.conf | tee -a $LOG_DEPLOYMENT;
	sysLogger "DONE" "Copied $(getConfigFile nginx_gzip.cnf) to /etc/nginx/conf.d/gzip.conf";
else
	sysLogger "INFO" "Nginx gzip configuration is deactivated (skip).";
fi

sysLogger "TEXT" "\n###################################\n#        Plesk PHP Packages       #\n###################################\n";
if [[ $PHP_DEPLOYMENT == 1 ]]; then
	# PHP Deployment Variables
	PHP_VERSIONS_ALL=( "7.3" "7.2" "7.1" "7.0" "5.6" "5.5" "5.4" "5.3" "5.2" )
	PHP_VERSIONS_DIFF=($(arrayDiff PHP_VERSIONS_ALL[@] PHP_VERSIONS[@]))
	TMP_PHP_DEPLOYMENT=0

	# PHP Deployment Installation
	if [[ ${#PHP_VERSIONS[@]} -gt 0 ]]; then
		for phpv in "${PHP_VERSIONS[@]}"
		do
			if [[ ! -f /opt/plesk/php/${phpv}/etc/php.ini ]]; then
				sysLogger "INFO" "Installation of PHP ${phpv}:";
				plesk installer --select-product-id plesk --select-release-current --install-component php${phpv} | tee -a $LOG_DEPLOYMENT;
				sysLogger "DONE" "Installation of PHP ${phpv} is finished (please check if there are any possible errors above).";
				TMP_PHP_DEPLOYMENT=1;
			fi
		done
	fi

	# PHP Deployment Uninstallation
	if [[ ${#PHP_VERSIONS_DIFF[@]} -gt 0 ]]; then
		for phpv_delete in "${PHP_VERSIONS_DIFF[@]}"
		do
			if [[ -f /opt/plesk/php/${phpv_delete}/etc/php.ini ]]; then
				sysLogger "INFO" "Uninstall of PHP ${phpv_delete}:";
				plesk installer --select-product-id plesk --select-release-current --remove-component php${phpv_delete} | tee -a $LOG_DEPLOYMENT;
				sysLogger "DONE" "Uninstall of PHP ${phpv_delete} is finished (please check if there are any possible errors above).";
				TMP_PHP_DEPLOYMENT=1;
			fi
		done
	fi

	# PHP Deployment Satus Message
	if [[ $TMP_PHP_DEPLOYMENT == 0 ]]; then
		sysLogger "INFO" "Your PHP Versions \"${PHP_VERSIONS[*]}\" are already installed (skip).";
	fi
fi

sysLogger "TEXT" "\n##################################\n#        Database Deployment       #\n###################################\n";
if [[ $DB_DEPLOYMENT == 1 ]]; then
	TMP_DB_CONF_FILE=/etc/my.cnf

	if [[ -f "$TMP_DB_CONF_FILE" ]]; then
		if [[ -n "$DB_INNODB_BUFFER_POOL_SIZE" && $DB_INNODB_BUFFER_POOL_SIZE != 0 ]]; then
			setConfVarInFile "innodb_buffer_pool_size" "$DB_INNODB_BUFFER_POOL_SIZE" "$TMP_DB_CONF_FILE";
			sysLogger "INFO" "innodb_buffer_pool_size set to ${DB_INNODB_BUFFER_POOL_SIZE}";
		fi
		if [[ -n "$DB_INNODB_ADDITIONAL_MEM_POOL_SIZE" && $DB_INNODB_ADDITIONAL_MEM_POOL_SIZE != 0 ]]; then
			setConfVarInFile "innodb_additional_mem_pool_size" "$DB_INNODB_ADDITIONAL_MEM_POOL_SIZE" "$TMP_DB_CONF_FILE";
			sysLogger "INFO" "innodb_additional_mem_pool_size set to ${DB_INNODB_ADDITIONAL_MEM_POOL_SIZE}";
		fi
		if [[ -n "$DB_INNODB_LOG_BUFFER_SIZE" && $DB_INNODB_LOG_BUFFER_SIZE != 0 ]]; then
			setConfVarInFile "innodb_log_buffer_size" "$DB_INNODB_LOG_BUFFER_SIZE" "$TMP_DB_CONF_FILE";
			sysLogger "INFO" "innodb_log_buffer_size set to ${DB_INNODB_LOG_BUFFER_SIZE}";
		fi
		if [[ -n "$DB_INNODB_THREAD_CONCURRENCY" && $DB_INNODB_THREAD_CONCURRENCY != 0 ]]; then
			setConfVarInFile "innodb_thread_concurrency" "$DB_INNODB_THREAD_CONCURRENCY" "$TMP_DB_CONF_FILE";
			sysLogger "INFO" "innodb_thread_concurrency set to ${DB_INNODB_THREAD_CONCURRENCY}";
		fi
		if [[ -n "$DB_QUERY_CACHE_SIZE" && $DB_QUERY_CACHE_SIZE != 0 ]]; then
			setConfVarInFile "query_cache_size" "$DB_QUERY_CACHE_SIZE" "$TMP_DB_CONF_FILE";
			sysLogger "INFO" "query_cache_size set to ${DB_QUERY_CACHE_SIZE}";
		fi
	else
		sysLogger "WARNING" "No DB Config found in $TMP_DB_CONF_FILE";
	fi
else
	sysLogger "INFO" "The DB Deployment is deactivated (skip).";
fi

sysLogger "TEXT" "\n###################################\n# Export Default / Custom Scripts #\n###################################\n";
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
	sysLogger "DONE" "All configured scripts have been copied to $SCRIPTS_EXPORT_PATH, you can call a script with yourscript.sh from anywhere.";
else
	sysLogger "INFO" "Skipped Import of Scripts (scripts/)..";
fi

sysLogger "TEXT" "\n###################################\n# Plesk Interface & System Prefs  #\n###################################\n";
# Plesk Localization
if [[ $PLESK_LOCALE != 0 ]]; then
	sysLogger "TEXT" "Deploy Plesk Localization to ${PLESK_LOCALE}.. "; plesk bin server_pref --set-default -locale $PLESK_LOCALE | tee -a $LOG_DEPLOYMENT;
fi
# Plesk AutoUpdates
if [[ $PLESK_AUTOUPDATES == 1 ]]; then
	sysLogger "TEXT" "Activate Plesk AutoUpdates.. "; plesk bin server_pref -u -autoupdates true | tee -a $LOG_DEPLOYMENT;
else
	sysLogger "TEXT" "Deactivate Plesk AutoUpdates.. "; plesk bin server_pref -u -autoupdates false | tee -a $LOG_DEPLOYMENT;
fi
# Plesk AutoUpdates Third Party
if [[ $PLESK_AUTOUPDATES_THIRD_PARTY == 1 ]]; then
	sysLogger "TEXT" "Activate Plesk AutoUpdates Third Party.. "; plesk bin server_pref -u -autoupdates-third-party true | tee -a $LOG_DEPLOYMENT;
else
	sysLogger "TEXT" "Deactivate Plesk AutoUpdates Third Party..  "; plesk bin server_pref -u -autoupdates-third-party false | tee -a $LOG_DEPLOYMENT;
fi
# Plesk Min Password Strength
if [[ $PLESK_MIN_PW_STRENGTH != 0 ]]; then
	sysLogger "TEXT" "Deploy Plesk Min Password Strength to ${PLESK_MIN_PW_STRENGTH}.. "; plesk bin server_pref -u -min_password_strength $PLESK_MIN_PW_STRENGTH | tee -a $LOG_DEPLOYMENT;
fi
# Plesk Force DB Prefix
if [[ $PLESK_DB_FORCE_PREFIX == 1 ]]; then
	sysLogger "TEXT" "Activate Force DB Prefix.. "; plesk bin server_pref -u -force-db-prefix true | tee -a $LOG_DEPLOYMENT;
else
	sysLogger "TEXT" "Deactivate Force DB Prefix.. "; plesk bin server_pref -u -force-db-prefix false | tee -a $LOG_DEPLOYMENT;
fi

sysLogger "DONE" "Finished Deployment of Plesk Interface & System Preferences.";

sysLogger "TEXT" "\n###################################\n#    Plesk ModSecurity Firewall   #\n###################################\n";
if [[ $PLESK_MODSECURITY_FIREWALL == 1 ]]; then
	sysLogger "TEXT" "Activating Web Application Firewall (ModSecurity) with Ruleset \"${PLESK_MODSECURITY_FIREWALL_RULESET}\"..\n";

	if [[ $PLESK_MODSECURITY_FIREWALL_RULESET && $PLESK_MODSECURITY_FIREWALL_CONFIG_PRESET ]]; then
		plesk bin server_pref --update-web-app-firewall -waf-rule-engine on -waf-rule-set $PLESK_MODSECURITY_FIREWALL_RULESET -waf-rule-set-update-period $PLESK_MODSECURITY_FIREWALL_UPDATE_PERIOD -waf-config-preset $PLESK_MODSECURITY_FIREWALL_CONFIG_PRESET | tee -a $LOG_DEPLOYMENT;
	else
		plesk bin server_pref --update-web-app-firewall -waf-rule-engine on -waf-rule-set $PLESK_MODSECURITY_FIREWALL_RULESET | tee -a $LOG_DEPLOYMENT;
	fi

	if [[ $PLESK_MODSECURITY_FIREWALL_RULESET == "tortix" ]]; then
		if ! hash aum 2>/dev/null; then
			aum configure
			aum upgrade
		else
			sysLogger "ERROR" "Command aum not found (probably the Atomicorp ruleset wasn't correctly installed).";
		fi
	fi

	plesk sbin modsecurity_ctl --disable | tee -a $LOG_DEPLOYMENT;
	plesk sbin modsecurity_ctl --enable | tee -a $LOG_DEPLOYMENT;
	service apache2 restart | tee -a $LOG_DEPLOYMENT;
	service httpd restart | tee -a $LOG_DEPLOYMENT;
	sysLogger "DONE" "Finished Deployment of the Web Application Firewall (ModSecurity) with Ruleset \"${PLESK_MODSECURITY_FIREWALL_RULESET}\".";
elif [[ $PLESK_MODSECURITY_FIREWALL == -1 ]]; then
	sysLogger "TEXT" "Deactivating Web Application Firewall (ModSecurity)..\n";
	plesk bin server_pref --update-web-app-firewall -waf-rule-engine off | tee -a $LOG_DEPLOYMENT;
	plesk sbin modsecurity_ctl --disable | tee -a $LOG_DEPLOYMENT;
	service httpd restart | tee -a $LOG_DEPLOYMENT;
	sysLogger "DONE" "Finished deactivating ModSecurity.";
else
	sysLogger "INFO" "The Web Application Firewall Deployment is deactivated (skip).";
fi

sysLogger "TEXT" "\n###################################\n#         Plesk Fail2Ban          #\n###################################\n";
if [[ $PLESK_FAIL2BAN == 1 ]]; then
	sysLogger "TEXT" "Activating Fail2Ban:\n";
	plesk bin ip_ban --enable | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "Applying Ban Settings:\n";
	plesk bin ip_ban --update -ban_period $PLESK_FAIL2BAN_BAN_PERIOD -ban_time_window $PLESK_FAIL2BAN_BAN_TIME_WINDOW -max_retries $PLESK_FAIL2BAN_BAN_MAX_ENTRIES | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "Applying Jails:\n";
	sysLogger "TEXT" "plesk-apache.. ";        plesk bin ip_ban --enable-jails plesk-apache | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "plesk-apache-badbot.. "; plesk bin ip_ban --enable-jails plesk-apache-badbot | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "plesk-courierimap.. ";   plesk bin ip_ban --enable-jails plesk-courierimap | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "plesk-horde.. ";         plesk bin ip_ban --enable-jails plesk-horde | tee -a $LOG_DEPLOYMENT; echo;
	if [[ $PLESK_MODSECURITY_FIREWALL == 1 ]]; then
		sysLogger "TEXT" "plesk-modsecurity.. "; plesk bin ip_ban --enable-jails plesk-modsecurity | tee -a $LOG_DEPLOYMENT; echo;
	else
		sysLogger "TEXT" "plesk-modsecurity (disable).. "; plesk bin ip_ban --disable-jails plesk-modsecurity | tee -a $LOG_DEPLOYMENT; echo;
	fi
	sysLogger "TEXT" "plesk-panel.. ";         plesk bin ip_ban --enable-jails plesk-panel | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "plesk-postfix.. ";       plesk bin ip_ban --enable-jails plesk-postfix | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "plesk-proftpd.. ";       plesk bin ip_ban --enable-jails plesk-proftpd | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "plesk-wordpress.. ";     plesk bin ip_ban --enable-jails plesk-wordpress | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "recidive.. ";            plesk bin ip_ban --enable-jails recidive | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "TEXT" "ssh.. ";                 plesk bin ip_ban --enable-jails ssh | tee -a $LOG_DEPLOYMENT; echo;
	sysLogger "DONE" "Finished Deployment of Plesk Fail2Ban (=>installed/activated).";
else
	sysLogger "TEXT" "Deactivating Fail2Ban:\n";
	plesk bin ip_ban --disable | tee -a $LOG_DEPLOYMENT;
	sysLogger "DONE" "Finished Deployment of Plesk Fail2Ban (=>deactivated).";
fi

sysLogger "TEXT" "\n###################################\n#         Plesk Extensions        #\n###################################\n";
if [[ $PLESK_EXTENSIONS_DEPLOYMENT == 1 && ${#PLESK_EXTENSIONS[@]} -ne 0 ]]; then
  for ext in "${PLESK_EXTENSIONS[@]}"
  do
    sysLogger "TEXT" "Deployment of ${ext}:\n";
    if [[ $ext = *".zip"* ]]; then
      plesk bin extension --upgrade $ext | tee -a $LOG_DEPLOYMENT; echo;
    elif [[ $ext = *"http://"* || $ext = *"https://"* ]]; then
      plesk bin extension --upgrade-url $ext | tee -a $LOG_DEPLOYMENT; echo;
    fi
  done
	sysLogger "DONE" "The Installation of the Plesk Extensions is finished (please check if there are any possible errors above).";
	sysLogger "TEXT" "(please keep in mind that the Deployment isn't able to remove extensions)\n";
else
  sysLogger "INFO" "No Plesk Extension Deployment specified or is deactivated (skip).";
	sysLogger "TEXT" "(please keep in mind that the Deployment isn't able to remove extensions)\n";
fi

sysLogger "TEXT" "\n###################################\n#    Mail Serverwide Settings     #\n###################################\n";
sysLogger "TEXT" "Deploying Mail Serverwide Settings..\n"

if [[ $MAIL_DEPLOYMENT == 1 ]]; then

	if [[ "${#MAIL_MAPS_ZONES}" -gt 0 && $MAIL_MAPS_ZONES != 0 ]]; then
		if [[ $MAIL_MAPS_ZONES = *"--"* ]]; then
			TMP_MAIL_MAPS_ZONES=$(echo $MAIL_MAPS_ZONES | tr --delete "--")
			plesk bin mailserver --add-maps-zone $TMP_MAIL_MAPS_ZONES
		else
			plesk bin mailserver --add-maps-zone $MAIL_MAPS_ZONES
		fi

		if [[ $MAIL_MAPS_STATUS == 1 ]]; then
			plesk bin mailserver --set-maps-status true
		elif [[ $MAIL_MAPS_STATUS == 0 ]]; then
			plesk bin mailserver --set-maps-status false
		fi
	fi

	if [[ "${#MAIL_AUTH}" -gt 0 && $MAIL_AUTH != 0 && "$MAIL_AUTH" == "smtp" ]]; then
		plesk bin mailserver --set-relay auth -auth-type $MAIL_AUTH
	elif [[ $MAIL_AUTH_LOCK_TIME -gt 0 && $MAIL_AUTH != 0 ]]; then
		plesk bin mailserver --set-relay auth -auth-type both -lock-time $MAIL_AUTH_LOCK_TIME
	fi

	if [[ $MAIL_MAX_SIZE != 0 ]]; then
		plesk bin mailserver --set-max-letter-size $MAIL_MAX_SIZE
	fi

	if [[ $MAIL_MAX_CONNECTIONS -gt 0 ]]; then
		plesk bin mailserver --set-max-connections $MAIL_MAX_CONNECTIONS
	fi

	if [[ $MAIL_MAX_CONNECTIONS_PER_IP -gt 0 ]]; then
		plesk bin mailserver --set-max-connections-per-ip $MAIL_MAX_CONNECTIONS_PER_IP
	fi

	if [[ $MAIL_SIGN_OUTGOING_MAIL == 1 ]]; then
		plesk bin mailserver --sign-outgoing-mail true
	elif [[ $MAIL_SIGN_OUTGOING_MAIL == 0 ]]; then
		plesk bin mailserver --sign-outgoing-mail false
	fi

	if [[ $MAIL_VERIFY_INCOMING_MAIL == 1 ]]; then
		plesk bin mailserver --verify-incoming-mail true
	elif [[ $MAIL_VERIFY_INCOMING_MAIL == 0 ]]; then
		plesk bin mailserver --verify-incoming-mail false
	fi

	sysLogger "DONE" "The Mail Serverwide Settings Deployment seems finished (please check if any errors above occured)."
else
	sysLogger "INFO" "The Mail Serverwide Settings Deployment is disabled (skip)."
fi

sysLogger "TEXT" "\n###################################\n#     Mail Outgoing Antispam      #\n###################################\n";
sysLogger "TEXT" "Deploying Mail Outgoing Antispam..\n"

if [[ $MAIL_OUTGOING_ANTISPAM == 1 ]]; then
	plesk bin mailserver --enable-outgoing-antispam
elif [[ $MAIL_OUTGOING_ANTISPAM == 0 ]]; then
	plesk bin mailserver --disable-outgoing-antispam
fi
if [[ $MAIL_OUTGOING_ANTISPAM_MAILBOX_LIMIT -gt 0 ]]; then
	plesk bin mailserver --set-outgoing-messages-mbox-limit $MAIL_OUTGOING_ANTISPAM_MAILBOX_LIMIT
fi
if [[ $MAIL_OUTGOING_ANTISPAM_DOMAIN_LIMIT -gt 0 ]]; then
	plesk bin mailserver --set-outgoing-messages-domain-limit $MAIL_OUTGOING_ANTISPAM_DOMAIN_LIMIT
fi
if [[ $MAIL_OUTGOING_ANTISPAM_SUBSCRIPTION_LIMIT -gt 0 ]]; then
	plesk bin mailserver --set-outgoing-messages-subscription-limit $MAIL_OUTGOING_ANTISPAM_SUBSCRIPTION_LIMIT
fi

sysLogger "DONE" "The Mail Outgoing Antispam Deployment seems finished (please check if any errors above occured)."

sysLogger "TEXT" "\n###################################\n#       Plesk Spam Assassin       #\n###################################\n";
sysLogger "TEXT" "Deploy Spam Assassin..\n";

if [[ -n $SPAM_ASSASSIN && $SPAM_ASSASSIN == 1 ]]; then
	if [[ $MAIL_MAPS_STATUS == 1 ]]; then
		plesk bin mailserver --set-maps-status true
	fi

	if [[ -n $SPAM_ASSASSIN_SCORE && $SPAM_ASSASSIN_SCORE -ge 1 ]]; then
		plesk bin spamassassin --update-server -hits $SPAM_ASSASSIN_SCORE
	elif [[ -n $SPAM_ASSASSIN_SCORE && $SPAM_ASSASSIN_SCORE != -1 ]]; then
		sysLogger "WARNING" "SPAM_ASSASSIN_SCORE (skip): Please use a number higher than 0."
	fi

	if [[ -n $SPAM_ASSASSIN_MAX_PROC && $SPAM_ASSASSIN_MAX_PROC -ge 1 && $SPAM_ASSASSIN_MAX_PROC -le 5 ]]; then
		plesk bin spamassassin --update-server -max-proc $SPAM_ASSASSIN_MAX_PROC
	elif [[ -n $SPAM_ASSASSIN_MAX_PROC && $SPAM_ASSASSIN_MAX_PROC != -1 ]]; then
		sysLogger "WARNING" "SPAM_ASSASSIN_MAX_PROC (skip): Please use a number between 1 and 5."
	fi

	sysLogger "DONE" "Finished Deployment of Spam Assassin (activated). \nSpamassassin Score: ${SPAM_ASSASSIN_SCORE}\nSpamassassin Max Proc: ${SPAM_ASSASSIN_MAX_PROC}"
elif [[ -n $SPAM_ASSASSIN && $SPAM_ASSASSIN == 0 ]]; then
	if [[ $MAIL_MAPS_STATUS == 0 ]]; then
		plesk bin mailserver --set-maps-status false
	fi
	sysLogger "DONE" "Finished Deployment of Spam Assassin (deactivated)."
else
	sysLogger "INFO" "The Deployment of Spam Assassin is disabled (skip)."
fi

sysLogger "TEXT" "\n###################################\n#      ProFTPD Passive Ports      #\n###################################\n";
sysLogger "TEXT" "Deploying ProFTPD Passive Ports for ProFTPD..\n";
if [[ $FTP_PASSIVE_PORTS != 0 ]]; then
	if [[ -d /etc/proftpd.d/ ]]; then
		printf "PassivePorts ${FTP_PASSIVE_PORTS}" > /etc/proftpd.d/passive_ports.conf;
		service xinetd restart | tee -a $LOG_DEPLOYMENT;
		sysLogger "DONE" "Finished Deployment of ProFTPD Passive Ports (Portrange: ${FTP_PASSIVE_PORTS}).";
	else
		sysLogger "ERROR" "The folder /etc/proftpd.d/ is missing, maybe ProFTPD isn't installed on your System.";
	fi
elif [[ -f /etc/proftpd.d/passive_ports.conf ]]; then
	rm -f /etc/proftpd.d/passive_ports.conf
	service xinetd restart | tee -a $LOG_DEPLOYMENT;
	sysLogger "DONE" "Finished Deployment of removing the ProFTPD Passive Ports.";
else
	sysLogger "INFO" "ProFTPD Passive Port Deployment is deactivated (skip).";
fi

sysLogger "TEXT" "\n###################################\n#         Change SSH Port         #\n###################################\n";
TMP_SSH_PORT_REGEX='^(?!#)Port\s(?<!-)\b([1-3]?\d{1,5}|65535)\b'
TMP_SSH_PORT_REGEX_COMMENT='^(#|#\s)Port\s(?<!-)\b([1-3]?\d{1,5}|65535)\b'
TMP_SSHD_CONFIG_PATH=/etc/ssh/sshd_config

if [[ $SSH_PORT != 0 ]]; then
	if [[ "$(grep -P ${TMP_SSH_PORT_REGEX} ${TMP_SSHD_CONFIG_PATH} | head -1)" != "Port ${SSH_PORT}" ]]; then
		if [[ "$(grep -P ${TMP_SSH_PORT_REGEX} ${TMP_SSHD_CONFIG_PATH})" ]]; then
			perl -pi -e "s/${TMP_SSH_PORT_REGEX}/Port ${SSH_PORT}/;" $TMP_SSHD_CONFIG_PATH | tee -a $LOG_DEPLOYMENT;
		elif [[ "$(grep -P ${TMP_SSH_PORT_REGEX_COMMENT} ${TMP_SSHD_CONFIG_PATH})" ]]; then
			perl -pi -e "s/${TMP_SSH_PORT_REGEX_COMMENT}/Port ${SSH_PORT}/;" $TMP_SSHD_CONFIG_PATH | tee -a $LOG_DEPLOYMENT;
		else
			printf "Port ${SSH_PORT}" | tee -a $TMP_SSHD_CONFIG_PATH $LOG_DEPLOYMENT;
		fi

		service sshd reload | tee -a $LOG_DEPLOYMENT;
		sysLogger "DONE" "Finished Deployment of Changing the SSH Port to ${SSH_PORT}.";
		sysLogger "INFO" "Please try to connect to the Server with another User Session separately now, just in case if something went really wrong, then in this case you can change the configuration in /etc/ssh/sshd_config back from your current User Session and restart the sshd service (service sshd reload).";
	else
		sysLogger "INFO" "The SSH Port is already set accordingly to your configurations (skip).";
	fi
else
	sysLogger "INFO" "The Deployment of the SSH Port Change is deactivated (skip).";
fi

sysLogger "TEXT" "\n###################################\n#         Plesk Firewall          #\n###################################\n";
# https://support.plesk.com/hc/en-us/articles/115002552134-How-to-manage-Plesk-Firewall-via-CLI-
# Problematic Implementation because of the firewall confirmation parameter/action (/usr/local/psa/bin/modules/firewall/settings -c)
# Therefore it has to be done manually

sysLogger "INFO" "The Plesk Firewall can't be enabled automatically, because of a special ssh confirmation security check.";
sysLogger "INFO" "If you wan't the Plesk Firewall to be enabled (recommended), then please do it manually in your plesk panel (or use custom iptables).";
sysLogger "INFO" "(for more informations please look up https://support.plesk.com/hc/en-us/articles/115000629013-How-to-install-Plesk-Firewall)";

# Add Firewall SSH Port Ruleset
# (due to the SSH Port Change Deployment)
if [[ $PLESK_FIREWALL != 0 ]]; then
	if [[ $SSH_PORT != 0 ]]; then
		if [[ $(iptables -S | grep "port $SSH_PORT") ]]; then
			# Add Firewall Ruleset to Plesk Firewall
			mysql -uadmin -p"$(cat /etc/psa/.psa.shadow)" -e "USE psa; INSERT INTO module_firewall_rules (id, configuration_id, direction, priority, object)VALUES(69, 1, 0, 21, 'a:8:{s:4:\"type\";s:6:\"custom\";s:5:\"class\";s:6:\"custom\";s:4:\"name\";s:15:\"SSH Connections\";s:9:\"direction\";s:5:\"input\";s:5:\"ports\";a:2:{i:0;s:9:\"$SSH_PORT/tcp\";i:1;s:9:\"$SSH_PORT/udp\";}s:4:\"from\";a:0:{}s:6:\"action\";s:5:\"allow\";s:10:\"originalId\";s:2:\"47\";}');" |& tee -a $LOG_DEPLOYMENT;
			mysql -uadmin -p"$(cat /etc/psa/.psa.shadow)" -e "USE psa; SELECT * FROM module_firewall_rules WHERE id=69;" |& tee -a $LOG_DEPLOYMENT;

			# Add Firewall Ruleset to iptables (will be overwritten by the Plesk Firewall if active)
			# (see also: https://support.plesk.com/hc/en-us/articles/115001078014-How-to-manage-local-firewall-rules-on-a-Plesk-for-Linux-server)
			iptables -I INPUT -p tcp --dport $SSH_PORT -m state --state NEW -j ACCEPT
			iptables -I INPUT -p udp --dport $SSH_PORT -m state --state NEW -j ACCEPT
			service iptables save

			sysLogger "INFO" "The following iptable rules have been added: "
			iptables -S | grep $SSH_PORT |& tee -a $LOG_DEPLOYMENT;
		else
			sysLogger "INFO" "The firewall deployment adds currently only firewall settings for the SSH Port Change Deployment, there is currently no SSH Port set (skip).";
		fi
	fi
else
	sysLogger "INFO" "No Firewall Deployment set (skip).";
fi

sysLogger "TEXT" "\n###################################\n#       Clean Up Tmp Folder       #\n###################################\n";
if [[ -n "$TMP_PATH" ]]; then
	rm -Rf "${TMP_PATH:?}/"*
	sysLogger "DONE" "Cleanup of $TMP_PATH was successful.";
else
	sysLogger "WARNING" "The Folder $TMP_PATH doesn't exist.";
fi

sysLogger "TEXT" "\n###################################\n#   Initialize After-Deployment   #\n###################################\n";
if [[ $PD_AFT_DEPLOYMENT != 0 && -f $PD_AFT_DEPLOYMENT ]]; then
	$PD_AFT_DEPLOYMENT | tee -a $LOG_DEPLOYMENT;
else
	sysLogger "INFO" "No Aft-Deployment set (skip).";
fi

sysLogger "TEXT" "\n###################################\n#       Deployment Finished       #\n###################################\n";
sysLogger "DONE" "The Plesk Deployer has finished your Deployment. Please check the output from above to be sure that everything went fine. Enjoy your newly and freshly configured Server :)";
mailAdmin;
