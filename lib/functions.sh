### getConfig() - Usage: getConfig <configFileName> ###
# Usage: getConfig <configFileName>
# Example: getConfig nginx_gzip.cnf
# Parameter: <configFileName> Can be any name that is available in configs/default or configs/custom
# Meaning: Outputs/Returns the Path to the right config file depending on the config.cnf settings
function getConfig(){
	if [[ -n "$1" ]]; then
		if [[ $CONFIGS_CUSTOM == 1 && -f $CONFIGS_PATH_CUSTOM/$1 ]]; then
			printf $CONFIGS_PATH_CUSTOM/$1
		elif [[ $CONFIGS_DEFAULT == 1 && -f $CONFIGS_PATH_DEFAULT/$1 ]]; then
			printf $CONFIGS_PATH_DEFAULT/$1
		elif [[ $CONFIGS_DEFAULT != 1 && $CONFIGS_CUSTOM != 1 ]]; then
			sysLogger "INFO" "Both of your configs_default and configs_custom are turned off. Skip config import of $1.."
		else
			sysLogger "ERROR" "No file ${CONFIGS_PATH_DEFAULT}/$1 found."
		fi
	else
		sysLogger "ERROR" "The getConfig() function got no parameter.";
	fi
}

### sysLogger() ###
# Usage: sysLogger <type> <message>
# Example: sysLogger "ERROR" "This is a Error Message."
# Parameter: <type> Can be ERROR, WARNING, INFO or DONE
# Parameter: <message> Just a normal Text to inform the User that something happened
# Meaning: Outputs/Returns specific Messages (and outputs them to a file if it's a "ERROR" type)
function sysLogger(){
	# Check if the Function has been properly accessed
	if [[ ! ${2+x} ]]; then
		printf "${RED}${MSG_ERROR} sysLogger() Parameters missing. E.g. sysLogger <type> <message>\n(possible types are: ${MSG_TYPES}) ${MSG_RESET}\n"; printf "$(currentTime) [$1]: sysLogger() Parameters missing.\n" >> $LOG_ERROR; exit 1;
	fi

	# Write Log Deployment
	printf "$2\n" >> $LOG_DEPLOYMENT;

	# SysLogger Message Output & Error Logging
	case "$1" in
		"ERROR") printf "\n${RED}${MSG_ERROR} $2 ${MSG_RESET}\n"; mailAdmin "$1" "$2"; printf "$(currentTime) [$1]: $2 \n" >> $LOG_ERROR; exit 1;;
		"WARNING") printf "\n${YELLOW}${MSG_WARNING} $2 ${MSG_RESET}\n"; printf "$(currentTime) [$1]: $2 \n" >> $LOG_ERROR;;
		"INFO") printf "\n${UNDERLINE}${MSG_INFO} $2 ${MSG_RESET}\n";;
		"DONE") printf "\n${GREEN}${MSG_DONE} $2 ${MSG_RESET}\n";;
		"TEXT") printf "$2";;
		*) printf "\n${RED}${MSG_ERROR} sysLogger() Wrong parameter <type> given. E.g. sysLogger <type> <message>\n(possible types are: ${MSG_TYPES}) ${MSG_RESET}\n"; printf "$(currentTime) [$1]: sysLogger() Wrong type given. \n" >> $LOG_ERROR; exit 1;;
	esac
}

### mailAdmin ###
# Usage: mailAdmin <subject> <yourMessage>
# Example: mailAdmin "ERROR" "Your Message"
function mailAdmin(){
	if [[ $PD_ADMIN_MAIL != 0 && "${#PD_ADMIN_MAIL}" > 0 ]]; then
		echo "$2" | mail -s "Plesk Deployer - $1" "$PD_ADMIN_MAIL";
	fi
}

### arrayDiff() ###
# Usage: arrayDiff <array1> <array2>
# Example: array3=$($(arrayDiff array1[@] array2[@]))	# Saves the Difference / Result as a Array
# Meaning: Compares two arrays to each other and returns the Difference (diff)
function arrayDiff(){
	awk 'BEGIN{RS=ORS=" "}
       {NR==FNR?a[$0]++:a[$0]--}
       END{for(k in a)if(a[k])print k}' <(echo -n "${!1}") <(echo -n "${!2}")
}

### currentTime() ###
# Usage: currentTime
# Meaning: Outputs/Returns the current Time
function currentTime(){
	printf $(date +"$TIME_FORMAT");
}

### currentTimeFile() ###
# Usage: currentTimeFile
# Meaning: Outputs/Returns the current Time as a valid File Format
function currentTimeFile(){
	printf $(date +"$TIME_FORMAT_FILE");
}
