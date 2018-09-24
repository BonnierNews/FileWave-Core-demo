#!/bin/bash

YO="/Applications/Utilities/yo.app/Contents/MacOS/yo"

FileWave-loggedin-username() {
	echo "$(stat -f%Su /dev/console)"
}
FileWave-loggedin-uid() {
	echo $(id -u $USERNAME 2>/dev/null)
}

FileWave-app-postflight() {
	USERNAME="$(FileWave-loggedin-username)"
	APP_PS="$1"
	APP_NAME="$2"
	APP_PATH="$3"
	CHOWN="$4"
	APP_ICON="$5"

	if [[ ${USERNAME} != "root" ]]; then
		if [[ "${CHOWN}" == "true" ]]; then
			chown -R ${USERNAME} "${APP_PATH}"
		fi
		# Check for running App
		if [[ "$(pgrep -lx "${APP_PS}" | awk '{print$2}')" != "" ]]; then
			# If all files are re-used for the fileset, don't inform the user!
			if [[ "$(tail -7 /var/log/fwcld.log | grep "(100 percent of data) for Fileset:")" == "" ]]; then
				USERID=$(FileWave-loggedin-uid)
				launchctl asuser ${USERID} $YO -t "Ny version av ${APP_NAME}" -n "Du bör starta om programmmet för att undvika problem." -i "${APP_ICON}"
			fi
		fi
	fi
}
FileWave-app-verify-chown() {
	USERNAME="$(FileWave-loggedin-username)"
	APP_PATH="$1"
	if [ ${USERNAME} != "root" ]; then
		chown -R ${USERNAME} "${APP_PATH}"
	fi
}

FileWave-unload-LaunchAgent() {
	# $1 = name of or path to LaunchAgent
	if [[ -f /Library/LaunchAgents/$1 ]]; then
		PLIST_PATH=/Library/LaunchAgents/$1
	else
		PLIST_PATH="$1"
	fi
	if [[ -f "${PLIST_PATH}" ]]; then
		sudo -u ${USERNAME} launchctl unload "${PLIST_PATH}"
	fi
}
FileWave-reload-LaunchAgent() {
	# $1 = name of or path to LaunchAgent
	if [[ -f /Library/LaunchAgents/$1 ]]; then
		PLIST_PATH=/Library/LaunchAgents/$1
	else
		PLIST_PATH="$1"
	fi
	if [[ -f "${PLIST_PATH}" ]]; then
		sudo -u ${USERNAME} launchctl unload "${PLIST_PATH}"
		sudo -u ${USERNAME} launchctl load -S Aqua "${PLIST_PATH}"
	fi
}

FileWave-unload-LaunchDaemon() {
	# $1 = name of or path to LaunchDaemon
	if [[ -f /Library/LaunchDaemons/$1 ]]; then
		PLIST_PATH=/Library/LaunchDaemons/$1
	else
		PLIST_PATH="$1"
	fi
	if [[ -f "${PLIST_PATH}" ]]; then
		launchctl unload "${PLIST_PATH}"
	fi
}
FileWave-reload-LaunchDaemon() {
	# $1 = name of or path to LaunchDaemon
	if [[ -f /Library/LaunchDaemons/$1 ]]; then
		PLIST_PATH=/Library/LaunchDaemons/$1
	else
		PLIST_PATH="$1"
	fi
	if [[ -f "${PLIST_PATH}" ]]; then
		launchctl unload "${PLIST_PATH}"
		launchctl load "${PLIST_PATH}"
	fi
}

FileWave-unload-extension() {
	# $1 = name of or path to Extension
	if [[ -d "${1}" ]]; then
		KEXT_BUNDLEID="$(defaults read "${1}/Contents/Info.plist" CFBundleIdentifier)"
		if [[ ! "$(kextstat -l | grep ${KEXT_BUNDLEID})" == "" ]]; then
			kextunload -b "${KEXT_BUNDLEID}"
		fi
	fi
}
FileWave-reload-extension() {
	# $1 = name of or path to Extension
	if [[ -d "${1}" ]]; then
		KEXT_BUNDLEID="$(defaults read "${1}/Contents/Info.plist" CFBundleIdentifier)"
		if [[ ! "$(kextstat -l | grep ${KEXT_BUNDLEID})" == "" ]]; then
			kextunload -b "${KEXT_BUNDLEID}"
		fi
		kextload "${1}"
	fi
}

FileWave-getuserdir() {
	# $1 = username
	if [[ -f /usr/local/sbin/getuserdir ]]; then
		echo $(/usr/local/sbin/getuserdir $1)
	else
		echo $(dscl localhost read /Local/Default/Users/$USERNAME NFSHomeDirectory | awk -F ": " '{print$2}')
	fi
}

FileWave-get-inventory-data() {
	# $1 = FileWave custom field

	UNCODED_STRING="$(cat /var/FileWave/custom.ini | grep ${1} | awk -F "${1}=" '{print $2}')"
	if [[ "$(echo "${UNCODED_STRING}" | grep "\\\\xc3")" == "" ]]; then
		THE_CUSTOM_VALUE="$(printf "${UNCODED_STRING}" | iconv -f ISO-8859-1 -t UTF-8)"
	else
		THE_CUSTOM_VALUE="$(printf "${UNCODED_STRING}" | iconv -f UTF-8 -t UTF-8)"
	fi
	if [[ "${PREV_CUSTOM_VALUE}" == "@Invalid()" ]]; then
		THE_CUSTOM_VALUE=""
	fi
	echo "${THE_CUSTOM_VALUE}"

}
FileWave-set-inventory-data() {
	if [[ "$1" == "" ]]; then
		if [[ "$2" == "" ]]; then
			# Clear value of $1
			/usr/local/sbin/FileWave.app/Contents/MacOS/fwcld -custom_write -key $1 >/dev/null
		else
			# Add value to custom_string
			/usr/local/sbin/FileWave.app/Contents/MacOS/fwcld -custom_write -key $1 -value "$2" -silent
		fi
	fi
}

FileWave-add-loggedin-to-group() {
	if [[ -n $1 ]] && [[ ! ${USERNAME} == "root" ]]; then
		if [[ $(dseditgroup -o checkmember -m ${USERNAME} $1 | awk '{print$1}') == "no" ]]; then
			dseditgroup -o edit -a ${USERNAME} -t user $1
		fi
	fi
}

USERNAME="$(FileWave-loggedin-username)"

# get path to PlistBuddy
if [[ -f /usr/libexec/PlistBuddy ]]; then
	PLIST_BUDDY=/usr/libexec/PlistBuddy
elif [[ -f /usr/local/sbin/PlistBuddy ]]; then
	PLIST_BUDDY=/usr/local/sbin/PlistBuddy
fi
