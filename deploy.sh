#!/bin/bash

##########################
#    Bash Strict Mode    #
##########################
set -eu
IFS=$'\n\t'

##########################
#   Check Permissions    #
##########################
if (( $EUID != 0 )); then
    printf "Please run this script as root."; exit 1;
fi

##########################
#    Setup Variables     #
##########################
if (( -f `dirname $BASH_SOURCE`/config.cnf )); then 
	source `dirname $BASH_SOURCE`/config.cnf;
else
	printf "${NOW_EXT}: ${RED}ERROR: Please make sure a configuration file (config.cnf) is set.${NORMAL}" >> $ERROR_LOG; exit 1;
fi

##########################
#       Deployment       #
##########################

printf "###############################\n#    Deployment in progress..    #\n###############################\n";
printf "Init..\n";

printf "###############################\n#    Custom Bash Profiles Init    #\n###############################\n";
if (( $BASH_PROFILE_DEFAULT == 1 || $BASH_PROFILE_CUSTOM == 1 )); then
	if (( -f ~/.bash_profile )); then
		sed -i -e '/### BASH_PROFILE_DEFAULT ###/,/### BASH_PROFILE_DEFAULT ###/d' ~/.bash_profile
		sed -i -e '/### BASH_PROFILE_CUSTOM ###/,/### BASH_PROFILE_CUSTOM ###/d' ~/.bash_profile
	else
		printf "${NOW_EXT}: ${YELLOW}WARNING: File ~/.bash_profile wasn't found on your system. A new ~/.bash_profile will be created from your config.${NORMAL}" >> 
	fi
	
	if (( $BASH_PROFILE_DEFAULT == 1 )); then cat $SCRIPTPATH/configs/bash_profile.cnf >> ~/.bash_profile; fi
	if (( $BASH_PROFILE_CUSTOM == 1 )); then cat $SCRIPTPATH/configs_custom/bash_profile.cnf >> ~/.bash_profile; fi
	
	source ~/.bash_profile
	
	printf "${GREEN}FINISHED: The bash profiles have been successfully applied / added to ~/.bash_profile.${NORMAL}";
else
	printf "${UNDERLINE}INFO: No Bash Profile Configuration in your config.cnf selected, skip..${NORMAL}";
fi

printf "###############################\n#    Additional Linux Packages    #\n###############################\n";
if (( "${#DISTRO}" > 0 )); then
	if (( $DISTRO =~ "Ubuntu" || $DISTRO =~ "Debian" )); then 
		apt-get -y install $LINUX_PACKAGES
		LINUX_INSTALL_PCKGS=1
	elif (( $DISTRO =~ "centos" )); then
		yum -y install $LINUX_PACKAGES
		LINUX_INSTALL_PCKGS=1
	else
		printf "${NOW_EXT}: ${YELLOW}WARNING: Wasn't able to determine your Distro Type (e.g. CentOS, Ubuntu), therefor no linux packages have been installed.${NORMAL}" >> $ERROR_LOG;
	fi
fi

if (( $LINUX_INSTALL_PCKGS == 1 )); then
	printf "${GREEN}FINISHED: Installed the additional linux packages $LINUX_PACKAGES (please see the install process above to check if everything has been installed successfully).${NORMAL}";
else
	printf "${UNDERLINE}INFO: No Linux Packages Selected.${NORMAL}"
fi

printf "###############################\n#     Additional Nginx Conf's     #\n###############################\n";
if (( $NGINX_GZIP == 1 )); then
	rm -f /etc/nginx/conf.d/gzip.conf
	cp $SCRIPTPATH/configs/nginx_gzip.cnf /etc/nginx/conf.d/gzip.conf
	printf "${GREEN}FINISHED: Copied ${SCRIPTPATH}/configs/nginx_gzip.cnf to /etc/nginx/conf.d/gzip.conf${NORMAL}"
else
	printf "${UNDERLINE}INFO: Skipped nginx gzip configuration..${NORMAL}"
fi

printf "###############################\n#      Import Custom Scripts      #\n###############################\n";
if (( ! -d ~/bin )); then mkdir ~/bin; fi
/bin/cp -f $SCRIPTPATH/bin/* ~/bin
chmod 700 ~/bin/*
printf "${GREEN}FINISHED: All custom scripts have been copied to ~/bin you can call a script with yourscript.sh from anywhere.${NORMAL}";


