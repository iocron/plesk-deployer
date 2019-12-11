### getConfigFile() - Usage: getConfigFile <configFileName> ###
# Usage: getConfigFile <configFileName>
# Example: getConfigFile nginx_gzip.cnf
# Parameter: <configFileName> Can be any name that is available in configs/default or configs/custom
# Meaning: Outputs/Returns the Path to the right config file depending on the config.cnf settings
function getConfigFile(){
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
		sysLogger "ERROR" "The getConfigFile() function got no parameter.";
	fi
}

### sysLogger() ###
# Usage: sysLogger <type> <message>
# Example: sysLogger "ERROR" "This is a Error Message."
# Parameter: <type> Can be ERROR, WARNING, INFO, DONE or TEXT
# Parameter: <message> Just a normal Text to inform the User that something happened
# Meaning: Outputs/Returns specific Messages (and outputs them to a file if it's a "ERROR" type)
function sysLogger(){
	# Check if the Function has been properly accessed
	if [[ ! ${1+x} && ! ${2+x} ]]; then
		printf "${RED}${MSG_ERROR} sysLogger() Parameters missing. E.g. sysLogger <type> <message>\n(possible types are: ${MSG_TYPES}) ${MSG_RESET}\n"; printf "$(currentTime) [$1]: sysLogger() Parameters missing.\n" >> $LOG_ERROR; exit 1;
	fi

	# Write Deployment Logging
		if [[ "$1" == "TEXT" ]]; then
			printf "$2" >> $LOG_DEPLOYMENT;
		else
			printf "[$1]: $2\n" >> $LOG_DEPLOYMENT;
		fi
	#fi

	# Write Error Logging & Output Messages
	case "$1" in
		"ERROR") printf "\n${RED}${MSG_ERROR} $2 ${MSG_RESET}\n"; if [[ $PD_ADMIN_MAIL_SEND_LOG == "LOG_ERROR" || $PD_ADMIN_MAIL_SEND_LOG == "LOG_ALL" ]]; then mailAdmin "$1" "$2"; fi; printf "$(currentTime) [$1]: $2 \n" >> $LOG_ERROR; exit 1;;
		"WARNING") printf "\n${YELLOW}${MSG_WARNING} $2 ${MSG_RESET}\n"; printf "$(currentTime) [$1]: $2 \n" >> $LOG_ERROR;;
		"INFO") printf "\n${UNDERLINE}${MSG_INFO} $2 ${MSG_RESET}\n";;
		"DONE") printf "\n${GREEN}${MSG_DONE} $2 ${MSG_RESET}\n";;
		"TEXT") printf "$2";;
		*) printf "\n${RED}${MSG_ERROR} sysLogger() Wrong parameter <type> given. E.g. sysLogger <type> <message>\n(possible types are: ${MSG_TYPES}) ${MSG_RESET}\n"; printf "$(currentTime) [$1]: sysLogger() Wrong type given. \n" >> $LOG_ERROR; exit 1;;
	esac
}

### mailAdmin ###
# Usage: mailAdmin OR mailAdmin <subject> <yourMessage>
# Example1: mailAdmin # Sends all Logs (Log Deployment) or no Logs to the Admin (based on the config settings)
# Example2: mailAdmin "A Error occurred" "Your Message.." # Send only a specific Message to the Admin
function mailAdmin(){
	if [[ $PD_ADMIN_MAIL != 0 && "${#PD_ADMIN_MAIL}" > 0 && $PD_ADMIN_MAIL_SEND_LOG != 0 ]]; then
		if [[ ${1+x} && ${2+x} ]]; then
			echo "$2" | mail -s "Plesk Deployer - $1" "$PD_ADMIN_MAIL";
		elif [[ $PD_ADMIN_MAIL_SEND_LOG == "LOG_DEPLOYMENT" || $PD_ADMIN_MAIL_SEND_LOG == "LOG_ALL" ]]; then
			sysLogger "DONE" "A Email with the content of the Log Deployment will be sent to ${PD_ADMIN_MAIL}.";
			mail -s "Plesk Deployer - Deployment Log (deployment_$TIME_STAMP_FILE.log)" "$PD_ADMIN_MAIL" < $LOG_DEPLOYMENT
		else
			sysLogger "WARNING" "Wrong Admin Mail Log type specified or no Log type specified at all (see PD_ADMIN_MAIL and PD_ADMIN_MAIL_SEND_LOG)";
		fi
	else
		sysLogger "INFO" "The mailAdmin functionality isn't activated, skip..";
	fi
}

### setConfVarInFile() ###
# Usage: setConfVarInFile <variableName> <variableValue> <file>
function setConfVarInFile(){
	if [[ $# -eq 3 ]]; then
		TMP_CONF_KEY=$1
		TMP_CONF_VALUE=$2
		TMP_FILE=$3

		TMP_REGEX="^(?!#)${TMP_CONF_KEY}[=\s]\K.+"
		TMP_REGEX_COMMENT_WITH_EQUAL_SIGN="^(#|#\s)${TMP_CONF_KEY}=.*"
		TMP_REGEX_COMMENT_WITH_SPACE="^(#|#\s)${TMP_CONF_KEY}\s.*"

		if [[ -f "$TMP_FILE" ]]; then
			if [[ "$(grep -P ${TMP_REGEX} ${TMP_FILE} | head -1)" != "$1 ${TMP_CONF_VALUE}" ]]; then
				if [[ "$(grep -P ${TMP_REGEX} ${TMP_FILE})" ]]; then
					perl -pi -e "s/${TMP_REGEX}/${TMP_CONF_VALUE}/;" $TMP_FILE | tee -a $LOG_DEPLOYMENT;
				elif [[ "$(grep -P ${TMP_REGEX_COMMENT_WITH_EQUAL_SIGN} ${TMP_FILE})" ]]; then
					perl -pi -e "s/${TMP_REGEX_COMMENT_WITH_EQUAL_SIGN}/${TMP_CONF_KEY}=${TMP_CONF_VALUE}/;" $TMP_FILE | tee -a $LOG_DEPLOYMENT;
				elif [[ "$(grep -P ${TMP_REGEX_COMMENT_WITH_SPACE} ${TMP_FILE})" ]]; then
					perl -pi -e "s/${TMP_REGEX_COMMENT_WITH_SPACE}/${TMP_CONF_KEY} ${TMP_CONF_VALUE}/;" $TMP_FILE | tee -a $LOG_DEPLOYMENT;
				elif [[ $(grep -P '^(?!#).*=' $TMP_FILE) ]]; then
					printf "$1=${TMP_CONF_VALUE}" | tee -a $TMP_FILE $LOG_DEPLOYMENT;
				elif [[ $(grep -P '^(?!#).*[ ]' $TMP_FILE) ]]; then
					printf "$1 ${TMP_CONF_VALUE}" | tee -a $TMP_FILE $LOG_DEPLOYMENT;
				else
					sysLogger "WARNING" "No allocation of the config file format found (no variables found).";
				fi
			else
				sysLogger "INFO" "The replacement operation has been skipped, because this entry already exists.";
			fi
		else
			sysLogger "WARNING" "String replacement failed, the file ${TMP_FILE} does not exist.";
		fi
	else
		sysLogger "WARNING" "setConfVarInFile() needs 3 Parameters. This operation has been skipped..";
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
