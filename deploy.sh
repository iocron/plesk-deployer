#!/bin/bash

### Bash Strict Mode ###
set -eu
IFS=$'\n\t'

### Include Global Config ###
TMP_BF=$(dirname $BASH_SOURCE);
if [[ -f $TMP_BF/config.cnf ]]; then
	source $TMP_BF/config.cnf;
else
	printf "$(date +"%Y-%m-%d-%M%S") [ERROR]: Please make sure a configuration file (config.cnf) is set.\n" | tee -a $TMP_BF/logs/error.log; exit 1;
fi

### Include Library ###
source $LIB_PATH/functions.sh

### Check Requirements ###
if [[ $EUID != 0 ]]; then
	syslogger "ERROR" "Please run this script as root.";
fi

if ! hash plesk 2>/dev/null; then
	syslogger "ERROR" "Plesk is not installed on your System."; 
fi

printf "###############################\n#      Deployment in progress..     #\n###############################\n";
printf "Init..\n";

printf "\n###############################\n#    Custom Bash Profiles Init    #\n###############################\n";
if [[ $CONFIGS_DEFAULT == 1 || $CONFIGS_CUSTOM == 1 ]]; then
	if [[ -f ~/.bash_profile ]]; then
		sed -i -e '/### BASH_PROFILE_DEFAULT ###/,/### BASH_PROFILE_DEFAULT ###/d' ~/.bash_profile
		sed -i -e '/### BASH_PROFILE_CUSTOM ###/,/### BASH_PROFILE_CUSTOM ###/d' ~/.bash_profile
	else
		syslogger "WARNING" "File ~/.bash_profile wasn't found on your system. A new ~/.bash_profile will be created from your config.";
	fi
	
	cat $(getConfig bash_profile.cnf) >> ~/.bash_profile;
	source ~/.bash_profile
	
	syslogger "DONE" "The bash profiles have been successfully applied / added to ~/.bash_profile.";
else
	syslogger "INFO" "No Bash Profile Configuration in your config.cnf selected, skip..";
fi

printf "\n###############################\n#    Additional Linux Packages    #\n###############################\n";
if [[ "${#DISTRO}" > 0 && $DISTRO != 0 ]]; then
	if [[ $DISTRO =~ "Ubuntu" || $DISTRO =~ "Debian" ]]; then 
		apt-get -y install $LINUX_PACKAGES
		LINUX_INSTALL_PCKGS=1
	elif [[ $DISTRO =~ "centos" ]]; then
		yum -y install $LINUX_PACKAGES
		LINUX_INSTALL_PCKGS=1
	else
		syslogger "WARNING" "Wasn't able to determine your Distro Type (e.g. CentOS, Ubuntu), therefor no linux packages have been installed.";
	fi
fi

if [[ $LINUX_INSTALL_PCKGS == 1 ]]; then
	syslogger "DONE" "Installed the additional linux packages $LINUX_PACKAGES (please see the install process above to check if everything has been installed successfully)";
else
	syslogger "INFO" "No Linux Packages Selected / Installed, skip..";
fi

printf "\n###############################\n#     Additional Nginx Conf's     #\n###############################\n";
if [[ $NGINX_GZIP == 1 ]]; then
	getConfig nginx_gzip.cnf; # Return exit 1 if the check fails
	
	rm -f /etc/nginx/conf.d/gzip.conf
	cp $(getConfig nginx_gzip.cnf) /etc/nginx/conf.d/gzip.conf
	syslogger "DONE" "Copied $(getConfig nginx_gzip.cnf) to /etc/nginx/conf.d/gzip.conf";
else
	syslogger "INFO" "Skipped nginx gzip configuration..";
fi

printf "\n###############################\n#      Import Custom Scripts      #\n###############################\n";
if [[ ! -d ~/bin ]]; then mkdir ~/bin; fi
if [[ $SCRIPTS_DEFAULT == 1 ]]; then /bin/cp -f $SCRIPTPATH/scripts/default/* ~/bin; fi
if [[ $SCRIPTS_CUSTOM == 1 ]]; then /bin/cp -f $SCRIPTPATH/scripts/custom/* ~/bin; fi
chmod 700 ~/bin/*
syslogger "DONE" "All custom scripts have been copied to ~/bin you can call a script with yourscript.sh from anywhere.";

printf "\n###############################\n#       Deployment Finished       #\n###############################\n";
syslogger "DONE" "The plesk deployer has finished your deployment.";
