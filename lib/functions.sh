### getConfig() - Usage: getConfig <configFileName> ###
# Usage: getConfig <configFileName>
# Usage Example: getConfig nginx_gzip.cnf
# Parameter: <configFileName> Can be any name that is available in configs/default or configs/custom
# Meaning: Outputs/Returns the Path to the right config file depending on the config.cnf settings
function getConfig(){
	if [[ -n "$1" ]]; then
		if [[ $CONFIGS_CUSTOM == 1 && -f $CONFIGS_PATH_CUSTOM/$1 ]]; then
			printf $CONFIGS_PATH_CUSTOM/$1
		elif [[ $CONFIGS_DEFAULT == 1 && -f $CONFIGS_PATH_DEFAULT/$1 ]]; then
			printf $CONFIGS_PATH_DEFAULT/$1
		elif [[ $CONFIGS_DEFAULT != 1 && $CONFIGS_CUSTOM != 1 ]]; then
			syslogger "INFO" "Both of your configs_default and configs_custom are turned off. Skip config import of $1.."
		else
			syslogger "ERROR" "No file ${CONFIGS_PATH_DEFAULT}/$1 found."
		fi
	else
		syslogger "ERROR" "The getConfig() function got no parameter.";
	fi
}

### syslogger() ###
# Usage: syslogger <type> <message>
# Usage Example: syslogger "ERROR" "This is a Error Message."
# Parameter: <type> Can be ERROR, WARNING, INFO or DONE
# Parameter: <message> Just a normal Text to Inform the User
# Meaning: Logs or Outputs/Returns specific Messages (and outputs them to a file if it is a error)
function syslogger(){
	if [[ ! ${2+x} ]]; then
		printf "${RED}${MSG_ERROR} syslogger() Parameters missing. E.g. syslogger <type> <message>\n(possible types are: ${MSG_TYPES}) ${MSG_RESET}\n"; printf "$(currentTime) [ERROR]: syslogger() Parameters missing.\n" >> $ERROR_LOG; exit 1;
	fi

	case "$1" in
		"ERROR") printf "\n${RED}${MSG_ERROR} $2 ${MSG_RESET}\n"; printf "$(currentTime) [ERROR]: $2 \n" >> $ERROR_LOG; exit 1;;
		"WARNING") printf "\n${YELLOW}${MSG_WARNING} $2 ${MSG_RESET}\n"; printf "$(currentTime) [WARNING]: $2 \n" >> $ERROR_LOG;;
		"INFO") printf "\n${UNDERLINE}${MSG_INFO} $2 ${MSG_RESET}\n";;
		"DONE") printf "\n${GREEN}${MSG_DONE} $2 ${MSG_RESET}\n";;
		*) printf "\n${RED}${MSG_ERROR} syslogger() Wrong parameter <type> given. E.g. syslogger <type> <message>\n(possible types are: ${MSG_TYPES}) ${MSG_RESET}\n"; printf "$(currentTime) [ERROR]: syslogger() Wrong type given. \n" >> $ERROR_LOG; exit 1;;
	esac
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
