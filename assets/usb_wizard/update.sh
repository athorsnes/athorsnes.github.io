#!/bin/bash

#
# USB PackageInstaller
#
TOOL_NAME="PackageInstaller"
VERSION=1.6


export PATH=$PATH:/bin/:/sbin/:/usr/bin/:/usr/sbin/:
cd $(dirname $0)

[ ! -e platform_common.sh ] && exit 1
. ./platform_common.sh

JM_DIR="/mnt/data/hmi/qthmi/deploy"
CDS3_DIR="/mnt/data/hmi/cds3/deploy"

updateCodesys(){

	CODESYS_PKG="$( ls  CODESYS_*.tar.gz 2>/dev/null | head -n1 )"
	( [ -e "$CODESYS_PKG" ] && ( tar tzf "$CODESYS_PKG" rts &>/dev/null ) ) || CODESYS_PKG=

	# Nothing to do
	[ ! -n "$CODESYS_PKG" -a ! -e  "Application.app" ] && return 1

	# Check for a Codesys package to install
	if [ -e "$CODESYS_PKG" ]; then
		[ ! -d  "${JM_DIR}" ] &&  die "Can not find Codesys folder" "Make sure JMobile is installed"

		killall codesyscontrol
		msg "* Updating Codesys..."

		rm -rf "${JM_DIR}/rts"
		tar xzf "$CODESYS_PKG" -C "${JM_DIR}" rts

		[ -e /dev/fram ] && dd if=/dev/zero of=/dev/fram bs=1024 count=64
		sync
	fi

	# Check for a Codesys application to install
	if [ -e "Application.app" ]; then
		if [ -d "${CDS3_DIR}" ]; then
			CDS_PRJ_DIR="${CDS3_DIR}/PlcLogic/Application"
			CDS_CFG="${CDS3_DIR}/CODESYSControl.cfg"
		elif [ -d "${JM_DIR}" ]; then
			CDS_PRJ_DIR="${JM_DIR}/rts/PlcLogic/Application"
			CDS_CFG="${JM_DIR}/rts/CODESYSControl.cfg"
		else
			die "Can not find Codesys folder" "Make sure the runtime is installed"
		fi

		[ ! -e "${CDS_CFG}" ] && die "Can not find Codesys cfg file"

		killall codesyscontrol
		msg "* Updating Codesys project..."

		[ -e "${CDS_PRJ_DIR}/Application.app" ] && rm -rf ${CDS_PRJ_DIR}/*
		mkdir -p ${CDS_PRJ_DIR}
		cp Application* "${CDS_PRJ_DIR}" || die "Failed installing files"

		if ( ! cat "${CDS_CFG}" | grep -q '^Application\.1=Application' ); then
			echo Enabling Codesys Application
			sed -i '/Application\.1=/d' "${CDS_CFG}"
			sed -i 's:\[CmpApp\]:\[CmpApp\]\nApplication.1=Application:' "${CDS_CFG}"
		fi

		[ -e /dev/fram ] && dd if=/dev/zero of=/dev/fram bs=1024 count=64
		sync
	fi

	return 0
}

pkgInstallDone(){
	updateCodesys
	success
}


PACKAGE_FILE="package.zip"
[ ! -e "$PACKAGE_FILE" ] && PACKAGE_FILE="UpdatePackage.zip"
if [ ! -e "$PACKAGE_FILE" ]; then 
	updateCodesys
	[ "$?" -eq 0 ] || die "Could not find any update file"
	success
fi

# Exit kiosk mode
dbus-send --print-reply --system --dest=com.exor.JMLauncher '/' com.exor.JMLauncher.exitKiosk boolean:false || die "Failed starting package installation"

# Get the application name
rm -rf /tmp/package.info
unzip "$(pwd)/$PACKAGE_FILE" package.info -d /tmp
pkgName="$( cat /tmp/package.info 2>/dev/null | tr '\r\n' 'N' | sed 's:.*<package>\(.*\)</package>.*:\1:' | sed 's:<\w\+>\s*N.*</\w\+>::g' | sed 's:.*<name>\(.*\)</name>.*:\1:' )"
[ ! -e /tmp/package.info -o -z "$pkgName" ] && die "Can not parse package"

echo Package name: $pkgName

# If it's a JMobile package and we already have a runtime installed we need to do an update
if [ "$pkgName" == "HMI Runtime" ]; then
	( cat /mnt/data/hmi/jmlauncher.xml 2>/dev/null | grep -q '<name>HMI Runtime' ) && UPDATE=1
fi


# Start package installation in background

dbus-send --print-reply --system --reply-timeout=180000 --dest=com.exor.JMLauncher '/' com.exor.JMLauncher.exitKiosk boolean:false

if [ -n "$UPDATE" ]; then
	msg "* Updating package..."
else
	msg "* Installing package..."
fi

(
sleep 2

if [ -n "$UPDATE" ]; then
	echo Starting package update...
	dbus-send --print-reply --system --reply-timeout=180000 --dest=com.exor.JMLauncher '/' com.exor.JMLauncher.update string:"$(pwd)/$PACKAGE_FILE" string:"/mnt/data/hmi/tmp" string:"" || die "Update failed"
else
	echo Starting package installation...
	dbus-send --print-reply --system --reply-timeout=180000 --dest=com.exor.JMLauncher '/' com.exor.JMLauncher.install string:"$(pwd)/$PACKAGE_FILE" || die "Installation failed"
fi

)&


# Start listening to dbus signals
(
while read eline; do

	( echo $eline | grep -q "member=installationFailed" ) && die "Installation failed"

done < <(dbus-monitor --system type='signal',interface=com.exor.JMLauncher,member=installationFailed)
) &

(
while read lline; do

	( echo $lline | grep -q "member=licenseAgreementRequest" ) || continue

	# We need to accept the license so that user interaction is not needed, also there is no
	# other way for devices without touchscreen. The user should be already aware of the license agreement
	dbus-send --print-reply --system --reply-timeout=120000 --dest=com.exor.JMLauncher '/' com.exor.JMLauncher.licenseAgreed \
		string:"$pkgName" boolean:true || die "Installation failed"

	echo License agreed!

done < <(dbus-monitor --system type='signal',interface=com.exor.JMLauncher,member=licenseAgreementRequest)
) &

if [ -n "$UPDATE" ]; then

	STATE=0
	while read pline; do

		if ( echo $pline | grep -q "member=stateChangeNotification" ); then
			STATE=1
			continue
		fi

		if [ "$STATE" -eq 1 ]; then
			STATE=0

			# Update completed
			if ( echo $pline | grep -q "int32 18" ); then
				break
			fi

			# Update failed
			( echo $pline | grep -q "int32 19" ) && die

		fi

	done < <(dbus-monitor --system type='signal',interface=com.exor.JMLauncher,member=stateChangeNotification)

else

	while read sline; do

		( echo $sline | grep -q "member=installationSuccess" ) || continue

		# Check if the application is enabled
		# Returns the value between <autostart></autostart> for our package
		pkgEnabled="$( cat /mnt/data/hmi/jmlauncher.xml | tr '\n' 'N' | sed 's:</package>:</package>\n:g' | grep "<name>$pkgName</name>" | sed 's:.*<autostart>\(.*\)</autostart>.*:\1:' )"

		[ -z "$pkgEnabled" ] && die "Failed to verify package installation"

		if [ ! "$pkgEnabled" -eq 1 ]; then

			echo Enabling application...

			# Get the current max package order number
			orderList="$(cat /mnt/data/hmi/jmlauncher.xml | grep '<order>' | sed 's:.*<order>\([0-9]*\)</order>.*:\1:' | sort -r )"
			lastIndex="$(echo $orderList | cut -d' ' -f1)"

			# Considering we have just installed a package we should have a value
			[ -z "$lastIndex" ] && die "Failed to enable the application"

			echo Application order: $(( $lastIndex + 1 ))

			# Enable application, add it in the last position
			dbus-send --system --print-reply --dest=com.exor.JMLauncher '/' com.exor.JMLauncher.add string:"$pkgName" int32:$(( $lastIndex + 1 )) || die "Failed to enable the application"
		fi

		break

	done < <(dbus-monitor --system type='signal',interface=com.exor.JMLauncher,member=installationSuccess)

fi

if [ -e "browser.ini" ]; then
	msg "Copying browser settings file to /mnt/data/hmi/chromium/deploy/"
    sudo cp browser.ini /mnt/data/hmi/chromium/deploy/
    if [ $? -eq 0 ]; then
		msg "browser.ini copied successfully."
    else
        msg "Failed to copy browser.ini."
    fi
	
fi

if [ -e "ini2json.sed" ]; then
	echo "Copying sed script file to /mnt/data/hmi/chromium/deploy/"
	sudo mv /mnt/data/hmi/chromium/deploy/ini2json.sed /mnt/data/hmi/chromium/deploy/old_ini2json.sed
    sudo cp ini2json.sed /mnt/data/hmi/chromium/deploy/
    if [ $? -eq 0 ]; then
		echo "ini2json.sed copied successfully."
    else
        echo "Failed to copy ini2json.sed."
    fi
fi

sync
pkgInstallDone
