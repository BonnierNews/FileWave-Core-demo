#!/bin/bash

source /Library/BonnierNews-Storage/Bonnier-Common/Scripts/FileWave-Core.sh
# APP_PS="$1"
# APP_NAME="$2"
# APP_PATH="$3"
# CHOWN="$4"
# APP_ICON="$5"

FileWave-app-postflight \
"firefox"\
 "Firefox" \
"/Users/Shared/Applications/Firefox.app" \
"true" \
"/Users/Shared/Applications/Firefox.app/Contents/Resources/firefox.icns"

exit 0

