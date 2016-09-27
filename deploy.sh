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
if [[ -f `dirname $BASH_SOURCE`/config.cnf ]]; then 
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
if [[ $BASH_PROFILE_DEFAULT == 1 || $BASH_PROFILE_CUSTOM == 1 ]]; then
	if [ -f ~/.bash_profile ]; then
		if [ $BASH_PROFILE_DEFAULT == 1 ]; then $SCRIPTPATH/configs/bash_profile_default.cnf > $SCRIPTPATH/configs/bash_profile_mixed.cnf; fi
		if [ $BASH_PROFILE_CUSTOM == 1 ]; then $SCRIPTPATH/configs/bash_profile_custom.cnf >> $SCRIPTPATH/configs/bash_profile_mixed.cnf; fi

		BASH_PROFILE_ORIG=$(cat ~/.bash_profile)
		# while read line; do
		while read -r line || [[ -n "$line" ]]; do
			if [[ ! $line =~ $BASH_PROFILE_ORIG ]]; then
				printf $line >> ~/.bash_profile
			fi
		done < $SCRIPTPATH/configs/bash_profile_mixed.cnf
		rm -f $SCRIPTPATH/configs/bash_profile_mixed.cnf
		
		printf "${GREEN}FINISHED: The bash profiles have been successfully applied / added to ~/.bash_profile.${NORMAL}";
	else
		cp $SCRIPTPATH/configs/bash_profile_default.cnf ~/.bash_profile
		chmod 644 ~/.bash_profile
		printf "${NOW_EXT}: ${YELLOW}WARNING: File ~/.bash_profile wasn't found on your system. A new ~/.bash_profile has been created from your config.${NORMAL}" >> $ERROR_LOG;
	fi
else
	printf "${UNDERLINE}INFO: No Bash Profile Configuration in your config.cnf selected, skip..${NORMAL}";
fi

printf "###############################\n#    Additional Linux Packages    #\n###############################\n";
if [[ $DISTRO =~ "Ubuntu" || $DISTRO =~ "Debian" ]]; then 
	apt-get -y install $LINUX_PACKAGES
	LINUX_INSTALL_PCKGS=1
elif [[ $DISTRO =~ "centos" ]]; then
	yum -y install $LINUX_PACKAGES
	LINUX_INSTALL_PCKGS=1
else
	printf "${YELLOW}WARNING: Wasn't able to determine your Distro Type (e.g. CentOS, Ubuntu), therefor no linux packages have been installed.${NORMAL}";
fi

if [[ $LINUX_INSTALL_PCKGS == 1 ]]; then
	printf "${GREEN}FINISHED: Installed the additional linux packages (please see the install process above to check if everything has been installed successfully).${NORMAL}";
fi

printf "###############################\n#     Additional Nginx Conf's     #\n###############################\n";
rm -f /etc/nginx/conf.d/pd_gzip.conf
cp $SCRIPTPATH/configs/nginx_gzip.cnf /etc/nginx/conf.d/pd_gzip.conf
printf "${GREEN}FINISHED: ${SCRIPTPATH}/configs/nginx_gzip.cnf to /etc/nginx/conf.d/pd_gzip.conf"
