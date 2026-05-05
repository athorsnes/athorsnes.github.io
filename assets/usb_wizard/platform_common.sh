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

success() {
	msg
	msg "\nUPDATE SUCCESSFULL !" "Please remove the USB drive."

	# Led ON
	if [ -n "$STATUS_LED" ]; then
		echo none > "${STATUS_LED}/trigger"
		echo 1 > "${STATUS_LED}/brightness"
	fi

	dbus-send --system --print-reply --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:440 int32:100; sleep 1
	dbus-send --system --print-reply --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:440 int32:100; sleep 1
	dbus-send --system --print-reply --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:440 int32:100; sleep 1

	# Wait until USB stick is unplugged
	while [ -e "$USBDEV" ]; do
		sleep 3
	done
	reboot -f
}

die() {
	msg
	if [ $# -gt 0 ]; then
		msg "ERROR: $1"
		shift
	else
		msg "ERROR: Operation failed"
	fi

	[ $# -gt 0 ] && msg "$2"

	cp $LOG_FILE $LOG_FILE_FAIL; sync
	msg	"Log saved to \"$LOG_FILE_FAIL\"" "Please remove the USB drive."

	if [ -n "$STATUS_LED" ]; then
		# Error led slow blinking. 1000/500 ms
		echo timer > "${STATUS_LED}/trigger"
		echo 1000 > "${STATUS_LED}/delay_on"
		echo 500 > "${STATUS_LED}/delay_off"
	fi

	while (true); do
		dbus-send --system --print-reply --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:440 int32:200 &>/dev/null; sleep 3
		# Reboot once the USB stick is unplugged
		[ -e "$USBDEV" ] || reboot -f
	done
}

LOG_FILE=lastRun.log
LOG_FILE_FAIL=lastFailed.log
exec &>$LOG_FILE

SCRIPTDIR="$( dirname $0 )"
USBDEV=$( df "$SCRIPTDIR" | sed -n 2p | awk '{print $1}')
HWCODE=$( cat /proc/cmdline | sed 's:.*hw_code=\([0-9]*\).*:\1:' )

if [ -e /boot/version ]; then
	TAG=$( cat /boot/version )
	PLATFORM=${TAG:0:2}
	PART=${TAG:8:1}
	OS_VERSION=${TAG:9:8}
fi

case $HWCODE in
128)
	STATUS_LED="/sys/class/leds/na16\:led\:enable"
	;;
132)
	STATUS_LED="/sys/class/leds/usr"
	;;
esac

dbus-send --print-reply --system --dest=com.exor.EPAD "/Buzzer" com.exor.EPAD.Buzzer.beep int32:440 int32:100 &>/dev/null

if [ -n "$STATUS_LED" ]; then
	# Running led fast blinking. 100/100 ms
	echo timer > "${STATUS_LED}/trigger"
	echo 100 > "${STATUS_LED}/delay_on"
	echo 100 > "${STATUS_LED}/delay_off"
fi

killall -9 psplash &>/dev/null; sleep 1
psplash --notouch &>/dev/null &

if [ -n "$TOOL_NAME" ]; then
	TITLE="$TOOL_NAME"
	[ -n "$VERSION" ] && TITLE="$TITLE v${VERSION}"
	msg "> $TITLE"
fi
