#!/bin/bash

### Bash Strict Mode ###
set -eu
IFS=$'\n\t'

### Setup Variables ###
if (( -f $(dirname $BASH_SOURCE) )); then 
	source $(dirname $BASH_SOURCE);
else
	printf "$(date +"%Y-%m-%d-%M%S") [ERROR]: Please make sure a configuration file (config.cnf) is set." >> $(dirname $BASH_SOURCE)/logs/error.log; exit 1;
fi

### Check Requirements ###
if (( $EUID != 0 )); then
    printf "${MSG_ERROR} Please run this script as root.${MSG_NORMAL}" >> $ERROR_LOG; exit 1;
fi

if ! hash plesk 2>/dev/null; then
	printf "${MSG_ERROR} Plesk is not installed on your System.${MSG_NORMAL}" >> $ERROR_LOG; exit 1; 
fi

printf "###############################\n#      Deployment in progress..     #\n###############################\n";
printf "Init..\n";

printf "\n###############################\n#    Custom Bash Profiles Init    #\n###############################\n";
if (( $BASH_PROFILE_DEFAULT == 1 || $BASH_PROFILE_CUSTOM == 1 )); then
	if (( -f ~/.bash_profile )); then
		sed -i -e '/### BASH_PROFILE_DEFAULT ###/,/### BASH_PROFILE_DEFAULT ###/d' ~/.bash_profile
		sed -i -e '/### BASH_PROFILE_CUSTOM ###/,/### BASH_PROFILE_CUSTOM ###/d' ~/.bash_profile
	else
		printf "${MSG_WARNING} File ~/.bash_profile wasn't found on your system. A new ~/.bash_profile will be created from your config.${MSG_NORMAL}" >> $ERROR_LOG;
	fi
	
	if (( $BASH_PROFILE_DEFAULT == 1 )); then cat $CONFIGS_DEFAULT/bash_profile.cnf >> ~/.bash_profile; fi
	if (( $BASH_PROFILE_CUSTOM == 1 )); then 
		if (( -f $CONFIGS_CUSTOM/bash_profile.cnf )); then
			cat $CONFIGS_CUSTOM/bash_profile.cnf >> ~/.bash_profile;
		else
			printf "${MSG_WARNING} File $CONFIGS_CUSTOM/bash_profile.cnf doesn't exist, skip..${MSG_NORMAL}" >> $ERROR_LOG;
		fi
	fi
	
	source ~/.bash_profile
	printf "${MSG_DONE} The bash profiles have been successfully applied / added to ~/.bash_profile.${MSG_NORMAL}";
else
	printf "${MSG_INFO} No Bash Profile Configuration in your config.cnf selected, skip..${MSG_NORMAL}";
fi

printf "\n###############################\n#    Additional Linux Packages    #\n###############################\n";
if (( "${#DISTRO}" > 0 )); then
	if (( $DISTRO =~ "Ubuntu" || $DISTRO =~ "Debian" )); then 
		apt-get -y install $LINUX_PACKAGES
		LINUX_INSTALL_PCKGS=1
	elif (( $DISTRO =~ "centos" )); then
		yum -y install $LINUX_PACKAGES
		LINUX_INSTALL_PCKGS=1
	else
		printf "${MSG_WARNING} Wasn't able to determine your Distro Type (e.g. CentOS, Ubuntu), therefor no linux packages have been installed.${MSG_NORMAL}" >> $ERROR_LOG;
	fi
fi

if (( $LINUX_INSTALL_PCKGS == 1 )); then
	printf "${MSG_DONE} Installed the additional linux packages $LINUX_PACKAGES (please see the install process above to check if everything has been installed successfully).${MSG_NORMAL}";
else
	printf "${MSG_INFO} No Linux Packages Selected.${MSG_NORMAL}";
fi

printf "\n###############################\n#     Additional Nginx Conf's     #\n###############################\n";
if (( $NGINX_GZIP == 1 )); then
	rm -f /etc/nginx/conf.d/gzip.conf
	cp $CONFIGS_DEFAULT/nginx_gzip.cnf /etc/nginx/conf.d/gzip.conf
	printf "${MSG_DONE} Copied ${SCRIPTPATH}/configs/default/nginx_gzip.cnf to /etc/nginx/conf.d/gzip.conf${MSG_NORMAL}";
else
	printf "${MSG_INFO} Skipped nginx gzip configuration..${MSG_NORMAL}";
fi

printf "\n###############################\n#      Import Custom Scripts      #\n###############################\n";
if (( ! -d ~/bin )); then mkdir ~/bin; fi
/bin/cp -f $SCRIPTPATH/bin/* ~/bin
chmod 700 ~/bin/*
printf "${MSG_DONE} All custom scripts have been copied to ~/bin you can call a script with yourscript.sh from anywhere.${MSG_NORMAL}";

printf "\n###############################\n#       Deployment Finished       #\n###############################\n";
printf "${MSG_DONE} The plesk deployer has finished your deployment.${MSG_NORMAL}";
