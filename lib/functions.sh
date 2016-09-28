### getConfig Function ###
function getConfig(){
	if [[ -n "$1" ]]; then
		if [[ $CONFIGS_CUSTOM == 1 && -f $CONFIGS_PATH_CUSTOM/$1 ]]; then
			printf $CONFIGS_PATH_CUSTOM/$1
		elif [[ $CONFIGS_DEFAULT == 1 && -f $CONFIGS_PATH_DEFAULT/$1 ]]; then
			printf $CONFIGS_PATH_DEFAULT/$1
		else
			syslogger "ERROR" "No file $CONFIGS_PATH_DEFAULT/$1 found."
		fi
	else
		syslogger "ERROR" "The getConfig() function got no parameter.";
	fi
}

function syslogger(){
	case "$1" in
		"ERROR") printf "${RED}${MSG_ERROR} $2 ${MSG_NORMAL}\n"; printf "$(currentTime) [ERROR]: $2 \n" >> $ERROR_LOG; exit 1;;
		"WARNING") printf "${YELLOW}${MSG_WARNING} $2 ${MSG_NORMAL}\n"; printf "$(currentTime) [WARNING]: $2 \n" >> $ERROR_LOG;;
		"INFO") printf "${UNDERLINE}${MSG_INFO} $2 ${MSG_NORMAL}\n";;
		"DONE") printf "${GREEN}${MSG_DONE} $2 ${MSG_NORMAL}\n";;
	esac
}

function currentTime(){
	printf $(date +"$TIME_FORMAT");
}

function currentTimeFile(){
	printf $(date +"$TIME_FORMAT_FILE");
}
