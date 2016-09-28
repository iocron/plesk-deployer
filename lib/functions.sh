### getConfig Function ###
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

function syslogger(){
	if [[ ! ${2+x} ]]; then
		printf "${RED}${MSG_ERROR} syslogger() Parameters missing. E.g. syslogger <type> <message>\n(possible types are: ${MSG_TYPES}) ${MSG_RESET}\n"; printf "$(currentTime) [ERROR]: syslogger() Parameters missing.\n" >> $ERROR_LOG; exit 1;
	fi
	
	case "$1" in
		"ERROR") printf "${RED}${MSG_ERROR} $2 ${MSG_RESET}\n"; printf "$(currentTime) [ERROR]: $2 \n" >> $ERROR_LOG; exit 1;;
		"WARNING") printf "${YELLOW}${MSG_WARNING} $2 ${MSG_RESET}\n"; printf "$(currentTime) [WARNING]: $2 \n" >> $ERROR_LOG;;
		"INFO") printf "${UNDERLINE}${MSG_INFO} $2 ${MSG_RESET}\n";;
		"DONE") printf "${GREEN}${MSG_DONE} $2 ${MSG_RESET}\n";;
		*) printf "${RED}${MSG_ERROR} syslogger() Wrong parameter <type> given. E.g. syslogger <type> <message>\n(possible types are: ${MSG_TYPES}) ${MSG_RESET}\n"; printf "$(currentTime) [ERROR]: syslogger() Wrong type given. \n" >> $ERROR_LOG; exit 1;;
	esac
}

function currentTime(){
	printf $(date +"$TIME_FORMAT");
}

function currentTimeFile(){
	printf $(date +"$TIME_FORMAT_FILE");
}
