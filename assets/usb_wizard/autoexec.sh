#!/bin/bash

TOOL_NAME="Auto setup"
VERSION=0.1

export PATH=$PATH:/bin/:/sbin/:/usr/bin/:/usr/sbin/:
cd $(dirname $0)

msg() {
	if [ $# -lt 1 ]; then
		psplashBuffer=""
		echo
		return
	fi

	sleep 2

	while [ $# -gt 0 ]; do
		echo -e $1; sync
		psplashBuffer="${psplashBuffer}\n$1"
		shift
	done

	psplash-write "MSG $( echo -e "$psplashBuffer" )


"
}

finished() {
	msg "Completed! Remove USB drive"
	sync
	while (true); do
		dbus-send --system --print-reply --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:440 int32:100
		sleep 1
		dbus-send --system --print-reply --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:660 int32:100
		sleep 1
		dbus-send --system --print-reply --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:880 int32:100
		sleep 3
		# Reboot once the USB stick is unplugged
		[ -e "$USBDEV" ] || reboot -f
	done
}

bspCheck() {
	if [ -e /etc/issue ]; then
		VERSION_NUMBER=$(grep -oE '[0-9]+(\.[a-z0-9]+)+' /etc/issue)
		msg "This script is running for BSP version $VERSION_NUMBER"
		echo "BSP Version: $VERSION_NUMBER"
	else
		msg "Could not find BSP version."
		echo "BSP Version: unknown"
		return 1
	fi
}

SCRIPTDIR="$( dirname $0 )"
USBDEV=$( df "$SCRIPTDIR" | sed -n 2p | awk '{print $1}')

MYLOG=output.log
exec &>>$MYLOG

BSP_VERSION=$(bspCheck)

dbus-send --system --print-reply --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:440 int32:100
killall -9 psplash &>/dev/null; sleep 1
psplash --notouch &>/dev/null &

msg "Running $TOOL_NAME v$VERSION"

./autosetup

UPDATEFILE="updatePackage.zip"
#Install updatePackage (USBApplicationInstallerv1.6)
if [ -e "$UPDATEFILE" ]; then 
	msg "Completed step 1, going to install UpdatePackage"
	sleep 1
	sudo /bin/bash ./update.sh
	sleep 2
	exit 0
elif [ -e "browser.ini" ]; then
	msg "Copying browser settings file to /mnt/data/hmi/chromium/deploy/"
	sleep 1
    sudo cp browser.ini /mnt/data/hmi/chromium/deploy/
    if [ $? -eq 0 ]; then
		msg "browser.ini copied successfully."
    else
        msg "Failed to copy browser.ini."
    fi
	sleep 1
fi

#if [ -f UPDATEFILE ]; then
#	msg "Completed step 1, going to install UpdatePackage"
#	sleep 1
#	sudo /bin/bash ./update.sh
#	sleep 2
#	exit 0
#fi

finished

